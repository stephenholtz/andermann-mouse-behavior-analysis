function Dff = calcWfDff(f,f0)
% Calculate the dff using fixed f0

    Dff = f./median(f0(:)) - 1;
