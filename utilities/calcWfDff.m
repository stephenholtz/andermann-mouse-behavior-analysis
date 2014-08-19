function dffTrace = calcWfDff(f,f0)
% Calculate the dff using fixed f0
dffTrace = (f./median(f0)) - 1;
