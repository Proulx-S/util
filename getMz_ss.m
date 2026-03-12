function [Mz_ss,pMri,Mz_ss_v0,Mx_ss_max,Mo] = getMz_ss(pMri,pRelax,vel,Mo)
    
%%% Precompute parameters %%%
% Force an update of longitudinal relaxation factor E1 and RF saturation factor q, if pRelax is provided
if exist('pRelax','var') && ~isempty(pRelax) && isfield(pRelax,'T1') && ~isempty(pRelax.T1)
    pMri.E1 = exp(-pMri.TR / pRelax.T1);
    pMri.q  = pMri.E1 * cosd(pMri.FA);
elseif ~isfield(pMri,'E1') || isempty(pMri.E1)
    error(['E1 not found in pMri' newline 'provide pRelax input']);
end
% Set equilibrium magnetization Mo to 1 if not provided
if ~exist('Mo','var') || isempty(Mo)
    Mo = 1;
end

%%% Compute steady-state longitudinal magnetization Mz_ss %%%
% Stationary spins (vel=0)
Mz_ss = Mo * (1 - pMri.E1) / (1 - pMri.q);

if nargout>2
    % Moving spins (Bianciardi et al. 2016)
    if exist('vel','var') && ~isempty(vel)
        vCrit  = pMri.sliceThickness / pMri.TR  /10; % [cm/s]
        regime = ones(size(vel));
        regime(vel==0    ) = 1; % regime 1: stationary spins
        regime(vel> 0    ) = 2; % regime 2: moving spins below critical velocity
        regime(vel>=vCrit) = 3; % regime 3: moving spins above critical velocity
        % regime 1
        Mz_ss_v0         = Mz_ss;
        Mz_ss            = nan(size(vel));
        Mz_ss(regime==1) = Mz_ss_v0;
        % regime 2
        u = vCrit ./ vel(regime==2);
        Mz_ss(regime==2) = Mz_ss_v0 + (Mo-Mz_ss_v0) .* (1 - pMri.q.^u)  ./  (u.*(1-pMri.q));
                        % %possible AI-proposed simplification...
                        % fMax = 1 / Mz_ss_v0;
                        % f = (1 - pMri.q.^u) ./ (u * (1 - pMri.q));
                        % f = min(1, max(0, f));
                        % f(vel >= vCrit) = 1;
                        % f(vel <= 0)  = 0;
                        % f = 1 + f .* (fMax - 1);
                        % Mz_ss_v0*f
        % regime 3
        Mx_ss_max        = Mo;
        Mz_ss(regime==3) = Mx_ss_max;
    else
        Mz_ss_v0  = [];
        Mx_ss_max = [];
    end
end
