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
expDateNum = '20140830_02';

% makes a set of stacks with dffs for troubleshooting
makeEpiDffStacks = 1;

% do ROI analysis (makeNewRois and makeRoiDffTraces require this)
processEpiRois = 1;
% make new ROIs
makeNewRois = 1;
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
durPostSecs   = .5;
dffFramesPrev = ceil(durPrevSecs*frameNums.epiRate);
dffFramesPost = ceil(durPostSecs*frameNums.epiRate);
[nBlocks,nStims,nReps] = size(stimTsInfo.all);

% Save a little space and make troubleshooting easier with this anon func
range2vec = @(v)(v(1):v(2));
ledCh = 1;

%% Do / save epi analysis (ROI and DFF)

if ~exist('epi','var')
    % Funciton well tested, use with caution
    fprintf('Loading all epi stacks...\n');
    epi = readTiffStackFolder(epiStackDir,inf,'double');
end

%% Make a stack of the dff responses for each stimulus
% Largely for troubleshooting 
if makeEpiDffStacks
    fprintf('Making Epi Dff stacks\nBlock: ');
    for iB = 1:nBlocks
        fprintf('%2.f ',iB);
        for iS = 1:nStims
            for iR = 1:nReps
                % place safe bounds around when the LED stim is likely
                % contaminating the image
                ledDaqInds = stimTsInfo.all(iB,iS,iR).led;
                ledStart   = frameNums.epi(ledDaqInds(1)) - nPreLedToss;
                ledEnd     = frameNums.epi(ledDaqInds(2)) + nPostLedToss;

                % establish analysis area around led
                analStart = ledStart - dffFramesPrev;
                analEnd   = ledEnd + dffFramesPost;

                % Which frames will be used for calculating f0
                f0FrameNums = analStart:(ledStart-1);
                f0Frame = mean(epi(:,:,f0FrameNums),3);

                % store dff and f0 in a HUGE struct
                fFrameNums = analStart:analEnd;
                dff = zeros(size(epi,1),size(epi,2),numel(fFrameNums));
                iFrame = 1;
                for f = fFrameNums
                    dff(:,:,iFrame) = (epi(:,:,f)./f0Frame)-1;
                    iFrame = iFrame + 1; 
                end
                epiStack(iB,iS,iR).dff = dff;
                epiStack(iB,iS,iR).f0 = f0Frame;
            end
        end
    end
    clear dff
    fprintf('\n')
    % Save the dffs so I don't need to load in the epi file every time
    fprintf('Saving epi dff stacks in: %s\n',fullfile(procDir,'epiStack.mat'));
    save(fullfile(procDir,'epiStack.mat'),'epiStack','-v7.3');
    % Calculate means now and save as separate var for quick loading
    % easiest way: one for each stimulus type
    clear flipStimStack
    for iS = 1:nStims
        iTS = 1;
        for iB = 1:nBlocks
            for iR = 1:numel(epiStack(iB,iS,:))
                % All dff have the same number of frames AFTER the LED
                % align them so that they all end together, using flip (later unflip)
                % This temporary variable is a 4-d matrix with 1=rows,2=cols,3=timeseries,4=timeseries reps
                flippedStack = flip(epiStack(iB,iS,iR).dff,3);
                flipStimStack(:,:,1:size(flippedStack,3),iTS) = flippedStack;
                iTS = iTS + 1;
            end
        end
        % Unflip the data align all by ending and then take the mean along the reps (4th dim)
        % take the average and store in epiStackMean struct
        epiStackMean(iS).dff = squeeze(mean(flip(flipStimStack,3),4));
        clear flipStimStack
    end
    fprintf('Saving mean epi dff stacks in: %s\n',fullfile(procDir,'epiStackMean.mat'));
    save(fullfile(procDir,'epiStackMean.mat'),'epiStackMean','-v7.3');
end

if processEpiRois
%% Image info / ROIs
    % Get image info command will be slow due to large file size
    % Load sample frame to set ROI(s)
    useDffForRoi = 1;
    if useDffForRoi
        load(fullfile(procDir,'epiStackMean.mat'));
        epiSampImage = epiStackMean(2).dff;
    else
        epiSampImage = readTiffStackFolder(epiStackDir,9202,'double'); 
    end

    % Load in rois or make new ones
    if makeNewRois || ~exist(fullfile(procDir,'epiROIs.mat'),'file')
        clear roi 
        for iRoi = 1:nRois
            clf;
            imagesc(epiSampImage);
            switch iRoi
                case 1
                    % The primary region of interest, makes up F signal
                    % "foreMask"
                    roi(iRoi).label = 'full region';
                case 2
                    % Mask of background fluorescence levels
                    % "bckMask"
                    roi(iRoi).label = 'extravisual corticies';
                case 3
                    % Mask of a non gcamp region to test for LED artifacts
                    % "testMask" 
                    roi(iRoi).label = 'non-gcamp region';
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
    if ~exist('epi','var') && (makeRoiDffTraces || makeNewRois)
        epi = tiffRead(epiTiffPath,'double');
    end

