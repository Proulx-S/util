function [cmap, info] = colormap_blueNeutralRed(wNeutral, wTransition, lNeutral, cOuter, N, plotProfiles)
%COLORMAP_BLUENEUTRALRED  LEGACY, fixed-hue (blue/red) diverging map. RESERVED FOR ACTIVATION MAPS
%   specifically (Seb's own convention, 2026-08-19) -- for any OTHER diverging-colormap need (e.g. a
%   fit-residual map), call colormap_divergingHue.m directly with a DIFFERENT hue pair instead, so that
%   use is never visually confusable with an activation map.
%
%   Generalized (2026-08-19) out to colormap_divergingHue.m/colorDivergingHueLCH.m, which now own the
%   hue pair as a real input instead of a hardcoded constant -- this file is kept ONLY for existing
%   callers' exact backward-compatible signature/behavior (same positional args, same no-arg self-demo,
%   same sweep mode, same cache-file naming). It is a thin wrapper: the actual gamut-search/LCH-ramp
%   math now lives in colorDivergingHueLCH.m (shared with colormap_divergingHue.m, never duplicated) --
%   this file's own localBuild below just calls that with hues FIXED to blue/red.
%
%   [cmap, info] = colormap_blueNeutralRed(wNeutral, wTransition, lNeutral, cOuter, N, plotProfiles)
%
%   All arguments are optional and positional; pass [] to keep a default. The colorbar is taken to span
%   [-1, 1] (total width 2). Widths are in those data units:
%
%     |<----- blue wing ----->|<-trans->|<-- flat -->|<-trans->|<-- red wing -->|
%    -1                                       0                                  1
%
%   wNeutral     width of the central FLAT neutral zone, in [-1,1] units,
%                spanning [-wNeutral/2, +wNeutral/2].            (default 0.4)
%   wTransition  width of EACH linear transition zone (neutral <-> inner
%                colour), in [-1,1] units.                       (default 0.16)
%                  Each wing then has width 1 - wNeutral/2 - wTransition; the
%                  two wings together span 2 - (wNeutral + 2*wTransition).
%                  Requires wNeutral + 2*wTransition <= 2.
%   lNeutral     lightness of the neutral zone, a 0..1 knob: 0 = black,
%                1 = white, 0.5 = mid-gray. [] matches the inner-edge lightness,
%                so leaving the dead-zone is a pure chroma onset.  (default [])
%   cOuter       chroma at the OUTER extremes of the wings, a 0..1 knob:
%                0 = white, 1 = the most saturated colour achievable by BOTH
%                wings (common gamut max, so the wings stay symmetric).
%                                                                  (default 0.2)
%   N            number of colours.                       (default 256)
%   plotProfiles when true, also save a profile panel (colorbar + L*/C*/hue +
%                the three ΔE profiles) for THIS colormap into the working
%                directory, exactly as the no-argument demo does for its set.
%                                                                (default false)
%
%   Sweep mode. If exactly one of wNeutral, wTransition, lNeutral or cOuter is
%   passed as a vector (length 2..16), the function instead builds the demo-style
%   panel sweeping that parameter (the others held fixed), saves it to the
%   working directory as colormap_blueNeutralRed_sweep_<name>.png, and returns
%   the colormap of the first swept value. Passing more than one vector errors.
%
%   Caching. A plain single call saves its colormap to a .mat in the working
%   directory named by its inputs (colormap_blueNeutralRed_wN..._wTr..._lN...
%   _cO..._N...); a later call with the same inputs loads it instead of
%   recomputing. When plotProfiles is set, the profile PNG shares that same
%   input-keyed base name. Sweeps and the no-argument demo do NOT cache (they
%   are one-off explorations), so they never litter the directory with .mat
%   files.
%
%   NO-ARG CALL -- colormap_blueNeutralRed() (zero arguments) does NOT return this function's own
%   positional defaults -- nargin==0 runs a "self-demo" instead (builds/leaves open an invisible demo
%   figure, saves a PNG to pwd, and returns that demo's OWN baseline parameterization, e.g.
%   wNeutral=0.20/lNeutral=0.50, NOT this file's own defaults of wNeutral=0.4/lNeutral=[]) -- a real,
%   confirmed (2026-08-19) footgun for any caller expecting a cheap "give me defaults" no-arg
%   convention. UNCHANGED from this file's pre-generalization behavior (kept as-is here -- a shared
%   tool's public no-arg contract is a bigger, cross-project call, not something to change unilaterally
%   while generalizing the hue) -- always pass explicit [] arguments if you want the real defaults.
%
%   shape, blueHue, redHue and gamutN are HARDCODED constants (see the
%   localConsts() helper at the bottom of the file); edit them there if needed
%   -- shape/gamutN are shared with colorDivergingHueLCH.m's own copy (duplicated,
%   this file family's own established small-helper-duplication convention, purely so this
%   legacy file's cache-invalidation fingerprint keeps working standalone); blueHue/redHue are
%   THIS FILE'S OWN fixed choice, forwarded to colorDivergingHueLCH.m as its hues argument.
%   shape is explained below.
%
%   info  struct: innerBlueLCH, innerRedLCH, outerBlueLCH, outerRedLCH [L C H];
%                 innerL, innerDeltaE; flatEdges, transEdges, wingWidth (data
%                 units); Lprofile, Cprofile, Hprofile; and the dE profiles
%                 dEprofile (+v vs -v), dEcentreProfile, dEouterProfile. (Same
%                 shape as colorDivergingHueLCH.m's own info struct, with its
%                 innerALCH/innerBLCH/outerALCH/outerBLCH renamed back to the
%                 blue/red-specific field names this file's own callers expect.)
%
%   The 'shape' constant. Within a wing the colour is interpolated from the
%   outer extreme (at the wing tip) to the inner max-separation colour (at the
%   dead-zone edge) as  colour = outer + (inner - outer) * s^shape,  where s
%   runs 0..1 from the outer tip to the inner edge. shape is thus a gamma on
%   that ramp:
%     shape = 1  : straight linear ramp of L* and C* across the wing.
%     shape > 1  : s^shape stays small over most of the wing, so colours hug
%                  the OUTER look and swing to the saturated inner colour only
%                  near the dead-zone -- i.e. high chroma is pushed toward the
%                  inner edge (a narrow, punchy band next to neutral).
%     shape < 1  : the inner colour spreads across most of the wing, with the
%                  pale outer look confined to the very tip -- high chroma
%                  pushed toward the outer edge.
%   It only reshapes the gradient along the wing; it does not move the region
%   boundaries or change the inner/outer endpoint colours.
%
%   Design. The two colours flanking the neutral zone (blue-inner, red-inner)
%   are found by searching the sRGB gamut for the equal-lightness blue/red pair
%   with the largest CIELAB Delta-E, so the instant a value leaves the dead-zone
%   its sign is maximally legible. The L* and C* profiles are ALWAYS symmetric
%   across the two wings (equal lightness, equal chroma at both the inner and
%   outer ends); only hue distinguishes the sign, so neither sign dominates.
%
%   Built in CIE LCH and converted via the Colorspace-Transformations tool
%   (same dependency as colormap_bivariateBlackToSpectral) -- see
%   colorDivergingHueLCH.m for the actual math this file now delegates to.

% ---- self-demo when called with no arguments when nargin == 0 ----------
if nargin == 0; [cmap, info] = localDemo(); return; end

% ---- defaults ----------------------------------------------------------
if nargin < 1 || isempty(wNeutral);    wNeutral    = 0.4;  end
if nargin < 2 || isempty(wTransition); wTransition = 0.16; end
if nargin < 3;                         lNeutral    = [];   end
if nargin < 4 || isempty(cOuter);      cOuter      = 0.2;  end
if nargin < 5 || isempty(N);           N           = 256;  end
if nargin < 6 || isempty(plotProfiles); plotProfiles = false; end
assert(isscalar(N) && N >= 2, 'N must be a scalar >= 2.');

% ---- sweep mode: exactly one tunable parameter given as an array --------
% (length 2..5). Builds the demo-style panel sweeping that parameter, saves it
% to the working directory, and returns the colormap of the first swept value.
swNames = {'wNeutral','wTransition','lNeutral','cOuter'};
swVals  = {wNeutral, wTransition, lNeutral, cOuter};
isArr   = cellfun(@(v) numel(v) > 1, swVals);
if any(isArr)
    assert(nnz(isArr) == 1, 'colormap_blueNeutralRed: only one parameter may be an array at a time.');
    vals = swVals{isArr};
    assert(numel(vals) <= 16, 'colormap_blueNeutralRed: a swept parameter may have at most 16 values.');
    [cmap, info] = localSweep(swNames{isArr}, vals(:).', wNeutral, wTransition, lNeutral, cOuter, N);
    return
end

assert(wNeutral >= 0 && wTransition >= 0, 'wNeutral and wTransition must be >= 0.');
assert(wNeutral + 2*wTransition <= 2, ...
    'wNeutral + 2*wTransition = %.3f exceeds the colorbar width (2); no room for wings.', ...
    wNeutral + 2*wTransition);

% ---- cache: load a precomputed colormap for these inputs if available --
% Only single (non-swept) calls touch the cache; localSweep/localDemo build
% directly via localBuild and never write .mat files.
consts    = localConsts();
cacheBase = localCacheName(wNeutral, wTransition, lNeutral, cOuter, N);
cacheFile = fullfile(pwd, [cacheBase '.mat']);
loaded = false;
if exist(cacheFile, 'file')
    S = load(cacheFile);
    if isfield(S,'consts') && isequal(S.consts, consts)
        cmap = S.cmap; info = S.info; loaded = true;   % load and use; no recompute
    end
end
if ~loaded
    [cmap, info] = localBuild(wNeutral, wTransition, lNeutral, cOuter, N);
    save(cacheFile, 'cmap', 'info', 'consts', '-v7');
end

% ---- optional: save a profile panel for THIS colormap ------------------
if plotProfiles
    localPlotCustom(cmap, info, wNeutral, wTransition, lNeutral, cOuter, cacheBase);
end
end

% =======================================================================
function c = localConsts()
% Hardcoded constants (EDIT HERE to change them). Stored in each cache .mat and checked on load, so
% editing one invalidates stale caches automatically. shape/gamutN are duplicated from
% colorDivergingHueLCH.m's own localConsts() (this file family's established small-helper-duplication
% convention -- see that file's own header) purely so THIS file's cache-invalidation fingerprint below
% keeps working without depending on that file's internals; blueHue/redHue are this file's own genuine
% fixed choice (forwarded as colorDivergingHueLCH.m's hues argument, never swept/overridden).
c.shape   = 1;            % L*/C* ramp curvature along each wing (gamma; see header) -- must match
                           % colorDivergingHueLCH.m's own shape constant or this fingerprint goes stale.
c.blueHue = [250 300];    % blue hue search sector [deg]
c.redHue  = [340 40];     % red  hue search sector [deg] (wraps through 0)
c.gamutN  = 41;           % sRGB samples / channel for the gamut search -- must match
                           % colorDivergingHueLCH.m's own gamutN constant, same caveat as shape above.
end

% =======================================================================
function [cmap, info] = localBuild(wNeutral, wTransition, lNeutral, cOuter, N)
% Delegates the actual gamut-search/LCH-ramp math to colorDivergingHueLCH.m, hues fixed to blue/red --
% no math duplicated here any more (pre-generalization, this function had its own ~150-line copy of
% that math; see colorDivergingHueLCH.m for where it now lives).
c = localConsts();
[cmap, info] = colorDivergingHueLCH({c.blueHue, c.redHue}, wNeutral, wTransition, lNeutral, cOuter, N);
% Field names below rename colorDivergingHueLCH.m's own side-A/side-B-generic info fields back to this
% file's own blue/red-specific names, for backward compatibility with existing callers of THIS file.
info.innerBlueLCH = info.innerALCH; info.innerRedLCH = info.innerBLCH;
info.outerBlueLCH = info.outerALCH; info.outerRedLCH = info.outerBLCH;
info = rmfield(info, {'innerALCH','innerBLCH','outerALCH','outerBLCH'});
end

% -----------------------------------------------------------------------
function [cmap, info] = localDemo()
% Self-demo, run when colormap_blueNeutralRed is called with no arguments. Builds a figure exercising
% the parameters across several "experiments" and, per experiment (column): the colorbar, the
% L*/C*/hue profiles, and the three ΔE profiles. Returns the baseline colormap as the function output.
N = 256;
x = linspace(-1, 1, N);

%          name, wNeutral, wTransition, lNeutral, cOuter
exps = {
  'baseline',        0.20,        0.20,     0.50, 0.20
  'no flat, sharp',  0.00,        0.20,     0.50, 0.20
  'black neutral',   0.20,        0.20,     0.00, 0.20
  'white neutral',   0.20,        0.20,     1.00, 0.20
  'saturated wings', 0.20,        0.20,     0.50, 1.00
  'wide flat+trans', 0.40,        0.40,     0.50, 0.20
};
ne = size(exps,1);

f = figure('MenuBar','none','ToolBar','none','Color','w','Visible','off', ...
           'Units','centimeters','Position',[0 0 5.5*ne 22]);
try, f.Theme = 'light'; catch, end
hT = tiledlayout(f, 5, ne, 'TileSpacing','compact','Padding','compact');

hLeg = gobjects(1,6);
for k = 1:ne
    [nm, wN, wTr, lN, cO] = exps{k,:};
    [ck, ik] = localBuild(wN, wTr, lN, cO, N);
    if k == 1, cmap = ck; info = ik; end   % baseline is the function output
    ttl = {nm, sprintf('wN=%.2f wTr=%.2f', wN, wTr), ...
           sprintf('lN=%.2f cO=%.2f', lN, cO), ...
           sprintf('\\DeltaE=%.0f', ik.innerDeltaE)};
    hh = localPlotColumn(hT, k, ne, x, ck, ik, ttl);
    if k == 1, hLeg = hh; end
end
localProfileLegend(hLeg);
localSavePlot(f, 'colormap_blueNeutralRed_demo.png');
end

% -----------------------------------------------------------------------
function [cmap, info] = localSweep(name, vals, wNeutral, wTransition, lNeutral, cOuter, N)
% Demo-style panel sweeping a single parameter 'name' over 'vals' (length<=5),
% holding the others fixed. Saves to the working directory; returns the first.
ne = numel(vals);
x  = linspace(-1, 1, N);
f = figure('MenuBar','none','ToolBar','none','Color','w','Visible','off', ...
           'Units','centimeters','Position',[0 0 5.5*ne 22]);
try, f.Theme = 'light'; catch, end
hT = tiledlayout(f, 5, ne, 'TileSpacing','compact','Padding','compact');

hLeg = gobjects(1,6);
for k = 1:ne
    wN = wNeutral; wTr = wTransition; lN = lNeutral; cO = cOuter;
    switch name
        case 'wNeutral',    wN  = vals(k);
        case 'wTransition', wTr = vals(k);
        case 'lNeutral',    lN  = vals(k);
        case 'cOuter',      cO  = vals(k);
    end
    [ck, ik] = localBuild(wN, wTr, lN, cO, N);
    if k == 1, cmap = ck; info = ik; end
    if isempty(lN); lNs = '[]'; else; lNs = sprintf('%.2f', lN); end
    ttl = {sprintf('%s = %.4g', name, vals(k)), ...
           sprintf('wN=%.2f wTr=%.2f', wN, wTr), ...
           sprintf('lN=%s cO=%.2f', lNs, cO), ...
           sprintf('\\DeltaE=%.0f', ik.innerDeltaE)};
    hh = localPlotColumn(hT, k, ne, x, ck, ik, ttl);
    if k == 1, hLeg = hh; end
end
localProfileLegend(hLeg);
localSavePlot(f, sprintf('colormap_blueNeutralRed_sweep_%s.png', name));
end

% -----------------------------------------------------------------------
function localPlotCustom(cmap, info, wNeutral, wTransition, lNeutral, cOuter, cacheBase)
% Single-column version of the demo panel, for one custom colormap. The PNG
% shares the input-keyed cache base name.
x = linspace(-1, 1, size(cmap,1));
f = figure('MenuBar','none','ToolBar','none','Color','w','Visible','off', ...
           'Units','centimeters','Position',[0 0 16 22]);
try, f.Theme = 'light'; catch, end
hT = tiledlayout(f, 5, 1, 'TileSpacing','compact','Padding','compact');
if isempty(lNeutral); lNstr = '[]'; else; lNstr = sprintf('%.2f', lNeutral); end
ttl = {'custom', sprintf('wN=%.2f wTr=%.2f', wNeutral, wTransition), ...
       sprintf('lN=%s cO=%.2f', lNstr, cOuter), ...
       sprintf('\\DeltaE=%.0f', info.innerDeltaE)};
h = localPlotColumn(hT, 1, 1, x, cmap, info, ttl);
localProfileLegend(h);
localSavePlot(f, [cacheBase '.png'], false);   % silent: per-call cache panel
end

% -----------------------------------------------------------------------
function base = localCacheName(wNeutral, wTransition, lNeutral, cOuter, N)
% Filename base encoding the inputs (used for the .mat cache and profile PNG).
fmt = @(v) strrep(strrep(sprintf('%.4g', v), '.', 'p'), '-', 'm');
if isempty(lNeutral); lNs = 'auto'; else; lNs = fmt(lNeutral); end
base = sprintf('colormap_blueNeutralRed_wN%s_wTr%s_lN%s_cO%s_N%d', ...
    fmt(wNeutral), fmt(wTransition), lNs, fmt(cOuter), N);
end

% -----------------------------------------------------------------------
function h = localPlotColumn(hT, k, ne, x, ck, ik, titleLines)
% Plot one colormap into column k of a 5-row tiledlayout: colorbar (row 1),
% L*/C*/hue (rows 2-3), the three ΔE profiles (rows 4-5). Returns the 6 line
% handles (L*, C*, hue, ΔE±v, ΔEcentre, ΔEouter) for building a legend.
cL  = [0 0 0];          cC  = [0.85 0.33 0.10]; cH  = [0.20 0.40 0.95];
cD1 = [0.50 0.00 0.55]; cD2 = [0.00 0.55 0.45]; cD3 = [0.80 0.50 0.00];

% row 1: colorbar
ax = nexttile(hT, k);
image(ax, x, [0 1], permute(ck,[3 1 2]));
set(ax,'YTick',[],'XTick',[-1 0 1]);
title(ax, titleLines, 'FontWeight','normal','FontSize',7);

% rows 2-3: L*, C* (left) and hue (right)
ax = nexttile(hT, ne + k, [2 1]);
Hp = ik.Hprofile; Hp(ik.Cprofile < 2) = NaN;
yyaxis(ax,'left'); hold(ax,'on');
h1 = plot(ax, x, ik.Lprofile, '-', 'Color',cL, 'LineWidth',1.3);
h2 = plot(ax, x, ik.Cprofile, '-', 'Color',cC, 'LineWidth',1.3);
ylim(ax,[0 120]); set(ax,'YTick',0:30:120); ax.YColor = 'k';
yyaxis(ax,'right');
h3 = plot(ax, x, Hp, '-', 'Color',cH, 'LineWidth',1.3);
ylim(ax,[0 360]); set(ax,'YTick',0:90:360); ax.YColor = cH;
set(ax,'XTick',[-1 0 1],'XTickLabel',[]); grid(ax,'on');
if k == 1,  yyaxis(ax,'left');  ylabel(ax,'L*, C*'); end
if k == ne, yyaxis(ax,'right'); ylabel(ax,'hue [deg]'); end

% rows 4-5: the three ΔE profiles
ax = nexttile(hT, 3*ne + k, [2 1]); hold(ax,'on');
h4 = plot(ax, x, ik.dEprofile,       '-', 'Color',cD1, 'LineWidth',1.3);
h5 = plot(ax, x, ik.dEcentreProfile, '-', 'Color',cD2, 'LineWidth',1.3);
h6 = plot(ax, x, ik.dEouterProfile,  '-', 'Color',cD3, 'LineWidth',1.3);
ylim(ax,[0 150]); set(ax,'YTick',0:30:150,'XTick',[-1 0 1]); grid(ax,'on');
xlabel(ax,'signed value'); if k == 1, ylabel(ax,'\DeltaE'); end

h = [h1 h2 h3 h4 h5 h6];
end

% -----------------------------------------------------------------------
function localProfileLegend(h)
lg = legend(h, {'L*','C*','hue', ...
    '\DeltaE: +v vs -v','\DeltaE: centre vs v','\DeltaE: outer vs v'}, ...
    'Orientation','horizontal');
lg.Layout.Tile = 'south';
end

% -----------------------------------------------------------------------
function localSavePlot(f, name, announce)
% headless-friendly: save a PNG in the working directory. Reports the path for
% the deliberate demo/sweep outputs; stays silent for the per-call cache panel.
if nargin < 3; announce = true; end
outPath = fullfile(pwd, name);
try, exportgraphics(f, outPath, 'Resolution', 150);
     if announce; fprintf('colormap_blueNeutralRed: saved %s\n', outPath); end
catch, end
end
