function loadCache(level)
    % Restore the CALLER's workspace from a cache file. Every variable stored in
    % the cache is loaded straight into the calling doIt's workspace.
    %
    % LEVEL is either:
    %   - numeric, resolved via cacheFileFor(level) to the calling doIt's
    %     level-N cache file (the file written by saveCache(level)), or
    %   - a string/char naming a cache .mat file directly -- e.g. one of the
    %     paths returned by checkCache() -- loaded as-is, no caller resolution.
    if ischar(level) || isstring(level)
        cacheFile = char(level);
        tag = 'loadCache';
    else
        cacheFile = cacheFileFor(level);
        tag = sprintf('loadCache(%g)', level);
    end
    if ~isfile(cacheFile)
        error('loadCache:missing', '%s: cache not found -> %s', tag, cacheFile);
    end
    fprintf('%s: cache found, loading -> %s\n', tag, cacheFile);
    esc = strrep(cacheFile, '''', '''''');   % escape single quotes for the eval'd string
    tLoad = tic;
    evalin('caller', sprintf('load(''%s'');', esc));
    fprintf('%s: loaded in %.2f s <- %s\n', tag, toc(tLoad), cacheFile);
end
