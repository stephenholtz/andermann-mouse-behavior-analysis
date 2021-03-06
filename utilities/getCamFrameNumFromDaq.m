function [fN,ifi] = getCamFrameNumFromDaq(daq,output,ignoreFirst)
%function [frameNum,interFrameInterval] = getCamFrameNumFromDaq(daqData,cameraOutputType,[ignoreFirstStrobeCluster = false])
%
% Determine which points in the DAQ's timeseries correspond to camera 
% frame numbers.
%
% Takes counter data from daq and returns a frame count vector for 
% indexing into. 
%
% Or, takes counter data and cleans it up, returning a frame count vector.
% TODO: figure out what cleaning works for the eye tracking strobes
%
% NOTE: imaqtool generates a set of strobes in the beginning and end that as 
% far as  I can tell are not frames, use ignoreFirst to try to find these 
% and  not use them.
%
% SLH 2014

% Anon func for inter frame onset interval
calcIfi = @(x)(diff([0; find(diff([x(1); x(:)]))]));

switch lower(output)
    case {'strobe'}
        strobeOn = [daq(1) diff(daq) > 0];
        fN = cumsum(strobeOn);
        ifi = calcIfi(fN);
    case {'counter'}
        fN = daq;
        ifi = calcIfi(fN);
        warning('Counter troubleshooting is not yet coded for eye tracking cameras!!')
    otherwise
        error('outputType not recognized')
end

% first frame will have different ifi
ifi = ifi(2:end);

% imaqtool generates a strobe set in the beginning that is not a frame
if ignoreFirst
    % look for a difference from mode, usually very good
    gaps = find(ifi>mode(ifi*1.5));
    if numel(gaps) == 2
        firstReal = gaps(1)+1;
        lastReal = gaps(2)+1;
        % Set bad part of cumsum = 0
        fN(fN < firstReal | fN > lastReal) = 0;
        % Reset first frame to 1 in this strange way
        fN(fN>0) = fN(fN>0) - min(fN(fN>0)) + 1;
    elseif numel(gaps) > 2
        error('Frame rate very inconsistent, check daq output for problems')
    elseif numel(gaps) < 2
        warning('Unable to detect imaqtool acquisition gaps, frame number lookup might suffer.')
    end

    ifi = calcIfi(fN); 
    ifi = ifi(2:end-1);
else
    % Remove the final ifi, which serves as an end point for other part of this
    % gap detection portion (above)
    ifi = ifi(1:end-1);
end
