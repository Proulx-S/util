function fig = setNicerColorOrder(fig, darkColorOrder, lightColorOrder)
%SETNICERCOLORORDER  Attach theme-aware color order to figure (white/black + glow/gem).
%   setNicerColorOrder(fig)
%   setNicerColorOrder(fig, darkColorOrder)
%   setNicerColorOrder(fig, darkColorOrder, lightColorOrder)
%
%   Uses themeAwareColorOrder with default palettes:
%     Dark:  [white; orderedcolors("glow")]
%     Light: [black; orderedcolors("gem")]
%
%   Pass [] for dark or light to use that default; omit or pass custom Nx3 for overrides.

    CdarkDefault  = [1 1 1; orderedcolors("glow")];
    ClightDefault = [0 0 0; orderedcolors("gem")];

    if nargin < 2 || isempty(darkColorOrder)
        darkColorOrder = CdarkDefault;
    end
    if nargin < 3 || isempty(lightColorOrder)
        lightColorOrder = ClightDefault;
    end

    fig.ThemeChangedFcn = @(src, event) themeAwareColorOrder(src, event, darkColorOrder, lightColorOrder);

    % Apply current theme's color order now
    if fig.Theme.BaseColorStyle == "dark"
        C = darkColorOrder;
    else
        C = lightColorOrder;
    end
    set(fig, 'DefaultAxesColorOrder', C);
    axs = findobj(fig, 'Type', 'axes');
    for k = 1:numel(axs)
        colororder(axs(k), C);
    end
end
