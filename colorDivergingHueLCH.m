function [cmap, info] = colorDivergingHueLCH(hues, wNeutral, wTransition, lNeutral, cOuter, N)
%COLORDIVERGINGHUELCH  Core, pure builder for a diverging two-hue-plus-neutral colormap in CIE LCH --
%   the generalized math colormap_divergingHue.m/colormap_blueNeutralRed.m both delegate to (neither
%   duplicates it). No caching, no demo, no plotting, no nargin==0 special case -- every argument is
%   REQUIRED (same "pure positional-argument primitive" category as gaussianModel.m/
%   buildIsochromatGrid.m elsewhere in this codebase; a one-off colormap build never needs a
%   StartPoint-style no-arg help listing).
%
%   [cmap, info] = colorDivergingHueLCH(hues, wNeutral, wTransition, lNeutral, cOuter, N)
%
%   hues         1x2 cell, {hueA, hueB} -- each a [lo hi] hue SECTOR in degrees (wraps if lo > hi,
%                same convention as the sector this function searches within for the max-Delta-E,
%                equal-lightness, in-gamut color on that side). hueA is the NEGATIVE-value side, hueB
%                the POSITIVE-value side. E.g. blue/red activation-map convention: {[250 300],[340 40]}.
%   wNeutral     width of the central FLAT neutral zone, in [-1,1] data units,
%                spanning [-wNeutral/2, +wNeutral/2].
%   wTransition  width of EACH linear transition zone (neutral <-> inner colour), in [-1,1] units.
%                  Each wing then has width 1 - wNeutral/2 - wTransition; the two wings together span
%                  2 - (wNeutral + 2*wTransition). Requires wNeutral + 2*wTransition <= 2.
%   lNeutral     lightness of the neutral zone, a 0..1 knob: 0 = black, 1 = white, 0.5 = mid-gray. []
%                matches the inner-edge lightness, so leaving the dead-zone is a pure chroma onset.
%   cOuter       chroma at the OUTER extremes of the wings, a 0..1 knob: 0 = white, 1 = the most
%                saturated colour achievable by BOTH wings (common gamut max, so the wings stay
%                symmetric).
%   N            number of colours.
%
%   info  struct: innerALCH, innerBLCH, outerALCH, outerBLCH [L C H]; innerL, innerDeltaE; flatEdges,
%                 transEdges, wingWidth (data units); Lprofile, Cprofile, Hprofile; and the dE profiles
%                 dEprofile (+v vs -v), dEcentreProfile, dEouterProfile. (Same shape as
%                 colormap_blueNeutralRed.m's own pre-generalization info struct, with
%                 innerBlueLCH/innerRedLCH/outerBlueLCH/outerRedLCH renamed innerALCH/innerBLCH/
%                 outerALCH/outerBLCH -- side A/B rather than a fixed blue/red identity.)
%
%   The 'shape' constant. Within a wing the colour is interpolated from the outer extreme (at the wing
%   tip) to the inner max-separation colour (at the dead-zone edge) as
%   colour = outer + (inner - outer) * s^shape, where s runs 0..1 from the outer tip to the inner edge.
%   shape is thus a gamma on that ramp (see localConsts() below to change it -- hardcoded, not exposed
%   as an input, matching colormap_blueNeutralRed.m's own original design):
%     shape = 1  : straight linear ramp of L* and C* across the wing.
%     shape > 1  : s^shape stays small over most of the wing, so colours hug the OUTER look and swing
%                  to the saturated inner colour only near the dead-zone.
%     shape < 1  : the inner colour spreads across most of the wing, pale outer look confined to the tip.
%
%   Design. The two colours flanking the neutral zone (side-A-inner, side-B-inner) are found by
%   searching the sRGB gamut, WITHIN each side's own hue sector, for the equal-lightness pair with the
%   largest CIELAB Delta-E, so the instant a value leaves the dead-zone its sign is maximally legible.
%   The L* and C* profiles are ALWAYS symmetric across the two wings (equal lightness, equal chroma at
%   both the inner and outer ends); only hue distinguishes the sign, so neither sign dominates.
%
%   Built in CIE LCH and converted via the Colorspace-Transformations tool (same dependency as
%   colormap_bivariateBlackToSpectral.m) -- interpolating L*/C* linearly in LCH space and converting to
%   sRGB only at the very end avoids the "Mach band" artifact a naive RGB lerp through gray produces
%   (see colormap_divergingHue.m's own header for the fuller rationale this generalization was built
%   from, 2026-08-19).
%
%   colorDivergingHueLCH({[250 300],[340 40]}, 0.4, 0.16, [], 0.2, 256)   % blue/red, colormap_blueNeutralRed.m's own defaults
%   colorDivergingHueLCH({[80 140],[260 320]}, 0.4, 0.16, [], 0.2, 256)   % green/violet, a non-activation-map hue pair

    assert(iscell(hues) && numel(hues)==2, 'colorDivergingHueLCH:badHues', ...
        'hues must be a 1x2 cell {hueA, hueB}, each a [lo hi] degree sector -- got %s.', class(hues));
    hueA = hues{1}; hueB = hues{2};
    assert(isequal(size(hueA),[1 2]) && isequal(size(hueB),[1 2]), 'colorDivergingHueLCH:badHueShape', ...
        'each of hues{1}/hues{2} must be a [lo hi] 1x2 vector.');
    assert(wNeutral >= 0 && wTransition >= 0, 'colorDivergingHueLCH:badWidths', ...
        'wNeutral and wTransition must be >= 0.');
    assert(wNeutral + 2*wTransition <= 2, 'colorDivergingHueLCH:widthsTooWide', ...
        'wNeutral + 2*wTransition = %.3f exceeds the colorbar width (2); no room for wings.', ...
        wNeutral + 2*wTransition);
    assert(isscalar(N) && N >= 2, 'colorDivergingHueLCH:badN', 'N must be a scalar >= 2.');

    c = localConsts(); shape = c.shape; gamutN = c.gamutN;

    % ---- dependency (mirrors colormap_bivariateBlackToSpectral.m) -------------
    cleanPath = '';
    if exist('colorspace', 'file') ~= 2
        toolDir = fileparts(mfilename('fullpath'));
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
    [innerALCH, innerBLCH, innerL, ~] = optimiseInnerPair(Lab, hueA, hueB);

    % ---- equalise inner chroma (symmetric wings, always) -------------------
    Cc = min(innerALCH(2), innerBLCH(2));   % common chroma in gamut for both
    innerALCH(2) = Cc; innerBLCH(2) = Cc;
    dE = lchDeltaE(innerALCH, innerBLCH);

    % ---- neutral-zone lightness (0 black .. 1 white; [] -> inner L) ---------
    if isempty(lNeutral); NeutralL = innerL; else; NeutralL = 100 * lNeutral; end

    % ---- common in-gamut chroma envelope of the two hues -------------------
    % Cenv(L) = max chroma reachable by BOTH hues at lightness L. Sharing this single envelope for both
    % wings is what keeps the rendered L*/C* profiles symmetric (neither hue clips where the other does
    % not).
    Lg   = (2:2:98)';
    Cenv = arrayfun(@(LL) min(maxChromaInGamut(LL, innerALCH(3)), ...
                              maxChromaInGamut(LL, innerBLCH(3))), Lg);

    % ---- outer-extreme colours: a COMMON (L*,C*) for both wings ------------
    [outerC, iMax] = max(Cenv); outerL = Lg(iMax);   % most-saturated common point
    oL = 100 + cOuter * (outerL - 100);
    oC =       cOuter *  outerC;
    outerALCH = [oL, oC, innerALCH(3)];
    outerBLCH = [oL, oC, innerBLCH(3)];

    % ---- region boundaries -------------------------------------------------
    % t in [0,1] (colormap index fraction) maps linearly to data [-1,1]: a data width W spans a t-width
    % W/2.
    % [0 .. tWingA] side-A wing | [.. tPlatLo] side-A ramp | [.. tPlatHi] flat neutral
    % | [.. tWingB] side-B ramp | [.. 1] side-B wing
    tPlatLo = 0.5 - wNeutral/4;        % data -wNeutral/2
    tPlatHi = 0.5 + wNeutral/4;        % data +wNeutral/2
    tWingA  = tPlatLo - wTransition/2; % side-A inner edge (max-sep colour)
    tWingB  = tPlatHi + wTransition/2; % side-B inner edge

    t = linspace(0, 1, N)';
    L = zeros(N,1); C = zeros(N,1); H = zeros(N,1);

    isSideAW = t <  tWingA;                       % side-A wing
    isSideAR = t >= tWingA & t < tPlatLo;         % side-A ramp
    isNeut   = t >= tPlatLo & t <= tPlatHi;       % flat plateau
    isSideBR = t >  tPlatHi & t <= tWingB;        % side-B ramp
    isSideBW = t >  tWingB;                        % side-B wing

    % side-A wing: outer -> inner (max-separation colour)
    sA = (t(isSideAW) ./ max(tWingA, eps)) .^ shape;   % 0 outer ... 1 inner
    L(isSideAW) = outerALCH(1) + (innerALCH(1) - outerALCH(1)) .* sA;
    C(isSideAW) = outerALCH(2) + (innerALCH(2) - outerALCH(2)) .* sA;
    H(isSideAW) = innerALCH(3);

    % side-A ramp: inner colour -> neutral (linear)
    rA = (t(isSideAR) - tWingA) ./ max(tPlatLo - tWingA, eps);   % 0 inner ... 1 neutral
    L(isSideAR) = innerALCH(1) + (NeutralL - innerALCH(1)) .* rA;
    C(isSideAR) = innerALCH(2) + (0        - innerALCH(2)) .* rA;
    H(isSideAR) = innerALCH(3);

    % flat neutral plateau
    L(isNeut) = NeutralL; C(isNeut) = 0; H(isNeut) = 0;

    % side-B ramp: neutral -> inner colour (linear)
    rB = (t(isSideBR) - tPlatHi) ./ max(tWingB - tPlatHi, eps);   % 0 neutral ... 1 inner
    L(isSideBR) = NeutralL + (innerBLCH(1) - NeutralL) .* rB;
    C(isSideBR) = 0        + (innerBLCH(2) - 0       ) .* rB;
    H(isSideBR) = innerBLCH(3);

    % side-B wing: inner -> outer
    sB = ((t(isSideBW) - tWingB) ./ max(1 - tWingB, eps)) .^ shape;  % 0 inner ... 1 outer
    L(isSideBW) = innerBLCH(1) + (outerBLCH(1) - innerBLCH(1)) .* sB;
    C(isSideBW) = innerBLCH(2) + (outerBLCH(2) - innerBLCH(2)) .* sB;
    H(isSideBW) = innerBLCH(3);

    % ---- clamp chroma to the common envelope (guarantees symmetry) ---------
    C = min(C, interp1(Lg, Cenv, min(max(L,Lg(1)),Lg(end))));

    % ---- LCH -> sRGB --------------------------------------------------------
    LCH = permute(reshape([L C H], [N 1 3]), [2 1 3]);  % 1 x N x 3
    RGB = colorspace('LCH->RGB', LCH);
    cmap = max(0, min(1, squeeze(RGB)));                % N x 3, gamut-clipped

    % ---- info ---------------------------------------------------------------
    info = struct();
    info.innerALCH = innerALCH;
    info.innerBLCH = innerBLCH;
    info.outerALCH = outerALCH;
    info.outerBLCH = outerBLCH;
    info.innerL       = innerL;
    info.innerDeltaE  = dE;
    info.flatEdges    = [-wNeutral/2, wNeutral/2];          % flat zone, data units
    info.transEdges   = [2*tWingA-1, 2*tWingB-1];           % inner-colour edges, data units
    info.wingWidth    = 1 - wNeutral/2 - wTransition;       % each wing, data units
    LabOut = squeeze(colorspace('RGB->Lab', permute(cmap, [3 1 2])));
    info.Lprofile = LabOut(:,1);
    info.Cprofile = hypot(LabOut(:,2), LabOut(:,3));
    info.Hprofile = mod(atan2d(LabOut(:,3), LabOut(:,2)), 360);   % hue [deg]; meaningless where C*~0
    % ΔE between the side-B(+v) and side-A(-v) colours at matched distance from centre (CIELAB distance
    % of each row to its mirror); symmetric by construction, 0 at the centre, peaking where the two
    % wings are most distinguishable.
    info.dEprofile = sqrt(sum((LabOut - flipud(LabOut)).^2, 2));
    % ΔE between the neutral centre colour and every other point (distance from neutral); symmetric, 0
    % at the centre, growing outward.
    centreLab = [NeutralL, 0, 0];
    info.dEcentreProfile = sqrt(sum((LabOut - centreLab).^2, 2));
    % ΔE between each point and the OUTER extreme of its own side (distance from the extreme, going
    % inward); symmetric, 0 at each outer end, growing inward.
    isLeft = (1:N)' <= N/2;
    dEout  = zeros(N,1);
    dEout(isLeft)  = sqrt(sum((LabOut(isLeft,:)  - LabOut(1,:)).^2, 2));
    dEout(~isLeft) = sqrt(sum((LabOut(~isLeft,:) - LabOut(N,:)).^2, 2));
    info.dEouterProfile = dEout;
end

% =======================================================================
function c = localConsts()
% Hardcoded constants (EDIT HERE to change them) -- gamutN/shape only; hues moved OUT to this
% function's own hues input, no longer hardcoded.
c.shape   = 1;            % L*/C* ramp curvature along each wing (gamma; see header)
c.gamutN  = 41;           % sRGB samples / channel for the gamut search
end

% =======================================================================
function Lab = gamutLab(n)
% Lab coordinates of an n^3 grid sampling of the sRGB cube.
g = linspace(0, 1, n);
[r, gr, b] = ndgrid(g, g, g);
Lab = squeeze(colorspace('RGB->Lab', reshape([r(:) gr(:) b(:)], [], 1, 3)));
end

% -----------------------------------------------------------------------
function [aLCH, bLCH, Lopt, dEopt] = optimiseInnerPair(Lab, hueA, hueB)
% Search the sRGB gamut for the equal-lightness sideA/sideB pair (each within its own hue sector)
% maximising CIELAB Delta-E. Equal lightness keeps the diverging map sign-balanced.
Lc = Lab(:,1); a = Lab(:,2); bb = Lab(:,3);
H  = mod(atan2d(bb, a), 360);
Cc = hypot(a, bb);

isA = localInSector(H, hueA) & Cc > 15;
isB = localInSector(H, hueB) & Cc > 15;
Al = Lab(isA, :);
Bl = Lab(isB, :);
assert(~isempty(Al), 'colorDivergingHueLCH:emptyHueSectorA', ...
    'no in-gamut, sufficiently saturated (chroma>15) colour found in hueA sector [%g %g] -- widen it.', hueA);
assert(~isempty(Bl), 'colorDivergingHueLCH:emptyHueSectorB', ...
    'no in-gamut, sufficiently saturated (chroma>15) colour found in hueB sector [%g %g] -- widen it.', hueB);

Lgrid = floor(min(Lc)) : 1 : ceil(max(Lc));
tol   = 1.5;
dEopt = -inf; aLCH = []; bLCH = []; Lopt = [];
for Lk = Lgrid
    A = Al(abs(Al(:,1) - Lk) <= tol, :);
    B = Bl(abs(Bl(:,1) - Lk) <= tol, :);
    if isempty(A) || isempty(B); continue; end
    for i = 1:size(A,1)
        d = sqrt((B(:,1)-A(i,1)).^2 + (B(:,2)-A(i,2)).^2 + (B(:,3)-A(i,3)).^2);
        [dm, j] = max(d);
        if dm > dEopt
            dEopt = dm; Lopt = Lk;
            aLCH = lab2lch(A(i,:), Lk);
            bLCH = lab2lch(B(j,:), Lk);
        end
    end
end
assert(~isempty(aLCH), 'colorDivergingHueLCH:noSeparationFound', ...
    'no shared lightness level found between hueA/hueB sectors -- widen the sectors or check for overlap.');
end

% -----------------------------------------------------------------------
function c = maxChromaInGamut(L, hue)
% Largest chroma C such that LCH(L,C,hue) lies inside sRGB (bisection).
% NOTE: colorspace('LCH->RGB',..) clips out-of-gamut RGB to [0,1], so a plain range check is useless.
% Instead round-trip LCH->RGB->Lab and require the chroma to survive: if it was clipped, the recovered
% chroma is smaller.
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
