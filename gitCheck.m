function [cmdLog, statusMsg, uncommittedMsg] = gitCheck(folder, cmdLog)
    % Check if a git repository is in sync with its remote.
    % Assumes remote is always origin. Current local branch (e.g. main) is always
    % compared to origin/<same name> (e.g. origin/main). Only checks status; no syncing.
    %
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
            warning('Git fetch skipped: authentication required (could not verify repository is up to date).');
            fprintf(['  To update manually, open a terminal (outside MATLAB) and run:\n' ...
                '    cd %s\n' ...
                '    git fetch origin\n' ...
                '  You may be prompted for your GitHub username and password or token.\n' ...
                '  If you use two-factor authentication, use a personal access token instead of your password.\n'], folder);
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
    
    % Remote is always origin. Compare local branch to origin/<same name>.
    originBranch = ['origin/' branchName];
    ob = ['''' strrep(originBranch, '''', '''\''') ''''];
    [stRemote, ~] = system(['cd ' folder ' && git rev-parse --verify ' ob ' 2>/dev/null']);
    branchIsLocalOnly = (stRemote ~= 0);
    
    if ~branchIsLocalOnly
        % origin/branchName exists: behind = HEAD..origin/branchName, ahead = origin/branchName..HEAD
        countCmd = ['cd ' folder ' && git rev-list --count HEAD..' ob ' 2>/dev/null || echo 0'];
        cmdLog{end+1} = ['git rev-list --count HEAD..' originBranch];
        [status, result] = system(countCmd);
        if status == 0
            commitsBehind = str2double(strtrim(result));
            aheadCmd = ['cd ' folder ' && git rev-list --count ' ob '..HEAD 2>/dev/null || echo 0'];
            cmdLog{end+1} = ['git rev-list --count ' originBranch '..HEAD'];
            [stA, resA] = system(aheadCmd);
            commitsAhead = (stA == 0) * str2double(strtrim(resA));
        end
    end
    
    if status == 0
        if ~exist('commitsAhead', 'var'); commitsAhead = 0; end
        if ~exist('commitsBehind', 'var'); commitsBehind = 0; end
        [~, repoName] = fileparts(folder);
        prefix = [repoName '\' branchName ': '];
        if commitsBehind > 0
            statusMsg = ['!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' newline '!!! ' prefix num2str(commitsBehind) ' commit(s) behind remote. !!!' newline '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'];
            disp(statusMsg);
        elseif commitsAhead > 0
            statusMsg = [prefix num2str(commitsAhead) ' commit(s) ahead of remote.'];
            disp(statusMsg);
        elseif branchIsLocalOnly
            statusMsg = ['  >>> ' prefix 'local only — remember to publish for remote backup.'];
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

