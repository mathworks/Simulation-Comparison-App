function app = runSimulationComparisonApp(options)
%runSimulationComparisonApp Compare signals from files or current SDI runs.
%   APP = runSimulationComparisonApp opens an empty comparison app.
%
%   APP = runSimulationComparisonApp(BaselineFile=BASELINE,
%   CompareFile=COMPARE) opens the app and loads the requested MAT-files.
%
%   APP = runSimulationComparisonApp(BaselineRunID=BASELINEID,
%   CompareRunID=COMPAREID) loads current Simulation Data Inspector runs.
%   Specify either a file or a run ID for each role, not both.
%
%   APP = runSimulationComparisonApp(CheckForUpdates=false) skips the
%   GitHub release check performed when a packaged app starts.
%
%   Errors offer to open a prefilled issue in the project GitHub repository.
%
%   APP is a structure containing model, viewModel, and view handles.
% Copyright 2026 The MathWorks, Inc.

arguments
    options.BaselineFile (1, 1) string = ""
    options.CompareFile (1, 1) string = ""
    options.BaselineRunID (1, 1) double = NaN
    options.CompareRunID (1, 1) double = NaN
    options.CheckForUpdates (1, 1) logical = true
    options.IssueReporter (1, 1) function_handle = ...
        @simcompare.IssueReporter.prompt
end

try
    validateSourceOptions(options);

    model = simcompare.Models.ComparisonModel();
    viewModel = simcompare.ViewModels.MainViewModel(model);
    view = simcompare.Views.MainView( ...
        viewModel, ...
        CheckForUpdates=options.CheckForUpdates, ...
        ErrorReporter=options.IssueReporter);

    app = struct( ...
        "model", model, ...
        "viewModel", viewModel, ...
        "view", view);

    view.show();
    if strlength(options.BaselineFile) > 0
        view.loadFile("baseline", options.BaselineFile);
    elseif isfinite(options.BaselineRunID)
        view.loadRun("baseline", options.BaselineRunID);
    end
    if strlength(options.CompareFile) > 0
        view.loadFile("compare", options.CompareFile);
    elseif isfinite(options.CompareRunID)
        view.loadRun("compare", options.CompareRunID);
    end
catch exception
    parentFigure = [];
    if exist("view", "var") && isvalid(view) && ...
            ~isempty(view.Figure) && isvalid(view.Figure)
        parentFigure = view.Figure;
    end
    simcompare.IssueReporter.notify( ...
        options.IssueReporter, exception, "App startup", parentFigure);
    rethrow(exception)
end
end

function validateSourceOptions(options)
validateRunID(options.BaselineRunID, "BaselineRunID");
validateRunID(options.CompareRunID, "CompareRunID");
if strlength(options.BaselineFile) > 0 && ...
        isfinite(options.BaselineRunID)
    error("simcompare:App:ConflictingBaselineSource", ...
        "Specify either BaselineFile or BaselineRunID, not both.");
end
if strlength(options.CompareFile) > 0 && ...
        isfinite(options.CompareRunID)
    error("simcompare:App:ConflictingCompareSource", ...
        "Specify either CompareFile or CompareRunID, not both.");
end
end

function validateRunID(runID, argumentName)
if isnan(runID)
    return
end
if ~isfinite(runID) || runID < 1 || runID ~= fix(runID)
    error("simcompare:App:InvalidRunID", ...
        "%s must be a positive integer run ID.", argumentName);
end
end
