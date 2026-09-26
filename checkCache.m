function tf = checkCache(level, tag)
    % True when the LEVEL cache for the calling doIt is ABSENT -- i.e. the guarded
    % block must (re)run. Pairs with saveCache/loadCache in the idiom:
    %
    %   if forceThis || checkCache(1)
    %       ... expensive work ...
    %       saveCache(1)
    %   else
    %       loadCache(1)
    %   end
    %
    % Cache path == the caller's file with LEVEL appended (see cacheFileFor).
    % Prints the resolved path and whether the cache was found, so a doIt's
    % console log shows which checkpoint each guarded block hit.
    %
    % Optional TAG (char/string, [A-Za-z0-9_-]+) adds a name component, so one doIt
    % can keep separate caches per variant (e.g. per dataset). Pass the same TAG
    % to all three helpers:
    %
    %   if forceThis || checkCache(1, dataset)     % -> doIt.<dataset>.cache1.mat
    %       ...
    %       saveCache(1, dataset)
    %   else
    %       loadCache(1, dataset)
    %   end
    %
    % Absent or empty TAG gives the untagged name (doIt.cache1.mat) unchanged.
    %
    % Side effect: starts the block stopwatch for LEVEL+TAG (see cacheTimer), so
    % saveCache can report how long the guarded block took -- no tic/toc needed in
    % the doIt. (With the `forceThis || checkCache` short-circuit this runs
    % whenever forceThis is false; to also time forced recomputes, write
    % `checkCache(1) || forceThis` so checkCache is always evaluated.)
    %
    % Called with no argument, checkCache() instead lists the calling doIt's
    % available cache files, tagged and untagged (<name>.cache*.mat and
    % <name>.*.cache*.mat): printed for interactive use, and returned as a string
    % array of full paths (e.g. cacheFiles = checkCache;).
    if nargin < 1
        st = dbstack('-completenames');
        if numel(st) < 2
            error('checkCache:noCaller', ...
                'checkCache must be called from a script or function file, not directly from the command line.');
        end
        [srcDir, srcName] = fileparts(st(2).file);
        files = [dir(fullfile(srcDir, sprintf('%s.cache*.mat', srcName))); ...
                 dir(fullfile(srcDir, sprintf('%s.*.cache*.mat', srcName)))];
        cacheFiles = strings(1, numel(files));
        for k = 1:numel(files)
            cacheFiles(k) = string(fullfile(files(k).folder, files(k).name));
        end
        cacheFiles = unique(cacheFiles, 'stable');
        if isempty(cacheFiles)
            fprintf('checkCache: no cache files found for %s\n', srcName);
        else
            fprintf('checkCache: available cache files for %s:\n', srcName);
            fprintf('  %s\n', cacheFiles);
        end
        tf = cacheFiles;
        return
    end
    if nargin < 2; tag = ''; end
    [cacheFile, label] = cacheFileFor(level, tag);
    tf = ~isfile(cacheFile);
    if tf
        fprintf('checkCache(%s): cache not found, block will run -> %s\n', label, cacheFile);
    else
        fprintf('checkCache(%s): cache found, block skipped -> %s\n', label, cacheFile);
    end
    cacheTimer(level, 'start', tag);
end
