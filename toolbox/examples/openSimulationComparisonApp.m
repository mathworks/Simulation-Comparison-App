%% Open the Simulation Comparison App
% This example shows the supported launch forms without requiring bundled
% simulation data or opening an interactive window during example checks.
% Copyright 2026 The MathWorks, Inc.

%% Open an Empty App
% Choose baseline and comparison MAT-files, current SDI runs, or imported
% MLDATX sessions from the app:
%
%   app = runSimulationComparisonApp;

%% Load Files at Startup
% Pass paths to MAT-files containing
% |Simulink.SimulationData.Dataset| variables:
%
%   app = runSimulationComparisonApp( ...
%       BaselineFile="baseline.mat", ...
%       CompareFile="comparison.mat");

%% Load SDI Runs at Startup
% Pass IDs for runs that are currently in the Simulation Data Inspector:
%
%   app = runSimulationComparisonApp( ...
%       BaselineRunID=baselineRunID, ...
%       CompareRunID=comparisonRunID);

%% Manage the Returned Handles
% The returned structure retains the MVVM objects. To close and release an
% app programmatically:
%
%   delete(app.view);
%   delete(app.viewModel);
%   delete(app.model);
%   clear app

toolboxRoot = fileparts(fileparts(mfilename("fullpath")));
entryPoint = fullfile(toolboxRoot, "runSimulationComparisonApp.m");
assert(isfile(entryPoint), ...
    "The Simulation Comparison App entry point is unavailable.");
disp("Use runSimulationComparisonApp to launch the app.");
