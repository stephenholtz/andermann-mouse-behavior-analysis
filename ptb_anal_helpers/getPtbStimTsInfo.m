function out = getPtbStimTsInfo(sOn,lOn,si)
% Function that gets timing information for each stimulus, very specific and unflexible for psych toolbox experiments!!
%
% note that this will totally break if some of the LED outputs don't work or if a single stimulus isn't presented
%
% stimulusOn = on and off stimulus
% ledOn      = led on and off
% Other input is what the ptb script spits out 'stim'
%
% Returns daq inds with:
%   out(Block,Stim,Rep).ptb = [on off]
%   out(Block,Stim,Rep).led = [on off]
%
% SLH 2014

%% Stimulus information from input
% This isn't a field in some experiments, so generate now hackishly
if ~isfield(si,'stimOrder')
    % Numbers all conditions with unique values
    si.stimOrder = zeros(numel(si.stimLocOrder)*si.nRepeats,1);
    for iStim = 1:numel(si.stimOrder)
        stimInd = 1+mod(iStim-1,numel(si.stimLocOrder));
        si.stimOrder(iStim) = si.stimLocOrder(stimInd) + numel(unique(si.stimLocOrder))*si.ledOnOffOrder(stimInd);
    end
end

% Determine number unique stimulus types and repeats (not in the struct)
nStimTypes   = numel(unique(si.stimOrder));
nRepsPerStim = length(si.stimLocOrder)/nStimTypes;
nStimsPerBlock = numel(si.stimLocOrder);

%% Find the stimulus onset and offset inds for all
sOnInds  = find(diff([sOn(1); sOn(:)])>0);
sOffInds = find(diff([sOn(1); sOn(:)])<0);
lOnInds  = find(diff([lOn(1); lOn(:)])>0);
lOffInds = find(diff([lOn(1); lOn(:)])<0);

% Source of many headaches, catch the error here so later stim ind lookup works perfectly
if numel(sOnInds) ~= numel(si.stimOrder)
    error('Something wrong with stimulus detection or with figuring out which were presented. Check daq trace and output of getPtbStimTsInfo')
end

block = 1;
rep = 1;
ledIter = 1;

% In order, assign each stimulus its onset and offset and led on/off if it has one
for i = 1:numel(si.stimOrder)
    % get stimulus number
    stim = si.stimOrder(i);
    % Wrap the rep num
    rep = mod(i,nRepsPerStim) + (~mod(i,nRepsPerStim) * nRepsPerStim);

    out(block,stim,rep).ptb = [sOnInds(i) sOffInds(i)];

    % if it is an led stimulus then get the led ind and save diff
    ledInd = mod(i,nStimsPerBlock) + (~mod(i,nStimsPerBlock)*nStimsPerBlock);
    if si.ledOnOffOrder(ledInd) == 1
        out(block,stim,rep).led = [lOnInds(ledIter) lOffInds(ledIter)];
        ledPreDiff(ledIter) = lOnInds(ledIter) - sOnInds(i);
        ledPostDiff(ledIter) = lOffInds(ledIter) - sOffInds(i) ;
        ledIter = ledIter+ 1;
    end
    % Update block num
    if ~mod(i,numel(si.stimLocOrder))
        block = block + 1;
    end
end

% Fill in rest with averages for calculations
avgPreLed = round(median(ledPreDiff));
avgPostLed = round(median(ledPostDiff));
for i = 1:numel(out)
    if isempty(out(i).led)
        out(i).led = [avgPreLed+out(i).ptb(1) avgPostLed+out(i).ptb(2)];
    end
end
