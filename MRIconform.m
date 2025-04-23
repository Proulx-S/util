function MRIconform(fList, fBase)
global src
    if iscell(fList)
        for f = 1:length(fList)
            MRIconform(fList{f}, fBase);
        end
        return;
    end

    cmd = {src.afni};
    cmd{end+1} = ['3dinfo -same_grid ' fList ' ' fBase];
    [~,cmdout] = system(strjoin(cmd,newline));
    if ~all(str2num(cmdout))
        mri    = MRIread(fBase,1);
        mriTmp = MRIread(fList  );
        mri.vol = mriTmp.vol; clear mriTmp;
        MRIwrite(mri,fList);
    end
