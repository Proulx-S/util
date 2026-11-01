function folder = gitToolShared(tool, opts)
% GITTOOLSHARED  Put a tool's SHARED clone ($BASS_ROOT/tools/<tool>, on main) on the path.
%
%   folder = gitToolShared(tool)
%   folder = gitToolShared(tool, opts)
%   opts   = gitToolShared()            % prints this help, returns the default opts
%
% D14 mode 1 (bass docs/v2/02-v2-design.md §6.11). Every project reads a tool from ONE shared
% clone, kept on main. This wrapper makes sure that clone exists and is fast-forwarded to
% origin/main, then adds it to the path through genpathClean. It runs only `git clone -b main`,
% `git fetch` and `git merge --ff-only`. It NEVER checks out, switches, stashes, resets or deletes
% anything. If the clone is on another branch, detached or dirty, it warns loudly, leaves the clone
% alone and still adds it to the path, so the doIt keeps running.
%
% To change a tool from a project, use gitToolDev (mode 2) instead.
%
% Inputs
%   tool   folder/repo name, e.g. 'util'. Must match ^[A-Za-z0-9._-]+$.
%   opts   struct, any subset of the defaults:
%     .url       remote URL. '' (default) = https://github.com/Proulx-S/<tool>
%     .toolsDir  folder holding the shared clones. '' (default) = $BASS_ROOT/tools, or
%                /scratch/bass/tools when BASS_ROOT is unset. Must exist and end in /tools.
%     .subDir    subfolder to put on the path ('' = the whole clone). No sparse checkout.
%
% Output
%   folder  absolute path of the shared clone.
%
% Edge cases
%   missing folder            -> git clone -b main; a failed clone (no network) is an error
%   folder that isn't a repo  -> loud warning, no git, added to the path anyway
%   offline (fetch fails)     -> warning, the local main is used as is
%   on another branch/detached-> loud warning (likely a legacy doIt pinning the shared clone with
%                                gitClone(...,branch)); no fast-forward
%   dirty tracked files       -> loud warning; no fast-forward (untracked files are ignored, so
%                                agent worktrees under .claude/worktrees/ don't count)
%   no origin/main            -> loud warning; no fast-forward
%   diverged from origin/main -> loud warning; left as is
%
% doIt usage
%   bassRoot = getenv('BASS_ROOT'); if isempty(bassRoot); bassRoot = '/scratch/bass'; end
%   addpath(fullfile(bassRoot,'tools','util'));          % bootstrap: gitTool* live in util
%   gitToolShared('util'); gitToolShared('vfMRItools');
%
% See also gitToolDev, genpathClean, gitClone (legacy; unchanged).

    defaults = struct('url', '', 'toolsDir', '', 'subDir', '');
    if nargin == 0
        help(mfilename);
        folder = defaults;
        return
    end
    if nargin < 2; opts = struct; end
    L = gitToolLib;
    opts = L.mergeOpts(defaults, opts);

    % ---- validate every path before any filesystem or git action ----
    tool = L.checkTool(tool);
    if isempty(opts.toolsDir); opts.toolsDir = fullfile(L.bassRootDir(), 'tools'); end
    toolsDir = L.canonicalDir(opts.toolsDir, 'opts.toolsDir');
    if ~endsWith(toolsDir, [filesep 'tools'])
        error('gitToolShared:badToolsDir', 'opts.toolsDir must end in /tools (got %s).', toolsDir);
    end
    folder = fullfile(toolsDir, tool);
    if ~endsWith(folder, [filesep 'tools' filesep tool])
        error('gitToolShared:badFolder', 'Refusing: %s does not end in /tools/%s.', folder, tool);
    end
    subDir = L.checkSubDir(opts.subDir);
    url = opts.url;
    if isempty(url); url = ['https://github.com/Proulx-S/' tool]; end
    url = L.checkUrl(url);

    disp([newline '-------------------------------- gitToolShared: ' tool]);
    log = {}; warns = {};

    if ~exist(folder, 'dir')
        if exist(folder, 'file')
            error('gitToolShared:notDir', '%s exists but is not a folder.', folder);
        end
        [st, out, log] = L.runGit(log, '', ['clone -b main -- ' L.q(url) ' ' L.q(folder)]);
        if st ~= 0
            error('gitToolShared:cloneFailed', 'git clone of %s into %s failed:\n%s', url, folder, out);
        end
        disp(['cloned ' url ' (main) into ' folder]);
    elseif ~L.isRepoRoot(folder)
        warns{end+1} = L.loud({[folder ' exists but is NOT a git repository (no .git at its root).'], ...
            'Left untouched; added to the path as is. Fix by hand (ask Seb).'});
    else
        [st, out, log] = L.runGit(log, folder, 'fetch origin');
        if st ~= 0
            warns{end+1} = L.loud({['git fetch failed (offline or no access): using the local state of ' folder '.'], strtrim(out)});
        end
        cur = L.currentBranch(folder);
        dirty = L.gitOut(folder, 'status --porcelain -uno');
        if ~strcmp(cur, 'main')
            if strcmp(cur, 'HEAD'); what = 'a DETACHED HEAD'; else; what = ['branch ''' cur '''']; end
            warns{end+1} = L.loud({['The SHARED clone ' folder ' is on ' what ', not main.'], ...
                'Likely a legacy doIt pinning it with gitClone(...,branch). Left alone: no fast-forward.', ...
                'Your path now uses THAT code. To change a tool from a project, use gitToolDev.'});
        elseif ~isempty(dirty)
            warns{end+1} = L.loud({['The SHARED clone ' folder ' has uncommitted changes to tracked files:'], ...
                dirty, 'Left alone: no fast-forward. Nobody should edit the shared clone in place (ask Seb).'});
        elseif ~L.hasRef(folder, 'refs/remotes/origin/main')
            warns{end+1} = L.loud({[url ' has no origin/main. Left alone: no fast-forward.']});
        else
            [st, out, log] = L.runGit(log, folder, 'merge --ff-only origin/main');
            if st ~= 0
                warns{end+1} = L.loud({['Could not fast-forward ' folder ' to origin/main (diverged?). Left as is.'], strtrim(out)});
            end
        end
    end

    p = fullfile(folder, subDir);
    addpath(genpathClean(p));   % see genpathClean.m: no .git/.claude/scratch
    L.summary(tool, folder, p, log, warns);
end

