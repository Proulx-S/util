function m1 = vencToM1(venc)
    % venc: velocity encoding value [cm/s]
    % m1: first moment of velocity encoding gradient [T*s^2/m]
    gamma = 2.6752218708e8/(2*pi);  % Gyromagnetic ratio/(2*pi) for 1H [Hz/T]
    m1    = pi ./ (gamma.*venc./ 100);
end