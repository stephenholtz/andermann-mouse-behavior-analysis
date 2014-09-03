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
%        /proc/eye*.avi
%        /proc/eyeStack/*.tiff
%        /proc/faceStack/*.tiff
%        /proc/epiStack/*.tiff
%        /proc/frameNums.mat
%        /proc/stimTsInfo.mat
%        .... filled in by this script's functions
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
forceClear = 1;
if forceClear
    clear all force
    close all force
    fprintf('Cleared workspace\n');
end
ticH = tic;

%% Set Animal/Experiment Specific information
animalName      = 'K51';
experimentName  = '20140902_01';

% Process only some of files
processEyeFiles     = 0;
processFaceFiles    = 1;
processEpiFiles     = 0;
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

    % Only make the avi file if needed
    eyeAviFileName = fullfile(procDir,['eye_' animalName '_' experimentName '.avi']);
    if ~exist(eyeAviFileName,'file')
        jpegsToAvi(eyeFileNames,eyeDir,eyeAviFileName);
    end
    
    eyeStackDir = fullfile(procDir,'eyeStacks');
    if ~exist(eyeStackDir,'dir')
        mkdir(eyeStackDir)
    end

    % These frames are already poorly compressed, might as well save them losslessly
    compression = 'lzw';
    useBigTiff = false;
    
    eyeTiffFileName = ['eye_' animalName '_' experimentName '.tiff'];

    [~,fN,ext] = fileparts(eyeAviFileName);
    movie2TiffDir([fN,ext],procDir,eyeTiffFileName,eyeStackDir,compression,useBigTiff);

elseif ~processEyeFiles
    fprintf('Skipping eye file preprocessing...\n')
else
    error('eyeDir not found')
end

%% Convert face tracking avi files to tiff stacks
faceDir = fullfile(rawDir,'face');
if exist(faceDir,'dir') && processFaceFiles
    fprintf('Starting face file preprocessing...\n')
    faceDirFiles = dir([faceDir filesep '*.avi']);
    faceFileNames = {faceDirFiles.name};

    % Get the number of frames in the movies for error checking
    movFrames = getNumMovFrames(faceFileNames,faceDir);
    
    % Convert avi to tiff and mat files (expects cell array)
    compression = 'PackBits';
    useBigTiff = false;

    faceStackDir = fullfile(procDir,'faceStacks');
    if ~exist(faceStackDir,'dir')
        mkdir(faceStackDir)
    end

    faceTiffName = [animalName '_' experimentName '.tiff'];
    movie2TiffDir(faceFileNames,faceDir,faceTiffName,faceStackDir,compression,useBigTiff);

elseif ~processFaceFiles
    fprintf('Skipping face file preprocessing...\n')
else
    error('faceDir not found')
end

%% Convert epifluorescence avi files to tiff stacks
epiDir = fullfile(rawDir,'epi');
if exist(epiDir,'dir') && processEpiFiles
    fprintf('Starting epi file preprocessing...\n')
    % Should only be one movie file with epi data AND exp in the name
    epiDirFiles = dir([epiDir filesep 'epi*exp*.*']);
    if isempty(epiDirFiles)
        error('No epi experiment files found')
    elseif numel(epiDirFiles) > 1
        warning('Multiple epi experiment files found!')
    else
        epiFileNames = {epiDirFiles(1).name};
    end

    epiStackDir = fullfile(procDir,'epiStacks');
    if ~exist(epiStackDir,'dir')
        mkdir(epiStackDir)
    end
    
    useBigTiff = false;
    % LZW or PackBits is fine, lzw might be faster faster, but less comp.
    compression = 'lzw';
    
    epiTiffName = ['epi_' animalName '_' experimentName '.tiff'];
    movie2TiffDir(epiFileNames,epiDir,epiTiffName,epiStackDir,compression,useBigTiff);
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
    if ~exist('daq','var')
        load(nidaqFilePath);
    end

    % Retrieve camera frame numbers from daq
    % Channel names are stored in daq.daqInNames for verification
    daqCh.epiStrobe  = 8;
    daqCh.faceStrobe = 9;
    daqCh.eyeCount   = 17;

    fprintf('Finding frame onsets in daq data\n');
    [frameNums.face,frameNums.faceIfi] = getCamFrameNumFromDaq(daq.Data(daqCh.faceStrobe,:),'strobe',0);
    [frameNums.eye,frameNums.eyeIfi]   = getCamFrameNumFromDaq(daq.Data(daqCh.eyeCount,:),'counter',0);
    [frameNums.epi,frameNums.epiIfi]   = getCamFrameNumFromDaq(daq.Data(daqCh.epiStrobe,:),'strobe',1);
    
    % Save the frame rate
    frameNums.faceRate = (median(frameNums.faceIfi) \ daq.daqRate);
    frameNums.eyeRate = (median(frameNums.eyeIfi) \ daq.daqRate);
    frameNums.epiRate = (median(frameNums.epiIfi) \ daq.daqRate);
    
    % Save stimulus timing info
    frameNumsFile = fullfile(procDir,['frameNums.mat']);
    save(frameNumsFile,'frameNums','-v7.3');

    % Retrieve stimulus locations within timeseries LED on / off and signals from the 
    % psychtoolbox let me reconstruct exp timeseries
    daqCh.LED       = 1;
    daqCh.PTB       = 2;

    % For easy parsing, specify inter stim interval
    interStimInt = stim.durOff;
    fprintf('Finding stimulus onsets in daq data\n');
    [stimOnOff,stimOnsets,stimOffsets] = ptbFramePulsesToSquare(daq.Data(daqCh.PTB,:),daq.daqRate,interStimInt);
    % LED signal is very reliable, no need to clean up timing info
    ledOnOff = daq.Data(daqCh.LED,:) > 3.5;

    % Generate structure with stimulus types and timing (+ other variables for debug)
    stimStruct       = getPtbStimTsInfo(stimOnOff,ledOnOff,stim);
    stimTsInfo.all   = stimStruct;
    % Convert logical fields to doubles here rather than in processing scripts (Plenty-O-HDD space)
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
