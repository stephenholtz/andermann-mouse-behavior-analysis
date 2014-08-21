%% Specify animal/experiment/data location
animalName  = 'K71';
expDateNum  = '20140815_01';

makeNewRois = 0;
calcNewDff  = 0;
saveFigs    = 1;

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
% Epi imaging tiff path
epiTiffPath = dir([procDir filesep 'epi_*.tiff']);
epiTiffPath = fullfile(procDir,epiTiffPath(1).name);
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,['nidaq_*.mat']));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);

% Load processed variables
load(fullfile(procDir,'faceMotion.mat'));
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

load(fullfile(procDir,'epiROIs.mat'))
load(fullfile(procDir,'epiDff.mat'))

% Should be calculated from daq trace...
epiFrameRate = 20; 
% Hand copied variables... store somewhere!
exp.daqRate = 5000;
bufferDaqSamps = ceil(0.425*exp.daqRate);
durPrevSecs = 1;
durPostSecs = 1;
dffFramesPrev = durPrevSecs*epiFrameRate;
dffFramesPost = durPostSecs*epiFrameRate;

%---------------------------------------------------
%% Group the DFFs for averaging within stimulus types

nRois = numel(roi);
if ~exist('preDff','var')
    for iRoi = 1:nRois
        i = 1;
        for stimSet = 1:6 
            switch stimSet
                case 1
                    stimsToUse = 1:6;
                    setName = 'all';
                case 2
                    stimsToUse = [1 2 4 5];
                    setName = 'allVis';     
                case 3
                    stimsToUse = 3;
                    setName = 'blank';        
                case 4
                    stimsToUse = 6;
                    setName = 'ledOnly';
                case 5
                    stimsToUse = [1 2];
                    setName = 'ledOffVis';        
                case 6
                    stimsToUse = [4 5];
                    setName = 'ledOnVis';
            end

            rowIter = 1;
            for iBlock = 1:size(stimTsInfo.all,1)
                for iStim = stimsToUse
                    for iRep = 1:numel([stimTsInfo.all{iBlock,iStim,:}])

                        % Dff values sets to average etc.,
                        preSub = mean(dff(iRoi).pre{iBlock,iStim,iRep}(end-2:end));
                        preDff(iRoi).('baselineSub').(setName)(rowIter,:) = dff(iRoi).pre{iBlock,iStim,iRep} - preSub;
                        preDff(iRoi).('normal').(setName)(rowIter,:) = dff(iRoi).pre{iBlock,iStim,iRep};
                        postDff(iRoi).('baselineSub').(setName)(rowIter,:) = dff(iRoi).post{iBlock,iStim,iRep} - preSub;
                        postDff(iRoi).('normal').(setName)(rowIter,:) = dff(iRoi).post{iBlock,iStim,iRep};

                        % TODO: Make this less destructive
                        try
                            fullDff(iRoi).('baselineSub').(setName)(rowIter,:) = dff(iRoi).full{iBlock,iStim,iRep} - preSub;
                            fullDff(iRoi).('normal').(setName)(rowIter,:) = dff(iRoi).full{iBlock,iStim,iRep};
                        catch
                            fullDff(iRoi).('baselineSub').(setName)(rowIter,:) = NaN;
                            fullDff(iRoi).('normal').(setName)(rowIter,:) = NaN;
                        end
                        rowIter = rowIter + 1;
                    end
                end
            end
        end
    end
end

%----------------------------------------------------------------------
%% Plot the combined stimulus responses

% Baselinesubtracted or raw traces
procType = 'normal';
%procType = 'baselineSub';

% To plot in seconds
indsPre = size(preDff(iRoi).(procType).all,2);
indsPost = size(postDff(iRoi).(procType).all,2);
indsFull = size(fullDff(iRoi).(procType).all,2);

xPre = (1:indsPre)*(1/epiFrameRate);
xGapOn = xPre(end) + mode(diff(xPre));
xPost = xGapOn + (1:indsPost)*(1/epiFrameRate);
xGapOff = xPost(1) - mode(diff(xPost));
xFull = (1:indsFull)*(1/epiFrameRate);

xTsVector = [xPre xGapOn xPost];

gapVal = 0;

