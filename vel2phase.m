function phase = vel2phase(v, venc)
    % v    : spin velocities [cm/s]
    % venc : velocity encoding values [cm/s]
    % phase: velocity encoded phase [rad]
    if numel(venc)~=1; dbstack; error('venc must be a scalar'); end
        
    gamma = 42.577e6;  % Gyromagnetic ratio for 1H [Hz/T]
    M1    = pi ./ (gamma .* venc./ 100);  % first moment ofvelocity encoding gradient [T*s^2/m]
    phase = gamma .* M1 .* v./100; % velocity encoded phase [rad]
end