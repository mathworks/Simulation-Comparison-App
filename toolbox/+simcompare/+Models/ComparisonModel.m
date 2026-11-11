classdef ComparisonModel < handle
    %ComparisonModel Load and compare logged Simulink Dataset signals.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetObservable, SetAccess = private)
        BaselineFile string = ""
        CompareFile string = ""
        BaselineRunID double = NaN
        CompareRunID double = NaN
        BaselineSourceDisplay string = ""
        CompareSourceDisplay string = ""
        BaselineDatasetName string = ""
        CompareDatasetName string = ""
        FixedPointAvailable logical = false
        Entries struct = struct( ...
            "Id", {}, ...
            "Name", {}, ...
            "Status", {}, ...
            "BaselineIndex", {}, ...
            "CompareIndex", {}, ...
            "BaselineDataType", {}, ...
            "CompareDataType", {}, ...
            "BaselineShape", {}, ...
            "CompareShape", {}, ...
            "Details", {}, ...
            "IsSelectable", {})
        Revision double = 0
    end

    properties (Access = private)
        BaselineDataset = []
        CompareDataset = []
        BaselineRecords struct = struct( ...
            "Name", {}, "Values", {}, "Metadata", {})
        CompareRecords struct = struct( ...
            "Name", {}, "Values", {}, "Metadata", {})
    end

    methods
        function obj = ComparisonModel(options)
            arguments
                options.FixedPointAvailable (1, 1) logical = ...
                    simcompare.Models.ComparisonModel.detectFixedPointSupport()
            end
            obj.FixedPointAvailable = options.FixedPointAvailable;
        end

        function loadBaseline(obj, filePath, datasetName)
            arguments
                obj
                filePath (1, 1) string
                datasetName (1, 1) string = ""
            end
            obj.loadFileRole("baseline", filePath, datasetName);
        end

        function loadCompare(obj, filePath, datasetName)
            arguments
                obj
                filePath (1, 1) string
                datasetName (1, 1) string = ""
            end
            obj.loadFileRole("compare", filePath, datasetName);
        end

        function loadBaselineRun(obj, runID)
            arguments
                obj
                runID (1, 1) double {mustBeInteger, mustBePositive}
            end
            obj.loadRunRole("baseline", runID);
        end

        function loadCompareRun(obj, runID)
            arguments
                obj
                runID (1, 1) double {mustBeInteger, mustBePositive}
            end
            obj.loadRunRole("compare", runID);
        end

        function clearBaseline(obj)
            obj.commitRole( ...
                "baseline", [], emptyRecords(), "", "", NaN, "");
        end

        function clearCompare(obj)
            obj.commitRole( ...
                "compare", [], emptyRecords(), "", "", NaN, "");
        end

        function tf = hasBaseline(obj)
            tf = ~isempty(obj.BaselineDataset);
        end

        function tf = hasCompare(obj)
            tf = ~isempty(obj.CompareDataset);
        end

        function tf = hasPair(obj)
            tf = obj.hasBaseline() && obj.hasCompare();
        end

        function count = getBaselineSignalCount(obj)
            count = numel(obj.BaselineRecords);
        end

        function count = getCompareSignalCount(obj)
            count = numel(obj.CompareRecords);
        end

        function entry = getEntry(obj, row)
            arguments
                obj
                row (1, 1) double {mustBeInteger, mustBePositive}
            end
            if row > numel(obj.Entries)
                error("simcompare:Model:EntryOutOfRange", ...
                    "Signal-table row %d does not exist.", row);
            end
            entry = obj.Entries(row);
        end

        function subscripts = defaultSubscripts( ...
                obj, entryId, signalInterpretation)
            arguments
                obj
                entryId (1, 1) double {mustBeInteger, mustBePositive}
                signalInterpretation (1, 1) string {mustBeMember( ...
                    signalInterpretation, ["Sample-based", "Frame-based"])} = ...
                    "Sample-based"
            end
            entry = obj.findEntry(entryId);
            obj.assertMatched(entry);
            if signalInterpretation == "Frame-based"
                subscripts = 1;
                return
            end
            rank = 1;
            if isfinite(entry.BaselineIndex)
                rank = max(rank, numel(obj.BaselineRecords( ...
                    entry.BaselineIndex).Metadata.Shape));
            end
            if isfinite(entry.CompareIndex)
                rank = max(rank, numel(obj.CompareRecords( ...
                    entry.CompareIndex).Metadata.Shape));
            end
            subscripts = ones(1, max(1, rank));
        end

        function tf = isScalar(obj, entryId, signalInterpretation)
            arguments
                obj
                entryId (1, 1) double {mustBeInteger, mustBePositive}
                signalInterpretation (1, 1) string {mustBeMember( ...
                    signalInterpretation, ["Sample-based", "Frame-based"])} = ...
                    "Sample-based"
            end
            entry = obj.findEntry(entryId);
            obj.assertMatched(entry);
            if signalInterpretation == "Frame-based"
                tf = true;
                return
            end
            tf = true;
            if isfinite(entry.BaselineIndex)
                baselineShape = obj.BaselineRecords( ...
                    entry.BaselineIndex).Metadata.Shape;
                tf = tf && prod(baselineShape) == 1;
            end
            if isfinite(entry.CompareIndex)
                compareShape = obj.CompareRecords( ...
                    entry.CompareIndex).Metadata.Shape;
                tf = tf && prod(compareShape) == 1;
            end
        end

        function validateSubscripts( ...
                obj, entryId, subscripts, signalInterpretation)
            arguments
                obj
                entryId (1, 1) double {mustBeInteger, mustBePositive}
                subscripts (1, :) double
                signalInterpretation (1, 1) string {mustBeMember( ...
                    signalInterpretation, ["Sample-based", "Frame-based"])} = ...
                    "Sample-based"
            end
            entry = obj.findEntry(entryId);
            obj.assertMatched(entry);

            if isempty(subscripts) || any(~isfinite(subscripts)) || ...
                    any(subscripts < 1) || any(subscripts ~= fix(subscripts))
                error("simcompare:Model:InvalidSubscripts", ...
                    "Element subscripts must be positive integers.");
            end
            if signalInterpretation == "Frame-based"
                if ~isequal(subscripts, 1)
                    error("simcompare:Model:InvalidSubscripts", ...
                        "Frame-based signals are converted to one scalar stream.");
                end
                return
            end

            hasBaseline = isfinite(entry.BaselineIndex);
            hasCompare = isfinite(entry.CompareIndex);
            baselineShape = 1;
            compareShape = 1;
            if hasBaseline
                baselineShape = obj.BaselineRecords( ...
                    entry.BaselineIndex).Metadata.Shape;
            end
            if hasCompare
                compareShape = obj.CompareRecords( ...
                    entry.CompareIndex).Metadata.Shape;
            end
            requiredRank = max([1, numel(baselineShape), ...
                numel(compareShape)]);
            if numel(subscripts) ~= requiredRank
                error("simcompare:Model:InvalidSubscripts", ...
                    "Enter %d subscript%s for these signal shapes.", ...
                    requiredRank, pluralSuffix(requiredRank));
            end

            baselineShape(end + 1:requiredRank) = 1;
            compareShape(end + 1:requiredRank) = 1;
            if hasBaseline && any(subscripts > baselineShape)
                error("simcompare:Model:BaselineIndexOutOfRange", ...
                    "Element %s is outside the baseline shape %s.", ...
                    formatSubscripts(subscripts), ...
                    formatShape(baselineShape));
            end
            if hasCompare && any(subscripts > compareShape)
                error("simcompare:Model:CompareIndexOutOfRange", ...
                    "Element %s is outside the comparison shape %s.", ...
                    formatSubscripts(subscripts), ...
                    formatShape(compareShape));
            end
        end

        function result = compare( ...
                obj, entryId, subscripts, shiftSeconds, ...
                signalInterpretation, errorType)
            arguments
                obj
                entryId (1, 1) double {mustBeInteger, mustBePositive}
                subscripts (1, :) double
                shiftSeconds (1, 1) double {mustBeFinite}
                signalInterpretation (1, 1) string {mustBeMember( ...
                    signalInterpretation, ["Sample-based", "Frame-based"])} = ...
                    "Sample-based"
                errorType (1, 1) string {mustBeMember( ...
                    errorType, ["Relative", "Absolute"])} = "Relative"
            end
            entry = obj.findEntry(entryId);
            obj.assertMatched(entry);
            obj.validateSubscripts( ...
                entryId, subscripts, signalInterpretation);

            hasBaseline = isfinite(entry.BaselineIndex);
            hasCompare = isfinite(entry.CompareIndex);
            baselineUnit = "";
            compareUnit = "";
            if hasBaseline
                baselineRecord = obj.BaselineRecords(entry.BaselineIndex);
                [baselineTime, baselineData] = extractSeries( ...
                    baselineRecord, subscripts, signalInterpretation);
                baselineUnit = baselineRecord.Metadata.Unit;
            else
                baselineTime = zeros(0, 1);
                baselineData = zeros(0, 1);
            end
            if hasCompare
                compareRecord = obj.CompareRecords(entry.CompareIndex);
                if hasBaseline && unitsRequireConversion( ...
                        baselineRecord.Metadata, compareRecord.Metadata)
                    compareRecord = convertRecordToUnit( ...
                        compareRecord, baselineRecord.Metadata.Unit);
                end
                [compareTime, compareData] = extractSeries( ...
                    compareRecord, subscripts, signalInterpretation);
                compareUnit = compareRecord.Metadata.Unit;
            else
                compareTime = zeros(0, 1);
                compareData = zeros(0, 1);
            end
            shiftedCompareTime = compareTime + shiftSeconds;

            if ~hasBaseline || ~hasCompare
                if hasBaseline
                    sourceBounds = [baselineTime(1), baselineTime(end)];
                else
                    sourceBounds = [shiftedCompareTime(1), ...
                        shiftedCompareTime(end)];
                end
                result = struct( ...
                    "Name", entry.Name, ...
                    "Subscripts", subscripts, ...
                    "BaselineTime", baselineTime, ...
                    "BaselineData", baselineData, ...
                    "BaselineUnit", baselineUnit, ...
                    "CompareTime", shiftedCompareTime, ...
                    "CompareData", compareData, ...
                    "CompareUnit", compareUnit, ...
                    "ErrorTime", zeros(0, 1), ...
                    "AbsoluteError", zeros(0, 1), ...
                    "PercentError", zeros(0, 1), ...
                    "ErrorData", zeros(0, 1), ...
                    "ErrorType", errorType, ...
                    "ErrorUnit", errorUnit(errorType, ...
                    baselineUnit, compareUnit), ...
                    "Interpolation", "", ...
                    "NearZeroTolerance", NaN, ...
                    "Overlap", [NaN, NaN], ...
                    "SourceBounds", sourceBounds);
                return
            end

            overlapStart = max(baselineTime(1), shiftedCompareTime(1));
            overlapEnd = min(baselineTime(end), shiftedCompareTime(end));
            hasOverlap = overlapStart <= overlapEnd;
            if hasOverlap
                inOverlap = baselineTime >= overlapStart & ...
                    baselineTime <= overlapEnd;
                errorTime = baselineTime(inOverlap);
                baselineOnErrorGrid = baselineData(inOverlap);
            else
                errorTime = zeros(0, 1);
                baselineOnErrorGrid = zeros(0, 1);
            end

            useLinear = baselineRecord.Metadata.IsFloating && ...
                compareRecord.Metadata.IsFloating;
            if useLinear
                interpolation = "linear";
            else
                interpolation = "previous";
            end
            compareOnErrorGrid = interpolateSeries( ...
                shiftedCompareTime, compareData, errorTime, ...
                interpolation);

            absoluteError = abs(compareOnErrorGrid - ...
                baselineOnErrorGrid);
            percentError = 100 .* (compareOnErrorGrid - ...
                baselineOnErrorGrid) ./ abs(baselineOnErrorGrid);
            finiteBaseline = baselineData(isfinite(baselineData));
            if isempty(finiteBaseline)
                baselineScale = 1;
            else
                baselineScale = max(1, max(abs(finiteBaseline)));
            end
            nearZeroTolerance = sqrt(eps("double")) * baselineScale;
            unavailable = ~isfinite(compareOnErrorGrid);
            nearZero = abs(baselineOnErrorGrid) <= nearZeroTolerance;
            percentError(unavailable | nearZero) = NaN;
            if errorType == "Relative"
                errorData = percentError;
            else
                errorData = absoluteError;
            end

            sourceBounds = [ ...
                min(baselineTime(1), shiftedCompareTime(1)), ...
                max(baselineTime(end), shiftedCompareTime(end))];
            if hasOverlap
                overlap = [overlapStart, overlapEnd];
            else
                overlap = [NaN, NaN];
            end

            result = struct( ...
                "Name", entry.Name, ...
                "Subscripts", subscripts, ...
                "BaselineTime", baselineTime, ...
                "BaselineData", baselineData, ...
                "BaselineUnit", baselineUnit, ...
                "CompareTime", shiftedCompareTime, ...
                "CompareData", compareData, ...
                "CompareUnit", compareUnit, ...
                "ErrorTime", errorTime, ...
                "AbsoluteError", absoluteError, ...
                "PercentError", percentError, ...
                "ErrorData", errorData, ...
                "ErrorType", errorType, ...
                "ErrorUnit", errorUnit(errorType, ...
                baselineUnit, compareUnit), ...
                "Interpolation", interpolation, ...
                "NearZeroTolerance", nearZeroTolerance, ...
                "Overlap", overlap, ...
                "SourceBounds", sourceBounds);
        end
    end

    methods (Static)
        function tf = detectFixedPointSupport()
            try
                tf = logical(license( ...
                    "test", "Fixed_Point_Toolbox")) && ...
                    ~isempty(ver("fixedpoint")) && ...
                    ~isempty(meta.class.fromName("embedded.fi"));
            catch
                tf = false;
            end
        end

        function names = findDatasetVariables(filePath)
            arguments
                filePath (1, 1) string
            end
            if strlength(filePath) == 0 || ~isfile(filePath)
                error("simcompare:Model:FileNotFound", ...
                    "MAT-file not found: %s", filePath);
            end
            variables = whos("-file", filePath);
            classes = string({variables.class});
            names = string({variables( ...
                classes == "Simulink.SimulationData.Dataset").name});
        end

        function runs = findSdiRuns()
            runIDs = double(Simulink.sdi.getAllRunIDs);
            runs = describeSdiRuns(runIDs);
        end

        function runs = importSdiSession(filePath)
            arguments
                filePath (1, 1) string
            end
            if strlength(filePath) == 0 || ~isfile(filePath)
                error("simcompare:Model:SdiSessionNotFound", ...
                    "SDI session file not found: %s", filePath);
            end
            [~, ~, extension] = fileparts(filePath);
            if ~strcmpi(extension, ".mldatx")
                error("simcompare:Model:UnsupportedSdiSessionFile", ...
                    "Select a Simulation Data Inspector session file " + ...
                    "with the .mldatx extension.");
            end

            existingRunIDs = double(Simulink.sdi.getAllRunIDs);
            try
                valid = Simulink.sdi.load(filePath);
            catch exception
                importError = MException( ...
                    "simcompare:Model:SdiSessionImportFailed", ...
                    "Could not import SDI session '%s': %s", ...
                    filePath, exception.message);
                throwAsCaller(addCause(importError, exception));
            end
            if ~valid
                error("simcompare:Model:InvalidSdiSession", ...
                    "The selected file is not a valid SDI session: %s", ...
                    filePath);
            end

            currentRunIDs = double(Simulink.sdi.getAllRunIDs);
            importedRunIDs = setdiff( ...
                currentRunIDs, existingRunIDs, "stable");
            runs = describeSdiRuns(importedRunIDs);
            if isempty(runs)
                error("simcompare:Model:EmptySdiSession", ...
                    "The selected SDI session contains no runs.");
            end
        end

        function subscripts = parseSubscripts(text)
            arguments
                text (1, 1) string
            end
            text = strtrim(text);
            if strlength(text) == 0
                error("simcompare:Model:InvalidSubscripts", ...
                    "Enter one-based element subscripts, such as 2 or 2,3.");
            end
            parts = strtrim(split(text, ","));
            subscripts = str2double(parts).';
            if any(strlength(parts) == 0) || ...
                    any(~isfinite(subscripts)) || ...
                    any(subscripts < 1) || ...
                    any(subscripts ~= fix(subscripts))
                error("simcompare:Model:InvalidSubscripts", ...
                    "Element subscripts must be comma-separated positive integers.");
            end
        end
    end

    methods (Access = private)
        function loadFileRole(obj, role, filePath, datasetName)
            arguments
                obj
                role (1, 1) string {mustBeMember(role, ...
                    ["baseline", "compare"])}
                filePath (1, 1) string
                datasetName (1, 1) string
            end
            datasetNames = obj.findDatasetVariables(filePath);
            if isempty(datasetNames)
                error("simcompare:Model:NoDataset", ...
                    "The MAT-file contains no Simulink SimulationData Dataset.");
            end
            if strlength(datasetName) == 0
                if numel(datasetNames) > 1
                    error("simcompare:Model:MultipleDatasets", ...
                        "The MAT-file contains multiple Dataset variables: %s.", ...
                        strjoin(datasetNames, ", "));
                end
                datasetName = datasetNames(1);
            elseif ~any(datasetNames == datasetName)
                error("simcompare:Model:DatasetNotFound", ...
                    "Dataset variable '%s' was not found in %s.", ...
                    datasetName, filePath);
            end

            loaded = load(filePath, datasetName);
            candidateDataset = loaded.(char(datasetName));
            if ~isa(candidateDataset, ...
                    "Simulink.SimulationData.Dataset")
                error("simcompare:Model:InvalidDataset", ...
                    "Variable '%s' is not a Simulink SimulationData Dataset.", ...
                    datasetName);
            end
            candidateRecords = buildRecords( ...
                candidateDataset, obj.FixedPointAvailable);
            obj.commitRole( ...
                role, candidateDataset, candidateRecords, ...
                filePath, datasetName, NaN, filePath);
        end

        function loadRunRole(obj, role, runID)
            arguments
                obj
                role (1, 1) string {mustBeMember(role, ...
                    ["baseline", "compare"])}
                runID (1, 1) double {mustBeInteger, mustBePositive}
            end
            if ~Simulink.sdi.isValidRunID(runID)
                error("simcompare:Model:RunNotFound", ...
                    "Simulation Data Inspector run %d is no longer available.", ...
                    runID);
            end

            runObject = Simulink.sdi.getRun(runID);
            candidateDataset = Simulink.sdi.exportRun(runID);
            candidateRecords = buildSdiRecords( ...
                candidateDataset, obj.FixedPointAvailable);
            runName = string(runObject.Name);
            if strlength(runName) == 0
                runName = "Unnamed run";
            end
            sourceDisplay = sprintf( ...
                "SDI: %s (run %d)", runName, runID);
            obj.commitRole( ...
                role, candidateDataset, candidateRecords, ...
                "", runName, runID, sourceDisplay);
        end

        function commitRole(obj, role, candidateDataset, ...
                candidateRecords, filePath, datasetName, runID, ...
                sourceDisplay)
            if role == "baseline"
                obj.BaselineDataset = candidateDataset;
                obj.BaselineRecords = candidateRecords;
                obj.BaselineFile = filePath;
                obj.BaselineRunID = runID;
                obj.BaselineSourceDisplay = sourceDisplay;
                obj.BaselineDatasetName = datasetName;
            else
                obj.CompareDataset = candidateDataset;
                obj.CompareRecords = candidateRecords;
                obj.CompareFile = filePath;
                obj.CompareRunID = runID;
                obj.CompareSourceDisplay = sourceDisplay;
                obj.CompareDatasetName = datasetName;
            end
            obj.rebuildEntries();
            obj.Revision = obj.Revision + 1;
        end

        function rebuildEntries(obj)
            entries = emptyEntries();
            baselineNames = string({obj.BaselineRecords.Name});
            compareNames = string({obj.CompareRecords.Name});
            allNames = unique([baselineNames, compareNames], "stable");

            for name = allNames
                baselineIndices = find(baselineNames == name);
                compareIndices = find(compareNames == name);
                if isempty(compareIndices)
                    for index = baselineIndices
                        metadata = obj.BaselineRecords(index).Metadata;
                        details = unmatchedDetails("baseline", metadata);
                        entries(end + 1) = makeEntry(name, ...
                            "Baseline only", index, NaN, ...
                            metadata.DataClass, "—", ...
                            metadata.ShapeText, "—", details, ...
                            metadata.Supported); %#ok<AGROW>
                    end
                elseif isempty(baselineIndices)
                    for index = compareIndices
                        metadata = obj.CompareRecords(index).Metadata;
                        details = unmatchedDetails("comparison", metadata);
                        entries(end + 1) = makeEntry(name, ...
                            "Compare only", NaN, index, ...
                            "—", metadata.DataClass, ...
                            "—", metadata.ShapeText, details, ...
                            metadata.Supported); %#ok<AGROW>
                    end
                elseif numel(baselineIndices) ~= 1 || ...
                        numel(compareIndices) ~= 1
                    details = sprintf( ...
                        "%d baseline and %d comparison signals share this name.", ...
                        numel(baselineIndices), numel(compareIndices));
                    if hasUnavailableFixedPoint( ...
                            obj.BaselineRecords, baselineIndices) || ...
                            hasUnavailableFixedPoint( ...
                            obj.CompareRecords, compareIndices)
                        details = details + " Fixed-point values require " + ...
                            "an available Fixed-Point Designer license.";
                    end
                    entries(end + 1) = makeEntry(name, "Ambiguous", ...
                        NaN, NaN, ...
                        joinedDataTypes( ...
                            obj.BaselineRecords, baselineIndices), ...
                        joinedDataTypes( ...
                            obj.CompareRecords, compareIndices), ...
                        joinedShapes(obj.BaselineRecords, baselineIndices), ...
                        joinedShapes(obj.CompareRecords, compareIndices), ...
                        details, false); %#ok<AGROW>
                else
                    baselineMetadata = obj.BaselineRecords( ...
                        baselineIndices).Metadata;
                    compareMetadata = obj.CompareRecords( ...
                        compareIndices).Metadata;
                    baselineRecord = obj.BaselineRecords(baselineIndices);
                    compareRecord = obj.CompareRecords(compareIndices);
                    if unitsConflict(baselineRecord, compareRecord)
                        status = "Unit mismatch";
                        details = unitMismatchDetails( ...
                            baselineMetadata, compareMetadata);
                        selectable = false;
                    elseif baselineMetadata.Supported && ...
                            compareMetadata.Supported
                        status = "Matched";
                        details = sprintf("%s interpolation", ...
                            interpolationFor(baselineMetadata, ...
                            compareMetadata));
                        unitAssumption = unitAssumptionDetails( ...
                            baselineMetadata, compareMetadata);
                        if strlength(unitAssumption) > 0
                            details = details + " " + unitAssumption;
                        end
                        unitConversion = unitConversionDetails( ...
                            baselineMetadata, compareMetadata);
                        if strlength(unitConversion) > 0
                            details = details + " " + unitConversion;
                        end
                        selectable = true;
                    elseif baselineMetadata.FixedPointUnavailable || ...
                            compareMetadata.FixedPointUnavailable
                        status = "Fixed-point unavailable";
                        details = unsupportedDetails( ...
                            baselineMetadata, compareMetadata);
                        selectable = false;
                    else
                        status = "Unsupported";
                        details = unsupportedDetails( ...
                            baselineMetadata, compareMetadata);
                        selectable = false;
                    end
                    entries(end + 1) = makeEntry(name, status, ...
                        baselineIndices, compareIndices, ...
                        baselineMetadata.DataClass, ...
                        compareMetadata.DataClass, ...
                        baselineMetadata.ShapeText, ...
                        compareMetadata.ShapeText, ...
                        details, selectable); %#ok<AGROW>
                end
            end

            for index = 1:numel(entries)
                entries(index).Id = index;
            end
            obj.Entries = entries;
        end

        function entry = findEntry(obj, entryId)
            indices = find([obj.Entries.Id] == entryId, 1);
            if isempty(indices)
                error("simcompare:Model:EntryNotFound", ...
                    "Signal entry %d does not exist.", entryId);
            end
            entry = obj.Entries(indices);
        end
    end

    methods (Static, Access = private)
        function assertMatched(entry)
            if ~entry.IsSelectable
                if entry.Status == "Unit mismatch"
                    error("simcompare:Model:UnitMismatch", ...
                        "Cannot compare signal '%s': %s", ...
                        entry.Name, entry.Details);
                end
                error("simcompare:Model:SignalNotComparable", ...
                    "Signal '%s' is not comparable (%s).", ...
                    entry.Name, entry.Status);
            end
        end
    end
