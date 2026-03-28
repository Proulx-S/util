function bw = kdeNormalApproxBW(d)
    % Normal optimal smoothing bandwidth for KDE (ksdensity.m), as proposed by Bowman & Azzalini 1997, section 2.4.2 Normal optimal smoothing.
    % Bowman, A. W. & Azzalini, A. Density Estimation for Inference. in Applied Smoothing Techniques for Data Analysis 25–47 (Oxford University PressOxford, 1997). doi:10.1093/oso/9780198523963.003.0002.

    [n,p] = size(d);
    bw = ( 4/((p+2)*n) )^( 1/(p+4) )  *  std(d, [], 1);