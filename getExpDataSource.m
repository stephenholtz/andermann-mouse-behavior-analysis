function dataDir = getExpDataSource(location)
% Return a directory with the location of my experiments so I
% can switch data source for home vs lab.
%
% SLH 2014
%#ok<*NBRAK,*UNRCH>

switch location 
    case {1,'local'} % Local copy (in amazon zocalo now)
        dataDir = '/Users/stephenholtz/zocalo/andermann_data/';
    case {2,'atlas'} % Andermann Lab server (Atlas server mounted)
        dataDir = '/Volumes/twophoton_data/epi_rig_behavior';
    case {3,'freenas'} % Home file server copy
        dataDir = '/Volumes/dataset1/andermann/';
    otherwise
        error('location input is not recognized')
end

if ~exist(dataDir,'dir')
    warning(['dataDir: ' dataDir ' does not seem to exist.'])
end
