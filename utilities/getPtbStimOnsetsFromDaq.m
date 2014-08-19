function [stimOnsets, stimOnsetInds] = getPtbStimOnsetsFromDaq(ptbTs,daqRate,interStimIntervalSeconds)
%function stimOnsets = getPtbStimOnsetsFromDaq(ptbTs,daqRate,interStimIntervalSeconds)
%
% Return visual stimulus onsets based on a minimum inter stimulus intervial.
% complexity b/c PsychToolbox has signal every frame sent, then returns to 0
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

% Make other output
stimOnsets  = zeros(numel(ptbTs),1);
stimOnsets(stimOnsetInds) = 1;
