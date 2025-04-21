function M = getMaskOutline(mask,precisionFactor)
% Extract contour of a mask image (0s and 1s) Matlab's polygon object M for
% later ploting over another image ( plot(M) ).
% Higher precisionFactor alleviates the round corners problem but is
% computationally more intense (requires image resizing)



%% Massage input
% exit if empty
if isempty(mask); M = mask; return; end
% set defaults
if ~exist('precisionFactor','var'); precisionFactor = []; end
if isempty(precisionFactor);        precisionFactor = 2; end
% read mask when specified as a filename
if ischar(mask) || iscell(mask); mask = MRIread(char(mask)); end
if isstruct(mask); mask = mask.vol; end
if nnz(size(mask)>1)==2; mask = squeeze(mask); else error('Your supposed to have a single slice here'); end
% disabe warning
warning('off','MATLAB:polyshape:repairedBySimplify')

%% Resize mask
xRs = ( (1:(size(mask,1)*precisionFactor)) - 0.5 ) / precisionFactor;
yRs = ( (1:(size(mask,2)*precisionFactor)) - 0.5 ) / precisionFactor;
mask = imresize(mask,precisionFactor,'nearest');

%% Compute contours
Mtmp = contourc(yRs,xRs,double(mask),[0.5 0.5]);
M = polyshape(Mtmp(:,2:1+Mtmp(2,1))' + [0.5 0.5]); Mtmp(:,1:1+Mtmp(2,1)) = [];
while ~isempty(Mtmp)
    M = xor(M,polyshape(Mtmp(:,2:1+Mtmp(2,1))' + [0.5 0.5])); Mtmp(:,1:1+Mtmp(2,1)) = [];
end