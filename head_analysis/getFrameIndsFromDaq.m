%% getFrameIndsFromDaq.m
% Determine which points in the DAQ's timeseries correspond to camera frame numbers
%
% headFrame = frame number of the head-on camera view (ptGrey in current setup)
% epiFrame  = frame number of the epifluorescence camera (qImaging in current setup)
%
% TODO: add eyeFrame for eye tracking camera's frame. This will require some 
% investigation of problems matching the counter to the number of frames
% TODO: make function that takes exp as argument
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

%% Initalize
forceClear = 1;
if forceClear
    close all force; 
    clear all force;
end

% General Flags
verbose     = 1;

%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140815_01';

% Retrieve folder location
dataDir     = getExpDataSource('macbook');
expDir      = fullfile(dataDir,animalName,expDateNum);
if verbose; fprintf('expDir: %s\n',expDir); end

% Load nidaq mat file
nidaqFileName = dir(fullfile(expDir,['nidaq_*.mat']));
nidaqFilePath = fullfile(expDir,nidaqFileName.name);
if verbose; fprintf('\tLoading daq file: %s\n',nidaqFileName(1).name); end
% loads in 'exp' struct
load(nidaqFilePath);

% Load processed head tracking info
if 0
headTrackFileName = dir(fullfile(expDir,['headTrack.mat']));
headTrackFilePath = fullfile(expDir,['headTrack.mat']);
if verbose; fprintf('\tLoading head tracking file: %s\n',headTrackFileName(1).name); end
% loads in stackRegOut
load(headTrackFilePath); 
end

%% Determine frame timseries information
% Preallocate nans
epiFrame    = nan(numel(exp.Count),1);
headFrame   = nan(numel(exp.Count),1);
eyeFrame    = nan(numel(exp.Count),1);

% Channel names should be stored in exp.daqInNames for verification
if ~exist('daqIndIds','var')
    daqIndId.epiStrobe  = 8;
    daqIndId.headStrobe = 9;
    daqIndId.eyeCount   = 17;
end

%  
headStrobe = exp.Data(daqIndId.headStrobe,:);
headStrobeOnsets = [0 diff(headStrobe) > 0];
headFrameNums = cumsum(headStrobeOnsets);

disp(headFrameNums(end))

%epiStrobe = exp.Data(daqIndId.epiStrobe,:);
%cumEpiStrobe = cumsum(epiStrobe);


%plot(headStrobe);
%hold all
%plot(cumsum(headStrobe));


% 
