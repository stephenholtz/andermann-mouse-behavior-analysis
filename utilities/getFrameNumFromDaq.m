function frameNum = getFrameNumFromDaq(daqData,outputType)
%function frameNum = getFrameNumFromDaq(daqData,outputType)
% Determine which points in the DAQ's timeseries correspond to camera frame numbers
%
% Takes counter data from daq and returns a frame count vector for indexing into. 
% Or, takes counter data and cleans it up, returning a frame count vector.
%
% TODO: figure out what cleaning works for the eye tracking strobes
% SLH 2014
switch lower(outputType)
    case {'strobe'}
        strobeOnsets = [daqData(1) diff(daqData) > 0];
        frameNum = cumsum(strobeOnsets);
    case {'counter'}
        frameNum = daqData;
        warning('Counter troubleshooting is not yet coded')
    otherwise
        error('outputType not recognized')
end
