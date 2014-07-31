function [licks,stim] = importTrialLicks(exp,bhvData,parameterStruct)
% importTrialLicks.m
%
% licks has fields for plotting lick behavior wrt stimulus type 
% some light processing on the raw data
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
logLicks    = exp.Data(daqChan.lick,:) > analogThresh;
% Throw away all but the lick onsets
logLicks = [0 (diff(logLicks) > 0)];

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
lickPavlovian       = [];
lickCondReward      = [];
lickBlank           = [];
lickCondPunish      = [];
lickNeutral         = [];
lickLedPavlovian    = [];
lickLedCondReward   = [];
lickLedBlank        = [];
lickLedCondPunish   = [];
lickLedNeutral      = [];
stimOn              = [];
for iTrial = 1:numTrials
    currCond = bhvData.ConditionNumber(iTrial); 
    currWind = (strobeInds(stimOnsetInds(iTrial))-(secsBefore*exp.daqRate)):(((secsDuring+secsAfter)*exp.daqRate)+strobeInds(stimOnsetInds(iTrial))-1);
    currWind(currWind < 1) = 1;
    switch currCond
        case 1 % Pavlovian
            lickPavlovian = [lickPavlovian; logLicks(currWind)];
        case 2 % Cond reward
            lickCondReward = [lickCondReward; logLicks(currWind)];
         case 3 % Blank
            lickBlank = [lickBlank; logLicks(currWind)];
        case 4 % Cond Punish
            lickCondPunish = [lickCondPunish; logLicks(currWind)];
        case 5 % Neutral
            lickNeutral = [lickNeutral; logLicks(currWind)];
        case 6 % LED + Pavlovian
            lickLedPavlovian = [lickLedPavlovian; logLicks(currWind)];
        case 7 % LED + Cond reward
            lickLedCondReward = [lickLedCondReward; logLicks(currWind)];
        case 8 % LED + Blank
            lickLedBlank = [lickLedBlank; logLicks(currWind)];
        case 9 % LED + Cond punish
            lickLedCondPunish = [lickLedCondPunish; logLicks(currWind)];
        case 10 % LED + Neutral
            lickLedNeutral = [lickLedNeutral; logLicks(currWind)];
     end
     stimOn = [stimOn; strobeLog(currWind)]; 
end
clear currCond iTrial currCond currWind nextRow

licks.pavlovian     = lickPavlovian;
licks.condReward    = lickCondReward;
licks.blank         = lickBlank;
licks.condPunish    = lickCondPunish;
licks.neutral       = lickNeutral;
licks.ledPavlovian  = lickLedPavlovian;
licks.ledCondReward = lickLedCondReward;
licks.ledBlank      = lickLedBlank;
licks.ledCondPunish = lickLedCondPunish;
licks.ledNeutral    = lickLedNeutral;
stim.on             = stimOn;