%% Determine frames for analysis and calculate DFFs

    % Calculate DFF, assume the second ROI is the background one
    foreMask = roi(1).bw;
    bckMask  = roi(2).bw;
    testMask = roi(3).bw;

    % Place dff and frames used to calculate it in a struct 
    % for easy plotting later
    fprintf('Calculating DeltaF/F...\n')
    if calcNewDff || ~exist(fullfile(procDir,'epiTrace.mat'),'file')
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

                    % establish analysis area around led
                    analStart = ledStart - dffFramesPrev;
                    analEnd   = ledEnd + dffFramesPost;

                    % Determine daq inds of adjusted frames
                    daqLedStart  = find(frameNums.epi == ledStart,1,'first');
                    daqLedEnd    = find(frameNums.epi == ledEnd,1,'last');
                    daqAnalStart = find(frameNums.epi == analStart,1,'first');
                    daqAnalEnd   = find(frameNums.epi == analEnd,1,'last');

                    % Which frames will be used for calculating f0
                    epiTrace(iB,iS,iR).f0Frames = [analStart (ledStart-1)];

                    % Save all this for exhaustive troubleshooting
                    epiTrace(iB,iS,iR).ledFrames   = [ledStart ledEnd];
                    epiTrace(iB,iS,iR).nLedFrames  = ledEnd-ledStart+1;
                    epiTrace(iB,iS,iR).analFrames  = [analStart analEnd];
                    epiTrace(iB,iS,iR).nAnalFrames = analEnd-analStart+1;
                    epiTrace(iB,iS,iR).daqLedInds  = [daqLedStart daqLedEnd];
                    epiTrace(iB,iS,iR).daqAnalInds = [daqAnalStart daqAnalEnd];

                    % The ind of the frame that everything should be aligned to is the end of the LED 
                    epiTrace(iB,iS,iR).alignmentInd = find(ledEnd==range2vec(epiTrace(iB,iS,iR).analFrames));

                    % Calculate the f0
                    iFrame = 1;
                    for frame = range2vec(epiTrace(iB,iS,iR).f0Frames)
                        currEpiFrame = epi(:,:,frame);
                        f0(iFrame) = mean(currEpiFrame(foreMask));

                        iFrame = iFrame + 1;
                    end

                    f0 = mean(f0);
                    epiTrace(iB,iS,iR).f0 = f0;

                    % Calculate the dff
                    iFrame = 1;
                    for frame = range2vec(epiTrace(iB,iS,iR).analFrames)
                        currEpiFrame = epi(:,:,frame);

                        % Calculate individual signals for testing
                        f     = mean(currEpiFrame(foreMask));
                        fBck  = mean(currEpiFrame(bckMask));
                        fTest = mean(currEpiFrame(testMask));

                        fSub  = f-fBck;
                        f0Sub = f0-fBck;

                        epiTrace(iB,iS,iR).f0(iFrame)    = f0;
                        epiTrace(iB,iS,iR).f(iFrame)     = f;
                        epiTrace(iB,iS,iR).fBck(iFrame)  = fBck;
                        epiTrace(iB,iS,iR).fTest(iFrame) = fTest;
                        epiTrace(iB,iS,iR).fSub(iFrame)  = fSub;

                        DffNoSub = (f./mean(f0(:)) - 1);
                        Dff      = (fSub./mean(f0Sub(:)) - 1);

                        % Now get the dff
                        epiTrace(iB,iS,iR).dffNoSub(iFrame) = DffNoSub;
                        epiTrace(iB,iS,iR).dff(iFrame)      = Dff;

                        iFrame = iFrame + 1;
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
        save(fullfile(procDir,'epiTrace.mat'),'epiTrace');

    elseif ~exist('dff','var')
        % Load in if reqd
        fprintf('Loading epi dff: %s\n',fullfile(procDir,'epiTrace.mat'));
        load(fullfile(procDir,'epiTrace.mat'))
    end
end


