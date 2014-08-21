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
% Epi imaging tiff path
epiTiffPath = dir([procDir filesep 'epi_*.tiff']);
epiTiffPath = fullfile(procDir,epiTiffPath(1).name);
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,['nidaq_*.mat']));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);

% Load data from experiment 'exp' struct (for testing)
load(nidaqFilePath);

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
    nRois = 3;
    for iRoi = 1:nRois
        clf;
        imagesc(epiSampImage);
        switch iRoi
            case 1
                roi(iRoi).label = 'full region';
            case 2
                roi(iRoi).label = 'reflective';
            case 3
                roi(iRoi).label = 'small region';
        end
        [   roi(iRoi).x,...
            roi(iRoi).y,...
            roi(iRoi).bw,...
            roi(iRoi).ix,...
            roi(iRoi).iy    ] = roipoly(epiSampImage);
        croppedRoi = epiSampImage.*roi(iRoi).bw;
        imagesc(croppedRoi)
    end
    % Save ROIs
    save(fullfile(procDir,'epiROIs.mat'),'roi','-v7.3');
else
    load(fullfile(procDir,'epiROIs.mat'))
end

% Pull in the entire tiff stack if needed
if ~exist('epi','var');
    epi = tiffRead(epiTiffPath,epiImInfo(1).BitDepth);
end

%% Determine frames for analysis and calculate DFFs

% Plot frames in an roi
%iFrame = 1;
%for iFrame = 1:20
%    imshow(epi(:,:,iFrame).*(roi(1).bw|roi(2).bw),[]);
%    pause(.1)
%end

% LED in frames does not completely agree with daq trace
% this slop gets rid of bad frames (almost every time?)
bufferFrames = floor(exp.DaqRate/5);

% For each led stimulus get the precise on and offset for finding
% proper f0 and f frames of epi image

durPrevSecs = .5;
durPostSecs = .5;

epiFrameRate = 20;
framesPrev = durPrevSecs*epiFrameRate;
framesPost = durPostSecs*epiFrameRate;

framesPrior = [];
framesPost = [];

nF0Frames = ceil(framesPrev/4);

% make yet another cell array with DFF values
for iRoi = 1:nRois
    for iBlock = 1:size(stimTsInfo.led,1)
        for iStim = [4 5 6];
            for iRep = 1:3
                ledTiming = stimTsInfo.led{iBlock,iStim,iRep};
                stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};

                frameStimOn = frameNums.epi(stimOnsetInd);

                preLedDaqInd = ledTiming(1) - bufferFrames;
                postLedDaqInd = ledTiming(2) + bufferFrames;
                            
                frameLedOn = frameNums.epi(preLedDaqInd);
                frameLedOff = frameNums.epi(postLedDaqInd);

                preLedFrames = frameLedOn-framesPrev:frameLedOn;
                postLedFrames = frameLedOff:frameLedOff+framesPost;

                % Get the DFF on these frames
                clear f f0
                for i = 1:numel(preLedFrames)
                    currEpi = epi(:,:,i);
                    f0(i) = median(currEpi(roi(iRoi).bw));
                    f(i) = median(currEpi(roi(iRoi).bw));
                end
                f0 = f0(end-nF0Frames:end);

                currDff = mean(f./median(f0(:)) - 1);
                dff(iRoi).pre{iBlock,iStim,iRep} = currDff;

                clear f
                for i = 1:numel(postLedFrames)
                    currEpi = epi(:,:,i);
                    f(i) = median(currEpi(roi(iRoi).bw));
                end

                currDff = f./median(f0(:)) - 1;
                dff(iRoi).post{iBlock,iStim,iRep} = currDff;
                 
                % make a matrix on which to calculate average frame diff from stim onset
                framesPrior = [framesPrior (frameLedOn - frameStimOn)];
                framesPost = [framesPost (frameLedOff + frameStimOn)];
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
    meanFramesPrior = mean(framesPrior);
    meanFramesPost = mean(framesPost);

    % Fill in the rest with average offsets
    for iBlock = 1:size(stimTsInfo.led,1)
        for iStim = [1 2 3]
            for iRep = 1:3
                stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};
                frameStimOn = frameNums.epi(stimOnsetInd);

                preLedFrames = frameStimOn + meanFramesPrior;
                postLedFrames = frameStimOn + meanFramesPost;

                % Get the DFF on these frames
                clear f f0
                for i = 1:numel(preLedFrames)
                    currEpi = epi(:,:,i);
                    f0(i) = median(currEpi(roi(iRoi).bw));
                    f(i) = median(currEpi(roi(iRoi).bw));
                end
                f0 = f0(end-nF0Frames:end);

                currDff = mean(f./median(f0(:)) - 1);
                dff(iRoi).pre{iBlock,iStim,iRep} = currDff;

                clear f
                for i = 1:numel(postLedFrames)
                    currEpi = epi(:,:,i);
                    f(i) = median(currEpi(roi(iRoi).bw));
                end

                currDff = f./median(f0(:)) - 1;
                dff(iRoi).post{iBlock,iStim,iRep} = currDff;
                
            end
        end
    end
end

%% Plot the dffs for each stimulus

% Determine the LED timing information first, then do the rest (start w/stimSet 6)
i = 1;
for stimSet = [6 1:5] 
    switch stimSet
        case 1
            stimsToUse = 1:6;
            setName = 'all';
        case 2
            stimsToUse = [1 2 4 5];
            setName = 'allVis';     
        case 3
            stimsToUse = 3;
            setName = 'blank';        
        case 4
            stimsToUse = 6;
            setName = 'ledOnly';
        case 5
            stimsToUse = [1 2];
            setName = 'ledOffVis';        
        case 6
            stimsToUse = [4 5];
            setName = 'ledOnVis';
    end

    rowIter = 1;
    for iBlock = 1:size(stimTsInfo.all,1)
        for iStim = stimsToUse
            for iRep = 1:numel([stimTsInfo.all{iBlock,iStim,:}])

                stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};
                % All LED conditions
                if iStim == 6 || iStim == 4 || iStim == 5 
                    
                end

                % Get the daq timeseries ind where this stimulus started (minus prestimtime)
                startDaqInd = stimOnsetInd - preStimTimeSamps;
                % Get the frame number of that starting daq ind
                startFrameInd = frameNums.face(startDaqInd);
                % Determine ending daq point
                endDaqInd = stimOnsetInd + stimTimeSec*daqRate + postStimTimeSamps;
                endFrameInd = frameNums.face(endDaqInd);

                % Number of frames is somewhat unreliable, truncate all to same length
                framesToUse = startFrameInd:endFrameInd;
                framesToUse = framesToUse(1:nReliableFrames);
                motionTs.('raw').(setName)(rowIter,:) = faceMotion.(method)(framesToUse,4);

                preStimFrames = startFrameInd:startFrameInd+nReliablePreStimFrames;
                motionTs.('baselineSub').(setName)(rowIter,:) = faceMotion.(method)(framesToUse,4) - median(faceMotion.(method)(preStimFrames,4));

                rowIter = rowIter + 1;
            end
        end
    end
end


%% save raw epi ROI timeseries data (? depends on how slow)


%% Calculate the dff for each set -- and save?


