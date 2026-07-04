function saveCache(level)
    % Checkpoint the CALLER's entire workspace to the LEVEL cache file (see
    % cacheFileFor for the path). Restore it later with loadCache(level).
    % Saved with -v7.3 so large variables (>2 GB) are handled. Reports the block's
    % compute time (from checkCache) and the save time, so the doIt needs no
    % tic/toc.
    cacheFile = cacheFileFor(level);
    tComp = cacheTimer(level, 'read');
    if ~isnan(tComp)
        fprintf('saveCache(%g): block computed in %.2f s\n', level, tComp);
    end
    fprintf('saveCache(%g): saving workspace -> %s\n', level, cacheFile);
    esc = strrep(cacheFile, '''', '''''');   % escape single quotes for the eval'd string
    tSave = tic;
    evalin('caller', sprintf('save(''%s'', ''-v7.3'');', esc));
    fprintf('saveCache(%g): saved in %.2f s <- %s\n', level, toc(tSave), cacheFile);
end
