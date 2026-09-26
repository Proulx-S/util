function saveCache(level, tag)
    % Checkpoint the CALLER's workspace to the LEVEL cache file (see
    % cacheFileFor for the path). Restore it later with loadCache(level).
    % Optional TAG (char/string, [A-Za-z0-9_-]+) selects a tagged cache file,
    % <doIt>.<tag>.cache<level>.mat; restore it with loadCache(level, tag). See
    % checkCache. Absent or empty TAG gives the untagged file.
    % Saved with -v7.3 so large variables (>2 GB) are handled. Reports the block's
    % compute time (from checkCache) and the save time, so the doIt needs no
    % tic/toc.
    %
    % Graphics handles are SKIPPED: any variable that is a matlab.graphics.Graphics
    % object (figure, axes, line, image, legend, colorbar, tiledlayout, uifigure,
    % uibutton, ...), an array of them, or a cell/struct holding nothing but such
    % objects. Saving a handle serialises the whole figure behind it -- slow to
    % save and slow to load -- and a doIt never needs one to resume. Skipped
    % names are listed. A cell/struct that mixes handles with data is saved as-is.
    if nargin < 2; tag = ''; end
    [cacheFile, label] = cacheFileFor(level, tag);
    tComp = cacheTimer(level, 'read', tag);
    if ~isnan(tComp)
        fprintf('saveCache(%s): block computed in %.2f s\n', label, tComp);
    end

    % Gather the caller's variables into a struct (copy-on-write: no duplication),
    % leaving graphics handles out, then save the struct's fields as variables.
    names = evalin('caller', 'who');
    S = struct();
    skipped = {};
    for k = 1:numel(names)
        x = evalin('caller', names{k});
        if isGraphicsOnly(x)
            skipped{end+1} = names{k}; %#ok<AGROW>
        else
            S.(names{k}) = x;
        end
    end
    if ~isempty(skipped)
        fprintf('saveCache(%s): skipping %d graphics handle var(s): %s\n', ...
            label, numel(skipped), strjoin(skipped, ', '));
    end

    fprintf('saveCache(%s): saving workspace -> %s\n', label, cacheFile);
    tSave = tic;
    save(cacheFile, '-v7.3', '-struct', 'S');
    fprintf('saveCache(%s): saved in %.2f s <- %s\n', label, toc(tSave), cacheFile);
end

function tf = isGraphicsOnly(x)
    % True when x holds nothing but graphics objects: a Graphics object or array
    % of them (gobjects placeholders included), or a non-empty cell/struct whose
    % every element/field is itself graphics-only.
    if isa(x, 'matlab.graphics.Graphics')
        tf = true;
    elseif iscell(x)
        tf = ~isempty(x) && all(cellfun(@isGraphicsOnly, x(:)));
    elseif isstruct(x)
        fn = fieldnames(x);
        tf = ~isempty(x) && ~isempty(fn);
        for i = 1:numel(fn)
            if ~tf; break; end
            tf = all(arrayfun(@(e) isGraphicsOnly(e.(fn{i})), x(:)));
        end
    else
        tf = false;
    end
end
