function varargout = shplot2(x,y,e,hA,varargin)
%% H = shplot(x,y,e,opt,varargin) 
% This function creates a shaded error-bar plot. It is a lightweight
% implementation of 'shadedErrorBar' by Rob Campbell intended
% to be used as a local function in other scripts.
%
% H is a structure of handles to parts of the plot (line path upper lower).
%
% EXAMPLE
%  n = 18; x = linspace(-1,1,n^2); y = peaks(n); y = y(:);
%  for j = 1:100, Y(:,j) = y + randn(n^2,1); end;
%  opt = {'Color', [1 .39 .3], 'Marker', '.'};
%  H = shplot(x,mean(Y,2),6*std(Y,[],2)./sqrt(size(Y,2)), opt{:});
%  grid on; box on; xlim([-1 1]);
%  legend([H.line H.patch],'<Y>','6\sigma_{m}(Y)');
%
% Written by Marcin Konowalczyk
% Timmel Group @ Oxford University

% modified by Sebastien Proulx 2025-05-04 (proulxs@stanford.edu) to accept a handle to an axis

x = x(:); y = y(:); e = abs(e(:));
isheld = ishold; if ~isheld; cla; hold on; end
if ~isempty(hA)
    H.line = plot(hA,x,y,varargin{:});
else
    H.line = plot(x,y,varargin{:});
end

eu = y + e; el = y - e;
col = 0.15*get(H.line,'color') + 0.85; ecol = 3*col-2;
set(gcf,'renderer','painters');
if ~isempty(hA)
    H.patch = patch(hA,[x ;flipud(x)],[el ;flipud(eu)],1,'facecolor',col,'edgecolor','none','facealpha',1);
    H.upper = plot(hA,x,eu,'-','color',ecol);
    H.lower = plot(hA,x,el,'-','color',ecol);
else
    H.patch = patch([x ;flipud(x)],[el ;flipud(eu)],1,'facecolor',col,'edgecolor','none','facealpha',1);
    H.upper = plot(x,eu,'-','color',ecol);
    H.lower = plot(x,el,'-','color',ecol);
end

uistack(H.line,'top');
if ~isheld; hold off; end
if nargout > 0; varargout = {H}; end
end