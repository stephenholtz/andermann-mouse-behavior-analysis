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
calcNewDff = 0;
nRois = 3;
saveFigs = 1;

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
if ~exist('epi','var') && (calcNewDff || makeNewRois)
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
bufferDaqSamps = floor(exp.daqRate/5);

% For each led stimulus get the precise on and offset for finding
% proper f0 and f frames of epi image

durPrevSecs = 1;
durPostSecs = 1;

epiFrameRate = 20;
dffFramesPrev = durPrevSecs*epiFrameRate;
dffFramesPost = durPostSecs*epiFrameRate;

framesPrior = [];
framesPost = [];

minPre = inf;
minPost = inf;
minFull = inf;
nF0Frames = ceil(dffFramesPrev/4);

% make yet another cell array with DFF values
if calcNewDff || ~exist(fullfile(procDir,'epiDff.mat'),'file')
    clear dff
    for iRoi = 1:nRois
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
    for iRoi = 1:nRois
        dff(iRoi).roi = roi(iRoi);
    end

    % Save the dffs so I don't need to load in the epi file every time
    fprintf('Saving epi dff in: %s\n',fullfile(procDir,'epiDff.mat'));
    save(fullfile(procDir,'epiDff.mat'),'dff');
elseif ~exist('dff','var')
    fprintf('Loading epi dff: %s\n',fullfile(procDir,'epiDff.mat'));
    load(fullfile(procDir,'epiDff.mat'))
end

%---------------------------------------------------
%% Group the DFFs for averaging within stimulus types
iRoi = 1;
i = 1;
for stimSet = 1:6 
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

                % Dff values sets to average etc.,
                preSub = mean(dff(iRoi).pre{iBlock,iStim,iRep}(end-2:end));
                preDff.('baselineSub').(setName)(rowIter,:) = dff(iRoi).pre{iBlock,iStim,iRep} - preSub;
                preDff.('normal').(setName)(rowIter,:) = dff(iRoi).pre{iBlock,iStim,iRep};
                postDff.('baselineSub').(setName)(rowIter,:) = dff(iRoi).post{iBlock,iStim,iRep} - preSub;
                postDff.('normal').(setName)(rowIter,:) = dff(iRoi).post{iBlock,iStim,iRep};

                % TODO: Make this less destructive
                try
                    fullDff.('baselineSub').(setName)(rowIter,:) = dff(iRoi).full{iBlock,iStim,iRep} - preSub;
                    fullDff.('normal').(setName)(rowIter,:) = dff(iRoi).full{iBlock,iStim,iRep};
                catch
                    fullDff.('baselineSub').(setName)(rowIter,:) = NaN;
                    fullDff.('normal').(setName)(rowIter,:) = NaN;
                end

                rowIter = rowIter + 1;
            end
        end
    end
end

%----------------------------------------------------------------------
%% Plot the combined stimulus responses

% Baselinesubtracted or raw traces
%procType = 'raw';
procType = 'baselineSub';

% To plot in seconds
indsPre = size(preDff.(procType).all,2);
indsPost = size(postDff.(procType).all,2);
indsFull = size(fullDff.(procType).all,2);

xPre = (1:indsPre)*(1/epiFrameRate);
xGap = xPre(end) + mode(diff(xPre));
xPost = xGap + (1:indsPost)*(1/epiFrameRate);
xFull = (1:indsFull)*(1/epiFrameRate);

xTsVector = [xPre xGap xPost];

gapVal = 0;

plotLumped = 1;
if plotLumped
    % These should be the same for all plots

    yLabel = '\DeltaF/F0';
    xLabel = 'Time (s)';

    for stimSet = 1:6
        switch stimSet
            case 1
                setName = 'all';
                titleStr = ({'DFF across all stimuli', '(blank conditions included'});
            case 2
                setName = 'allVis';     
                titleStr = ({'DFF across all visual stimuli', '(no blank conditions)'});
            case 3
                setName = 'blank';        
                titleStr = ({'DFF across all blank stimuli', ''});
            case 4
                setName = 'ledOnly';
                titleStr =({'DFF to LED Only',''});
            case 5
                setName = 'ledOffVis';        
                titleStr =({'DFF to visual stimuli LED Off',''});
            case 6
                setName = 'ledOnVis';
                titleStr =({'DFF to visual stimuli LED On',''});
        end

        figure();
        dPre = preDff.(procType).(setName);
        dGap = gapVal*ones(size(dPre,1),1); 
        dPost = postDff.(procType).(setName);
        dVector = [dPre, dGap, dPost];
        plot(xTsVector,dVector);
        hold all
        plot([xGap xGap],ylim,'lineWidth',3,'Color','G')
        plot(xTsVector,mean(dVector),'LineWidth',3,'Color','k');
        ylabel(yLabel)
        xlabel(xLabel)
        title(titleStr)
        if saveFigs
            figSaveName = fullfile(figDir,['epiDff_' setName '_' animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-eps',gcf)
        end 
    end
end

%% Plot comparisons of averaged motion responses
plotLumpedComparisons = 1;
if plotLumpedComparisons
    % These should be the same for all plots
    offsetSeconds = 2;
    yLabel = '\DeltaF/F0';
    xLabel = 'Time (s)';

    for comparisonType = 1:3
        switch comparisonType
            case 1
                setName1 = 'allVis';
                setName2 = 'blank';
                titleStr = {'\DeltaF/F0 All visual vs blank stimuli'};
                setLegName1 = 'All Visual Stimuli';
                setLegName2 = 'Blank Stimuli';
            case 2
                setName1 = 'ledOnly';
                setName2 = 'blank';
                titleStr = {'\DeltaF/F0 LED vs blank stimuli'};
                setLegName1 = 'LED Only';
                setLegName2 = 'Blank Stimuli';
            case 3
                setName1 = 'ledOffVis';
                setName2 = 'ledOnVis';
                titleStr = {'\DeltaF/F0 with LED off vs LED on'};
                setLegName1 = 'LED Off Vis Stim';
                setLegName2 = 'LED On Vis Stim';
        end

        figure();
        dPre = preDff.(procType).(setName1);
        dGap = gapVal*ones(size(dPre,1),1); 
        dPost = postDff.(procType).(setName1);
        dVector = [dPre, dGap, dPost];
        plot(xTsVector,mean(dVector));
        hold all
        dPre = preDff.(procType).(setName2);
        dGap = gapVal*ones(size(dPre,1),1); 
        dPost = postDff.(procType).(setName2);
        dVector = [dPre, dGap, dPost];
        plot(xTsVector,mean(dVector));
 
        % Terrible hack to get correct ylim
        plot([xGap xGap],ylim,'lineWidth',3,'Color','G')
        plot([xGap xGap],ylim,'lineWidth',3,'Color','G')
        ylabel(yLabel)
        xlabel(xLabel)
        title(titleStr)
        lH = legend(setLegName1,setLegName2,'stimulus on/off');

        if saveFigs
            figSaveName = fullfile(figDir,['epiDff_' setName1 '_vs_' setName2 '_' animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-eps',gcf)
        end
    end
end

