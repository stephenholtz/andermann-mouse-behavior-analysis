%% getEpiRoiDff.m
%
% Uses data from preprocessing to find which inds are needed for calculating
% 1 - dff in stimuli that include LED stimulation (to avoid the saturated 
% frames), 
% 2 - dff for those that did not have LED stimulation (but also take same 
% rough bounds for comparison).
%
% SLH

%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140815_01';
% Get the base location for data, see function for details
dataDir = getExpDataSource('macbook');
% Experiment directory
expDir  = fullfile(dataDir,animalName,expDateNum);
% Processed data filepath
procDir = fullfile(expDir,'proc');

%% Determine the inds

%% Save the inds?

%% Load sample frame to set ROI(s)
epiTiffPath = dir([procDir filesep 'epi_*.tiff']);
epiTiffPath = fullfile(procDir,epiTiffPath(1).name);
% command will be slow due to large file size
if ~exist('epiImInfo','var')
    epiImInfo   = imfinfo(epiTiffPath);
end
nRois = 1;

epiSampImage= imread(epiTiffPath,1);
for iRoi = 1:nRois
    clf;
    sampleFrame = epiSampImage(:,:,1);
    imagesc(sampleFrame);
    [   roi(iRoi).bw,...
        roi(iRoi).x,...
        roi(iRoi).y,...
        roi(iRoi).ix,...
        roi(iRoi).iy    ] = roipoly(sampleFrame);
    croppedroi = sampleFrame.*roi(iRoi).bw;
    imagesc(croppedroi)
end

%% Pull in tiff stack(s) and apply ROI mask
if ~exist('epi','var');
    epi = loadtiff(epiTiffPath);
end

%% save raw epi ROI timeseries data (? depends on how slow)


%% Calculate the dff for each set -- and save?


