%% plotEpiDff.m
% Plot the epi signal in a few ways...
%
% SLH

%% Specify animal/experiment/data location
animalName        = 'K51';
expDateNum        = '20140902_01';
justLoadVariables = 0;
recalculateDs     = 1;
saveFigs          = 1;

doPlotLumpAllTraces = 1;
doPlotComparisonTraces = 1;
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
if ~exist('frameNums','var')
    load(fullfile(procDir,'frameNums.mat'));    % frameNums
end
if ~exist('stimTsInfo','var')
    load(fullfile(procDir,'stimTsInfo.mat'));   % stimTsInfo
end
if ~exist('roi','var')
    load(fullfile(procDir,'epiROIs.mat'));      % roi
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
traceTypes = {'dff'};
colorOrder = get(gca,'ColorOrder');

[nBlocks,nStims,nReps] = size(stimTsInfo.all);
for i = 1:numel(epiTrace)
    lenDff(i) = numel(epiTrace(i).dff);
    nOff(i) = epiTrace(i).ledOnOff(2);
    nPostLedOff(i) = lenDff(i) - nOff(i);
    nOn(i) = epiTrace(i).ledOnOff(1);
    nPreLedOff(i) = lenDff(i) - nOn(i); 
end

nPostLedOff = median(nPostLedOff);
nPreStimFrames = ceil(.5*frameNums.epiRate);
nPreLedOff = min(nPreLedOff) + nPreStimFrames;
% all above is pretty pointless, just use this
nTotalFrames = min(lenDff);
% Set up on and off times
stm=[epiTrace(:).ptbOnOff];
led=[epiTrace(:).ledOnOff];
xPosStim = nTotalFrames - [min(lenDff-(stm(1:2:end))) min(lenDff-(stm(2:2:end)))];
xPosLed = nTotalFrames - [min(lenDff-(led(1:2:end))) min(lenDff-(led(2:2:end)))];
clear stm led

axF = [0.05 2.6 -0.01225 0.0225];
axZ = [1.4 2.3 -0.01225 0.0225];
 
if ~exist('dS','var') || recalculateDs
    clear dS

    % average the full blocks (and also therefore) average each rep of a stimuli across blocks
    blockStimInd = 1;
    for iS = 1:nStims
        for iR = 1:nReps
            iRow = 1;
            for iB = 1:nBlocks
                dS.fullBlocks(blockStimInd).dff(iRow,:) = epiTrace(iB,iS,iR).dff(end-nTotalFrames+1:end);

                % All dff have the same number of frames AFTER the LED
                % align them so that they all end together, using flip (later unflip)
                %tmpFlip = flip(epiTrace(iB,iS,iR).dff);

                % Store a trace for every stim in a block to then average over
                % for looking at adaptation (e.g. subsequent reps)
                %dS.fullBlocks(blockStimInd).dff(iRow,1:numel(tmpFlip)) = tmpFlip;
                iRow = iRow + 1;
            end
            %dS.fullBlocks(blockStimInd).dff = fliplr(dS.fullBlocks(blockStimInd).dff);
            blockStimInd = blockStimInd + 1;
        end
        % 'Unflip' the data so that the ends are aligned, it adds, but only at 
        % the beginning so not a huge problem
        clear tmpFlip
    end

    % Average in logical sets for quick comparison
    for stimSet = 1:6
        switch stimSet
            case 1
                stimsToUse = [1 3];
                setName = 'vis';
            case 2
                stimsToUse = [2 4];
                setName = 'blank';     
            case 3
                stimsToUse = 2;
                setName = 'blankLedOff';        
            case 4
                stimsToUse = 4;
                setName = 'blankLedOn';
            case 5
                stimsToUse = 1;
                setName = 'medStimLedOff';
            case 6
                stimsToUse = 3;
                setName = 'medStimLedOn';
        end

        % Gather all traces
        for tT = traceTypes 
            traceType = tT{1};
            iRow = 1;
            for iS = stimsToUse
                for iB = 1:size(epiTrace,1) 
                    for iR = 1:numel(epiTrace(iB,iS,:))
                        dS.(setName).(traceType)(iRow,:) = epiTrace(iB,iS,iR).(traceType)(end-nTotalFrames+1:end);
                        % All dff have the same number of frames AFTER the LED
                        % align them so that they all end together, using flip (later unflip)
                        %tmpFlip = flip(epiTrace(iB,iS,iR).(traceType));
                        %dS.(setName).(traceType)(iRow,1:numel(tmpFlip)) = tmpFlip;
                        iRow = iRow + 1;
                    end
                end
            end
%            % 'Unflip' the data so that the ends are aligned, it adds, but only at 
%            % the beginning so not a huge problem
%            dS.(setName).(traceType) = fliplr(dS.(setName).(traceType));
%            dS.(setName).(traceType) = fliplr(dS.(setName).(traceType));
        end
        clear tmpFlip
    end
end
% Clean up while still a script
clear tT iRow iS iR setName traceType stimsToUse


