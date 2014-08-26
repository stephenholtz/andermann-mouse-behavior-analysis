%% Rough outline of workflow for ChR2 Experiment Data
% Just for documentation, not really meant to be run
%
% ./utilities:           are meant to be generally useful
% ./processing_scripts:  long preparatory scripts
% ./ml_anal_helpers:     for monkeylogic exp analysis
% ./ptb_anal_helpers:    for psychtoolbox exp analysis
%
% ./.... others should hopefully be self explanatory
%
% SLH 2014

%------------------------------------------------------------------
%% Psych toolbox experiments
%------------------------------------------------------------------

%% Preprocessing:
%   Preprocess heterogenous videos/images to common format (BigTiff
%   and .mat) and retrieve frame timing information from nidaq data

% Script to run all of preprocessing functions
preprocessChR2Exp;
% uses functions in the ./utilities and ./ptb_anal_helpers

%% Process image file data:
%   Run analysis on images to retrieve motion etc.,
%   Also, calculate DF/F for ROIs on epi images during each stimulus
%   repitition etc.,
   
% Script for 'data' processing
processChR2ExpData;

%% Analysis/plotting
%   Rough analysis and plotting scripts, using processed data

% Scripts to plot per stimulus motion / DFF / eye dilation

%------------------------------------------------------------------
%% Monkeylogic experiments
%------------------------------------------------------------------

