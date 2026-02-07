function [mriCoef, fOut] = afni_getFitCoef(fStat, fOut, force)
% afni_getFitCoef - Extract all fitted coefficient sub-bricks from AFNI stats bucket to .nii.gz
%
% [mriCoef, fOut] = afni_getFitCoef(fStat)
% [mriCoef, fOut] = afni_getFitCoef(fStat, fOut)
% [mriCoef, fOut] = afni_getFitCoef(fStat, fOut, force)
%
% Inputs:
%   fStat - Path prefix to the AFNI stats dataset (e.g. .../task-*_cond-FULL_model-*_stats).
%           Dataset on disk: fStat+orig.HEAD / fStat+orig.BRIK
%   fOut  - (optional) Output .nii.gz path. Default: [fStat '_all_coefs.nii.gz']
%   force - (optional) If true, overwrite existing fOut. Default: false
%
% Outputs:
%   mriCoef - MRI struct from MRIread (4D vol: coef sub-bricks including baseline).
%   fOut    - Path to the created .nii.gz (all _Coef sub-bricks, including baseline).
%
% When only fStat and one output are requested, output is written to a temp file,
% read into mriCoef, then the temp file is deleted.
%
% Requires global src.afni set (e.g. 'ml afni/24.3.00' or path to AFNI env).
global src
if ~exist('src', 'var') || ~isfield(src, 'afni') || isempty(src.afni)
    error('afni_getFitCoef:NoAfni', 'Global src.afni must be set to load AFNI (e.g. ''ml afni/24.3.00'').');
end

useTemp = (nargin < 2 || isempty(fOut)) && (nargout == 1);
if nargin < 2 || isempty(fOut)
    if useTemp
        fOut = [tempname '.nii.gz'];
    else
        fOut = [char(fStat) '_all_coefs.nii.gz'];
    end
else
    fOut = char(fOut);
end
if nargin < 3 || isempty(force)
    force = false;
end

fStat = char(fStat);
inHead = [fStat '+orig.HEAD'];
inBrik = [fStat '+orig.BRIK'];

if ~(exist(inHead, 'file') || exist(inBrik, 'file'))
    error('afni_getFitCoef:MissingDataset', 'AFNI dataset not found: %s (+orig.HEAD or +orig.BRIK)', fStat);
end

if ~useTemp && ~force && exist(fOut, 'file')
    if nargout >= 1
        mriCoef = MRIread(fOut);
    end
    return;
end

inAfni = [fStat '+orig'];
cmd = {src.afni};
cmd{end+1} = ['3dinfo -label "' inAfni '"'];
[err, labelsStr] = system(strjoin(cmd, newline));
if err
    msg = ['3dinfo failed:' newline labelsStr];
    error('afni_getFitCoef:3dinfo', msg);
end

% 3dinfo -label outputs one label per sub-brick, separated by pipe
labels = strsplit(strtrim(labelsStr), '|');
idx = find(contains(labels, '_Coef'))-1;


if isempty(idx)
    error('afni_getFitCoef:NoCoef', 'No sub-brick with label containing _Coef in %s', inAfni);
end

sel = ['[' strjoin(arrayfun(@(x) num2str(x), idx, 'UniformOutput', false), ',') ']'];
cmd = {src.afni};
cmd{end+1} = sprintf('3dbucket -overwrite -prefix "%s" "%s%s"', fOut, inAfni, sel);
[err, cmdOut] = system(strjoin(cmd, newline));
if err
    msg = ['3dbucket failed:' newline cmdOut];
    error('afni_getFitCoef:3dbucket', msg);
end

if nargout >= 1
    mriCoef = MRIread(fOut);
end
if useTemp
    delete(fOut);
end

end
