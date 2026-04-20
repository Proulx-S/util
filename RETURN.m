function RETURN()
% Touches a <script>.done sentinel file, then returns. Use in place of
% bare `return` at exit points so external watchers know the script ended.
st = dbstack('-completenames');
if numel(st) > 1
    sentinelFile = regexprep(st(end).file, '\.m$', '.done');
    system(['touch "' sentinelFile '"']);
end
end
