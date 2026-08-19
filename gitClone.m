function gitClone(url, folder, repoSubDir, branch, allowWrite)
    % Clone or ensure repo at folder is present and (optionally) on given branch.
    % Remote is always origin. User specifies the local branch name (e.g. main);
    % it is always synced with origin/<same name> (e.g. origin/main) -- INCLUDING
    % fast-forwarding an already-correctly-named local branch that's simply stale
    % (see FAST-FORWARD below; this was previously a gap -- a local branch already
    % matching the target name was left exactly where it was, never advanced).
    %
    % folder is left read-only afterward (this is meant to be the shared canonical
    % clone used across projects) unless allowWrite is true. To develop a tool
    % locally instead, use getClone.m, which clones a detached, writable,
    % project-tracked copy.
    %
    % FAST-FORWARD: once on the target branch (whether just switched to it or
    % already there), runs `git merge --ff-only origin/<branch>`. This is what
    % actually advances a stale-but-correctly-named local branch -- the checkout
    % step above only fires when the CURRENT branch name differs from the target,
    % so without this, a folder already sitting on (say) 'main' but behind
    % origin/main was silently left stale even though its own status check further
    % below would print "N commits behind" and do nothing about it. A genuine
    % divergence (local commits not on origin -- should not happen on a pristine,
    % lock-protected mirror) makes --ff-only refuse rather than silently resolving
    % it; folder is left WRITABLE (not re-locked) in that case so it can be
    % inspected by hand.
    %
    % UNCOMMITTED-CHANGES SAFETY NET: this folder should never have uncommitted
    % changes (it's read-only whenever nobody is actively calling this function),
    % but if the lock was bypassed (allowWrite=true) or a prior run crashed before
    % re-locking, don't silently discard whatever is sitting here. Any uncommitted
    % changes (tracked + untracked) are stashed before the checkout/fast-forward
    % above can touch the working tree, then popped back once the sync itself is
    % done. A clean pop is silent (just a confirmation message); a pop that would
    % conflict is left IN THE STASH -- never dropped, never forced -- with an
    % explicit `git stash list`/`git stash pop` recovery message, and the folder is
    % again left WRITABLE (not re-locked) so the conflict can be resolved by hand.
    %
    % If you see "authentication required": run in a terminal (outside MATLAB):
    %   cd <repo_folder>
    %   git fetch origin
    % You may be prompted for credentials; use a personal access token if 2FA is enabled.
    if ~exist('repoSubDir', 'var'); repoSubDir = []; end
    if ~exist('branch', 'var'); branch = []; end
    if ~exist('allowWrite', 'var') || isempty(allowWrite); allowWrite = false; end
    branch = char(branch);
    if ~isempty(branch)
        branch = strtrim(branch);
        if contains(branch, '''') || contains(branch, ';') || contains(branch, newline)
            error('gitClone:invalidBranch', 'Branch name contains invalid characters.');
        end
    end
    disp([newline '--------------------------------']);
    cmdLog = {};
    statusMsg = '';
    uncommittedMsg = '';
    switchedToDefaultMsg = '';
    skipRelock = false;   % set true on an unresolved anomaly (diverged history / stash-pop conflict)
    if exist(fullfile(folder,repoSubDir), 'dir')
        disp([url ' ' repoSubDir newline 'already downloaded to:' newline ' ' folder]);

        % A prior run may have left this read-only; restore write access before
        % fetching/checking out.
        system(['chmod -R u+w ' folder]);

        % Safety net (see file header UNCOMMITTED-CHANGES SAFETY NET): stash any uncommitted
        % changes BEFORE the checkout/fast-forward below can touch the working tree.
        wasStashed = false; stashLabel = '';
        [~, dirtyStatus] = system(['cd ' folder ' && git status --porcelain']);
        if ~isempty(strtrim(dirtyStatus))
            stashLabel = ['gitClone.m auto-stash ' char(datetime('now','Format','yyyy-MM-dd_HHmmss'))];
            cmdLog{end+1} = ['git stash push -u -m "' stashLabel '"'];
            [stStash, stashOut] = system(['cd ' folder ' && git stash push -u -m ''' stashLabel '''']);
            if stStash == 0 && ~contains(stashOut, 'No local changes to save')
                wasStashed = true;
                disp([newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline ...
                      '!!! ' folder ' had UNCOMMITTED CHANGES (unexpected for a locked' newline ...
                      '!!! shared clone) -- stashed as: ' stashLabel newline ...
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
            cmdLog{end+1} = ['git merge --ff-only origin/' branch];
            [stFF, ffOut] = system(ffCmd);
            if stFF ~= 0
                skipRelock = true;
                disp([newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline ...
                      '!!! Could not fast-forward ' folder ' to origin/' branch '.' newline ...
                      '!!! (local history has diverged -- should not happen on a pristine' newline ...
                      '!!! shared mirror; investigate by hand -- folder left WRITABLE)' newline ...
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
        if wasStashed && ~skipRelock
            [stPop, popOut] = system(['cd ' folder ' && git stash pop 2>&1']);
            if stPop == 0
                disp(['Restored the auto-stashed uncommitted changes (' stashLabel ') cleanly.']);
            else
                skipRelock = true;
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
    addpath(genpath(fullfile(folder,repoSubDir)));
    disp(['added to path:' newline ' ' fullfile(folder,repoSubDir)]);
    if skipRelock
        disp([newline '--------------------------------' newline ...
            'NOTE: ' folder ' left WRITABLE -- an anomaly above (diverged history, or a' newline ...
            'stash-pop conflict) needs resolving by hand before it should be re-locked.' newline ...
            'Re-run gitClone (or fix it directly) once resolved.' newline ...
            '--------------------------------']);
    elseif ~allowWrite
        system(['chmod -R a-w ' folder]);
        disp([newline '--------------------------------' newline ...
            'NOTE: ' folder ' is now read-only. It''s the shared canonical clone used' newline ...
            'by every project -- edits here can be silently overwritten and can race' newline ...
            'concurrent runs.' newline ...
            'To develop this tool locally: use getClone.m instead (tracks a detached' newline ...
            'copy in your project''s own repo). To write here anyway (not recommended):' newline ...
            'call gitClone with allowWrite=true.' newline ...
            '--------------------------------']);
    else
        disp('NOTE: read-only protection disabled for this call (allowWrite=true).');
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
    