end

function unit = errorUnit(errorType, baselineUnit, compareUnit)
if errorType == "Relative"
    unit = "%";
elseif strlength(baselineUnit) > 0
    unit = baselineUnit;
else
    unit = compareUnit;
end
end

function runs = describeSdiRuns(runIDs)
emptyRun = struct( ...
    "RunID", NaN, ...
    "Name", "", ...
    "SignalCount", 0, ...
    "DisplayName", "");
runs = repmat(emptyRun, 1, numel(runIDs));
runCount = 0;
for runID = runIDs(:).'
    if ~Simulink.sdi.isValidRunID(runID)
        continue
    end
    runObject = Simulink.sdi.getRun(runID);
    runName = string(runObject.Name);
    if strlength(runName) == 0
        runName = "Unnamed run";
    end
    signalCount = double(runObject.SignalCount);
    runCount = runCount + 1;
    runs(runCount) = struct( ...
        "RunID", runID, ...
        "Name", runName, ...
        "SignalCount", signalCount, ...
        "DisplayName", sprintf( ...
        "%s — run %d (%d signal%s)", ...
        runName, runID, signalCount, ...
        pluralSuffix(signalCount)));
end
runs = runs(1:runCount);
end

function records = buildRecords(dataset, fixedPointAvailable)
records = emptyRecords();
for index = 1:dataset.numElements
    element = dataset{index};
    records = appendRecords(records, ...
        buildElementRecords(element, "", fixedPointAvailable));
