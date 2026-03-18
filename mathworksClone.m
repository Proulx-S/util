function curToolboxDir = mathworksClone(url, folder, forceUpdate)
% Clone or ensure a MathWorks File Exchange (or similar) toolbox is installed.
% Downloads from url, extracts into folder, adds to path.
% If the toolbox already exists at folder, it is left as-is unless forceUpdate is true.
%
% Inputs:
%   url         - URL to the .zip download (e.g. MathWorks File Exchange)
%   folder      - Directory to extract the toolbox into (and add to path)
%   forceUpdate - (optional) If true, re-download and overwrite even if present. Default false.

if ~exist('forceUpdate', 'var')
    forceUpdate = false;
end

disp([newline '--------------------------------']);
curToolboxDir = folder;
zipFile = fullfile(folder, '_mathworks_download.zip');

alreadyInstalled = exist(curToolboxDir, 'dir');
needDownload = ~alreadyInstalled || forceUpdate;

if alreadyInstalled && ~forceUpdate
    disp([url newline 'already installed at:' newline ' ' curToolboxDir]);
else
    if needDownload
        if forceUpdate && alreadyInstalled
            disp('Re-downloading and overwriting toolbox...');
            rmdir(curToolboxDir, 's');
        else
            disp('Downloading toolbox...');
        end
        if ~exist(curToolboxDir, 'dir')
            mkdir(curToolboxDir);
        end
        try
            websave(zipFile, url);
        catch
            if exist(zipFile, 'file')
                delete(zipFile);
            end
            error('mathworksClone:downloadFailed', ...
                'Could not download toolbox. Check your internet connection and URL.');
        end
        unzip(zipFile, curToolboxDir);
        delete(zipFile);
        disp('Toolbox downloaded and extracted.');
    end
end

addpath(genpath(curToolboxDir));
disp(['added to path:' newline ' ' curToolboxDir]);
disp('--------------------------------');
