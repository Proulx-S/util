function [cmdLog, statusMsg, uncommittedMsg] = gitCheck(folder, cmdLog)
    % Check if a git repository is in sync with its remote
    % Only checks status, does not perform any syncing operations
    % cmdLog: optional cell array of git commands run (appended to, returned)
    % statusMsg: message to repeat at end (e.g. 'util\main: in sync with remote.')
    % uncommittedMsg: subtle warning when there are uncommitted changes (or '')
    if nargin < 2; cmdLog = {}; end
    statusMsg = '';
    uncommittedMsg = '';
    
    % Save current backtrace state and turn off for this function
    oldState = warning('query', 'backtrace');
    warning('off', 'backtrace');
    cleanup = onCleanup(@() warning(oldState.state, 'backtrace'));
    
    % Check if it's a git repository
    gitDir = fullfile(folder, '.git');
    if ~exist(gitDir, 'dir')
        warning('Directory is not a git repository. Skipping sync check.');
        return;
    end
    
    % Fetch latest changes from remote
    % Use GIT_TERMINAL_PROMPT=0 to prevent hanging on credential prompts
    % Redirect stderr to capture errors and prevent hanging
    fetchCmd = ['cd ' folder ' && GIT_TERMINAL_PROMPT=0 git fetch origin 2>&1'];
    cmdLog{end+1} = 'GIT_TERMINAL_PROMPT=0 git fetch origin';
    [status, output] = system(fetchCmd);
    if status ~= 0
        % Check if it's a credential/auth error (common when run from MATLAB)
        if contains(output, 'Username') || contains(output, 'credential') || contains(output, 'authentication')
            warning('Git fetch skipped: authentication required (run manually if needed)');
            warning('could not make sure repository is up to date');
        elseif contains(output, 'Could not resolve host') || contains(output, 'Name or service not known') || contains(output, 'network')
            warning('Git fetch skipped: network connectivity issue (host unreachable)');
            warning('Repository sync check skipped due to network error. Will retry on next check.');
        else
            warning('Failed to fetch from remote repository: %s', output);
        end
        return;
    end
    
    % Get current branch name
    revParseCmd = ['cd ' folder ' && git rev-parse --abbrev-ref HEAD'];
    cmdLog{end+1} = 'git rev-parse --abbrev-ref HEAD';
    [status, branchName] = system(revParseCmd);
    if status ~= 0
        warning('Failed to get current branch name');
        return;
    end
    
    branchName = strtrim(branchName);
    
    % Check if branch tracks a remote branch
    trackCmd = ['cd ' folder ' && git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo ""'];
    cmdLog{end+1} = 'git rev-parse --abbrev-ref --symbolic-full-name @{u}';
    [status, trackingBranch] = system(trackCmd);
    if status == 0
        trackingBranch = strtrim(trackingBranch);
        if ~isempty(trackingBranch)
            % Log resolved form for copy-paste (no @{u})
            cmdLog{end} = ['git rev-parse --abbrev-ref --symbolic-full-name ' trackingBranch];
            % Quote ref for shell in case branch name has special characters
            tr = ['''' strrep(trackingBranch, '''', '''\''') ''''];
            countCmd = ['cd ' folder ' && git rev-list --count HEAD..' tr ' 2>/dev/null || echo 0'];
            cmdLog{end+1} = ['git rev-list --count HEAD..' trackingBranch];
            [status, result] = system(countCmd);
            if status == 0
                commitsBehind = str2double(strtrim(result));
                aheadCmd = ['cd ' folder ' && git rev-list --count ' tr '..HEAD 2>/dev/null || echo 0'];
                cmdLog{end+1} = ['git rev-list --count ' trackingBranch '..HEAD'];
                [stA, resA] = system(aheadCmd);
                commitsAhead = (stA == 0) * str2double(strtrim(resA));
            end
        else
            % No tracking branch: try origin/<branch> first (branch may exist on remote), else origin/HEAD
            originBranch = ['origin/' branchName];
            ob = ['''' strrep(originBranch, '''', '''\''') ''''];
            countCmd = ['cd ' folder ' && git rev-list --count HEAD..' ob ' 2>/dev/null || git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0'];
            cmdLog{end+1} = ['git rev-list --count HEAD..' originBranch ' (or origin/HEAD)'];
            [status, result] = system(countCmd);
            if status == 0
                commitsBehind = str2double(strtrim(result));
                aheadCmd = ['cd ' folder ' && git rev-list --count ' ob '..HEAD 2>/dev/null || git rev-list --count origin/HEAD..HEAD 2>/dev/null || echo 0'];
                cmdLog{end+1} = ['git rev-list --count ' originBranch '..HEAD (or origin/HEAD..HEAD)'];
                [stA, resA] = system(aheadCmd);
                commitsAhead = (stA == 0) * str2double(strtrim(resA));
            end
        end
    else
        % Fallback: try origin/HEAD
        countCmd = ['cd ' folder ' && git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0'];
        cmdLog{end+1} = 'git rev-list --count HEAD..origin/HEAD';
        [status, result] = system(countCmd);
        if status == 0
            commitsBehind = str2double(strtrim(result));
            aheadCmd = ['cd ' folder ' && git rev-list --count origin/HEAD..HEAD 2>/dev/null || echo 0'];
            cmdLog{end+1} = 'git rev-list --count origin/HEAD..HEAD';
            [stA, resA] = system(aheadCmd);
            commitsAhead = (stA == 0) * str2double(strtrim(resA));
        end
    end
    
    if status == 0
        if ~exist('commitsAhead', 'var'); commitsAhead = 0; end
        if ~exist('commitsBehind', 'var'); commitsBehind = 0; end
        % If we're about to show "in sync" but branch exists on remote, recheck ahead using origin/branchName
        if commitsBehind == 0 && commitsAhead == 0
            originBranch = ['origin/' branchName];
            ob = ['''' strrep(originBranch, '''', '''\''') ''''];
            recheckCmd = ['cd ' folder ' && git rev-list --count ' ob '..HEAD 2>/dev/null'];
            [stR, resR] = system(recheckCmd);
            if stR == 0
                n = str2double(strtrim(resR));
                if ~isnan(n) && n > 0
                    commitsAhead = n;
                end
            end
        end
        [~, repoName] = fileparts(folder);
        prefix = [repoName '\' branchName ': '];
        if commitsBehind > 0
            statusMsg = ['!!! ' prefix num2str(commitsBehind) ' commit(s) behind remote. !!!'];
            disp('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            disp(statusMsg);
            disp('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        elseif commitsAhead > 0
            statusMsg = [prefix num2str(commitsAhead) ' commit(s) ahead of remote.'];
            disp(statusMsg);
        else
            statusMsg = [prefix 'in sync with remote.'];
            disp(statusMsg);
        end
        % Subtle warning when there are uncommitted local changes
        [stU, outU] = system(['cd ' folder ' && git status --porcelain']);
        if stU == 0 && ~isempty(strtrim(outU))
            uncommittedMsg = '  (uncommitted local changes)';
        end
    end
end

