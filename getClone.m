function getClone(url, folder, repoSubDir, branch)
    % Get a detached, locally-developable copy of a tool repo, tracked by the
    % calling project's own repo -- for deliberately modifying tool source from
    % inside a project, as opposed to gitClone.m's read-only shared clone.
    %
    % folder is expected to be a project-local path (e.g. project/devTools/<tool>).
    % If folder already exists, it is left untouched (never clobbers in-progress
    % local edits) -- only addpath is (re-)run.
    % Otherwise: clones fresh from url (writable, via gitClone's allowWrite=true),
    % records provenance (url, branch, commit SHA) to folder/.origin.json, then
    % strips folder/.git so the copy is no longer its own repo -- the project's
    % repo tracks it like any other project file from then on.
    if ~exist('repoSubDir', 'var'); repoSubDir = []; end
    if ~exist('branch', 'var'); branch = []; end

    if exist(fullfile(folder,repoSubDir), 'dir')
        disp([folder ' already exists locally -- leaving it untouched.']);
        addpath(genpath(fullfile(folder,repoSubDir)));
        disp(['added to path:' newline ' ' fullfile(folder,repoSubDir)]);
        return
    end

    gitClone(url, folder, repoSubDir, branch, true);

    [st, sha] = system(['cd ' folder ' && git rev-parse HEAD']);
    if st ~= 0
        error('getClone:noCommit', 'Could not resolve HEAD commit in %s before detaching.', folder);
    end
    sha = strtrim(sha);

    origin = struct('url', url, 'branch', branch, 'commit', sha);
    fid = fopen(fullfile(folder, '.origin.json'), 'w');
    fprintf(fid, '%s', jsonencode(origin));
    fclose(fid);

    system(['rm -rf ' fullfile(folder,'.git')]);
    disp([newline '--------------------------------' newline ...
        'NOTE: ' folder ' has been detached from ' url ' (commit ' sha ').' newline ...
        'It is now tracked by this project''s own repo -- edit it freely. Provenance' newline ...
        'saved to ' fullfile(folder,'.origin.json') ' for syncing changes back upstream later.' newline ...
        '--------------------------------']);
end
