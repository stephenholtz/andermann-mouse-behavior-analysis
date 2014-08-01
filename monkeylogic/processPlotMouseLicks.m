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
forceClear = 0;
if forceClear
    close all force; 
    clear all force;
end

verbose = 1;
saveFigs = 1;

%% Specify animal/experiment/data location
animalName  = 'K69';
switch animalName
    case {'K69'}
        expDateNums  = {'20140724_02',...
                        '20140725_01',...
                        '20140728_01',...
                        '20140729_01',...
                        '20140730_01'};
    case {'RS2'}
        expDateNums  = {'20140724_02',...
                        '20140725_01',...
                        '20140728_01',...
                        '20140729_01',...
                        '20140730_01'};
    case {'K57'}
    otherwise
        error(['animalName ' animalName ' not found'])
end
dataDir = getExpDataSource('local');

for edn = expDateNums
    expDateNum = edn{1};
    clear edn
    close all force

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

    % anonymous funcs for later use
    binCount = @(vec,factor)(sum(reshape(vec,size(vec,1),floor(size(vec,2)/factor),[]),3));
    relFreq     = @(mat)(sum(mat,1)/sum(sum(mat)));

    % set experimental and data parameters for importTrialLicks.m
    pS.secsBefore  = 2;
    pS.secsDuring  = 2;
    pS.secsAfter   = 3;

    % Get the lick rasters back
    [licks,stim,breaks] = importTrialLicks(exp,bhvData,pS);

%% Make lick frequency plots
    makeLickFrequencyPlot = 0;
    if makeLickFrequencyPlot
        fprintf('makeLickFrequencyPlot\n')
        binSize = 250;
        binFactor = (binSize/1000)*exp.daqRate;
        pavLickFreq = relFreq(binCount(licks.pavlovian,binFactor));
        cRLickFreq = relFreq(binCount(licks.condReward,binFactor));
        timeVec = 0:(binFactor/exp.daqRate):((size(licks.pavlovian,2)/exp.daqRate)-(binFactor/exp.daqRate));

        figSaveDir = fullfile(dataDir,'summary-figures',animalName);
        figName = ['Licks-' num2str(binSize) 'ms-bins-' animalName '-' expDateNum]; 

        figure('Color',[1 1 1],'Position',[20 20 600 400]);
        plot(timeVec,pavLickFreq,'linewidth',2);
        hold
        box off
        plot(timeVec,cRLickFreq,'linewidth',2);
        plot([pS.secsBefore pS.secsBefore],[ylim],'linewidth',2,'Color','k','linestyle','--')
        plot([pS.secsBefore+pS.secsDuring pS.secsBefore+pS.secsDuring],[ylim],'linewidth',2,'Color','k','linestyle','--')
        lH = legend('Pavlovian','Conditional Reward','Stim On/Off');
        lH.Location = 'NorthWest';
        title({[animalName ' ' expDateNum ' - ' num2str(binSize) 'ms binned licks'],'Pavlovian / Conditional Reward'},'interpreter','none');
        ylabel('Freq. Binned Licks')
        xlabel('Time (s)')

        if saveFigs
            if ~exist(figSaveDir,'dir')
                mkdir(figSaveDir)
            end
            export_fig(fullfile(figSaveDir,[figName '.pdf']))
        end
    end

