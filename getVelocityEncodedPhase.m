function [spinPhase, M1] = getVelocityEncodedPhase(v, venc)
    % v: column vector of spin velocities [cm/s]
    % venc: row vector of velocity encoding values [cm/s]
    % spinPhase: velocity encoded phase [rad]
    % M1: first moment of velocity encoding gradient [T*s^2/m]

    if ~all(size(v   ,   2:16 )==1); error('v must be a column vector'      ); end
    if ~all(size(venc,[1 3:16])==1); error('venc must be a row vector'); end


    gamma = 42.577e6;  % Gyromagnetic ratio for 1H [Hz/T]
    M1 = pi ./ (gamma .* venc./ 100);  % first moment ofvelocity encoding gradient [T*s^2/m]
    spinPhase = gamma .* M1 .* v./100; % velocity encoded phase [rad]
end