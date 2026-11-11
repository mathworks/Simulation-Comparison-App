classdef MainViewModel < handle
    %MainViewModel Observable presentation state for the comparison app.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetObservable, SetAccess = private)
        BaselineFileDisplay string = ""
        CompareFileDisplay string = ""
        BaselineStatus string = "Not loaded"
        CompareStatus string = "Not loaded"
        SignalTable table = table( ...
            false(0, 1), strings(0, 1), strings(0, 1), ...
            strings(0, 1), strings(0, 1), strings(0, 1), ...
            strings(0, 1), strings(0, 1), ...
            VariableNames=[ ...
            "Export", "Name", "Status", "BaselineDataType", ...
            "CompareDataType", "BaselineShape", "CompareShape", ...
            "Details"])
        SelectedRow double = NaN
        SignalInterpretation string = "Sample-based"
        ElementText string = "1"
        SelectionSummary string = "Select a matched signal."
        StatusMessage string = "Choose baseline and comparison sources."
        ErrorType string = "Relative"
        TimeUnit string = "s"
        XMin double = 0
        XMax double = 1
        ShiftValue double = 0
        ShiftLimits double = [-1, 1]
        PlotData struct = struct( ...
            "Name", "", ...
            "BaselineTime", zeros(0, 1), ...
            "BaselineData", zeros(0, 1), ...
            "BaselineUnit", "", ...
            "CompareTime", zeros(0, 1), ...
            "CompareData", zeros(0, 1), ...
            "CompareUnit", "", ...
            "ErrorTime", zeros(0, 1), ...
            "AbsoluteError", zeros(0, 1), ...
            "PercentError", zeros(0, 1), ...
            "ErrorData", zeros(0, 1), ...
            "ErrorType", "Relative", ...
            "ErrorUnit", "", ...
            "Interpolation", "", ...
            "TimeUnit", "s")
        CanCompare logical = false
        IsSelectedSignalScalar logical = false
        CanExport logical = false
        IsExporting logical = false
        FixedPointAvailable logical = false
        FixedPointWarningMessage string = ""
    end

    properties (Access = private)
        Model simcompare.Models.ComparisonModel
        ModelListeners cell = {}
        PendingPairReset logical = false
        PendingSelectedSignalName string = ""
        PendingSingleSourceRestore logical = false
        ShiftSeconds double = 0
        ShiftLimitsSeconds double = [-1, 1]
        XLimitsSeconds double = [0, 1]
        PlotSeconds struct = struct( ...
            "Name", "", ...
            "Subscripts", 1, ...
            "BaselineTime", zeros(0, 1), ...
            "BaselineData", zeros(0, 1), ...
            "BaselineUnit", "", ...
            "CompareTime", zeros(0, 1), ...
            "CompareData", zeros(0, 1), ...
            "CompareUnit", "", ...
            "ErrorTime", zeros(0, 1), ...
            "AbsoluteError", zeros(0, 1), ...
            "PercentError", zeros(0, 1), ...
            "ErrorData", zeros(0, 1), ...
            "ErrorType", "Relative", ...
            "ErrorUnit", "", ...
            "Interpolation", "", ...
            "NearZeroTolerance", NaN, ...
            "Overlap", [NaN, NaN], ...
            "SourceBounds", [0, 1])
    end

    methods
        function obj = MainViewModel(model)
            arguments
                model simcompare.Models.ComparisonModel
            end
            obj.Model = model;
            obj.FixedPointAvailable = model.FixedPointAvailable;
            if ~obj.FixedPointAvailable
                obj.FixedPointWarningMessage = ...
                    "A Fixed-Point Designer license is not available. " + ...
                    "Fixed-point signals are listed but cannot be compared. " + ...
                    "Standard MATLAB numeric and logical signals remain available.";
            end
            obj.ModelListeners{end + 1} = addlistener( ...
                model, "Revision", "PostSet", ...
                @(~, ~) obj.onModelChanged());
            obj.syncFromModel(false, "", false);
        end

        function delete(obj)
            for index = 1:numel(obj.ModelListeners)
                listener = obj.ModelListeners{index};
                if isvalid(listener)
                    delete(listener);
                end
            end
            obj.ModelListeners = {};
        end

        function names = inspectDatasetNamesCommand(obj, filePath)
            arguments
                obj
                filePath (1, 1) string
            end
            try
                names = obj.Model.findDatasetVariables(filePath);
                if isempty(names)
                    obj.StatusMessage = ...
                        "The selected MAT-file contains no SimulationData Dataset.";
                end
            catch exception
                names = strings(1, 0);
                obj.StatusMessage = "Load failed: " + ...
                    string(exception.message);
            end
        end

        function runs = inspectSdiRunsCommand(obj)
            try
                runs = obj.Model.findSdiRuns();
                if isempty(runs)
                    obj.StatusMessage = ...
                        "No Simulation Data Inspector runs are available.";
                else
                    obj.StatusMessage = sprintf( ...
                        "Found %d Simulation Data Inspector run%s.", ...
                        numel(runs), pluralSuffix(numel(runs)));
                end
            catch exception
                runs = struct( ...
                    "RunID", {}, ...
                    "Name", {}, ...
                    "SignalCount", {}, ...
                    "DisplayName", {});
                obj.StatusMessage = "Could not read SDI runs: " + ...
                    string(exception.message);
            end
        end

        function runs = importSdiSessionCommand(obj, filePath)
            arguments
                obj
                filePath (1, 1) string
            end
            try
                runs = obj.Model.importSdiSession(filePath);
                obj.StatusMessage = sprintf( ...
                    "Imported %d SDI run%s from %s.", ...
                    numel(runs), pluralSuffix(numel(runs)), filePath);
            catch exception
                runs = struct( ...
                    "RunID", {}, ...
                    "Name", {}, ...
                    "SignalCount", {}, ...
                    "DisplayName", {});
                obj.StatusMessage = "SDI session import failed: " + ...
                    string(exception.message);
            end
        end

        function success = loadBaselineCommand(obj, filePath, datasetName)
            arguments
                obj
                filePath (1, 1) string
                datasetName (1, 1) string = ""
            end
            success = obj.loadCommand("baseline", filePath, datasetName);
        end

        function success = loadCompareCommand(obj, filePath, datasetName)
            arguments
                obj
                filePath (1, 1) string
                datasetName (1, 1) string = ""
            end
            success = obj.loadCommand("compare", filePath, datasetName);
        end

        function success = loadBaselineRunCommand(obj, runID)
            arguments
                obj
                runID (1, 1) double {mustBeInteger, mustBePositive}
            end
            success = obj.loadRunCommand("baseline", runID);
        end

        function success = loadCompareRunCommand(obj, runID)
            arguments
                obj
                runID (1, 1) double {mustBeInteger, mustBePositive}
            end
            success = obj.loadRunCommand("compare", runID);
        end

        function clearBaselineCommand(obj)
            obj.clearSourceCommand("baseline");
        end

        function clearCompareCommand(obj)
            obj.clearSourceCommand("compare");
        end

        function selectRowCommand(obj, row)
            arguments
                obj
                row (1, 1) double {mustBeInteger, mustBePositive}
            end
            entry = obj.Model.getEntry(row);
            obj.SelectedRow = row;
            obj.SignalInterpretation = "Sample-based";
            if ~entry.IsSelectable
                obj.CanCompare = false;
                obj.IsSelectedSignalScalar = false;
                obj.PlotSeconds = emptyPlotSeconds();
                obj.SelectionSummary = entry.Name + " — " + ...
                    entry.Status;
                obj.StatusMessage = entry.Details;
                obj.refreshPresentation();
                return
            end

            entryId = entry.Id;
            try
                subscripts = obj.Model.parseSubscripts(obj.ElementText);
                obj.Model.validateSubscripts( ...
                    entryId, subscripts, obj.SignalInterpretation);
            catch
                subscripts = obj.Model.defaultSubscripts( ...
                    entryId, obj.SignalInterpretation);
                obj.ElementText = formatSubscripts(subscripts);
            end
            obj.updatePlot(subscripts);
            obj.StatusMessage = "Selected " + entry.Name + ".";
        end

        function setElementCommand(obj, text)
            arguments
                obj
                text (1, 1) string
            end
            if ~obj.hasSelectedMatch()
                obj.StatusMessage = "Select a matched signal first.";
                return
            end
            try
                entry = obj.Model.getEntry(obj.SelectedRow);
                subscripts = obj.Model.parseSubscripts(text);
                obj.Model.validateSubscripts( ...
                    entry.Id, subscripts, obj.SignalInterpretation);
                obj.ElementText = formatSubscripts(subscripts);
                obj.updatePlot(subscripts);
                obj.StatusMessage = "Element " + ...
                    obj.ElementText + " selected.";
            catch exception
                obj.StatusMessage = "Element error: " + ...
                    string(exception.message);
            end
        end

        function setSignalInterpretationCommand(obj, signalInterpretation)
            arguments
                obj
                signalInterpretation (1, 1) string {mustBeMember( ...
                    signalInterpretation, ["Sample-based", "Frame-based"])}
            end
            if ~obj.hasSelectedMatch()
                obj.StatusMessage = "Select a matched signal first.";
                return
            end

            entry = obj.Model.getEntry(obj.SelectedRow);
            previousInterpretation = obj.SignalInterpretation;
            previousElementText = obj.ElementText;
            try
                subscripts = obj.Model.defaultSubscripts( ...
                    entry.Id, signalInterpretation);
                obj.Model.validateSubscripts( ...
                    entry.Id, subscripts, signalInterpretation);
                obj.SignalInterpretation = signalInterpretation;
                obj.ElementText = formatSubscripts(subscripts);
                obj.updatePlot(subscripts);
                obj.StatusMessage = signalInterpretation + ...
                    " interpretation selected.";
            catch exception
                obj.SignalInterpretation = previousInterpretation;
                obj.ElementText = previousElementText;
                obj.StatusMessage = "Interpretation error: " + ...
                    string(exception.message);
            end
        end

        function setTimeUnitCommand(obj, unit)
            arguments
                obj
                unit (1, 1) string {mustBeMember(unit, ...
                    ["s", "ms", "µs"])}
            end
            obj.TimeUnit = unit;
            obj.refreshPresentation();
            obj.StatusMessage = "Time unit set to " + unit + ".";
        end

        function setErrorTypeCommand(obj, errorType)
            arguments
                obj
                errorType (1, 1) string {mustBeMember( ...
                    errorType, ["Relative", "Absolute"])}
            end
            obj.ErrorType = errorType;
            if obj.hasSelectedMatch()
                subscripts = obj.Model.parseSubscripts(obj.ElementText);
                obj.updatePlot(subscripts);
            else
                obj.refreshPresentation();
            end
            obj.StatusMessage = errorType + " error selected.";
        end

        function setXLimitsCommand(obj, minimum, maximum)
            arguments
                obj
                minimum (1, 1) double
                maximum (1, 1) double
            end
            if ~isfinite(minimum) || ~isfinite(maximum) || minimum >= maximum
                obj.StatusMessage = ...
                    "X limits must be finite and X-min must be less than X-max.";
                obj.refreshPresentation();
                return
            end
            scale = unitScale(obj.TimeUnit);
            obj.XLimitsSeconds = [minimum, maximum] .* scale;
            obj.updateShiftLimits();
            obj.refreshPresentation();
            obj.StatusMessage = "X limits updated.";
        end

        function resetViewCommand(obj)
            if ~obj.CanCompare
                obj.StatusMessage = "Select a matched signal first.";
                return
            end
            obj.resetXLimitsFromPlot();
            obj.refreshPresentation();
            obj.StatusMessage = "X view reset to the shifted overlap.";
        end

        function setTimeShiftCommand(obj, shiftValue)
            arguments
                obj
                shiftValue (1, 1) double
            end
            if ~isfinite(shiftValue)
                obj.StatusMessage = "Time shift must be finite.";
                obj.refreshPresentation();
                return
            end
            obj.ShiftSeconds = shiftValue * unitScale(obj.TimeUnit);
            if obj.hasSelectedMatch()
                subscripts = obj.Model.parseSubscripts(obj.ElementText);
                obj.updatePlot(subscripts);
                obj.StatusMessage = sprintf( ...
                    "Comparison shifted by %.9g %s.", ...
                    shiftValue, obj.TimeUnit);
            else
                obj.refreshPresentation();
            end
        end

        function alignComparisonAtPointCommand(obj, selectedX, selectedY)
            arguments
                obj
                selectedX (1, 1) double {mustBeFinite}
                selectedY (1, 1) double {mustBeFinite}
            end
            if ~obj.hasSelectedMatch()
                obj.StatusMessage = "Select a matched signal first.";
                return
            end

            compareTime = obj.PlotData.CompareTime;
            compareData = obj.PlotData.CompareData;
            comparisonX = closestComparisonXAtY( ...
                compareTime, compareData, selectedX, selectedY);
            if ~isfinite(comparisonX)
                obj.StatusMessage = ...
                    "The comparison signal has no finite points to align.";
                return
            end

            shiftDelta = selectedX - comparisonX;
            obj.setTimeShiftCommand(obj.ShiftValue + shiftDelta);
        end

        function zeroShiftCommand(obj)
            obj.setTimeShiftCommand(0);
        end

        function setExportSelectionCommand(obj, row, selected)
            arguments
                obj
                row (1, 1) double {mustBeInteger, mustBePositive}
                selected (1, 1) logical
            end
            if row > height(obj.SignalTable)
                obj.StatusMessage = "The selected export row does not exist.";
                return
            end
            if selected && obj.SignalTable.Status(row) ~= "Matched"
                obj.StatusMessage = ...
                    "Only uniquely matched, supported signals can be exported.";
                selected = false;
            end
            tableData = obj.SignalTable;
            tableData.Export(row) = selected;
            obj.SignalTable = tableData;
            obj.updateCanExport();
        end

        function selectAllForExportCommand(obj)
            if isempty(obj.SignalTable)
                obj.StatusMessage = "Load two datasets before selecting exports.";
                return
            end
            tableData = obj.SignalTable;
            tableData.Export = tableData.Status == "Matched";
            obj.SignalTable = tableData;
            obj.updateCanExport();
            count = sum(tableData.Export);
            obj.StatusMessage = sprintf( ...
                "Selected %d signal%s for export.", ...
                count, pluralSuffix(count));
        end

        function clearExportSelectionCommand(obj)
            tableData = obj.SignalTable;
            tableData.Export(:) = false;
            obj.SignalTable = tableData;
            obj.updateCanExport();
            obj.StatusMessage = "Export selection cleared.";
        end

        function names = getExportableSignalNames(obj)
            names = obj.SignalTable.Name( ...
                obj.SignalTable.Status == "Matched");
        end

        function exportedFiles = exportSelectedPlots( ...
                obj, outputFolder, format, options)
            arguments
                obj
                outputFolder (1, 1) string
                format (1, 1) string
                options.ProgressFcn (1, 1) function_handle = ...
                    @(~, ~, ~) []
                options.Resolution (1, 1) double { ...
                    mustBeFinite, mustBePositive} = 150
                options.BaselineLegendText (1, 1) string = "Baseline"
                options.CompareLegendText (1, 1) string = "Comparison"
            end
            rows = find(obj.SignalTable.Export);
            if isempty(rows)
                error("simcompare:ViewModel:NoExportSelection", ...
                    "Select at least one matched signal to export.");
            end
            exportedFiles = obj.exportRows( ...
                rows, outputFolder, format, ...
                options.ProgressFcn, options.Resolution, ...
                options.BaselineLegendText, ...
                options.CompareLegendText);
        end

        function exportedFile = exportCurrentPlot( ...
                obj, outputFolder, format, options)
            arguments
                obj
                outputFolder (1, 1) string
                format (1, 1) string
                options.ProgressFcn (1, 1) function_handle = ...
                    @(~, ~, ~) []
                options.Resolution (1, 1) double { ...
                    mustBeFinite, mustBePositive} = 150
                options.BaselineLegendText (1, 1) string = "Baseline"
                options.CompareLegendText (1, 1) string = "Comparison"
            end
            if ~obj.hasSelectedMatch()
                error("simcompare:ViewModel:NoSelectedSignal", ...
                    "Select a matched signal to export.");
            end
            exportedFiles = obj.exportRows( ...
                obj.SelectedRow, outputFolder, format, ...
                options.ProgressFcn, options.Resolution, ...
                options.BaselineLegendText, ...
                options.CompareLegendText);
            exportedFile = exportedFiles(1);
        end

        function exportedFiles = exportSignals( ...
                obj, signalNames, outputFolder, format, options)
            arguments
                obj
                signalNames string
                outputFolder (1, 1) string
                format (1, 1) string
                options.ProgressFcn (1, 1) function_handle = ...
                    @(~, ~, ~) []
                options.Resolution (1, 1) double { ...
                    mustBeFinite, mustBePositive} = 150
                options.BaselineLegendText (1, 1) string = "Baseline"
                options.CompareLegendText (1, 1) string = "Comparison"
            end
            rows = obj.resolveSignalRows(signalNames);
            exportedFiles = obj.exportRows( ...
                rows, outputFolder, format, ...
                options.ProgressFcn, options.Resolution, ...
                options.BaselineLegendText, ...
                options.CompareLegendText);
        end

        function seconds = getTimeShiftSeconds(obj)
            seconds = obj.ShiftSeconds;
        end

        function limits = getXLimitsSeconds(obj)
            limits = obj.XLimitsSeconds;
        end
    end

    methods (Access = private)
        function success = loadCommand(obj, role, filePath, datasetName)
            success = false;
            obj.PendingPairReset = true;
            obj.PendingSelectedSignalName = ...
                obj.currentMatchedSignalName();
            obj.PendingSingleSourceRestore = false;
            try
                if role == "baseline"
                    obj.Model.loadBaseline(filePath, datasetName);
                else
                    obj.Model.loadCompare(filePath, datasetName);
                end
                success = true;
                obj.StatusMessage = sprintf( ...
                    "Loaded %s Dataset '%s'.", role, datasetNameOrModel( ...
                    obj.Model, role));
            catch exception
                obj.PendingPairReset = false;
                obj.PendingSelectedSignalName = "";
                obj.PendingSingleSourceRestore = false;
                obj.StatusMessage = "Load failed: " + ...
                    string(exception.message);
            end
        end

        function success = loadRunCommand(obj, role, runID)
            success = false;
            obj.PendingPairReset = true;
            obj.PendingSelectedSignalName = ...
                obj.currentMatchedSignalName();
            obj.PendingSingleSourceRestore = false;
            try
                if role == "baseline"
                    obj.Model.loadBaselineRun(runID);
                else
                    obj.Model.loadCompareRun(runID);
                end
                success = true;
                obj.StatusMessage = sprintf( ...
                    "Loaded %s SDI run %d ('%s').", ...
                    role, runID, datasetNameOrModel(obj.Model, role));
            catch exception
                obj.PendingPairReset = false;
                obj.PendingSelectedSignalName = "";
                obj.PendingSingleSourceRestore = false;
                obj.StatusMessage = "Load failed: " + ...
                    string(exception.message);
            end
        end

        function clearSourceCommand(obj, role)
            obj.PendingPairReset = true;
            obj.PendingSelectedSignalName = ...
                obj.currentMatchedSignalName();
            obj.PendingSingleSourceRestore = true;
            if role == "baseline"
                obj.Model.clearBaseline();
                obj.StatusMessage = "Baseline source cleared.";
            else
                obj.Model.clearCompare();
                obj.StatusMessage = "Comparison source cleared.";
            end
        end

        function onModelChanged(obj)
            resetPair = obj.PendingPairReset;
            selectedSignalName = obj.PendingSelectedSignalName;
            allowSingleSource = obj.PendingSingleSourceRestore;
            obj.PendingPairReset = false;
            obj.PendingSelectedSignalName = "";
            obj.PendingSingleSourceRestore = false;
            obj.syncFromModel( ...
                resetPair, selectedSignalName, allowSingleSource);
        end

        function syncFromModel( ...
                obj, resetPair, selectedSignalName, allowSingleSource)
            obj.BaselineFileDisplay = obj.Model.BaselineSourceDisplay;
            obj.CompareFileDisplay = obj.Model.CompareSourceDisplay;
            if obj.Model.hasBaseline()
                obj.BaselineStatus = sourceStatus( ...
                    obj.Model, "baseline", ...
                    obj.Model.getBaselineSignalCount());
            else
                obj.BaselineStatus = "Not loaded";
            end
            if obj.Model.hasCompare()
                obj.CompareStatus = sourceStatus( ...
                    obj.Model, "compare", ...
                    obj.Model.getCompareSignalCount());
            else
                obj.CompareStatus = "Not loaded";
            end
            selectedExportNames = obj.SignalTable.Name( ...
                obj.SignalTable.Export);
            signalTable = entriesTable(obj.Model.Entries);
            signalTable.Export = signalTable.Status == "Matched" & ...
                ismember(signalTable.Name, selectedExportNames);
            obj.SignalTable = signalTable;
            obj.updateCanExport();

            if ~obj.Model.hasBaseline() && ~obj.Model.hasCompare()
                obj.ShiftSeconds = 0;
                obj.ShiftLimitsSeconds = [-1, 1];
                obj.XLimitsSeconds = [0, 1];
                obj.clearSelection();
                return
            end
            if resetPair
                if obj.restoreSelection( ...
                        selectedSignalName, allowSingleSource)
                    return
                end
                obj.ShiftSeconds = 0;
                obj.selectFirstMatched(true);
                return
            end
            if ~obj.hasSelectedMatch()
                obj.selectFirstMatched(false);
            else
                subscripts = obj.Model.parseSubscripts(obj.ElementText);
                obj.updatePlot(subscripts);
            end
        end

        function signalName = currentMatchedSignalName(obj)
            signalName = "";
            if ~obj.Model.hasPair() || ~obj.hasSelectedMatch()
                return
            end
            entry = obj.Model.getEntry(obj.SelectedRow);
            if entry.Status == "Matched"
                signalName = entry.Name;
            end
        end

        function restored = restoreSelection( ...
                obj, signalName, allowSingleSource)
            restored = false;
            if strlength(signalName) == 0
                return
            end

            entries = obj.Model.Entries;
            eligible = [entries.IsSelectable];
            if ~allowSingleSource
                eligible = eligible & ...
                    string({entries.Status}) == "Matched";
            end
            rows = find( ...
                string({entries.Name}) == signalName & eligible);
            if ~isscalar(rows)
                return
            end

            entry = entries(rows);
            try
                subscripts = obj.Model.parseSubscripts(obj.ElementText);
                obj.Model.validateSubscripts( ...
                    entry.Id, subscripts, obj.SignalInterpretation);
            catch
                return
            end

            obj.SelectedRow = rows;
            obj.updatePlot(subscripts);
            restored = true;
        end

        function selectFirstMatched(obj, resetLimits)
            rows = find([obj.Model.Entries.IsSelectable], 1);
            if isempty(rows)
                obj.clearSelection();
                obj.StatusMessage = ...
                    "No uniquely matched, supported signals are available.";
                return
            end
            obj.SelectedRow = rows;
            obj.SignalInterpretation = "Sample-based";
            entry = obj.Model.getEntry(rows);
            subscripts = obj.Model.defaultSubscripts( ...
                entry.Id, obj.SignalInterpretation);
            obj.ElementText = formatSubscripts(subscripts);
            obj.updatePlot(subscripts);
            if resetLimits
                obj.resetXLimitsFromPlot();
                obj.refreshPresentation();
            end
        end

        function updatePlot(obj, subscripts)
            entry = obj.Model.getEntry(obj.SelectedRow);
            obj.PlotSeconds = obj.Model.compare( ...
                entry.Id, subscripts, obj.ShiftSeconds, ...
                obj.SignalInterpretation, obj.ErrorType);
            obj.CanCompare = true;
            obj.IsSelectedSignalScalar = obj.Model.isScalar( ...
                entry.Id, obj.SignalInterpretation);
            obj.SelectionSummary = sprintf( ...
                "%s  |  baseline %s  |  comparison %s  |  %s", ...
                entry.Name, entry.BaselineShape, entry.CompareShape, ...
                obj.SignalInterpretation);
            obj.updateShiftLimits();
            obj.refreshPresentation();
        end

        function updateShiftLimits(obj)
            limits = obj.XLimitsSeconds;
            span = limits(2) - limits(1);
            if ~isfinite(span) || span <= 0
                bounds = obj.PlotSeconds.SourceBounds;
                span = bounds(2) - bounds(1);
            end
            if ~isfinite(span) || span <= 0
                span = max(1e-6, max(abs(obj.PlotSeconds.SourceBounds)));
            end
            limit = max([span, abs(obj.ShiftSeconds) * 1.1, 1e-9]);
            obj.ShiftLimitsSeconds = [-limit, limit];
        end

        function resetXLimitsFromPlot(obj)
            overlap = obj.PlotSeconds.Overlap;
            if all(isfinite(overlap))
                limits = overlap;
            else
                limits = obj.PlotSeconds.SourceBounds;
            end
            obj.XLimitsSeconds = expandEqualLimits(limits);
            obj.updateShiftLimits();
        end

        function refreshPresentation(obj)
            scale = unitScale(obj.TimeUnit);
            obj.XMin = obj.XLimitsSeconds(1) / scale;
            obj.XMax = obj.XLimitsSeconds(2) / scale;
            obj.ShiftValue = obj.ShiftSeconds / scale;
            obj.ShiftLimits = obj.ShiftLimitsSeconds / scale;

            source = obj.PlotSeconds;
            obj.PlotData = struct( ...
                "Name", source.Name, ...
                "BaselineTime", source.BaselineTime / scale, ...
                "BaselineData", source.BaselineData, ...
                "BaselineUnit", source.BaselineUnit, ...
                "CompareTime", source.CompareTime / scale, ...
                "CompareData", source.CompareData, ...
                "CompareUnit", source.CompareUnit, ...
                "ErrorTime", source.ErrorTime / scale, ...
                "AbsoluteError", source.AbsoluteError, ...
                "PercentError", source.PercentError, ...
                "ErrorData", source.ErrorData, ...
                "ErrorType", obj.ErrorType, ...
                "ErrorUnit", source.ErrorUnit, ...
                "Interpolation", source.Interpolation, ...
                "TimeUnit", obj.TimeUnit);
        end

        function clearSelection(obj)
            obj.SelectedRow = NaN;
            obj.SignalInterpretation = "Sample-based";
            obj.ElementText = "1";
            obj.SelectionSummary = "Select a matched signal.";
            obj.CanCompare = false;
            obj.IsSelectedSignalScalar = false;
            obj.PlotSeconds = emptyPlotSeconds();
            obj.refreshPresentation();
        end

        function tf = hasSelectedMatch(obj)
            tf = isfinite(obj.SelectedRow) && ...
                obj.SelectedRow >= 1 && ...
                obj.SelectedRow <= numel(obj.Model.Entries) && ...
                obj.Model.Entries(obj.SelectedRow).IsSelectable;
        end

        function updateCanExport(obj)
            obj.CanExport = ~isempty(obj.SignalTable) && ...
                any(obj.SignalTable.Export);
        end

        function rows = resolveSignalRows(obj, requestedNames)
            requestedNames = unique(string(requestedNames(:)), "stable");
            if isempty(requestedNames)
                error("simcompare:ViewModel:NoExportSelection", ...
                    "Specify at least one signal name to export.");
            end
            if any(strlength(requestedNames) == 0)
                error("simcompare:ViewModel:EmptySignalName", ...
                    "Signal names cannot be empty.");
            end

            tableNames = obj.SignalTable.Name;
            rows = zeros(1, numel(requestedNames));
            for index = 1:numel(requestedNames)
                matches = find(tableNames == requestedNames(index));
                if isempty(matches)
                    error("simcompare:ViewModel:SignalNotFound", ...
                        "Signal '%s' was not found in the comparison.", ...
                        requestedNames(index));
                end
                matches = matches( ...
                    obj.SignalTable.Status(matches) == "Matched");
                if ~isscalar(matches)
                    error("simcompare:ViewModel:SignalNotComparable", ...
                        "Signal '%s' is not uniquely matched and supported.", ...
                        requestedNames(index));
                end
                rows(index) = matches;
            end
        end

        function exportedFiles = exportRows( ...
                obj, rows, outputFolder, format, progressFcn, resolution, ...
                baselineLegendText, compareLegendText)
            if obj.IsExporting
                error("simcompare:ViewModel:ExportInProgress", ...
                    "A plot export is already in progress.");
            end
            obj.IsExporting = true;
            exportCleanup = onCleanup(@() obj.finishExport());
            try
                selections = obj.makeExportSelections(rows);
                exportedFiles = ...
                    simcompare.Exporters.ComparisonPlotExporter.export( ...
                    obj.Model, selections, ...
                    OutputFolder=outputFolder, ...
                    Format=format, ...
                    TimeUnit=obj.TimeUnit, ...
                    ShiftSeconds=obj.ShiftSeconds, ...
                    XLimitsSeconds=obj.XLimitsSeconds, ...
                    ErrorType=obj.ErrorType, ...
                    Resolution=resolution, ...
                    BaselineLegendText=baselineLegendText, ...
                    CompareLegendText=compareLegendText, ...
                    ProgressFcn=progressFcn);
                obj.StatusMessage = sprintf( ...
                    "Exported %d comparison plot%s to %s.", ...
                    numel(exportedFiles), ...
                    pluralSuffix(numel(exportedFiles)), outputFolder);
            catch exception
                obj.StatusMessage = "Export failed: " + ...
                    string(exception.message);
                rethrow(exception)
            end
        end

        function selections = makeExportSelections(obj, rows)
            selections = repmat( ...
                struct( ...
                "EntryId", NaN, ...
                "Subscripts", 1, ...
                "SignalInterpretation", "Sample-based"), ...
                1, numel(rows));
            for index = 1:numel(rows)
                entry = obj.Model.getEntry(rows(index));
                if rows(index) == obj.SelectedRow
                    subscripts = obj.Model.parseSubscripts( ...
                        obj.ElementText);
                    signalInterpretation = obj.SignalInterpretation;
                else
                    signalInterpretation = "Sample-based";
                    subscripts = obj.Model.defaultSubscripts( ...
                        entry.Id, signalInterpretation);
                end
                obj.Model.validateSubscripts( ...
                    entry.Id, subscripts, signalInterpretation);
                selections(index) = struct( ...
                    "EntryId", entry.Id, ...
                    "Subscripts", subscripts, ...
                    "SignalInterpretation", signalInterpretation);
            end
        end

        function finishExport(obj)
            obj.IsExporting = false;
        end
    end
