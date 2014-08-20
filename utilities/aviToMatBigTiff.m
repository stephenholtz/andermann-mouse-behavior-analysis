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
            useParpool = 1;
        catch ME %#ok<*NASGU>
            matlabpool('open',4);
            useParpool = 1;
        end
        parfor iAvi = 1:numel(vObj)
            disp(['Started iAvi : ' num2str(iAvi)])
            rawFrames{iAvi} = takeOne3rdDim(read(vObj(iAvi)));
            disp(['Finished iAvi : ' num2str(iAvi)])
        end
        if ~useParpool
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
            useParpool = 1;
        catch ME %#ok<*NASGU>
            matlabpool('open',4);
            useParpool = 1;
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
        if ~useParpool
            matlabpool('close')
        end        
        
    case {'byMovie',4}
        % Works okay on the server, writes a series of tiffs
        takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));
        for iAvi = 1:numel(vObj)
            disp(['Started iAvi : ' num2str(iAvi)])
            for i = 1:100
                frames(:,:,i) = takeOne3rdDim(read(vObj(iAvi),i));
            end
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

            i = 1;
            while i <= size(frames,3) 
                written = 0;   
                while ~written
                    % Not sure how this situation occurs, but required
                    if i > size(frames,3)
                        break
                    end
                    if ~mod(i,100)
                        disp(['Frames written: ' num2str(i)]);
                    end
                    try
                        if i == 1
                            imwrite(frames(:,:,i),currFileName,'WriteMode','overwrite')
                        else
                            imwrite(frames(:,:,i),currFileName,'WriteMode','append')
                        end
                        written = 1;
                        i = i + 1;
                    catch STUPID
                        disp(['STUPID: permission error, trying again on frame ' num2str(i)])
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
