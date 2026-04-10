function venc = M1toVenc(m1)
    % m1  : first moment of velocity encoding gradient [T*s^2/m]
    % venc: velocity encoding value [cm/s]
    gamma = 2.6752218708e8/(2*pi);  % Gyromagnetic ratio/(2*pi) for 1H [Hz/T]
    venc  = pi ./ (gamma.*m1) .* 100;
end