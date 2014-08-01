function [licks,stim,breaks] = importTrialLicks(exp,bhvData,parameterStruct)
% importTrialLicks.m
%
% Does light processing on raw data, returns logical of lick onsets (licks)
% stimulus (stim) and beam breaks (breaks). This function has gotten a bit out
% of hand. Perhaps restructure it later.
%
% TODO: remove fieldnames (look how many!) and return large matricies or 
% cell arrays instead
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

%% Parse the input parameterStruct
if isfield(parameterStruct,'daqChan')
    daqChan = parameterStruct.daqChan;
else
    % Channel names are also stored in the exp struct
    daqChan.lick        = 3;
    daqChan.reward      = 4;
    daqChan.punish      = 5;
    daqChan.codeStrobe  = 8;
    daqChan.codeBits    = [9 10 11 12 13];
end
if isfield(parameterStruct,'verbose')
    verbose = parameterStruct.verbose;
else
    verbose = 0;
end
if isfield(parameterStruct,'secsBefore')
    secsBefore = parameterStruct.secsBefore;
else
    secsBefore = 1;
end
if isfield(parameterStruct,'secsDuring')
    secsDuring = parameterStruct.secsDuring;
else
    secsDuring = 2;
end
if isfield(parameterStruct,'secsAfter')
    secsAfter = parameterStruct.secsAfter;
else
    secsAfter = 3;
end
clear parameterStruct

%% Begin processing
% Threshold analog channels (struct from nidaq acquisition = exp)
analogThresh = 4;

if verbose; fprintf('\tProcessing analog channels\n'); end
logBreaks    = exp.Data(daqChan.lick,:) > analogThresh;
% Throw away all but the lick onsets
logLickOnsets = [0 (diff(logBreaks) > 0)];

%logRewards  = exp.Data(daqChan.reward,:) > analogThresh;
%logPunish   = exp.Data(daqChan.punish,:) > analogThresh;
clear analogThresh

% Monkeylogic / specifics notes: 
%
% Default "codes" up to 32 from monkeylogic are captured with 5 bits
% lookup is in codes.txt (in my monkeylogic-running repo). Convert
% the bits acquired to the codes. 
%
% Default is to send 9 9 9 # 18 18 18 where # is the actual data 
% and 9/18 are failsafes for aligning. 
% Rohan uses 25 to be videos turning on and off and the bhv trial
% errors to indicate what the animal's trial result was (vs using
% the behavioral codes). This works well because it uses the 1's 
% bit only (probably should have just used this).
% 
% bhv struct has enough information to figure out what was going on
% more or less. Although some mysterious differences between codes
% and observed daq output occur, not just a shift register or false 
% bit. Replace 9->18, 25->6, 18->4
%
% Working version gives this output:
% trial onsets = 18 18 18 / trial offsets = 4 4 4
% stimulus onsets/offsets = 6 
% 12 also happens between 6's, no idea what it means
%
% TODO: place these notes somewhere better
if verbose; fprintf('\tImporting monkeylogic behavioral codes\n'); end
% Only look at the falling edge of the digital strobe
strobeLog = [exp.Data(daqChan.codeStrobe,1) diff(exp.Data(daqChan.codeStrobe,:)) == -1];
strobeInds = find(strobeLog);
codesMat = nan(numel(daqChan.codeBits),numel(strobeInds));
for iBit = 1:numel(daqChan.codeBits)
    codesMat(iBit,:) = exp.Data(daqChan.codeBits(iBit),strobeInds);
