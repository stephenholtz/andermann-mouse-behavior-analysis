function nFrames = getNumMovFrames(movFileCellArray,movFileDirectory)
%function nFrames = getNumMovFrames(movFileCellArray,movFileDirectory) 
% Return number of frames in video files.
% 
% Expects cell array of filenames and a directory.
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

% Very fast, iterate over videoreader objects to get the number of
% frames in each avi
for iMov = 1:numel(movFileCellArray)
    vObj(iMov) = VideoReader(fullfile(movFileDirectory,movFileCellArray{iMov}));
    [~] = read(vObj(iMov),inf);
    nFrames(iMov) = vObj(iMov).NumberOfFrames;
end
for iMov = 1:numel(movFileCellArray)
    delete(vObj(iMov))
end
