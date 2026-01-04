function gitCheck(folder)
    % Check if a git repository is in sync with its remote
    % Only checks status, does not perform any syncing operations
    
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
    [status, output] = system(['cd ' folder ' && GIT_TERMINAL_PROMPT=0 git fetch origin 2>&1']);
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
    [status, branchName] = system(['cd ' folder ' && git rev-parse --abbrev-ref HEAD']);
    if status ~= 0
        warning('Failed to get current branch name');
        return;
    end
    
    branchName = strtrim(branchName);
    
    % Check if branch tracks a remote branch
    [status, trackingBranch] = system(['cd ' folder ' && git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo ""']);
    if status == 0
        trackingBranch = strtrim(trackingBranch);
        if ~isempty(trackingBranch)
            % Compare local vs remote tracking branch
            [status, result] = system(['cd ' folder ' && git rev-list --count HEAD..@{u} 2>/dev/null || echo 0']);
        else
            % No tracking branch, try origin/HEAD or origin/main/master
            [status, result] = system(['cd ' folder ' && git rev-list --count HEAD..origin/' branchName ' 2>/dev/null || git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0']);
        end
    else
        % Fallback: try origin/HEAD
        [status, result] = system(['cd ' folder ' && git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0']);
    end
    
    if status == 0
        commitsBehind = str2double(strtrim(result));
        if commitsBehind > 0
            disp(['Repository is ' num2str(commitsBehind) ' commit(s) behind remote.']);
        else
            disp('Repository is up to date with remote.');
        end
    end
end

