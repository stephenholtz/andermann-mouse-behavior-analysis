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
animalName = 'K51';
expDateNum = '20140902_01';

% do ROI analysis (makeNewRois and makeRoiDffTraces require this)
processEpiRois = 1;
% make new ROIs
makeNewRois = 0;
% calculate new dff traces
makeRoiDffTraces = 1;

% number ROIs, 3 = background/foreground/test
nRois = 3; 

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
epiStackDir = fullfile(procDir,'epiStacks');
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,'nidaq_*.mat'));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);

% Load data from experiment 'daq' struct
if ~exist('daq','var')
    load(nidaqFilePath);
end

% Load processed variables
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

%% Common DFF / ROI variables
% Empirically determined # of frames to throw out pre and post LED 
% rising edge and falling edge
% @20Hz: nPreLedToss = 3; nPostLedToss = 4;
% @16Hz: nPreLedToss = 2; nPostLedToss = 3;
nPreLedToss  = 2; 
nPostLedToss = 3;

% For analysis / plots use this amount before and after LED on/off
durPrevSecs   = .5;
durPostSecs   = 1;
dffFramesPrev = ceil(durPrevSecs*frameNums.epiRate);
dffFramesPost = ceil(durPostSecs*frameNums.epiRate);
[nBlocks,nStims,nReps] = size(stimTsInfo.all);

% Save a little space and make troubleshooting easier with this anon func
range2vec = @(v)(v(1):v(2));
sum2 = @(M)(sum(0+M(:)));

% Server doesn't have flip (older ver is flipdim)
if ~exist('flip','builtin')
    flip = @(X,D)(flipdim(X,D));
end

%% Do / save epi analysis (ROI and DFF)
% Load in the full stack if it isn't already in memory
if ~exist('epi','var')
    fprintf('Loading all epi stacks...\n');
    % My version of read tiff folder, doesn't total progress indicator...
    epi = readTiffStackFolder(epiStackDir,inf,'double');
end

if processEpiRois
%% Image info / ROIs
    % Get image info command will be slow due to large file size
    % Load in rois or make new ones
    if makeNewRois || ~exist(fullfile(procDir,'epiROIs.mat'),'file')
        % Load sample frame to set ROI(s)
        if ~exist('epiStackMean','var')
            % This kinda works
            load(fullfile(procDir,'epiStackMean.mat'));
        end
        clear roi
        close all force
        
        for iRoi = 1:nRois
            switch iRoi
                case 1
                    % The primary region of interest, makes up F signal
                    % "foreMask" -- should take dff std to find the flashy area
                    roi(iRoi).label = 'full region';
                    imgForRoi = mat2gray(std(epiStackMean(1).dff,[],3));
                case 2
                    % Mask of background fluorescence levels
                    % "bckMask" -- should take mean of raw to find brighter bck
                    roi(iRoi).label = 'extravisual corticies';
                    imgForRoi = mat2gray(sum(readTiffStackFolder(epiStackDir,1:10,'double'),3));
                case 3
                    % Mask of a non gcamp region to test for LED artifacts
                    % "testMask" -- just look at raw signal mean
                    roi(iRoi).label = 'non-gcamp region';
                    imgForRoi = mat2gray(sum(readTiffStackFolder(epiStackDir,1:10,'double'),3));
            end
            disp(['Select ',roi(iRoi).label '...']);
            [   roi(iRoi).x,...
                roi(iRoi).y,...
                roi(iRoi).bw,...
                roi(iRoi).ix,...
                roi(iRoi).iy    ] = roipoly(imgForRoi);
            croppedRoi = imgForRoi.*roi(iRoi).bw;
            pause(.5)
        end
        % Save ROIs
        fprintf('Saving epiROIs.mat\n')
        save(fullfile(procDir,'epiROIs.mat'),'roi','-v7.3');
    else
        load(fullfile(procDir,'epiROIs.mat'))
    end

