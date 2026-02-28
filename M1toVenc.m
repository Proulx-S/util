function venc = M1toVenc(M1)
    % M1  : first moment of velocity encoding gradient [T*s^2/m]
    % venc: velocity encoding value [cm/s]
    gamma = 42.577e6;  % Gyromagnetic ratio for 1H [Hz/T]
    venc  = pi ./ (gamma.*M1) .* 100;
end