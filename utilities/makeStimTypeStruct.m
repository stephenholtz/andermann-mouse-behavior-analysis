function [stimCell,stimTypeInds,blockNumInds] = makeStimTypeStruct(stimOnsets,stimOrder,nBlockRepeats,stimsPerBlock)
%function [stimCell,stimTypeInds] = makeStimTypeStruct(stimOnsets,stimOrder,nBlockRepeats)
% Make a stimulus type, repetition, block organized output for easy indexing
if ~exist('nBlockRepeats','var')
    nBlockRepeats = 1;
end
if ~exist('stimsPerBlock','var')
    stimsPerBlock = 1;
end

% Determine number unique stimulus types
nStimTypes = numel(unique(stimOrder));

% Generate outputs
stimTypeInds = zeros(numel(stimOnsets),1);
blockNumInds = zeros(numel(stimOnsets),1);
currBlock = 1;
onsetInds = find(stimOnsets);

% Loop through onsets and assign a stimulus to data blocks
for i = 1:numel(onsetInds)-1
   stimTypeInds(onsetInds(i):onsetInds(i+1)) = stimOrder(i);
   blockNumInds(onsetInds(i):onsetInds(i+1)) = currBlock;
   if ~mod(i,stimsPerBlock)
        currBlock = currBlock + 1;
   end
end

% Make organized output cell array
currInd = 1;
% Number of whole block repeats
for iBlock = 1:nBlockRepeats
    % Number of stimuli in each block
    for iStim = 1:nStimTypes
        % Hard coded for now TODO: fix logic
        for iRep = 1:3
            currStim = stimOrder(currInd);
            stimCell{iBlock,iStim,iRep} = onsetInds(currInd);
            currInd = currInd + 1;
        end
    end
end

