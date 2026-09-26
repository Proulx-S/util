function loadCache(level, tag)
    % Restore the CALLER's workspace from a cache file. Every variable stored in
    % the cache is loaded straight into the calling doIt's workspace.
    %
    % LEVEL is either:
    %   - numeric, resolved via cacheFileFor(level, tag) to the calling doIt's
    %     level-N cache file (the file written by saveCache(level, tag)), or
    %   - a string/char naming a cache .mat file directly -- e.g. one of the
    %     paths returned by checkCache() -- loaded as-is, no caller resolution
    %     (TAG must then be omitted).
    %
    % Optional TAG (char/string, [A-Za-z0-9_-]+): see checkCache. Absent or empty
    % gives the untagged cache file.
    if nargin < 2; tag = ''; end
    if ischar(level) || isstring(level)
        if ~isempty(tag) && ~(isstring(tag) && isscalar(tag) && strlength(tag) == 0)
            error('loadCache:tagWithPath', 'loadCache(path) takes no TAG: the path already names the file.');
        end
        cacheFile = char(level);
        lbl = 'loadCache';
    else
        [cacheFile, label] = cacheFileFor(level, tag);
        lbl = sprintf('loadCache(%s)', label);
    end
    if ~isfile(cacheFile)
        error('loadCache:missing', '%s: cache not found -> %s', lbl, cacheFile);
    end
    fprintf('%s: cache found, loading -> %s\n', lbl, cacheFile);
    esc = strrep(cacheFile, '''', '''''');   % escape single quotes for the eval'd string
    tLoad = tic;
    evalin('caller', sprintf('load(''%s'');', esc));
    fprintf('%s: loaded in %.2f s <- %s\n', lbl, toc(tLoad), cacheFile);
end
