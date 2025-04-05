function val = MRIget(fspec,prop)
global src

switch prop
    case {'nt' 'nv' 'nFrame' 'nframes'}
        [~,nFrame] = system(strjoin({src.afni ['3dinfo -nt ' fspec]},newline));
        nFrame = str2num(nFrame);
        val = nFrame;
    case {'vox' 'voxSize' 'size'}
        [~,xyz] = system(strjoin({src.afni ['3dinfo -adi -adj -adk ' fspec]},newline));
        xyz = str2num(xyz);
        val = xyz;
    otherwise
        dbstack; error('unkown property')
end



