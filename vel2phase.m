function phase = vel2phase(v, venc)
    % v    : [cm/s] spin velocities 
    % venc : [cm/s] velocity encoding values (venc dimension is forced to the 5th)
    % phase: [rad] velocity encoded phase dim [v1 v2 v3 v4 v5 v6 venc1 venc2 venc3 venc4 venc5 venc6 venc7 venc8 venc9 venc10]
    if numel(venc)~=1
        vencDim = size(venc,1:16)>1;
        if nnz(vencDim)>1; dbstack; error('xx'); end
        permIdx = circshift(1:16,5-find(vencDim));
        venc = permute(venc, permIdx);
    end
        
    gamma = 42.577e6;  % Gyromagnetic ratio for 1H [Hz/T]
    M1    = pi ./ (gamma .* venc./ 100);  % first moment ofvelocity encoding gradient [T*s^2/m]
    phase = gamma .* M1 .* v./100; % velocity encoded phase [rad]
end