end

function tableData = entriesTable(entries)
if isempty(entries)
    tableData = table( ...
        false(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), ...
        VariableNames=[ ...
        "Export", "Name", "Status", "BaselineDataType", ...
        "CompareDataType", "BaselineShape", "CompareShape", ...
        "Details"]);
    return
end
tableData = table( ...
    false(numel(entries), 1), ...
    string({entries.Name}).', ...
    string({entries.Status}).', ...
    string({entries.BaselineDataType}).', ...
    string({entries.CompareDataType}).', ...
    string({entries.BaselineShape}).', ...
    string({entries.CompareShape}).', ...
    string({entries.Details}).', ...
    VariableNames=[ ...
    "Export", "Name", "Status", "BaselineDataType", ...
    "CompareDataType", "BaselineShape", "CompareShape", ...
    "Details"]);
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

function limits = expandEqualLimits(limits)
if ~all(isfinite(limits))
    limits = [0, 1];
elseif limits(1) == limits(2)
    padding = max(1e-9, max(1, abs(limits(1))) * 1e-6);
    limits = limits + [-padding, padding];
end
end

function comparisonX = closestComparisonXAtY( ...
        compareTime, compareData, selectedX, selectedY)
valid = isfinite(compareTime) & isfinite(compareData);
if ~any(valid)
    comparisonX = NaN;
    return
