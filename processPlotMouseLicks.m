% processPlotMouseLicks.m
%
% Script to process data from a set of experiemnts using importTrialLicks
%
% All relevant files for each experiment are in the same 
% directory. Original stimuli presented and scripts controlling
% stimulus timing and presentation are not.
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>
verbose = 1;
saveFigs = 1;

%% Specify animal/experiment/data location
animalName  = 'K69';
expDateNum  = '20140728_01';
dataDir     = getExpDataSource('atlas');

%% Load in experimental data
expDir = fullfile(dataDir,animalName,expDateNum);
if verbose; fprintf('expDir: %s\n',expDir); end

% Load in BHV file (behavioral results + metadata) 
bhvFileName = dir(fullfile(expDir,'*.bhv'));
bhvFilePath = fullfile(expDir,bhvFileName.name);
if verbose; fprintf('\tLoading bhv file: %s\n',bhvFileName.name); end
bhvData = bhv_read(bhvFilePath);

% Load in .mat (nidaq + acquisition metadata)
matFileName = dir(fullfile(expDir,'*.mat'));
matFilePath = fullfile(expDir,matFileName.name);
if verbose; fprintf('\tLoading daq file: %s\n',matFileName.name); end
load(matFilePath); % loads in 'exp' struct
% Missing field (will add back in to files)
if ~isfield(exp,'daqRate'); exp.daqRate = 5E3; end

% experimental and data parameters for importTrialLicks.m
pS.verbose     = 1;
pS.secsBefore  = 1;
pS.secsDuring  = 2;
pS.secsAfter   = 3;

% Get the lick rasters back
licks = importTrialLicks(exp,bhvData,pS);

%% Make lick frequency plots
figSaveDir = fullfile(dataDir,'summary-figures',animalName);
figName = ['Licks-' animalName '-' expDateNum]; 
figure('Color',[1 1 1],'Position',[20 20 600 400]);
timeVec = (1:size(licks.pavlovian,2))/exp.daqRate;
plot(timeVec,sum(licks.pavlovian));
hold
box off
plot(timeVec,sum(licks.condReward));
plot([pS.secsBefore pS.secsBefore],[ylim],'linewidth',2)
plot([pS.secsBefore+pS.secsDuring pS.secsBefore+pS.secsDuring],[ylim],'linewidth',2)
legend('Pavlovian','Conditional Reward','Stim On', 'Stim Off')
title('Lick Frequency: Pavlovian / Conditional');
ylabel('Licks')
xlabel('Time (s)')

if saveFigs
    if ~exist(figSaveDir,'dir')
        mkdir(figSaveDir)
    end
    export_fig(fullfile(figSaveDir,[figName '.pdf']))
end

%% Make lick raster plots
figName = ['Licks-' animalName '-' expDateNum]; 
fH = figure('Color',[1 1 1],'Position',[20 20 600 400]);
hold
box off
title('Lick Frequency: Pavlovian / Conditional');
ylabel('Licks')
xlabel('Time (s)')

if saveFigs
    if ~exist(figSaveDir,'dir')
        mkdir(figSaveDir)
    end
    export_fig(fullfile(figSaveDir,[figName '.pdf']))
end