end
end

function records = buildSdiRecords(dataset, fixedPointAvailable)
records = emptyRecords();
for index = 1:dataset.numElements
    element = dataset{index};
    if isa(element, "Simulink.SimulationData.Dataset")
        % exportRun wraps Dataset sources in one transport-level Dataset.
        % Its name is the source variable, not part of the signal hierarchy.
        elementRecords = buildDatasetRecords( ...
            element, "", fixedPointAvailable);
    else
        elementRecords = buildElementRecords( ...
            element, "", fixedPointAvailable);
    end
    records = appendRecords(records, elementRecords);
end
end

function records = buildDatasetRecords( ...
        dataset, parentName, fixedPointAvailable)
records = emptyRecords();
for index = 1:dataset.numElements
    records = appendRecords(records, buildElementRecords( ...
        dataset{index}, parentName, fixedPointAvailable));
end
if isempty(records)
    records = makeRecord( ...
        parentName, [], unsupportedMetadata( ...
        "Bus contains no signal elements.", class(dataset)));
end
end

function records = buildElementRecords( ...
        element, parentName, fixedPointAvailable)
name = joinedSignalName(parentName, objectName(element));
if isa(element, "Simulink.SimulationData.Dataset")
    records = buildDatasetRecords(element, name, fixedPointAvailable);
