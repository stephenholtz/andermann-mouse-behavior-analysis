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

fprintf('\nConverting AVI(s) to Tiff Stack: %.8d / %8.d',1,numel(framesToWrite));
updateIncrement = ceil(log10(numel(framesToWrite)));

switch loadType
    case {'allAtOnce',1}
        % Load all frames into memory and then write tiff stack
        %rawFrames = (zeros(nImgRows,nImgCols,numel(framesToWrite)));
        rawFrames(nImgRows,nImgCols,numel(framesToWrite)) = 0;
        for iFrame = framesToWrite
            iAvi = find(cumsum(nFrames) >= iFrame, 1, 'first');
            aviFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
            currRawFrame = read(vObj(iAvi),aviFrame);        
            rawFrames(:,:,iFrame) = currRawFrame(:,:,1);
            if ~mod(iFrame,updateIncrement)
                fprintf([repmat('\b',1,19) '%8.d / %8.d'],iFrame,numel(framesToWrite));
            end
        end
        if ~exist('writetiff','file')
            writetiff(rawFrames,saveFileName,'uint8');
        else
            imwrite(rawFrames,saveFileName)
        end

    case {'paralell',2}
        % Load all frames into memory in paralell and then write tiff stack
    case {'serial',3}
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
