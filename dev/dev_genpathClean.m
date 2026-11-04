function dev_genpathClean
% DEV_GENPATHCLEAN  Test genpathClean: which folders of a tool end up on a project's path.
%
%   Run from a util worktree, in one plain command:
%     /home/sebp/MATLAB/R2025a/bin/matlab -batch "addpath dev; dev_genpathClean"
%
% Builds a throwaway tree in <util>/scratch/gpc_<stamp>/ (gitignored) and checks that genpathClean
% keeps ordinary subfolders and drops '.'-prefixed ones, 'scratch' and 'dev' (at any depth below the
% root), while components of the root itself are never inspected. Deletes nothing.
    utilDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(utilDir);
    if ~exist(fullfile(utilDir, 'scratch'), 'dir'); error('dev:noScratch', 'No scratch/ in %s.', utilDir); end
    % the root itself is under a folder named 'dev' and 'scratch': must not matter
    R = fullfile(utilDir, 'scratch', ['gpc_' char(datetime('now','Format','yyyyMMdd_HHmmss'))], 'dev', 'tool');
    keepDirs = {'', 'sub', 'sub/deeper', 'developer', 'devTools', 'private2'};
    dropDirs = {'.git', '.claude/worktrees/x', 'scratch', 'scratch/a', 'dev', 'dev/a', 'sub/dev', 'sub/.hidden'};
    for d = [keepDirs dropDirs]; mkdir(fullfile(R, d{1})); end
    parts = strsplit(genpathClean(R), pathsep);
    nFail = 0;
    for d = keepDirs
        nFail = nFail + report(any(strcmp(parts, fullfile(R, d{1}))), ['kept    ' disp_(d{1})]);
    end
    for d = dropDirs
        nFail = nFail + report(~any(strcmp(parts, fullfile(R, d{1}))), ['dropped ' disp_(d{1})]);
    end
    fprintf('\n==== %d checks, %d failed ====\nsandbox: %s\n', numel(keepDirs) + numel(dropDirs), nFail, R);
    if nFail; error('dev_genpathClean:failed', '%d check(s) failed', nFail); end
end

function f = report(ok, what)
    if ok; fprintf('  PASS  %s\n', what); f = 0; else; fprintf('  FAIL  %s\n', what); f = 1; end
end

function s = disp_(d)
    if isempty(d); s = '<root>'; else; s = d; end
end