elseif isprop(element, "Values")
    records = buildValueRecords( ...
        element.Values, name, fixedPointAvailable);
else
    records = makeRecord( ...
        name, [], unsupportedMetadata( ...
        "Dataset element has no Values property.", class(element)));
end
end

function records = buildValueRecords(values, name, fixedPointAvailable)
if isa(values, "timeseries")
    records = makeRecord( ...
        name, values, inspectValues(values, fixedPointAvailable));
    return
end

if isa(values, "Simulink.SimulationData.Dataset")
    records = buildDatasetRecords(values, name, fixedPointAvailable);
    return
end

if isstruct(values) && isscalar(values)
    fields = string(fieldnames(values));
    records = emptyRecords();
    for field = fields.'
        fieldRecords = buildValueRecords( ...
            values.(field), joinedSignalName(name, field), ...
            fixedPointAvailable);
        records = appendRecords(records, fieldRecords);
    end
    if isempty(records)
        records = makeRecord( ...
            name, values, unsupportedMetadata( ...
            "Bus contains no signal fields.", class(values)));
    end
    return
end

records = makeRecord( ...
    name, values, unsupportedMetadata( ...
    "Values must be a timeseries or logged bus.", class(values)));
end

function records = emptyRecords()
records = struct( ...
    "Name", {}, ...
    "Values", {}, ...
    "Metadata", {});
