%% getNumFrames.m
%
% Quick script to sequentially loads in movie frames 
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140815_01';

% Retrieve folder location
dataDir     = getExpDataSource('macbook');
expDir      = fullfile(dataDir,animalName,expDateNum);

% Find all the avi files (a bit of unneeded specificity)
movieDirName = 'whisker';
movieFileBaseName = 'whisker';
aviLocation = fullfile([expDir filesep movieDirName]);
aviFileStruct = dir([aviLocation filesep movieFileBaseName '*.avi']);
% Sort the files by datenum to fix ordering problems
[~,aviOrder]= sort([aviFileStruct(:).datenum]);
aviFiles = {aviFileStruct(aviOrder).name}; 

%% Import avi files and select ROI(s)
% set up object instances
for iAvi = 1:numel(aviFiles)
    vObj(iAvi) = VideoReader(fullfile(aviLocation,aviFiles{iAvi}));
%    [~] = read(vObj(iAvi),inf);
    nFrames(iAvi) = vObj(iAvi).NumberOfFrames;
end
totalFrames = sum(nFrames);
