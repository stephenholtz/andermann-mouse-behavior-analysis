function [tiffInfo, mat] = aviToMatBigTiff(aviFileCellArray,aviFileDirectory,saveFileName,compression)
% function [tiffInfo, mat] = aviToMatBigTiff(aviFileCellArray,aviFileDirectory,saveFileName)
%  Very simple avi reading and tiff writing with bigtiff format
%
%  Takes an argument for compression type. Should use JPEG for the videos, 
%  and LZW or none for epi data.
%  
% SLH 2014
%#ok<*NBRAK,*UNRCH>

mat = [];

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
t = Tiff(saveFileName,'w8');
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

testing = 0;
if testing
    framesToWrite = 1:2000:sum(nFrames);
else
    framesToWrite = 1:sum(nFrames);
end

fprintf('\nConverting AVI(s) to Tiff Stack: %.8d / %8.d',1,numel(framesToWrite));
updateIncrement = ceil(log10(numel(framesToWrite)));
% Write all the frames to a tiffstack
for iFrame = framesToWrite
    % Find the correct avi file to read (if needed)
    iAvi = find(cumsum(nFrames) > iFrame, 1, 'first');
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
fprintf('\n');

% Close the tiff
t.close();

% Give some output
tiffInfo = tagstruct;
tiffInfo.NumFrames = numel(framesToWrite);
