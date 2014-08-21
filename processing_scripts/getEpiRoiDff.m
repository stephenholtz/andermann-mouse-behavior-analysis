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

%% Determine frames for analysis

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

% Plot frames in an roi
%iFrame = 1;
%for iFrame = 1:20
%    imshow(epi(:,:,iFrame).*(roi(1).bw|roi(2).bw),[]);
%    pause(.1)
%end

for iBlock = 1:size(stimTsInfo.all,1)
end

i = 1;
% Determine the LED timing information first, then do the rest (start w/stimSet 6)
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


