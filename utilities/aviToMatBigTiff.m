function tiffInfo = aviToMatBigTiff(aviFileCellArray,aviFileDirectory,saveFileName,compression,loadType)
%function tiffInfo = aviToMatBigTiff(aviFileCellArray,aviFileDirectory,saveFileName,compression,loadType)
%  Very simple avi reading and tiff writing that works on the server as
%  a memory hog, or locally with bigtiff format
%
%  Takes an argument for compression type. Should use JPEG for the videos, 
%  and LZW or none for epi data.
%  
% SLH 2014
%#ok<*NBRAK,*UNRCH>

% Get info about AVI files
for iAvi = 1:numel(aviFileCellArray)
    vObj(iAvi) = VideoReader(fullfile(aviFileDirectory,aviFileCellArray{iAvi}));
    [~] = read(vObj(iAvi),inf);
    nFrames(iAvi) = vObj(iAvi).NumberOfFrames;
end
nImgRows = vObj(1).Height;
nImgCols = vObj(1).Width;
switch vObj(1).VideoFormat
    case {'RGB24'}
        % This is UINT8x3 off the pointgrey camera
        bitDepth = 8;
        doRgbToGray = 1;
    case {'Grayscale'}
        % This is from the epi camera
        bitDepth = vObj(1).BitsPerPixel;
        doRgbToGray = 0;
    otherwise
        error('VideoFormat not accounted for')
end

% Open up a BigTIFF file to write to
tagstruct.ImageLength = nImgRows;
tagstruct.ImageWidth = nImgCols;
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = bitDepth;
tagstruct.SamplesPerPixel = 1;
%tagstruct.RowsPerStrip = 1;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

% See libtiff documentation or matlab's for explanation
switch lower(compression)
    case {'no'}
        tagstruct.Compression = Tiff.Compression.None;
    case {'jpeg'}
        tagstruct.Compression = Tiff.Compression.JPEG;
    case {'lzw'}
        tagstruct.Compression = Tiff.Compression.LZW;
    otherwise
        error('Compression type not accounted for');
end
framesToWrite = 1:sum(nFrames);
updateIncrement = ceil(log10(numel(framesToWrite)));

