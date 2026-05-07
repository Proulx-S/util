function cmap = blueBlackRed(N)
% blueBlackRed  Perceptually-designed diverging colormap.
%   cmap = blueBlackRed(N)  returns an N×3 RGB colormap (default N=256).
%
%   Colour path through CIE L*C*H° space:
%     light blue → pure blue → dark blue → black → dark red → pure red → light red
%
%   Designed for signed data (phase maps, velocity maps).  Hue encodes
%   sign; luminance encodes magnitude; black at zero gives a sharp
%   zero-crossing cue while transitions elsewhere remain perceptually smooth.
%
%   Requires the Colorspace-Transformations toolbox (auto-downloaded to the
%   parent directory of util on first call).

if nargin < 1 || isempty(N); N = 256; end

% Ensure CIE colorspace conversion toolbox is available
if exist('colorspace','file') ~= 2
    toolDir = fileparts(fileparts(mfilename('fullpath')));
    tool    = 'Colorspace-Transformations';
    toolURL = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/28790/versions/5/download/zip';
    if ~exist(fullfile(toolDir,tool),'dir')
        tmpZip = fullfile(tempdir,'colorspace.zip');
        websave(tmpZip, toolURL);
        unzip(tmpZip, fullfile(toolDir,tool));
        delete(tmpZip);
    end
    addpath(genpath(fullfile(toolDir,tool)));
end

% Control points [t, L, C, H_deg] in CIE L*C*H° (hue: 0°=red, 270°=blue)
ctrl = [
    0.00,  80,  25,  280;   % light blue
    0.28,  38,  50,  280;   % pure blue
    0.40,  12,  18,  285;   % dark blue
    0.50,   0,   0,    0;   % black
    0.60,  12,  18,   30;   % dark red
    0.72,  42,  60,   25;   % pure red
    1.00,  80,  28,   18;   % light red
];

t    = linspace(0, 1, N)';
L    = interp1(ctrl(:,1), ctrl(:,2), t, 'pchip');
C    = max(0, interp1(ctrl(:,1), ctrl(:,3), t, 'pchip'));
H    = interp1(ctrl(:,1), ctrl(:,4), t, 'pchip');

LCH  = permute(reshape([L, C, H], [N, 1, 3]), [2 1 3]);  % 1×N×3
RGB  = colorspace('LCH->RGB', LCH);
cmap = squeeze(max(0, min(1, RGB)));                       % N×3
