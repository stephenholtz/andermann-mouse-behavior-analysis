%% saveDffStacks.m
% Make a stack of the dff responses for each stimulus
% 
% ROIs made in getEpiRoiDff
%
% SLH

%% Specify animal/experiment/data location
animalName = 'K51';
expDateNum = '20140902_01';

% makes a set of stacks with dffs for troubleshooting
makeNewEpiDffStacks = 0;
writeNewDffTiffs    = 1;

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

% Load processed variables
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

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

% Look at imhist of max dff, everything above .1 is junk
maxDffSignal = .1;

% Save a little space and make troubleshooting easier with this anon func
range2vec = @(v)(v(1):v(2));
sum2 = @(M)(sum(0+M(:)));
shiftBaseline = @(M)(M+abs(min(M(:))));

% Server doesn't have flip
if ~exist('flip','builtin')
    flip = @(X,D)(flipdim(X,D));
end

% Load processed variables
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

%% Process data as dffs and save (or load) mat files
if makeNewEpiDffStacks

    % Load in the full stack if it isn't already in memory
    if ~exist('epi','var')
        fprintf('Loading all epi stacks...\n');
        % My version of read tiff folder, doesn't total progress indicator...
        epi = readTiffStackFolder(epiStackDir,inf,'double');
    end

    clear epiStack epiStackMean
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

                ptbDaqInds = stimTsInfo.all(iB,iS,iR).ptb;
                ptbStart   = frameNums.epi(ptbDaqInds(1));
                ptbEnd     = frameNums.epi(ptbDaqInds(2));

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

                epiStack(iB,iS,iR).dff = (dff);
                epiStack(iB,iS,iR).f0 = f0Frame;

                % Store these values for presentation purposes
                epiStack(iB,iS,iR).ptbOnOff = [(ptbStart - analStart) (ptbEnd - analStart)];
                epiStack(iB,iS,iR).ledOnOff = [(ledStart - analStart) (ledEnd - analStart)];
            end
            imshow(imadjust(max(epiStack(iB,iS,1).dff,[],3),[0 maxDffSignal]))
            pause(.1)
        end
    end
    clear dff
    fprintf('\n')
    % Calculate means now and save as separate var for quick loading easiest way: one for each stimulus type (arb pick 2nd block of stimulus presentation)
    clear flipStimStack 
    fprintf('Making Mean Epi Dff stacks\nStim: ');
    for iS = 1:nStims
        ptbOnOff = [];
        ledOnOff = [];

        fprintf('%2.f ',iS);
        iTS = 1;
        for iB = 1:nBlocks
            for iR = 1:numel(epiStack(iB,iS,:))
                % All dff have the same number of frames AFTER the LED
                % align them so that they all end together, using flip (later unflip)
                % This temporary variable is a 4-d matrix with 1=rows,2=cols,3=timeseries,4=timeseries reps
                flippedStack = flip(epiStack(iB,iS,iR).dff,3);
                flipStimStack(:,:,1:size(flippedStack,3),iTS) = flippedStack;
                ptbOnOff = [ptbOnOff; epiStack(iB,iS,iR).ptbOnOff];
                ledOnOff = [ledOnOff; epiStack(iB,iS,iR).ledOnOff];
                iTS = iTS + 1;
            end
        end
        % Unflip the data align all by ending and then take the mean along the reps (4th dim)
        % take the average and store in epiStackMean struct
        epiStackMean(iS).dff = (mean(flip(flipStimStack,3),4));
        epiStackMean(iS).ptbOnOff = mean(ptbOnOff,1);
        epiStackMean(iS).ledOnOff = mean(ledOnOff,1);

        clear flipStimStack
    end
    fprintf('\n')

    fprintf('Saving mean epi dff stacks in: %s\n',fullfile(procDir,'epiStackMean.mat'));
    save(fullfile(procDir,'epiStackMean.mat'),'epiStackMean','-v7.3');

    % Save a sample of the dffs so I don't need to load in the epi file every time
    epiStack = epiStack(2,:,:);
    fprintf('Saving sample epi dff stacks in: %s\n',fullfile(procDir,'epiStack.mat'));
    save(fullfile(procDir,'epiStack.mat'),'epiStack','-v7.3');

elseif (~exist('epiStack','var') || ~exist('epiStackMean','var')) && (exist(fullfile(procDir,'epiStack.mat'),'file') && exist(fullfile(procDir,'epiStackMean.mat'),'file'))

    % Load in if they exist
    fprintf('Loading epiStack.mat and epiStackMean.mat\n')
    load(fullfile(procDir,'epiStack.mat'))
    load(fullfile(procDir,'epiStackMean.mat'))
end

%% Save the stacks as tiffs for viewing
if writeNewDffTiffs
    fprintf('Writing tiff stacks: ');
    option.BitsPerSample = 32;
    option.Float = true;
    option.Append = false;
    option.Compression = 'lzw';
    option.BigTiff = false;

    for i = 1:numel(epiStack)
        [iBlock,iStim,iRep] = ind2sub(size(epiStack),i);
        switch iStim
            case 1
                stimNameStr = 'MedialLedOff';
            case 2
                stimNameStr = 'NoVisLedOff';
            case 3
                stimNameStr = 'MedialLedOn';
            case 4
                stimNameStr = 'NoVisLedOn';
        end

        fprintf('raw %d ',i);

        fileName = ['rawDffStack_' stimNameStr '_rep_' num2str(i) '_STIM_ON_OFF_' num2str(epiStack(i).ptbOnOff(1)) '_' num2str(epiStack(i).ptbOnOff(2)) '.tiff'];
        tiffWrite((mat2gray(epiStack(i).dff)),fileName,figDir,option)

        fileName = ['f0_' stimNameStr '_rep_' num2str(i) '_STIM_ON_OFF_' num2str(epiStack(i).ptbOnOff(1)) '_' num2str(epiStack(i).ptbOnOff(2)) '.tiff'];
        tiffWrite((mat2gray(epiStack(i).f0)),fileName,figDir,option)

        fprintf('\n')
    end

    for i = 1:numel(epiStackMean)
        [iBlock,iStim,iRep] = ind2sub(size(epiStack),i);
        switch iStim
            case 1
                stimNameStr = 'MedialLedOff';
            case 2
                stimNameStr = 'NoVisLedOff';
            case 3
                stimNameStr = 'MedialLedOn';
            case 4
                stimNameStr = 'NoVisLedOn';
        end
        fprintf('mean %d ',i);

        fileName = ['meanDffStack_' stimNameStr '_rep_' num2str(i) '_STIM_ON_OFF_' num2str(epiStackMean(i).ptbOnOff(1)) '_' num2str(epiStackMean(i).ptbOnOff(2)) '.tiff'];
        tiffWrite((mat2gray(epiStackMean(i).dff)),fileName,figDir,option)

        fprintf('\n')
    end
end
