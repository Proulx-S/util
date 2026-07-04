function saveCache(level)
    % Checkpoint the CALLER's entire workspace to the LEVEL cache file (see
    % cacheFileFor for the path). Restore it later with loadCache(level).
    % Saved with -v7.3 so large variables (>2 GB) are handled.
    cacheFile = cacheFileFor(level);
    fprintf('saveCache(%g): saving workspace -> %s\n', level, cacheFile);
    esc = strrep(cacheFile, '''', '''''');   % escape single quotes for the eval'd string
    evalin('caller', sprintf('save(''%s'', ''-v7.3'');', esc));
    fprintf('saveCache(%g): saved <- %s\n', level, cacheFile);
end
