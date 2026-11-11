classdef ComparisonPlotExporter
    %ComparisonPlotExporter Export signal comparisons as individual files.
    % Copyright 2026 The MathWorks, Inc.

    methods (Static)
        function exportedFiles = export(model, selections, options)
            arguments
                model simcompare.Models.ComparisonModel
                selections (1, :) struct
                options.OutputFolder (1, 1) string
                options.Format (1, 1) string = "png"
                options.TimeUnit (1, 1) string {mustBeMember( ...
                    options.TimeUnit, ["s", "ms", "µs"])} = "s"
                options.ShiftSeconds (1, 1) double {mustBeFinite} = 0
                options.XLimitsSeconds (1, 2) double = [NaN, NaN]
                options.ErrorType (1, 1) string {mustBeMember( ...
                    options.ErrorType, ["Relative", "Absolute"])} = ...
                    "Relative"
                options.Resolution (1, 1) double { ...
                    mustBeFinite, mustBePositive} = 150
                options.BaselineLegendText (1, 1) string = ""
                options.CompareLegendText (1, 1) string = ""
                options.ProgressFcn (1, 1) function_handle = ...
                    @(~, ~, ~) []
            end

            validateSelections(selections);
            outputFolder = prepareOutputFolder(options.OutputFolder);
            format = normalizeFormat(options.Format);
            scale = unitScale(options.TimeUnit);
            xLimits = exportLimits( ...
                options.XLimitsSeconds, scale);
            exportedFiles = strings(numel(selections), 1);
            usedStems = strings(0, 1);

            [figureHandle, layout, sourceAxes, errorAxes, ...
                baselineLine, compareLine, errorLine] = ...
                createExportFigure( ...
                    options.TimeUnit, ...
                    options.ErrorType, ...
                    legendDisplayName( ...
                options.BaselineLegendText, ...
                model.BaselineDatasetName, "Baseline"), ...
                legendDisplayName( ...
                options.CompareLegendText, ...
                model.CompareDatasetName, "Comparison"));
            figureCleanup = onCleanup(@() deleteValidFigure(figureHandle));

            for index = 1:numel(selections)
                selection = selections(index);
                entry = model.getEntry(selection.EntryId);
                signalInterpretation = selectionInterpretation(selection);
                result = model.compare( ...
                    entry.Id, selection.Subscripts, options.ShiftSeconds, ...
                    signalInterpretation, options.ErrorType);
                updateExportFigure( ...
                    sourceAxes, errorAxes, baselineLine, ...
                    compareLine, errorLine, result, ...
                    selection.Subscripts, signalInterpretation, ...
                    scale, xLimits);

                stem = uniqueFileStem( ...
                    entry, selection.Subscripts, usedStems, ...
                    outputFolder, format);
                usedStems(end + 1, 1) = stem; %#ok<AGROW>
                exportedFiles(index) = fullfile( ...
                    outputFolder, stem + "." + format);
                writeExport( ...
                    layout, exportedFiles(index), format, ...
                    options.Resolution);
                options.ProgressFcn( ...
                    index, numel(selections), exportedFiles(index));
            end
        end
    end
end

function validateSelections(selections)
if isempty(selections)
    error("simcompare:Export:NoSignals", ...
        "Select at least one signal to export.");
end
requiredFields = ["EntryId", "Subscripts"];
if ~all(isfield(selections, requiredFields))
    error("simcompare:Export:InvalidSelection", ...
        "Each export selection must contain EntryId and Subscripts.");
end
for index = 1:numel(selections)
    entryId = selections(index).EntryId;
    subscripts = selections(index).Subscripts;
    if ~isnumeric(entryId) || ~isscalar(entryId) || ...
            ~isfinite(entryId) || entryId < 1 || entryId ~= fix(entryId)
        error("simcompare:Export:InvalidSelection", ...
            "Each EntryId must be a positive integer.");
    end
    if ~isnumeric(subscripts) || isempty(subscripts) || ...
            ~isrow(subscripts) || any(~isfinite(subscripts)) || ...
            any(subscripts < 1) || any(subscripts ~= fix(subscripts))
        error("simcompare:Export:InvalidSelection", ...
            "Each Subscripts value must be a row of positive integers.");
    end
    if isfield(selections, "SignalInterpretation")
        signalInterpretation = string( ...
            selections(index).SignalInterpretation);
        if ~isscalar(signalInterpretation) || ~ismember( ...
                signalInterpretation, ["Sample-based", "Frame-based"])
            error("simcompare:Export:InvalidSelection", ...
                "SignalInterpretation must be Sample-based or Frame-based.");
        end
    end
