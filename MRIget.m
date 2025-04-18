function val = MRIget(fspec,prop)
global src

switch prop
    case {'tr'}
        [~,tr] = system(strjoin({src.afni ['3dinfo -tr ' fspec]},newline));
        tr = str2num(tr);
        val = tr;
    case {'nt' 'nv' 'nFrame' 'nframes'}
        [~,nFrame] = system(strjoin({src.afni ['3dinfo -nt ' fspec]},newline));
        nFrame = str2num(nFrame);
        val = nFrame;
    case {'depth' 'nk' 'nslice' 'nslices' 'nSlice' 'nSlices' 'slice' 'slices'}
        [~,depth] = system(strjoin({src.afni ['3dinfo -nk ' fspec]},newline));
        depth = str2num(depth);
        val = depth;
    case {'vox' 'voxSize' 'size'}
        [~,xyz] = system(strjoin({src.afni ['3dinfo -adi -adj -adk ' fspec]},newline));
        xyz = str2num(xyz);
        val = xyz;
    otherwise
        dbstack; error('unkown property')
end



