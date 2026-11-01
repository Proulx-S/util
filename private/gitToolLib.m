function L = gitToolLib()
% GITTOOLLIB  Helpers shared by gitToolShared and gitToolDev (private: visible to util only).
%   L = gitToolLib;  then L.q(s), L.runGit(...), ...
% Path checks error out BEFORE any filesystem or git action. Nothing here deletes anything.
    L.mergeOpts    = @mergeOpts;
    L.bassRootDir  = @bassRootDir;
    L.checkTool    = @checkTool;
    L.canonicalDir = @canonicalDir;
    L.checkSubDir  = @checkSubDir;
    L.checkUrl     = @checkUrl;
    L.q            = @q;
    L.runGit       = @runGit;
    L.gitOut       = @gitOut;
    L.isRepoRoot   = @isRepoRoot;
    L.currentBranch= @currentBranch;
    L.hasRef       = @hasRef;
    L.loud         = @loud;
    L.summary      = @summary;
end

function opts = mergeOpts(defaults, opts)
    if nargin < 2 || isempty(opts); opts = struct; end
    if ~isstruct(opts) || ~isscalar(opts); error('gitTool:badOpts', 'opts must be a scalar struct.'); end
    f = fieldnames(opts);
    for k = 1:numel(f)
        if ~isfield(defaults, f{k}); error('gitTool:badOpts', 'Unknown option ''%s''.', f{k}); end
        defaults.(f{k}) = opts.(f{k});
    end
    opts = defaults;
end

function r = bassRootDir()
    r = getenv('BASS_ROOT');
    if isempty(r); r = '/scratch/bass'; end
end

function tool = checkTool(tool)
    if ~(ischar(tool) || (isstring(tool) && isscalar(tool))); error('gitTool:badTool', 'tool must be a char name.'); end
    tool = char(tool);
    if isempty(regexp(tool, '^[A-Za-z0-9._-]+$', 'once')) || any(strcmp(tool, {'.', '..'}))
        error('gitTool:badTool', 'Refusing tool name ''%s'': must match ^[A-Za-z0-9._-]+$ (and not . or ..).', tool);
    end
end

function d = canonicalDir(d, name)
    % non-empty, an existing folder, absolute after resolving .. and symlinks, and not '/'
    if ~(ischar(d) || (isstring(d) && isscalar(d))) || isempty(strtrim(char(d)))
        error('gitTool:badDir', 'Refusing %s: must be a non-empty folder path.', name);
    end
    d = char(d);
    if ~exist(d, 'dir'); error('gitTool:badDir', 'Refusing %s: not an existing folder: %s', name, d); end
    d = char(java.io.File(d).getCanonicalPath());
    if isempty(d) || strcmp(d, filesep) || d(1) ~= filesep
        error('gitTool:badDir', 'Refusing %s = ''%s''.', name, d);
    end
end

function s = checkSubDir(s)
    s = char(s);
    if isempty(s); return; end
    if isempty(regexp(s, '^[A-Za-z0-9._/-]+$', 'once')) || s(1) == '/' || any(strcmp(strsplit(s, '/'), '..'))
        error('gitTool:badSubDir', 'Refusing opts.subDir ''%s'': relative, no .., [A-Za-z0-9._/-] only.', s);
    end
end

function url = checkUrl(url)
    url = char(url);
    if isempty(url) || any(url == newline) || any(url == char(13)) || startsWith(url, '-')
        error('gitTool:badUrl', 'Refusing url ''%s''.', url);
    end
end

function s = q(s)   % single-quote for bash
    s = ['''' strrep(char(s), '''', '''\''''') ''''];
end

function [st, out, log] = runGit(log, folder, args)
    % logged git call; never prompts (no hang in -batch)
    if isempty(folder); loc = ''; else; loc = ['-C ' q(folder) ' ']; end
    log{end+1} = ['git ' loc args];
    [st, out] = system(['GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND=''ssh -o BatchMode=yes'' git ' loc args ' 2>&1']);
end

function out = gitOut(folder, args)
    % read-only git query; '' on failure
    [st, out] = system(['git -C ' q(folder) ' ' args ' 2>/dev/null']);
    if st ~= 0; out = ''; end
    out = strtrim(out);
end

function tf = isRepoRoot(folder)
    % true only if folder is itself a repo root (not a plain folder inside another repo)
    tf = false;
    if ~exist(fullfile(folder, '.git'), 'file') && ~exist(fullfile(folder, '.git'), 'dir'); return; end
    top = gitOut(folder, 'rev-parse --show-toplevel');
    if isempty(top); return; end
    tf = strcmp(char(java.io.File(top).getCanonicalPath()), char(java.io.File(folder).getCanonicalPath()));
end

function b = currentBranch(folder)
    b = gitOut(folder, 'rev-parse --abbrev-ref HEAD');   % 'HEAD' when detached
end

function tf = hasRef(folder, ref)
    st = system(['git -C ' q(folder) ' rev-parse --verify -q ' q(ref) ' >/dev/null 2>&1']);
    tf = (st == 0);
end

function msg = loud(lines)
    bar = repmat('!', 1, 72);
    lines = cellfun(@(x) ['!!! ' strrep(char(x), newline, [newline '!!!   '])], lines, 'UniformOutput', false);
    msg = strjoin([{bar}, lines, {bar}], newline);
    disp(msg);
end

function summary(tool, folder, p, log, warns)
    disp(['added to path: ' p]);
    if isRepoRoot(folder)
        b = currentBranch(folder); sha = gitOut(folder, 'rev-parse --short HEAD');
        ab = sscanf(gitOut(folder, 'rev-list --left-right --count HEAD...@{u}'), '%d');
        if numel(ab) == 2; abMsg = sprintf('%d ahead, %d behind its upstream', ab(1), ab(2));
        else; abMsg = 'no upstream'; end
        disp([tool ' on ' b ' @' sha ' (' abMsg ')']);
    end
    if ~isempty(log)
        disp('--- git commands run ---');
        for k = 1:numel(log); disp(['  ' num2str(k) '. ' log{k}]); end
    end
    if ~isempty(warns)
        disp([newline num2str(numel(warns)) ' WARNING(S) for ' tool ', repeated:']);
        for k = 1:numel(warns); disp(warns{k}); end
    end
    disp('--------------------------------');
end
