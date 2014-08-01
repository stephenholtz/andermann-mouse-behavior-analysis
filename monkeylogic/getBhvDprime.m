function [dPrimeTotal,dPrimeNeutral,dPrimePunish] = getBhvDprime(bhvData,trialErrorVals,quartersToUse)
% From Rohan's dprime function 
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
trialErrs = bhvData.TrialError;
if exist('quartersToUse','var')
    quarterSize = floor(numel(trialErrs)/4);
    tE = [];
    if sum(quartersToUse == 1)
        tE = [tE trialErrs(1:(quarterSize-1))];        
    end
    if sum(quartersToUse == 2)
        tE = [tE; trialErrs((quarterSize*1):((quarterSize*2)-1))];
    end
    if sum(quartersToUse == 3)
        tE = [tE; trialErrs((quarterSize*2):(quarterSize*3)-1)]; 
    end
    if sum(quartersToUse == 4)
        tE = [tE; trialErrs(quarterSize*3:end)]; 
    end
    trialErrs = tE;
end

t = trialErrorVals;
% Default values:
% t.reward_lick       = [0];
% t.reward_nolick     = [1];
% t.neutral_lick      = [3];
% t.neutral_nolick    = [2];
% t.punish_lick       = [5];
% t.punish_nolick     = [4];

% Get fraction of hits, false alarms, misses...
fracRewardLick  = (sum(trialErrs == t.reward_lick)  ...
    / sum(trialErrs == t.reward_nolick | trialErrs == t.reward_lick));
fracNeutralLick = (sum(trialErrs == t.neutral_lick) ...
    / sum(trialErrs == t.neutral_nolick | trialErrs == t.neutral_lick));
fracPunishLick  = (sum(trialErrs == t.punish_lick)  ...
    / sum(trialErrs == t.punish_nolick | trialErrs == t.punish_lick));

% Replace nans with zeros
fracRewardLick(isnan(fracRewardLick))   = 0;
fracNeutralLick(isnan(fracNeutralLick)) = 0;
fracPunishLick(isnan(fracPunishLick))   = 0;

dPrimeTotal     = fracRewardLick - (0.5*fracNeutralLick) - (0.5*fracPunishLick);
dPrimeNeutral   = fracRewardLick - fracNeutralLick;
dPrimePunish    = fracRewardLick - fracPunishLick;
