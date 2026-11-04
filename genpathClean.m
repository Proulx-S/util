function p = genpathClean(d)
    % genpath(d) with the junk pruned: drops every directory that, BELOW d, has a
    % path component starting with '.' (.git, .claude/worktrees/<name>/..., which
    % genpath otherwise descends into -- so every agent worktree's full copy of a
    % tool would land on every consumer's MATLAB path), named 'scratch' (the
    % gitignored throwaway folder) or named 'dev' (kept dev scripts: run them with
    % addpath(fullfile(d,'dev')), never from a project's path). Components of d
    % itself are never inspected, so
    % a repo living under e.g. /scratch/... or ~/.claude/... is unaffected.
    % Used by gitClone.m / getClone.m in place of a bare genpath.
    d = char(d);
    while numel(d) > 1 && d(end) == filesep; d = d(1:end-1); end
    parts = strsplit(genpath(d), pathsep);
    keep = false(size(parts));
    for k = 1:numel(parts)
        if isempty(parts{k}); continue; end
        rel = parts{k}(numel(d)+1:end);            % '' for d itself, '/sub/dir' below it
        comps = strsplit(rel, filesep);
        comps = comps(~cellfun(@isempty, comps));
        keep(k) = ~any(startsWith(comps, '.') | strcmp(comps, 'scratch') | strcmp(comps, 'dev'));
    end
    p = strjoin(parts(keep), pathsep);
end