end

function record = makeRecord(name, values, metadata)
record = struct( ...
    "Name", string(name), ...
    "Values", values, ...
    "Metadata", metadata);
end

function records = appendRecords(records, additionalRecords)
if isempty(additionalRecords)
    return
end
records(end + 1:end + numel(additionalRecords)) = additionalRecords;
end

function name = objectName(value)
if isprop(value, "Name")
    name = string(value.Name);
else
    name = "";
end
if ~isscalar(name)
    name = join(name, " ");
end
name = strtrim(name);
end

function name = joinedSignalName(parentName, childName)
parentName = string(parentName);
childName = string(childName);
if strlength(parentName) == 0
    name = childName;
elseif strlength(childName) == 0
    name = parentName;
else
    name = parentName + "." + childName;
end
end

function metadata = inspectValues(values, fixedPointAvailable)
if ~isa(values, "timeseries")
    metadata = unsupportedMetadata( ...
        "Values must be a timeseries.", class(values));
    return
end

data = values.Data;
isFixedPoint = isa(data, "embedded.fi");
if isFixedPoint && ~fixedPointAvailable
    metadata = unavailableFixedPointMetadata(values, data);
    return
end
isSupportedClass = isnumeric(data) || islogical(data) || isFixedPoint;
if ~isSupportedClass
    metadata = unsupportedMetadata( ...
        "Data must be numeric, logical, or fixed-point.", class(data));
    return
