function [Mxy_ss,pMri] = getMxy_ss(Mz_ss,pMri,pRelax)


%%% Precompute parameters %%%
% Force an update of transverse relaxation factor E2 and RF*relaxation factor Q2, if pRelax is provided
if exist('pRelax','var') && ~isempty(pRelax) && isfield(pRelax,'T2star') && ~isempty(pRelax.T2star)
    pMri.E2 = exp( -pMri.TE / pRelax.T2star );
    pMri.Q2  = pMri.E2 * sind(pMri.FA);
elseif ~isfield(pMri,'E2') || isempty(pMri.E2)
    error(['E2 not found in pMri' newline 'provide pRelax input']);
end

%%% Compute steady-state transverse magnetization Mxy_ss %%%
Mxy_ss = Mz_ss .* pMri.Q2;