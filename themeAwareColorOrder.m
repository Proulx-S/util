function themeAwareColorOrder(fig, event, darkColorOrder, lightColorOrder)
%THEMEAWARECOLORORDER  Set color order from theme; optional custom dark and/or light.
%   themeAwareColorOrder(fig, event, darkColorOrder, lightColorOrder)
%   Use [] for any argument to use MATLAB's default for that theme.
%
%   Examples:
%     themeAwareColorOrder(fig, event, myDark)              % custom dark only
%     themeAwareColorOrder(fig, event, [], myLight)        % custom light only
%     themeAwareColorOrder(fig, event, myDark, myLight)    % both custom

    if nargin < 4
        lightColorOrder = [];
    end

    if event.Theme.BaseColorStyle == "dark"
        if isempty(darkColorOrder)
            C = orderedcolors("glow");
        else
            C = darkColorOrder;
        end
    else
        if isempty(lightColorOrder)
            C = orderedcolors("gem");
        else
            C = lightColorOrder;
        end
    end

    % Apply to figure default (for future axes) and to all existing axes
    set(fig, 'DefaultAxesColorOrder', C);
    axs = findobj(fig, 'Type', 'axes');
    for k = 1:numel(axs)
        colororder(axs(k), C);
    end
end
