function prob = credibleMean2d(d,alpha,nBoot,plotFlag)
% warning('off','MATLAB:polyshape:repairedBySimplify')
if ~exist('alpha'   ,'var') || isempty(alpha   ); alpha    = 0.05 ; end
if ~exist('nBoot'   ,'var') || isempty(nBoot   ); nBoot    = 2^9  ; end
if ~exist('plotFlag','var') || isempty(plotFlag); plotFlag = false; end


% Loop through cell array of datasets d
if iscell(d)
    prob = cell(size(d));
    for dIdx = 1:length(d)
        prob{dIdx} = credibleMean2d(d{dIdx},alpha,nBoot);
    end
    return
end



% Compute probability map of the bootstrapped mean -- using ksdensity.m defaults
[prob.map,xi,bw] = ksdensity( bootstrp(nBoot,@mean,d) );
[prob.x, ~, ix] = unique(xi(:,1), 'stable');
[prob.y, ~, iy] = unique(xi(:,2), 'stable');
prob.map = accumarray([iy ix], prob.map, [numel(prob.y) numel(prob.x)]);
prob.map = prob.map./sum(prob.map(:));
prob.x = prob.x'; clear ix iy xi
prob.bw    = bw;
prob.nBoot = nBoot;

% Compute 1-alpha confidence area
probDescending = sort(prob.map(:),'descend');
probThresh     = probDescending(  find( cumsum(probDescending)>(1-alpha) ,1,'first')  );
M = contourc(double(prob.x),double(prob.y),double(prob.map),[1 1].*double(probThresh));
prob.CIcontour = polyshape;
while ~isempty(M)
    prob.CIcontour = addboundary(prob.CIcontour,M(1,2:1+M(2,1)),M(2,2:1+M(2,1)));
    M(:,1:1+M(2,1)) = [];
end
prob.CIprob    = sum(prob.map( prob.map(:)>probThresh ));
prob.alpha     = alpha;