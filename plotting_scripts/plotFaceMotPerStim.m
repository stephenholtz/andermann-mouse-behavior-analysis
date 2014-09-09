%% Quickly plot face motion from each stimulus
% 
% Plots the output or output with offset subtracted
%
% SLH 2014

%% Set up filepaths / load processed data 
animalName  = 'K51';
expDateNum  = '20140902_01';

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
if ~exist('faceMotion','var')
    load(fullfile(procDir,'faceMotion.mat'));
end
if ~exist('frameNums','var')
    load(fullfile(procDir,'frameNums.mat'));
end
if ~exist('stimTsInfo','var')
    load(fullfile(procDir,'stimTsInfo.mat'));
end
if ~exist('roi','var')
    load(fullfile(procDir,'faceROIs.mat'));
end


%% Common plotting variables
saveFigs              = 1;
% Make these plots
plotLumped            = 0;
plotLumpedComparisons = 1;
plotPerStimMotDiff    = 0;

% Use these analysis windows
durPrevSecs   = .5;
durPostSecs   = 1;
motFramesDur = ceil(stim.durOn*frameNums.faceRate);
motFramesPrev = ceil(durPrevSecs*frameNums.faceRate);
motFramesPost = ceil(durPostSecs*frameNums.faceRate);
totalMotFrames = motFramesPrev+motFramesDur+motFramesPost-10;

axF = [0 2 -2 6];
axZ = [.25 1.95 -1.5 2];

%----------------------------------------------------------------------
%% Combine Stimuli across entire experiment (different stimSets)
[nBlocks,nStims,nReps] = size(stimTsInfo.all);
clear motion motionTs
for iStim = 1:4
    for iRoi = 1:5;
        rowIter = 1;
        for iBlock = 1:(nBlocks-12)
            for iRep = 1:nReps
                ledDaqInds = stimTsInfo.all(iBlock,iStim,iRep).led;
                ledStart   = frameNums.face(ledDaqInds(1));
                ledEnd     = frameNums.face(ledDaqInds(2));

                ptbDaqInds = stimTsInfo.all(iBlock,iStim,iRep).ptb;
                ptbStart   = frameNums.face(ptbDaqInds(1));
                ptbEnd     = frameNums.face(ptbDaqInds(2));

                % establish analysis area around led
                analStart = ledStart - motFramesPrev;
                analEnd   = ledEnd + motFramesPost;

                motionTs(iRoi).all(rowIter,:).ptbOnOff = [(ptbStart - analStart) (ptbEnd - analStart)];
                motionTs(iRoi).all(rowIter,:).ledOnOff = [(ledStart - analStart) (ledEnd - analStart)];

                % Number of frames is somewhat unreliable, truncate all to same length
                framesToUse = analStart:analEnd;
                framesToUse = framesToUse(end-totalMotFrames+1:end);

                % Use the abs motion vector, (x^2 + y^2)^(1/2)
                x = faceMotion.stackRegCell{iRoi}(framesToUse,4);
                y = faceMotion.stackRegCell{iRoi}(framesToUse,3); 
                absMotion = sqrt(x.^2 + y.^2);
                motionTs(iRoi).('noSub').all{iStim}(rowIter,:) = absMotion;
                motionTs(iRoi).('baseSub').all{iStim}(rowIter,:) = absMotion - median(absMotion(1:motFramesPrev));

                rowIter = rowIter + 1;
            end
        end
    end
end
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

    for iRoi = 1:5
        rowIter = 1;
        for iBlock = 1:(nBlocks-12)
            for iStim = stimsToUse
                for iRep = 1:nReps
                    ledDaqInds = stimTsInfo.all(iBlock,iStim,iRep).led;
                    ledStart   = frameNums.face(ledDaqInds(1));
                    ledEnd     = frameNums.face(ledDaqInds(2));

                    ptbDaqInds = stimTsInfo.all(iBlock,iStim,iRep).ptb;
                    ptbStart   = frameNums.face(ptbDaqInds(1));
                    ptbEnd     = frameNums.face(ptbDaqInds(2));

                    % establish analysis area around led
                    analStart = ledStart - motFramesPrev;
                    analEnd   = ledEnd + motFramesPost;

                    motionTs(iRoi).(setName)(rowIter,:).ptbOnOff = [(ptbStart - analStart) (ptbEnd - analStart)];
                    motionTs(iRoi).(setName)(rowIter,:).ledOnOff = [(ledStart - analStart) (ledEnd - analStart)];

                    % Number of frames is somewhat unreliable, truncate all to same length
                    framesToUse = analStart:analEnd;
                    framesToUse = framesToUse(end-totalMotFrames+1:end);

                    % Use the abs motion vector, (x^2 + y^2)^(1/2)
                    x = faceMotion.stackRegCell{iRoi}(framesToUse,4);
                    y = faceMotion.stackRegCell{iRoi}(framesToUse,3); 
                    absMotion = sqrt(x.^2 + y.^2);
                    motionTs(iRoi).('noSub').(setName)(rowIter,:) = absMotion;
                    motionTs(iRoi).('baseSub').(setName)(rowIter,:) = absMotion - mean(absMotion(1:motFramesPrev));

                    rowIter = rowIter + 1;
                end
            end
        end
    end
