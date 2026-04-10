function theta = vel2phase(vel, m1)
    % vel  : [cm/s] spin velocities 
    % m1   : [T*s^2/m] first moment of velocity encoding gradients
    % theta: [rad] velocity encoded phase dim

    gamma = 2.6752218708e8/(2*pi);   % Gyromagnetic ratio/(2*pi) for 1H [Hz/T]
    theta = gamma .* m1 .* vel./100; % velocity encoded phase [rad]
end