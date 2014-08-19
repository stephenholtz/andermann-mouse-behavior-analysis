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

%% Set Animal/Experiment Specific information
animalName      = 'K71';
experimentName  = '20140815_01';

% Process only some of files (testing time)
processEyeFiles     = 0;
processFaceFiles    = 1;
processEpiFiles     = 0;
processNidaqData    = 0;

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
    loadType = 'allAtOnce';
    eyeTiffFileName = fullfile(procDir,['eye_' animalName '_' experimentName '.tiff']);
    [~,fN,ext] = fileparts(eyeAviFileName);
    eyeTiffInfo = aviToMatBigTiff({[fN,ext]},procDir,eyeTiffFileName,compressionType,loadType);
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
    % Load types: allAtOnce, or serial
    loadType = 'allAtOnce';
    faceTiffFileName = fullfile(procDir,['face_' animalName '_' experimentName '.tiff']);
    faceTiffInfo = aviToMatBigTiff(faceFileNames,faceDir,faceTiffFileName,compressionType,loadType);
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
    fprintf('Starting nidaq / metadata processing\n')

    % loads in metadata
    metaFileName = dir(fullfile(rawDir,['stimulus_metadata_*.mat']));
    metaFilePath = fullfile(rawDir,metaFileName(1).name);
    load(metaFilePath)

    % Construct stimulus order (should place in exp script in the future)
    if isfield(stim,'stimTypeOrder')
        stimOrder = stim.stimTypeOrder; 
    else
        % Numbers all conditions with unique values
        stimOrder = zeros(numel(stim.stimLocOrder)*stim.nRepeats,1);
        for iStim = 1:numel(stimOrder)
            stimInd = 1+mod(iStim-1,numel(stim.stimLocOrder));
            stimOrder(iStim) = stim.stimLocOrder(stimInd) + numel(unique(stim.stimLocOrder))*stim.ledOnOffOrder(stimInd);
        end
    end

    % loads in 'exp' struct
    nidaqFileName = dir(fullfile(rawDir,['nidaq_*.mat']));
    nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);
    load(nidaqFilePath);

    % Retrieve camera frame numbers from daq
    % Channel names are stored in exp.daqInNames for verification
    daqCh.epiStrobe  = 8;
    daqCh.faceStrobe = 9;
    daqCh.eyeCount   = 17;

    fprintf('Finding frame onsets in daq data\n');
    frameNums.face= getFrameNumFromDaq(exp.Data(daqCh.faceStrobe,:),'strobe');
    frameNums.eye= getFrameNumFromDaq(exp.Data(daqCh.eyeCount,:),'counter');
    frameNums.epi= getFrameNumFromDaq(exp.Data(daqCh.epiStrobe,:),'strobe');

    % Save stimulus timing info
    frameNumsFile = fullfile(procDir,['frameNums.mat']);
    save(frameNumsFile,'frameNums','-v7.3');

    % Retrieve stimulus locations within timeseries LED on / off and signals from the 
    % psychtoolbox let me reconstruct exp timeseries
    daqCh.LED       = 1;
    daqCh.PTB       = 2;

    % For easy parsing, specify inter stim interval
    interStimInt = 0.25;
    fprintf('Finding stimulus onsets in daq data\n');
    stimOnsets = getPtbStimOnsetsFromDaq(exp.Data(daqCh.PTB,:),exp.daqRate,interStimInt);

    % Generate structure with stimulus types and timing (other variables are for debug)
    stimsPerBlock = numel(stim.stimLocOrder);
    [stimCell,stimInds,blockInds] = makeStimTypeStruct(stimOnsets,stimOrder,stim.nRepeats,stimsPerBlock);

    stimTsInfo.allStructure = {'Block','Stim','Rep'};
    stimTsInfo.all = stimCell;
    stimTsInfo.onsets = stimOnsets;
    stimTsInfo.inds = stimInds;
    stimTsInfo.blocks = blockInds;

    % Save stimulus timing info
    stimulusIndsInfoFile = fullfile(procDir,['stimTsInfo.mat']);
    save(stimulusIndsInfoFile,'stimTsInfo','-v7.3');
else
    fprintf('Skipping nidaq processing\n')
end
