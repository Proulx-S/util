function vel = phase2vel(theta, m1)
    % theta: velocity encoded phase [rad]
    % m1   : first moment of velocity encoding gradients [T*s^2/m]
    % vel  : spin velocities [cm/s]

    % if numel(venc)~=1
    %     vencDim = size(venc,1:16)>1;
    %     if nnz(vencDim)>1; dbstack; error('xx'); end
    %     permIdx = circshift(1:16,5-find(vencDim));
    %     venc = permute(venc, permIdx);
    % end
    % if numel(venc)~=1 && any(size(venc)~=size(phase)); dbstack; error('venc must be a scalar or the same length as phase'); end
        
    gamma = 2.6752218708e8/(2*pi);           % Gyromagnetic ratio/(2*pi) for 1H [Hz/T]
    % M1    = pi ./ (gamma .* venc./ 100);    % first moment of velocity encoding gradient [T*s^2/m]
    vel     = theta .* 100 ./ (gamma .* m1);  % spin velocities [cm/s]
end