%% Determine frames for analysis and calculate DFFs

    % Calculate DFF, assume the second ROI is the background one
    foreMask = roi(1).bw;
    bckMask  = roi(2).bw;
    testMask = roi(3).bw;

    % Place dff and frames used to calculate it in a struct 
    % for easy plotting later
    fprintf('Calculating DeltaF/F...\n')
    if makeRoiDffTraces || ~exist(fullfile(procDir,'epiTrace.mat'),'file')
        fprintf('Block: ');
        for iB = 1:nBlocks
            fprintf('%2.f ',iB);
            for iS = 1:nStims
                for iR = 1:nReps
                    % place safe bounds around when the LED stim is likely
                    % contaminating the image
                    ledDaqInds = stimTsInfo.all(iB,iS,iR).led;
                    ledStart   = frameNums.epi(ledDaqInds(1)) - nPreLedToss;
                    ledEnd     = frameNums.epi(ledDaqInds(2)) + nPostLedToss;

                    ptbDaqInds = stimTsInfo.all(iB,iS,iR).ptb;
                    ptbStart   = frameNums.epi(ptbDaqInds(1));
                    ptbEnd     = frameNums.epi(ptbDaqInds(2));

                    % establish analysis area around led
                    analStart = ledStart - dffFramesPrev;
                    analEnd   = ledEnd + dffFramesPost;

                    % Which frames will be used for calculating f0 and f
                    f0FrameNums = analStart:(ledStart-1);
                    fFrameNums = analStart:analEnd;

                     % Get f0 with background subtracted out
                    f0 = zeros(numel(f0FrameNums),1);
                    iFrame = 1;

                    for f = f0FrameNums
                        currFrame = epi(:,:,f);
                        f0(iFrame) = mean(currFrame(foreMask));
                        iFrame = iFrame + 1;
                    end
                    f0 = median(f0);
                    
                    % Get the background and foreground signal (separately for troubleshooting)
                    fSig = zeros(numel(fFrameNums),1);
                    fBck = zeros(numel(fFrameNums),1);
                    iFrame = 1;

                    for f = fFrameNums
                        currFrame = epi(:,:,f);
                        fBck(iFrame) = median(currFrame(bckMask));
                        fSig(iFrame) = median(currFrame(foreMask));
                        iFrame = iFrame + 1;
                    end
                    
                    % store dff and f0 in a HUGE struct
                    dff = zeros(numel(fFrameNums),1);
                    bckdff = zeros(numel(fFrameNums),1);
                    for iF = 1:numel(fSig)  
                        dff(iF) = (fSig(iF)-f0)/f0;
                        bckdff(iF) = (fBck(iF)-f0)/f0;
                    end

                    % add in baseline shift, subtract out background
                    % TODO: clean this up after testing
                    dff = dff - median(dff(1:numel(f0FrameNums)));
                    bckdff = bckdff - median(bckdff(1:numel(f0FrameNums)));
                    dff = dff-bckdff;
                    dff = dff - median(dff(1:numel(f0FrameNums)));

                    epiTrace(iB,iS,iR).dff  = dff;
                    epiTrace(iB,iS,iR).f0   = f0;
                    epiTrace(iB,iS,iR).fSig = fSig;
                    epiTrace(iB,iS,iR).fBck = fBck;

                    % For easy plotting
                    epiTrace(iB,iS,iR).ptbOnOff = [(ptbStart - analStart) (ptbEnd - analStart)];
                    epiTrace(iB,iS,iR).ledOnOff = [(ledStart - analStart) (ledEnd - analStart)];

                    % Save all this other stuff for exhaustive troubleshooting
                    epiTrace(iB,iS,iR).f0Frames    = f0FrameNums;
                    epiTrace(iB,iS,iR).fFrames     = fFrameNums;

                    daqLedStart  = find(frameNums.epi == ledStart,1,'first');
                    daqLedEnd    = find(frameNums.epi == ledEnd,1,'last');
                    daqAnalStart = find(frameNums.epi == analStart,1,'first');
                    daqAnalEnd   = find(frameNums.epi == analEnd,1,'last');

                    epiTrace(iB,iS,iR).ledFrames   = [ledStart ledEnd];
                    epiTrace(iB,iS,iR).nLedFrames  = ledEnd-ledStart+1;
                    epiTrace(iB,iS,iR).analFrames  = [analStart analEnd];
                    epiTrace(iB,iS,iR).nAnalFrames = analEnd-analStart+1;
                    epiTrace(iB,iS,iR).daqLedInds  = [daqLedStart daqLedEnd];
                    epiTrace(iB,iS,iR).daqAnalInds = [daqAnalStart daqAnalEnd];
                end
            end
        end
    end

    % Clean up while this is still a script
    clear daqAnal* daqLed* anal* frame iB iS iR f f0 f0Sub fBck fSub DffNoSub Dff ledDaqInds
    clear currEpiFrame foreMask bckMask
    fprintf(' Done\n')

    % Save the dffs so I don't need to load in the epi file every time
    fprintf('Saving epi dff traces in: %s\n',fullfile(procDir,'epiTrace.mat'));
    save(fullfile(procDir,'epiTrace.mat'),'epiTrace','-v7.3');

elseif ~exist('dff','var')
    % Load in if reqd
    fprintf('Loading epi dff: %s\n',fullfile(procDir,'epiTrace.mat'));
    load(fullfile(procDir,'epiTrace.mat'))
end