end
if ~isreal(data)
    metadata = unsupportedMetadata( ...
        "Complex data is not supported.", class(data));
    return
end

time = values.Time;
if ~isnumeric(time) || ~isreal(time) || isempty(time)
    metadata = unsupportedMetadata( ...
        "Time must be a nonempty real numeric vector.", class(data));
    return
end
time = double(time(:));
timeDifferences = diff(time);
if any(~isfinite(time)) || any(timeDifferences < 0)
    metadata = unsupportedMetadata( ...
        "Time must be finite and nondecreasing.", class(data));
    return
end
hasDuplicateTimes = any(timeDifferences == 0);

[dataSize, timeDimension, shape] = dataLayout(values, data);
if dataSize(timeDimension) ~= numel(time)
    metadata = unsupportedMetadata( ...
        "Data dimensions do not agree with the time vector.", class(data));
    return
end

metadata = struct( ...
    "Supported", true, ...
    "Reason", "", ...
    "DataClass", string(class(data)), ...
    "IsFloating", isa(data, "double") || isa(data, "single") || ...
        isa(data, "half"), ...
    "IsFixedPoint", isFixedPoint, ...
    "FixedPointUnavailable", false, ...
    "HasDuplicateTimes", hasDuplicateTimes, ...
    "TimeDimension", timeDimension, ...
    "Shape", double(shape), ...
    "ShapeText", formatShape(shape), ...
    "Unit", signalUnit(values));
end

