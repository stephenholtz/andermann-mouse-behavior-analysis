%% Quickly plot face motion from each stimulus
% 
% Plots the output or output with offset subtracted
%
% SLH 2014

%% Set up filepaths / load processed data 
animalName  = 'K51';
expDateNum  = '20140830_02';

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
% Metadata path
metaPath = dir([rawDir filesep 'stimulus_metadata*.mat']);
metaPath = fullfile(rawDir,metaPath(1).name);
% Load data from 'stim' struct
if ~exist('stim','var')
    load(metaPath);
end
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,'nidaq_*.mat'));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);
% Load data from experiment 'daq' struct
if ~exist('daq','var')
    fprintf('loading nidaq data...')
    load(nidaqFilePath);
    fprintf(' done\n')
end

load(fullfile(procDir,'faceMotion.mat'));
load(fullfile(procDir,'frameNums.mat'));
load(fullfile(procDir,'stimTsInfo.mat'));

%% Common plotting variables
saveFigs              = 1;

% Make these plots
plotLumped            = 1;
plotLumpedComparisons = 1;
plotPerStimMotDiff    = 1;

% Use these analysis windows
stimTimeSec            = stim.durOn;
preStimTimeSec         = .25;
preStimTimeSamps       = daq.daqRate*preStimTimeSec;
postStimTimeSec        = .25;
postStimTimeSamps      = daq.daqRate*postStimTimeSec;
nReliableFrames        = floor(frameNums.faceRate*(preStimTimeSec+postStimTimeSec+stimTimeSec) - 6);
nReliablePreStimFrames = floor(frameNums.faceRate*(preStimTimeSec) - 6);

%----------------------------------------------------------------------
%% Combine Stimuli across entire experiment (different stimSets)
[nBlocks,nStims,nReps] = size(stimTsInfo.all);
for iStim = 1:6
    iRoi = 1;
    rowIter = 1;
    for iBlock = 1:nBlocks
        for iRep = 1:nReps
            stimDaqBounds = stimTsInfo.all(iBlock,iStim,iRep).led;
            stimOnsetInd = stimDaqBounds(1);
            stimOffsetInd = stimDaqBounds(2);
            % Get the daq timeseries ind where this stimulus started (minus prestimtime)
            startDaqInd = stimOnsetInd - preStimTimeSamps;
            % Get the frame number of that starting daq ind
            startFrameInd = frameNums.face(startDaqInd);
            % Determine ending daq point
            endDaqInd = stimOnsetInd + stimTimeSec*daq.daqRate + postStimTimeSamps;
            endFrameInd = frameNums.face(endDaqInd);

            % Number of frames is somewhat unreliable, truncate all to same length
            framesToUse = startFrameInd:endFrameInd;
            framesToUse = framesToUse(1:nReliableFrames);

            % Use the abs motion vector, (x^2 + y^2)^(1/2)
            x = faceMotion.stackRegCell{iRoi}(framesToUse,4);
            y = faceMotion.stackRegCell{iRoi}(framesToUse,3); 
            absMotion = sqrt(x.^2 + y.^2);
            motionTs.('noSub').all{iStim}(rowIter,:) = absMotion;
            motionTs.('baseSub').all{iStim}(rowIter,:) = absMotion - median(absMotion(1:nReliablePreStimFrames));

            rowIter = rowIter + 1;
        end
    end
end
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
        case 7
            stimsToUse = 1;
            setName = 'medStimLedOff';
        case 8
            stimsToUse = 2;
            setName = 'latStimLedOff';
        case 9
            stimsToUse = 4;
            setName = 'medStimLedOn';
        case 10
            stimsToUse = 5;
            setName = 'latStimLedOn';
    end

    iRoi = 1;
    rowIter = 1;
    for iBlock = 1:nBlocks
        for iStim = stimsToUse
            for iRep = 1:nReps
                stimDaqBounds = stimTsInfo.all(iBlock,iStim,iRep).led;
                stimOnsetInd = stimDaqBounds(1);
                stimOffsetInd = stimDaqBounds(2);
                % Get the daq timeseries ind where this stimulus started (minus prestimtime)
                startDaqInd = stimOnsetInd - preStimTimeSamps;
                % Get the frame number of that starting daq ind
                startFrameInd = frameNums.face(startDaqInd);
                % Determine ending daq point
                endDaqInd = stimOnsetInd + stimTimeSec*daq.daqRate + postStimTimeSamps;
                endFrameInd = frameNums.face(endDaqInd);

                % Number of frames is somewhat unreliable, truncate all to same length
                framesToUse = startFrameInd:endFrameInd;
                framesToUse = framesToUse(1:nReliableFrames);

                % Use the abs motion vector, (x^2 + y^2)^(1/2)
                x = faceMotion.stackRegCell{iRoi}(framesToUse,4);
                y = faceMotion.stackRegCell{iRoi}(framesToUse,3); 
                absMotion = sqrt(x.^2 + y.^2);
                motionTs.('noSub').(setName)(rowIter,:) = absMotion;
                motionTs.('baseSub').(setName)(rowIter,:) = absMotion - median(absMotion(1:nReliablePreStimFrames));

                rowIter = rowIter + 1;
            end
        end
    end
