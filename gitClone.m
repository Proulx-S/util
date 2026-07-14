function gitClone(url, folder, repoSubDir, branch, allowWrite)
    % Clone or ensure repo at folder is present and (optionally) on given branch.
    % Remote is always origin. User specifies the local branch name (e.g. main);
    % it is always synced with origin/<same name> (e.g. origin/main).
    % If branch is empty or omitted, defaults to the remote default branch (e.g. main).
    %
    % folder is left read-only afterward (this is meant to be the shared canonical
    % clone used across projects) unless allowWrite is true. To develop a tool
    % locally instead, use getClone.m, which clones a detached, writable,
    % project-tracked copy.
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
    if exist(fullfile(folder,repoSubDir), 'dir')
        disp([url ' ' repoSubDir newline 'already downloaded to:' newline ' ' folder]);

        % A prior run may have left this read-only; restore write access before
        % fetching/checking out.
        system(['chmod -R u+w ' folder]);

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
        end
        clear stFetch
        % Check repository sync status
        [cmdLog, statusMsg, uncommittedMsg] = gitCheck(folder, cmdLog);
        
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
    if ~allowWrite
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
    