function metadata = unsupportedMetadata(reason, dataClass)
metadata = struct( ...
    "Supported", false, ...
    "Reason", string(reason), ...
    "DataClass", string(dataClass), ...
    "IsFloating", false, ...
    "IsFixedPoint", false, ...
    "FixedPointUnavailable", false, ...
    "HasDuplicateTimes", false, ...
    "TimeDimension", NaN, ...
    "Shape", NaN, ...
    "ShapeText", "—", ...
    "Unit", "");
end

function entries = emptyEntries()
entries = struct( ...
    "Id", {}, ...
    "Name", {}, ...
    "Status", {}, ...
    "BaselineIndex", {}, ...
    "CompareIndex", {}, ...
    "BaselineDataType", {}, ...
    "CompareDataType", {}, ...
    "BaselineShape", {}, ...
    "CompareShape", {}, ...
    "Details", {}, ...
    "IsSelectable", {});
end

function entry = makeEntry(name, status, baselineIndex, compareIndex, ...
        baselineDataType, compareDataType, baselineShape, compareShape, ...
        details, isSelectable)
entry = struct( ...
    "Id", NaN, ...
    "Name", string(name), ...
    "Status", string(status), ...
    "BaselineIndex", baselineIndex, ...
    "CompareIndex", compareIndex, ...
    "BaselineDataType", string(baselineDataType), ...
    "CompareDataType", string(compareDataType), ...
    "BaselineShape", string(baselineShape), ...
    "CompareShape", string(compareShape), ...
    "Details", string(details), ...
    "IsSelectable", isSelectable);
end

function text = formatShape(shape)
shape = double(shape);
if isempty(shape)
    shape = 1;
end
text = "[" + strjoin(string(shape), "×") + "]";
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

function details = unmatchedDetails(side, metadata)
if metadata.Supported
    details = "Present only in the " + side + " dataset.";
elseif metadata.FixedPointUnavailable
    details = "Present only in the " + side + ...
        " dataset; fixed-point data requires an available " + ...
        "Fixed-Point Designer license.";
else
    details = "Present only in the " + side + ...
        " dataset; value is unsupported: " + metadata.Reason;
end
end

function text = joinedShapes(records, indices)
shapes = strings(1, numel(indices));
for index = 1:numel(indices)
    shapes(index) = records(indices(index)).Metadata.ShapeText;
end
text = strjoin(shapes, ", ");
end

function text = joinedDataTypes(records, indices)
dataTypes = strings(1, numel(indices));
for index = 1:numel(indices)
    dataTypes(index) = records(indices(index)).Metadata.DataClass;
end
text = strjoin(dataTypes, ", ");
end

function text = unsupportedDetails(baselineMetadata, compareMetadata)
parts = strings(0, 1);
if ~baselineMetadata.Supported
    parts(end + 1) = "Baseline: " + baselineMetadata.Reason;
end
if ~compareMetadata.Supported
    parts(end + 1) = "Comparison: " + compareMetadata.Reason;
end
text = strjoin(parts, " ");
end

function tf = unitsConflict(baselineRecord, compareRecord)
baselineMetadata = baselineRecord.Metadata;
compareMetadata = compareRecord.Metadata;
tf = false;
if ~unitsRequireConversion(baselineMetadata, compareMetadata)
    return
end
try
    convertValuesToUnit(compareRecord.Values, baselineMetadata.Unit);
catch
    tf = true;
end
end

function tf = unitsRequireConversion(baselineMetadata, compareMetadata)
tf = baselineMetadata.Supported && compareMetadata.Supported && ...
    strlength(baselineMetadata.Unit) > 0 && ...
    strlength(compareMetadata.Unit) > 0 && ...
    baselineMetadata.Unit ~= compareMetadata.Unit;
end

function details = unitMismatchDetails(baselineMetadata, compareMetadata)
details = "Cannot convert comparison unit '" + compareMetadata.Unit + ...
    "' to baseline unit '" + baselineMetadata.Unit + "'.";
end

function details = unitAssumptionDetails(baselineMetadata, compareMetadata)
if strlength(baselineMetadata.Unit) == 0 && ...
        strlength(compareMetadata.Unit) > 0
    details = "Assuming baseline unit '" + compareMetadata.Unit + ...
        "' because it is undefined.";
elseif strlength(baselineMetadata.Unit) > 0 && ...
        strlength(compareMetadata.Unit) == 0
    details = "Assuming comparison unit '" + baselineMetadata.Unit + ...
        "' because it is undefined.";
else
    details = "";
end
end

function details = unitConversionDetails(baselineMetadata, compareMetadata)
if unitsRequireConversion(baselineMetadata, compareMetadata)
    details = "Implicitly converting comparison unit '" + ...
        compareMetadata.Unit + "' to baseline unit '" + ...
        baselineMetadata.Unit + "'.";
else
    details = "";
end
end

function tf = hasUnavailableFixedPoint(records, indices)
if isempty(indices)
    tf = false;
    return
end
metadata = [records(indices).Metadata];
tf = any([metadata.FixedPointUnavailable]);
end

function metadata = unavailableFixedPointMetadata(values, data)
metadata = unsupportedMetadata( ...
    "Fixed-point data requires an available Fixed-Point Designer license.", ...
    class(data));
metadata.IsFixedPoint = true;
metadata.FixedPointUnavailable = true;
metadata.Unit = signalUnit(values);
try
    [~, timeDimension, shape] = dataLayout(values, data);
    metadata.TimeDimension = timeDimension;
    metadata.Shape = double(shape);
    metadata.ShapeText = formatShape(shape);
