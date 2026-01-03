function MRIwriteDummy(filename, data, tr)
% CREATE_DUMMY_NIFTI Create a dummy NIFTI timeseries file
%
% Usage:
%   MRIwriteDummy('dummy_timeseries.nii', [1 2 3 4 5], 2)  % Single voxel
%   MRIwriteDummy('dummy_timeseries.nii', rand(100, 10), 2)  % 100 timepoints, 10 voxels
%   MRIwriteDummy('dummy_timeseries.nii')  % Default: 5 timepoints, 1 voxel, TR=2s
%
% Inputs:
%   filename - Output NIFTI filename (default: 'dummy_timeseries.nii')
%   data     - Timeseries data matrix: [timepoints x voxels] (default: [1 2 3 4 5])
%              Rows = time, Columns = voxels
%   tr       - Repetition time in seconds (default: 2)

if ~exist('filename', 'var') || isempty(filename)
    filename = 'dummy_timeseries.nii';
end

if ~exist('data', 'var') || isempty(data)
    data = [1 2 3 4 5];
end

if ~exist('tr', 'var') || isempty(tr)
    tr = 2; % seconds
end

% Ensure data is 2D: [timepoints x voxels]
if isvector(data)
    data = data(:);  % Make column vector: [timepoints x 1] (single voxel)
end

[n_timepoints, n_voxels] = size(data);

% Reshape data to 4D: [x y z time]
% Arrange voxels along x-axis: [n_voxels x 1 x 1 x n_timepoints]
data_4d = reshape(data', [n_voxels 1 1 n_timepoints]);

% Create MRI structure (FreeSurfer format)
mri = struct();
mri.vol = data_4d;
mri.vox2ras0 = eye(4);  % Identity transformation matrix
mri.volres = [1 1 1];   % 1mm voxel size
mri.tr = tr * 1000;     % TR in milliseconds
mri.te = 0;
mri.ti = 0;
mri.flip_angle = 0;
mri.nframes = n_timepoints;

% Write NIFTI file using FreeSurfer's MRIwrite
% % Add FreeSurfer MATLAB path if needed
% if ~exist('MRIwrite', 'file')
%     % Try common FreeSurfer paths
%     fs_paths = {
%         '/usr/local/freesurfer/matlab',
%         '/opt/freesurfer/matlab',
%         getenv('FREESURFER_HOME')
%     };
%     for p = fs_paths
%         if ~isempty(p{1}) && exist(fullfile(p{1}, 'MRIwrite.m'), 'file')
%             addpath(p{1});
%             break;
%         end
%     end
% end

if ~exist('MRIwrite', 'file')
    error('MRIwrite not found. Please add FreeSurfer MATLAB path or use AFNI tools instead.');
end

MRIwrite(mri, filename);
fprintf('Created %s: %d timepoints, %d voxels, TR=%.1fs\n', filename, n_timepoints, n_voxels, tr);

end
