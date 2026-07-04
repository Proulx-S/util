function loadCache(level)
    % Restore the CALLER's workspace from the LEVEL cache file written by
    % saveCache(level) (see cacheFileFor for the path). Every variable stored in
    % the cache is loaded straight into the calling doIt's workspace.
    cacheFile = cacheFileFor(level);
    if ~isfile(cacheFile)
        error('loadCache:missing', 'No level-%g cache to load: %s', level, cacheFile);
    end
    fprintf('loadCache(%g): loading -> %s\n', level, cacheFile);
    esc = strrep(cacheFile, '''', '''''');   % escape single quotes for the eval'd string
    evalin('caller', sprintf('load(''%s'');', esc));
    fprintf('loadCache(%g): loaded <- %s\n', level, cacheFile);
end
