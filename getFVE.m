function [venc, m1, vel, Ns, vencMin, vencMax] = getFVE(FVEres, FVEbw, method)
    % vencRes: [cm/s]    velocity spectrum resolution
    % vencMax: [cm/s]    velocity spectrum bandwidth (maximum velocity)
    % venc   : [cm/s]    velocity encoding values 
    % m1     : [T*s^2/m] gradient first moments
    % Nvenc  :           number of velocity encodings
    % Fvenc  : [cm/s]    velocity spectrum "frequency" axis

    switch method
        case 'FVEmono'
            m1 = linspace(0, vencToM1(FVEres/2), 2*round(vencToM1(FVEres/2)/vencToM1(FVEbw/2))+1)';
        case 'FVEbipo'
            m1 = linspace(-vencToM1(FVEres), vencToM1(FVEres), 2*round(vencToM1(FVEres)/vencToM1(FVEbw))+1)';
    end
    venc = M1toVenc(m1);
    Ns   = length(venc);
    vel  = linspace(-FVEbw, FVEbw, Ns)';
    vencMin = min(abs(venc));
    vencMax = max(abs(venc(venc~=inf & venc~=-inf)));
end