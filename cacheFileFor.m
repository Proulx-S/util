function cacheFile = cacheFileFor(level)
    % Resolve the cache-file path for the calling doIt (script or function file).
    % Internal helper for checkCache / saveCache / loadCache -- not meant to be
    % called directly. The cache file lives next to the caller's source file, with
    % LEVEL appended to the filename before a .mat extension:
    %   /path/to/doIt.m  +  level 1   ->   /path/to/doIt.cache1.mat
    %
    % LEVEL is the (first and only) argument threaded through the three public
    % cache functions, so a single doIt can keep several independent checkpoints
    % (doIt.cache1.mat, doIt.cache2.mat, ...).
    %
    % The caller is taken from the call stack: st(1)=cacheFileFor, st(2)=one of the
    % public cache functions, st(3)=the doIt that called it. Called from the command
    % line (no source file) there is no st(3), which is an error.
    st = dbstack('-completenames');
    if numel(st) < 3
        error('cacheFileFor:noCaller', ...
            ['checkCache/saveCache/loadCache must be called from a script or function file, ' ...
             'not directly from the command line.']);
    end
    [srcDir, srcName] = fileparts(st(3).file);
    cacheFile = fullfile(srcDir, sprintf('%s.cache%g.mat', srcName, level));
end
