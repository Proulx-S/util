function mri = vol2vec(mri,mask,forceFlag,keepFlag)
% vol2vec.m and vec2vol.m
% To be used with MRIread.m and MRIwrite.m from Freesurfer
% (/usr/local/freesurfer/dev/matlab/).
% Moves from a 4D (voxX x voxY x voxZ x time) volume timeseries to a
% vectorize 2D (time X vox) format using a user-specified mask (vol2vec.m),
% and vice-versa (vec2vol.m).
% This saves memory while keeping data in a compatible format.
% When no mask is provided, only voxels that are not all zeros and do not
% contain nans are used.
% forceFlag = -1; will skip the main task of vectorizing the 3d volume but
% will still do the other small things this function is doing.
if ~exist('mask','var')
    mask = [];
    noMaskFlag = true;
else
    noMaskFlag = false;
end
if ~exist('forceFlag','var')
    forceFlag = false;
end
if ~exist('keepFlag','var')
    keepFlag = false;
end
if ~isfield(mri,'imMean')
    for runInd = 1:length(mri)
        mri(runInd).imMean = mean(mri(runInd).vol,4);
    end
end

if ischar(mask) && exist(mask,'file')
    mask = MRIread(mask);
end
mri2 = cell(size(mri));
for i = 1:length(mri)
    mri2{i} = doIt(mri(i),mask,forceFlag,keepFlag);
end
if diff(size(mri2))<0
    mri = cat(1,mri2{:});
else
    mri = cat(2,mri2{:});
end


function mri = doIt(mri,mask,forceFlag,keepFlag)
if ~isfield(mri,'t'); mri.t = []; end
if ~isfield(mri,'nDummy'); mri.nDummy = []; end

%% Add some info to the output struct
if ~isfield(mri,'volInfo'); [mri.volInfo] = deal(strjoin({'X' 'Y' 'Z' 'time/freq' 'taper/mode' 'run'},' x ')); end
if ~isfield(mri,'vecInfo'); [mri.vecInfo] = deal(strjoin({'time/freq' 'vox' 'taper/mode' 'run'},' x ')); end

%% Add time vector
if ~isfield(mri,'tr') && isfield(mri,'Fs')
    mri.tr = 1/mean(mri.Fs)*1000;
end
if ~isfield(mri,'nframes')
    mri.nframes = mri.nFrame;
end

if isempty(mri.nDummy)
    mri.nDummy = nan;
end
nDummy = mri.nDummy; if isnan(nDummy); nDummy = 0; end
if isempty(mri.t)
    
    mri.t = ( (0:mri.nframes-1).*(mri.tr/1000) )'';
end

%% Exit if enough
if isempty(mri.vol) && isfield(mri,'vec') && ~isempty(mri.vec); return; end

%% Set mask to vol2vec
if exist('mask','var') && ~isempty(mask) && ~isempty(mri.vol)
    
    if ~forceFlag && isfield(mri,'vol2vec') && ~isempty(mri.vol2vec)
        % vol2vec is already specified, proceed only if forceFlag is provided
        dbstack
        error('mask already exists, use forceFlag to override')
    end
    % identify if mask is defined as a logical mask or indices, then define
    % vol2vec as logical mask
    if isMRI(mask)
        mri.vol2vec = logical(mask.vol);
    elseif length(mask)==1 || ~all(mask(:)==0 | mask(:)==1) % then mask is an index
        mri.vol2vec = false(mri.volsize);
        mri.vol2vec(mask) = true;
    else
        mri.vol2vec = logical(mask);
    end
    mri.vol2vecFlag = 'customMask';
else
    if ~isfield(mri,'vol2vec') || isempty(mri.vol2vec)
        % if mask not specified, initate vol2vec inclubnding all voxels except those with nans or all
        % zeroes
        zeroMask = all(mri.vol(:,:,:,:)==0,4);
        nanMask = any(isnan(mri.vol(:,:,:,:)),4);
        mri.vol2vec = ~zeroMask & ~nanMask;
        if any(~mri.vol2vec(:))
            mri.vol2vecFlag = 'validVoxMask';
        else
            mri.vol2vecFlag = 'allVoxMask';
        end
    end
end

%% Exit if enough
if forceFlag==-1; return; end

%% Vectorize according to vol2vec
tmp = permute(mri.vol,[4 5 6 7 1 2 3]);
mri.vec = permute(tmp(:,:,:,:,mri.vol2vec),[1 5 2 3 4]);
if ~keepFlag
    mri.vol = [];
end
fieldList = {'chanLabel' 't0' 'Fs'};
for i = 1:length(fieldList)
    if isfield(mri,fieldList{i}) && all(size(mri.(fieldList{i}),[1 2])==size(mri.vol2vec))
        mri.(fieldList{i}) = mri.(fieldList{i})(mri.vol2vec);
    end
end
% if isfield(mri,'volMean')
%     tmp = permute(mri.volMean,[4 5 6 7 1 2 3]);
%     mri.vecMean = permute(tmp(:,:,:,:,mri.vol2vec),[1 5 2 3 4]); clear tmp
%     mri.volMean = [];
% end


%% Beautigy a little
mri = setNiceFieldOrder(mri,{'vol' 'vol2vec' 'vec'});