tVec = (1:size(dS.vis.dff,2))./frameNums.epiRate;
%----------------------------------------------------------------------
%% Plot the combined stimulus responses
%----------------------------------------------------------------------
% Make plots of all responses and their averages
if doPlotLumpAllTraces  
    for axisType = 1:2
        yLabel = '\DeltaF/F0';
        xLabel = 'Time (s)';
        for stimSet = 1:6
            switch stimSet
                case 1
                    setName = 'vis';
                    titleStr = ({'Across visual conditions'});
                case 2
                    setName = 'blank';     
                    titleStr = ({'All blank conditions'});
                case 3
                    setName = 'blankLedOff';        
                    titleStr = ({'Blank conditions no LED'});
                case 4
                    setName = 'blankLedOn';
                    titleStr =({'Blank conditions with LED'});
                case 5
                    setName = 'medStimLedOn';
                    titleStr =({'Medial visual conditions'});
                case 6
                    setName = 'medStimLedOff';
                    titleStr =({'Medial visual conditions'});
            end
            tVec = (1:size(dS.(setName).dff,2))./frameNums.epiRate;
            dVec = dS.(setName).dff;

            figure();
            plot(tVec,dVec');
            hold all
            plot(tVec,median(dVec),'Color','k','LineWidth',4);

            % Get the ylims right for plotting
            for ii = 1:2
                plot([tVec(xPosLed(1)) tVec(xPosLed(1))],ylim,'Color','b','linestyle','--','linewidth',2);
                plot([tVec(xPosLed(2)) tVec(xPosLed(2))],ylim,'Color','b','linestyle','--','linewidth',2);
                plot([tVec(xPosStim(1)) tVec(xPosStim(1))],ylim,'Color','k','linestyle','--','linewidth',2);
                plot([tVec(xPosStim(2)) tVec(xPosStim(2))],ylim,'Color','k','linestyle','--','linewidth',2);
            end

            box off
            set(gca,'TickDir','out')
            title(titleStr);
            ylabel(yLabel);
            xlabel(xLabel);

            % adjust axis manually
            if axisType == 1
                axis(axF)
                axisStr = 'full';
            elseif axisType == 2
                axis(axZ)
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
        for stimSet = 1:4
            switch stimSet
                case 1
                    setNames = {'medStimLedOff','blankLedOff'};
                    titleStr = ({'Visual vs. Blank, (LED off)'});
                case 2
                    setNames = {'medStimLedOn','blankLedOn'};
                    titleStr = ({'Visual vs. Blank, (LED on)'});
                case 3
                    setNames = {'blankLedOn','blankLedOff'};
                    titleStr = ({'Blank, LED On vs. LED Off'});
                case 4
                    setNames = {'medStimLedOff','medStimLedOn','blankLedOff','blankLedOn'};
                    titleStr = ({'All conditions'});
            end

            figure();
            clear eH
            tVec = (1:size(dS.(setNames{1}).dff,2))./frameNums.epiRate;
            for iSet = 1:numel(setNames)
                dVec = dS.(setNames{iSet}).dff;
                eVec = std(dVec)/sqrt(size(dVec,1));
                %tH = shadedErrorBar(tVec,median(dVec),[eVec;eVec],{'Color',.9*colorOrder(iSet,:),'MarkerFaceColor',.9*colorOrder(iSet,:)},1);
                eH(iSet) = tH.mainLine;
                plot(tVec,median(dVec),'LineWidth',2);
                hold all
            end
            plot([tVec(xPosLed(1)) tVec(xPosLed(1))],ylim,'Color','b','linestyle','--','linewidth',2);
            plot([tVec(xPosLed(2)) tVec(xPosLed(2))],ylim,'Color','b','linestyle','--','linewidth',2);
            plot([tVec(xPosStim(1)) tVec(xPosStim(1))],ylim,'Color','k','linestyle','--','linewidth',2);
            plot([tVec(xPosStim(2)) tVec(xPosStim(2))],ylim,'Color','k','linestyle','--','linewidth',2);
            
            % Set the legend up
            lh = legend(gca,setNames);
            box off
            set(gca,'TickDir','out')

            title(titleStr);
            ylabel(yLabel);
            xlabel(xLabel);

            % adjust axis manually
            if axisType == 1
                axis(axF)
                axisStr = 'full';
            elseif axisType == 2
                axis(axZ)
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
        for stimSet = 1:4
            switch stimSet
                case 1
                    setNames = {'medStimLedOff'};
                    blockInds = 1:4;
                case 2
                    setNames = {'blankLedOff'};
                    blockInds = 5:8;
                case 3
                    setNames = {'medStimLedOn'};
                    blockInds = 9:12;
                case 4
                    setNames = {'blankLedOn'};
                    blockInds = 12:16;
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
            plot([tVec(xPosLed(1)) tVec(xPosLed(1))],ylim,'Color','b','linestyle','--','linewidth',2);
            plot([tVec(xPosLed(2)) tVec(xPosLed(2))],ylim,'Color','b','linestyle','--','linewidth',2);
            plot([tVec(xPosStim(1)) tVec(xPosStim(1))],ylim,'Color','k','linestyle','--','linewidth',2);
            plot([tVec(xPosStim(2)) tVec(xPosStim(2))],ylim,'Color','k','linestyle','--','linewidth',2);
 
            % Set the legend up
            lh=legend({'rep 1','rep 2','rep 3','rep 4'});
            box off
            set(gca,'TickDir','out')

            title(titleStr);
            ylabel(yLabel);
            xlabel(xLabel);
            % adjust axis manually
            if axisType == 1
                axis(axF)
                axisStr = 'full';
            elseif axisType == 2
                axis(axZ)
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