doPlotLumped = 1;
if doPlotLumped
    for iRoi = 1:nRois
        % These should be the same for all plots
        yLabel = '\DeltaF/F0';
        xLabel = 'Time (s)';

        for stimSet = 1:6
            switch stimSet
                case 1
                    setName = 'all';
                    titleStr = ({'DFF across all stimuli (inc blanks)','Pre + Post LED Timeseries'});
                case 2
                    setName = 'allVis';     
                    titleStr = ({'DFF across all visual stimuli (no blanks)','Pre + Post LED Timeseries'});
                case 3
                    setName = 'blank';        
                    titleStr = ({'DFF across all blank stimuli','Pre + Post LED Timeseries'});
                case 4
                    setName = 'ledOnly';
                    titleStr =({'DFF to LED Only','Pre + Post LED Timeseries'});
                case 5
                    setName = 'ledOffVis';        
                    titleStr =({'DFF to visual stimuli LED Off','Pre + Post LED Timeseries'});
                case 6
                    setName = 'ledOnVis';
                    titleStr =({'DFF to visual stimuli LED On','Pre + Post LED Timeseries'});
            end

            figure();
            dPre = preDff(iRoi).(procType).(setName);
            dGap = gapVal*ones(size(dPre,1),1); 
            dPost = postDff(iRoi).(procType).(setName);
            dVector = [dPre, dGap, dPost];
            plot(xTsVector,dVector);
            hold all
            plot([xGapOn xGapOn],ylim,'lineWidth',3,'Color','G')
            plot(xTsVector,mean(dVector),'LineWidth',3,'Color','k');
            ylabel(yLabel)
            xlabel(xLabel)
            title(titleStr)
            if saveFigs
                figSaveName = fullfile(figDir,['epiDff_pre_post' 'roi' num2str(iRoi) roi(iRoi).label '_' setName '_' animalName '_' expDateNum]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end 
        end
    end
end

%------------------------------------------------------------
%% Plot comparisons of averaged motion responses
doPlotLumpedComparisons = 1;
if doPlotLumpedComparisons
    for iRoi = 1:nRois
        % These should be the same for all plots
        yLabel = '\DeltaF/F0';
        xLabel = 'Time (s)';

        for comparisonType = 1:3
            switch comparisonType
                case 1
                    setName1 = 'allVis';
                    setName2 = 'blank';
                    titleStr = {'\DeltaF/F0 All visual vs blank stimuli','Pre + Post LED Timeseries'};
                    setLegName1 = 'All Visual Stimuli';
                    setLegName2 = 'Blank Stimuli';
                case 2
                    setName1 = 'ledOnly';
                    setName2 = 'blank';
                    titleStr = {'\DeltaF/F0 LED vs blank stimuli','Pre + Post LED Timeseries'};
                    setLegName1 = 'LED Only';
                    setLegName2 = 'Blank Stimuli';
                case 3
                    setName1 = 'ledOffVis';
                    setName2 = 'ledOnVis';
                    titleStr = {'\DeltaF/F0 with LED off vs LED on','Pre + Post LED Timeseries'};
                    setLegName1 = 'LED Off Vis Stim';
                    setLegName2 = 'LED On Vis Stim';
            end

            figure();
            dPre = preDff(iRoi).(procType).(setName1);
            dGap = gapVal*ones(size(dPre,1),1); 
            dPost = postDff(iRoi).(procType).(setName1);
            dVector = [dPre, dGap, dPost];
            plot(xTsVector,mean(dVector));
            hold all
            dPre = preDff(iRoi).(procType).(setName2);
            dGap = gapVal*ones(size(dPre,1),1); 
            dPost = postDff(iRoi).(procType).(setName2);
            dVector = [dPre, dGap, dPost];
            plot(xTsVector,mean(dVector));
     
            % Terrible hack to get correct ylim
            plot([xGapOn xGapOn],ylim,'lineWidth',3,'Color','G')
            plot([xGapOn xGapOn],ylim,'lineWidth',3,'Color','G')
            ylabel(yLabel)
            xlabel(xLabel)
            title(titleStr)
            lH = legend(setLegName1,setLegName2,'stimulus on/off');

            if saveFigs
                figSaveName = fullfile(figDir,['epiDff_pre_post' 'roi' num2str(iRoi) roi(iRoi).label '_' setName1 '_vs_' setName2 '_' animalName '_' expDateNum]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end
        end
    end
end

%------------------------------------------------------------
%% Plot comparisons of full timeseries
doPlotFullTs = 1;
if doPlotFullTs
    for iRoi = 1:nRois
        % These should be the same for all plots
        yLabel = '\DeltaF/F0';
        xLabel = 'Time (s)';

        for comparisonType = 1:3
            switch comparisonType
                case 1
                    setName1 = 'allVis';
                    setName2 = 'blank';
                    titleStr = {'\DeltaF/F0 All visual vs blank stimuli','Full Timeseries'};
                    setLegName1 = 'All Visual Stimuli';
                    setLegName2 = 'Blank Stimuli';
                case 2
                    setName1 = 'ledOnly';
                    setName2 = 'blank';
                    titleStr = {'\DeltaF/F0 LED vs blank stimuli','Full Timeseries'};
                    setLegName1 = 'LED Only';
                    setLegName2 = 'Blank Stimuli';
                case 3
                    setName1 = 'ledOffVis';
                    setName2 = 'ledOnVis';
                    titleStr = {'\DeltaF/F0 with LED off vs LED on','Full Timeseries'};
                    setLegName1 = 'LED Off Vis Stim';
                    setLegName2 = 'LED On Vis Stim';
            end

            % Need to figure out why lens of full are different between stimuli??
            figure();
            indsFull = size(fullDff(iRoi).(procType).(setName1),2);
            xTsVector = (1:indsFull)*(1/epiFrameRate);
            dVector = fullDff(iRoi).(procType).(setName1);
            plot(xTsVector,nanmean(dVector));
            hold all
            indsFull = size(fullDff(iRoi).(procType).(setName2),2);
            xTsVector = (1:indsFull)*(1/epiFrameRate);
            dVector = fullDff(iRoi).(procType).(setName2);
            plot(xTsVector,nanmean(dVector));
 
            % Terrible hack to get correct ylim
            plot([xGapOn xGapOn],ylim,'lineWidth',3,'Color','G')
            plot([xGapOff xGapOff],ylim,'lineWidth',3,'Color','G')
            ylabel(yLabel)
            xlabel(xLabel)
            title(titleStr)
            lH = legend(setLegName1,setLegName2,'led on/off');

            if saveFigs
                figSaveName = fullfile(figDir,['epiDff_full' 'roi' num2str(iRoi) roi(iRoi).label '_' setName1 '_vs_' setName2 '_' animalName '_' expDateNum]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end
        end
    end
end
