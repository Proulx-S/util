function mri = vec2vol(mri,keepFlag)
% vol2vec.m and vec2vol.m
% To be used with MRIread.m and MRIwrite.m from Freesurfer
% (/usr/local/freesurfer/dev/matlab/).
% Moves from a 4D volume timeseries to a vectorize 2D (time X voxel) format
% using a user-specified mask (vol2vec.m), and vice-versa (vec2vol.m).
% This saves memory while keeping data in a compatible format.
if ~exist('keepFlag','var')
    keepFlag = false;
end

mri2 = cell(size(mri));
for i = 1:length(mri)
    mri2{i} = doIt(mri(i),keepFlag);
end
mri = [mri2{:}];




function mri = doIt(mri,keepFlag)

%% Add some info to the output struct
if ~isfield(mri,'volInfo'); [mri.volInfo] = deal(strjoin({'X' 'Y' 'Z' 'freq/time' 'taper' 'run'},' x ')); end
if ~isfield(mri,'vecInfo'); [mri.vecInfo] = deal(strjoin({'freq/time' 'vox' 'taper' 'run'},' x ')); end

if ~isfield(mri,'vec') || isempty(mri.vec) && ~isempty(mri.vol)
    % already in volume format
    return
end
if ~isfield(mri,'height') && ~isfield(mri,'width') && ~isfield(mri,'depth')
    % not a volume
    mri.vol = permute(mri.vec,[2 3 4 1]);
    mri.vec = [];
    return
end

if ~isfield(mri,'nruns')
    mri.nruns = size(mri.vec,4);
end
if ~isfield(mri,'ntapers')
    mri.ntapers = size(mri.vec,3);
end
if ~isfield(mri,'nfreq')
    if prod(size(mri.vec,[1 4]))~=mri.nruns*mri.nframes
        dbstack; error('nframes*nruns incorrect')
    end
else
    if prod(size(mri.vec,[1 4]))~=mri.nruns*mri.nfreq
        dbstack; error('nframes*nruns incorrect')
    end
end
nframes = size(mri.vec,1);
nruns = size(mri.vec,4);
if islogical(mri.vec)
    mri.vol = false(nframes,mri.ntapers,nruns,mri.height,mri.width,mri.depth);
else
    mri.vol =   nan(nframes,mri.ntapers,nruns,mri.height,mri.width,mri.depth,class(mri.vec));
end
mri.vol(:,:,:,mri.vol2vec) = permute(mri.vec,[1 3 4 2]);
mri.vol = permute(mri.vol,[4 5 6 1 2 3]);
if ~keepFlag
    mri.vec = [];
end
% if isfield(mri,'vecMean')
%     mri.volMean = nan(1,mri.ntapers,mri.nruns,mri.height,mri.width,mri.depth);
%     mri.volMean(:,:,:,mri.vol2vec) = permute(mri.vecMean,[1 3 4 2]);
%     mri.volMean = permute(mri.volMean,[4 5 6 1 2 3]);
%     mri.vecMean = [];
% end