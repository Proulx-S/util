function hF = resizeFig(hF, width, height)
% Resize figure to given dimensions in centimeters, then drawnow.
hF.Units    = 'centimeters';
hF.Position = [hF.Position(1:2) width height];
drawnow;
end
