function printFigs(figs, fNames, figDir, printIt)
% printFigs - Export figures to png/fig/svg/eps by a cumulative level.
%
% printFigs(figs, fNames, figDir)
% printFigs(figs, fNames, figDir, printIt)
%
% Inputs:
%   figs    - array of figure handles to export.
%   fNames  - base filenames (string array or cellstr, no extension), one per
%             figure in figs (element k names figs(k)).
%   figDir  - output directory (created if it does not exist).
%   printIt - (optional) cumulative export level. Default 1.
%               0 : nothing
%               1 : png                     (300 dpi)
%               2 : png + fig
%               3 : png + fig + svg + eps   (svg & eps as vector)
%
% png is written at 300 dpi via exportgraphics; svg and eps via exportgraphics
% with ContentType 'vector'; fig via savefig. exportgraphics captures the
% figure's current colors, so for white-on-dark panels set dark groot defaults
% before plotting (headless MATLAB has no interactive dark theme).

    if ~exist('printIt','var') || isempty(printIt); printIt = 1; end
    if ~printIt; return; end

    figs   = figs(:);
    fNames = string(fNames(:));
    if numel(fNames) ~= numel(figs)
        error('printFigs:nameCount', ...
            'one name per figure required (%d figs, %d names).', numel(figs), numel(fNames));
    end
    if ~exist(figDir,'dir'); mkdir(figDir); end

    % Headless warm-up: in a -batch/-nodisplay session the FIRST exportgraphics can
    % drop the figure background and text; absorb that on a throwaway so the real
    % exports are clean. Skipped in interactive sessions (render pipeline is warm).
    if batchStartupOptionUsed
        wf = figure('Visible','off'); axes(wf); title(wf.CurrentAxes,'warmup'); drawnow;
        try, exportgraphics(wf, fullfile(tempdir,'printFigs_warmup.png')); catch, end
        close(wf);
    end

    for k = 1:numel(figs)
        f = fullfile(figDir, fNames(k));
        figure(figs(k)); drawnow; % force a full render before capture
        exportgraphics(figs(k), f + ".png", 'Resolution', 300);
        if printIt>=2; savefig(       figs(k), char(f + ".fig"));                   end
        if printIt>=3; exportgraphics(figs(k), f + ".svg", 'ContentType', 'vector');
                       exportgraphics(figs(k), f + ".eps", 'ContentType', 'vector'); end
    end
    disp("printFigs: exported " + numel(figs) + " figure(s) to " + string(figDir))
end
