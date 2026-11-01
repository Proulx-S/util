function folder = gitToolDev(tool, branch, projectDir, opts)
% GITTOOLDEV  Put a project's DEV CLONE of a tool (<projectDir>/devTools/<tool>) on the path.
%
%   folder = gitToolDev(tool, branch, projectDir)
%   folder = gitToolDev(tool, branch, projectDir, opts)
%   opts   = gitToolDev()                  % prints this help, returns the default opts
%
% D14 mode 2 (bass docs/v2/02-v2-design.md §6.11). A project that needs a tool change works in its
% own real git clone of the tool (it keeps .git), on a branch dev-<project>-<feature> pushed to the
% tool's remote. The tool agent later merges that branch into the tool's main. This wrapper makes
% sure the clone exists and is on that branch (cloning, creating the branch from origin/main and
% pushing it with tracking when needed), fast-forwards it when it is clean and behind, and adds
% it to the path through genpathClean, AFTER removing the shared clone of the same tool
% ($BASS_ROOT/tools/<tool>) from the path so the two copies don't mix.
%
% It never discards edits or commits: fast-forward only, never reset, stash, force or delete.
%
% Inputs
%   tool        folder/repo name, e.g. 'util'. Must match ^[A-Za-z0-9._-]+$.
%   branch      FULL branch name, e.g. 'dev-vesTrack-colormap'. Must start with 'dev-'. Written in
%               full so the tool agent can grep the doIts that use it.
%   projectDir  the project's folder (a doIt's workDir). Must be an existing folder, not '/'.
%   opts        struct, any subset of the defaults:
%     .url       remote URL. '' (default) = https://github.com/Proulx-S/<tool>
%     .toolsDir  folder of the shared clones, only used to take the shared copy off the path.
%                '' (default) = $BASS_ROOT/tools, or /scratch/bass/tools when BASS_ROOT is unset.
%     .subDir    subfolder to put on the path ('' = the whole clone). No sparse checkout.
%
% Output
%   folder  absolute path of the dev clone, <projectDir>/devTools/<tool>.
%
% Edge cases
%   folder missing          -> git clone; then the branch from origin, or created from origin/main
%                              and pushed with -u. A failed clone is an error; a failed push is a
%                              loud warning with the command to rerun.
%   folder that isn't a repo-> ERROR (probably a legacy getClone copy, stripped of .git: ask Seb)
%   origin URL differs      -> loud warning
%   offline (fetch fails)   -> warning, local state used; a missing branch is created locally
%   on another branch       -> clean: switch to <branch> (the other branch keeps its commits);
%                              dirty or detached: ERROR (running the wrong code silently is worse)
%   dirty on <branch>       -> no fast-forward (normal while developing); status printed
%   unpushed commits        -> noted; not pushed for you
%   branch not on remote    -> pushed with -u (also when an earlier push failed)
%   diverged from remote    -> loud warning, left alone
%   devTools/<tool>/ not gitignored by the project -> loud warning (the project file isn't edited)
%
% doIt usage
%   bassRoot = getenv('BASS_ROOT'); if isempty(bassRoot); bassRoot = '/scratch/bass'; end
%   addpath(fullfile(bassRoot,'tools','util'));          % bootstrap: gitTool* live in util
%   gitToolShared('util');                                % tools you only read
%   gitToolDev('vfMRItools', 'dev-vesTrack-colormap', workDir);   % the tool you are changing
%
% See also gitToolShared, genpathClean, gitClone (legacy; unchanged).

    defaults = struct('url', '', 'toolsDir', '', 'subDir', '');
    if nargin == 0
        help(mfilename);
        folder = defaults;
        return
    end
    if nargin < 3; error('gitToolDev:nargin', 'Usage: gitToolDev(tool, branch, projectDir [, opts]).'); end
    if nargin < 4; opts = struct; end
    L = gitToolLib;
    opts = L.mergeOpts(defaults, opts);

    % ---- validate every path and name before any filesystem or git action ----
    tool = L.checkTool(tool);
    branch = checkBranch(branch);
    projectDir = L.canonicalDir(projectDir, 'projectDir');
    folder = fullfile(projectDir, 'devTools', tool);
    if ~endsWith(folder, [filesep 'devTools' filesep tool])
        error('gitToolDev:badFolder', 'Refusing: %s does not end in /devTools/%s.', folder, tool);
    end
    subDir = L.checkSubDir(opts.subDir);
    url = opts.url;
    if isempty(url); url = ['https://github.com/Proulx-S/' tool]; end
    url = L.checkUrl(url);
    if isempty(opts.toolsDir); opts.toolsDir = fullfile(L.bassRootDir(), 'tools'); end
    sharedDir = fullfile(char(opts.toolsDir), tool);

    disp([newline '-------------------------------- gitToolDev: ' tool ' on ' branch]);
    log = {}; warns = {};
    qb = L.q(branch);

    % ---- 1. the clone ----
    online = true;
    if ~exist(folder, 'dir')
        if exist(folder, 'file'); error('gitToolDev:notDir', '%s exists but is not a folder.', folder); end
        [st, out, log] = L.runGit(log, '', ['clone -- ' L.q(url) ' ' L.q(folder)]);
        if st ~= 0
            error('gitToolDev:cloneFailed', 'git clone of %s into %s failed:\n%s', url, folder, out);
        end
        disp(['cloned ' url ' into ' folder]);
    elseif ~L.isRepoRoot(folder)
        error('gitToolDev:notRepo', ['%s exists but is not a git repository (no .git at its root).\n' ...
            'It is probably a legacy getClone copy. Close it out first (develop-tool-locally skill): ask Seb.'], folder);
    else
        [st, out, log] = L.runGit(log, folder, 'fetch origin');
        if st ~= 0
            online = false;
            warns{end+1} = L.loud({['git fetch failed (offline or no access): using the local state of ' folder '.'], strtrim(out)});
        end
    end
    originUrl = L.gitOut(folder, 'remote get-url origin');
    if ~strcmp(normUrl(originUrl), normUrl(url))
        warns{end+1} = L.loud({[folder ' has origin ' originUrl ','], ['not ' url '. Check that this is the right clone.']});
    end

    % ---- 2. the branch ----
    cur = L.currentBranch(folder);
    hasRemote = L.hasRef(folder, ['refs/remotes/origin/' branch]);
    if ~strcmp(cur, branch)
        if strcmp(cur, 'HEAD')
            error('gitToolDev:detached', '%s is on a DETACHED HEAD, not %s. Left alone: fix it by hand.', folder, branch);
        end
        dirty = L.gitOut(folder, 'status --porcelain -uno');
        if ~isempty(dirty)
            error('gitToolDev:dirtyOtherBranch', ['%s is on ''%s'' with uncommitted changes, not on %s.\n' ...
                'Left alone: commit (or move) those changes, then rerun.\n%s'], folder, cur, branch, dirty);
        end
        if L.hasRef(folder, ['refs/heads/' branch])
            [st, out, log] = L.runGit(log, folder, ['switch ' qb]);
        elseif hasRemote
            [st, out, log] = L.runGit(log, folder, ['switch -c ' qb ' --track ' L.q(['origin/' branch])]);
        else
            if ~L.hasRef(folder, 'refs/remotes/origin/main')
                error('gitToolDev:noMain', '%s has no origin/main to create %s from.', folder, branch);
            end
            [st, out, log] = L.runGit(log, folder, ['switch --no-track -c ' qb ' origin/main']);
            if st == 0; disp(['created ' branch ' from origin/main']); end
            if st == 0 && ~online
                warns{end+1} = L.loud({['Created ' branch ' from the LOCAL origin/main (offline): it may already exist on the remote.'], ...
                    'Rerun when online; a push that is rejected means the remote has it (nothing is lost).'});
            end
        end
        if st ~= 0
            error('gitToolDev:switchFailed', 'Could not switch %s to %s:\n%s', folder, branch, out);
        end
        if ~strcmp(cur, branch) && ~isempty(cur)
            disp(['switched ' folder ' from ''' cur ''' to ''' branch ''' (''' cur ''' keeps its commits)']);
        end
    end

    % ---- 3. sync with the remote branch: push if missing, ff only if clean and behind ----
    if ~hasRemote
        if online
            [st, out, log] = L.runGit(log, folder, ['push -u origin ' qb]);
            if st ~= 0
                warns{end+1} = L.loud({['Could not push ' branch ' to origin: it exists only in ' folder '.'], strtrim(out), ...
                    ['Rerun this, or: git -C ' L.q(folder) ' push -u origin ' qb]});
            else
                disp(['pushed ' branch ' to origin with tracking']);
            end
        else
            warns{end+1} = L.loud({[branch ' is local only (offline). Rerun when online to push it.']});
        end
    else
        if isempty(L.gitOut(folder, 'rev-parse --abbrev-ref @{u}'))
            [~, ~, log] = L.runGit(log, folder, ['branch --set-upstream-to=' L.q(['origin/' branch])]);
        end
        ab = sscanf(L.gitOut(folder, ['rev-list --left-right --count HEAD...' L.q(['origin/' branch])]), '%d');
        dirty = L.gitOut(folder, 'status --porcelain -uno');
        if numel(ab) == 2
            ahead = ab(1); behind = ab(2);
            if behind > 0 && ahead > 0
                warns{end+1} = L.loud({[branch ' has DIVERGED from origin: ' num2str(ahead) ' local and ' num2str(behind) ' remote commit(s).'], ...
                    'Left alone. Merge or rebase by hand (never force-push a shared branch).'});
            elseif behind > 0 && ~isempty(dirty)
                disp([branch ' is ' num2str(behind) ' commit(s) behind origin, but has uncommitted edits: not fast-forwarded.']);
            elseif behind > 0
                [st, out, log] = L.runGit(log, folder, ['merge --ff-only ' L.q(['origin/' branch])]);
                if st ~= 0
                    warns{end+1} = L.loud({['Could not fast-forward ' branch '. Left as is.'], strtrim(out)});
                end
            elseif ahead > 0
                disp([branch ' has ' num2str(ahead) ' unpushed commit(s): push when ready (git -C ' L.q(folder) ' push).']);
            end
        end
    end

    % ---- 4. is devTools/<tool>/ ignored by the project? ----
    [st, ~] = system(['git -C ' L.q(projectDir) ' check-ignore -q ' L.q(['devTools/' tool '/']) ' 2>/dev/null']);
    if st == 1
        warns{end+1} = L.loud({['devTools/' tool '/ is NOT gitignored in ' projectDir '.'], ...
            ['Add the line  devTools/' tool '/  to the project''s .gitignore (in your project PR).']});
    end

    % ---- 5. path: shared copy off, dev clone on ----
    nOff = 0;
    if exist(sharedDir, 'dir')
        sharedDir = char(java.io.File(sharedDir).getCanonicalPath());
        P = strsplit(path, pathsep);
        off = P(strcmp(P, sharedDir) | startsWith(P, [sharedDir filesep]));
        nOff = numel(off);
        if nOff; rmpath(off{:}); end
    end
    p = fullfile(folder, subDir);
    addpath(genpathClean(p));   % see genpathClean.m: no .git/.claude/scratch
    if nOff; disp(['took ' num2str(nOff) ' folder(s) of the shared ' sharedDir ' off the path']); end
    L.summary(tool, folder, p, log, warns);
end


function branch = checkBranch(branch)
    if ~(ischar(branch) || (isstring(branch) && isscalar(branch))); error('gitToolDev:badBranch', 'branch must be a char name.'); end
    branch = char(branch);
    if ~startsWith(branch, 'dev-') || numel(branch) < 5 || isempty(regexp(branch, '^[A-Za-z0-9._/-]+$', 'once'))
        error('gitToolDev:badBranch', 'Refusing branch ''%s'': must be the full dev-<project>-<feature> name ([A-Za-z0-9._/-]).', branch);
    end
    if system(['git check-ref-format --branch ''' branch ''' >/dev/null 2>&1']) ~= 0
        error('gitToolDev:badBranch', 'Refusing branch ''%s'': not a valid git branch name.', branch);
    end
end

function u = normUrl(u)
    u = regexprep(strtrim(char(u)), '(\.git)?/*$', '');
end
