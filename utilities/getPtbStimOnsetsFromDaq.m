function [stimOnsets,stimOffsets,stimOnOff] = getPtbStimTimingFromDaq(ptbTs,daqRate,interStimIntervalSeconds)
%function stimOnsets = getPtbStimOnsetsFromDaq(ptbTs,daqRate,interStimIntervalSeconds)
%
% Return visual stimulus onsets offsets based on a minimum inter stimulus intervial.
% complexity b/c PsychToolbox has signal every frame sent, is not continuous 
%
% SLH 2014

% All voltage encoded values are >= 1
ptbLog      = (ptbTs) > 0.5;
frameOnsets = diff([ptbLog(1), ptbLog]) > 0;
timeBnStim  = interStimIntervalSeconds/daqRate^-1;

onsetInds = [find(frameOnsets(1)), find(frameOnsets)];
stimOnsetInds = onsetInds(diff([onsetInds(1), onsetInds]) > timeBnStim);
% diff will miss the first onset, so prepend it
stimOnsetInds = [find(frameOnsets,1,'first') stimOnsetInds];

stimOnsets  = zeros(numel(ptbTs),1);
stimOnsets(stimOnsetInds) = 1;

% Get offsets with fliplr
offsetInds = [find(frameOnsets(end)) find(fliplr(frameOnsets))];
stimOffsetInds = offsetInds(diff([offsetInds(1), offsetInds]) > timeBnStim);
% diff will miss the first onset, so prepend it
stimOffsetInds = [find(frameOnsets,1,'last') stimOffsetInds];

stimOffsets  = zeros(numel(ptbTs),1);
stimOffsets(stimOffsetInds) = 1;

% 
stimOnOff = zeros(numel(ptbTs),1);
for iStim = 1:numel(stimOnsetInds) 
    stimOnOff(stimOnsetIns(iStim):stimOffsetInds(iStim)) = 1;
end
