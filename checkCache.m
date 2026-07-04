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
    tf = ~isfile(cacheFileFor(level));
    cacheTimer(level, 'start');
end
