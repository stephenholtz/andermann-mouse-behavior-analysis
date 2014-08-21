function [stimCell,ledCell,stimTypeInds,blockNumInds] = makeStimTypeStruct( stimOnsets,stimDur,...
                                                                            ledOn,ledPreStimDur,ledPostStimDur,...
                                                                            daqRate,...
                                                                            stimOrder,nBlockRepeats,stimsPerBlock)
% Make a stimulus type, repetition, block organized output for easy indexing
if ~exist('nBlockRepeats','var')
    nBlockRepeats = 1;
end
if ~exist('stimsPerBlock','var')
    stimsPerBlock = 1;
end

% Hard coded for now TODO: fix logic
nStimsPerRep = 3;

% Determine number unique stimulus types
nStimTypes = numel(unique(stimOrder));

% Conditions with led onset to detect
ledStimConds = [4 5 6];

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
preLedLookAround = (ledPreStimDur)*daqRate*(1.25);
postLedLookAround = (ledPostStimDur+stimDur)*daqRate*(1.25);

% Number of whole block repeats
for iBlock = 1:nBlockRepeats
    % Number of stimuli in each block
    for iStim = 1:nStimTypes
        for iRep = 1:nStimsPerRep
            currStim = stimOrder(currInd);
            stimCell{iBlock,iStim,iRep} = onsetInds(currInd);

            % Figure out when the LED goes on and off for appropriate conditions
            if sum(currStim == ledStimConds)

                % Detect onset
                preLedInds = ((onsetInds(currInd)-preLedLookAround):(onsetInds(currInd)+preLedLookAround));
                preLed = ledOn(preLedInds);
                ledOnInd = find(diff([preLed(1) preLed])>0);
                if numel(ledOnInd) > 1
                    error('More than one LED onset found')
                elseif numel(ledOnInd) == 0
                    error('No LED onset found')
                end
                ilOn = preLedInds(ledOnInd(1));

                % Detect offset
                postLedInds = ((onsetInds(currInd)):(onsetInds(currInd)+postLedLookAround));
                postLed = ledOn(postLedInds);
                ledOffInd = find(diff([postLed(1) postLed])<0);
                if numel(ledOffInd) > 1
                    error('More than one LED offset found')
                elseif numel(ledOffInd) == 0
                    error('No LED offset found')
                end
                ilOff = postLedInds(ledOffInd(1)) - 1;

            else
                ilOn = 0;
                ilOff = 0;
            end

            ledCell{iBlock,iStim,iRep} = [ilOn,ilOff];
            currInd = currInd + 1;
        end
    end
end

