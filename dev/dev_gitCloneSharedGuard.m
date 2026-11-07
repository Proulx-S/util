function dev_gitCloneSharedGuard
% DEV_GITCLONESHAREDGUARD  Test gitClone's shared-clone guard on throwaway repos.
%
%   Run from a util worktree, in one plain command:
%     /home/sebp/MATLAB/R2025a/bin/matlab -batch "addpath dev; dev_gitCloneSharedGuard"
%
% Builds <util>/scratch/gcg_<stamp>/ (gitignored): two bare "remotes" (one with default branch main
% and a branch feature, one with default dev), a fake BASS_ROOT whose tools/ holds shared clones, and
% a fake project. BASS_ROOT is pointed at the sandbox for the test and restored after. The real
% /scratch/bass/tools is never touched. Deletes nothing.
    utilDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(utilDir);
    if ~exist(fullfile(utilDir, 'scratch'), 'dir'); error('dev:noScratch', 'No scratch/ in %s.', utilDir); end
    S = fullfile(utilDir, 'scratch', ['gcg_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
    tools = fullfile(S, 'bass', 'tools'); proj = fullfile(S, 'proj');
    mkdir(tools); mkdir(fullfile(proj, 'devTools'));
    oldRoot = getenv('BASS_ROOT'); oldDir = pwd;
    cleanup = onCleanup(@() restore(oldRoot, oldDir));
    setenv('BASS_ROOT', fullfile(S, 'bass'));

    urlA = makeRemote(S, 'toolA', 'main', {'feature'});
    urlB = makeRemote(S, 'toolB', 'dev',  {'main'});
    A = fullfile(tools, 'toolA'); B = fullfile(tools, 'toolB');
    sh(['git clone -q ' urlA ' ' A]); sh(['git clone -q ' urlB ' ' B]);
    nFail = 0;

    % 1. shared clone, non-default branch -> error, nothing changed
    nFail = nFail + expectErr(@() gitClone(urlA, A, [], 'feature'), 'gitClone:sharedCloneBranch', ...
        'shared clone, branch feature -> refused');
    nFail = nFail + check(strcmp(head(A), 'main'), '  ... and toolA still on main');
    % 2. empty branch and the default branch -> fine
    nFail = nFail + expectOk(@() gitClone(urlA, A), 'shared clone, no branch -> ok');
    nFail = nFail + expectOk(@() gitClone(urlA, A, [], 'main'), 'shared clone, branch main (default) -> ok');
    % 3. fast-forward still happens on a clean shared clone
    pushCommit(S, 'toolA', 'main', 'ff.txt');
    gitClone(urlA, A);
    nFail = nFail + check(exist(fullfile(A, 'ff.txt'), 'file') == 2, 'clean shared clone is fast-forwarded');
    % 4. a remote whose default is dev
    nFail = nFail + expectOk(@() gitClone(urlB, B, [], 'dev'), 'default dev: branch dev -> ok');
    nFail = nFail + expectErr(@() gitClone(urlB, B, [], 'main'), 'gitClone:sharedCloneBranch', ...
        'default dev: branch main -> refused');
    % 5. relative path and symlinked path are recognised
    cd(tools);
    nFail = nFail + expectErr(@() gitClone(urlA, 'toolA', [], 'feature'), 'gitClone:sharedCloneBranch', ...
        'relative path to a shared clone -> refused');
    cd(oldDir);
    sh(['ln -s ' tools ' ' fullfile(S, 'toolsLink')]);
    nFail = nFail + expectErr(@() gitClone(urlA, fullfile(S, 'toolsLink', 'toolA'), [], 'feature'), ...
        'gitClone:sharedCloneBranch', 'symlinked path to a shared clone -> refused');
    % 6. missing shared clone with a branch -> refused, no folder created; without -> cloned on default
    C = fullfile(tools, 'toolC');
    nFail = nFail + expectErr(@() gitClone(urlA, C, [], 'feature'), 'gitClone:sharedCloneBranch', ...
        'missing shared clone, branch feature -> refused');
    nFail = nFail + check(~exist(C, 'dir'), '  ... and no folder created');
    gitClone(urlA, C);
    nFail = nFail + check(strcmp(head(C), 'main'), 'missing shared clone, no branch -> cloned on main');
    % 7. shared clone already off its default -> error both ways, never switched back
    sh(['git -C ' A ' checkout -q feature']);
    nFail = nFail + expectErr(@() gitClone(urlA, A, [], 'main'), 'gitClone:sharedCloneOffDefault', ...
        'shared clone on feature, branch main -> refused');
    nFail = nFail + expectErr(@() gitClone(urlA, A), 'gitClone:sharedCloneOffDefault', ...
        'shared clone on feature, no branch -> refused');
    nFail = nFail + check(strcmp(head(A), 'feature'), '  ... and toolA left on feature');
    sh(['git -C ' A ' checkout -q main']);
    % 8. dirty shared clone -> not stashed, not fast-forwarded, still on the path
    fid = fopen(fullfile(A, 'README.md'), 'a'); fprintf(fid, 'local edit\n'); fclose(fid);
    pushCommit(S, 'toolA', 'main', 'ff2.txt');
    nFail = nFail + expectOk(@() gitClone(urlA, A), 'dirty shared clone -> no error');
    [~, stash] = system(['git -C ' A ' stash list']);
    nFail = nFail + check(isempty(strtrim(stash)), '  ... no stash created');
    nFail = nFail + check(~exist(fullfile(A, 'ff2.txt'), 'file'), '  ... not fast-forwarded');
    nFail = nFail + check(contains(fileread(fullfile(A, 'README.md')), 'local edit'), '  ... edit kept');
    nFail = nFail + check(contains(path, A), '  ... still added to the path');
    sh(['git -C ' A ' checkout -q -- README.md']);
    % 9. offline: cached origin/HEAD is used; without it, refused
    sh(['git -C ' B ' remote set-url origin ' fullfile(S, 'nowhere.git')]);
    nFail = nFail + expectOk(@() gitClone(urlB, B), 'offline, cached origin/HEAD -> ok');
    nFail = nFail + expectErr(@() gitClone(urlB, B, [], 'main'), 'gitClone:sharedCloneBranch', ...
        'offline, branch main -> refused');
    sh(['git -C ' B ' remote set-head origin -d']);
    nFail = nFail + expectErr(@() gitClone(urlB, B), 'gitClone:sharedCloneDefaultUnknown', ...
        'offline, no origin/HEAD -> refused');
    % 10. project-local clone: unchanged behaviour (checks the branch out)
    P = fullfile(proj, 'devTools', 'toolA');
    gitClone(urlA, P, [], 'feature');
    nFail = nFail + check(strcmp(head(P), 'feature'), 'project devTools clone, branch feature -> checked out');
    % 11. a folder elsewhere (stand-in for a Mac path) is not guarded
    O = fullfile(S, 'Users', 'sebp', 'tools', 'toolA');
    mkdir(fileparts(O)); gitClone(urlA, O, [], 'feature');
    nFail = nFail + check(strcmp(head(O), 'feature'), 'folder outside $BASS_ROOT/tools -> not guarded');

    fprintf('\n==== %d failed ====\nsandbox: %s\n', nFail, S);
    if nFail; error('dev_gitCloneSharedGuard:failed', '%d check(s) failed', nFail); end
end

function url = makeRemote(S, name, defaultBranch, others)
    url = fullfile(S, 'remotes', [name '.git']); seed = fullfile(S, 'seeds', name);
    mkdir(seed);
    sh(['git init -q -b ' defaultBranch ' ' seed]);
    sh(['cd ' seed ' && echo hello > README.md && git add README.md && git -c user.email=t@t -c user.name=t commit -q -m init']);
    for k = 1:numel(others)
        sh(['cd ' seed ' && git branch ' others{k}]);
    end
    sh(['git clone -q --bare ' seed ' ' url]);
end

function pushCommit(S, name, branch, file)
    seed = fullfile(S, 'seeds', name);
    sh(['cd ' seed ' && git checkout -q ' branch ' && echo x > ' file ' && git add ' file ...
        ' && git -c user.email=t@t -c user.name=t commit -q -m ' file ' && git push -q ' ...
        fullfile(S, 'remotes', [name '.git']) ' ' branch]);
end

function b = head(d)
    [~, b] = system(['git -C ' d ' symbolic-ref --short HEAD']); b = strtrim(b);
end

function sh(cmd)
    [st, out] = system(cmd);
    if st ~= 0; error('dev:sh', 'command failed: %s\n%s', cmd, out); end
end

function f = expectErr(fn, id, what)
    try
        evalc('fn()'); ok = false; got = 'no error';
    catch e
        ok = strcmp(e.identifier, id); got = e.identifier;
    end
    f = check(ok, what);
    if ~ok; fprintf('        expected %s, got %s\n', id, got); end
end

function f = expectOk(fn, what)
    try
        evalc('fn()'); f = check(true, what);
    catch e
        f = check(false, what); fprintf('        error: %s: %s\n', e.identifier, e.message);
    end
end

function f = check(ok, what)
    if ok; fprintf('  PASS  %s\n', what); f = 0; else; fprintf('  FAIL  %s\n', what); f = 1; end
end

function restore(oldRoot, oldDir)
    setenv('BASS_ROOT', oldRoot); cd(oldDir);
end
