%% getEyeFaceMotion.m
% 
% from stackreg:
% Rigid registration algorithm (fft of 2d xcorr?) to figure out movement
% From stackRegister: (call will be verbose)
%      OUTS(:,1) is correlation coefficients
%      OUTS(:,2) is global phase difference between images 
%               (should be zero if images real and non-negative).
%      OUTS(:,3) is net row shift
%      OUTS(:,4) is net column shift
%
% SLH 2014

%% Specify animal/experiment/data location
animalName      = 'K71';
expDateNum      = '20140815_01';
nRois           = 6;
makeNewFaceRois = 0;

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

%------------------------------------------------------------------
%% FACE
%------------------------------------------------------------------
processFaceImages = 0;
if processFaceImages
    % Stacks of face tiff movies stored here (and file info in mat file)
    faceStackDir = fullfile(procDir,'faceStacks');
    load(fullfile(faceStackDir,'frameInfo.mat'));

    % Load in one file for drawing roi
    faceImage = imread(fullfile(faceStackDir,frameInfo(1).fileName),100);

    % Find a region of interest for the snout tracking
    % Seems like slecting part of the nose helps
    if makeNewFaceRois || ~exist(fullfile(procDir,'faceROIs.mat'),'file')
        for iRoi = 1:nRois
            clf;
            imagesc(faceImage);
            colormap(gray)
            switch iRoi
                case 1
                    roi(iRoi).label = 'betweenEyesSquare';
                case 2
                    roi(iRoi).label = 'betweenEyesDownSnout';
                case 3
                    roi(iRoi).label = 'largeSquareAboveNose';
                case 4
                    roi(iRoi).label = 'ballRight';
                case 5
                    roi(iRoi).label = 'wiskerBaseL';
                case 6
                    roi(iRoi).label = 'wiskerBaseR';

            end
            fprintf('Select ROI %s\n',roi(iRoi).label)
            RoiH = imrect(gca);
            roi(iRoi).Pos = round(getPosition(RoiH));
            roi(iRoi).Xinds = roi(iRoi).Pos(1):(roi(iRoi).Pos(1)+roi(iRoi).Pos(3)); 
            roi(iRoi).Yinds = roi(iRoi).Pos(2):(roi(iRoi).Pos(2)+roi(iRoi).Pos(4));

            pause(.5)
            croppedFace = faceImage(roi(iRoi).Yinds,roi(iRoi).Xinds);
        end
        save(fullfile(procDir,'faceROIs.mat'),'roi');
    else
        load(fullfile(procDir,'faceROIs.mat'));
    end

    % Make a substack with just this ROI
    fprintf('Loading in stacks for stackRegister\n') 
    totalFrames = 0;
    for i = 1:nRois
        faceMotionCell{i} = [];
    end
    % Load one stack, calculate stackreg for all rois then load next
    for iStack = 1:numel(frameInfo)
        clear currStack
        fprintf('Stack: %4.d /  %4.d\n',iStack,numel(frameInfo))
        currStack = tiffRead(fullfile(faceStackDir,frameInfo(iStack).fileName),1);
        for iRoi = 1:nRois
            fprintf('ROI: %2.d /  %2.d\n',iRoi,nRois)
            currFaceSubStack{iRoi} = currStack(roi(iRoi).Yinds,roi(iRoi).Xinds,:);
            
            % Register to the median frame stack
            if iStack == 1
                refFrame{iRoi} = median(currFaceSubStack{iRoi},3);
                roiFrame{iRoi} = currFaceSubStack{iRoi}(:,:,round(.5*size(currFaceSubStack{iRoi},3)));
            end
            faceMotionCell{iRoi} = [faceMotionCell{iRoi}; stackRegister(currFaceSubStack{iRoi},refFrame{iRoi})];
            totalFrames = size(currFaceSubStack{iRoi},3) + totalFrames;
        end
    end
    faceMotion.stackRegCell = faceMotionCell;
    faceMotion.refFrames    = refFrame;
    faceMotion.roiFrame     = roiFrame;
    faceMotion.totalFrames  = totalFrames;
    save(fullfile(procDir,'faceMotion.mat'),'faceMotion','-v7.3')
end

%------------------------------------------------------------------
%% EYE Do dialation analysis on eye
%------------------------------------------------------------------
eyeStackDir = fullfile(procDir,'eyeStacks');
% per stack frame information
load(fullfile(eyeStackDir,'frameInfo.mat'))

doEyeSimpDilation = 1;
if doEyeSimpDilation
    % use the first tiffstack in the directory for testing
    eyeStack = (tiffRead(fullfile(eyeStackDir,frameInfo(1).fileName)));
    iH = imshow(eyeStack(:,:,100));

    % Make rectangular roi and get positions
    rH = impoly(gca);
    pos = wait(rH);
    mask = createMask(rH);

    % For fun
    rZ = @(X)(reshape(X,numel(X(:,:,1)),size(X,3)));
    tM = @(X,M)(X)

    roiVals = eyeStack(
    hist(eyeStack(


    
    
    % Determine reasonable threshold
    
    % Apply threshold to the roi
    
    % Get a pupil diameter proxy for each frame (of all stacks)
    for iStack = 1:numel(frameInfo)
        
    end

    % Eliminate the eye blinks from trace, and record them in new vector
    
    % Change any values more than 1.5SD less than mean to nans

    % Save the frame-by-frame vectors
    eyeMotion.blinks = [];
    eyeMotion.diameterProxy = [];

    save(fullfile(procDir,'eyeMotion.mat'),'eyeMotion','-v7.3')
end