catch
    % Keep the signal visible even when its dimensions cannot be inspected.
end
end

function record = convertRecordToUnit(record, targetUnit)
record.Values = convertValuesToUnit(record.Values, targetUnit);
record.Metadata.Unit = targetUnit;
end

function convertedValues = convertValuesToUnit(values, targetUnit)
sourceUnit = signalUnit(values);
probe = timeseries([0; 1], [0; 1]);
probe.DataInfo.Units = Simulink.SimulationData.Unit(char(sourceUnit));
runID = Simulink.sdi.createRun( ...
    "Simulation Comparison App unit conversion", "vars", probe);
runCleanup = onCleanup(@() deleteSdiRun(runID));
runObject = Simulink.sdi.getRun(runID);
probeSignal = runObject.getSignalByIndex(1);
convertUnits(probeSignal, char(targetUnit));
convertedProbe = double(probeSignal.Values.Data(:));
if numel(convertedProbe) ~= 2
    error("simcompare:Model:UnitConversionFailed", ...
        "Unable to determine the conversion from '%s' to '%s'.", ...
        sourceUnit, targetUnit);
end
offset = convertedProbe(1);
scale = convertedProbe(2) - offset;
convertedValues = values;
convertedValues.Data = scale .* double(values.Data) + offset;
convertedValues.DataInfo.Units = Simulink.SimulationData.Unit( ...
    char(targetUnit));
end

function deleteSdiRun(runID)
if Simulink.sdi.isValidRunID(runID)
    Simulink.sdi.deleteRun(runID);
end
end

function unit = signalUnit(values)
unit = "";
try
    dataUnit = values.DataInfo.Units;
    if isa(dataUnit, "Simulink.SimulationData.Unit")
        unit = string(dataUnit.Name);
    elseif ischar(dataUnit) || isstring(dataUnit)
        unit = string(dataUnit);
    end
catch
    % Units are optional metadata on logged timeseries data.
end
if ~isscalar(unit)
    unit = join(unit, " ");
end
unit = strtrim(unit);
end

function [dataSize, timeDimension, shape] = dataLayout(values, data)
dataSize = size(data);
if values.IsTimeFirst
    timeDimension = 1;
else
    timeDimension = ndims(data);
end
shape = dataSize;
shape(timeDimension) = [];
if isempty(shape)
    shape = 1;
end
while ~isscalar(shape) && shape(end) == 1
    shape(end) = [];
end
end

function method = interpolationFor(baselineMetadata, compareMetadata)
if baselineMetadata.IsFloating && compareMetadata.IsFloating
    method = "linear";
else
    method = "previous-value";
end
end

function [time, data] = extractSeries( ...
        record, subscripts, signalInterpretation)
metadata = record.Metadata;
rawData = record.Values.Data;
rawTime = double(record.Values.Time(:));
if signalInterpretation == "Frame-based"
    [time, data] = expandFrameSeries(rawTime, rawData, metadata);
    [time, keepIndices] = unique(time, "last");
    data = data(keepIndices);
else
    dataDimensions = ndims(rawData);
    sampleDimensions = setdiff(1:dataDimensions, ...
        metadata.TimeDimension, "stable");
    indices = repmat({':'}, 1, dataDimensions);
    for index = 1:numel(sampleDimensions)
        if index <= numel(subscripts)
            indices{sampleDimensions(index)} = subscripts(index);
        else
            indices{sampleDimensions(index)} = 1;
        end
    end
    selected = rawData(indices{:});
    data = double(selected(:));
    time = rawTime;
    if metadata.HasDuplicateTimes
        keepSamples = [time(1:end - 1) ~= time(2:end); true];
        time = time(keepSamples);
        data = data(keepSamples);
    end
end
end

function [time, data] = expandFrameSeries(rawTime, rawData, metadata)
frameSampleCount = prod(metadata.Shape);
if frameSampleCount == 1
    time = rawTime;
    data = double(rawData(:));
    return
end

frameDimensions = setdiff(1:ndims(rawData), ...
    metadata.TimeDimension, "stable");
frameData = permute(rawData, ...
    [frameDimensions, metadata.TimeDimension]);
frameData = reshape(frameData, frameSampleCount, numel(rawTime));
frameIntervals = diff(rawTime);
positiveIntervals = frameIntervals( ...
    isfinite(frameIntervals) & frameIntervals > 0);
if isempty(positiveIntervals)
    error("simcompare:Model:FrameTimingUnavailable", ...
        "Frame-based conversion requires at least two distinct frame timestamps.");
end
defaultFrameInterval = median(positiveIntervals);
frameIntervals(end + 1, 1) = defaultFrameInterval;
frameIntervals(~isfinite(frameIntervals) | frameIntervals <= 0) = ...
    defaultFrameInterval;
sampleOffsets = (0:frameSampleCount - 1).' ./ frameSampleCount;
time = rawTime.' + sampleOffsets .* frameIntervals.';
time = time(:);
data = double(frameData(:));
end

function values = interpolateSeries(time, data, queryTime, method)
values = NaN(size(queryTime));
if isempty(queryTime) || isempty(time)
    return
end
if isscalar(time)
    tolerance = 8 * eps(max(1, abs(time(1))));
    exact = abs(queryTime - time(1)) <= tolerance;
    values(exact) = data(1);
    return
end
values = interp1(time, data, queryTime, char(method), NaN);
values = values(:);
end
