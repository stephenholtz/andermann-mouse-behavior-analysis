%% plotEpiDff.m
% Plot the epi signal in a few ways...
%
% SLH

%% Specify animal/experiment/data location
animalName        = 'K51';
expDateNum        = '20140830_02';
justLoadVariables = 0;
recalculateDs     = 1;
saveFigs          = 1;

doPlotTroubleshooting = 0;
doPlotLumpAllTraces = 0;
doPlotComparisonTraces = 0;
doPlotRepComparison = 1;
doPlotByBlock = 1;
%% Establish filepaths / load preprocessed variables
% Get the base location for data, see function for details
if ispc
    dataDir = getExpDataSource('atlas-pc');
elseif ismac
    dataDir = getExpDataSource('macbook');
end

% Experiment directory
expDir  = fullfile(dataDir,animalName,expDateNum);
% Processed data filepath
procDir = fullfile(expDir,'proc');
% raw data
rawDir = fullfile(expDir,'raw');
% figure saving
figDir = fullfile(expDir,'figs');
if ~exist(figDir,'dir')
    mkdir(figDir)
end
% Epi imaging tiff path
epiStackDir = fullfile(procDir,'epiStacks');
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,'nidaq_*.mat'));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);
if ~exist('daq','var')
    load(nidaqFilePath)
end

%-------------------------------------------------------------
% Load processed variables                      % Struct name:
%-------------------------------------------------------------
if ~exist('faceMotion','var')
    load(fullfile(procDir,'faceMotion.mat'));   % faceMotion
end
if ~exist('frameNums','var')
    load(fullfile(procDir,'frameNums.mat'));    % frameNums
end
if ~exist('stimTsInfo','var')
    load(fullfile(procDir,'stimTsInfo.mat'));   % stimTsInfo
end
if ~exist('roi','var')
    load(fullfile(procDir,'epiROIs.mat'));      % roi
end
if ~exist('epiStack','var')
    load(fullfile(procDir,'epiStack.mat'));     % epiStack
end
if ~exist('epiStackMean','var')
    load(fullfile(procDir,'epiStackMean.mat')); % epiStackMean
end
if ~exist('epiTrace','var')
    load(fullfile(procDir,'epiTrace.mat'));     % epiTrace
end
% Clean up variable names to make hacking easier
clear dataDir epiTiffPath expDir nidaqFileName nidaqFilePath rawDir procDir

if justLoadVariables
    disp('BREAK!')
    break
end

%% Group the DFFs for averaging within stimulus types
HARD_CODED_STOP = 63; % Something wrong with alignment, unsure of where super long trials are coming from??
traceTypes = {'dff'};
[nBlocks,nStims,nReps] = size(stimTsInfo.all);

if ~exist('dS','var') || recalculateDs
    clear dS

    % average the full blocks (and also therefore) average each rep of a stimuli across blocks
    blockStimInd = 1;
    for iS = 1:nStims
        for iR = 1:nReps
            iRow = 1;
            for iB = 1:nBlocks
                % All dff have the same number of frames AFTER the LED
                % align them so that they all end together, using flip (later unflip)
                tmpFlip = flip(epiTrace(iB,iS,iR).dff);

                % Store a trace for every stim in a block to then average over
                % for looking at adaptation (e.g. subsequent reps)
                dS.fullBlocks(blockStimInd).dff(iRow,1:numel(tmpFlip)) = tmpFlip;
                iRow = iRow + 1;
            end
            dS.fullBlocks(blockStimInd).dff = fliplr(dS.fullBlocks(blockStimInd).dff(:,1:HARD_CODED_STOP));
            blockStimInd = blockStimInd + 1;
        end
        % 'Unflip' the data so that the ends are aligned, it adds, but only at 
        % the beginning so not a huge problem
        clear tmpFlip
    end

    % Average in logical sets for quick comparison
    for stimSet = 1:10
        switch stimSet
            case 1
                stimsToUse = 1:6;
                setName = 'allStimuli';
            case 2
                stimsToUse = [1 2 4 5];
                setName = 'allVisStimuli';     
            case 3
                stimsToUse = 3;
                setName = 'blankNoLed';        
            case 4
                stimsToUse = 6;
                setName = 'blankWithLed';
            case 5
                stimsToUse = [1 2];
                setName = 'visStimNoLed';        
            case 6
                stimsToUse = [4 5];
                setName = 'visStimWithLed';
            case 7
                stimsToUse = 1;
                setName = 'medialStimLedOff';
            case 8
                stimsToUse = 2;
                setName = 'lateralStimLedOff';
            case 9
                stimsToUse = 4;
                setName = 'medialStimLedOn';
            case 10 
                stimsToUse = 5;
                setName = 'lateralStimLedOn';
        end

        % Gather all traces
        for tT = traceTypes 
            traceType = tT{1};
            iRow = 1;
            for iS = stimsToUse
                for iB = 1:size(epiTrace,1) 
                    for iR = 1:numel(epiTrace(iB,iS,:))
                        % All dff have the same number of frames AFTER the LED
                        % align them so that they all end together, using flip (later unflip)
                        tmpFlip = flip(epiTrace(iB,iS,iR).(traceType));
                        dS.(setName).(traceType)(iRow,1:numel(tmpFlip)) = tmpFlip;
                        iRow = iRow + 1;
                    end
                end
            end
            % 'Unflip' the data so that the ends are aligned, it adds, but only at 
            % the beginning so not a huge problem
            dS.(setName).(traceType) = fliplr(dS.(setName).(traceType)(:,1:HARD_CODED_STOP));
        end
        clear tmpFlip
    end
