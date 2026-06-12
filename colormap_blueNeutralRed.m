function [cmap, info] = colormap_blueNeutralRed(wNeutral, wTransition, lNeutral, cOuter, N, plotProfiles)
%COLORMAP_BLUENEUTRALRED  Diverging blue-neutral-red map with a controllable
%   neutral dead-zone and maximal perceptual separation between the inner
%   edges of the two coloured wings.
%
%   [cmap, info] = colormap_blueNeutralRed(wNeutral, wTransition, lNeutral, cOuter, N, plotProfiles)
%
%   All arguments are optional and positional; pass [] to keep a default.
%   The colorbar is taken to span [-1, 1] (total width 2). Widths are in those
%   data units:
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
%   shape, blueHue, redHue and gamutN are HARDCODED constants (see the
%   localConsts() helper at the bottom of the file); edit them there if needed.
%   shape is explained below.
%
%   info  struct: innerBlueLCH, innerRedLCH, outerBlueLCH, outerRedLCH [L C H];
%                 innerL, innerDeltaE; flatEdges, transEdges, wingWidth (data
%                 units); Lprofile, Cprofile, Hprofile; and the dE profiles
%                 dEprofile (+v vs -v), dEcentreProfile, dEouterProfile.
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
%   (same dependency as colormap_bivariateBlackToSpectral).

% ---- self-demo when called with no arguments (demo code at end of file) -
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
% Hardcoded constants (EDIT HERE to change them). Stored in each cache .mat and
% checked on load, so editing one invalidates stale caches automatically.
c.shape   = 1;            % L*/C* ramp curvature along each wing (gamma; see header)
c.blueHue = [250 300];    % blue hue search sector [deg]
c.redHue  = [340 40];     % red  hue search sector [deg] (wraps through 0)
c.gamutN  = 41;           % sRGB samples / channel for the gamut search
end

% =======================================================================
function [cmap, info] = localBuild(wNeutral, wTransition, lNeutral, cOuter, N)
% Core construction: gamut search + CIE-LCH ramp + profiles. No caching, no
% plotting -- this is what localSweep/localDemo call directly.
c = localConsts(); shape = c.shape; blueHue = c.blueHue; redHue = c.redHue; gamutN = c.gamutN;

% ---- dependency (mirrors colormap_bivariateBlackToSpectral) -------------
cleanPath = '';
if exist('colorspace', 'file') ~= 2
    toolDir = fileparts(fileparts(mfilename('fullpath')));
    tool    = 'Colorspace-Transformations';
    toolURL = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/28790/versions/5/download/zip';
    if ~exist(fullfile(toolDir, tool), 'dir')
        tmpZip = fullfile(tempdir, 'colorspace.zip');
        websave(tmpZip, toolURL); unzip(tmpZip, fullfile(toolDir, tool)); delete(tmpZip);
    end
    cleanPath = genpath(fullfile(toolDir, tool));
    addpath(cleanPath);
end
cleanup = onCleanup(@() localRmpath(cleanPath)); %#ok<NASGU>

% ---- sRGB gamut sample (shared by the searches below) ------------------
Lab = gamutLab(gamutN);

% ---- max-separation equal-lightness inner pair -------------------------
[innerBlueLCH, innerRedLCH, innerL, dE] = optimiseInnerPair(Lab, blueHue, redHue);

% ---- equalise inner chroma (symmetric wings, always) -------------------
Cc = min(innerBlueLCH(2), innerRedLCH(2));   % common chroma in gamut for both
innerBlueLCH(2) = Cc; innerRedLCH(2) = Cc;
dE = lchDeltaE(innerBlueLCH, innerRedLCH);

% ---- neutral-zone lightness (0 black .. 1 white; [] -> inner L) ---------
if isempty(lNeutral); NeutralL = innerL; else; NeutralL = 100 * lNeutral; end

% ---- common in-gamut chroma envelope of the two hues -------------------
% Cenv(L) = max chroma reachable by BOTH the blue and the red hue at lightness
% L. Sharing this single envelope for both wings is what keeps the rendered
% L*/C* profiles symmetric (neither hue clips where the other does not).
Lg   = (2:2:98)';
Cenv = arrayfun(@(LL) min(maxChromaInGamut(LL, innerBlueLCH(3)), ...
                          maxChromaInGamut(LL, innerRedLCH(3))), Lg);

% ---- outer-extreme colours: a COMMON (L*,C*) for both wings ------------
[outerC, iMax] = max(Cenv); outerL = Lg(iMax);   % most-saturated common point
oL = 100 + cOuter * (outerL - 100);
oC =       cOuter *  outerC;
outerBlueLCH = [oL, oC, innerBlueLCH(3)];
outerRedLCH  = [oL, oC, innerRedLCH(3)];

