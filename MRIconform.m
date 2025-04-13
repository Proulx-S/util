function MRIconform(fList, fBase)

    if iscell(fList)
        for f = 1:length(fList)
            MRIconform(fList{f}, fBase);
        end
        return;
    end
    mri    = MRIread(fBase,1);
    mriTmp = MRIread(fList  );
    mri.vol = mriTmp.vol; clear mriTmp;
    MRIwrite(mri,fList);