end

nTotalFrames = 138;
stm=[motionTs(1).all.ptbOnOff];
led=[motionTs(1).all.ledOnOff];
xPosStim = [min((stm(1:2:end))) min((stm(2:2:end)))];
xPosLed =  [min((led(1:2:end))) min((led(2:2:end)))];
clear stm led

%----------------------------------------------------------------------
%% Plot the combined stimulus motion responses

% Baselinesubtracted or raw traces
%procType = 'noSub';
procType = 'baseSub';
if plotLumped
    for iRoi = 1:5
        % These should be the same for all plots
        tVec = (1:size(motionTs(iRoi).(procType).vis,2))/frameNums.faceRate;
        yLabel = 'Pixel Shift';
        xLabel = 'Time (s)';

        for stimSet = 1:6
            switch stimSet
                case 1
                    setName = 'vis';
                    titleStr = ({'Facial motion to vis stim'});
                case 2
                    setName = 'blank';     
                    titleStr = ({'Facial motion to blank stim'});
                case 3
                    setName = 'blankLedOff';        
                    titleStr = ({'Facial motion to blank stim LED off'});
                case 4
                    setName = 'blankLedOn';
                    titleStr = ({'Facial motion to blank stim LED on'});
                case 5
                    setName = 'medStimLedOff';
                    titleStr = ({'Facial motion to vis stim LED off'});
                case 6
                    setName = 'medStimLedOn';
                    titleStr = ({'Facial motion to vis stim LED on'});
            end
            titleStr{2} = roi(iRoi).label;

            figure();
            plot(tVec,motionTs(iRoi).(procType).(setName));
            hold all
                plot([tVec(xPosLed(1)) tVec(xPosLed(1))],ylim,'Color','b','linestyle','--','linewidth',2);
                plot([tVec(xPosLed(2)) tVec(xPosLed(2))],ylim,'Color','b','linestyle','--','linewidth',2);
                plot([tVec(xPosStim(1)) tVec(xPosStim(1))],ylim,'Color','k','linestyle','--','linewidth',2);
                plot([tVec(xPosStim(2)) tVec(xPosStim(2))],ylim,'Color','k','linestyle','--','linewidth',2);
            %plot([onsetSeconds onsetSeconds],ylim,'lineWidth',3,'Color','G')
            %plot([offsetSeconds offsetSeconds],ylim,'lineWidth',3,'Color','G')
            plot(tVec,mean(motionTs(iRoi).(procType).(setName)),'LineWidth',3,'Color','k');
            ylabel(yLabel)
            xlabel(xLabel)
            title(titleStr)
            box off
            axis(axF);

            if saveFigs
                figSaveName = fullfile(figDir,['faceMot_' roi(iRoi).label '_' procType '_' setName '_' animalName '_' expDateNum]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end 
        end
    end
end

%----------------------------------------------------------------------
%% Plot comparisons of averaged motion responses
if plotLumpedComparisons
    for iRoi = 1:5
    % These should be the same for all plots
    tVec = (1:size(motionTs(iRoi).(procType).vis,2))/frameNums.faceRate;
    yLabel = 'Pixel Shift';
    xLabel = 'Time (s)';
    for comparisonType = 1:4
        switch comparisonType
            case 1
                setNames = {'blankLedOff','blankLedOn','medStimLedOff','medStimLedOn'};
                titleStr = {'All Conditions'};
                setLegNames = setNames;
            case 2
                setNames = {'blankLedOff','blankLedOn'};
                titleStr = {'Blank Comparison'};
                setLegNames = setNames;
            case 3
                setNames = {'medStimLedOff','medStimLedOn'};
                titleStr = {'Vis Comparison'};
                setLegNames = setNames;
            case 4
                setNames = {'vis','blank'};
                titleStr = {'All Vis vs All Blank'};
                setLegNames = setNames;
        end
        titleStr{2} = roi(iRoi).label;
        
        figure();
        for i = 1:numel(setNames)
            plot(tVec,mean(motionTs(iRoi).(procType).(setNames{i})),'LineWidth',3);
            hold all
        end

        % Terrible hack to get correct ylim
                plot([tVec(xPosLed(1)) tVec(xPosLed(1))],ylim,'Color','b','linestyle','--','linewidth',2);
                plot([tVec(xPosLed(2)) tVec(xPosLed(2))],ylim,'Color','b','linestyle','--','linewidth',2);
                plot([tVec(xPosStim(1)) tVec(xPosStim(1))],ylim,'Color','k','linestyle','--','linewidth',2);
                plot([tVec(xPosStim(2)) tVec(xPosStim(2))],ylim,'Color','k','linestyle','--','linewidth',2);
%        plot([onsetSeconds onsetSeconds],ylim,'lineWidth',3,'Color','G')
%        plot([offsetSeconds offsetSeconds],ylim,'lineWidth',3,'Color','G')
%        plot([onsetSeconds onsetSeconds],ylim,'lineWidth',3,'Color','G')
%        plot([offsetSeconds offsetSeconds],ylim,'lineWidth',3,'Color','G')
        ylabel(yLabel)
        xlabel(xLabel)
        title(titleStr)
        setLegNames{end+1} = 'Stim On/Off';
        lH = legend(setLegNames);
        box off
        axis(axZ);

        if saveFigs
            figSaveName = fullfile(figDir,['faceMot_compare' roi(iRoi).label '_' procType '_' [setNames{:}] ]);
            export_fig(gcf,figSaveName,'-pdf',gcf)
        end
    end
    end
end

%----------------------------------------------------------------------
%% Calculate reponses in a window after stimulus onset (wrt baseline)
procType = 'baselineSub';
moct = 'median';
postStimRespWindowMs = 200;
nFramesRespWindow = floor(postStimRespWindowMs/1000*frameNums.faceRate) - 2;
rowIter = 1;
for iBlock = 1:(nBlocks-12)
    % New col for each stimulus rep / type (should be 1:18)
    colIter = 1;
    for iStim = 1:4
        for iRep = 1:nReps
                ledDaqInds = stimTsInfo.all(iBlock,iStim,iRep).led;
                ledStart   = frameNums.face(ledDaqInds(1));
                ledEnd     = frameNums.face(ledDaqInds(2));

                ptbDaqInds = stimTsInfo.all(iBlock,iStim,iRep).ptb;
                ptbStart   = frameNums.face(ptbDaqInds(1));
                ptbEnd     = frameNums.face(ptbDaqInds(2));

                % establish analysis area around led
                analStart = ledStart - motFramesPrev;
                analEnd   = ledEnd + motFramesPost;

                motionTs(iRoi).all(rowIter,:).ptbOnOff = [(ptbStart - analStart) (ptbEnd - analStart)];
                motionTs(iRoi).all(rowIter,:).ledOnOff = [(ledStart - analStart) (ledEnd - analStart)];

                % Number of frames is somewhat unreliable, truncate all to same length
                framesToUse = analStart:analEnd;
                framesToUse = framesToUse(end-totalMotFrames+1:end);

                % Use the abs motion vector, (x^2 + y^2)^(1/2)
                x = faceMotion.stackRegCell{iRoi}(framesToUse,4);
                y = faceMotion.stackRegCell{iRoi}(framesToUse,3); 
                absPostMotion = sqrt(x.^2 + y.^2);

                preFramesToUse = analStart:ledStart;
                x = faceMotion.stackRegCell{iRoi}(preFramesToUse,4);
                y = faceMotion.stackRegCell{iRoi}(preFramesToUse,3); 
                absPreMotion = sqrt(x.^2 + y.^2);

                motion(iRoi).(setName)(rowIter,colIter) = median(absPreMotion) - median(absPostMotion);
                motion(iRoi).(moct)(rowIter,colIter) = median(faceMotion.stackRegCell{iRoi}(framesToUse,4)) - median(faceMotion.stackRegCell{iRoi}(preFramesToUse,4));
            colIter = colIter + 1;
        end
    end
    rowIter = rowIter + 1;
end

%----------------------------------------------------------------------
%% Plot responses in window pre vs post 
if plotPerStimMotDiff
    for iRoi = 1:5
        moct = 'median';
        % These should be the same for all plots
        yLabel = {'Median Diff Pixel Shift','Pre vs 250ms Post Stimulus Onset'};
        xLabel = 'Stimulus Type';
        titleStr = 'Difference in motion across all block repetitions';
        figure();
        plot(motion(iRoi).(moct)')
        hold all
        plot(mean(motion(iRoi).(moct)),'LineWidth',3,'Color','k');
        ylabel(yLabel)
        xlabel(xLabel)
        set(gca,'Xtick',1:16)
        set(gca,'XtickLabel',{'M','M','M','M','B','B','B','B','M+LED','M+LED','M+LED','M+LED','B+LED','B+LED','B+LED','B+LED'});
        try
            set(gca,'XTickLabelRotation',45)
        catch
            warning('Tick rotation not supported')
        end
        title(titleStr)
        if saveFigs
            figSaveName = fullfile(figDir,['face_mot_diff_' roi(iRoi).label '_' procType '_'  animalName '_' expDateNum]);
            export_fig(gcf,figSaveName,'-pdf',gcf)
        end 
    end
end