end
% Clean up while still a script
clear tT iRow iS iR setName traceType stimsToUse

%----------------------------------------------------------------------
%% Plot troubleshooting things
% NOTE:probably doesn't help with anything in current form
fH = figure();
colorOrder = get(gca,'ColorOrder');
close(fH)
% number of aligned frames after LED turns off that *REALLY SHOULD BE* LED free 
nPostToUse = epiTrace(1).analFrames(2) - epiTrace(1).ledFrames(2) + 1;
nPreToUse = epiTrace(1).ledFrames(1) - epiTrace(1).analFrames(1);

tVec = (1:size(dS.allStimuli.dff,2))./frameNums.epiRate;
xPosLedOff = (numel(tVec) - nPostToUse);
xPosLedOn = (nPreToUse);

if doPlotTroubleshooting
    figure()
    plot(median(dS.blankNoLed.dff))
    plot([xPosLedOff xPosLedOff],ylim,'Color','g','linestyle','--','linewidth',2);

    title('Raw Signal wrt LED');
    ylabel('Median Intensity');
    xlabel('Frame');

    box off
    set(gca,'TickDir','out')

    % adjust axis manually
    %axis([0 70 -0.1 0.2])
    axis([0 4.5 -0.25 0.55])

    if saveFigs
        figSaveName = fullfile(figDir,['epi_raw_troubleshooting_1_' animalName]);
        export_fig(gcf,figSaveName,'-pdf',gcf)
    end 
end

