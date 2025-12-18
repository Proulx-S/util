function scaleFont(hFig,scaleFactor)

    hFont = findall(hFig,'-property','FontSize');
    fontSizes = get(hFont,'FontSize');
    if iscell(fontSizes)
        fontSizes = cell2mat(fontSizes);
    end
    newFontSizes = fontSizes*scaleFactor;
    for i = 1:length(hFont)
        set(hFont(i),'FontSize',newFontSizes(i));
    end
