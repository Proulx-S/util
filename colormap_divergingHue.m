function [cmap, info] = colormap_divergingHue(hues, wNeutral, wTransition, lNeutral, cOuter, N, plotProfiles)
%COLORMAP_DIVERGINGHUE  Diverging two-hue-plus-neutral map with a controllable neutral dead-zone and
%   maximal perceptual separation between the inner edges of the two coloured wings -- GENERALIZED
%   (2026-08-19) from colormap_blueNeutralRed.m so the hue PAIR is a real input instead of a hardcoded
%   constant. colormap_blueNeutralRed.m is now a thin LEGACY wrapper fixing hues to blue/red and is
%   RESERVED FOR ACTIVATION MAPS specifically (Seb's own convention) -- use this function directly, with
%   a DIFFERENT hue pair, for any other diverging need (e.g. a fit-residual map) so it's never visually
%   confusable with an activation map. Core math lives in colorDivergingHueLCH.m (shared by both this
%   function and colormap_blueNeutralRed.m -- see that file's own header for why the math itself is
%   never duplicated).
%
%   [cmap, info] = colormap_divergingHue(hues, wNeutral, wTransition, lNeutral, cOuter, N, plotProfiles)
%
%   All arguments are optional and positional; pass [] to keep a default. The colorbar is taken to span
%   [-1, 1] (total width 2). Widths are in those data units:
%
%     |<----- side-A wing --->|<-trans->|<-- flat -->|<-trans->|<-- side-B wing -->|
%    -1                                       0                                  1
%
%   hues         1x2 cell, {hueA, hueB} -- each a [lo hi] hue SECTOR in degrees (wraps if lo > hi) to
%                search within for the max-Delta-E, equal-lightness, in-gamut colour on that side. hueA
%                is the NEGATIVE-value side, hueB the POSITIVE-value side.
%                                                       (default {[250 300],[340 40]}, blue/red)
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
%                'trans' -- transition zones hold the wing's own colour FIXED and fade an ALPHA
%                channel to 0 instead of blending towards grey (see colorDivergingHueLCH.m's own
%                header for the exact behaviour and info.alpha below). NOT sweepable (a scalar char
%                setting, unlike the numeric knob).
%   cOuter       wing chroma knob(s), each a 0..1 value where 0 = white and 1 =
%                that end's own most saturated colour achievable by BOTH wings
%                (common gamut max, so the wings stay symmetric). SCALAR or a
%                LENGTH-2 [cInner cOuter] PAIR (2026-09-02, Seb's own ask):
%                  scalar v        -- the OUTER extremes only; the inner edges
%                                     stay at full saturation. Same as [1 v] --
%                                     the historical, and pre-2026-09-02 only,
%                                     form.
%                  [cInner cOuter] -- cInner scales the INNER edges (the colours
%                                     flanking the dead zone), cOuter the OUTER
%                                     extremes. cInner=1 is the max-ΔE pair the
%                                     gamut search found, cInner=0 whitens the
%                                     inner edges out completely.
%                cInner<1 deliberately trades away some of the inner-edge
%                perceptual separation this function is built around; the ΔE
%                actually achieved is reported in info.innerDeltaE (and printed
%                on every demo/sweep panel), so the cost is visible.
%                                                                  (default 0.2)
%   N            number of colours.                       (default 256)
%   plotProfiles when true, also save a profile panel (colorbar + L*/C*/hue +
%                the three ΔE profiles) for THIS colormap into the working
%                directory, exactly as the no-argument demo does for its set.
%                                                                (default false)
%
%   Sweep mode. If exactly one of wNeutral, wTransition, lNeutral or cOuter is
%   passed as a vector (length 2..16), the function instead builds the demo-style
%   panel sweeping that parameter (the others held fixed, hues fixed too -- hues
%   itself is NOT sweepable), saves it to the working directory as
%   colormap_divergingHue_sweep_<name>.png, and returns the colormap of the first
%   swept value. Passing more than one vector errors.
%     cOuter is the ONE EXCEPTION to "a vector means a sweep", because length 2
%     is now its [cInner cOuter] pair (see above). Its rule is:
%       scalar              -- single colormap, outer knob only.
%       1x2 / 2x1           -- single colormap, the [cInner cOuter] PAIR. NOT a
%                              2-value sweep (the one form whose meaning changed
%                              on 2026-09-02).
%       2xK matrix (K>=2)   -- sweep of K pairs, one [cInner; cOuter] per COLUMN.
%                              This is also how to sweep exactly 2 outer knobs:
%                              [1 1; 0.2 0.5].
%       vector, length>=3   -- sweep of that many outer knobs, cInner=1 for all
%                              (unchanged from before).
%     Any other shape errors rather than guessing.
%
%   Caching. A plain single call saves its colormap to a .mat in the working
%   directory named by its inputs (colormap_divergingHue_hA..._hB..._wN..._wTr..._lN...
%   _cO..._N...); a later call with the same inputs loads it instead of
%   recomputing. When plotProfiles is set, the profile PNG shares that same
%   input-keyed base name. Sweeps and the no-argument demo do NOT cache (they
%   are one-off explorations), so they never litter the directory with .mat
%   files. The cO field of that name stays bare (cO0p2) whenever cInner is 1 --
%   including the explicit pair [1 0.2], which builds a colormap identical to the
%   scalar 0.2 and so deliberately SHARES its cache entry -- and becomes
%   cO<inner>to<outer> (cO0p6to0p2, mirroring the hue fields' own "to") only when
%   cInner is actually in play. Pre-2026-09-02 .mat files therefore keep hitting.
%
%   NO-ARG CALL -- colormap_divergingHue() (zero arguments) does NOT return this function's own
%   positional defaults -- it runs a "self-demo" instead (builds/saves a demo panel PNG, returns that
%   demo's OWN baseline parameterization, generally DIFFERENT from the plain positional defaults above).
%   This mirrors colormap_blueNeutralRed.m's own original, pre-generalization no-arg behavior exactly
%   (kept for consistency between the two, not because it's the ideal convention -- see
%   plotGaussianFitPanels.m in the humanMouse project for a concrete case where this distinction
%   mattered and had to be worked around by always passing explicit [] arguments, never a bare call).
%
%   shape and gamutN are HARDCODED constants (see colorDivergingHueLCH.m's own localConsts() helper);
%   edit them there if needed -- shared by both this function and colormap_blueNeutralRed.m.
%
%   info  struct: innerALCH, innerBLCH, outerALCH, outerBLCH [L C H]; innerL, innerDeltaE; flatEdges,
%                 transEdges, wingWidth (data units); Lprofile, Cprofile, Hprofile; alpha; and the dE
%                 profiles dEprofile (+v vs -v), dEcentreProfile, dEouterProfile. See
%                 colorDivergingHueLCH.m's own header for the exact field meanings.
%
%   Design. See colorDivergingHueLCH.m's own header for the full design rationale (CIE LCH gamut
%   search, why it avoids the naive-RGB-interpolation "Mach band" artifact, etc.) -- not restated here.
%
%   colormap_divergingHue({[80 140],[260 320]});                          % green/violet, defaults otherwise
%   colormap_divergingHue({[80 140],[260 320]}, 0.4, 0.16, [], 0.2, 256);  % same, fully explicit (safe vs. the no-arg trap)
%   colormap_divergingHue([], [], [], [], [0.6 0.2]);                      % inner edges pulled 40% towards white
%   colormap_divergingHue([], [], [], [], [1 1; 0.2 0.5]);                 % 2-value cOuter sweep, cInner=1 (see Sweep mode)
%   colormap_divergingHue([], [], [], [], [1 0.8 0.6 0.4; 0.2 0.2 0.2 0.2]); % sweep cInner alone, cOuter held at 0.2

% ---- self-demo when called with no arguments ----------------------------
if nargin == 0; [cmap, info] = localDemo(); return; end

% ---- defaults ----------------------------------------------------------
if nargin < 1 || isempty(hues);        hues        = {[250 300],[340 40]}; end
if nargin < 2 || isempty(wNeutral);    wNeutral    = 0.4;  end
if nargin < 3 || isempty(wTransition); wTransition = 0.16; end
if nargin < 4;                         lNeutral    = [];   end
if nargin < 5 || isempty(cOuter);      cOuter      = 0.2;  end
if nargin < 6 || isempty(N);           N           = 256;  end
if nargin < 7 || isempty(plotProfiles); plotProfiles = false; end
assert(iscell(hues) && numel(hues)==2, 'colormap_divergingHue:badHues', ...
    'hues must be a 1x2 cell {hueA, hueB}, each a [lo hi] degree sector.');
assert(isscalar(N) && N >= 2, 'N must be a scalar >= 2.');

% ---- sweep mode: exactly one tunable parameter given as an array --------
% (length 2..16). hues is NEVER swept -- fixed for the whole panel. Builds the demo-style panel
% sweeping that parameter, saves it to the working directory, and returns the colormap of the first
% swept value.
swNames = {'wNeutral','wTransition','lNeutral','cOuter'};
swVals  = {wNeutral, wTransition, lNeutral, cOuter};
isArr   = cellfun(@(v) isnumeric(v) && numel(v) > 1, swVals);   % lNeutral='trans' (numel 5) is a
                                                                 % scalar CHAR setting, never a sweep
% cOuter needs its own rule: a length-2 vector is its [cInner cOuter] PAIR, not a 2-value sweep.
[isArr(4), cOuterSwVals] = localCOuterSweep(cOuter);
if any(isArr)
    assert(nnz(isArr) == 1, 'colormap_divergingHue: only one parameter may be an array at a time.');
    iSw = find(isArr);
    if iSw == 4; vals = cOuterSwVals; else; vals = swVals{iSw}(:).'; end   % vals is 1xK, or 2xK for cOuter
    assert(size(vals,2) <= 16, 'colormap_divergingHue: a swept parameter may have at most 16 values.');
    [cmap, info] = localSweep(swNames{iSw}, vals, hues, wNeutral, wTransition, lNeutral, cOuter, N);
    return
end

assert(wNeutral >= 0 && wTransition >= 0, 'wNeutral and wTransition must be >= 0.');
assert(wNeutral + 2*wTransition <= 2, ...
    'wNeutral + 2*wTransition = %.3f exceeds the colorbar width (2); no room for wings.', ...
    wNeutral + 2*wTransition);

% ---- cache: load a precomputed colormap for these inputs if available --
% Only single (non-swept) calls touch the cache; localSweep/localDemo build directly via
% colorDivergingHueLCH and never write .mat files.
cacheBase = localCacheName(hues, wNeutral, wTransition, lNeutral, cOuter, N);
cacheFile = fullfile(pwd, [cacheBase '.mat']);
loaded = false;
if exist(cacheFile, 'file')
    S = load(cacheFile);
    if isfield(S,'hues') && isequal(S.hues, hues)
        cmap = S.cmap; info = S.info; loaded = true;   % load and use; no recompute
    end
end
if ~loaded
    [cmap, info] = colorDivergingHueLCH(hues, wNeutral, wTransition, lNeutral, cOuter, N);
    save(cacheFile, 'cmap', 'info', 'hues', '-v7');
end

% ---- optional: save a profile panel for THIS colormap ------------------
if plotProfiles
    localPlotCustom(cmap, info, hues, wNeutral, wTransition, lNeutral, cOuter, cacheBase);
end
end

% =======================================================================
function [cmap, info] = localDemo()
% Self-demo, run when colormap_divergingHue is called with no arguments. Builds a figure exercising
% wNeutral/wTransition/lNeutral/cOuter across several "experiments" (hues fixed to blue/red for the
% demo, matching colormap_blueNeutralRed.m's own original demo exactly) and, per experiment (column):
% the colorbar, the L*/C*/hue profiles, and the three ΔE profiles. Returns the baseline colormap as the
% function output.
hues = {[250 300],[340 40]};
N = 256;
x = linspace(-1, 1, N);

%          name, wNeutral, wTransition, lNeutral, cOuter (scalar, or [cInner cOuter])
exps = {
  'baseline',        0.20,        0.20,     0.50, 0.20
  'no flat, sharp',  0.00,        0.20,     0.50, 0.20
  'black neutral',   0.20,        0.20,     0.00, 0.20
  'white neutral',   0.20,        0.20,     1.00, 0.20
  'saturated wings', 0.20,        0.20,     0.50, 1.00
  'pale inner',      0.20,        0.20,     0.50, [0.50 0.20]
  'wide flat+trans', 0.40,        0.40,     0.50, 0.20
};
ne = size(exps,1);

f = figure('MenuBar','none','ToolBar','none','Color','w','Visible','off', ...
           'Units','centimeters','Position',[0 0 5.5*ne 22]);
try, f.Theme = 'light'; catch, end
hT = tiledlayout(f, 5, ne, 'TileSpacing','tight','Padding','tight');

hLeg = gobjects(1,6);
for k = 1:ne
    [nm, wN, wTr, lN, cO] = exps{k,:};
    [ck, ik] = colorDivergingHueLCH(hues, wN, wTr, lN, cO, N);
    if k == 1, cmap = ck; info = ik; end   % baseline is the function output
    ttl = {nm, sprintf('wN=%.2f wTr=%.2f', wN, wTr), ...
           sprintf('lN=%.2f cO=%s', lN, localFmtCOuter(cO)), ...
           sprintf('\\DeltaE=%.0f', ik.innerDeltaE)};
    hh = localPlotColumn(hT, k, ne, x, ck, ik, ttl);
    if k == 1, hLeg = hh; end
end
localProfileLegend(hLeg);
localSavePlot(f, 'colormap_divergingHue_demo.png');
end

% -----------------------------------------------------------------------
function [cmap, info] = localSweep(name, vals, hues, wNeutral, wTransition, lNeutral, cOuter, N)
% Demo-style panel sweeping a single parameter 'name' over 'vals' (at most 16 values), holding the
% others (INCLUDING hues) fixed. Saves to the working directory; returns the first.
% vals is 1xK for the plain numeric knobs and 2xK for a cOuter pair sweep, so it is always indexed
% COLUMN-wise below (vals(:,k) -- a scalar or a [cInner; cOuter] column).
ne = size(vals,2);
x  = linspace(-1, 1, N);
f = figure('MenuBar','none','ToolBar','none','Color','w','Visible','off', ...
           'Units','centimeters','Position',[0 0 5.5*ne 22]);
try, f.Theme = 'light'; catch, end
hT = tiledlayout(f, 5, ne, 'TileSpacing','tight','Padding','tight');

hLeg = gobjects(1,6);
for k = 1:ne
    wN = wNeutral; wTr = wTransition; lN = lNeutral; cO = cOuter;
    v  = vals(:,k).';
    switch name
        case 'wNeutral',    wN  = v;
        case 'wTransition', wTr = v;
        case 'lNeutral',    lN  = v;
        case 'cOuter',      cO  = v;   % 1x2 [cInner cOuter] for a pair sweep
    end
    [ck, ik] = colorDivergingHueLCH(hues, wN, wTr, lN, cO, N);
    if k == 1, cmap = ck; info = ik; end
    if isempty(lN); lNs = '[]'; else; lNs = sprintf('%.2f', lN); end
    if strcmp(name, 'cOuter'); vs = localFmtCOuter(v); else; vs = sprintf('%.4g', v); end
    ttl = {sprintf('%s = %s', name, vs), ...
           sprintf('wN=%.2f wTr=%.2f', wN, wTr), ...
           sprintf('lN=%s cO=%s', lNs, localFmtCOuter(cO)), ...
           sprintf('\\DeltaE=%.0f', ik.innerDeltaE)};
    hh = localPlotColumn(hT, k, ne, x, ck, ik, ttl);
    if k == 1, hLeg = hh; end
end
localProfileLegend(hLeg);
localSavePlot(f, sprintf('colormap_divergingHue_sweep_%s.png', name));
end

% -----------------------------------------------------------------------
function localPlotCustom(cmap, info, hues, wNeutral, wTransition, lNeutral, cOuter, cacheBase)
% Single-column version of the demo panel, for one custom colormap. The PNG shares the input-keyed
% cache base name.
x = linspace(-1, 1, size(cmap,1));
f = figure('MenuBar','none','ToolBar','none','Color','w','Visible','off', ...
           'Units','centimeters','Position',[0 0 16 22]);
try, f.Theme = 'light'; catch, end
hT = tiledlayout(f, 5, 1, 'TileSpacing','tight','Padding','tight');
if isempty(lNeutral)
    lNstr = '[]';
elseif ischar(lNeutral) || (isstring(lNeutral) && isscalar(lNeutral))
    lNstr = char(lNeutral);
else
    lNstr = sprintf('%.2f', lNeutral);
end
ttl = {sprintf('hueA=%s hueB=%s', mat2str(hues{1}), mat2str(hues{2})), ...
       sprintf('wN=%.2f wTr=%.2f', wNeutral, wTransition), ...
       sprintf('lN=%s cO=%s', lNstr, localFmtCOuter(cOuter)), ...
       sprintf('\\DeltaE=%.0f', info.innerDeltaE)};
h = localPlotColumn(hT, 1, 1, x, cmap, info, ttl);
localProfileLegend(h);
localSavePlot(f, [cacheBase '.png'], false);   % silent: per-call cache panel
end

% -----------------------------------------------------------------------
function base = localCacheName(hues, wNeutral, wTransition, lNeutral, cOuter, N)
% Filename base encoding the inputs (used for the .mat cache and profile PNG).
fmt = @(v) strrep(strrep(sprintf('%.4g', v), '.', 'p'), '-', 'm');
fmtHue = @(h) sprintf('%sto%s', fmt(h(1)), fmt(h(2)));
if isempty(lNeutral)
    lNs = 'auto';
elseif ischar(lNeutral) || (isstring(lNeutral) && isscalar(lNeutral))
    lNs = char(lNeutral);
else
    lNs = fmt(lNeutral);
end
% cOuter: bare cO<outer> whenever cInner is 1 (so a scalar and its equivalent [1 v] pair share one
% cache entry, and pre-2026-09-02 .mat files still hit), cO<inner>to<outer> otherwise -- reusing
% fmtHue's own "<lo>to<hi>" convention for a two-valued field.
if isscalar(cOuter) || cOuter(1) == 1
    cOs = fmt(cOuter(end));
else
    cOs = sprintf('%sto%s', fmt(cOuter(1)), fmt(cOuter(2)));
end
base = sprintf('colormap_divergingHue_hA%s_hB%s_wN%s_wTr%s_lN%s_cO%s_N%d', ...
    fmtHue(hues{1}), fmtHue(hues{2}), fmt(wNeutral), fmt(wTransition), lNs, cOs, N);
end

% -----------------------------------------------------------------------
function [isSweep, vals] = localCOuterSweep(cOuter)
% cOuter's own sweep/pair disambiguation -- the one knob where "numel > 1 means sweep" does NOT hold,
% because length 2 is its [cInner cOuter] pair (2026-09-02). Rules (see this file's Sweep-mode header):
%   scalar               -> not a sweep (outer knob only)
%   1x2 / 2x1            -> not a sweep, it's the PAIR   <-- the meaning that CHANGED
%   2xK, K>=2            -> sweep of K pairs, one [cInner; cOuter] per column
%   vector, numel>=3     -> sweep of that many outer knobs, cInner=1 throughout
%   anything else        -> error, rather than guessing which of the two it meant
% vals is returned as 2xK for every sweep case, so localSweep can index it uniformly by column.
vals = [];
if ~isnumeric(cOuter) || numel(cOuter) <= 2
    isSweep = false;                                              % scalar, or the pair
elseif size(cOuter,1) == 2
    isSweep = true;  vals = cOuter;                               % 2xK: explicit pairs
elseif isvector(cOuter)
    isSweep = true;  vals = [ones(1,numel(cOuter)); cOuter(:).']; % K>=3 outer knobs, cInner=1
else
    error('colormap_divergingHue:badCOuterShape', ...
        ['cOuter must be a scalar, a [cInner cOuter] pair, a 2xK matrix of pairs, or a length>=3 ' ...
         'vector of outer knobs -- got %dx%d.'], size(cOuter,1), size(cOuter,2));
end
end

% -----------------------------------------------------------------------
function s = localFmtCOuter(cO)
% cOuter for a panel title: "0.20" for the scalar/outer-only form, "[0.60 0.20]" for a pair.
if numel(cO) == 2; s = sprintf('[%.2f %.2f]', cO(1), cO(2)); else; s = sprintf('%.2f', cO); end
end

% -----------------------------------------------------------------------
function h = localPlotColumn(hT, k, ne, x, ck, ik, titleLines)
% Plot one colormap into column k of a 5-row tiledlayout: colorbar (row 1), L*/C*/hue (rows 2-3), the
% three ΔE profiles (rows 4-5). Returns the 6 line handles (L*, C*, hue, ΔE±v, ΔEcentre, ΔEouter) for
% building a legend.
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
    '\DeltaE: sideB(+v) vs sideA(-v)','\DeltaE: centre vs v','\DeltaE: outer vs v'}, ...
    'Orientation','horizontal');
lg.Layout.Tile = 'south';
end

% -----------------------------------------------------------------------
function localSavePlot(f, name, announce)
% headless-friendly: save a PNG in the working directory. Reports the path for the deliberate
% demo/sweep outputs; stays silent for the per-call cache panel.
if nargin < 3; announce = true; end
outPath = fullfile(pwd, name);
try, exportgraphics(f, outPath, 'Resolution', 150);
     if announce; fprintf('colormap_divergingHue: saved %s\n', outPath); end
catch, end
end