end
end

function outputFolder = prepareOutputFolder(outputFolder)
if strlength(strtrim(outputFolder)) == 0
    error("simcompare:Export:EmptyOutputFolder", ...
        "Specify an output folder.");
end
if isfile(outputFolder)
    error("simcompare:Export:OutputIsFile", ...
        "The output path is an existing file: %s", outputFolder);
end
if ~isfolder(outputFolder)
    [created, message] = mkdir(outputFolder);
    if ~created
        error("simcompare:Export:CreateFolderFailed", ...
            "Could not create output folder '%s': %s", ...
            outputFolder, message);
    end
end
if isMATLABReleaseOlderThan("R2025a")
    % filePermissions is unavailable on the minimum supported release.
    [~, attributes] = fileattrib(outputFolder); %#ok<FILEATTRIB>
    outputFolder = string(attributes.Name);
else
    outputFolder = string(filePermissions(outputFolder).AbsolutePath);
end
end

function format = normalizeFormat(format)
format = lower(strtrim(format));
switch format
    case "jpeg"
        format = "jpg";
    case "tiff"
        format = "tif";
end
if ~ismember(format, ["png", "jpg", "tif", "pdf", "svg"])
    error("simcompare:Export:UnsupportedFormat", ...
        "Format must be PNG, JPEG, TIFF, PDF, or SVG.");
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

function limits = exportLimits(seconds, scale)
if all(isnan(seconds))
    limits = [NaN, NaN];
elseif all(isfinite(seconds)) && seconds(1) < seconds(2)
    limits = seconds ./ scale;
else
    error("simcompare:Export:InvalidXLimits", ...
        "X limits must both be NaN or finite increasing values.");
end
end

function [figureHandle, layout, sourceAxes, errorAxes, ...
        baselineLine, compareLine, errorLine] = createExportFigure( ...
        timeUnit, errorType, baselineLegendText, compareLegendText)
figureHandle = figure( ...
    Visible=matlab.lang.OnOffSwitchState.off, ...
    Theme="light", ...
    Color="white", ...
    Position=[100, 100, 1200, 800]);
layout = tiledlayout(figureHandle, 4, 1, ...
    TileSpacing="compact", Padding="compact");

sourceAxes = nexttile(layout, 1, [3, 1]);
sourceAxes.Tag = "ComparisonSourceAxes";
sourceAxes.YLabel.String = "Value";
sourceAxes.XLabel.String = "Time (" + timeUnit + ")";
hold(sourceAxes, matlab.lang.OnOffSwitchState.on);
baselineLine = plot(sourceAxes, NaN, NaN, ...
    DisplayName=baselineLegendText, ...
    LineWidth=1.1);
compareLine = plot(sourceAxes, NaN, NaN, "--", ...
    DisplayName=compareLegendText, ...
    LineWidth=1.1);
hold(sourceAxes, matlab.lang.OnOffSwitchState.off);
grid(sourceAxes, matlab.lang.OnOffSwitchState.on);

errorAxes = nexttile(layout, 4);
errorLine = plot(errorAxes, NaN, NaN, ...
    DisplayName=errorType + " error", LineWidth=1.1);
errorAxes.Tag = "ComparisonErrorAxes";
errorAxes.YLabel.String = errorYAxisLabel(errorType, "");
errorAxes.XLabel.String = "Time (" + timeUnit + ")";
grid(errorAxes, matlab.lang.OnOffSwitchState.on);
end

function name = legendDisplayName(requestedName, datasetName, fallback)
datasetName = strtrim(string(datasetName));
if strlength(datasetName) == 0
    datasetName = fallback;
end
legendLabel = strtrim(string(requestedName));
if strlength(legendLabel) == 0
    legendLabel = fallback;
end
name = datasetName + " | " + legendLabel;
end

function updateExportFigure(sourceAxes, errorAxes, baselineLine, ...
        compareLine, errorLine, result, subscripts, signalInterpretation, ...
        scale, xLimits)
set(baselineLine, ...
    XData=result.BaselineTime ./ scale, ...
    YData=result.BaselineData);
set(compareLine, ...
    XData=result.CompareTime ./ scale, ...
    YData=result.CompareData);
set(errorLine, ...
    XData=result.ErrorTime ./ scale, ...
    YData=result.ErrorData, ...
    DisplayName=result.ErrorType + " error");
