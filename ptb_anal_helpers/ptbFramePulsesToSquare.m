function [stimOnOff,stimOnsets,stimOffsets] = ptbFramePulsesToSquare(ptbTs,daqRate,isiSeconds)
%function [stimOnOff,stimOnsets,stimOffsets] = ptbFramePulsesToSquare(PsychToolboxOutput,DaqSampleRate,interStimIntervalSeconds)
%
% The offset ind is the time of last frame starting, so isn't actual stimoff time (need photodiode for that)
%
% Return visual stimulus onsets offsets and logical based on a minimum inter stimulus intervial.
% This has some complexity b/c PsychToolbox in this experiment setns a signal every frame sent, and is 
% not continuous.
%
% SLH 2014

% All voltage encoded values are >= 1
ptbLog      = (ptbTs) > 0.5;
frameOnsets = diff([ptbLog(1), ptbLog]) > 0;
timeBnStim  = isiSeconds/daqRate^-1;

onsetInds = [find(frameOnsets(1)), find(frameOnsets)];
stimOnsetInds = onsetInds(diff([onsetInds(1), onsetInds]) > timeBnStim);
% diff will miss the first onset, so prepend it
stimOnsetInds = [find(frameOnsets,1,'first') stimOnsetInds];

% Make output
stimOnsets  = zeros(numel(ptbTs),1);
stimOnsets(stimOnsetInds) = 1;

% Get offsets with flip applied at beginning and end
frameOffsets = diff([ptbLog(end), flip(ptbLog)]) > 0;
offsetInds = [find(frameOffsets(1)) find(frameOffsets)];
stimOffsetInds = offsetInds(diff([offsetInds(1), offsetInds]) > timeBnStim);
% Append the skipped diff
stimOffsetInds = [find(frameOffsets,1,'first') stimOffsetInds];

% Make output
stimOffsets  = zeros(numel(ptbTs),1);
stimOffsets(stimOffsetInds) = 1;
stimOffsets = flip(stimOffsets);
stimOffsetInds = [find(stimOffsets(1)) find(stimOffsets)];

% Make a square wave type output for visualization 
stimOnOff = zeros(numel(ptbTs),1);
for iStim = 1:numel(stimOnsetInds) 
    stimOnOff(stimOnsetInds(iStim):stimOffsetInds(iStim)) = 1;
end
