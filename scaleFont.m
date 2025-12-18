function scaleFont(hFig,scaleFactor);
    if ~exist('scaleFactor', 'var') || isempty(scaleFactor); scaleFactor = 1; end
    if ~exist('hFig', 'var') || isempty(hFig); hFig = gcf; end
    
    hFont = findall(hFig,'-property','FontSize');
    fontSizes = get(hFont,'FontSize');
    if iscell(fontSizes)
        fontSizes = cell2mat(fontSizes);
    end
    newFontSizes = fontSizes*scaleFactor;
    for i = 1:length(hFont)
        set(hFont(i),'FontSize',newFontSizes(i));
    end
    
    % Handle tiledlayout title font size (titles don't get caught by findall)
    hTiledLayouts = findall(hFig, 'Type', 'tiledlayout');
    for i = 1:length(hTiledLayouts)
        hT = hTiledLayouts(i);
        % Scale tiledlayout title font size
        if ~isempty(hT.Title) && isvalid(hT.Title)
            try
                currentTitleFontSize = hT.Title.FontSize;
                hT.Title.FontSize = currentTitleFontSize * scaleFactor;
            catch
                % If title font size can't be accessed/set, skip it
            end
        end
    end
    
    % Adjust layout to accommodate larger fonts
    if scaleFactor > 1
        % Handle tiledlayout padding and spacing
        for i = 1:length(hTiledLayouts)
            hT = hTiledLayouts(i);
            % Increase padding proportionally to font scale
            % Padding can be a char array or numeric
            try
                currentPadding = hT.Padding;
                if ischar(currentPadding) || isstring(currentPadding)
                    % Convert named padding to numeric
                    switch char(currentPadding)
                        case 'loose'
                            paddingValue = 0.16;
                        case 'normal'
                            paddingValue = 0.08;
                        case 'compact'
                            paddingValue = 0.04;
                        case 'tight'
                            paddingValue = 0.02;
                        otherwise
                            paddingValue = 0.08;
                    end
                else
                    paddingValue = currentPadding;
                end
                % Scale padding (but cap it to prevent excessive padding)
                newPadding = min(paddingValue * scaleFactor, 0.2);
                hT.Padding = newPadding;
            catch
                % If setting padding fails, try setting to 'loose'
                try
                    hT.Padding = 'loose';
                catch
                end
            end
            
            % Also adjust TileSpacing if needed
            try
                currentSpacing = hT.TileSpacing;
                if ischar(currentSpacing) || isstring(currentSpacing)
                    switch char(currentSpacing)
                        case 'loose'
                            spacingValue = 0.16;
                        case 'normal'
                            spacingValue = 0.08;
                        case 'compact'
                            spacingValue = 0.04;
                        case 'tight'
                            spacingValue = 0.02;
                        otherwise
                            spacingValue = 0.08;
                    end
                else
                    spacingValue = currentSpacing;
                end
                newSpacing = min(spacingValue * scaleFactor, 0.2);
                hT.TileSpacing = newSpacing;
            catch
                % If setting spacing fails, try setting to 'loose'
                try
                    hT.TileSpacing = 'loose';
                catch
                end
            end
        end
        
        % For regular axes (not in tiledlayout), try tightlayout
        % But skip if we have tiledlayout (tightlayout doesn't work well with it)
        if isempty(hTiledLayouts)
            try
                tightlayout(hFig);
            catch
                % If tightlayout doesn't exist or fails, manually adjust axes
                hAxes = findall(hFig, 'Type', 'axes');
                for j = 1:length(hAxes)
                    ax = hAxes(j);
                    % Skip if this axes is part of a tiledlayout
                    parent = ax.Parent;
                    if isa(parent, 'matlab.graphics.layout.TiledChartLayout')
                        continue;
                    end
                    % Get current position
                    pos = ax.OuterPosition;
                    % Slightly reduce the axes area to make room for larger labels
                    marginAdjust = 0.03 * (scaleFactor - 1); % 3% per unit scale above 1
                    if marginAdjust > 0
                        pos(1) = pos(1) + marginAdjust * pos(3); % left margin
                        pos(2) = pos(2) + marginAdjust * pos(4); % bottom margin
                        pos(3) = pos(3) * (1 - 2*marginAdjust); % width
                        pos(4) = pos(4) * (1 - 2*marginAdjust); % height
                        ax.OuterPosition = pos;
                    end
                end
            end
        end
        
        % Force a redraw to ensure labels are properly positioned
        drawnow;
    end
