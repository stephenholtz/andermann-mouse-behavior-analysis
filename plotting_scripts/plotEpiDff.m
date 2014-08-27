%% plotEpiDff.m
% Plot the epi signal in a few ways...
%
% SLH

%% Specify animal/experiment/data location
animalName        = 'K71';
expDateNum        = '20140815_01';
justLoadVariables = 0;
saveFigs          = 1;

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
% Epi imaging tiff path
epiTiffPath = dir([procDir filesep 'epi_*.tiff']);
epiTiffPath = fullfile(procDir,epiTiffPath(1).name);
% Path for nidaq data
nidaqFileName = dir(fullfile(rawDir,'nidaq_*.mat'));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);
% Load data from experiment 'exp' struct
if ~exist('exp','var')
    fprintf('Loading nidaq data\n')
    load(nidaqFilePath);
end

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
nidaqFileName = dir(fullfile(rawDir,'nidaq_*.mat'));
nidaqFilePath = fullfile(rawDir,nidaqFileName(1).name);
if ~exist('exp','var')
    load(nidaqFilePath)
end

%-----------------------------------------------------------
% Load processed variables                  % Struct name:
%-----------------------------------------------------------
load(fullfile(procDir,'faceMotion.mat'));   % faceMotion
load(fullfile(procDir,'frameNums.mat'));    % frameNums
load(fullfile(procDir,'stimTsInfo.mat'));   % stimTsInfo
load(fullfile(procDir,'epiROIs.mat'));      % roi
load(fullfile(procDir,'epiSig.mat'));       % epiSig

% Approximage imaging rates
epiRate  = exp.daqRate*(1/median(frameNums.epiIfi));
faceRate = exp.daqRate*(1/median(frameNums.face));
eyeRate  = exp.daqRate*(1/median(frameNums.eye));

% Clean up variable names to make plotting easier
clear dataDir epiTiffPath expDir nidaqFileName nidaqFilePath rawDir procDir

if justLoadVariables
    disp('BREAK!')
    break
end

%% Group the DFFs for averaging within stimulus types
traceTypes = {'f','fBck','fSub','dff','dffNoSub','fTest'};

recalculateDs = 1;
if ~exist('dS','var') || recalculateDs
    for stimSet = 1:8
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
                stimsToUse = [1 4];
                setName = 'medialStimuli';
            case 8
                stimsToUse = [2 5];
                setName = 'lateralStimuli';
         end

        % Gather all traces in cell arrays temporarily
        for tT = traceTypes 
            traceType = tT{1};
            iRow = 1;
            for iS = stimsToUse
                for iB = 1:size(epiSig,1) 
                    for iR = 1:numel(epiSig(iB,iS,:))
                        % All dff have the same number of frames AFTER the LED
                        % align them so that they all end together, using flip (later unflip)
                        tmpFlip = flip(epiSig(iB,iS,iR).(traceType));
                        dS.(setName).(traceType)(iRow,1:numel(tmpFlip)) = tmpFlip;
                        iRow = iRow + 1;
                    end
                end
            end
            % 'Unflip' the data so that the ends are aligned, it adds, but only at 
            % the beginning so not a huge problem
            dS.(setName).(traceType) = fliplr(dS.(setName).(traceType));
        end
        clear tmpFlip
    end
end
% Clean up while still a script
clear tT iRow iS iR setName traceType stimsToUse

%----------------------------------------------------------------------
%% Plot troubleshooting things
%----------------------------------------------------------------------
epiFrameRate = exp.daqRate/median(frameNums.epiIfi);
fH = figure();
colorOrder = get(gca,'ColorOrder');
close(fH)
% number of aligned frames after LED turns off that *REALLY SHOULD BE* LED free 
nPostToUse = epiSig(1).analFrames(2) - epiSig(1).ledFrames(2) + 1;
nPreToUse = epiSig(1).ledFrames(1) - epiSig(1).analFrames(1);

tVec = (1:size(dS.allStimuli.dff,2))./epiFrameRate;
xPosLedOff = (numel(tVec) - nPostToUse);
xPosLedOn = (nPreToUse);

getBaseLine = @(X,N)(X-median(X(1:N)));
norm2Max = @(X)(X./max(X(:)));
doPlotTroubleshooting = 1;
if doPlotTroubleshooting
    figure()
    plot(255\(getBaseLine(median(dS.blankWithLed.fTest),nPreToUse)))
    hold all
    plot(255\(getBaseLine(median(dS.blankNoLed.fTest),nPreToUse)))
    plot(255\(getBaseLine(median(dS.blankWithLed.f),nPreToUse)))
    plot(255\(getBaseLine(median(dS.blankNoLed.f),nPreToUse)))
    plot([xPosLedOff xPosLedOff],ylim,'Color','g','linestyle','--','linewidth',2);

    % Test area == mostly gcamp free...
    lh = legend('LED ON: F test area','LED OFF: F test area','LED ON: F vis area','LED OFF: F vis area','LED OFF point');
    title('Raw Signal wrt LED');
    ylabel('Median Intensity');
    xlabel('Frame');

    box off
    set(gca,'TickDir','out')

    % adjust axis manually
    axis([46 60 -0.005 0.02])

    if saveFigs
        figSaveName = fullfile(figDir,['epi_raw_troubleshooting_1_' animalName]);
        export_fig(gcf,figSaveName,'-pdf',gcf)
    end 
end

%----------------------------------------------------------------------
%% Plot the combined stimulus responses
%----------------------------------------------------------------------
% Make plots of all responses and their averages
doPlotLumpAllTraces = 1;
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
                    setName = 'medialStimuli';
                    titleStr =({'Medial visual conditions'});
                case 8
                    setName = 'lateralStimuli';
                    titleStr =({'Lateral visual conditions'});
            end
            tVec = (1:size(dS.(setName).dff,2))./epiFrameRate;
            dVec = dS.(setName).dffNoSub;

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
                axis([0 3.1 -0.01 0.065])
                axisStr = 'full';
            elseif axisType == 2
                axis([2.25 3.05 -0.005 0.065])
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
doPlotComparisonTraces = 1;
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
                    setNames = {'medialStimuli','lateralStimuli'};
                    titleStr = ({'Medial vs lateral visual conditions'});
            end

            figure();
            clear eH
            tVec = (1:size(dS.(setNames{1}).dff,2))./epiFrameRate;
            for iSet = 1:numel(setNames)
                dVec = dS.(setNames{iSet}).dffNoSub;
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
                axis([0 3.1 -0.05 0.065])
                axisStr = 'full';
            elseif axisType == 2
                axis([2.25 3.05 -0.005 0.065])
                axisStr = 'zoom';
            end

            if saveFigs
                figSaveName = fullfile(figDir,['epi_comparison_' axisStr '_' [setNames{:}]]);
                export_fig(gcf,figSaveName,'-pdf',gcf)
            end 
        end
    end
end
