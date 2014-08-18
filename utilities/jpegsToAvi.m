function [aviFileInfo] = jpegsToAvi(jpegFileCellArray,jpegFileDirectory,saveFileName)
%function jpegsToAvi(jpegFileCellArray,jpegFileDirectory,aviSaveDirectory)
%
% Writes a series of jpegs to an AVI file for viewing. Outputs the name
% of the file written to and other information about the AVI.
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

% Set up VideoWriter
vObj = VideoWriter(saveFileName,'Grayscale AVI');
nFrames = numel(jpegFileCellArray);

testing = 0;
if testing
    framesToWrite = 1:2000:sum(nFrames);
else
    framesToWrite = 1:sum(nFrames);
end

fprintf('\nConverting JPEGs to AVI: %.8d / %8.d',1,numel(framesToWrite));
updateIncrement = ceil(log10(numel(framesToWrite)));
open(vObj)
for iFrame = framesToWrite
    currFrame = rgb2gray(imread(fullfile(jpegFileDirectory,jpegFileCellArray{iFrame})));
    writeVideo(vObj,currFrame);

    if ~mod(iFrame,updateIncrement)
        fprintf([repmat('\b',1,19) '%8.d / %8.d'],iFrame,numel(framesToWrite));
    end
end
fprintf('\n')

% Give some output
aviFileInfo = get(vObj);
close(vObj);