end

%----------------------------------------------------------------------
%% Plot the combined stimulus motion responses

% Baselinesubtracted or raw traces
%procType = 'noSub';
procType = 'baseSub';
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
            case 7
                setName = 'medStimLedOff';
                titleStr =({'Facial motion to medial visual stimuli LED off',''});
            case 8
                setName = 'latStimLedOff';
                titleStr =({'Facial motion to lateral visual stimuli LED off',''});
            case 9
                setName = 'medStimLedOn';
                titleStr =({'Facial motion to medial visual stimuli LED On',''});
            case 10 
                setName = 'latStimLedOn';
                titleStr =({'Facial motion to lateral visual stimuli LED On',''});
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
            figSaveName = fullfile(figDir,['faceMot_' procType '_' setName '_' animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-pdf',gcf)
        end 
    end
end

%----------------------------------------------------------------------
%% Plot comparisons of averaged motion responses
if plotLumpedComparisons
    % These should be the same for all plots
    xTsVector = (1:size(motionTs.(procType).all,2))/camFrameRate;
    onsetSeconds = 1;
    offsetSeconds = 2;
    yLabel = 'Pixel Shift';
    xLabel = 'Time (s)';
    for comparisonType = 1:4
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
            case 4
                setName1 = 'medStimLedOff';
                setName2 = 'latStimLedOff';
                titleStr = {'Facial motion medial vs lateral stim w/LED on'};
                setLegName1 = 'LED Off Med Vis Stim';
                setLegName2 = 'LED Off Lat Vis Stim';
            case 5
                setName1 = 'medStimLedOn';
                setName2 = 'latStimLedOn';
                titleStr = {'Facial motion medial vs lateral stim w/LED on'};
                setLegName1 = 'LED On Med Vis Stim';
                setLegName2 = 'LED On Lat Vis Stim';
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
            figSaveName = fullfile(figDir,['faceMot_compare' procType '_' setName1 '_vs' setName2 '_' animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-pdf',gcf)
        end
    end
end

%----------------------------------------------------------------------
%% Calculate reponses in a window after stimulus onset (wrt baseline)
procType = 'baselineSub';
moct = 'median';
postStimRespWindowMs = 250;
nFramesRespWindow = floor(postStimRespWindowMs/1000*camFrameRate) - 2;
rowIter = 1;
for iBlock = 1:nBlocks
    % New col for each stimulus rep / type (should be 1:18)
    colIter = 1;
    for iStim = 1:6
        for iRep = 1:nReps
                stimDaqBounds = stimTsInfo.all(iBlock,iStim,iRep).led;
                stimOnsetInd = stimDaqBounds(1);
                stimOffsetInd = stimDaqBounds(2);
                % Get the daq timeseries ind where this stimulus started (minus prestimtime)
                startDaqInd = stimOnsetInd - preStimTimeSamps;
                % Get the frame number of that starting daq ind
                startFrameInd = frameNums.face(startDaqInd);
                % Determine ending daq point
                endDaqInd = stimOnsetInd + stimTimeSec*daq.daqRate + postStimTimeSamps;
                endFrameInd = frameNums.face(endDaqInd);

                % Number of frames is somewhat unreliable, truncate all to same length
                framesToUse = stimOnFrameInd:(stimOnFrameInd+nFramesRespWindow);
                preFramesToUse = (stimOnFrameInd-nReliablePreStimFrames):stimOnFrameInd; 

                % Use the abs motion vector, (x^2 + y^2)^(1/2)
                x = faceMotion.stackRegCell{iRoi}(framesToUse,4);
                y = faceMotion.stackRegCell{iRoi}(framesToUse,3); 
                absPostMotion = sqrt(x.^2 + y.^2);
                x = faceMotion.stackRegCell{iRoi}(preFramesToUse,4);
                y = faceMotion.stackRegCell{iRoi}(preFramesToUse,3); 
                absPreMotion = sqrt(x.^2 + y.^2);
                %motion.(setName)(rowIter,:) = absMotion;
                motion.(setName)(rowIter,colIter) = median(absPreMotion) - median(absPostMotion);

            motion.(moct)(rowIter,colIter) = median(faceMotion.stackRegCell(framesToUse,4)) - median(faceMotion.stackRegCell(preStimFrames,4));
            colIter = colIter + 1;
        end
    end
    rowIter = rowIter + 1;
end

%----------------------------------------------------------------------
%% Plot responses in window pre vs post 
if plotPerStimMotDiff
    moct = 'median';
    % These should be the same for all plots
    yLabel = {'Median Diff Pixel Shift','Pre vs 250ms Post Stimulus Onset'};
    xLabel = 'Stimulus Type';
    titleStr = 'Difference in motion across all block repetitions';
    figure();
    plot(motion.(moct)')
    hold all
    plot(mean(motion.(moct)),'LineWidth',3,'Color','k');
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
        figSaveName = fullfile(figDir,['all_stimuli_median_response_diff_' procType '_'  animalName '_' expDateNum]);
        export_fig(gcf,figSaveName,'-pdf',gcf)
    end 
end

