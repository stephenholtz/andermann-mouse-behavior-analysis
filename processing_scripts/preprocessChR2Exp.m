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
%        /proc/stimInfo.mat
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
ticH = tic;

%% Set Animal/Experiment Specific information
animalName      = 'K71';
experimentName  = '20140815_01';

% Process only some of files (testing time)
processEyeFiles     = 0;
processFaceFiles    = 0;
processEpiFiles     = 1;
processNidaqData    = 0;

%% Establish base filepaths

% Get the base location for data, see function for details
if ispc
    dataDir = getExpDataSource('atlas-pc');
elseif ismac
    dataDir = getExpDataSource('macbook');
end

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
%% Convert eye tracking jpegs to Avi (for easier viewing) then to tiff
eyeDir = fullfile(rawDir,'eye');
if exist(eyeDir,'dir') && processEyeFiles
    fprintf('Starting eye file preprocessing...\n')
    % Sort the file names and pass to converter fuction
    eyeDirFiles = dir([eyeDir filesep '*.jpg']);
    [~,eyeFileOrder]= sort([eyeDirFiles(:).datenum]);
    eyeFileNames = {eyeDirFiles(eyeFileOrder).name};

    eyeAviFileName = fullfile(procDir,['eye_' animalName '_' experimentName '.avi']);
    %aviFileInfo = jpegsToAvi(eyeFileNames,eyeDir,eyeAviFileName);

    eyeStackDir = fullfile(procDir,'eyeStacks');
    if ~exist(eyeStackDir,'dir')
        mkdir(eyeStackDir)
    end

    % These frames are already poorly compressed, might as well save them lossless
    compression = 'lzw';
    eyeTiffFileName = ['eye_' animalName '_' experimentName '.tiff'];

    [~,fN,ext] = fileparts(eyeAviFileName);
    aviToTiffDir({[fN,ext]},procDir,eyeTiffFileName,eyeStackDir,compression);

elseif ~processEyeFiles
    fprintf('Skipping eye file preprocessing...\n')
else
    error('eyeDir not found')
end

%% Convert face tracking avi files to tiff stacks
faceDir = fullfile(rawDir,'face');
if exist(faceDir,'dir') && processFaceFiles
    fprintf('Starting face file preprocessing...\n')
    % Sort the file names and pass to converter function
    faceDirFiles = dir([faceDir filesep '*.avi']);
    [~,faceFileOrder]= sort([faceDirFiles(:).datenum]);
    faceFileNames = {faceDirFiles(faceFileOrder).name};

    % Convert avi to tiff and mat files (expects cell array)
    compression = 'jpeg';

    faceStackDir = fullfile(procDir,'faceStacks');
    if ~exist(faceStackDir,'dir')
        mkdir(faceStackDir)
    end

    faceTiffName = [animalName '_' experimentName '.tiff'];
    aviToTiffDir(faceFileNames,faceDir,faceTiffName,faceStackDir,compression);

elseif ~processFaceFiles
    fprintf('Skipping face file preprocessing...\n')
else
    error('faceDir not found')
end

%% Convert epifluorescence avi files to tiff stacks
epiDir = fullfile(rawDir,'epi');
if exist(epiDir,'dir') && processEpiFiles
    fprintf('Starting epi file preprocessing...\n')
    % Should only be one avi file with epi data
    epiDirFiles = dir([epiDir filesep 'epi*.avi']);
    epiFileNames = {epiDirFiles(1).name};

    epiStackDir = fullfile(procDir,'epiStacks');
    if ~exist(epiStackDir,'dir')
        mkdir(epiStackDir)
    end

    compression = 'lzw';
    epiTiffName = ['epi_' animalName '_' experimentName '.tiff'];
    aviToTiffDir(epiFileNames,epiDir,epiTiffName,epiStackDir,compression);
elseif ~processEpiFiles
    fprintf('Skipping epi files preprocessing...\n')
else
    error('faceDir not found')
end

%% process Nidaq data
if processNidaqData
    fprintf('Starting nidaq / metadata processing...\n')

    % loads in metadata
    metaFileName = dir(fullfile(rawDir,['stimulus_metadata_*.mat']));
    metaFilePath = fullfile(rawDir,metaFileName(1).name);
    load(metaFilePath)

    % loads in poorly named 'exp' struct
    nidaqFileName = dir(fullfile(rawDir,['nidaq_*.mat']));
    nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);
    if ~exist('exp','var')
        load(nidaqFilePath);
    end

    % Retrieve camera frame numbers from daq
    % Channel names are stored in exp.daqInNames for verification
    daqCh.epiStrobe  = 8;
    daqCh.faceStrobe = 9;
    daqCh.eyeCount   = 17;

    fprintf('Finding frame onsets in daq data\n');
    [frameNums.face,frameNums.faceIfi] = getCamFrameNumFromDaq(exp.Data(daqCh.faceStrobe,:),'strobe',0);
    [frameNums.eye,frameNums.eyeIfi]   = getCamFrameNumFromDaq(exp.Data(daqCh.eyeCount,:),'counter',0);
    [frameNums.epi,frameNums.epiIfi]   = getCamFrameNumFromDaq(exp.Data(daqCh.epiStrobe,:),'strobe',1);

    % Save stimulus timing info
    frameNumsFile = fullfile(procDir,['frameNums.mat']);
    save(frameNumsFile,'frameNums','-v7.3');

    % Retrieve stimulus locations within timeseries LED on / off and signals from the 
    % psychtoolbox let me reconstruct exp timeseries
    daqCh.LED       = 1;
    daqCh.PTB       = 2;

    % For easy parsing, specify inter stim interval
    interStimInt = 0.5;
    fprintf('Finding stimulus onsets in daq data\n');
    [stimOnOff,stimOnsets,stimOffsets] = ptbFramePulsesToSquare(exp.Data(daqCh.PTB,:),exp.daqRate,interStimInt);
    % LED signal is very reliable, no need to clean up timing info
    ledOnOff = exp.Data(daqCh.LED,:) > 3.5;

    % Generate structure with stimulus types and timing (+ other variables for debug)
    stimStruct       = getPtbStimTsInfo(stimOnOff,ledOnOff,stim);
    stimTsInfo.all   = stimStruct;
    stimTsInfo.ptb   = 0+stimOnOff(:);
    stimTsInfo.ledOn = 0+ledOnOff(:);

    % Save stimulus timing info
    stimulusIndsInfoFile = fullfile(procDir,['stimTsInfo.mat']);
    save(stimulusIndsInfoFile,'stimTsInfo','-v7.3');
else
    fprintf('Skipping nidaq processing...\n')
end

tElapsed = toc(ticH);
fprintf('Time elapsed: %2.2f seconds\n',tElapsed/60)