switch loadType
    case {'writeFolder',0}
        % Write 2k stacks from the AVIs to a folder, with a frameInfo.mat file for lookup
        % they are ordered, but include a field just incase it isn't clear
        nPerStack = 1000;
        totalFrames = sum(nFrames);
        framesLeft = 1:totalFrames;
        iStack = 1;
        [d,f,e] = fileparts(saveFileName);

        while ~isempty(framesLeft)
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

            frameInfo(iStack).fileName = [prepend '_f' firstFrame '_l' lastFrame '_' f e ];
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

            % Store the inds of the avis that the frames came from
            for i = 1:numel(frameInfo(iStack).fileSource)
                frameIter = 1;
                for iFrame = currFrames 
                    aviUsed(iter) = find(cumsum(nFrames) >= iFrame, 1, 'first');
                    aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
                    frameInfo(iStack).aviFrameNum{i}(frameIter) = aviFrame;
                    frameIter = frameIter + 1;
                end
            end
            
            if numel(framesLeft) >= nPerStack
                framesLeft = framesLeft(nPerStack+1:end);
            else
                framesLeft = [];
            end
            iStack = iStack + 1;
        end 
        
        % save frameInfo struct
        save(fullfile(d,'frameInfo.mat'),'frameInfo','-v7.3')
        fprintf('Saved: %s\n',fullfile(d,'frameInfo.mat'))

        % Write each of the tiffstacks in parpool
        %try
        %    if isempty(gcp)
        %        parpool;
        %    end
        %    legacyPar = 0;
        %catch ME %#ok<*NASGU>
        %     matlabpool('open',4);
        %     legacyPar = 1;
        %end

        % For just grabbing
        takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));

        % Complex for parfor, would need to pregenerate all needd objects...
        aviFrame = 0;
        stacksToWrite = 1:numel(frameInfo);
        for iStack = stacksToWrite
            % Read in the images for this stack with VideoRead
            frameIter = 1;
            framesToUse = frameInfo(iStack).frameNums;
            rawFrames = uint8(zeros(nImgRows,nImgCols,numel(frameInfo(iStack).frameNums)));
            fprintf('\nAVI loading for stack %d / %d\n',iStack,numel(stacksToWrite));
            fprintf('\tAVI frame %8.d / %8.d',frameIter,numel(framesToUse));
            for iFrame = framesToUse
                if ~mod(frameIter,ceil(nPerStack/10));
                    fprintf([repmat('\b',1,29) 'AVI frame %8.d / %8.d'],frameIter,numel(framesToUse));
                end
                iAvi = find(cumsum(nFrames) >= iFrame, 1, 'first');
                aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
                rawFrames(:,:,frameIter) = takeOne3rdDim(read(vObj(iAvi),aviFrame));        
                frameIter = frameIter + 1;
            end
            fprintf('\nTiff writing for stack %d of %d\n',iStack,numel(stacksToWrite));
            option.BitsPerSample = 8;
            option.Append = false;
            option.Compression = 'LZW';
            option.BigTiff = true;
            tiffWrite(rawFrames,frameInfo(iStack).fileName,d,option)
        end

        % Clean up parpool objects
        %if legacyPar
        %    matlabpool('close')
        %elseif ~isempty(gcp)
        %    delete(gcp)
        %end
       
    case {'allAtOnce',1}
        % Load all frames into memory and then write tiff stack
        fprintf('\nConverting AVI(s) to Tiff Stack: %.8d / %8.d',1,numel(framesToWrite));
        rawFrames = (zeros(nImgRows,nImgCols,numel(framesToWrite)));
        for iFrame = framesToWrite
            iAvi = find(cumsum(nFrames) >= iFrame, 1, 'first');
            aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
            currRawFrame = read(vObj(iAvi),aviFrame);        
            rawFrames(:,:,iFrame) = currRawFrame(:,:,1);
            if ~mod(iFrame,updateIncrement)
                fprintf([repmat('\b',1,19) '%8.d / %8.d'],iFrame,numel(framesToWrite));
            end
        end
        if exist('writetiff','file')
            startupMA            
            writetiff(rawFrames,saveFileName,'uint8');
        else
            imwrite(rawFrames,saveFileName)
        end

    case {'byMovieFullLoadParFor',2}
        % Works okay on the server, loads in each movie, takes the relevant
        % dimension and then writes the concatenated stack as a tiff...
        % depends on having a lot of free ram...
        takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));
        try
            parpool(4)
            legacyPar = 1;
        catch ME %#ok<*NASGU>
            matlabpool('open',4);
            legacyPar = 1;
        end
        parfor iAvi = 1:numel(vObj)
            disp(['Started iAvi : ' num2str(iAvi)])
            rawFrames{iAvi} = takeOne3rdDim(read(vObj(iAvi)));
            disp(['Finished iAvi : ' num2str(iAvi)])
        end
        if ~legacyPar
            matlabpool('close')
        end
        frames = [];
        for iAvi = 1:numel(vObj)
           frames = cat(3,frames,rawFrames{iAvi}); 
        end
        if exist('writetiff','file')
            startupMA
            writetiff(frames,saveFileName,'uint8');
        else
            imwrite(frames,saveFileName)
        end
    case {'byMovieParFor',3}
        % Works okay on the server, writes a series of tiffs
        takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));
        try
            parpool(4)
            legacyPar = 1;
        catch ME %#ok<*NASGU>
            matlabpool('open',4);
            legacyPar = 1;
        end
        for iAvi = 1:numel(vObj)
            disp(['Started iAvi : ' num2str(iAvi)])
            frames = takeOne3rdDim(read(vObj(iAvi)));
            disp(['Finished iAvi : ' num2str(iAvi)])
            [d,f,e]=fileparts(saveFileName);
            if numel(num2str(iAvi)) < 10
                prepend =['0' num2str(iAvi)];
            else
                prepend = num2str(iAvi);
            end
            currFileName = fullfile(d,[prepend '_' f e]);
            options.color = false;
            options.append = false;
            options.append = 'lzw';
            saveastiff(frames,currFileName,options);
            %%%Very very large files written with x12 blowup from AVI!!
            %%startupMA
            %%writetiff(frames,currFileName,'uint8');
        end
        if ~legacyPar
            matlabpool('close')
        end        
        
    case {'byMovie',4}
        % Works okay on the server, writes a series of tiffs
        takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));
        for iAvi = 1:numel(vObj)
            disp(['Started iAvi : ' num2str(iAvi)])
            frames = takeOne3rdDim(read(vObj(iAvi)));
            disp(['Finished iAvi : ' num2str(iAvi)])
            [d,f,e]=fileparts(saveFileName);
            if numel(num2str(iAvi)) < 10
                prepend =['0' num2str(iAvi)];
            else
                prepend = num2str(iAvi);
            end
            currFileName = fullfile(d,[prepend '_' f e]);
            options.color = false;
            options.append = true;
            options.comp = 'none';
            disp(['Curr tiff name: ' currFileName])
            
            % This is how to use matlab's imwrite in a stable way...

            iFrame = 1;
            while iFrame <= size(frames,3) 
                written = 0;   
                while ~written
                    % Not sure how this situation occurs, but required
                    if iFrame > size(frames,3)
                        break
                    end
                    if ~mod(iFrame,100)
                        disp(['Frames written: ' num2str(iFrame)]);
                    end
                    try
                        if iFrame == 1
                            imwrite(frames(:,:,iFrame),currFileName,'WriteMode','overwrite')
                        else
                            imwrite(frames(:,:,iFrame),currFileName,'WriteMode','append')
                        end
                        written = 1;
                        iFrame = iFrame + 1;
                    catch STUPID
                        disp(['STUPID: permission error, trying again on frame ' num2str(iFrame)])
                        written = 0;
                        pause(.05)
                    end
                end
            end
            
            %%%does not work for large files, stay as corrupt temporary
            %%%files... 
            %saveastiff(frames,currFileName,options);
            %%%Very very large files written with x12 blowup from AVI!!
            %%startupMA
            %%writetiff(frames,currFileName,'uint8');
        end
        
    case {'serial',5}
        fprintf('\nConverting AVI(s) to BigTiff Stack: %.8d / %8.d',1,numel(framesToWrite));
        % Write all the frames to a tiffstack
        t = Tiff(saveFileName,'w8');
        for iFrame = framesToWrite
            % Find the correct avi file to read (if needed)
            iAvi = find(cumsum(nFrames) >= iFrame, 1, 'first');
            aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
            currRawFrame = read(vObj(iAvi),aviFrame);

            if doRgbToGray
                currFrame = rgb2gray(currRawFrame); 
            else
                currFrame = currRawFrame;
            end
            
            % Write the tag structure for each frame
            t.setTag(tagstruct);
            t.write(currFrame);

            if iFrame ~= framesToWrite(end)
                t.writeDirectory();
            end
            if ~mod(iFrame,updateIncrement)
                fprintf([repmat('\b',1,19) '%8.d / %8.d'],iFrame,numel(framesToWrite));
            end
        end
        % Close the tiff
        t.close();
        tiffInfo = tagstruct;
    otherwise
        error('loadType not recognized')
end
fprintf('\n');

% Give some output
tiffInfo.NumFrames = numel(framesToWrite);
tiffInfo.saveFileName = saveFileName;
