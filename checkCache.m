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
    tf = ~isfile(cacheFileFor(level));
end
