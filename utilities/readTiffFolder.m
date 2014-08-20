function [stack,stackFrameNums] = readTiffFolder(folder,frameNumbers,method)
% function [stack] = readTiffFolder(folder,frameNumbers)
% folder: a folder with only tiff stacks in it
% frameNumbers: the numbers of the frames w/rt the entire appended
% set of tiffstacks desired, can span/bridge multiple stacks
%
% folder has a frameInfo.mat file with frame number by file lookups
% and total frames
% 
% SLH 

% Determine the frame numbers in each stack from frameInfo.mat
frameInfoFname = fullfile(folder,'frameInfo.mat');
if ~exist('frameInfoFname','var')
    error('frameInfo.mat not found')
else
    load(frameInfoFname)
end

% Get file names for each tiff in the folder
tiffPath = dir([folder filesep '*.tiff']);
% Sort the 
faceTiffPath = fullfile(folder,faceTiffPath(1).name);
imInfo = imfinfo(faceTiffPath);

% Determine the stacks that have desired frames
stacksToUse = 0;

% matrix with starting and stopping frames within
% each stack
stackSubsets = 0;

% preallocate stack
stack = zeros(nRows,nCols,nStackFrames);

% load in each folder
