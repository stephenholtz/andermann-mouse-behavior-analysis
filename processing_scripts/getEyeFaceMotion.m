%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140815_01';
nRois       = 1;

% Get the base location for data, see function for details
dataDir = getExpDataSource('macbook');
% Experiment directory
expDir  = fullfile(dataDir,animalName,expDateNum);
% Processed data filepath
procDir = fullfile(expDir,'proc');

%% Import entire face image for processing
faceTiffPath = dir([procDir filesep 'face_*.tiff']);
faceTiffPath = fullfile(procDir,faceTiffPath(1).name);
imInfo = imfinfo(faceTiffPath);

testing = 1;
if testing
    % some real junk data
    junkData = unidrnd(10,1777685,4);
    faceMotion.stackReg = junkData;
    save(fullfile(procDir,'faceMotion.mat'),'faceMotion','-v7.3')
    framesToUse = 1:floor(numel(imInfo)/4);
else
    framesToUse = 1:numel(imInfo);
end
faceImage = zeros(imInfo(1).Width,imInfo(1).Height,numel(framesToUse));
for iFrame = framesToUse
   faceImage(:,:,iFrame) = imread(faceTiffPath,iFrame);
end
% Find a region of interest for the snout tracking
% Seems like slecting part of the nose helps
for iRoi = 1:nRois
    clf;
    sampleFrame = faceImage(:,:,1);
    imagesc(sampleFrame);
    snout.RoiH{iRoi} = imrect(gca);
    snout.Pos{iRoi} = round(getPosition(snout.RoiH{iRoi}));
    snout.Xinds{iRoi} = snout.Pos{iRoi}(1):(snout.Pos{iRoi}(1)+snout.Pos{iRoi}(3)); 
    snout.Yinds{iRoi} = snout.Pos{iRoi}(2):(snout.Pos{iRoi}(2)+snout.Pos{iRoi}(4));

    pause(.5)
    croppedSnout = sampleFrame(snout.Yinds{iRoi},snout.Xinds{iRoi});
    imagesc(croppedSnout)
end

% Make a substack with just this ROI
for iRoi = nRois
    fprintf('Finding face motion, Frame %0.10d',1)
    faceSubStack = (zeros(numel(snout.Yinds{iRoi}),numel(snout.Xinds{iRoi}),numel(framesToUse)));
    frameIter = 1;
    for iFrame = framesToUse
        if ~mod(frameIter,100)
            fprintf('\b\b\b\b\b\b\b\b\b\b%0.10d',iFrame)
        end
        faceSubStack(:,:,frameIter) = faceImage(snout.Yinds{iRoi},snout.Xinds{iRoi},iFrame);
        frameIter = frameIter + 1; 
        fprintf('\n')
    end
end

%% Use a rigid registration algorithm (fft of 2d xcorr?) to figure out movement
% From stackRegister: (call will be verbose)
%      OUTS(:,1) is correlation coefficients
%      OUTS(:,2) is global phase difference between images 
%               (should be zero if images real and non-negative).
%      OUTS(:,3) is net row shift
%      OUTS(:,4) is net column shift
baseFrame = 10;
[stackRegOut,~] = stackRegister(faceMotion,faceMotion(:,:,baseFrame));
faceMotion(1).stackReg = stackRegOut;
save(fullfile(procDir,'faceMotion.mat'),'faceMotion','-v7.3')

%------------------------------------------------------------------
%% EYE
%------------------------------------------------------------------
% Import eye image stack for processing
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
