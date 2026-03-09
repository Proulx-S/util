function [RGB, Hvar, CLvar] = colormap_bivariateBlackToSpectral(Hvar,CLvar,HvarLim,CLvarLim,Hmax,Hshift,Hrange,Crange,Lrange,cbFlag)

% Dependency
toClean.path = {};
if exist('colorspace', 'file') ~= 2
    toolDir = fileparts(fileparts(mfilename('fullpath')));
    tool    = 'Colorspace-Transformations'; toolURL = 'https://www.mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/28790/versions/5/download/zip';
    if ~exist(fullfile(toolDir, tool), 'dir')
        disp(['Downloading Colorspace-Transformations from MathWorks to' newline fullfile(toolDir, tool)]);
        tmpZip = fullfile(tempdir, 'shplot.zip'); websave(tmpZip, toolURL); unzip(tmpZip, fullfile(toolDir, tool)); delete(tmpZip);
    end
    toClean.path{end+1} = genpath(fullfile(toolDir,tool));
    addpath(toClean.path{end});
end


% Default limits to the input variables
if ~exist('HvarLim','var')  || isempty(HvarLim);  HvarLim  = [0 1]; end
if ~exist('CLvarLim','var') || isempty(CLvarLim); CLvarLim = [0 1]; end
    
% When only variable limits HvarLim and CLvarLim are provided, produce a colormap for an arbitrary range of input variables
if ~exist('Hvar','var') || isempty(Hvar) || ~exist('CLvar','var') || isempty(CLvar)
    nGrid = 2^7;
    clvar = linspace(CLvarLim(1), CLvarLim(2), nGrid);
    hvar = linspace(HvarLim(1)  , HvarLim(2) , nGrid);
    [CLvar, Hvar] = meshgrid(clvar, hvar);
    if ~exist('cbFlag','var') || isempty(cbFlag); cbFlag = true ; else; cbFlag = false; end
else
    if ~exist('cbFlag','var') || isempty(cbFlag); cbFlag = false; else; cbFlag = true ; end
end

% Default limits to colormap (defined in HCL color space for perceptual independence)
% luminance L
if ~exist('Lrange','var') || isempty(Lrange)
    Lrange = [0 80]; % [0 100]
end
% chroma C
if ~exist('Crange','var') || isempty(Crange)
    Crange = [0 35]; % [0 100]
end
% hue H
if ~exist('Hmax','var') || isempty(Hmax)
    Hmax = 2*pi; % 1.5*pi
end
if ~exist('Hshift','var') || isempty(Hshift)
    Hshift = 0; % pi/8
end
if ~exist('Hrange','var') || isempty(Hrange)
    Hrange = [0 Hmax]; % [0 2*pi]
    Hrange = wrapTo2Pi(Hrange + Hshift); % [0 2*pi]
end

% Convert to HCL color space
% Hvar to hue H
H = interp1(HvarLim ,Hrange,Hvar )./pi*180;
% CLvar to chroma C
C = interp1(CLvarLim,Crange,CLvar);
% CLvar to luminance L
L = interp1(CLvarLim,Lrange,CLvar);


% Convert to RGB color space
RGB = colorspace('LCH->RGB',cat(3,L,C,H));


% Plot colormap
if cbFlag
    figure('MenuBar','none','ToolBar','none');
    hT = tiledlayout(3,2); hT.TileSpacing = 'compact'; hT.Padding = 'compact'; hT.TileIndexing = 'columnmajor'; ax = {};
    for i = 1:3
        ax{end+1} = nexttile(hT,i);
        histogram(reshape(RGB(i,:,:),[numel(RGB(i,:,:)) 1]),2^6);
        xlim([0 1]);
    end
    ax{end+1} = nexttile([3 1]);
    image(CLvarLim,HvarLim,RGB);
    set(ax{end},'YDir','normal','YAxisLocation','right');
    axis square;
    title('Bivariate Black to Spectral');
    xlabel('variable mapped to luminance and chroma');
    ylabel('variable mapped to hue');
    title(hT, sprintf('Histogram of RGB values\nH: [%.2f, %.2f], C: [%.2f, %.2f], L: [%.2f, %.2f]', ...
        Hrange(1), Hrange(2), Crange(1), Crange(2), Lrange(1), Lrange(2)));
end


% Clean up paths
for i = 1:numel(toClean.path)
    rmpath(toClean.path{i});
end
