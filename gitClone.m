function gitClone(url, folder, repoSubDir)
    if ~exist('repoSubDir', 'var'); repoSubDir = []; end

    if exist(fullfile(folder,repoSubDir), 'dir')
        disp([newline url ' ' repoSubDir newline 'already downloaded to:' newline ' ' folder newline]);
        
        % Check repository sync status
        gitCheck(folder);
        
    else
        cmd = {};
        if isempty(repoSubDir)
            cmd{end+1} = ['git clone ' url ' ' folder];
        else
            cmd{end+1} = ['git clone --filter=blob:none --sparse ' url ' ' folder];
            cmd{end+1} = ['cd ' folder];
            cmd{end+1} = ['git sparse-checkout init --no-cone'];
            cmd{end+1} = ['git sparse-checkout set ' repoSubDir '/** /README* /LICENSE*'];
            cmd{end+1} = ['git checkout'];
        end
        disp(strjoin(cmd,newline));
        system(strjoin(cmd,newline));
    end
    addpath(genpath(fullfile(folder,repoSubDir)));
    disp(['added to path:' newline ' ' fullfile(folder,repoSubDir)]);
    