end

segmentValid = valid(1:end - 1) & valid(2:end);
x1 = compareTime(1:end - 1);
x2 = compareTime(2:end);
y1 = compareData(1:end - 1);
y2 = compareData(2:end);

varying = segmentValid & y1 ~= y2;
fraction = (selectedY - y1(varying)) ./ ...
    (y2(varying) - y1(varying));
crosses = fraction >= 0 & fraction <= 1;
varyingX1 = x1(varying);
varyingX2 = x2(varying);
crossingX = varyingX1(crosses) + fraction(crosses) .* ...
    (varyingX2(crosses) - varyingX1(crosses));

flat = segmentValid & y1 == selectedY & y2 == selectedY;
flatMinimum = min(x1(flat), x2(flat));
flatMaximum = max(x1(flat), x2(flat));
flatX = min(max(selectedX, flatMinimum), flatMaximum);
crossingX = [crossingX; flatX];

if isempty(crossingX)
    validIndices = find(valid);
    yDistance = abs(compareData(valid) - selectedY);
    closestY = min(yDistance);
    candidates = validIndices(yDistance == closestY);
    [~, nearestCandidate] = min( ...
        abs(compareTime(candidates) - selectedX));
    comparisonX = compareTime(candidates(nearestCandidate));
else
    [~, closestCrossing] = min(abs(crossingX - selectedX));
    comparisonX = crossingX(closestCrossing);
