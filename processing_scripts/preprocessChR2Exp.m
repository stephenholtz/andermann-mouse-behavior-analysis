%% preprocessChR2Exp.m
%
% Initial file proessing for experiments. Goal of making analysis/hacking
% easier afterwards. Requires entire analysis directory being in matlab's
% path. And hopefully nothing else.
%
% Expected file directory / locations:
% /expDir/raw/...
%        /raw/eye/*.jpeg
%        /raw/face/*.avi
%        /raw/epi/epi*.avi
%        /raw/nidaq_*.mat
%        /raw/stimulus_*.mat
%        /proc/...
%        /proc/*.tiff
%        .... filled in by this script's functions
%
% TODO: update file directory above with expected ouptut
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
forceClear = 0;
if forceClear
    clear all force
    close all force
    fprintf('Cleared workspace\n');
end

%% Set Animal/Experiment Specific information
animalName      = 'K71';
experimentName  = '20140815_01';

% Process only some of files (testing time)
processEyeFiles     = 1;
processFaceFiles    = 1;
processEpiFiles     = 1;
processNidaqData    = 1;

%% Establish base filepaths

% Get the base location for data, see function for details
dataDir = getExpDataSource('macbook');
% Experiment directory
expDir  = fullfile(dataDir,animalName,experimentName);
% Raw data filepath 
rawDir  = fullfile(expDir,'raw');
% Processed data filepath
procDir = fullfile(expDir,'proc');

% Check / make  general filestructure
if ~exist(dataDir,'dir')
    error('dataDir not found')
elseif ~exist(expDir,'dir')
    error('expDir not found')
elseif ~exist(rawDir,'dir')
    error('expects a ''raw'' directory within expDir')
else
    % everything checks out, make a processed File directory
    if ~exist(procDir,'dir')
        mkdir(procDir)
    end
end

%% Convert all videos to tiff stacks and mat files

% Convert eye tracking jpegs to Avi, then to tiff
eyeDir = fullfile(rawDir,'eye');
if exist(eyeDir,'dir') && processEyeFiles
    fprintf('Starting eye file preprocessing\n')
    % Sort the file names and pass to converter fuction
    eyeDirFiles = dir([eyeDir filesep '*.jpg']);
    [~,eyeFileOrder]= sort([eyeDirFiles(:).datenum]);
    eyeFileNames = {eyeDirFiles(eyeFileOrder).name};

    eyeAviFileName = fullfile(procDir,['eye_' animalName '_' experimentName '.avi']);
    aviFileInfo = jpegsToAvi(eyeFileNames,eyeDir,eyeAviFileName);

    % Convert avi to tiff and mat files (expects cell array)
    compressionType = 'jpeg';
    eyeTiffFileName = fullfile(procDir,['eye_' animalName '_' experimentName '.tiff']);
    [~,fN,ext] = fileparts(eyeAviFileName);
    [eyeTiffInfo, eyeMat] = aviToMatBigTiff({[fN,ext]},procDir,eyeTiffFileName,compressionType);
    % 41235 had issue "comma separated list has zero items"
elseif ~processEyeFiles
    fprintf('Skipping eye file preprocessing\n')
else
    error('eyeDir not found')
end

% Convert face tracking avi files to tiff stacks
faceDir = fullfile(rawDir,'face');
if exist(faceDir,'dir') && processFaceFiles
    fprintf('Starting face file preprocessing\n')
    % Sort the file names and pass to converter function
    faceDirFiles = dir([faceDir filesep '*.avi']);
    [~,faceFileOrder]= sort([faceDirFiles(:).datenum]);
    faceFileNames = {faceDirFiles(faceFileOrder).name};

    % Convert avi to tiff and mat files (expects cell array)
    compressionType = 'jpeg';
    faceTiffFileName = fullfile(procDir,['face_' animalName '_' experimentName '.tiff']);
    [faceTiffInfo, faceMat] = aviToMatBigTiff(faceFileNames,faceDir,faceTiffFileName,compressionType);
elseif ~processFaceFiles
    fprintf('Skipping face file preprocessing\n')
else
    error('faceDir not found')
end

% Convert epifluorescence avi files to tiff stacks
epiDir = fullfile(rawDir,'epi');
if exist(epiDir,'dir') && processEpiFiles
    fprintf('Starting epi file preprocessing\n')
    % Should only be one avi file with epi data
    epiDirFiles = dir([epiDir filesep 'epi*.avi']);
    epiFileNames = {epiDirFiles(1).name};

    % Convert avi to tiff and mat files
    compressionType = 'lzw';
    epiTiffFileName = fullfile(procDir,['epi_' animalName '_' experimentName '.tiff']);
    [epiTiffInfo, epiMat] = aviToMatBigTiff(epiFileNames,epiDir,epiTiffFileName,compressionType);
elseif ~processEpiFiles
    fprintf('Skipping epi files preprocessing\n')
else
    error('faceDir not found')
end

%% process Nidaq data
if processNidaqData
    fprintf('Starting nidaq processing\n')
    nidaqFileName = dir(fullfile(rawDir,['nidaq_*.mat']));
    nidaqFilePath = fullfile(rawDir,nidaqFileName.name);

    % loads in 'exp' struct
    load(nidaqFilePath);

    % Retrieve camera frame numbers from daq
    daqCh.epiStrobe  = 8;
    daqCh.faceStrobe = 9;
    daqCh.eyeCount   = 17;

    faceFrameNums = getFrameNumFromDaq(exp.Data(daqCh.faceStrobe,:),'strobe');
    eyeFrameNums = getFrameNumFromDaq(exp.Data(daqCh.eyeCount,:),'counter');
    epiFrameNums = getFrameNumFromDaq(exp.Data(daqCh.epiStrobe,:),'strobe');

    % Retrieve stimulus locations within timeseries 
    daqCh.LED       = 1;
    daqCh.ptb       = 2;

    %getStimTypeIndsFromDaq(exp.Data(daqCh.LED));

else
    fprintf('Skipping nidaq processing\n')
end