%% Make beam break plots
    makeBreakFreqPlot = 1;
    if makeBreakFreqPlot
        fprintf('makeBreakFreqPlot\n')
        binSize = 250;
        binFactor = (binSize/1000)*exp.daqRate;
        pavLickFreq = relFreq(binCount(breaks.pavlovian,binFactor));
        cRLickFreq = relFreq(binCount(breaks.condReward,binFactor));
        timeVec = 0:(binFactor/exp.daqRate):((size(breaks.pavlovian,2)/exp.daqRate)-(binFactor/exp.daqRate));

        figSaveDir = fullfile(dataDir,'summary-figures',animalName);
        figName = ['BeamBreakFreq-' num2str(binSize) 'ms-bins-' animalName '-' expDateNum]; 

        figure('Color',[1 1 1],'Position',[20 20 600 400]);
        plot(timeVec,pavLickFreq,'linewidth',2);
        hold
        box off
        plot(timeVec,cRLickFreq,'linewidth',2);
        plot([pS.secsBefore pS.secsBefore],[ylim],'linewidth',2,'Color','k','linestyle','--')
        plot([pS.secsBefore+pS.secsDuring pS.secsBefore+pS.secsDuring],[ylim],'linewidth',2,'Color','k','linestyle','--')
        lH = legend('Pavlovian','Conditional Reward','Stim On/Off');
        lH.Location = 'NorthWest';
        title({[animalName ' ' expDateNum ' - ' num2str(binSize) 'ms binned beam breaks'],'Pavlovian / Conditional Reward'},'interpreter','none');
        ylabel('Freq. Binned Beam Breaks')
        xlabel('Time (s)')

        if saveFigs
            if ~exist(figSaveDir,'dir')
                mkdir(figSaveDir)
            end
            export_fig(fullfile(figSaveDir,[figName '.pdf']))
        end
    end
%% Make lick raster plot
    makeLickRasterPlot = 0;
    if makeLickRasterPlot
        fprintf('makeLickRasterPlot\n')

        % For adding lines to the images a silly way
        myBwColormap = [1 1 1; 0 0 0; 0.1801 0.7177 0.6424];

        binSize = 25; % 1ms
        binFactor = (binSize/1000)*exp.daqRate;    
        
        timeVec = 0:(binFactor/exp.daqRate):((size(licks.pavlovian,2)/exp.daqRate)-(binFactor/exp.daqRate));

        % Light binning for visualization
        pavLickRast     = binCount(licks.pavlovian,binFactor)>0; 
        condLickRewRast = binCount(licks.condReward,binFactor)>0; 
        blankLickRast   = binCount(licks.blank,binFactor)>0;

        % Extend the ticks down so they are easier to see
        pavLickRast     = (pavLickRast | circshift(pavLickRast,-1))+0;
        condLickRewRast = (condLickRewRast | circshift(condLickRewRast,-1))+0;
        blankLickRast   = (blankLickRast | circshift(blankLickRast,-1))+0;

        % Draw lines on the images this way.... silly
        pavLickRast(:,[pS.secsBefore*(exp.daqRate/binFactor) (pS.secsBefore+pS.secsDuring)*(exp.daqRate/binFactor) ]) = 2; 
        condLickRewRast(:,[pS.secsBefore*(exp.daqRate/binFactor) (pS.secsBefore+pS.secsDuring)*(exp.daqRate/binFactor) ]) = 2; 
        blankLickRast(:,[pS.secsBefore*(exp.daqRate/binFactor) (pS.secsBefore+pS.secsDuring)*(exp.daqRate/binFactor) ]) = 2; 

        figName = ['LickRaster-' animalName '-' expDateNum]; 
        fH = figure('Color',[1 1 1],'Position',[20 20 600 400]);

        subplot(3,1,1)
        imagesc(pavLickRast)
        set(gca,'Xticklabel','') 
        box off
        title({[animalName ' ' expDateNum],'Conditional Reward'},'interpreter','none')
        
        subplot(3,1,2)
        imagesc(condLickRewRast)
        set(gca,'Xticklabel','') 
        box off
        title('Pavlovian')

        subplot(3,1,3)
        imagesc(blankLickRast)
        unitsPerSec = 1/(binFactor/exp.daqRate);
        set(gca,'XTick',0:unitsPerSec:(unitsPerSec*(pS.secsBefore+pS.secsDuring+pS.secsAfter)));
        set(gca,'XtickLabel',get(gca,'XTick')/unitsPerSec) 
        box off
        title('Blank')
        ylabel('Trial #')
        xlabel('Time (s)')

        % Has 3 colors, blank, ticks, and division lines
        colormap(myBwColormap)

        if saveFigs
            if ~exist(figSaveDir,'dir')
                mkdir(figSaveDir)
            end
            export_fig(fullfile(figSaveDir,[figName '.pdf']))
        end
    end
end
