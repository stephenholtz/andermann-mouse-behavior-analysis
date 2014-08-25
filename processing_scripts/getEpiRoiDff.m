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

makeNewRois = 0;
calcNewDff  = 1;
nRois       = 2;

% Get the base location for data, see function for details
if ispc
    dataDir = getExpDataSource('atlas-pc');
elseif ismac
    dataDir = getExpDataSource('macbook');
end

% Experiment directory
expDir  = fullfile(dataDir,animalName,expDateNum);
% Processed data filepath
procDir = fullfile(expDir,'proc');
% raw data
rawDir = fullfile(expDir,'raw');
% figure saving
figDir = fullfile(expDir,'figs');
% Epi imaging tiff path
epiTiffPath = dir([procDir filesep 'epi_*.tiff']);
epiTiffPath = fullfile(procDir,epiTiffPath(1).name);
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,['nidaq_*.mat']));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);

% Load data from experiment 'exp' struct
if ~exist('exp','var')
    load(nidaqFilePath);
end

% Load processed variables
load(fullfile(procDir,'faceMotion.mat'));
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

%% Image info / ROIs
% Get image info command will be slow due to large file size
if ~exist('epiImInfo','var')
    epiImInfo = imfinfo(epiTiffPath);
end

% Load sample frame to set ROI(s)
epiSampImage= double(imread(epiTiffPath,1));

% Load in rois or make new ones
if makeNewRois || ~exist(fullfile(procDir,'epiROIs.mat'),'file')
    clear roi 
    for iRoi = 1:nRois
        clf;
        imagesc(epiSampImage);
        switch iRoi
            case 1
                roi(iRoi).label = 'full region';
            case 2
                roi(iRoi).label = 'extravisual corticies';
        end
        disp(['Select ',roi(iRoi).label '...']);
        [   roi(iRoi).x,...
            roi(iRoi).y,...
            roi(iRoi).bw,...
            roi(iRoi).ix,...
            roi(iRoi).iy    ] = roipoly(epiSampImage);
        croppedRoi = epiSampImage.*roi(iRoi).bw;
        imagesc(croppedRoi)
        pause(.5)
    end
    % Save ROIs
    fprintf('Saving epiROIs.mat\n')
    save(fullfile(procDir,'epiROIs.mat'),'roi','-v7.3');
else
    load(fullfile(procDir,'epiROIs.mat'))
end

% Pull in the entire tiff stack if needed
if ~exist('epi','var') && (calcNewDff || makeNewRois)
    epi = tiffRead(epiTiffPath,'double');
end

%% Determine frames for analysis and calculate DFFs

% Plot frames in an roi
%iFrame = 1;
%for iFrame = 1:20
%    imshow(epi(:,:,iFrame).*(roi(1).bw|roi(2).bw),[]);
%    pause(.1)
%end

% LED presence in frames does not completely agree with daq trace
% this slop gets rid of bad frames (almost every time?)
bufferDaqSamps = ceil(0.425*exp.daqRate);

% For each led stimulus get the precise on and offset for finding
% proper f0 and f frames of epi image

durPrevSecs = 1;
durPostSecs = 1;

% In some experiments frame rate wasn't calculated
if ~isfield(exp,'epiRate')
    exp.epiFrameRate = 20;
end
dffFramesPrev = durPrevSecs*exp.epiFrameRate;
dffFramesPost = durPostSecs*exp.epiFrameRate;

framesPrior = [];
framesPost = [];

minPre = inf;
minPost = inf;
minFull = inf;
nF0Frames = ceil(dffFramesPrev/4);

