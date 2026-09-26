function [cacheFile, label] = cacheFileFor(level, tag)
    % Resolve the cache-file path for the calling doIt (script or function file).
    % Internal helper for checkCache / saveCache / loadCache -- not meant to be
    % called directly. The cache file lives next to the caller's source file, with
    % LEVEL (and an optional TAG) appended to the filename before a .mat extension:
    %   /path/to/doIt.m  +  level 1              ->   /path/to/doIt.cache1.mat
    %   /path/to/doIt.m  +  level 1, tag 'test'  ->   /path/to/doIt.test.cache1.mat
    %
    % LEVEL is threaded through the three public cache functions, so a single doIt
    % can keep several independent checkpoints (doIt.cache1.mat, doIt.cache2.mat,
    % ...). TAG (optional, char/string) keeps further variants apart, e.g. one set
    % of caches per dataset. Absent or empty, the name is exactly the untagged
    % one. A non-empty TAG must be a filename-safe token: [A-Za-z0-9_-]+.
    %
    % LABEL is the call as printed in the helpers' console messages, e.g.
    % "1" or "1, 'test'".
    %
    % The caller is taken from the call stack: st(1)=cacheFileFor, st(2)=one of the
    % public cache functions, st(3)=the doIt that called it. Called from the command
    % line (no source file) there is no st(3), which is an error.
    if nargin < 2; tag = ''; end
    tag = cacheTag(tag);
    st = dbstack('-completenames');
    if numel(st) < 3
        error('cacheFileFor:noCaller', ...
            ['checkCache/saveCache/loadCache must be called from a script or function file, ' ...
             'not directly from the command line.']);
    end
    [srcDir, srcName] = fileparts(st(3).file);
    if isempty(tag)
        cacheFile = fullfile(srcDir, sprintf('%s.cache%g.mat', srcName, level));
        label = sprintf('%g', level);
    else
        cacheFile = fullfile(srcDir, sprintf('%s.%s.cache%g.mat', srcName, tag, level));
        label = sprintf('%g, ''%s''', level, tag);
    end
end

function tag = cacheTag(tag)
    % Normalise TAG to char ('' when absent/empty) and check it is filename-safe.
    if isempty(tag) || (isstring(tag) && isscalar(tag) && strlength(tag) == 0)
        tag = '';   % [], '', "" -> untagged
        return
    end
    if ~((ischar(tag) && isrow(tag)) || (isstring(tag) && isscalar(tag)))
        error('cacheFileFor:badTag', 'Cache TAG must be a char row vector or string scalar.');
    end
    tag = char(tag);
    if isempty(regexp(tag, '^[A-Za-z0-9_-]+$', 'once'))
        error('cacheFileFor:badTag', ...
            'Cache TAG ''%s'' is not filename-safe: use only letters, digits, _ and -.', tag);
    end
end
