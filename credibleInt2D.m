function [prob,probSample] = credibleInt2D(d,CItarget,bw,deltaXY,plotFlag)
warning('off','MATLAB:polyshape:repairedBySimplify')
if ~exist('CItarget'  ,'var') || isempty(CItarget  ); CItarget  = 0.95 ; end
if ~exist('bw'        ,'var')                       ; bw        = []   ; end
if ~exist('deltaXY'   ,'var')                       ; deltaXY   = []   ; end
if ~exist('plotFlag'  ,'var') || isempty(plotFlag  ); plotFlag  = false; end
% assert(mod(gridBw,1) == 0, 'gridBw must be an integer.');
ptsInBW = 2^2;
nBoot   = 2^8;

% Notes:
% - area will increase with kdensity bandwidth (bw)
% - area is independent of the number of grid points (deltaXY^2*length(x)*length(y))
% - dependence on deltaXY not tested





if iscell(d)

    %%%% Analyze the cell array of datasets d %%%%

    % Define a fixed grid spacing for all datasets
    % as a small fraction of the smallest optimal normal smoothing bandwidth
    normalApproxBW = nan(size(d));
    for dIdx = 1:length(d)
        normalApproxBW(dIdx) = mean(  kdeNormalApproxBW( bootstrp(nBoot,@mean,d{dIdx}) )  );
    end
    deltaXY = min(normalApproxBW)./ptsInBW;

    % % Estimate the maximum sem
    % ddSEM   = max( std(cat(3,d{:}),[],1) ./ sqrt(size(cat(3,d{:}),1)) ,[],'all');
    % if isempty(deltaXY)
    %     % define the deltaXY as a small fraction of sem
    %     deltaXY = ddSEM./ptsInSEM;
    % end


    % Analyze each dataset independently with same deltaXY grid spacing
    prob.map      = [];
    prob.CImap    = [];
    prob.CIprob   = [];
    prob.x        = [];
    prob.y        = [];
    prob.bw       = [];
    prob.polyCont = [];
    prob      = repmat(prob,size(d));
    % for dIdx = 1:length(d)
    %     prob(dIdx).bw = normalApproxBW(dIdx);
    % end

    probSample.map = [];
    probSample.x   = [];
    probSample.y   = [];
    probSample.bw  = [];
    probSample = repmat(probSample,size(d));
    
    
    % CIarea   = cell(size(d));
    % probMap  = cell(size(d));
    % probMapSample = cell(size(d));
    % x        = cell(size(d));
    % y        = cell(size(d));
    % bw       = nan(size(d));
    % CIprob   = nan(size(d));
    % polyCont = repmat(polyshape,size(d));
    for dIdx = 1:length(d)
        [prob(dIdx),probSample(dIdx)] = credibleInt2D(d{dIdx},CItarget,normalApproxBW(dIdx),deltaXY);
        
        % [CIarea{dIdx},probMap{dIdx},probMapSample{dIdx},x{dIdx},y{dIdx},CIprob(dIdx),polyCont(dIdx)] = credibleInt2D(d{dIdx},CItarget,normalApproxBW(dIdx),deltaXY);
        % [CIarea,probMap,x,y,bw,~,CIprob,polyCont,bwMatlab] = credibleInt2D(d{dIdx},CItarget,normalApproxBW(dIdx),deltaXY);
    end

    % bwMatlab = mean(cat(1,bwMatlab{:}),2);
    % figure('MenuBar', 'none','ToolBar', 'none');
    % scatter(bwMatlab,bw,'filled'); hold on; grid on; axis image
    % return
    % bw

    % then merge the probability maps
    xLim = [min(cellfun(@min, x)) max(cellfun(@max, x))];
    yLim = [min(cellfun(@min, y)) max(cellfun(@max, y))];
    xSample = linspace(xLim(1), xLim(2), round(range(xLim) / deltaXY) + 1);
    ySample = linspace(yLim(1), yLim(2), round(range(yLim) / deltaXY) + 1);
    xSample = round(xSample/deltaXY).*deltaXY;
    ySample = round(ySample/deltaXY).*deltaXY;
    [X, Y] = meshgrid(xSample, ySample);
    probMapSample{end+1} = zeros(size(X));
    for dIdx = 1:length(d)-1
        probMapSample{end} = probMapSample{end} + interp2(x{dIdx}, y{dIdx}, probMapSample{dIdx}, X, Y, 'linear', 0);
        probMapSample{dIdx} = [];
    end
    probMapSample = probMapSample{end};

    % and plot merged probability map
    if plotFlag
        figure('MenuBar', 'none','ToolBar', 'none');
        imagesc(xSample, ySample, probMapSample); axis image; hold on
        colormap(gray);
        axis tight;
        xlim(xSample([1 end])+[-1 1].*deltaXY/2);
        ylim(ySample([1 end])+[-1 1].*deltaXY/2);
        cMap = jet;
        cMap = interp1(linspace(0,1,size(cMap,1))',cMap,linspace(0,1,length(d))');
        for dIdx = 1:length(d)
            hP = plot(polyCont(dIdx),'FaceColor','none','EdgeColor',cMap(dIdx,:));
        end
    end
    return


