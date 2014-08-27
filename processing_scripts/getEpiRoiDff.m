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
nRois       = 3;

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
nidaqFileName = dir(fullfile(rawDir,'nidaq_*.mat'));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);

% Load data from experiment 'exp' struct
if ~exist('exp','var')
    load(nidaqFilePath);
end

% Load processed variables
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

%% Do / save epi analysis (ROI and DFF)
processEpiData = 1;
if processEpiData

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
                case 3
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
    if ~exist('epi','var') && (calcNewDff || makeNewRois)
        epi = tiffRead(epiTiffPath,'double');
    end

%% Determine frames for analysis and calculate DFFs
    % Empirically determined # of frames to throw out pre and post LED 
    % rising edge and falling edge @20Hz, easiest method
    nPreLedToss  = 2+1;
    nPostLedToss = 3+1;

    % For analysis use this amount before and after
    epiRate       = exp.daqRate*(1/median(frameNums.epiIfi));
    durPrevSecs   = .5;
    durPostSecs   = .5;
    dffFramesPrev = ceil(durPrevSecs*epiRate);
    dffFramesPost = ceil(durPostSecs*epiRate);

    [nBlocks,nStims,nReps] = size(stimTsInfo.all);

    % Calculate DFF, assume the second ROI is the background one
    foreMask = roi(1).bw;
    bckMask  = roi(2).bw;
    testMask = roi(3).bw;

    % Save a little space and make troubleshooting easier with anon func
    range2inds = @(v)(v(1):v(2));
    ledCh = 1;

    % Place dff and frames used to calculate it in a struct 
    % for easy plotting later
    fprintf('Calculating DeltaF/F...\n')
    if calcNewDff || ~exist(fullfile(procDir,'epiSig.mat'),'file')
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
                    epiSig(iB,iS,iR).f0Frames = [analStart (ledStart-1)];

                    % Save all this for exhaustive troubleshooting
                    epiSig(iB,iS,iR).ledFrames   = [ledStart ledEnd];
                    epiSig(iB,iS,iR).nLedFrames  = ledEnd-ledStart+1;
                    epiSig(iB,iS,iR).analFrames  = [analStart analEnd];
                    epiSig(iB,iS,iR).nAnalFrames = analEnd-analStart+1;
                    epiSig(iB,iS,iR).daqLedInds  = [daqLedStart daqLedEnd];
                    epiSig(iB,iS,iR).daqAnalInds = [daqAnalStart daqAnalEnd];

                    % The ind of the frame that everything should be aligned to is the end of the LED 
                    epiSig(iB,iS,iR).alignmentInd = find(ledEnd==range2inds(epiSig(iB,iS,iR).analFrames));

                    % Calculate the f0
                    iFrame = 1;
                    for frame = range2inds(epiSig(iB,iS,iR).f0Frames)
                        currEpiFrame = epi(:,:,frame);
                        f0(iFrame) = mean(currEpiFrame(foreMask));

                        iFrame = iFrame + 1;
                    end

                    f0 = mean(f0);
                    epiSig(iB,iS,iR).f0 = f0;

                    % Calculate the dff
                    iFrame = 1;
                    for frame = range2inds(epiSig(iB,iS,iR).analFrames)
                        currEpiFrame = epi(:,:,frame);

                        % Calculate individual signals for testing
                        f     = mean(currEpiFrame(foreMask));
                        fBck  = mean(currEpiFrame(bckMask));
                        fTest = mean(currEpiFrame(testMask));

                        fSub  = f-fBck;
                        f0Sub = f0-fBck;

                        epiSig(iB,iS,iR).f0(iFrame)    = f0;
                        epiSig(iB,iS,iR).f(iFrame)     = f;
                        epiSig(iB,iS,iR).fBck(iFrame)  = fBck;
                        epiSig(iB,iS,iR).fTest(iFrame) = fTest;
                        epiSig(iB,iS,iR).fSub(iFrame)  = fSub;

                        DffNoSub = (f./mean(f0(:)) - 1);
                        Dff      = (fSub./mean(f0Sub(:)) - 1);

                        % Now get the dff
                        epiSig(iB,iS,iR).dffNoSub(iFrame) = DffNoSub;
                        epiSig(iB,iS,iR).dff(iFrame)      = Dff;

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
        fprintf('Saving epi dff in: %s\n',fullfile(procDir,'epiSig.mat'));
        save(fullfile(procDir,'epiSig.mat'),'epiSig');

    elseif ~exist('dff','var')
        % Load in if reqd
        fprintf('Loading epi dff: %s\n',fullfile(procDir,'epiSig.mat'));
        load(fullfile(procDir,'epiSig.mat'))
    end
end


