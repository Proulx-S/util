function [Mz_ss,pMri,Mz_ss_v0,Mz_ss_max,Mo,vel] = getMz_ss(pMri,pRelax,vel,Mo)
% getMz_ss.m  Steady-state longitudinal magnetization for GRE/FLASH (Bianciardi et al. 2016 for moving spins).
%
% INFLOW MODEL VERSION: staircase -- KNOWN ERROR, kept unchanged on this branch for reproducibility.
%   For 0 < vel < vCrit, regime 2 evaluates Bianciardi et al. 2016 eq. 2.4, (1-Q1^u)/(u*(1-Q1)), at
%   u = ceil(vCrit/vel), also for the default velocity sweep used when vel is omitted. That is exact
%   only when vCrit/vel is an integer; between integers it over-saturates (by up to 12 % of the inflow excess
%   at FA 40 deg, 49 % at 90 deg) and makes Mz(vel) a staircase. The exact slice-column average,
%   <Q1^m> = [(1-Q1^K)/(1-Q1) + (U-K)*Q1^K]/U with U = vCrit/vel and K = floor(U), piecewise linear
%   in vel, is on the util errata branches (errata, Miller2026-errata, dev-inflow-errata,
%   dev-postISMRM-errata) and is recommended. See util issue #15.
%
% REFERENCES
%   Bianciardi M, Toschi N, Polimeni JR, et al. (2016) The pulsatility volume index: an indicator of
%     cerebrovascular compliance based on fast magnetic resonance imaging of cardiac and respiratory
%     pulsatility. Phil Trans R Soc A 374:20150184. doi:10.1098/rsta.2015.0184
%     (three-regime formulation; eq. 2.4, derived for integer vCrit/vel)
%   Gullberg GT, Simons MA, Wehrli FW (1988) A mathematical model for signal from spins flowing during
%     the application of spin echo pulse sequences. Magn Reson Imaging 6:437-461.
%     doi:10.1016/0730-725X(88)90481-X (fractional-volume method)
%   Gao J-H, Holland SK, Gore JC (1988) Nuclear magnetic resonance signal from flowing nuclei in rapid
%     imaging using gradient echoes. Med Phys 15:809-814. doi:10.1118/1.596197
%     (that method for spoiled FLASH: exact for non-integer vCrit/vel, sec. III.A, eq. 26)
%   Comparison of the four inflow versions (2026-11-06; private repo, the label above stands on its own):
%   https://github.com/Proulx-S/microscopyValidation/blob/9057997d65a96cad63419fed24daa1ba885ed6c6/docs/inflowBetweenIntegerPulseCounts.md
%
% INPUTS
%   pMri   - MRI acquisition struct. Required fields: TR, FA; and either (E1, q) or provide pRelax.
%            When vel is used: sliceThickness is also required.
%   pRelax - (optional) Relaxation struct with field T1 [s]. Used to set (and overide) pMri.E1 and pMri.Q1.
%   vel    - (optional) Velocity [cm/s], scalar or array. If given, Mz_ss is computed per velocity
%            (stationary, below/above critical velocity). Omit or [] for stationary-spin result only.
%   Mo     - (optional) Equilibrium magnetization. Default 1.
%
% OUTPUTS
%   Mz_ss     - Steady-state longitudinal magnetization. Scalar if vel not given; otherwise same size as vel.
%   pMri      - Same struct with E1 and q updated (from pRelax when provided).
%   Mz_ss_v0  - (optional) Mz_ss for stationary spins (vel=0). Set only when nargout > 2 and vel is given.
%   Mz_ss_max - (optional) Maximum Mz_ss (= Mo), for spins above critical velocity. Set only when nargout > 2 and vel is given.
%   Mo        - Equilibrium magnetization used (1 or input Mo).
%
%%% Precompute parameters %%%
% Force an update of longitudinal relaxation factor E1 and RF saturation factor q, if pRelax is provided
if exist('pRelax','var') && ~isempty(pRelax) && isfield(pRelax,'T1') && ~isempty(pRelax.T1)
    pMri.E1 = exp(-pMri.TR / pRelax.T1);
    pMri.Q1 = pMri.E1 * cosd(pMri.FA);
elseif ~isfield(pMri,'E1') || isempty(pMri.E1)
    error(['E1 not found in pMri' newline 'provide pRelax input']);
end
% Set equilibrium magnetization Mo to 1 if not provided
if ~exist('Mo','var') || isempty(Mo)
    Mo = 1;
end

%%% Compute steady-state longitudinal magnetization Mz_ss %%%
% Stationary spins (vel=0)
Mz_ss = Mo * (1 - pMri.E1) / (1 - pMri.Q1);

if nargout>2  ||  ( exist('vel','var') && ~isempty(vel) )
    if ~exist('vel','var') || isempty(vel)
        if ~isfield(pMri,'vCrit') || isempty(pMri.vCrit)
            pMri.vCrit = 0.1.*pMri.sliceThickness./pMri.TR;
        end
        vel = linspace(0, pMri.vCrit+40*pMri.vCrit/32, 34);
    end
    % Moving spins (Bianciardi et al. 2016)    
    if exist('vel','var') && ~isempty(vel)
        vel = abs(vel);

        pMri.vCrit  = pMri.sliceThickness / pMri.TR  /10; % [cm/s]
        regime = ones(size(vel));
        regime(vel==0    ) = 1; % regime 1: stationary spins
        regime(vel> 0    ) = 2; % regime 2: moving spins below critical velocity
        regime(vel>=pMri.vCrit) = 3; % regime 3: moving spins above critical velocity
        % regime 1
        Mz_ss_v0         = Mz_ss;
        Mz_ss            = nan(size(vel));
        Mz_ss(regime==1) = Mz_ss_v0;
        % regime 2
        u = ceil(pMri.vCrit ./ vel(regime==2)); % reflects number of RF seen by a spin
        Mz_ss(regime==2) = Mz_ss_v0 + (Mo-Mz_ss_v0) .* (1 - pMri.Q1.^u)  ./  (u.*(1-pMri.Q1));
                        % %possible AI-proposed simplification...
                        % fMax = 1 / Mz_ss_v0;
                        % f = (1 - pMri.Q1.^u) ./ (u * (1 - pMri.Q1));
                        % f = min(1, max(0, f));
                        % f(vel >= pMri.vCrit) = 1;
                        % f(vel <= 0)  = 0;
                        % f = 1 + f .* (fMax - 1);
                        % Mz_ss_v0*f
        % regime 3
        Mz_ss_max        = Mo;
        Mz_ss(regime==3) = Mz_ss_max;
    else
        Mz_ss_v0  = [];
        Mz_ss_max = [];
    end
end
