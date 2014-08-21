%% Quickly plot face motion from each stimulus
% 
% Plots the output or output with offset subtracted
%
% SLH 2014

%% Set up filepaths
animalName  = 'K71';
expDateNum  = '20140815_01';
saveFigs    = 1;
% Get the base location for data
dataDir = getExpDataSource('macbook');
% Experiment directory
expDir  = fullfile(dataDir,animalName,expDateNum);
% Processed data filepath
rawDir = fullfile(expDir,'raw');
procDir = fullfile(expDir,'proc');
figDir = fullfile(expDir,'figs');

%% Load variables
% Stimulus metadata
stimMetaFile = dir(fullfile(rawDir,'stimulus_*.mat'));
load(fullfile(rawDir,stimMetaFile(1).name));
% entire daq timeseries
daqFile = dir(fullfile(rawDir,'nidaq_*.mat'));
%load(fullfile(rawDir,daqFile(1).name));

% Processed variables
load(fullfile(procDir,'faceMotion.mat'));
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

% loop over data to make a large matrix
% This part is simple because we want the time from stimulus onset to offset
method          = 'stackReg';
camFrameRate    = 70;
daqRate         = 5000;
stimTimeSec     = stim.durOn;
preStimTimeSec  = 1;
preStimTimeSamps= daqRate*preStimTimeSec;
postStimTimeSec = 1;
postStimTimeSamps= daqRate*postStimTimeSec;
nReliableFrames = camFrameRate*(preStimTimeSec+postStimTimeSec+stimTimeSec) - 10;
nReliablePreStimFrames = camFrameRate*(preStimTimeSec) - 10;

%----------------------------------------------------------------------
%% Combine Stimuli across entire experiment (different stimSets)
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
                stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};
                % Get the daq timeseries ind where this stimulus started (minus prestimtime)
                startDaqInd = stimOnsetInd - preStimTimeSamps;
                % Get the frame number of that starting daq ind
                startFrameInd = frameNums.face(startDaqInd);
                % Determine ending daq point
                endDaqInd = stimOnsetInd + stimTimeSec*daqRate + postStimTimeSamps;
                endFrameInd = frameNums.face(endDaqInd);

                % Number of frames is somewhat unreliable, truncate all to same length
                framesToUse = startFrameInd:endFrameInd;
                framesToUse = framesToUse(1:nReliableFrames);
                motionTs.('raw').(setName)(rowIter,:) = faceMotion.(method)(framesToUse,4);

                preStimFrames = startFrameInd:startFrameInd+nReliablePreStimFrames;
                motionTs.('baselineSub').(setName)(rowIter,:) = faceMotion.(method)(framesToUse,4) - median(faceMotion.(method)(preStimFrames,4));

                rowIter = rowIter + 1;
            end
        end
    end
end

%----------------------------------------------------------------------
%% Plot the combined stimulus motion responses

% Baselinesubtracted or raw traces
%procType = 'raw';
procType = 'baselineSub';

