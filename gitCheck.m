function gitCheck(folder)
    % Check if a git repository is in sync with its remote
    % Only checks status, does not perform any syncing operations
    
    % Check if it's a git repository
    gitDir = fullfile(folder, '.git');
    if ~exist(gitDir, 'dir')
        warning('Directory is not a git repository. Skipping sync check.');
        return;
    end
    
    % Fetch latest changes from remote
    [status, ~] = system(['cd ' folder ' && git fetch origin']);
    if status ~= 0
        warning('Failed to fetch from remote repository');
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

