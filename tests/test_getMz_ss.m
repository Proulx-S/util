function results = test_getMz_ss(verbose)
% test_getMz_ss  Validate the moving-spin (inflow) branch of getMz_ss against a pulse-by-pulse simulation.
%
%   results = test_getMz_ss        % prints a table, errors if a check fails
%   results = test_getMz_ss(false) % quiet
%
% Reference ("truth"): spins flow at constant velocity v through a rectangular slice [0, TH),
% entering fully relaxed (M0) through z = 0; RF pulses every TR. For each spin in the slice at a
% late pulse, the number of pulses it has already received is counted from its entry time, and its
% Mz is evolved explicitly, pulse by pulse (Mz <- Mz*cos(FA)*E1 + M0*(1-E1)). The column average of
% Mz just before that pulse is what a voxel spanning the slice measures (times sin(FA)*E2).
%
% Checks
%   1. getMz_ss matches the pulse-by-pulse column average for integer and non-integer vCrit/v.
%   2. At integer vCrit/v it equals Bianciardi et al. 2016 eq. 2.4.
%   3. At FA = 90 deg it is linear in v (Bianciardi et al. 2016 eq. 2.6).
%   4. It is continuous in v (no steps), and tends to Mz(v=0) as v -> 0 and to M0 as v -> vCrit.
%   5. The no-velocity call (default velocity list) is unchanged.
% See docs/inflowColumnAverage.md.

if ~exist('verbose','var') || isempty(verbose); verbose = true; end
tolTruth = 2e-5;   % [M0] absolute; the reference's stratified-sampling error is < (#segment edges)/nSpin
results  = struct();

% Target protocol (vesTrack example data: 7 T, 2D spoiled GRE) and Bianciardi et al. 2016 expt 1
protocols(1) = struct('name','7T fl2d1 (TR 8.4 ms, FA 40)', 'TR',8.4e-3, 'FA',40, 'sliceThickness',1.2, 'T1',2.58);
protocols(2) = struct('name','Bianciardi 2016 (TR 33 ms, FA 90)', 'TR',33e-3, 'FA',90, 'sliceThickness',1.2, 'T1',2.5);
protocols(3) = struct('name','low FA (TR 20 ms, FA 10)', 'TR',20e-3, 'FA',10, 'sliceThickness',2.0, 'T1',1.6);

