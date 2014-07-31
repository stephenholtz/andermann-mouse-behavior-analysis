% processMouseDprimeProgress.m
%
% Get a mouse's dprime and plot it over time
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
verbose = 1;
saveFigs = 1;

%% Specify animal/experiment/data location
animalName  = 'RS2';
switch animalName
    case {'K69'}
        expDateNums  = {'20140724_01',...
                        '20140724_02',...
                        '20140725_01',...
                        '20140728_01',...
                        '20140729_01',...
                        '20140730_01'};
    case {'RS2'}
        expDateNums  = {'20140724_01',...
                        '20140724_02',...
                        '20140725_01',...
                        '20140728_01',...
                        '20140729_01',...
                        '20140730_01'};
    case {'K57'}
    otherwise
        error(['animalName ' animalName ' not found'])
end
dataDir     = getExpDataSource('local');

% Default bhv.TrialError meanings
t.reward_lick       = [0];
t.reward_nolick     = [1];
t.neutral_lick      = [3];
t.neutral_nolick    = [2];
t.punish_lick       = [5];
t.punish_nolick     = [4];

%% Load in the bhv files sequentially
dPtotal   = ones(1,numel(expDateNums));
dPneutral = ones(1,numel(expDateNums));
dPpunish  = ones(1,numel(expDateNums));
quartersToUse = [2 3 4];
for iExp = 1:numel(expDateNums)
    expDir = fullfile(dataDir,animalName,expDateNums{iExp});
    bhvFileName = dir(fullfile(expDir,'*.bhv'));
    bhvFilePath = fullfile(expDir,bhvFileName.name);
    if verbose; fprintf('\tLoading bhv file: %s\n',bhvFileName.name); end
    bhvData{iExp} = bhv_read(bhvFilePath);
    [dPtotal(iExp),dPneutral(iExp),dPpunish(iExp)] = getBhvDprime(bhvData{iExp},t,quartersToUse);
end

%% Generate Plots

% A very simple dprime over days
doSimpleDprime = 1;
if doSimpleDprime
    figSaveDir = fullfile(dataDir,'summary-figures',animalName);
    figName = ['DPrime-' animalName '-' expDateNums{1} '-to-' expDateNums{end}]; 
    figure('Color',[1 1 1],'Position',[20 20 600 400]);
    bar([dPtotal;dPneutral;dPpunish]');
    hold
    box off
    set(gca,'Xtick',1:numel(dPtotal));
    lH = legend('D'' Total','D'' Neutral','D'' Punish');
    lH.Location = 'NorthWest';
    title({'D'' Over experimental days',[animalName ' ' expDateNums{1} ' to ' expDateNums{end}]},'interpreter','none');
    ylabel('D''')
    xlabel('Day #')

    if saveFigs
        if ~exist(figSaveDir,'dir')
            mkdir(figSaveDir)
        end
        export_fig(fullfile(figSaveDir,[figName '.pdf']))
    end
end

