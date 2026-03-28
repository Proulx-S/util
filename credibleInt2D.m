function [CIarea,probMap,x,y,bw,deltaXY,CIprob,polyCont] = credibleInt2D(d,CItarget,gridBw,deltaXY,x,y,plotFlag)
warning('off','MATLAB:polyshape:repairedBySimplify')
if ~exist('CItarget'  ,'var') || isempty(CItarget  ); CItarget  = 0.95 ; end
if ~exist('gridBw'    ,'var') || isempty(gridBw    ); gridBw    = 3    ; end
if ~exist('deltaXY'   ,'var')                       ; deltaXY   = []   ; end
if ~exist('x'         ,'var')                       ; x         = []   ; end
if ~exist('y'         ,'var')                       ; y         = []   ; end
if ~exist('plotFlag'  ,'var') || isempty(plotFlag  ); plotFlag  = false; end
assert(mod(gridBw,1) == 0, 'gridBw must be an integer.');

% Notes:
% - area will increase with kdensity bandwidth (bw)
% - area is independent of the number of grid points (deltaXY^2*length(x)*length(y))
% - dependence on deltaXY not tested





if iscell(d)



    % When d is a cell array, each cell is treated as a separate dataset to be processed independently using the same parameters.
    if ~isempty(x) && ~isempty(y) && isempty(deltaXY)
        deltaXY = mean([diff(x) diff(y)]);
    end
    CIarea   = cell(size(d));
    probMap  = cell(size(d));
    x        = cell(size(d));
    y        = cell(size(d));
    bw       = nan(size(d));
    CIprob   = nan(size(d));
    polyCont = repmat(polyshape,size(d));
    for dIdx = 1:length(d)
        [CIarea{dIdx},probMap{dIdx},x{dIdx},y{dIdx},bw(dIdx),~,CIprob(dIdx),polyCont(dIdx)] = credibleInt2D(d{dIdx},CItarget,gridBw,deltaXY);
    end

    % then merge the probability maps
    xLim = [min(cellfun(@min, x)) max(cellfun(@max, x))];
    yLim = [min(cellfun(@min, y)) max(cellfun(@max, y))];
    x{end+1} = linspace(xLim(1), xLim(2), round(range(xLim) / deltaXY) + 1);
    y{end+1} = linspace(yLim(1), yLim(2), round(range(yLim) / deltaXY) + 1);
    x{end} = round(x{end}/deltaXY).*deltaXY;
    y{end} = round(y{end}/deltaXY).*deltaXY;
    [X, Y] = meshgrid(x{end}, y{end});
    probMap{end+1} = zeros(size(X));
    for dIdx = 1:length(d)
        probMap{end} = probMap{end} + interp2(x{dIdx}, y{dIdx}, probMap{dIdx}, X, Y, 'linear', 0);
    end

    % and plot merged probability map
    if plotFlag
        figure;
        imagesc(x{end}, y{end}, probMap{end}); axis image; hold on
        colormap(gray);
        axis tight;
        xlim(x{end}([1 end])+[-1 1].*deltaXY/2);
        ylim(y{end}([1 end])+[-1 1].*deltaXY/2);
        cMap = jet;
        cMap = interp1(linspace(0,1,size(cMap,1))',cMap,linspace(0,1,length(d))');
        for dIdx = 1:length(d)
            hP = plot(polyCont(dIdx),'FaceColor','none','EdgeColor',cMap(dIdx,:));
        end
    end
    return


else

    % Continue to analysis of the single dataset d

end



if isempty(x) || isempty(y)
    % Define grid and bandwidth
    xLim = [min(d(:,1)) max(d(:,1))];
    yLim = [min(d(:,2)) max(d(:,2))];
    if isempty(deltaXY)
        % at least 2^8 grid points in the larger dimension
        deltaXY = max([range(xLim) range(yLim)])/2^8;
    end
    xLim = round(xLim./deltaXY).*deltaXY;
    yLim = round(yLim./deltaXY).*deltaXY;
    bw    = deltaXY.*gridBw;

    % Add bw-dependent margin to the grid limits
    xLim = xLim + [-1 1].*3.*bw;
    yLim = yLim + [-1 1].*3.*bw;

    % Make grid
    x = linspace(xLim(1),xLim(2),round(range(xLim)/deltaXY)+1);
    y = linspace(yLim(1),yLim(2),round(range(yLim)/deltaXY)+1);
else
    if ~isempty(deltaXY)
        warning('deltaXY is provided but x and y are not empty. deltaXY will be ignored.');
    end
    deltaXY = mean([diff(x) diff(y)]);
    bw      = deltaXY.*gridBw;
end
[X,Y] = meshgrid(x,y);

% Compute probability map
probMap    = nan(size(X));
probMap(:) = ksdensity(d,[X(:) Y(:)],'Bandwidth',bw);
probMap    = probMap./sum(probMap(:));
% Compute cumulative probabilities
probMap_sorted = sort(probMap(:),'descend');
probMap_cum    = cumsum(probMap_sorted);
% Compute cumulative probabilities threshold
probThresh_idx = find(probMap_cum>CItarget,1,'first');
probThresh     = probMap_sorted( probThresh_idx );
% Compute credible interval area and associated probability
CIarea         = probMap>probThresh;
CIprob         = sum(probMap(CIarea));

% Get credible interval contour
if nargout > 7
    M = contourc(double(x),double(y),probMap,[1 1].*probThresh);
    polyCont = polyshape;
    while ~isempty(M)
        polyCont = addboundary(polyCont,M(1,2:1+M(2,1)),M(2,2:1+M(2,1)));
        M(:,1:1+M(2,1)) = [];
    end
end

% Plot
if plotFlag
    figure;
    % figure('MenuBar', 'none','ToolBar', 'none');
    
    % plot probability map
    imagesc(x,y,probMap); axis image; hold on
    plot(d(:,1),d(:,2),'.r','markersize',eps);
    colormap(gray); ylabel(colorbar,'probability');
    xlabel('var1'); ylabel('var2');
    lims = axis;

    % get contour of credible interval
    M = contourc(double(x),double(y),probMap,[1 1].*probThresh);
    polyCont = polyshape;
    while ~isempty(M)
        polyCont = addboundary(polyCont,M(1,2:1+M(2,1)),M(2,2:1+M(2,1)));
        M(:,1:1+M(2,1)) = [];
    end
    % and plot it
    hCont = plot(polyCont,'FaceColor','none','EdgeColor','g');
    axis(lims);
    legend(hCont,['cumProb=CItarget (CIprob=' num2str(CIprob) ')']);
end
