function tiffInfo = aviToTiffFolder(aviFileNames,aviFileDir,tiffFileBaseName,tiffFileDir,compression)
%%function tiffInfo = aviToTiffFolder(aviFileNames,aviFileDir,tiffFileBaseName,tiffFileDir,compression)
%  
%  Takes an argument for compression type. Should use JPEG for the videos, 
%  and LZW or none for epi data.
%  
% SLH 2014
%#ok<*NBRAK,*UNRCH,*AGROW>

%% Create AVI objects
for i = 1:numel(aviFileNames)
    vObj(i) = VideoReader(fullfile(aviFileDir,aviFileNames{i}));
    [~] = read(vObj(i),inf);
    nFrames(i) = vObj(i).NumberOfFrames;
end

% Assume all movies are the same dims
nRows = vObj(1).Height;
nCols = vObj(1).Width;

% Limited videoformat options for our data:
switch vObj(1).VideoFormat
    case {'RGB24'}
        % This is UINT8x3 off the pointgrey camera
        BitsPerPixel= 8;
        take3rdDim = 1;
    case {'Grayscale'}
        % This is from the epi camera
        BitsPerPixel = vObj(1).BitsPerPixel;
        take3rdDim = 0;
    otherwise
        error('VideoFormat not accounted for')
end

% Write stacks from the AVIs to a folder, with a frameInfo.mat file for lookup
nPerStack   = 1000;
totalFrames = sum(nFrames);
framesLeft  = 1:totalFrames;

%% Make a struct with information on each stack and the frames within
iStack = 1;
while ~isempty(framesLeft)

    % Update the current frames
    if numel(framesLeft) < nPerStack
        currFrames = framesLeft;
    else
        currFrames = framesLeft(1:nPerStack);
    end

    % Set up the name of the stack
    prepend = num2str(iStack);
    while numel(prepend) < 5
        prepend =['0' prepend];
    end

    firstFrame = num2str(currFrames(1));
    while numel(prepend) < 8 
        firstFrame =['0' firstFrame];
    end

    lastFrame = num2str(currFrames(end));
    while numel(prepend) < 8
        lastFrame =['0' lastFrame];
    end

    frameInfo(iStack).fileName = [prepend '_f' firstFrame '_l' lastFrame '_' tiffFileBaseName];
    frameInfo(iStack).stackNum = iStack;
    frameInfo(iStack).frameNums = currFrames;
    frameInfo(iStack).nTotalFrames = totalFrames;

    % Store the names of the avis that the frames came from
    aviUsed = zeros(numel(currFrames),1);
    iter = 1;
    for iFrame = currFrames
        aviUsed(iter) = find(cumsum(nFrames) >= iFrame, 1, 'first');
        iter = iter + 1;
    end 
    frameInfo(iStack).fileSource = aviFileCellArray(unique(aviUsed));

    % Store the inds of the avis that the frames came from (clunky)
    for i = 1:numel(frameInfo(iStack).fileSource)
        frameIter = 1;
        for iFrame = currFrames 
            aviUsed(iter) = find(cumsum(nFrames) >= iFrame, 1, 'first');
            aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
            frameInfo(iStack).aviFrameNum{i}(frameIter) = aviFrame;
            frameIter = frameIter + 1;
        end
    end

    % Update frames left
    if numel(framesLeft) >= nPerStack
        framesLeft = framesLeft(nPerStack+1:end);
    else
        framesLeft = [];
    end
    iStack = iStack + 1;
end 

% Save the frameInfo.mat file for later use (reduntant with filenames)
save(fullfile(tiffFileDir,'frameInfo.mat'),'frameInfo','-v7.3')
fprintf('Saved: %s\n',fullfile(tiffFileDir,'frameInfo.mat'))

% Anon func for grabbing that is faster than RGB conversion
takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));

% Loop over all of the stacks in one process
stacksToWrite = 1:numel(frameInfo);
for iStack = stacksToWrite

    frameIter = 1;

    % Which frames will be used in the stack
    framesInStack = frameInfo(iStack).frameNums;
    rawFrames = uint8(zeros(nRows,nCols,numel(frameInfo(iStack).frameNums)));

    % Print output
    fprintf('\nAVI loading for stack %d / %d\n',iStack,numel(stacksToWrite));
    fprintf('\tAVI frame %8.d / %8.d',frameIter,numel(framesInStack));

    for iFrame = framesInStack
        if ~mod(frameIter,ceil(nPerStack/10));
            fprintf([repmat('\b',1,29) 'AVI frame %8.d / %8.d'],frameIter,numel(framesInStack));
        end

        % Look up which avi object should be used
        iAvi = find(cumsum(nFrames) >= iFrame, 1, 'first');
        aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));

        if take3rdDim
            rawFrames(:,:,frameIter) = takeOne3rdDim(read(vObj(iAvi),aviFrame));        
        else
            rawFrames(:,:,frameIter) = (read(vObj(iAvi),aviFrame));        
        end
        frameIter = frameIter + 1;
    end

    fprintf('\nTiff writing for stack %d of %d\n',iStack,numel(stacksToWrite));

    % Use modified Harvey Lab writer (cleaner than mine)
    option.BitsPerSample = BitsPerPixel;
    option.Append = false;
    option.Compression = 'LZW';
    option.BigTiff = true;

    tiffWrite(rawFrames,frameInfo(iStack).fileName,tiffFileDir,option)
end