end
clear iBit
codesMat = flipud(codesMat');
codeVals = bin2dec(num2str(codesMat));

% Stimulus onsets
stimOnsetLog    = (codeVals == 6) | (codeVals == 12);
stimOnsetLog    = diff([stimOnsetLog(1); stimOnsetLog]) == 1;
stimOnsetInds   = find(stimOnsetLog);
% Trial onsets (unneeded)
trialOnsetLog   = (codeVals == 18);
trialOnsetLog   = diff([trialOnsetLog(1); trialOnsetLog]) == -1;
% Trial offsets (unneeded)
trialOffsetLog  = (codeVals == 4);
trialOffsetLog  = diff([trialOffsetLog(1); trialOffsetLog]) == 1;

if numel(bhvData.TrialNumber) ~= sum(trialOnsetLog)
   warning('Trial number in monkeylogic bhv file does not agree with number of detected trial onsets') 
end
numTrials = sum(trialOnsetLog);

% Gather data for a quick plot of animal licks to various stimuli

% 1 = pavlovian / 2 = conditional reward / 3 = blank 
% 4 = condition punish / 5 = neutral  / +5 for ChR2
stimOn                  = [];
logLickPavlovian        = [];    breaksPavlovian         = [];
logLickCondReward       = [];    breaksCondReward        = [];
logLickBlank            = [];    breaksBlank             = [];
logLickCondPunish       = [];    breaksCondPunish        = [];
logLickNeutral          = [];    breaksNeutral           = [];
logLickLedPavlovian     = [];    breaksLedPavlovian      = [];
logLickLedCondReward    = [];    breaksLedCondReward     = [];
logLickLedBlank         = [];    breaksLedBlank          = [];
logLickLedCondPunish    = [];    breaksLedCondPunish     = [];
logLickLedNeutral       = [];    breaksLedNeutral        = [];
logAllLicks             = [];    breaksAll               = [];

for iTrial = 1:numTrials
    currCond = bhvData.ConditionNumber(iTrial); 
    currWind = (strobeInds(stimOnsetInds(iTrial))-(secsBefore*exp.daqRate)):(((secsDuring+secsAfter)*exp.daqRate)+strobeInds(stimOnsetInds(iTrial))-1);
    currWind(currWind < 1) = 1;
    switch currCond
        case 1 % Pavlovian
            logLickPavlovian = [logLickPavlovian; logLickOnsets(currWind)];
            breaksPavlovian = [breaksPavlovian; logBreaks(currWind)];
        case 2 % Cond reward
            logLickCondReward = [logLickCondReward; logLickOnsets(currWind)];
            breaksCondReward = [breaksCondReward; logBreaks(currWind)];
         case 3 % Blank
            logLickBlank = [logLickBlank; logLickOnsets(currWind)];
            breaksBlank = [breaksBlank; logBreaks(currWind)];
        case 4 % Cond Punish
            logLickCondPunish = [logLickCondPunish; logLickOnsets(currWind)];
            breaksCondPunish = [breaksCondPunish; logBreaks(currWind)];
        case 5 % Neutral
            logLickNeutral = [logLickNeutral; logLickOnsets(currWind)];
            breaksNeutral = [breaksNeutral; logBreaks(currWind)];
        case 6 % LED + Pavlovian
            logLickLedPavlovian = [logLickLedPavlovian; logLickOnsets(currWind)];
            breaksLedPavlovian = [breaksLedPavlovian; logBreaks(currWind)];
        case 7 % LED + Cond reward
            logLickLedCondReward = [logLickLedCondReward; logLickOnsets(currWind)];
            breaksLedCondReward = [breaksLedCondReward; logBreaks(currWind)];
        case 8 % LED + Blank
            logLickLedBlank = [logLickLedBlank; logLickOnsets(currWind)];
            breaksLedBlank = [breaksLedBlank; logBreaks(currWind)];
        case 9 % LED + Cond punish
            logLickLedCondPunish = [logLickLedCondPunish; logLickOnsets(currWind)];
            breaksLedCondPunish = [breaksLedCondPunish; logBreaks(currWind)];
        case 10 % LED + Neutral
            logLickLedNeutral = [logLickLedNeutral; logLickOnsets(currWind)];
            breaksLedNeutral = [breaksLedNeutral; logBreaks(currWind)];
     end
     logAllLicks    = [logAllLicks; logLickOnsets(currWind)];
     breaksAll      = [breaksAll; logBreaks(currWind)];
     stimOn         = [stimOn; strobeLog(currWind)]; 
end
clear currCond iTrial currCond currWind nextRow

stim.on             = stimOn;

licks.pavlovian     = logLickPavlovian;
licks.condReward    = logLickCondReward;
licks.blank         = logLickBlank;
licks.condPunish    = logLickCondPunish;
licks.neutral       = logLickNeutral;
licks.ledPavlovian  = logLickLedPavlovian;
licks.ledCondReward = logLickLedCondReward;
licks.ledBlank      = logLickLedBlank;
licks.ledCondPunish = logLickLedCondPunish;
licks.ledNeutral    = logLickLedNeutral;
licks.all           = logAllLicks;

breaks.pavlovian     = breaksPavlovian;
breaks.condReward    = breaksCondReward;
breaks.blank         = breaksBlank;
breaks.condPunish    = breaksCondPunish;
breaks.neutral       = breaksNeutral;
breaks.ledPavlovian  = breaksLedPavlovian;
breaks.ledCondReward = breaksLedCondReward;
breaks.ledBlank      = breaksLedBlank;
breaks.ledCondPunish = breaksLedCondPunish;
breaks.ledNeutral    = breaksLedNeutral;
breaks.all           = breaksAll;