else

    %%%% Continue to analysis of the single dataset d %%%%

    % % Estimate the maximum sem
    % ddSEM   = max( std(d,[],1) ./ sqrt(size(d,1)) ,[],'all');
    % if isempty(deltaXY)
    %     % define the deltaXY as a small fraction of sem
    %     deltaXY = ddSEM./ptsInSEM;
    % end


end




% Generate bootstrapped distribution of the mean
dBoot = bootstrp(nBoot,@mean,d);



% bwX = ksdensityNormalApproxBW2D(d)

% [prob,xi,bw] = ksdensity(d);


% ux = unique(xi(:,1),'stable');
% uy = unique(xi(:,2),'stable');
% [~,ix] = ismember(xi(:,1),ux);
% [~,iy] = ismember(xi(:,2),uy);
% probMap = accumarray([iy ix],prob,[numel(uy) numel(ux)]);





% Define grid limits
xLim = [min(d(:,1)) max(d(:,1))];
yLim = [min(d(:,2)) max(d(:,2))];
xLim = xLim + [-1 1].*bw.*0;
yLim = yLim + [-1 1].*bw.*0;
xLim = round(xLim./deltaXY).*deltaXY;
yLim = round(yLim./deltaXY).*deltaXY;

% Make grid
prob.x = linspace(xLim(1),xLim(2),round(range(xLim)/deltaXY)+1);
prob.y = linspace(yLim(1),yLim(2),round(range(yLim)/deltaXY)+1);
[X,Y] = meshgrid(prob.x,prob.y);

% Compute sample distribution map
probSample.x      = prob.x;
probSample.y      = prob.y;
probSample.map    = nan(size(X));
probSample.map(:) = ksdensity(d    ,[X(:) Y(:)]               );
probSample.map    = prob.map./max(prob.map(:));

% Compute probability map of the mean
prob.map    = nan(size(X));
prob.map(:) = ksdensity(dBoot,[X(:) Y(:)],'Bandwidth',bw);
prob.map    = prob.map./sum(prob.map(:));

% Compute cumulative probabilities
probMap_sorted = sort(prob.map(:),'descend');
probMap_cum    = cumsum(probMap_sorted);
% Compute cumulative probabilities threshold
probThresh_idx = find(probMap_cum>CItarget,1,'first');
probThresh     = probMap_sorted( probThresh_idx );
% Compute credible interval area and associated probability
prob.CImap  = prob.map>probThresh;
prob.CIprob = sum(prob.map(prob.CImap));

% Get credible interval contour
M = contourc(double(prob.x),double(prob.y),prob.map,[1 1].*probThresh);
prob.polyCont = polyshape;
while ~isempty(M)
    prob.polyCont = addboundary(prob.polyCont,M(1,2:1+M(2,1)),M(2,2:1+M(2,1)));
    M(:,1:1+M(2,1)) = [];
end

% Plot
if plotFlag
    figure('MenuBar', 'none','ToolBar', 'none');
    
    % plot sample distribution density map
    imagesc(probSample.x,probSample.y,probSample.map); axis image; hold on
    plot(d(:,1),d(:,2),'.r','markersize',eps);
    colormap(gray); ylabel(colorbar,'probability');
    xlabel('var1'); ylabel('var2');
    lims = axis;

    % plot contour of credible interval of the mean
    hCont = plot(prob.polyCont,'FaceColor','none','EdgeColor','g');
    axis(lims);
    legend(hCont,['cumProb=CItarget (CIprob=' num2str(prob.CIprob) ')']);
end