end
end

function text = formatSubscripts(subscripts)
text = strjoin(string(subscripts), ",");
end

function suffix = pluralSuffix(count)
if count == 1
    suffix = "";
else
    suffix = "s";
end
end

function value = datasetNameOrModel(model, role)
if role == "baseline"
    value = model.BaselineDatasetName;
else
    value = model.CompareDatasetName;
end
end

function text = sourceStatus(model, role, signalCount)
if role == "baseline"
    runID = model.BaselineRunID;
    datasetName = model.BaselineDatasetName;
else
    runID = model.CompareRunID;
    datasetName = model.CompareDatasetName;
end
if isfinite(runID)
    text = sprintf( ...
        "SDI run %d: %s (%d signals)", ...
        runID, datasetName, signalCount);
else
    text = sprintf( ...
        "Loaded %s (%d signals)", ...
        datasetName, signalCount);
end
end

function plotData = emptyPlotSeconds()
plotData = struct( ...
    "Name", "", ...
    "Subscripts", 1, ...
    "BaselineTime", zeros(0, 1), ...
    "BaselineData", zeros(0, 1), ...
    "BaselineUnit", "", ...
    "CompareTime", zeros(0, 1), ...
    "CompareData", zeros(0, 1), ...
    "CompareUnit", "", ...
    "ErrorTime", zeros(0, 1), ...
    "AbsoluteError", zeros(0, 1), ...
    "PercentError", zeros(0, 1), ...
    "ErrorData", zeros(0, 1), ...
    "ErrorType", "Relative", ...
    "ErrorUnit", "", ...
    "Interpolation", "", ...
    "NearZeroTolerance", NaN, ...
    "Overlap", [NaN, NaN], ...
    "SourceBounds", [0, 1]);
end
