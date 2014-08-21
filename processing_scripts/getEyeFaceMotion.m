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
animalName  = 'K71';
expDateNum  = '20140815_01';

nRois       = 4;
makeNewRois = 1;

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
processFaceImages = 1;
if processFaceImages
    % Stacks of face tiff movies stored here (and file info in mat file)
    faceStackDir = fullfile(procDir,'faceStacks');
    load(fullfile(faceStackDir,'frameInfo.mat'));

    % Load in one file for drawing roi
    faceImage = imread(fullfile(faceStackDir,frameInfo(1).fileName),100);

    % Find a region of interest for the snout tracking
    % Seems like slecting part of the nose helps
    if makeNewRois || ~exist(fullfile(procDir,'faceROIs.mat'),'file')
        for iRoi = 1:nRois
            clf;
            imagesc(faceImage);
            switch iRoi
                case 1
                    roi(iRoi).label = 'main';
            end

            RoiH = imrect(gca);
            roi(iRoi).Pos = round(getPosition(RoiH));
            roi(iRoi).Xinds = roi(iRoi).Pos(1):(roi(iRoi).Pos(1)+roi(iRoi).Pos(3)); 
            roi(iRoi).Yinds = roi(iRoi).Pos(2):(roi(iRoi).Pos(2)+roi(iRoi).Pos(4));

            pause(.1)
            croppedFace = sampleFrame(roi(iRoi).Yinds,roi(iRoi).Xinds);
            imagesc(croppedFace)
        end
        save(fullfile(procDir,'faceROIs.mat'),'roi');
    else
        load(fullfile(procDir,'faceROIs.mat'));
    end

    % Make a substack with just this ROI
    fprintf('Loading in stacks for stackRegister\n') 
    totalFrames = 0;

    for iRoi = 1:nRois
        fprintf('ROI: %2.d /  %2.d\n',iRoi,nRois)
        for iStack = 1:numel(frameInfo)
            fprintf('Stack: %4.d /  %4.d\n',iStack,numel(frameInfo))
            currStack = tiffRead(fullfile(faceStackDir,frameInfo(iStack).fileName),8);
            faceSubStack = (zeros(numel(roi(iRoi).Yinds),numel(roi(iRoi).Xinds),size(currStack,3)));
            for iFrame = 1:size(currStack,3) 
                faceSubStack(:,:,iFrame) = currStack(roi(iRoi).Yinds,roi(iRoi).Xinds,iFrame);
            end

            % Register to the median frame stack
            if iStack == 1
                refFrame{iRoi} = median(faceSubStack,3);
                roiFrame{iRoi} = faceSubStack(:,:,round(.5*size(faceSubStack,3)));
            end

            [stackRegOut,~] = stackRegister(faceSubStack,refFrame);
            faceMotionStruct(iStack).stackReg = stackRegOut;
            totalFrames = size(faceSubStack,3) + totalFrames;
        end
    end

    stackRegOut = [];
    for i = 1:numel(faceMotionStruct)
        stackRegOut = [stackRegOut; faceMotionStruct(i).stackReg];
    end

    faceMotion.stackReg = stackRegOut;
    faceMotion.refFrames = refFrame;
    faceMotion.roiFrame = roiFrame;
    faceMotion.totalFrames = totalFrames;
    save(fullfile(procDir,'faceMotion.mat'),'faceMotion','-v7.3')

end

%------------------------------------------------------------------
%% EYE
%------------------------------------------------------------------
% Do dialation analysis on eye
eyeTiffPath = dir([procDir filesep 'eye_*.tiff']);
eyeTiffPath = fullfile(procDir,eyeTiffPath(1).name);
eyeImInfo = imfinfo(eyeTiffPath);

doEyeStackReg = 0;
if doEyeStackReg
    testing = 1;
    if testing
        junkData = unidrnd(10,numel(eyeImInfo),4);
        eyeMotion.stackReg = junkData;
        save(fullfile(procDir,'eyeMotion.mat'),'eyeMotion','-v7.3')
        eyeFramesToUse = 1:floor(numel(eyeImInfo)/4);
    else
        eyeframesToUse = 1:numel(imInfo);
    end
    eyeImage = zeros(imInfo(1).Width,imInfo(1).Height,numel(eyeFramesToUse));
    for iFrame = framesToUse
       eyeImage(:,:,iFrame) = imread(eyeTiffPath,iFrame);
    end

    baseFrame = 330;
    [stackRegOut,~] = stackRegister(eyeMotion,eyeMotion(:,:,baseFrame));
    eyeMotion(1).stackReg = stackRegOut;
    save(fullfile(procDir,'eyeMotion.mat'),'eyeMotion','-v7.3')
end

doEyeBlack = 1;
if doEyeBlack
    save(fullfile(procDir,'eyeBlack.mat'),'eyeBlack','-v7.3')
end
