%% processFaceStackReg.m
%
% Quick script to sequentially loads in movie frames for processing.
%
% All movies are motion jpeg compressed avi files w/ quality 
% between 60-100 (less than 50 is not useable)
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
nRois       = 1;

% Fig Specific vars
showDownsampAvis = 0;
makeStackRegSnoutAvi = 0;
textSize = 14;
saveSnoutAvi = 0;

%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140815_01';

% Get the base location for data, see function for details
dataDir = getExpDataSource('macbook');
% Experiment directory
expDir  = fullfile(dataDir,animalName,expDateNum);
% Processed data filepath
procDir = fullfile(expDir,'proc');

faceTiffPath = dir([procDir filesep 'face_*.tiff']);
faceTiffPath = fullfile(procDir,faceTiffPath(1).name);

%% Find all the avi files (a bit of unneeded specificity)
%movieDirName = 'whisker';
%movieFileBaseName = 'whisker';
%aviLocation = fullfile([expDir filesep movieDirName]);
%aviFileStruct = dir([aviLocation filesep movieFileBaseName '*.avi']);
%% Sort the files by datenum to fix ordering problems
%[~,aviOrder]= sort([aviFileStruct(:).datenum]);
%aviFiles = {aviFileStruct(aviOrder).name}; 

%%% Import avi files and select ROI(s)
% set up object instances
%for iAvi = 1:numel(aviFiles)
%    vObj(iAvi) = VideoReader(fullfile(aviLocation,aviFiles{iAvi}));
%    [~] = read(vObj(iAvi),inf);
%    nFrames(iAvi) = vObj(iAvi).NumberOfFrames;
%end
%totalFrames = sum(nFrames);

%% Import entire image for stackreg...
imInfo = imfinfo(faceTiffPath);
testing = 1;
if testing
    junkData = unidrnd(10,numel(imInfo),4);
    faceMotion.stackReg = junkData;
    save(fullfile(procDir,'faceMotion.mat'),'faceMotion','-v7.3')
end
%framesToUse = 1:numel(imInfo);
framesToUse = 1:floor(numel(imInfo)/4);
faceImage = zeros(imInfo.Width,imInfo.Height,numel(framesToUse));
for iFrame = framesToUse
   faceImage(:,:,iFrame) = imread(faceTiffPath,iFrame);
end

%sampleFrame = read(vObj(1),1);

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

% Look at rough movements and video problems
if showDownsampAvis 
    figure('Color',[1 1 1],'Position',[25 25 800 400]);
    frameStride = 2;
    for iAvi = 1:numel(aviFiles)
        for iFrame = 1:frameStride:nFrames(iAvi)
            currFrame = read(vObj(iAvi),iFrame);
            subplot(1,2,[1]);
            imagesc(currFrame);
            title('Full')
            subplot(1,2,[2]);
            imagesc(currFrame(snout.Yinds{iRoi},snout.Xinds{iRoi}));
            title('Snout')
            colormap(gray)
            pause(.1)
        end
    end
end

% Make a substack with just this ROI
%framesToUse = 1:6000;
for iRoi = nRois
    fprintf('Finding face motion, Frame %0.10d',1)
    faceMotion = (zeros(numel(snout.Yinds{iRoi}),numel(snout.Xinds{iRoi}),numel(framesToUse)));
    frameIter = 1;
    for iFrame = framesToUse
        if ~mod(frameIter,100)
            fprintf('\b\b\b\b\b\b\b\b\b\b%0.10d',iFrame)
        end
        faceMotion(:,:,frameIter) = faceImage(snout.Yinds{iRoi},snout.Xinds{iRoi},iFrame);
        frameIter = frameIter + 1; 
        fprintf('\n')
    end

