function embedded = getEmbeddedFrameInfo(aviFileCellArray,aviFileDirectory,saveDir)
%%function embedded = getEmbeddedFrameInfo(aviFileCellArray,aviFileDirectory,saveDir)
% 
% embedded: struct with frame by frame timseries of embedded data
%
% NOTE: INCOMPLETE only takes the timestamp information (default config for camera embedding)
% NOTE: This will ONLY work for uncompressed movies, compression occurs
% on the PC, post-compression, values inevitably become unuseable for 
% detecting single frame drops etc.,
%
% Pointgrey camera embeds information in the first few pixels of the
% frames, these have timestamps among other things that can be set
% in the FlyCapture2 Demo program.
%
% From pointgrey documentation:
% The first byte of embedded image data starts at pixel 0,0 (column 0,
% row 0) and continues in the first row of the image data i.e. (1,0),
% (2,0), etc (matlab counts at 1, so adjust)
% 
% Each piece of information takes up 1 quadlet (4 bytes) of the image. 
% When the camera is operating in Y8 (8bits/pixel) mode, this is 
% therefore 4 pixels (cols) worth of data. The types of information that
% can be embedded (e.g. image timestamp, camera shutter and gain settings, 
% etc.) vary between models.
%
% Timestamp:
%   first 7 bits = seconds (0-127)
%   next 13 bits = cycle (0-7999)
%   last 12 bits = cycle offset (repeats each cycle, unsure of value)
%
%   only need the seconds and the cycle to get info on dropped frames
%   (last bits are least significant)
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

% General Flags
verbose     = 1;
saveFlag    = 1;

for iAvi = 1:numel(aviFileCellArray)
    vObj(iAvi) = VideoReader(fullfile(aviFileDirectory,aviFileCellArray{iAvi}));
    if verbose;    fprintf('%s\n',vObj(iAvi).name); end

    % VideoFormat determines how many pixels are needed for the timestamps
    switch vObj(iAvi).VideoFormat
        case {'RGB24','Y8'}
            % Only ever using the first row
            stampRows = 1;
            stampCols = 1:4;
            movieFormat = 'Y8';
            bitsPerPixel = 8;
        otherwise
            error('VideoFormat not accounted for.')
    end

    % read in the information from all of the movie's erames
    [~] = read(vObj(iAvi),inf);
    format = movieFormat;
    nFrames = vObj(iAvi).NumberOfFrames;
    frameStamp = zeros(nFrames,numel(stampCols));

    % Cannot read in subframes with the VideoReader, super duper lame
    % so this is super duper slow
    for iFrame = 1:nFrames
        tmpFrame = read(vObj(iAvi),iFrame);
        frameStamp(iFrame,:) = tmpFrame(1,stampCols);
    end
end

%% Process embedded information
% note this would break for bit-depths > 8, need different inds
embedded.dec            = frameStamp;
embedded.bin            = reshape(dec2bin(frameStamp,bitsPerPixel)',...
                                nFrames,bitsPerPixel*numel(stampCols));
embedded.secCount       = bin2dec(embedded.bin(:,1:7));
embedded.cycleCount     = bin2dec(embedded.bin(:,8:20));
embedded.cycleOffset    = bin2dec(embedded.bin(:,21:32));

% Save raw for later processing
if saveFlag
    if verbose; fprintf('Saving to %s\n',saveDir); end
    save(fullfile(saveDir,'embeddedFrameInfo.m'),'embedded','-v7.3');
end
