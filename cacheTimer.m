function elapsed = cacheTimer(level, action, tag)
    % Shared per-level stopwatch for the doIt cache helpers, so the doIt itself
    % needs no tic/toc. checkCache starts a level's clock; saveCache reads it to
    % report how long the guarded block took to compute.
    %   cacheTimer(level,'start'[,tag]) -> (re)start the clock for LEVEL (and TAG)
    %   cacheTimer(level,'read'[,tag])  -> seconds since that start (NaN if never started)
    % State is persistent and keyed by level + tag, so nested levels, and the same
    % level under different tags, don't clobber each other. clearvars (top of a
    % doIt) does not wipe it; each 'start' resets it.
    persistent T
    if isempty(T); T = containers.Map('KeyType','char','ValueType','uint64'); end
    if nargin < 3 || isempty(tag); tag = ''; end
    key = sprintf('%.17g|%s', double(level), char(tag));
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