updateSourceLegend( ...
    sourceAxes, baselineLine, compareLine, result);

if signalInterpretation == "Frame-based"
    sourceAxes.Title.String = result.Name + " — frame-based samples";
else
    elementText = strjoin(string(subscripts), ",");
    sourceAxes.Title.String = result.Name + ...
        " — element " + elementText;
end
sourceAxes.Title.Interpreter = "none";
errorAxes.Title.String = errorTitle(result);
errorAxes.Title.Interpreter = "none";
errorAxes.YLabel.String = errorYAxisLabel( ...
    result.ErrorType, result.ErrorUnit);
ylim(sourceAxes, "auto");
ylim(errorAxes, "auto");

if all(isfinite(xLimits))
    limits = xLimits;
else
    limits = expandEqualLimits(result.SourceBounds ./ scale);
end
xlim(sourceAxes, limits);
xlim(errorAxes, limits);
drawnow
end

function text = errorTitle(result)
if strlength(result.Interpolation) == 0
    text = result.ErrorType + " error";
else
    text = result.ErrorType + " error (" + ...
        result.Interpolation + " interpolation)";
end
end

function text = errorYAxisLabel(errorType, errorUnit)
if errorType == "Relative"
    text = "Error (%)";
elseif strlength(strtrim(errorUnit)) == 0
    text = "Error";
else
    text = "Error (" + errorUnit + ")";
end
end

function updateSourceLegend(sourceAxes, baselineLine, compareLine, result)
legendLines = gobjects(0, 1);
if ~isempty(result.BaselineTime)
    legendLines(end + 1) = baselineLine;
end
if ~isempty(result.CompareTime)
    legendLines(end + 1) = compareLine;
end
sourceLegend = legend(sourceAxes, legendLines, ...
    Orientation="horizontal", ...
    Interpreter="none");
sourceLegend.Layout.Tile = "north";
end

function signalInterpretation = selectionInterpretation(selection)
if isfield(selection, "SignalInterpretation")
    signalInterpretation = string(selection.SignalInterpretation);
else
    signalInterpretation = "Sample-based";
end
end

function stem = uniqueFileStem( ...
        entry, subscripts, usedStems, outputFolder, format)
stem = sanitizeFileStem(entry.Name);
if entry.BaselineShape ~= "[1]" || entry.CompareShape ~= "[1]"
    elementText = strjoin(string(subscripts), "_");
    stem = stem + "_element_" + elementText;
end
baseStem = stem;
suffix = 2;
while any(strcmpi(stem, usedStems)) || ...
        isfile(fullfile(outputFolder, stem + "." + format))
    stem = baseStem + "_" + suffix;
    suffix = suffix + 1;
end
end

function stem = sanitizeFileStem(name)
stem = strtrim(string(name));
reservedCharacters = ["<", ">", ":", """", "/", "\", "|", "?", "*"];
stem = replace(stem, reservedCharacters, "_");
stem = regexprep(stem, "[\x00-\x1F]", "_");
stem = regexprep(stem, "[ .]+$", "");
if strlength(stem) == 0
    stem = "signal";
end
if ~isempty(regexpi(stem, ...
        "^(con|prn|aux|nul|com[1-9]|lpt[1-9])$", "once"))
    stem = "_" + stem;
end
if strlength(stem) > 120
    stem = extractBefore(stem, 121);
end
end

function writeExport(layout, filePath, format, resolution)
if format == "svg"
    writeSvgExport(layout, filePath);
elseif format == "pdf"
    exportgraphics(layout, filePath, ContentType="vector");
else
    exportgraphics(layout, filePath, Resolution=resolution);
end
end

function writeSvgExport(layout, filePath)
try
    exportgraphics(layout, filePath, ContentType="vector");
catch exception
    if ~strcmp(exception.identifier, ...
            "MATLAB:print:InvalidFileFormatForExport")
        rethrow(exception);
    end
    print(ancestor(layout, "figure"), filePath, "-dsvg");
end
end

function limits = expandEqualLimits(limits)
if ~all(isfinite(limits))
    limits = [0, 1];
elseif limits(1) == limits(2)
    padding = max(1e-9, max(1, abs(limits(1))) * 1e-6);
    limits = limits + [-padding, padding];
end
end

function deleteValidFigure(figureHandle)
if isgraphics(figureHandle)
    delete(figureHandle);
end
end
