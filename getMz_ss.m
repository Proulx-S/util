function [Mz_ss,pMri,Mz_ss_v0,Mz_ss_max,Mo,vel] = getMz_ss(pMri,pRelax,vel,Mo)
% getMz_ss.m  Steady-state longitudinal magnetization for GRE/FLASH (Bianciardi et al. 2016 for moving spins).
%
% For moving spins, Mz_ss is the average Mz over the slice column just before an RF pulse (what a
% voxel spanning the slice measures), for plug flow perpendicular to a rectangular slice profile,
% at any velocity (exact also for non-integer vCrit/vel). Derivation and validation:
% docs/inflowColumnAverage.md, tests/test_getMz_ss.m.
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

pMri.vCrit = 0.1.*pMri.sliceThickness./pMri.TR; % cm/s
if nargout>2  ||  ( exist('vel','var') && ~isempty(vel) )
    if ~exist('vel','var') || isempty(vel)
        u   = flip(2:2^10); % number of RF seen by a spin
        vel = pMri.vCrit./[u 1 0.75];
    end
    % Moving spins (Bianciardi et al. 2016)    
    if exist('vel','var') && ~isempty(vel)
        vel = abs(vel);

        regime = ones(size(vel));
        regime(vel==0    ) = 1; % regime 1: stationary spins
        regime(vel> 0    ) = 2; % regime 2: moving spins below critical velocity
        regime(vel>=pMri.vCrit) = 3; % regime 3: moving spins above critical velocity
        % regime 1
        Mz_ss_v0         = Mz_ss;
        Mz_ss            = nan(size(vel));
        Mz_ss(regime==1) = Mz_ss_v0;
        % regime 2: average over the slice column (plug flow perpendicular to a rectangular slice).
        % A spin at depth z into the slice has seen m = floor(z/(vel*TR)) earlier pulses; spins are
        % uniform in z, so with U = vCrit/vel (not necessarily an integer) and K = floor(U):
        %   <Q1^m> = [ (1-Q1^K)/(1-Q1) + (U-K)*Q1^K ] / U
        % For integer U this is Bianciardi et al. 2016 eq. 2.4, (1-Q1^U)/(U*(1-Q1)), i.e. the
        % average over velocity segments that have seen 1..U pulses (Brown et al. 2014, eq. 24.9).
        % Rounding U (previously ceil) is exact only at integer U; see docs/inflowColumnAverage.md.
        U = pMri.vCrit ./ vel(regime==2);
        K = floor(U);
        f = ( (1 - pMri.Q1.^K)./(1 - pMri.Q1) + (U - K).*pMri.Q1.^K ) ./ U;
        Mz_ss(regime==2) = Mz_ss_v0 + (Mo-Mz_ss_v0) .* f;
        % regime 3
        Mz_ss_max        = Mo;
        Mz_ss(regime==3) = Mz_ss_max;
    else
        Mz_ss_v0  = [];
        Mz_ss_max = [];
    end
end