% make yet another cell array with DFF values
if calcNewDff || ~exist(fullfile(procDir,'epiDff.mat'),'file')
    clear dff
    for iRoi = 1:numel(roi)
        for iBlock = 1:size(stimTsInfo.led,1)
            for iStim = [4 5 6];
                for iRep = 1:3
                    ledTiming = stimTsInfo.led{iBlock,iStim,iRep};
                    stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};

                    frameStimOn = frameNums.epi(stimOnsetInd);

                    preLedDaqInd = ledTiming(1) - bufferDaqSamps;
                    postLedDaqInd = ledTiming(2) + bufferDaqSamps;
                                
                    frameLedOn = frameNums.epi(preLedDaqInd);
                    frameLedOff = frameNums.epi(postLedDaqInd);

                    preLedFrames = frameLedOn-dffFramesPrev:frameLedOn;
                    postLedFrames = frameLedOff:frameLedOff+dffFramesPost;

                    % Get the DFF on these frames
                    clear f f0
                    for i = 1:numel(preLedFrames)
                        currEpi = epi(:,:,preLedFrames(i));
                        f0(i) = median(currEpi(roi(iRoi).bw));
                        f(i) = median(currEpi(roi(iRoi).bw));
                    end
                    f0 = f0(end-nF0Frames:end);
                    currDff = (f./median(f0(:)) - 1);
                    dff(iRoi).pre{iBlock,iStim,iRep} = currDff;

                    clear f
                    for i = 1:numel(postLedFrames)
                        currEpi = epi(:,:,postLedFrames(i));
                        f(i) = median(currEpi(roi(iRoi).bw));
                    end
                    currDff = f./median(f0(:)) - 1;
                    dff(iRoi).post{iBlock,iStim,iRep} = currDff;
                    
                    clear f
                    allFrames = preLedFrames(1):postLedFrames(end);
                    for i = 1:numel(allFrames)
                        currEpi = epi(:,:,allFrames(i));
                        f(i) = median(currEpi(roi(iRoi).bw));
                    end
                    currDff = f./median(f0(:)) - 1;
                    dff(iRoi).full{iBlock,iStim,iRep} = currDff;

                    dff(iRoi).preFrames{iBlock,iStim,iRep} = preLedFrames;
                    dff(iRoi).postFrames{iBlock,iStim,iRep} = postLedFrames;
                    dff(iRoi).allFrames{iBlock,iStim,iRep} = allFrames;
                     
                    % make a matrix on which to calculate average frame diff from stim onset
                    framesPrior = [framesPrior (frameLedOn - frameStimOn)];
                    framesPost = [framesPost (frameLedOff - frameStimOn)];
                end
            end
        end

        dff(iRoi).framesPrior = framesPrior;
        dff(iRoi).framesPost = framesPost;

        testing = 0;
        if testing
            figure;
            subplot(2,1,1)
            plot(framesPrior)
            subplot(2,1,2)
            plot(framesPost)
        end

        % Means are good enough for comparison b/n led and non led stims
        meanFramesPrior = ceil(mean(framesPrior));
        meanFramesPost = ceil(mean(framesPost));

        % Fill in the rest with average offsets
        for iBlock = 1:size(stimTsInfo.led,1)
            for iStim = [1 2 3]
                for iRep = 1:3
                    stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};
                    frameStimOn = frameNums.epi(stimOnsetInd);

                    preLedFrames = (frameStimOn - meanFramesPrior - dffFramesPrev):(frameStimOn - meanFramesPrior);
                    postLedFrames = (frameStimOn + meanFramesPost):(frameStimOn + meanFramesPost + dffFramesPost);
                    
                    % Get the DFF on these frames
                    clear f f0
                    for i = 1:numel(preLedFrames)
                        currEpi = epi(:,:,preLedFrames(i));
                        f0(i) = median(currEpi(roi(iRoi).bw));
                        f(i) = median(currEpi(roi(iRoi).bw));
                    end
                    f0 = f0(end-nF0Frames:end);
                    currDff = (f./median(f0(:)) - 1);
                    dff(iRoi).pre{iBlock,iStim,iRep} = currDff;

                    clear f
                    for i = 1:numel(postLedFrames)
                        currEpi = epi(:,:,postLedFrames(i));
                        f(i) = median(currEpi(roi(iRoi).bw));
                    end
                    currDff = f./median(f0(:)) - 1;
                    dff(iRoi).post{iBlock,iStim,iRep} = currDff;
                    
                    clear f
                    allFrames = preLedFrames(1):postLedFrames(end);
                    for i = 1:numel(allFrames)
                        currEpi = epi(:,:,allFrames(i));
                        f(i) = median(currEpi(roi(iRoi).bw));
                    end
                    currDff = f./median(f0(:)) - 1;
                    dff(iRoi).full{iBlock,iStim,iRep} = currDff;

                    dff(iRoi).preFrames{iBlock,iStim,iRep} = preLedFrames;
                    dff(iRoi).postFrames{iBlock,iStim,iRep} = postLedFrames;
                    dff(iRoi).allFrames{iBlock,iStim,iRep} = allFrames;
                end
            end
        end
    end

    % Copy over the roi in case of emergency?
    for iRoi = 1:numel(roi)
        dff(iRoi).roi = roi(iRoi);
    end

    % Save the dffs so I don't need to load in the epi file every time
    fprintf('Saving epi dff in: %s\n',fullfile(procDir,'epiDff.mat'));
    save(fullfile(procDir,'epiDff.mat'),'dff');
elseif ~exist('dff','var')
    fprintf('Loading epi dff: %s\n',fullfile(procDir,'epiDff.mat'));
    load(fullfile(procDir,'epiDff.mat'))
end
