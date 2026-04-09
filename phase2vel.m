function v = phase2vel(phase, venc)
    % phase: velocity encoded phase [rad]
    % venc : velocity encoding values [cm/s]  (venc dimension is forced to the 5th)
    % v    : spin velocities [cm/s]

    if numel(venc)~=1
        vencDim = size(venc,1:16)>1;
        if nnz(vencDim)>1; dbstack; error('xx'); end
        permIdx = circshift(1:16,5-find(vencDim));
        venc = permute(venc, permIdx);
    end
    % if numel(venc)~=1 && any(size(venc)~=size(phase)); dbstack; error('venc must be a scalar or the same length as phase'); end
        
    gamma = 42.577e6;  % Gyromagnetic ratio for 1H [Hz/T]
    M1    = pi ./ (gamma .* venc./ 100);  % first moment of velocity encoding gradient [T*s^2/m]
    v     = phase .* 100 ./ (gamma .* M1);  % spin velocities [cm/s]
end