% ---- region boundaries -------------------------------------------------
% t in [0,1] (colormap index fraction) maps linearly to data [-1,1]: a data
% width W spans a t-width W/2.
% [0 .. tWingB] blue wing | [.. tPlatLo] blue ramp | [.. tPlatHi] flat neutral
% | [.. tWingR] red ramp | [.. 1] red wing
tPlatLo = 0.5 - wNeutral/4;        % data -wNeutral/2
tPlatHi = 0.5 + wNeutral/4;        % data +wNeutral/2
tWingB  = tPlatLo - wTransition/2; % blue inner edge (max-sep colour)
tWingR  = tPlatHi + wTransition/2; % red  inner edge

t = linspace(0, 1, N)';
L = zeros(N,1); C = zeros(N,1); H = zeros(N,1);

isBlueW = t <  tWingB;                       % blue wing
isBlueR = t >= tWingB & t < tPlatLo;         % blue ramp
isNeut  = t >= tPlatLo & t <= tPlatHi;       % flat plateau
isRedR  = t >  tPlatHi & t <= tWingR;        % red ramp
isRedW  = t >  tWingR;                        % red wing

% blue wing: outer -> inner (max-separation colour)
sB = (t(isBlueW) ./ max(tWingB, eps)) .^ shape;   % 0 outer ... 1 inner
L(isBlueW) = outerBlueLCH(1) + (innerBlueLCH(1) - outerBlueLCH(1)) .* sB;
C(isBlueW) = outerBlueLCH(2) + (innerBlueLCH(2) - outerBlueLCH(2)) .* sB;
H(isBlueW) = innerBlueLCH(3);

% blue ramp: inner colour -> neutral (linear)
rB = (t(isBlueR) - tWingB) ./ max(tPlatLo - tWingB, eps);   % 0 inner ... 1 neutral
L(isBlueR) = innerBlueLCH(1) + (NeutralL - innerBlueLCH(1)) .* rB;
C(isBlueR) = innerBlueLCH(2) + (0        - innerBlueLCH(2)) .* rB;
H(isBlueR) = innerBlueLCH(3);

% flat neutral plateau
L(isNeut) = NeutralL; C(isNeut) = 0; H(isNeut) = 0;

% red ramp: neutral -> inner colour (linear)
rR = (t(isRedR) - tPlatHi) ./ max(tWingR - tPlatHi, eps);   % 0 neutral ... 1 inner
L(isRedR) = NeutralL + (innerRedLCH(1) - NeutralL) .* rR;
C(isRedR) = 0        + (innerRedLCH(2) - 0       ) .* rR;
H(isRedR) = innerRedLCH(3);

% red wing: inner -> outer
sR = ((t(isRedW) - tWingR) ./ max(1 - tWingR, eps)) .^ shape;  % 0 inner ... 1 outer
L(isRedW) = innerRedLCH(1) + (outerRedLCH(1) - innerRedLCH(1)) .* sR;
C(isRedW) = innerRedLCH(2) + (outerRedLCH(2) - innerRedLCH(2)) .* sR;
H(isRedW) = innerRedLCH(3);

% ---- clamp chroma to the common envelope (guarantees symmetry) ---------
% Both wings share L and the clamped C, so they render identically up to hue.
C = min(C, interp1(Lg, Cenv, min(max(L,Lg(1)),Lg(end))));

% ---- LCH -> sRGB --------------------------------------------------------
LCH = permute(reshape([L C H], [N 1 3]), [2 1 3]);  % 1 x N x 3
RGB = colorspace('LCH->RGB', LCH);
cmap = max(0, min(1, squeeze(RGB)));                % N x 3, gamut-clipped

% ---- info ---------------------------------------------------------------
info = struct();
info.innerBlueLCH = innerBlueLCH;
info.innerRedLCH  = innerRedLCH;
info.outerBlueLCH = outerBlueLCH;
info.outerRedLCH  = outerRedLCH;
info.innerL       = innerL;
info.innerDeltaE  = dE;
info.flatEdges    = [-wNeutral/2, wNeutral/2];          % flat zone, data units
info.transEdges   = [2*tWingB-1, 2*tWingR-1];           % inner-colour edges, data units
info.wingWidth    = 1 - wNeutral/2 - wTransition;       % each wing, data units
LabOut = squeeze(colorspace('RGB->Lab', permute(cmap, [3 1 2])));
info.Lprofile = LabOut(:,1);
info.Cprofile = hypot(LabOut(:,2), LabOut(:,3));
info.Hprofile = mod(atan2d(LabOut(:,3), LabOut(:,2)), 360);   % hue [deg]; meaningless where C*~0
% ΔE between the red(+v) and blue(-v) colours at matched distance from centre
% (CIELAB distance of each row to its mirror); symmetric by construction, 0 at
% the centre, peaking where the two wings are most distinguishable.
info.dEprofile = sqrt(sum((LabOut - flipud(LabOut)).^2, 2));
% ΔE between the neutral centre colour and every other point (distance from
% neutral); symmetric, 0 at the centre, growing outward.
centreLab = [NeutralL, 0, 0];
info.dEcentreProfile = sqrt(sum((LabOut - centreLab).^2, 2));
% ΔE between each point and the OUTER extreme of its own side (distance from
% the extreme, going inward); symmetric, 0 at each outer end, growing inward.
isLeft = (1:N)' <= N/2;
dEout  = zeros(N,1);
dEout(isLeft)  = sqrt(sum((LabOut(isLeft,:)  - LabOut(1,:)).^2, 2));
dEout(~isLeft) = sqrt(sum((LabOut(~isLeft,:) - LabOut(N,:)).^2, 2));
info.dEouterProfile = dEout;
end

