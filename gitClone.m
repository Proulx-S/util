function gitClone(url, folder, repoSubDir, branch, allowWrite)
    % Clone or ensure repo at folder is present and (optionally) on given branch.
    % Remote is always origin. User specifies the local branch name (e.g. main);
    % it is always synced with origin/<same name> (e.g. origin/main) -- INCLUDING
    % fast-forwarding an already-correctly-named local branch that's simply stale
    % (see FAST-FORWARD below; this was previously a gap -- a local branch already
    % matching the target name was left exactly where it was, never advanced).
    %
    % folder is left WRITABLE afterward. (Until 2026-09-11 it was chmod'd read-only
    % as the shared canonical clone used across projects; that lock is retired --
    % modifications to a shared tool now go through a dedicated agent session
    % launched in that tool's own directory, on a branch + PR like any repo. A
    % clone left read-only by an older gitClone is unlocked on its next sync.)
    % allowWrite (5th arg) is accepted for backward compatibility but ignored.
    % getClone.m still clones a detached, project-tracked copy for the cases that
    % need one.
    %
    % FAST-FORWARD: once on the target branch (whether just switched to it or
    % already there), runs `git merge --ff-only origin/<branch>`. This is what
    % actually advances a stale-but-correctly-named local branch -- the checkout
    % step above only fires when the CURRENT branch name differs from the target,
    % so without this, a folder already sitting on (say) 'main' but behind
    % origin/main was silently left stale even though its own status check further
    % below would print "N commits behind" and do nothing about it. A genuine
    % divergence (local commits not on origin -- should not happen on a pristine
    % shared mirror) makes --ff-only refuse rather than silently resolving it, and
    % a loud message asks for it to be inspected by hand.
    %
    % UNCOMMITTED-CHANGES SAFETY NET: this folder should not normally have
    % uncommitted changes, but if it does (an edit made in place, a prior run that
    % crashed mid-sync), don't silently discard whatever is sitting here. Any
    % uncommitted changes to TRACKED files are stashed before the
    % checkout/fast-forward above can touch the working tree, then popped back once
    % the sync itself is done. A clean pop is silent (just a confirmation message);
    % a pop that would conflict is left IN THE STASH -- never dropped, never forced
    % -- with an explicit `git stash list`/`git stash pop` recovery message so the
    % conflict can be resolved by hand. Untracked files are deliberately NOT
    % counted or stashed (`git status --porcelain -uno`, `git stash push` without
    % -u): checkout / --ff-only never discard them, so stashing buys nothing, and
    % `stash -u` would physically remove an agent worktree's checkout under
    % .claude/worktrees/ (or any other untracked dir) from the working tree.
    %
    % SHARED-CLONE GUARD (2026-11-06): a folder directly under $BASS_ROOT/tools (or
    % /scratch/bass/tools) cloned from github.com/Proulx-S is a tool's SHARED clone, read by
    % every project and kept on the tool's default branch (bass rule shared-tools.md, D14).
    % (Third-party repos there, e.g. tcltk's tcl/tk pinned on core-8-4-branch, are exempt.)
    % For such a folder gitClone
    %   - ERRORS if asked for any other branch (it used to check it out, silently changing
    %     the code every other project runs); the message gives the project-local
    %     alternative: gitClone(url, fullfile(<projectDir>,'devTools',<tool>), ..., branch);
    %   - ERRORS if the clone is already off its default branch, and never switches it
    %     back itself (Seb restores it once, by hand);
    %   - never stashes it: uncommitted tracked changes are reported, and the clone is
    %     left as is (no fast-forward) but still added to the path.
    % The default branch is origin/HEAD, refreshed from the remote when online (offline:
    % the cached origin/HEAD); if it can't be determined, that is an error, not a guess.
    % Any other folder (a project's devTools/, a Mac path) behaves exactly as before.
    % Preferred for new code: gitToolShared (shared clone) and gitToolDev (project clone).
    % Test: dev/dev_gitCloneSharedGuard.m.
    %
    % If you see "authentication required": run in a terminal (outside MATLAB):
    %   cd <repo_folder>
    %   git fetch origin
    % You may be prompted for credentials; use a personal access token if 2FA is enabled.
    if ~exist('repoSubDir', 'var'); repoSubDir = []; end
    if ~exist('branch', 'var'); branch = []; end
    % allowWrite is a retired no-op (see header); still accepted so 5-arg callers keep working.
    branch = char(branch);
    if ~isempty(branch)
        branch = strtrim(branch);
        if contains(branch, '''') || contains(branch, ';') || contains(branch, newline)
            error('gitClone:invalidBranch', 'Branch name contains invalid characters.');
        end
    end
    % SHARED-CLONE GUARD (see file header): runs before ANY git or filesystem action, and errors
    % rather than checking out a non-default branch in (or switching back) a shared tool clone.
    [isShared, sharedDefault] = sharedCloneGuard(url, folder, branch);
    if isShared && isempty(branch) && ~isempty(sharedDefault)
        branch = sharedDefault;   % same branch the guard just checked the clone is on
    end
    sharedDirty = false;          % shared clone with uncommitted tracked changes: no stash, no ff
    disp([newline '--------------------------------']);
    cmdLog = {};
    statusMsg = '';
    uncommittedMsg = '';
    switchedToDefaultMsg = '';
    anomaly = false;   % set true on an unresolved anomaly (diverged history / stash-pop conflict)
    if exist(fullfile(folder,repoSubDir), 'dir')
        disp([url ' ' repoSubDir newline 'already downloaded to:' newline ' ' folder]);

        % A gitClone older than 2026-09-11 left this read-only; make sure it is writable
        % before fetching/checking out (one-time unlock, harmless on an already-writable folder).
        system(['chmod -R u+w ' folder]);

        % Safety net (see file header UNCOMMITTED-CHANGES SAFETY NET): stash any uncommitted
        % changes to TRACKED files BEFORE the checkout/fast-forward below can touch the working
        % tree. Untracked files are neither counted (-uno) nor stashed (no -u) -- see header.
        wasStashed = false; stashLabel = '';
        [~, dirtyStatus] = system(['cd ' folder ' && git status --porcelain -uno']);
        if ~isempty(strtrim(dirtyStatus)) && isShared
            % A shared clone is never stashed (that would hide someone's edit from every project):
            % leave it exactly as is, skip the fast-forward, and say so.
            sharedDirty = true;
            disp([newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline ...
                  '!!! ' folder ' is a SHARED tool clone with UNCOMMITTED CHANGES to' newline ...
                  '!!! tracked files. Not stashed, not fast-forwarded: left exactly as is.' newline ...
                  '!!! Changed files:' newline strtrim(dirtyStatus) newline ...
                  '!!! Ask Seb (or the tool''s agent) what they are before running from it.' newline ...
                  '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!']);
        elseif ~isempty(strtrim(dirtyStatus))
            stashLabel = ['gitClone.m auto-stash ' char(datetime('now','Format','yyyy-MM-dd_HHmmss'))];
            cmdLog{end+1} = ['git stash push -m "' stashLabel '"'];
            [stStash, stashOut] = system(['cd ' folder ' && git stash push -m ''' stashLabel '''']);
            if stStash == 0 && ~contains(stashOut, 'No local changes to save')
                wasStashed = true;
                disp([newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline ...
                      '!!! ' folder ' had UNCOMMITTED CHANGES (unexpected for a shared' newline ...
                      '!!! clone) -- stashed as: ' stashLabel newline ...
                      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!']);
            end
        end

        % Fetch so we have up-to-date refs (and origin/HEAD for default branch)
        fetchCmd = ['cd ' folder ' && GIT_TERMINAL_PROMPT=0 git fetch origin 2>&1'];
        cmdLog{end+1} = 'GIT_TERMINAL_PROMPT=0 git fetch origin';
        [stFetch, ~] = system(fetchCmd);

        branchWasUnspecified = false;
        % Default to remote default branch when branch not specified
        if isempty(branch)
            % git fetch does NOT refresh origin/HEAD; re-resolve it so a changed remote
            % default branch is picked up instead of the stale cached one (else a repo
            % whose GitHub default moved, e.g. dev->main, gets switched back to the old branch).
            cmdLog{end+1} = 'git remote set-head origin --auto';
            system(['cd ' folder ' && GIT_TERMINAL_PROMPT=0 git remote set-head origin --auto 2>/dev/null']);
            [stD, defaultBranch] = system(['cd ' folder ' && git rev-parse --abbrev-ref origin/HEAD 2>/dev/null']);
            if stD == 0
                defaultBranch = strtrim(defaultBranch);
                defaultBranch = strrep(defaultBranch, 'origin/', '');
                if ~isempty(defaultBranch)
                    branch = defaultBranch;
                    branchWasUnspecified = true;
                end
            end
        end
        if ~isempty(branch)
            revCmd = ['cd ' folder ' && git rev-parse --abbrev-ref HEAD'];
            cmdLog{end+1} = 'git rev-parse --abbrev-ref HEAD';
            [st, cur] = system(revCmd);
            cur = strtrim(cur);
            if st == 0 && ~strcmp(cur, branch)
                % Branch exists locally: switch. Else origin/branch exists: checkout (creates local tracking).
                % Else create new local branch (user asked for a branch that doesn't exist on remote).
                bq = ['''' strrep(branch, '''', '''\''') ''''];
                refHead = ['''' 'refs/heads/' strrep(branch, '''', '''\''') ''''];
                refOrigin = ['''' 'origin/' strrep(branch, '''', '''\''') ''''];
                [stLocal, ~] = system(['cd ' folder ' && git rev-parse --verify ' refHead ' 2>/dev/null']);
                [stOrigin, ~] = system(['cd ' folder ' && git rev-parse --verify ' refOrigin ' 2>/dev/null']);
                if stLocal == 0
                    coCmd = ['cd ' folder ' && git checkout ' bq ' 2>&1'];
                    cmdLog{end+1} = ['git checkout ' branch];
                    system(coCmd);
                elseif stOrigin == 0
                    coCmd = ['cd ' folder ' && git checkout ' bq ' 2>&1'];
                    cmdLog{end+1} = ['git checkout ' branch];
                    system(coCmd);
                else
                    coCmd = ['cd ' folder ' && git checkout -b ' bq ' 2>&1'];
                    cmdLog{end+1} = ['git checkout -b ' branch];
                    system(coCmd);
                end
                if branchWasUnspecified
                    [~, repoName] = fileparts(folder);
                    switchedToDefaultMsg = ['!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline '!!! Switched to remote default branch ''' branch ''' (' repoName '). !!!' newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'];
                    disp(switchedToDefaultMsg);
                end
            end
            % FAST-FORWARD (see file header) -- runs whether we just switched onto this branch or
            % were already sitting on it; --ff-only so a genuine divergence is surfaced, never
            % silently resolved.
            refOriginFF = ['''' 'origin/' strrep(branch, '''', '''\''') ''''];
            ffCmd = ['cd ' folder ' && git merge --ff-only ' refOriginFF ' 2>&1'];
            if sharedDirty
                stFF = 0;   % shared clone with uncommitted changes: left as is (warned above)
            else
                cmdLog{end+1} = ['git merge --ff-only origin/' branch];
                [stFF, ffOut] = system(ffCmd);
            end
            if stFF ~= 0
                anomaly = true;
                disp([newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline ...
                      '!!! Could not fast-forward ' folder ' to origin/' branch '.' newline ...
                      '!!! (local history has diverged -- should not happen on a pristine' newline ...
                      '!!! shared mirror; investigate by hand)' newline ...
                      '!!! git output:' newline strtrim(ffOut) newline ...
                      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!']);
            end
        end
        clear stFetch
        % Check repository sync status
        [cmdLog, statusMsg, uncommittedMsg] = gitCheck(folder, cmdLog);

        % Restore any auto-stashed changes (see file header) now that the sync itself is done --
        % skipped if the fast-forward above already hit an unresolved anomaly (working tree state
        % is uncertain then; better to leave the stash untouched too). Never forced: a pop that
        % would conflict is left IN THE STASH exactly as-is, never dropped.
        if wasStashed && ~anomaly
            [stPop, popOut] = system(['cd ' folder ' && git stash pop 2>&1']);
            if stPop == 0
                disp(['Restored the auto-stashed uncommitted changes (' stashLabel ') cleanly.']);
            else
                anomaly = true;
                disp([newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline ...
                      '!!! Auto-stash ''' stashLabel ''' could NOT be reapplied cleanly (conflicts' newline ...
                      '!!! with the newly-synced state) -- LEFT IN THE STASH, not dropped.' newline ...
                      '!!! Resolve by hand: cd ' folder '; git stash list; git stash pop' newline ...
                      '!!! git output:' newline strtrim(popOut) newline ...
                      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!']);
            end
        end

    else
        if isempty(repoSubDir)
            cmd = ['git clone ' url ' ' folder];
            if ~isempty(branch)
                cmd = ['git clone -b ' branch ' ' url ' ' folder];
            end
            cmdLog{end+1} = cmd;
            disp(cmd);
            system(['bash -c ''' cmd '''']);
        else
            cmd1 = ['git clone --filter=blob:none --sparse ' url ' ' folder];
            if ~isempty(branch)
                cmd1 = ['git clone -b ' branch ' --filter=blob:none --sparse ' url ' ' folder];
            end
            cmd2 = ['cd ' folder ' && git sparse-checkout init --no-cone && git sparse-checkout set ' repoSubDir '/** /README* /LICENSE* && git checkout'];
            cmdLog{end+1} = cmd1;
            cmdLog{end+1} = ['git sparse-checkout init --no-cone && git sparse-checkout set ' repoSubDir '/** /README* /LICENSE* && git checkout'];
            disp([cmd1 newline cmd2]);
            system(['bash -c ''' cmd1 '''']);
            system(['bash -c ''' cmd2 '''']);
        end
    end
    addpath(genpathClean(fullfile(folder,repoSubDir)));   % see genpathClean.m: no .git/.claude/scratch
    disp(['added to path:' newline ' ' fullfile(folder,repoSubDir)]);
    if anomaly
        disp([newline '--------------------------------' newline ...
            'NOTE: ' folder ' needs attention -- an anomaly above (diverged history, or a' newline ...
            'stash-pop conflict) needs resolving by hand.' newline ...
            'Re-run gitClone (or fix it directly) once resolved.' newline ...
            '--------------------------------']);
    end
    % Print git command history
    if ~isempty(cmdLog)
        disp([newline '--- Git commands run (history) ---']);
        for k = 1:numel(cmdLog)
            disp(['  ' num2str(k) '. ' cmdLog{k}]);
        end
        disp('--------------------------------');
    end
    % Repeat repository status at the end
    if ~isempty(statusMsg)
        disp(statusMsg);
    end
    if ~isempty(uncommittedMsg)
        disp(uncommittedMsg);
    end
    if ~isempty(switchedToDefaultMsg)
        disp(switchedToDefaultMsg);
    end


function [isShared, defaultBranch] = sharedCloneGuard(url, folder, branch)
% SHARED-CLONE GUARD. A folder directly under $BASS_ROOT/tools (or /scratch/bass/tools), cloned from
% github.com/Proulx-S, is a tool's SHARED clone: every project on the server reads that one copy, and it stays on the tool's default
% branch (bass rule shared-tools.md, design D14). Checking another branch out there silently changes
% the code every other project runs. So, before any git or filesystem action:
%   - a branch other than the default is REFUSED, with an error naming the project-local alternative;
%   - a shared clone found OFF its default branch is also an error: gitClone never switches a shared
%     clone itself, in either direction (Seb restores it once, by hand);
%   - with an empty branch, the default is used (returned in defaultBranch).
% The default branch is the clone's origin/HEAD, refreshed from the remote when online
% (git remote set-head origin --auto; offline, the cached origin/HEAD is used). A missing clone asks
% the remote (git ls-remote --symref). If the default cannot be determined, that is an error too,
% rather than a guess.
% Any other folder (a project's devTools/<tool>, a Mac path, a worktree under tools/<tool>/.claude)
% returns isShared = false, and gitClone behaves as before.
    isShared = false; defaultBranch = '';
    folderC = canonicalPath(folder);
    roots = unique({canonicalPath(fullfile(bassRoot(), 'tools')), canonicalPath('/scratch/bass/tools')});
    parent = fileparts(folderC);
    for k = 1:numel(roots)
        if exist(roots{k}, 'dir') && strcmp(parent, roots{k}); isShared = true; end
    end
    if ~isShared; return; end
    % Only Seb's own tools (github.com/Proulx-S/...) are shared clones in the D14 sense. A third-party
    % repo kept in the tools folder at a deliberate pin (e.g. tcltk's tcl/tk on core-8-4-branch, for
    % vesselRecon) is left to gitClone's ordinary behaviour.
    if isempty(regexpi(char(url), 'github\.com[:/]Proulx-S/', 'once'))
        isShared = false;
        disp(['gitClone: ' folderC ' is in the shared tools folder but ' char(url) ' is not a Proulx-S ' ...
            'repo: the shared-clone guard does not apply.']);
        return
    end
    [~, tool] = fileparts(folderC);

    isRepo = exist(fullfile(folderC, '.git'), 'dir') || exist(fullfile(folderC, '.git'), 'file');
    current = '';
    if isRepo
        system(['cd ' shq(folderC) ' && GIT_TERMINAL_PROMPT=0 git remote set-head origin --auto >/dev/null 2>&1']);
        [st, out] = system(['cd ' shq(folderC) ' && git rev-parse --abbrev-ref origin/HEAD 2>/dev/null']);
        if st == 0; defaultBranch = strrep(strtrim(out), 'origin/', ''); end
        [st, out] = system(['cd ' shq(folderC) ' && git symbolic-ref --quiet --short HEAD 2>/dev/null']);
        if st == 0; current = strtrim(out); else; current = '(detached HEAD)'; end
    else
        [st, out] = system(['GIT_TERMINAL_PROMPT=0 git ls-remote --symref ' shq(url) ' HEAD 2>/dev/null']);
        tok = regexp(out, 'ref: refs/heads/(\S+)\s+HEAD', 'tokens', 'once');
        if st == 0 && ~isempty(tok); defaultBranch = tok{1}; end
    end

    if isempty(defaultBranch)
        if ~isRepo && isempty(branch); return; end   % fresh clone of the remote default: nothing to check
        error('gitClone:sharedCloneDefaultUnknown', ['gitClone refused: %s is a SHARED tool clone, and ' ...
            'its default branch could not be determined (offline, and no origin/HEAD).\n' ...
            'Nothing was changed. Rerun when online, or ask Seb.'], folderC);
    end

    if ~isempty(branch) && ~strcmp(branch, defaultBranch)
        error('gitClone:sharedCloneBranch', ['gitClone refused to check out ''%s'' in %s.\n' ...
            'That folder is the SHARED clone of %s: every project reads it, and it stays on its ' ...
            'default branch ''%s''.\nNothing was changed (no checkout, fetch or stash).\n' ...
            'To run this project on ''%s'', clone that branch into the project instead:\n%s'], ...
            branch, folderC, tool, defaultBranch, branch, projectCloneHint(url, tool, branch));
    end
    if isRepo && ~strcmp(current, defaultBranch)
        error('gitClone:sharedCloneOffDefault', ['gitClone refused: the SHARED clone %s is on ''%s'', ' ...
            'not its default branch ''%s''\n(probably switched there by an older gitClone call with a ' ...
            'branch). Running from it would use the wrong code, and gitClone no longer switches shared ' ...
            'clones.\nNothing was changed. Seb restores it once, by hand, after checking it is clean:\n' ...
            '  git -C %s status --short\n  git -C %s checkout %s\n' ...
            'If a project needs ''%s'', it clones that branch into the project instead:\n%s'], ...
            folderC, current, defaultBranch, folderC, folderC, defaultBranch, current, ...
            projectCloneHint(url, tool, current));
    end


function s = projectCloneHint(url, tool, branch)
    s = sprintf(['  gitClone(''%s'', fullfile(<projectDir>,''devTools'',''%s''), <repoSubDir>, ''%s'')\n' ...
        '(a real clone inside the project; gitignore devTools/). To CHANGE the tool, use\n' ...
        '  gitToolDev(''%s'', ''dev-<project>-<feature>'', <projectDir>)\n' ...
        'See bass rule shared-tools.md and skill bass-code:shared-tool-change.'], url, tool, branch, tool);


function r = bassRoot()
    r = getenv('BASS_ROOT');
    if isempty(r); r = '/scratch/bass'; end


function c = canonicalPath(p)
% absolute, with .. and symlinks resolved as far as the path exists; no trailing separator.
% A relative path is taken from MATLAB's pwd (java.io.File alone would use the JVM's start folder).
    p = char(p);
    if isempty(p) || p(1) ~= filesep; p = fullfile(pwd, p); end
    c = char(java.io.File(p).getCanonicalPath());
    while numel(c) > 1 && c(end) == filesep; c(end) = []; end


function s = shq(s)
% single-quote a string for the shell
    s = ['''' strrep(char(s), '''', '''\''''') ''''];
    