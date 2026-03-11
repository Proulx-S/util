function gitClone(url, folder, repoSubDir, branch)
    if ~exist('repoSubDir', 'var'); repoSubDir = []; end
    if ~exist('branch', 'var'); branch = []; end
    branch = char(branch);
    if ~isempty(branch)
        branch = strtrim(branch);
        if contains(branch, '''') || contains(branch, ';') || contains(branch, newline)
            error('gitClone:invalidBranch', 'Branch name contains invalid characters.');
        end
    end
    disp([newline '--------------------------------']);
    if exist(fullfile(folder,repoSubDir), 'dir')
        disp([url ' ' repoSubDir newline 'already downloaded to:' newline ' ' folder]);
        
        % Optionally switch to requested branch and update
        if ~isempty(branch)
            [st, out] = system(['cd ' folder ' && GIT_TERMINAL_PROMPT=0 git fetch origin 2>&1']);
            if st == 0
                [st, cur] = system(['cd ' folder ' && git rev-parse --abbrev-ref HEAD']);
                cur = strtrim(cur);
                if st == 0 && ~strcmp(cur, branch)
                    system(['cd ' folder ' && git checkout ' branch ' 2>&1']);
                end
            end
        end
        % Check repository sync status
        gitCheck(folder);
        
    else
        if isempty(repoSubDir)
            cmd = ['git clone ' url ' ' folder];
            if ~isempty(branch)
                cmd = ['git clone -b ' branch ' ' url ' ' folder];
            end
            disp(cmd);
            system(['bash -c ''' cmd '''']);
        else
            cmd1 = ['git clone --filter=blob:none --sparse ' url ' ' folder];
            if ~isempty(branch)
                cmd1 = ['git clone -b ' branch ' --filter=blob:none --sparse ' url ' ' folder];
            end
            cmd2 = ['cd ' folder ' && git sparse-checkout init --no-cone && git sparse-checkout set ' repoSubDir '/** /README* /LICENSE* && git checkout'];
            disp([cmd1 newline cmd2]);
            system(['bash -c ''' cmd1 '''']);
            system(['bash -c ''' cmd2 '''']);
        end
    end
    addpath(genpath(fullfile(folder,repoSubDir)));
    disp(['added to path:' newline ' ' fullfile(folder,repoSubDir)]);
    