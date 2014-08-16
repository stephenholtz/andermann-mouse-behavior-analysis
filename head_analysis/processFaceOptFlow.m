%% processFaceOptFlow.m
%
% Try to use the computer vision system toolbox to track facial motion
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
%% Initalize
forceClear = 1;
if forceClear
    close all force; 
    clear all force;
end

% General Flags
verbose     = 1;
saveFigs    = 1;

% Fig Specific vars
textSize    = 14;
overwriteSnoutStack = 1;


%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140808_01';

% Retrieve folder location
dataDir     = getExpDataSource('macbook');
expDir      = fullfile(dataDir,animalName,expDateNum);
saveDir     = fullfile(dataDir,'summary-figures',animalName);
if ~exist(saveDir,'dir')
    mkdir(saveDir)
end

% Find all the avi files (a bit of unneeded specificity)
movieDirName = 'whisker';
movieFileBaseName = 'whisker';
aviLocation = fullfile([expDir filesep movieDirName]);
aviFileStruct = dir([aviLocation filesep movieFileBaseName '*.avi']);
% Sort the files by datenum to fix ordering problems
[~,aviOrder]= sort([aviFileStruct(:).datenum]);
aviFiles = {aviFileStruct(aviOrder).name}; 

%% Import avi files and select an ROI
% set up object instances
for iAvi = 1:numel(aviFiles)
    vObj(iAvi) = VideoReader(fullfile(aviLocation,aviFiles{iAvi}));
    [~] = read(vObj(iAvi),inf);
    nFrames(iAvi) = vObj(iAvi).NumberOfFrames;
end
totalFrames = sum(nFrames);
framesToUse = 1:500;
avisToUse = 1;

%% Make a stack with just the snout for processing
if overwriteSnoutStack || ~exist('snoutStack','var') && ~(exist(fullfile(saveDir,'snoutStack.avi'),'file'))
    % Find a region of interest for the snout tracking
    figure('Color',[1 1 1]);
    sampleFrame = read(vObj(1),1);
    imagesc(sampleFrame);

    % Selecting from just below the eyes, to above the nose works best, as
    % long as the rectangle is not too wide.
    snoutRoiH = imrect(gca);
    snoutPos = round(getPosition(snoutRoiH));
    snoutXinds = snoutPos(1):(snoutPos(1)+snoutPos(3)); 
    snoutYinds = snoutPos(2):(snoutPos(2)+snoutPos(4));

    croppedSnout = sampleFrame(snoutYinds,snoutXinds);
    imagesc(croppedSnout)

    % save an avi of the snoutStack
    fprintf('\tMaking snoutStack\n')
    snoutObj = VideoWriter(fullfile(saveDir,'snoutStack.avi'));
    snoutStack = zeros(numel(snoutYinds),numel(snoutXinds),numel(framesToUse));
    frameIter = 1;
    for iAvi = 1%:numel(vObj) 
        for iFrame = framesToUse
            currFrame = read(vObj(1),iFrame);
            snoutStack(:,:,frameIter) = currFrame(snoutYinds,snoutXinds);
            frameIter = frameIter + 1; 
        end
    end
    open(snoutObj)
    % Reshape doesn't work for this for some reason
    for iFrame = 1:size(snoutStack,3)
        writeVideo(snoutObj,mat2gray(snoutStack(:,:,iFrame)));
    end
    close(snoutObj);
    clear snoutObj
    save(fullfile(saveDir,'snoutStack.mat'),'snoutStack','-v7.3')
    %snoutObj = VideoReader(fullfile(saveDir,'snoutStack.avi'));
elseif exist(fullfile(saveDir,'snoutStack.avi'),'file')
    fprintf('\tLoading snoutStack\n')
    load(fullfile(saveDir,'snoutStack.mat'))
    %snoutObj = VideoReader(fullfile(saveDir,'snoutStack.avi'));
end

%% Make vision objects

% Required to be this object for the comp vision toolbox functions
snoutObj = vision.VideoFileReader(fullfile(saveDir,'snoutStack.avi'));
snoutObj.ImageColorSpace = 'Intensity';

% May need to convert the image type (use this)
converter = vision.ImageDataTypeConverter;

% Optical Flow computer vision toolbox
clear opticalFlow
opticalFlow = vision.OpticalFlow;
output = 1;
switch output
    case 1
        opticalFlow.OutputValue = 'Magnitude-squared';
        opticalFlow.Method = 'Horn-Schunck';
        iAvi = 1;
        frameIter = 1;
        figure('Position',[50 50 800 800],'Color',[1 1 1]);
        summedMov = zeros(numel(framesToUse),1);
        for iFrame = framesToUse
            currFrame = read(vObj(iAvi),iFrame);
            currVisFrame = step(snoutObj);
            currFlow = step(opticalFlow,currVisFrame);
            frameIter = frameIter + 1;
            subplot(2,2,[1])
            imagesc(currFrame)
            subplot(2,2,2);
            plotFrames = (iFrame-10):iFrame;
            plotFrames(plotFrames < 1) = 1;
            summedMov(iFrame) = sum(currFlow(:));
            plot(summedMov(plotFrames),'LineWidth',3)
            axis([xlim min(summedMov)-eps max(summedMov)+eps]);
            subplot(2,2,3)
            imagesc(currVisFrame)
            subplot(2,2,4)
            imagesc(currFlow)
            pause(.05)
        end
    case 2
        opticalFlow.Method = 'Lucas-Kanade';
        opticalFlow.OutputValue = 'Horizontal and vertical components in complex form';
        iAvi = 1;
        frameIter = 1;
        figure('Position',[50 50 800 800],'Color',[1 1 1]);
        shapeObj = vision.ShapeInserter;
        shapeObj.Shape = 'Lines';
        shapeObj.BorderColor = 'white';
        [Y, X] = meshgrid(1:size(snoutStack,1), 1:size(snoutStack,2));
        for iFrame = framesToUse
            currFrame = read(vObj(iAvi),iFrame);
            currVisFrame = step(snoutObj);
            currFlow = step(opticalFlow,currVisFrame);
            H = imag(currFlow)*5;
            V = real(currFlow)*5;
            lines = [Y(:)'; X(:)'; Y(:)'+V(:)'; X(:)'+H(:)'];
            shapeOut = step(shapeObj, currVisFrame,  lines');

            frameIter = frameIter + 1;
            subplot(2,2,[1 2])
            imagesc(currFrame)
            subplot(2,2,3)
            imagesc(currVisFrame)
            subplot(2,2,4)
            imagesc(shapeOut)
            pause(.04)
        end
    case 3
        for iFrame = framesToUse
        end
end