%    if 0
%        faceMotion{iRoi} = (zeros(numel(snout.Yinds{iRoi}),numel(snout.Xinds{iRoi}),totalFrames));
%        frameIter = 1;
%        for iAvi = 1:numel(aviFiles)
%            fprintf('\t\tAVI %d of %d\n',iAvi,numel(aviFiles))
%            fprintf('\t\t\tFrame %0.10d',1)
%            for iFrame = 1:nFrames(iAvi)
%                if ~mod(iFrame,100)
%                    fprintf('\b\b\b\b\b\b\b\b\b\b%0.10d',iFrame)
%                end
%                currFrame = (read(vObj(iAvi),iFrame));
%                faceMotion{iRoi}(:,:,frameIter) = currFrame(snout.Yinds{iRoi},snout.Xinds{iRoi});
%                frameIter = frameIter + 1; 
%            end
%            fprintf('\n')
%        end
%    end
%    if saveSnoutAvi
%        fprintf('\t\tWriting snout ROI %d to AVI',iRoi)
%        snoutObj(iRoi) = VideoWriter(fullfile(saveDir,['snoutStackRoi_' num2str(iRoi) '.avi']));
%        open(snoutObj(iRoi))
%        % Reshape doesn't work for this for some reason
%        for iFrame = 1:size(snoutStack{iRoi},3)
%            writeVideo(snoutObj(iRoi),(snoutStack{iRoi}(:,:,iFrame)));
%        end
%        close(snoutObj(iRoi));
%    end
end
%save(fullfile(procDir,'faceMotion.mat'),'faceMotion','snout','-v7.3')


%% Use a rigid registration algorithm (fft of 2d xcorr?) to figure out movement
% From stackRegister: (call will be verbose)
%      OUTS(:,1) is correlation coefficients
%      OUTS(:,2) is global phase difference between images 
%               (should be zero if images real and non-negative).
%      OUTS(:,3) is net row shift
%      OUTS(:,4) is net column shift
for iRoi = 1
    [stackRegOut,regStack] = stackRegister(faceMotion,faceMotion(:,:,10));
end
faceMotion.stackReg = stackRegOut;
save(fullfile(procDir,'faceMotion.mat'),'faceMotion','-v7.3')

%% Make an AVI to Look at rough movements and video problems
if makeStackRegSnoutAvi
    aviFileName = ['Snout-movement-' animalName '-' expDateNum '-stackRegister.avi']; 
    vwObj = VideoWriter(fullfile(figSaveDir,aviFileName),'Motion JPEG AVI');
    vwObj.Quality = 100;
    open(vwObj)

    figure('Color',[1 1 1],'Position',[25 25 800 800]);
    frameIter = 1;
    frameStride = 2;
    iAvi = 1;
    framesToUse = 1:nFrames(iAvi);
    for iFrame = framesToUse 
        % Show full and cropped images
        currFrame = read(vObj(iAvi),iFrame);
        subplot(2,2,[1]);
        imagesc(currFrame);
        title('Full','FontSize',FontSizeLg)
        subplot(2,2,[2]);
        imagesc(currFrame(snout.Yinds{iRoi},snout.Xinds{iRoi}));
        colormap(gray)
        title('Snout','FontSize',FontSizeLg)

        % Plot the output of stackRegister 
        aH = subplot(2,1,2);
        cla(aH);
        plotFrames = (iFrame-20):iFrame;
        plotFrames(plotFrames < 1) = 1;
        plot(outs(plotFrames,4),'LineWidth',3,'FontSize',FontSizeLg)
        hold on 
        plot(diff([outs(plotFrames(1),4); outs(plotFrames,4)]),'LineWidth',3,'FontSize',FontSizeLg)
        box off
        axis([xlim min(outs(:,4)) max(outs(:,4))]);
        title('stackRegister out','FontSize',FontSizeLg)
        ylabel('Column Displacement','FontSize',FontSizeLg)
        xlabel('Frame Num','FontSize',FontSizeLg)
        lH = legend('Displacement','Diff(displacement)');
        set(lH,'Location','NorthWest','FontSize',FontSizeLg)

        % avifile seems to not work for large movies
        % Best option for getting high quality movies is now to print a jpg, then 
        % load it back in and add that to the video with writeVideo
        %
        % This method is incredibly slow, but works:
        figPos = get(gcf,'Position');
        figPos = [figPos(1) figPos(2) figPos(3)-figPos(1)-1 figPos(4)-figPos(2)-1];
        gottenFrame = getframe(gcf,figPos);
        writeVideo(vwObj,gottenFrame);
    end
    close(vwObj);
end