% =======================================================================
function Lab = gamutLab(n)
% Lab coordinates of an n^3 grid sampling of the sRGB cube.
g = linspace(0, 1, n);
[r, gr, b] = ndgrid(g, g, g);
Lab = squeeze(colorspace('RGB->Lab', reshape([r(:) gr(:) b(:)], [], 1, 3)));
end

% -----------------------------------------------------------------------
function [blueLCH, redLCH, Lopt, dEopt] = optimiseInnerPair(Lab, blueHue, redHue)
% Search the sRGB gamut for the equal-lightness blue/red pair maximising
% CIELAB Delta-E. Equal lightness keeps the diverging map sign-balanced.
Lc = Lab(:,1); a = Lab(:,2); bb = Lab(:,3);
H  = mod(atan2d(bb, a), 360);
Cc = hypot(a, bb);

isBlue = localInSector(H, blueHue) & Cc > 15;
isRed  = localInSector(H, redHue)  & Cc > 15;
Bl = Lab(isBlue, :);
Rl = Lab(isRed,  :);

Lgrid = floor(min(Lc)) : 1 : ceil(max(Lc));
tol   = 1.5;
dEopt = -inf; blueLCH = []; redLCH = []; Lopt = [];
for Lk = Lgrid
    B = Bl(abs(Bl(:,1) - Lk) <= tol, :);
    R = Rl(abs(Rl(:,1) - Lk) <= tol, :);
    if isempty(B) || isempty(R); continue; end
    for i = 1:size(B,1)
        d = sqrt((R(:,1)-B(i,1)).^2 + (R(:,2)-B(i,2)).^2 + (R(:,3)-B(i,3)).^2);
        [dm, j] = max(d);
        if dm > dEopt
            dEopt = dm; Lopt = Lk;
            blueLCH = lab2lch(B(i,:), Lk);
            redLCH  = lab2lch(R(j,:), Lk);
        end
    end
end
end

% -----------------------------------------------------------------------
function c = maxChromaInGamut(L, hue)
% Largest chroma C such that LCH(L,C,hue) lies inside sRGB (bisection).
% NOTE: colorspace('LCH->RGB',..) clips out-of-gamut RGB to [0,1], so a plain
% range check is useless. Instead round-trip LCH->RGB->Lab and require the
% chroma to survive: if it was clipped, the recovered chroma is smaller.
lo = 0; hi = 150;
for it = 1:24
    mid = (lo + hi) / 2;
    rgb = colorspace('LCH->RGB', reshape([L mid hue], [1 1 3]));
    lab = colorspace('RGB->Lab', rgb);
    crec = hypot(lab(2), lab(3));
    if abs(crec - mid) < 0.5; lo = mid; else; hi = mid; end
end
c = lo;
end

% -----------------------------------------------------------------------
function dE = lchDeltaE(lch1, lch2)
a1 = lch1(2)*cosd(lch1(3)); b1 = lch1(2)*sind(lch1(3));
a2 = lch2(2)*cosd(lch2(3)); b2 = lch2(2)*sind(lch2(3));
dE = sqrt((lch1(1)-lch2(1))^2 + (a1-a2)^2 + (b1-b2)^2);
end

% -----------------------------------------------------------------------
function lch = lab2lch(lab, Lforce)
% Lab row -> [L C H], with L pinned to the shared lightness Lforce.
lch = [Lforce, hypot(lab(2), lab(3)), mod(atan2d(lab(3), lab(2)), 360)];
end

% -----------------------------------------------------------------------
function tf = localInSector(h, sec)
% true where hue h (deg) falls in sector [lo hi], handling wrap (lo > hi).
lo = sec(1); hi = sec(2);
if lo <= hi; tf = h >= lo & h <= hi; else; tf = h >= lo | h <= hi; end
end

% -----------------------------------------------------------------------
function localRmpath(pth)
if ~isempty(pth); rmpath(pth); end
end

% =======================================================================
% Self-demo, run when colormap_blueNeutralRed is called with no arguments.
% Builds a figure exercising the parameters across several "experiments" and,
% per experiment (column): the colorbar, the L*/C*/hue profiles, and the three
% ΔE profiles. Returns the baseline colormap as the function output.
% =======================================================================
function [cmap, info] = localDemo()
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
