function tf = checkCache(level)
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
    %
    % Side effect: starts LEVEL's block stopwatch (see cacheTimer), so saveCache
    % can report how long the guarded block took -- no tic/toc needed in the doIt.
    % (With the `forceThis || checkCache` short-circuit this runs whenever
    % forceThis is false; to also time forced recomputes, write `checkCache(1) ||
    % forceThis` so checkCache is always evaluated.)
    %
    % Called with no argument, checkCache() instead lists the calling doIt's
    % available cache files: printed for interactive use, and returned as a
    % string array of full paths (e.g. cacheFiles = checkCache;).
    if nargin < 1
        st = dbstack('-completenames');
        if numel(st) < 2
            error('checkCache:noCaller', ...
                'checkCache must be called from a script or function file, not directly from the command line.');
        end
        [srcDir, srcName] = fileparts(st(2).file);
        files = dir(fullfile(srcDir, sprintf('%s.cache*.mat', srcName)));
        cacheFiles = strings(1, numel(files));
        for k = 1:numel(files)
            cacheFiles(k) = string(fullfile(files(k).folder, files(k).name));
        end
        if isempty(cacheFiles)
            fprintf('checkCache: no cache files found for %s\n', srcName);
        else
            fprintf('checkCache: available cache files for %s:\n', srcName);
            fprintf('  %s\n', cacheFiles);
        end
        tf = cacheFiles;
        return
    end
    tf = ~isfile(cacheFileFor(level));
    cacheTimer(level, 'start');
end
