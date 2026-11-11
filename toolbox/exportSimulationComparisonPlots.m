function exportedFiles = exportSimulationComparisonPlots( ...
        baselineFile, compareFile, options)
%exportSimulationComparisonPlots - Export signal comparison plots
%   FILES = exportSimulationComparisonPlots(BASELINEFILE, COMPAREFILE)
%   exports every uniquely matched, supported signal to a comparison-plots
%   folder in the current folder.
%
%   FILES = exportSimulationComparisonPlots(...,Signals=NAMES,OutputFolder=FOLDER,Format=FORMAT)
%   exports the exact signal NAMES as individual files in FOLDER. FORMAT
%   can be "png", "jpg", "tif", "pdf", or "svg". FILES contains the
%   generated file paths.
%
%   FILES = exportSimulationComparisonPlots(...,BaselineLegendText=BASELINETEXT,CompareLegendText=COMPARETEXT)
%   overrides the label portion of each legend entry. Legend entries use
%   "datasetName | legendLabel". The label defaults are "Baseline" and
%   "Comparison".
%
%   FILES = exportSimulationComparisonPlots(...,ErrorType=TYPE) selects the
%   error calculation. TYPE must be:
%       "Relative" - (default) Signed percentage error.
%       "Absolute" - Absolute difference in signal units.
%
%   Additional options select Dataset variables, set the display time
%   unit, apply a comparison time shift in seconds, set X limits in the
%   selected time unit, and choose the raster resolution. Errors offer to
%   open a prefilled issue in the project GitHub repository before they are
%   rethrown.
% Copyright 2026 The MathWorks, Inc.

arguments
    baselineFile (1, 1) string
    compareFile (1, 1) string
    options.Signals string = strings(1, 0)
    options.OutputFolder (1, 1) string = ...
        fullfile(string(pwd), "comparison-plots")
    options.Format (1, 1) string = "png"
    options.BaselineDatasetName (1, 1) string = ""
    options.CompareDatasetName (1, 1) string = ""
    options.BaselineLegendText (1, 1) string = "Baseline"
    options.CompareLegendText (1, 1) string = "Comparison"
    options.TimeUnit (1, 1) string {mustBeMember( ...
        options.TimeUnit, ["s", "ms", "µs"])} = "s"
    options.ErrorType (1, 1) string {mustBeMember( ...
        options.ErrorType, ["Relative", "Absolute"])} = "Relative"
    options.TimeShiftSeconds (1, 1) double {mustBeFinite} = 0
    options.XLimits (1, 2) double = [NaN, NaN]
    options.Resolution (1, 1) double { ...
        mustBeFinite, mustBePositive} = 150
    options.IssueReporter (1, 1) function_handle = ...
        @simcompare.IssueReporter.prompt
end

try
    model = simcompare.Models.ComparisonModel();
    modelCleanup = onCleanup(@() delete(model));
    model.loadBaseline(baselineFile, options.BaselineDatasetName);
    model.loadCompare(compareFile, options.CompareDatasetName);

    rows = resolveSignalRows(model.Entries, options.Signals);
    selections = makeSelections(model, rows);
    scale = unitScale(options.TimeUnit);
    exportedFiles = simcompare.Exporters.ComparisonPlotExporter.export( ...
        model, selections, ...
        OutputFolder=options.OutputFolder, ...
        Format=options.Format, ...
        TimeUnit=options.TimeUnit, ...
        ErrorType=options.ErrorType, ...
        ShiftSeconds=options.TimeShiftSeconds, ...
        XLimitsSeconds=options.XLimits .* scale, ...
        Resolution=options.Resolution, ...
        BaselineLegendText=options.BaselineLegendText, ...
        CompareLegendText=options.CompareLegendText);
catch exception
    simcompare.IssueReporter.notify( ...
        options.IssueReporter, exception, ...
        "CLI: exportSimulationComparisonPlots");
    rethrow(exception)
end
end

function rows = resolveSignalRows(entries, requestedNames)
selectable = [entries.IsSelectable];
if isempty(requestedNames)
    rows = find(selectable);
    if isempty(rows)
        error("simcompare:Export:NoComparableSignals", ...
            "The datasets contain no uniquely matched, supported signals.");
    end
    return
end

requestedNames = unique(string(requestedNames(:)), "stable");
if any(strlength(requestedNames) == 0)
    error("simcompare:Export:EmptySignalName", ...
        "Signal names cannot be empty.");
end
entryNames = string({entries.Name});
rows = zeros(1, numel(requestedNames));
for index = 1:numel(requestedNames)
    matches = find(entryNames == requestedNames(index));
    if isempty(matches)
        error("simcompare:Export:SignalNotFound", ...
            "Signal '%s' was not found in the comparison.", ...
            requestedNames(index));
    end
    selectableMatches = matches(selectable(matches));
    if isempty(selectableMatches)
        error("simcompare:Export:SignalNotComparable", ...
            "Signal '%s' is not uniquely matched and supported.", ...
            requestedNames(index));
    end
    rows(index) = selectableMatches;
end
end

function selections = makeSelections(model, rows)
selections = repmat( ...
    struct("EntryId", NaN, "Subscripts", 1), 1, numel(rows));
for index = 1:numel(rows)
    entry = model.getEntry(rows(index));
    selections(index) = struct( ...
        "EntryId", entry.Id, ...
        "Subscripts", model.defaultSubscripts(entry.Id));
end
end

function scale = unitScale(unit)
switch unit
    case "s"
        scale = 1;
    case "ms"
        scale = 1e-3;
    case "µs"
        scale = 1e-6;
end
end
