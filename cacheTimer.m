function elapsed = cacheTimer(level, action)
    % Shared per-level stopwatch for the doIt cache helpers, so the doIt itself
    % needs no tic/toc. checkCache starts a level's clock; saveCache reads it to
    % report how long the guarded block took to compute.
    %   cacheTimer(level,'start') -> (re)start the clock for LEVEL
    %   cacheTimer(level,'read')  -> seconds since that start (NaN if never started)
    % State is persistent and keyed by level, so nested levels don't clobber each
    % other. clearvars (top of a doIt) does not wipe it; each 'start' resets it.
    persistent T
    if isempty(T); T = containers.Map('KeyType','double','ValueType','uint64'); end
    key = double(level);
    elapsed = NaN;
    switch action
        case 'start'
            T(key) = tic;
            elapsed = 0;
        case 'read'
            if isKey(T, key); elapsed = toc(T(key)); end
        otherwise
            error('cacheTimer:action', 'action must be ''start'' or ''read''.');
    end
end