for iP = 1:numel(protocols)
    P = protocols(iP);
    pMri = struct('TR',P.TR,'FA',P.FA,'sliceThickness',P.sliceThickness);
    pRelax = struct('T1',P.T1);
    [Mss, pMri] = getMz_ss(pMri, pRelax);
    vCrit = 0.1*P.sliceThickness/P.TR; % [cm/s]

    % --- 1. against the pulse-by-pulse reference -------------------------------------------
    frac  = [0.03 0.05 0.1 0.2 0.3 1/3 0.45 0.5 0.6 0.7 0.9 0.99 1 1.5 2];
    vel   = frac*vCrit;
    Mz    = getMz_ss(pMri, pRelax, vel);
    truth = arrayfun(@(v) columnTruth(v, P), vel);
    errEx = abs(Mz - truth) ./ max(truth - Mss, eps);   % error relative to the inflow excess (reported)
    assert(all(abs(Mz - truth) < tolTruth), 'test_getMz_ss:truth', ...
        '%s: getMz_ss differs from the pulse-by-pulse column average (max %.2g M0)', P.name, max(abs(Mz - truth)));

    % --- 2. integer vCrit/v: Bianciardi eq. 2.4 ----------------------------------------------
    u   = [2 3 5 10 37 100];
    Mzu = getMz_ss(pMri, pRelax, vCrit./u);
    bia = Mss + (1-Mss).*(1 - pMri.Q1.^u)./(u.*(1 - pMri.Q1));
    assert(max(abs(Mzu - bia)) < 1e-12, 'test_getMz_ss:bianciardi', '%s: integer-U case differs from eq. 2.4', P.name);

    % --- 3. FA = 90: linear in v (q = 0) ------------------------------------------------------
    if P.FA == 90
        vv  = linspace(0.01, 0.99, 50)*vCrit;
        lin = Mss + (1-Mss).*vv/vCrit;
        assert(max(abs(getMz_ss(pMri, pRelax, vv) - lin)) < 1e-12, 'test_getMz_ss:linear', '%s: not linear at FA=90', P.name);
    end

    % --- 4. continuity (no step where vCrit/v crosses an integer) and limits ---------------------
    k     = 2:50;  d = 1e-9;
    vLo   = vCrit./(k + d);  vHi = vCrit./(k - d);          % just slower / just faster than vCrit/k
    jump  = max(abs(getMz_ss(pMri,pRelax,vHi) - getMz_ss(pMri,pRelax,vLo)));
    jumpCeil = max(abs(ceilVersion(vHi,vCrit,Mss,pMri.Q1) - ceilVersion(vLo,vCrit,Mss,pMri.Q1)));
    assert(jump < 1e-6, 'test_getMz_ss:continuity', '%s: step of %.3g in Mz(v) at integer vCrit/v', P.name, jump);
    assert(abs(getMz_ss(pMri,pRelax,1e-6*vCrit) - Mss) < 1e-3*(1-Mss), 'test_getMz_ss:limit0', '%s: v->0 limit', P.name);
    assert(abs(getMz_ss(pMri,pRelax,(1-1e-9)*vCrit) - 1) < 1e-6, 'test_getMz_ss:limitVc', '%s: v->vCrit limit', P.name);

    % --- 5. default velocity list unchanged ---------------------------------------------------
    [MzDef,~,~,~,~,velDef] = getMz_ss(pMri, pRelax);
    uDef  = pMri.vCrit./velDef;
    expct = ones(size(velDef));
    reg2  = uDef > 1;
    expct(reg2) = Mss + (1-Mss).*(1 - pMri.Q1.^round(uDef(reg2)))./(round(uDef(reg2)).*(1 - pMri.Q1));
    assert(max(abs(MzDef - expct)) < 1e-9, 'test_getMz_ss:default', '%s: default velocity list changed', P.name);

    % --- report --------------------------------------------------------------------------------
    errCeil = abs(ceilVersion(vel, vCrit, Mss, pMri.Q1) - truth) ./ max(truth - Mss, eps);
    results(iP).name      = P.name;
    results(iP).frac      = frac;
    results(iP).truth     = truth;
    results(iP).getMz_ss  = Mz;
    results(iP).errExcess = errEx;
    results(iP).errExcessCeil = errCeil;
    results(iP).maxStep   = jump;
    results(iP).maxStepCeil = jumpCeil;
    if verbose
        fprintf('\n%s  (Q1 = %.4f, Mz(v=0) = %.4f, vCrit = %.2f cm/s)\n', P.name, pMri.Q1, Mss, vCrit);
        fprintf('  v/vCrit   truth    getMz_ss  |err|/excess   previous ceil(u): |err|/excess\n');
        for k = 1:numel(frac)
            fprintf('  %6.3f   %7.4f   %7.4f   %9.1e      %9.1e\n', frac(k), truth(k), Mz(k), errEx(k), errCeil(k));
        end
        fprintf('  largest step in Mz(v) where vCrit/v crosses an integer (2..50): %.1e (previous ceil(u): %.3f)\n', jump, jumpCeil);
    end
end
if verbose; fprintf('\ntest_getMz_ss: all checks passed\n'); end
end


function Mbar = columnTruth(v, P)
% Pulse-by-pulse column average of Mz just before a pulse (M0 = 1), plug flow at v [cm/s].
nSpin = 200003;                               % prime, so segment edges never align with the samples
E1  = exp(-P.TR/P.T1);
vmm = 10*v;                                   % [mm/s]
tTransit = P.sliceThickness/vmm;              % [s] time to cross the slice
nPulse   = ceil(tTransit/P.TR) + 3;           % observe just before pulse nPulse (pulses at k*TR)
tObs     = nPulse*P.TR;
tEntry   = tObs - ((1:nSpin) - 0.5)/nSpin*tTransit;   % stratified: spins uniform in depth
nPrior   = nPulse - floor(tEntry/P.TR) - 1;   % pulses at k*TR with tEntry < k*TR < tObs
Mz = ones(1, nSpin);
for k = 1:max(nPrior)
    hit = nPrior >= k;
    Mz(hit) = Mz(hit)*cosd(P.FA)*E1 + (1 - E1);
end
Mbar = mean(Mz);
end


function Mz = ceilVersion(vel, vCrit, Mss, Q1)
% The previous implementation (u = ceil(vCrit/vel)), kept here only for comparison.
Mz = ones(size(vel));
in = vel > 0 & vel < vCrit;
u  = ceil(vCrit./vel(in));
Mz(in) = Mss + (1-Mss).*(1 - Q1.^u)./(u.*(1 - Q1));
Mz(vel == 0) = Mss;
end
