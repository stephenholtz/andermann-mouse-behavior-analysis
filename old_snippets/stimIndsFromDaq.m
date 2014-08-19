%% stimIndsFromDaq.m
% Determine when different stimuli occur in the DAQ's timeseries for easy processing,
% stimuli / blocks are not randomized in these experiments.
%
% stimType  = enumerated unique conditions by order of appearance (1:6)
% blockNum  = repeat or block number 
% stimLoc   = location of the stimulus 1,2,3
% ledOn     = if the LED was on
%
% TODO: make function that takes exp as argument
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
%% Initalize
forceClear = 1;
if forceClear
    fprintf('Clearing workspace\n')
    close all force; 
    clear all force;
end

% General Flags
verbose     = 1;

%% Retrieve file locations / load data
animalName  = 'K71';
expDateNum  = '20140808_01';

% Retrieve folder location
dataDir     = getExpDataSource('macbook');
expDir      = fullfile(dataDir,animalName,expDateNum);
if verbose; fprintf('expDir: %s\n',expDir); end

% Load nidaq mat file
nidaqFileName = dir(fullfile(expDir,['nidaq_*.mat']));
nidaqFilePath = fullfile(expDir,nidaqFileName.name);
if verbose; fprintf('\tLoading daq file: %s\n',nidaqFileName(1).name); end
% loads in 'exp' struct
load(nidaqFilePath);


% Channel names should be stored in exp.daqInNames for verification
if ~exist('daqIndIds','var')
    daqIndId.LED = 1;
    daqIndId.PTB = 2;
end 

% There are 6 unique conditions 3 unique locations and 3 reps at each loc
nStimTypes = 6;
nStimLocs = 3;
nStimReps = 3;

%% Determine stimulus timeseries information
fprintf('\tProcessing DAQ Data\n');

% LED is constant on or off
ledOn = exp.Data(daqIndId.LED,:) > 3.5;
% Only the onsets of the frames are sent out to the nidaq 
ptbVals     = round(exp.Data(daqIndId.PTB,:));
ptbLog      = (exp.Data(daqIndId.PTB,:)) > 0.5;
timeBnStim  = 1.5/exp.daqRate^-1;

% Preallocate
stimLoc = zeros(numel(ptbVals),1);
stimType = zeros(numel(ptbVals),1);

indsLeft    = 0;
currStimLoc = 0;
currStimType= 0;

for currInd = 1:numel(ptbVals)
    if ptbLog(currInd) ~= 0 && indsLeft == 0
        currStimLoc = max(ptbVals(currInd:currInd+timeBnStim/4));
        currStimType = currStimLoc + nStimLocs*max(ledOn(currInd:currInd+timeBnStim/4));
        indsLeft = timeBnStim;
    end
    stimLoc(currInd) = currStimLoc;
    stimType(currInd) = currStimType;
    if indsLeft > 0
        indsLeft = (indsLeft - 1);
    end 
end

% Figure out if something went wrong during voltage encoding (extra stimLoc is 0)
if numel(unique(stimLoc)) > nStimLocs+1
    warning('Detected larger number of stimulus types than expected')
end

% Determine the repetition number and block for all
% stimulus presentations
blockNum    = zeros(numel(exp.Count),1);
currSet     = zeros(nStimTypes,1);
currBlock   = 1;
currStimType= 0; 
for currInd = 1:numel(stimType)
    if stimType(currInd) ~= currStimType
        currStimType = stimType(currInd);
        % Get the current type, if it has happened
        % go to the next block and reset values
        if currSet(currStimType) == 1;
            currBlock = currBlock + 1;
            currSet = [1; zeros(nStimTypes-1,1)];
        else
            currSet(currStimType) = 1;
        end
     end
     blockNum(currInd) = currBlock;
end

%% Establish the daq inds for each rep / stimtype


