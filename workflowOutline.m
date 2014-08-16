%% Rough outline of workflow for ChR2 Experiment Data
% (will probably quickly change)
%
% SLH 2014

%% Preprocessing:
%   Preprocess heterogenous videos/images to common format (BigTiff
%   and .mat) and retrieve frame timing information from nidaq data

% Script to run all of preprocessing functions
preprocessChR2Exp;

%% Process image file data:
%   Run analysis on images to retrieve motion etc.,
%   Also, calculate DF/F for ROIs on epi images during each stimulus
%   repitition etc.,
   
% Script for 'data' processing
processChR2ExpData;

%% Analysis/plotting
%   Rough analysis and plotting scripts, using processed data

% Scripts to plot per stimulus motion / DFF / eye dilation
plotPerStimulusBehaviorActivity;
plotPerStimulusDff;