plotLumped = 1;
if plotLumped
    % These should be the same for all plots
    xTsVector = (1:size(motionTs.(procType).all,2))/camFrameRate;
    onsetSeconds = 1;
    offsetSeconds = 2;
    yLabel = 'Pixel Shift';
    xLabel = 'Time (s)';

    for stimSet = 1:6
        switch stimSet
            case 1
                setName = 'all';
                titleStr = ({'Facial motion across all stimuli', '(blank conditions included'});
            case 2
                setName = 'allVis';     
                titleStr = ({'Facial motion across all visual stimuli', '(no blank conditions)'});
            case 3
                setName = 'blank';        
                titleStr = ({'Facial motion across all blank stimuli', ''});
            case 4
                setName = 'ledOnly';
                titleStr =({'Facial motion to LED Only',''});
            case 5
                setName = 'ledOffVis';        
                titleStr =({'Facial motion to visual stimuli LED Off',''});
            case 6
                setName = 'ledOnVis';
                titleStr =({'Facial motion to visual stimuli LED On',''});
        end

        figure();
        plot(xTsVector,motionTs.(procType).(setName));
        hold all
        plot([onsetSeconds onsetSeconds],ylim,'lineWidth',3,'Color','G')
        plot([offsetSeconds offsetSeconds],ylim,'lineWidth',3,'Color','G')
        plot(xTsVector,mean(motionTs.(procType).(setName)),'LineWidth',3,'Color','k');
        ylabel(yLabel)
        xlabel(xLabel)
        title(titleStr)
        if saveFigs
            figSaveName = fullfile(figDir,[setName '_' animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-eps',gcf)
        end 
    end
end

%----------------------------------------------------------------------
%% Plot comparisons of averaged motion responses
plotLumpedComparisons = 1;
if plotLumpedComparisons
    % These should be the same for all plots
    xTsVector = (1:size(motionTs.(procType).all,2))/camFrameRate;
    onsetSeconds = 1;
    offsetSeconds = 2;
    yLabel = 'Pixel Shift';
    xLabel = 'Time (s)';
    for comparisonType = 1:3
        switch comparisonType
            case 1
                setName1 = 'allVis';
                setName2 = 'blank';
                titleStr = {'All visual vs blank stimuli'};
                setLegName1 = 'All Visual Stimuli';
                setLegName2 = 'Blank Stimuli';
            case 2
                setName1 = 'ledOnly';
                setName2 = 'blank';
                titleStr = {'Only LED vs blank stimuli'};
                setLegName1 = 'LED Only';
                setLegName2 = 'Blank Stimuli';
            case 3
                setName1 = 'ledOffVis';
                setName2 = 'ledOnVis';
                titleStr = {'Facial motion with LED off vs LED on'};
                setLegName1 = 'LED Off Vis Stim';
                setLegName2 = 'LED On Vis Stim';
        end
        
        figure();
        plot(xTsVector,mean(motionTs.(procType).(setName1)),'LineWidth',3);
        hold all
        plot(xTsVector,mean(motionTs.(procType).(setName2)),'LineWidth',3);
        % Terrible hack to get correct ylim
        plot([onsetSeconds onsetSeconds],ylim,'lineWidth',3,'Color','G')
        plot([offsetSeconds offsetSeconds],ylim,'lineWidth',3,'Color','G')
        plot([onsetSeconds onsetSeconds],ylim,'lineWidth',3,'Color','G')
        plot([offsetSeconds offsetSeconds],ylim,'lineWidth',3,'Color','G')
        ylabel(yLabel)
        xlabel(xLabel)
        title(titleStr)
        lH = legend(setLegName1,setLegName2,'stimulus on/off');

        if saveFigs
            figSaveName = fullfile(figDir,[setName1 '_vs_' setName2 '_' animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-eps',gcf)
        end
    end
end
%----------------------------------------------------------------------
%% Calculate reponses in a window after stimulus onset (wrt baseline)
procType = 'baselineSub';
postStimRespWindowMs = 250;
nFramesRespWindow = floor(postStimRespWindowMs/1000*camFrameRate) - 2;
rowIter = 1;
for iBlock = 1:size(stimTsInfo.all,1)
    % New col for each stimulus rep / type (should be 1:18)
    colIter = 1;
    for iStim = 1:6
        for iRep = 1:numel([stimTsInfo.all{iBlock,iStim,:}])
            stimOnsetInd = stimTsInfo.all{iBlock,iStim,iRep};
            stimOnFrameInd = frameNums.face(stimOnsetInd);
            % Get the daq timeseries ind where this stimulus started (minus prestimtime)
            startDaqInd = stimOnsetInd - preStimTimeSamps;
            % Get the frame number of that starting daq ind
            startFrameInd = frameNums.face(startDaqInd);

            % Number of frames is somewhat unreliable, truncate all to same length
            framesToUse = stimOnFrameInd:(stimOnFrameInd+nFramesRespWindow);
            preStimFrames = startFrameInd:startFrameInd+nReliablePreStimFrames;
            motion.('median')(rowIter,colIter) = median(faceMotion.(method)(framesToUse,4)) - median(faceMotion.(method)(preStimFrames,4));
            colIter = colIter + 1;
        end
    end
    rowIter = rowIter + 1;
end

plotPerStimMotDiff = 1;
if plotPerStimMotDiff
    method = 'median';
    % These should be the same for all plots
    yLabel = {'Median Diff Pixel Shift','Pre vs 250ms Post Stimulus Onset'};
    xLabel = 'Stimulus Type';
    titleStr = 'Difference in motion across all block repetitions';
    figure();
    plot(motion.(method)')
    hold all
    plot(mean(motion.(method)),'LineWidth',3,'Color','k');
    ylabel(yLabel)
    xlabel(xLabel)
    set(gca,'Xtick',1:18)
    set(gca,'XtickLabel',{'1','1','1','2','2','2','3','3','3','1-LED','1-LED','1-LED','2-LED','2-LED','2-LED','3-LED','3-LED','3-LED'});
    try
        set(gca,'XTickLabelRotation',45)
    catch
        warning('Tick rotation not supported')
    end
    title(titleStr)
    if saveFigs
        figSaveName = fullfile(figDir,['all_stimuli_median_response_' animalName '_' expDateNum]);
        export_fig(gcf,figSaveName,'-eps',gcf)
    end 
end