%----------------------------------------------------------------------
%% Plot the combined stimulus responses
%----------------------------------------------------------------------
% Make plots of all responses and their averages
if doPlotLumpAllTraces  
    for axisType = 1:2
        yLabel = '\DeltaF/F0';
        xLabel = 'Time (s)';
        for stimSet = 1:8
            switch stimSet
                case 1
                    setName = 'allStimuli';
                    titleStr = ({'Across all conditions (inc blanks)'});
                case 2
                    setName = 'allVisStimuli';     
                    titleStr = ({'All visual conditions (no blanks)'});
                case 3
                    setName = 'blankNoLed';        
                    titleStr = ({'Blank conditions no LED'});
                case 4
                    setName = 'blankWithLed';
                    titleStr =({'Blank conditions with LED'});
                case 5
                    setName = 'visStimNoLed';        
                    titleStr =({'Visual conditions no LED'});
                case 6
                    setName = 'visStimWithLed';
                    titleStr =({'Visual conditions with LED'});
                case 7
                    setName = 'medialStimLedOff';
                    titleStr =({'Medial visual conditions'});
                case 8
                    setName = 'lateralStimLedOff';
                    titleStr =({'Lateral visual conditions'});
            end
            tVec = (1:size(dS.(setName).dff,2))./frameNums.epiRate;
            dVec = dS.(setName).dff;

            figure();

            plot(tVec,dVec');
            hold all
            plot(tVec,median(dVec),'Color','k','LineWidth',4);

            % Get the ylims right for plotting
            for ii = 1:2
                plot([tVec(xPosLedOn) tVec(xPosLedOn)],ylim,'Color','g','linestyle','--','linewidth',2);
                plot([tVec(xPosLedOff) tVec(xPosLedOff)],ylim,'Color','g','linestyle','--','linewidth',2);
            end

            box off
            set(gca,'TickDir','out')

            title(titleStr);
            ylabel(yLabel);
            xlabel(xLabel);

            % adjust axis manually
            if axisType == 1
                axis([0.075 4.15 -0.01 0.05])
                axisStr = 'full';
            elseif axisType == 2
                axis([2.5 4.3 -0.015 0.05])
                axisStr = 'zoom';
            end

            if saveFigs
                figSaveName = fullfile(figDir,['epi_' axisStr '_' setName '_' animalName '_' expDateNum]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end 
        end
    end
end

%----------------------------------------------------------------------
%% Plot comparisons of different conditions 
%----------------------------------------------------------------------
% Make plots of all responses and their averages
if doPlotComparisonTraces 
    yLabel = '\DeltaF/F0';
    xLabel = 'Time (s)';
    for axisType = 1:2
        for stimSet = 1:5
            switch stimSet
                case 1
                    setNames = {'visStimNoLed','blankNoLed'};
                    titleStr = ({'Visual versus Blank no LED stimulation'});
                case 2
                    setNames = {'visStimNoLed','visStimWithLed'};
                    titleStr = ({'Visual versus Blank with LED stimulation'});
                case 3
                    setNames = {'blankNoLed','blankWithLed'};
                    titleStr = ({'Blank conditions with/without LED'});
                case 4
                    setNames = {'visStimNoLed','visStimWithLed','blankNoLed','blankWithLed'};
                    titleStr = ({'All grouped conditions'});
                case 5
                    setNames = {'medialStimLedOff','lateralStimLedOff'};
                    titleStr = ({'Medial vs lateral visual conditions without LED'});
            end

            figure();
            clear eH
            tVec = (1:size(dS.(setNames{1}).dff,2))./frameNums.epiRate;
            for iSet = 1:numel(setNames)
                dVec = dS.(setNames{iSet}).dff;
                eVec = std(dVec)/sqrt(size(dVec,1));
                tH = shadedErrorBar(tVec,median(dVec),[eVec;eVec],{'Color',.9*colorOrder(iSet,:),'MarkerFaceColor',.9*colorOrder(iSet,:)},1);
                eH(iSet) = tH.mainLine;
                %plot(tVec,median(dVec),'LineWidth',2);
                hold all
            end
            plot([tVec(xPosLedOn) tVec(xPosLedOn)],ylim,'Color','k','linestyle','--','linewidth',2);
            eH(iSet+1) = plot([tVec(xPosLedOff) tVec(xPosLedOff)],ylim,'Color','k','linestyle','--','linewidth',2);
            
            % Set the legend up
            lh = legend(eH,setNames);
            box off
            set(gca,'TickDir','out')

            title(titleStr);
            ylabel(yLabel);
            xlabel(xLabel);

            % adjust axis manually
            if axisType == 1
                axis([0.075 4.15 -0.01 0.04])
                axisStr = 'full';
            elseif axisType == 2
                axis([2.5 4.3 -0.015 0.04])
                axisStr = 'zoom';
            end

            if saveFigs
                figSaveName = fullfile(figDir,['epi_comparison_' axisStr '_' [setNames{:}]]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end 
        end
    end
end

%% plot comparisons of different reps
if doPlotRepComparison
    yLabel = '\DeltaF/F0';
    xLabel = 'Time (s)';
    for axisType = 1:2
        for stimSet = 1:6
            switch stimSet
                case 1
                    setNames = {'medialLedOff'};
                    blockInds = 1:3;
                case 2
                    setNames = {'lateralLedOff'};
                    blockInds = 4:6;
                case 3
                    setNames = {'blankLedOff'};
                    blockInds = 7:9;
                case 4
                    setNames = {'medialLedOn'};
                    blockInds = 10:12;
                case 5
                    setNames = {'lateralLedOn'};
                    blockInds = 13:15;
                case 6
                    setNames = {'blankLedOn'};
                    blockInds = 16:18;
            end
            titleStr = ({['reps of ' setNames{1}]});
            
            figure();
            clear eH
            tVec = (1:size(dS.fullBlocks(blockInds(1)).dff,2))/frameNums.epiRate;
            for iRep = 1:numel(blockInds)
                dVec = dS.fullBlocks(blockInds(iRep)).dff;
                eVec = std(dVec)/sqrt(size(dVec,1));
                %tH = shadedErrorBar(tVec,median(dVec),[eVec;eVec],{'Color',.9*colorOrder(iSet,:),'MarkerFaceColor',.9*colorOrder(iSet,:)},1);
                %eH(iSet) = tH.mainLine;
                plot(tVec,median(dVec),'LineWidth',2);
                hold all
            end
            plot([tVec(xPosLedOn) tVec(xPosLedOn)],ylim,'Color','k','linestyle','--','linewidth',2);
            eH(iSet+1) = plot([tVec(xPosLedOff) tVec(xPosLedOff)],ylim,'Color','k','linestyle','--','linewidth',2);
            
            % Set the legend up
            %lh = legend(eH,{'rep 1','rep 2','rep 3'});
            lh=legend({'rep 1','rep 2','rep 3'});
            box off
            set(gca,'TickDir','out')

            title(titleStr);
            ylabel(yLabel);
            xlabel(xLabel);

            % adjust axis manually
            if axisType == 1
                axis([0.075 4.15 -0.01 0.04])
                axisStr = 'full';
            elseif axisType == 2
                axis([2.5 4.3 -0.015 0.04])
                axisStr = 'zoom';
            end
            set(lh,'location','best');

            if saveFigs
                figSaveName = fullfile(figDir,['epi_stim_rep_comparison_' axisStr '_' [setNames{:}]]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end 
        end
    end

end

%% plot entire block responses
if doPlotByBlock

end
