function nFrames = getNumAviFrames(aviFileCellArray,aviFileDirectory)
%function nFrames = getNumAviFrames(aviFileCellArray,aviFileDirectory)
% 
% Return number of frames in avi files.
% 
% Expects cell array of filenames and a directory.
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

% Very fast, iterate over videoreader objects to get the number of
% frames in each avi
for iAvi = 1:numel(aviFileCellArray)
    vObj(iAvi) = VideoReader(fullfile(aviFileDirectory,aviFileCellArray{iAvi}));
    [~] = read(vObj(iAvi),inf);
    nFrames(iAvi) = vObj(iAvi).NumberOfFrames;
end
for iAvi = 1:numel(aviFileCellArray)
    close(vObj(iAvi))
end
