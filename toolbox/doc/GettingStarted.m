%[text] # Getting Started with Simulation Comparison App
%[text] Simulation Comparison App compares matching signals stored in two `Simulink.SimulationData.Dataset` variables loaded from MAT-files, current Simulation Data Inspector (SDI) runs, or saved SDI sessions. It supports signal-element selection, visual time shifting, synchronized source plots, and relative or absolute error analysis.
%[text] Copyright 2026 The MathWorks, Inc.
%[text] ## Verify the Installation
%[text] Confirm that the public entry point is available on the MATLAB path.
toolboxRoot = fileparts(fileparts(mfilename("fullpath")));
entryPoint = fullfile(toolboxRoot, "runSimulationComparisonApp.m");
assert(isfile(entryPoint), ...
    "The Simulation Comparison App entry point is unavailable.");
disp("Simulation Comparison App is ready.");
%%
%[text] ## Open an Empty App
%[text] Run the following command when you want to choose files interactively:
%[text] ```matlabCodeExample
%[text] app = runSimulationComparisonApp;
%[text] ```
%[text] Packaged versions check GitHub for a newer stable release at startup using the public API without credentials. If one is available, choose `Download` to open its release page or `Later` to continue. Network failures and unavailable releases are ignored silently. To skip the check, call `runSimulationComparisonApp(CheckForUpdates=false)`.
%[text] ## Load Two Simulation Results
%[text] Supply MAT-files at startup with name-value arguments:
%[text] ```matlabCodeExample
%[text] app = runSimulationComparisonApp( ...
%[text]     BaselineFile="baseline.mat", ...
%[text]     CompareFile="comparison.mat");
%[text] ```
%[text] Each MAT-file must contain a `Simulink.SimulationData.Dataset` variable. When a file contains more than one Dataset variable, the app prompts you to choose one.
%[text] To select a current SDI run, click `SDI...` beside either source. The chooser lists each run by name, run ID, and signal count. Current SDI runs can also be loaded at startup:
%[text] ```matlabCodeExample
%[text] app = runSimulationComparisonApp( ...
%[text]     BaselineRunID=baselineRunID, ...
%[text]     CompareRunID=comparisonRunID);
%[text] ```
%[text] To load an exported SDI session, click `Browse...`, choose its `.mldatx` file, and then select one of the imported runs. Existing runs in the current SDI repository are preserved.
%[text] Click the `×` button beside either source to clear it. The signal table and plots refresh from the remaining source, or clear completely when neither source remains selected.
%[text] Specify either a MAT-file or an SDI run ID for each role, not both.
%[text] Fixed-point comparison requires an available Fixed-Point Designer license. Without one, the app displays a warning and lists fixed-point signals as unavailable. Standard MATLAB numeric and logical signals remain comparable.
%[text] ## Compare Signals and Elements
%[text] Select a matched signal in the table. For vector or multidimensional signals, enter one-based subscripts such as `2` or `2,3`. Positive time shift values move the comparison trace to the right.
%[text] ## Select the Error Type
%[text] The lower plot evaluates the comparison signal on baseline timestamps within the shifted overlap. Relative error is selected by default and displays:
%[text] ```matlabCodeExample
%[text] 100 * (comparison - baseline) / abs(baseline)
%[text] ```
%[text] Absolute error displays `abs(comparison - baseline)` in the baseline signal's unit. The selected error type persists when signals or datasets change. Near-zero baseline samples appear as gaps for relative error, and unavailable interpolated samples appear as gaps for either type.
%[text] ## Export Comparison Plots
%[text] In the app, mark signals in the `Export` column, choose an output format, and click `Export selected to folder...`. The app writes one two-panel comparison plot per selected signal. To export only the currently displayed signal, click `Quick export current`. The plot is written to the current MATLAB folder in the selected format.
%[text] Export selected signals without opening the app:
%[text] ```matlabCodeExample
%[text] files = exportSimulationComparisonPlots( ...
%[text]     "baseline.mat", "comparison.mat", ...
%[text]     Signals=["speed", "torque"], ...
%[text]     OutputFolder="comparison-plots", ...
%[text]     Format="png", ...
%[text]     ErrorType="Absolute");
%[text] ```
%[text] Supported formats are PNG, JPEG, TIFF, PDF, and SVG. `ErrorType` accepts `Relative` (the default) or `Absolute`. Omitting `Signals` exports every uniquely matched, supported signal.
%[text] ## Report an Error
%[text] If MATLAB encounters an error while starting the app, handling an app action, or running `exportSimulationComparisonPlots`, you can open a prefilled issue in the project GitHub repository. The draft includes the error identifier, context, MATLAB and app versions, platform, and stack trace. Review the draft before submitting it. The issue is created by your signed-in GitHub account.
%[text] ## Next Steps
%[text] - Read function help: `help runSimulationComparisonApp`
%[text] - Read export help: `help exportSimulationComparisonPlots`
%[text] - Open the launch example: `open examples/openSimulationComparisonApp.m` \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright"}
%---
