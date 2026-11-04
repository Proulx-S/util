function test_gitToolWrappers(utilDir)
% TEST_GITTOOLWRAPPERS  Headless test of gitToolShared / gitToolDev (D14) against throwaway repos.
%
%   Lives on util's dev-gitTool branch (the branch, not a subfolder, keeps it out of main).
%   Run from a util WORKTREE on that branch (not the shared clone), in one plain command:
%     /home/sebp/MATLAB/R2025a/bin/matlab -batch "test_gitToolWrappers"
%
% utilDir: the util copy under test (default: this file's folder). Each run creates a fresh
% sandbox <utilDir>/scratch/d14test_<stamp>/ (gitignored) with a bare origin over file://, so
% nothing is pushed to util's remote. It deletes nothing. Prints PASS/FAIL per check and a total.
    if nargin < 1 || isempty(utilDir); utilDir = fileparts(mfilename('fullpath')); end
    restoredefaultpath; addpath(utilDir);
    R = fullfile(utilDir, 'scratch', ['d14test_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
    if ~exist(fullfile(utilDir, 'scratch'), 'dir'); error('dev:noScratch', 'No scratch/ in %s.', utilDir); end
    mkdir(R);
    setenv('BASS_ROOT', R);              % so the default toolsDir points into the sandbox
    url  = ['file://' R '/origin.git'];

    % ---------- fixtures ----------
    sh(['git init -q --bare -b main ' R '/origin.git']);
    sh(['git clone -q ' url ' ' R '/seed']);
    writeFn(R, 'seed', 'toyFn', 'shared-v1');
    sh(['cd ' R '/seed && git add -A && git commit -qm v1 && git push -q origin main']);
    pushSeed = @(br, tag) sh(['cd ' R '/seed && git switch -q ' br ' && echo ' tag ' >> log.txt && git add -A && git commit -qm ' tag ' && git push -q origin ' br]);
    for d = {'tools','s3/tools','s4/tools','s5/tools','s6/tools','s7/tools','proj','proj2','proj3','proj4','proj5','proj6'}
        mkdir(fullfile(R, d{1}));
    end
    for pj = {'proj','proj3','proj4','proj5','proj6'}
        sh(['cd ' R '/' pj{1} ' && git init -q && printf "devTools/toyTool/\n" > .gitignore']);
    end
    sh(['cd ' R '/proj2 && git init -q']);   % NOT ignoring devTools/
    o  = struct('url', url);
    oT = @(sub) struct('url', url, 'toolsDir', fullfile(R, sub, 'tools'));
    shared = fullfile(R, 'tools', 'toyTool');

    % ================= MODE 1: gitToolShared =================
    hdr('S0 no-arg call returns default opts');
    d = gitToolShared(); check(isstruct(d) && all(isfield(d, {'url','toolsDir','subDir'})), 'defaults struct');

    hdr('S1 missing -> clone main, on path');
    f = gitToolShared('toyTool', o);
    check(strcmp(f, shared), 'returned folder'); check(strcmp(br(f), 'main'), 'on main');
    check(startsWith(which('toyFn'), shared), 'toyFn from shared');

    hdr('S2 remote advanced -> fast-forward');
    pushSeed('main', 'v2'); gitToolShared('toyTool', o);
    check(strcmp(rev(f, 'HEAD'), rev(f, 'origin/main')), 'HEAD == origin/main');

    hdr('S3 dirty tracked file -> warn, no ff');
    g = fullfile(R, 's3', 'tools', 'toyTool'); gitToolShared('toyTool', oT('s3'));
    sh(['echo edit >> ' g '/toyFn.m']); pushSeed('main', 'v3');
    h0 = rev(g, 'HEAD'); out = evalc('gitToolShared(''toyTool'', oT(''s3''))');
    check(strcmp(rev(g, 'HEAD'), h0) && contains(out, 'uncommitted changes'), 'not ff, warned');
    check(contains(fileread([g '/toyFn.m']), 'edit'), 'edit kept');

    hdr('S4 on another branch -> warn, left on it');
    g = fullfile(R, 's4', 'tools', 'toyTool'); gitToolShared('toyTool', oT('s4'));
    sh(['git -C ' g ' switch -q -c dev-legacyPin']);
    out = evalc('gitToolShared(''toyTool'', oT(''s4''))');
    check(strcmp(br(g), 'dev-legacyPin') && contains(out, 'not main'), 'still dev-legacyPin, warned');

    hdr('S5 folder exists, not a repo -> warn, untouched, on path');
    g = fullfile(R, 's5', 'tools', 'toyTool'); mkdir(g); writeFile([g '/plainFn.m'], 'function plainFn; end');
    out = evalc('gitToolShared(''toyTool'', oT(''s5''))');
    check(contains(out, 'NOT a git repository') && ~exist([g '/.git'], 'dir'), 'warned, no .git created');
    check(startsWith(which('plainFn'), g), 'on path');

    hdr('S6 offline -> warn, local main used');
    sh(['git clone -q --bare ' R '/origin.git ' R '/offline.git']);
    oOff = struct('url', ['file://' R '/offline.git'], 'toolsDir', fullfile(R, 's6', 'tools'));
    gitToolShared('toyTool', oOff); sh(['chmod 000 ' R '/offline.git']);
    out = evalc('gitToolShared(''toyTool'', oOff)'); sh(['chmod 755 ' R '/offline.git']);
    check(contains(out, 'git fetch failed'), 'offline warned');

    hdr('S7 diverged -> warn, left as is');
    g = fullfile(R, 's7', 'tools', 'toyTool'); gitToolShared('toyTool', oT('s7'));
    sh(['cd ' g ' && echo local >> local.txt && git add -A && git commit -qm local']); pushSeed('main', 'v4');
    h0 = rev(g, 'HEAD'); out = evalc('gitToolShared(''toyTool'', oT(''s7''))');
    check(strcmp(rev(g, 'HEAD'), h0) && contains(out, 'Could not fast-forward'), 'diverged warned, HEAD kept');

    hdr('S8 refusals (no fs/git action)');
    refuse(@() gitToolShared('a/b', o), 'gitTool:badTool');
    refuse(@() gitToolShared('', o), 'gitTool:badTool');
    refuse(@() gitToolShared('..', o), 'gitTool:badTool');
    refuse(@() gitToolShared('toyTool', struct('url', url, 'toolsDir', '/')), 'gitTool:badDir');
    refuse(@() gitToolShared('toyTool', struct('url', url, 'toolsDir', '')), '');   % '' = default: allowed
    refuse(@() gitToolShared('toyTool', struct('url', url, 'toolsDir', R)), 'gitToolShared:badToolsDir');
    refuse(@() gitToolShared('toyTool', struct('url', url, 'subDir', '../x')), 'gitTool:badSubDir');
    refuse(@() gitToolShared('toyTool', struct('bogus', 1)), 'gitTool:badOpts');

    % ================= MODE 2: gitToolDev =================
    gitToolShared('toyTool', o);    % shared copy on the path first, as a doIt would have it
    P = fullfile(R, 'proj'); dv = fullfile(P, 'devTools', 'toyTool');

    hdr('D0 no-arg call returns default opts');
    d = gitToolDev(); check(isstruct(d) && isfield(d, 'url'), 'defaults struct');

    hdr('D1 missing, branch not on remote -> clone, create from main, push -u; shared off path');
    f = gitToolDev('toyTool', 'dev-proj-feat', P, o);
    check(strcmp(f, dv) && strcmp(br(dv), 'dev-proj-feat'), 'on dev-proj-feat');
    check(~isempty(sh(['git ls-remote --heads ' url ' dev-proj-feat'])), 'branch on remote');
    check(strcmp(sh(['git -C ' dv ' rev-parse --abbrev-ref @{u}']), 'origin/dev-proj-feat'), 'tracking set');
    check(startsWith(which('toyFn'), dv), 'toyFn from dev clone');
    check(~contains(path, shared), 'shared clone off the path');

    hdr('D2 rerun, nothing to do');
    out = evalc('gitToolDev(''toyTool'', ''dev-proj-feat'', P, o)');
    check(~contains(out, '!!!'), 'no warnings');

    hdr('D3 remote branch advanced, clean -> ff');
    sh(['cd ' R '/seed && git fetch -q && git switch -q -c dev-proj-feat --track origin/dev-proj-feat']);
    pushSeed('dev-proj-feat', 'f1'); gitToolDev('toyTool', 'dev-proj-feat', P, o);
    check(strcmp(rev(dv, 'HEAD'), rev(dv, 'origin/dev-proj-feat')), 'HEAD == origin/dev-proj-feat');

    hdr('D4 dirty + remote advanced -> no ff, edit kept');
    sh(['echo devedit >> ' dv '/toyFn.m']); pushSeed('dev-proj-feat', 'f2');
    h0 = rev(dv, 'HEAD'); out = evalc('gitToolDev(''toyTool'', ''dev-proj-feat'', P, o)');
    check(strcmp(rev(dv, 'HEAD'), h0) && contains(out, 'not fast-forwarded'), 'not ff');
    check(contains(fileread([dv '/toyFn.m']), 'devedit'), 'edit kept');

    hdr('D5 diverged (local commit + remote commit) -> warn, kept');
    sh(['cd ' dv ' && git commit -qam devcommit']);
    h0 = rev(dv, 'HEAD'); out = evalc('gitToolDev(''toyTool'', ''dev-proj-feat'', P, o)');
    check(strcmp(rev(dv, 'HEAD'), h0) && contains(out, 'DIVERGED'), 'diverged warned, commit kept');

    hdr('D6 unpushed commit only -> noted, not pushed');
    P5 = fullfile(R, 'proj5'); d5 = fullfile(P5, 'devTools', 'toyTool');
    gitToolDev('toyTool', 'dev-proj5-x', P5, o);
    sh(['cd ' d5 ' && echo a >> a.txt && git add -A && git commit -qm a']);
    out = evalc('gitToolDev(''toyTool'', ''dev-proj5-x'', P5, o)');
    check(contains(out, 'unpushed') && ~strcmp(rev(d5, 'HEAD'), rev(d5, 'origin/dev-proj5-x')), 'noted, not pushed');

    hdr('D7 branch already on remote, fresh clone -> tracks it');
    P3 = fullfile(R, 'proj3'); d3 = fullfile(P3, 'devTools', 'toyTool');
    gitToolDev('toyTool', 'dev-proj-feat', P3, o);
    check(strcmp(rev(d3, 'HEAD'), rev(d3, 'origin/dev-proj-feat')), 'at origin/dev-proj-feat');

    hdr('D8 clean, on another branch -> switch');
    sh(['git -C ' d3 ' switch -q main']);
    gitToolDev('toyTool', 'dev-proj-feat', P3, o); check(strcmp(br(d3), 'dev-proj-feat'), 'switched back');

    hdr('D9 dirty on another branch -> ERROR, left alone');
    sh(['git -C ' d3 ' switch -q main']); sh(['echo x >> ' d3 '/toyFn.m']);
    refuse(@() gitToolDev('toyTool', 'dev-proj-feat', P3, o), 'gitToolDev:dirtyOtherBranch');
    check(strcmp(br(d3), 'main') && contains(fileread([d3 '/toyFn.m']), 'x'), 'still main, edit kept');

    hdr('D10 detached -> ERROR');
    P4 = fullfile(R, 'proj4'); d4 = fullfile(P4, 'devTools', 'toyTool');
    gitToolDev('toyTool', 'dev-proj-feat', P4, o); sh(['git -C ' d4 ' switch -q --detach HEAD~1']);
    refuse(@() gitToolDev('toyTool', 'dev-proj-feat', P4, o), 'gitToolDev:detached');

    hdr('D11 folder exists, not a repo (legacy getClone copy) -> ERROR, untouched');
    P6 = fullfile(R, 'proj6'); d6 = fullfile(P6, 'devTools', 'toyTool'); mkdir(d6);
    writeFile([d6 '/legacy.m'], 'function legacy; end');
    refuse(@() gitToolDev('toyTool', 'dev-proj6-x', P6, o), 'gitToolDev:notRepo');
    check(exist([d6 '/legacy.m'], 'file') && ~exist([d6 '/.git'], 'dir'), 'untouched');

    hdr('D12 project does not ignore devTools/<tool>/ -> warn');
    out = evalc('gitToolDev(''toyTool'', ''dev-proj2-x'', fullfile(R,''proj2''), o)');
    check(contains(out, 'NOT gitignored'), 'warned');

    hdr('D13 offline, new branch -> created locally from origin/main, warned; push on rerun');
    sh(['chmod 000 ' R '/origin.git']);
    out = evalc('gitToolDev(''toyTool'', ''dev-proj5-offline'', P5, o)'); sh(['chmod 755 ' R '/origin.git']);
    check(strcmp(br(d5), 'dev-proj5-offline') && contains(out, 'git fetch failed') && contains(out, 'local only'), 'created locally, warned');
    gitToolDev('toyTool', 'dev-proj5-offline', P5, o);
    check(~isempty(sh(['git ls-remote --heads ' url ' dev-proj5-offline'])), 'pushed on rerun');

    hdr('D14 refusals (no fs/git action)');
    refuse(@() gitToolDev('toyTool', 'dev-p-x', '', o), 'gitTool:badDir');
    refuse(@() gitToolDev('toyTool', 'dev-p-x', '/', o), 'gitTool:badDir');
    refuse(@() gitToolDev('toyTool', 'dev-p-x', fullfile(R, 'nope'), o), 'gitTool:badDir');
    refuse(@() gitToolDev('a/b', 'dev-p-x', P, o), 'gitTool:badTool');
    refuse(@() gitToolDev('toyTool', 'main', P, o), 'gitToolDev:badBranch');
    refuse(@() gitToolDev('toyTool', 'dev-', P, o), 'gitToolDev:badBranch');
    refuse(@() gitToolDev('toyTool', 'dev-p-x;rm', P, o), 'gitToolDev:badBranch');
    refuse(@() gitToolDev('toyTool', 'dev-p..x', P, o), 'gitToolDev:badBranch');
    refuse(@() gitToolDev('toyTool', 'dev-p-x'), 'gitToolDev:nargin');
    check(~exist(fullfile(R, 'devTools'), 'dir') && ~exist('/devTools', 'dir'), 'no stray devTools created');

    [nPass, nFail] = check('report');
    fprintf('\n==== %d passed, %d failed ====\nsandbox: %s\n', nPass, nFail, R);
end

function [np, nf] = check(ok, what)
    persistent nP nF
    if isempty(nP); nP = 0; nF = 0; end
    if ischar(ok); np = nP; nf = nF; return; end
    if ok; nP = nP + 1; fprintf('  PASS  %s\n', what);
    else;  nF = nF + 1; fprintf('  FAIL  %s\n', what); end
end
function refuse(fn, id)
    try
        evalc('fn()');
        check(isempty(id), ['no error (expected ' id ')']);
    catch e
        check(strcmp(e.identifier, id), ['refused with ' e.identifier ' (expected ' id '): ' strtok(e.message, newline)]);
    end
end

function hdr(s); fprintf('\n## %s\n', s); end
function out = sh(cmd)
    [st, out] = system(cmd); out = strtrim(out);
    if st ~= 0; error('test:sh', 'fixture command failed: %s\n%s', cmd, out); end
end
function b = br(d); b = sh(['git -C ' d ' rev-parse --abbrev-ref HEAD']); end
function r = rev(d, ref); r = sh(['git -C ' d ' rev-parse ' ref]); end
function writeFile(p, s); fid = fopen(p, 'w'); fprintf(fid, '%s\n', s); fclose(fid); end
function writeFn(R, sub, name, tag)
    writeFile(fullfile(R, sub, [name '.m']), sprintf('function s = %s; s = ''%s''; end', name, tag));
end
