classdef ComparisonModelTest < matlab.unittest.TestCase
    %ComparisonModelTest Tests dataset loading and comparison behavior.
    % Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        InvalidSubscripts = struct(Empty=[], Zero=0, Fractional=1.5, ...
            Infinite=Inf, Missing=NaN, WrongRank=[1, 1])
    end

    methods (Test)
        function testInvalidSubscriptsAreRejected(testCase, InvalidSubscripts)
            [baselineFile, compareFile] = createScalarFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);

            testCase.verifyError(@() model.compare(1, InvalidSubscripts, 0), ...
                "simcompare:Model:InvalidSubscripts");
        end

        function testOutOfRangeEntryIsRejected(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);

            testCase.verifyError(@() model.getEntry(1), "simcompare:Model:EntryOutOfRange");
            testCase.verifyError(@() model.defaultSubscripts(1), "simcompare:Model:EntryNotFound");
        end

        function testFrameInterpretationRejectsElementSelection(testCase)
            [baselineFile, compareFile] = createScalarFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);

            testCase.verifyError(@() model.compare(1, 2, 0, "Frame-based"), ...
                "simcompare:Model:InvalidSubscripts");
        end

        function testNamedDatasetSelectionRejectsUnknownVariable(testCase)
            [baselineFile, compareFile] = createScalarFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);
            originalEntries = model.Entries;

            testCase.verifyError(@() model.loadBaseline(baselineFile, "missing"), ...
                "simcompare:Model:DatasetNotFound");
            testCase.verifyEqual(model.Entries, originalEntries);
            testCase.verifyTrue(model.hasPair());
        end

        function testPositiveShiftAndLinearInterpolation(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            baseline = {testsupport.spec( ...
                "signal", (0:3)', [1; 2; 3; 4])};
            comparison = {testsupport.spec( ...
                "signal", (0:2)', [1.5; 2.5; 3.5])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, 1, 1);

            testCase.verifyEqual(result.CompareTime, [1; 2; 3], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.ErrorTime, [1; 2; 3], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.PercentError, ...
                [-25; -100/6; -12.5], AbsTol=1e-12);
            testCase.verifyEqual(result.ErrorData, ...
                result.PercentError, AbsTol=1e-12);
            testCase.verifyEqual(result.ErrorType, "Relative");
            testCase.verifyEqual(result.ErrorUnit, "%");
            testCase.verifyEqual(result.Interpolation, "linear");
        end

        function testTimeLastMultidimensionalElement(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            time = (0:3)';
            baselineData = reshape(1:24, [2, 3, 4]);
            comparisonData = baselineData + 1;
            baseline = {testsupport.spec( ...
                "matrix", time, baselineData)};
            comparison = {testsupport.spec( ...
                "matrix", time, comparisonData)};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, [2, 3], 0);

            testCase.verifyEqual(model.Entries(1).BaselineShape, "[2×3]");
            testCase.verifyEqual(result.BaselineData, [6; 12; 18; 24], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareData, [7; 13; 19; 25], ...
                AbsTol=1e-12);
            testCase.verifyError(@() model.compare(1, [3, 1], 0), ...
                "simcompare:Model:BaselineIndexOutOfRange");
        end

        function testFrameBasedInterpretationExpandsFrames(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            sampleData = (1:6).';
            frameData = reshape(sampleData, [2, 1, 3]);
            baseline = {testsupport.spec( ...
                "frame", (0:0.1:0.5).', sampleData)};
            comparison = {testsupport.spec( ...
                "frame", [0; 0.2; 0.4], frameData)};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, 1, 0, "Frame-based");

            testCase.verifyEqual( ...
                model.defaultSubscripts(1, "Frame-based"), 1);
            testCase.verifyTrue(model.isScalar(1, "Frame-based"));
            testCase.verifyEqual(result.BaselineTime, (0:0.1:0.5).', ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareTime, (0:0.1:0.5).', ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareData, sampleData, ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.PercentError, zeros(6, 1), ...
                AbsTol=1e-12);
        end

        function testDuplicateTimestampsKeepLastSample(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            baseline = {testsupport.spec( ...
                "signal", [0; 1; 1; 2], [1; 10; 20; 30])};
            comparison = {testsupport.spec( ...
                "signal", [0; 1; 2], [1; 20; 30])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, 1, 0);

            testCase.verifyEqual(result.BaselineTime, [0; 1; 2], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.BaselineData, [1; 20; 30], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.PercentError, zeros(3, 1), ...
                AbsTol=1e-12);
        end

        function testPreviousInterpolationForInteger(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            integerBaseline = int16([1; 2; 4]);
            integerCompare = int16([10; 30]);
            baseline = {testsupport.spec( ...
                "integer", [0; 1; 2], integerBaseline)};
            comparison = {testsupport.spec( ...
                "integer", [0; 2], integerCompare)};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            integerResult = model.compare(1, 1, 0);

            testCase.verifyEqual(integerResult.Interpolation, "previous");
            testCase.verifyEqual(integerResult.PercentError, ...
                [900; 400; 650], AbsTol=1e-12);
        end

        function testPreviousInterpolationForFixedPoint(testCase)
            testCase.assumeTrue( ...
                simcompare.Models.ComparisonModel.detectFixedPointSupport(), ...
                "Fixed-Point Designer is unavailable.");
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            fixedBaseline = fi([1; 2; 3], 1, 16, 8);
            fixedCompare = fi([1; 3], 1, 16, 8);
            baseline = {testsupport.spec( ...
                "fixed", [0; 1; 2], fixedBaseline)};
            comparison = {testsupport.spec( ...
                "fixed", [0; 2], fixedCompare)};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            fixedResult = model.compare(1, 1, 0);

            testCase.verifyEqual(fixedResult.Interpolation, "previous");
        end

        function testCompatibleUnitsConvertComparisonToBaselineUnits(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            createUnitDatasetFile(baselineFile, "m", [1; 2]);
            createUnitDatasetFile(compareFile, "cm", [100; 200]);
            model = loadPair(testCase, baselineFile, compareFile);

            entry = model.Entries(1);
            result = model.compare(entry.Id, 1, 0);
            absoluteResult = model.compare( ...
                entry.Id, 1, 0, "Sample-based", "Absolute");

            testCase.verifyEqual(entry.Status, "Matched");
            testCase.verifyTrue(entry.IsSelectable);
            testCase.verifySubstring(entry.Details, ...
                "Implicitly converting comparison unit 'cm' to baseline unit 'm'.");
            testCase.verifyEqual(result.BaselineUnit, "m");
            testCase.verifyEqual(result.CompareUnit, "m");
            testCase.verifyEqual(result.CompareData, [1; 2], AbsTol=1e-12);
            testCase.verifyEqual(absoluteResult.ErrorData, zeros(2, 1), ...
                AbsTol=1e-12);
            testCase.verifyEqual(absoluteResult.ErrorUnit, "m");
        end

        function testIncompatibleUnitsCannotBeCompared(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            createUnitDatasetFile(baselineFile, "m");
            createUnitDatasetFile(compareFile, "s");
            model = loadPair(testCase, baselineFile, compareFile);

            entry = model.Entries(1);

            testCase.verifyEqual(entry.Status, "Unit mismatch");
            testCase.verifyFalse(entry.IsSelectable);
            testCase.verifySubstring(entry.Details, ...
                "Cannot convert comparison unit 's' to baseline unit 'm'.");
            testCase.verifyError(@() model.compare(entry.Id, 1, 0), ...
                "simcompare:Model:UnitMismatch");
        end

        function testMissingUnitAssumesDefinedUnit(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            createUnitDatasetFile(baselineFile, "");
            createUnitDatasetFile(compareFile, "m/s");
            model = loadPair(testCase, baselineFile, compareFile);

            entry = model.Entries(1);

            testCase.verifyEqual(entry.Status, "Matched");
            testCase.verifyTrue(entry.IsSelectable);
            testCase.verifySubstring(entry.Details, ...
                "Assuming baseline unit 'm/s' because it is undefined.");
        end

        function testNoLicenseLeavesStandardSignalsComparable(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            time = [0; 1];
            baseline = { ...
                testsupport.spec("doubleSignal", time, [1; 2]), ...
                testsupport.spec("singleSignal", time, single([1; 2])), ...
                testsupport.spec("integerSignal", time, int8([1; 2])), ...
                testsupport.spec("logicalSignal", time, logical([1; 1]))};
            comparison = { ...
                testsupport.spec("doubleSignal", time, [2; 3]), ...
                testsupport.spec("singleSignal", time, single([2; 3])), ...
                testsupport.spec("integerSignal", time, int8([2; 3])), ...
                testsupport.spec("logicalSignal", time, logical([1; 0]))};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = simcompare.Models.ComparisonModel( ...
                FixedPointAvailable=false);
            testCase.addTeardown(@delete, model);

            model.loadBaseline(baselineFile);
            model.loadCompare(compareFile);
            doubleEntry = entryByName(model.Entries, "doubleSignal");
            singleEntry = entryByName(model.Entries, "singleSignal");
            integerEntry = entryByName(model.Entries, "integerSignal");
            logicalEntry = entryByName(model.Entries, "logicalSignal");
            doubleResult = model.compare(doubleEntry.Id, 1, 0);
            singleResult = model.compare(singleEntry.Id, 1, 0);
            integerResult = model.compare(integerEntry.Id, 1, 0);
            logicalResult = model.compare(logicalEntry.Id, 1, 0);

            testCase.verifyFalse(model.FixedPointAvailable);
            testCase.verifyTrue(all( ...
                string({model.Entries.Status}) == "Matched"));
            testCase.verifyTrue(all([model.Entries.IsSelectable]));
            testCase.verifyEqual( ...
                doubleEntry.BaselineDataType, "double");
            testCase.verifyEqual( ...
                singleEntry.BaselineDataType, "single");
            testCase.verifyEqual( ...
                integerEntry.CompareDataType, "int8");
            testCase.verifyEqual( ...
                logicalEntry.CompareDataType, "logical");
            testCase.verifyEqual(doubleResult.Interpolation, "linear");
            testCase.verifyEqual(singleResult.Interpolation, "linear");
            testCase.verifyEqual(integerResult.Interpolation, "previous");
            testCase.verifyEqual(logicalResult.Interpolation, "previous");
        end

        function testNoLicenseListsFixedPointSignalAsUnavailable(testCase)
            testCase.assumeTrue( ...
                simcompare.Models.ComparisonModel.detectFixedPointSupport(), ...
                "A fixed-point fixture cannot be created without the product.");
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            time = [0; 1];
            baseline = { ...
                testsupport.spec("standard", time, [1; 2]), ...
                testsupport.spec("fixed", time, fi([1; 2], 1, 8, 4))};
            comparison = { ...
                testsupport.spec("standard", time, [2; 3]), ...
                testsupport.spec("fixed", time, fi([2; 3], 1, 8, 4))};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = simcompare.Models.ComparisonModel( ...
                FixedPointAvailable=false);
            testCase.addTeardown(@delete, model);

            model.loadBaseline(baselineFile);
            model.loadCompare(compareFile);
            statuses = statusByName(model.Entries);
            fixedEntry = model.Entries( ...
                find(string({model.Entries.Name}) == "fixed", 1));

            testCase.verifyEqual(statuses.standard, "Matched");
            testCase.verifyEqual(statuses.fixed, ...
                "Fixed-point unavailable");
            testCase.verifyFalse(fixedEntry.IsSelectable);
            testCase.verifySubstring( ...
                fixedEntry.Details, "Fixed-Point Designer license");
            testCase.verifyError( ...
                @() model.compare(fixedEntry.Id, 1, 0), ...
                "simcompare:Model:SignalNotComparable");
        end

        function testNearZeroBaselineCreatesNaNGaps(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            baseline = {testsupport.spec( ...
                "signal", [0; 1; 2], [0; 2; 4])};
            comparison = {testsupport.spec( ...
                "signal", [0; 2], [0; 6])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, 1, 0);

            testCase.verifyTrue(isnan(result.PercentError(1)));
            testCase.verifyEqual(result.PercentError(2:3), [50; 50], ...
                AbsTol=1e-12);
        end

        function testAbsoluteErrorIncludesNearZeroBaseline(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            baseline = {testsupport.spec( ...
                "signal", [0; 1; 2], [0; 2; 4])};
            comparison = {testsupport.spec( ...
                "signal", [0; 2], [0; 6])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare( ...
                1, 1, 0, "Sample-based", "Absolute");

            testCase.verifyEqual(result.AbsoluteError, [0; 1; 2], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.ErrorData, ...
                result.AbsoluteError, AbsTol=1e-12);
            testCase.verifyEqual(result.ErrorType, "Absolute");
            testCase.verifyEqual(result.ErrorUnit, "");
        end

        function testLogicalDataUsesPreviousInterpolation(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            baseline = {testsupport.spec( ...
                "signal", [0; 1; 2], logical([0; 1; 1]))};
            comparison = {testsupport.spec( ...
                "signal", [0; 2], logical([0; 1]))};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, 1, 0);

            testCase.verifyEqual(result.Interpolation, "previous");
            testCase.verifyTrue(isnan(result.PercentError(1)));
            testCase.verifyEqual(result.PercentError(2:3), ...
                [-100; 0], AbsTol=1e-12);
        end

        function testNoOverlapReturnsEmptyErrorTrace(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            baseline = {testsupport.spec( ...
                "signal", [0; 1], [1; 2])};
            comparison = {testsupport.spec( ...
                "signal", [10; 11], [1; 2])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            result = model.compare(1, 1, 0);

            testCase.verifyEmpty(result.ErrorTime);
            testCase.verifyEmpty(result.PercentError);
            testCase.verifyTrue(all(isnan(result.Overlap)));
        end

        function testMatchingStatusesAreNotGuessed(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            time = [0; 1];
            baseline = { ...
                testsupport.spec("dup", time, [1; 2]), ...
                testsupport.spec("dup", time, [3; 4]), ...
                testsupport.spec("onlyB", time, [1; 2]), ...
                testsupport.spec("unsupported", time, [1+1i; 2+1i])};
            comparison = { ...
                testsupport.spec("dup", time, [1; 2]), ...
                testsupport.spec("onlyC", time, [1; 2]), ...
                testsupport.spec("unsupported", time, [1; 2])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            model = loadPair(testCase, baselineFile, compareFile);

            statuses = statusByName(model.Entries);

            testCase.verifyEqual(statuses.dup, "Ambiguous");
            testCase.verifyEqual(statuses.onlyB, "Baseline only");
            testCase.verifyEqual(statuses.onlyC, "Compare only");
            testCase.verifyEqual(statuses.unsupported, "Unsupported");
        end

        function testFailedLoadRetainsValidBaseline(testCase)
            folder = makeTemporaryFolder(testCase);
            baselineFile = fullfile(folder, "baseline.mat");
            invalidFile = fullfile(folder, "invalid.mat");
            testsupport.createDatasetFile(baselineFile, "logs", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            ordinaryValue = 42;
            save(invalidFile, "ordinaryValue");
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            model.loadBaseline(baselineFile);

            testCase.verifyError(@() model.loadBaseline(invalidFile), ...
                "simcompare:Model:NoDataset");

            testCase.verifyEqual(model.BaselineFile, string(baselineFile));
            testCase.verifyEqual(model.getBaselineSignalCount(), 1);
        end

        function testMultipleDatasetsRequireSelection(testCase)
            folder = makeTemporaryFolder(testCase);
            multipleFile = fullfile(folder, "multiple.mat");
            specifications = { ...
                testsupport.spec("signal", [0; 1], [1; 2])};
            first = testsupport.makeDataset(specifications);
            second = testsupport.makeDataset(specifications);
            save(multipleFile, "first", "second");
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);

            testCase.verifyError(@() model.loadBaseline(multipleFile), ...
                "simcompare:Model:MultipleDatasets");
            model.loadBaseline(multipleFile, "second");

            testCase.verifyEqual(model.BaselineDatasetName, "second");
        end

        function testClearBaselineRetainsComparisonSource(testCase)
            [baselineFile, compareFile] = createScalarFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);

            model.clearBaseline();

            testCase.verifyFalse(model.hasBaseline());
            testCase.verifyTrue(model.hasCompare());
            testCase.verifyEqual(model.BaselineFile, "");
            testCase.verifyTrue(isnan(model.BaselineRunID));
            testCase.verifyEqual(model.BaselineSourceDisplay, "");
            testCase.verifyEqual(model.BaselineDatasetName, "");
            testCase.verifyEqual(string({model.Entries.Status}), ...
                "Compare only");
        end

        function testClearComparisonRetainsBaselineSource(testCase)
            [baselineFile, compareFile] = createScalarFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);

            model.clearCompare();

            testCase.verifyTrue(model.hasBaseline());
            testCase.verifyFalse(model.hasCompare());
            testCase.verifyEqual(model.CompareFile, "");
            testCase.verifyTrue(isnan(model.CompareRunID));
            testCase.verifyEqual(model.CompareSourceDisplay, "");
            testCase.verifyEqual(model.CompareDatasetName, "");
            testCase.verifyEqual(string({model.Entries.Status}), ...
                "Baseline only");
        end

        function testDiscoversAndLoadsSdiRuns(testCase)
            baselineRunID = createSdiRun(testCase, ...
                "simcompare baseline", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            compareRunID = createSdiRun(testCase, ...
                "simcompare comparison", ...
                {testsupport.spec("signal", [0; 1], [2; 4])});
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);

            runs = model.findSdiRuns();
            model.loadBaselineRun(baselineRunID);
            model.loadCompareRun(compareRunID);
            result = model.compare(1, 1, 0);

            testCase.verifyTrue(any([runs.RunID] == baselineRunID));
            testCase.verifyTrue(any([runs.RunID] == compareRunID));
            testCase.verifyEqual(model.BaselineRunID, baselineRunID);
            testCase.verifyEqual(model.CompareRunID, compareRunID);
            testCase.verifyEqual(model.BaselineFile, "");
            testCase.verifyEqual(model.CompareFile, "");
            testCase.verifySubstring( ...
                model.BaselineSourceDisplay, "simcompare baseline");
            testCase.verifySubstring( ...
                model.CompareSourceDisplay, "simcompare comparison");
            testCase.verifyEqual(result.BaselineData, [1; 2], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareData, [2; 4], ...
                AbsTol=1e-12);
        end

        function testImportsSavedSdiSessionAndPreservesCurrentRuns(testCase)
            folder = makeTemporaryFolder(testCase);
            sessionFile = fullfile(folder, "regression-session.mldatx");
            baselineRunID = createSdiRun(testCase, ...
                "session baseline", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            compareRunID = createSdiRun(testCase, ...
                "session comparison", ...
                {testsupport.spec("signal", [0; 1], [2; 4])});
            Simulink.sdi.save(sessionFile);
            deleteSdiRun(baselineRunID);
            deleteSdiRun(compareRunID);
            sentinelRunID = createSdiRun(testCase, ...
                "current session sentinel", ...
                {testsupport.spec("sentinel", [0; 1], [3; 4])});
            existingRunIDs = double(Simulink.sdi.getAllRunIDs);
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);

            importedRuns = model.importSdiSession(sessionFile);
            importedRunIDs = [importedRuns.RunID];
            testCase.addTeardown(@() deleteSdiRuns(importedRunIDs));
            baselineImport = importedRuns( ...
                string({importedRuns.Name}) == "session baseline");
            model.loadBaselineRun(baselineImport.RunID);

            testCase.verifyTrue( ...
                Simulink.sdi.isValidRunID(sentinelRunID));
            testCase.verifyFalse(any( ...
                ismember(importedRunIDs, existingRunIDs)));
            testCase.verifyTrue(any( ...
                string({importedRuns.Name}) == "session comparison"));
            testCase.verifyEqual(baselineImport.SignalCount, 1);
            testCase.verifyEqual(model.BaselineDatasetName, ...
                "session baseline");
            testCase.verifyEqual(model.getBaselineSignalCount(), 1);
        end

        function testRejectsNonMldatxSessionFile(testCase)
            folder = makeTemporaryFolder(testCase);
            invalidFile = fullfile(folder, "not-a-session.mat");
            ordinaryValue = 42;
            save(invalidFile, "ordinaryValue");

            testCase.verifyError( ...
                @() simcompare.Models.ComparisonModel ...
                .importSdiSession(invalidFile), ...
                "simcompare:Model:UnsupportedSdiSessionFile");
        end

        function testRejectsInvalidMldatxSession(testCase)
            folder = makeTemporaryFolder(testCase);
            invalidFile = fullfile(folder, "invalid.mldatx");
            writelines("not an SDI session", invalidFile);

            testCase.verifyError( ...
                @() simcompare.Models.ComparisonModel ...
                .importSdiSession(invalidFile), ...
                "simcompare:Model:SdiSessionImportFailed");
        end

        function testComparesMultilevelNonVirtualBusLeaf(testCase)
            [baselineFile, compareFile] = createBusFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);
            entry = entryByName(model.Entries, ...
                "NonVirtualBus.Controller.Measurements.Vector");

            result = model.compare(entry.Id, 2, 0);

            testCase.verifyEqual(entry.Status, "Matched");
            testCase.verifyEqual(entry.BaselineDataType, "double");
            testCase.verifyEqual(entry.BaselineShape, "[2]");
            testCase.verifyEqual(result.BaselineData, [10; 20; 30], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareData, [20; 40; 60], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.PercentError, 100 .* ones(3, 1), ...
                AbsTol=1e-12);
        end

        function testComparesMultilevelVirtualBusLeaf(testCase)
            [baselineFile, compareFile] = createBusFiles(testCase);
            model = loadPair(testCase, baselineFile, compareFile);
            entry = entryByName(model.Entries, ...
                "VirtualBus.Controller.Measurements.Scalar");

            result = model.compare(entry.Id, 1, 0);

            testCase.verifyEqual(entry.Status, "Matched");
            testCase.verifyEqual(result.Name, ...
                "VirtualBus.Controller.Measurements.Scalar");
            testCase.verifyEqual(result.BaselineData, [1; 2; 3], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareData, [2; 4; 6], ...
                AbsTol=1e-12);
        end

        function testLoadsMultilevelBusesFromSdiRuns(testCase)
            [baselineFile, compareFile] = createBusFiles(testCase);
            baselineRunID = createSdiFileRun( ...
                testCase, "bus baseline", baselineFile);
            compareRunID = createSdiFileRun( ...
                testCase, "bus comparison", compareFile);
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);

            model.loadBaselineRun(baselineRunID);
            model.loadCompareRun(compareRunID);
            names = string({model.Entries.Name});
            entry = entryByName(model.Entries, ...
                "VirtualBus.Controller.Measurements.Vector");
            result = model.compare(entry.Id, 1, 0);

            testCase.verifyEqual(model.getBaselineSignalCount(), 4);
            testCase.verifyTrue(any( ...
                names == "NonVirtualBus.Controller.Measurements.Scalar"));
            testCase.verifyTrue(any( ...
                names == "VirtualBus.Controller.Measurements.Vector"));
            testCase.verifyFalse(any(startsWith(names, "baselineLogs.")));
            testCase.verifyEqual(result.BaselineData, [1; 2; 3], ...
                AbsTol=1e-12);
            testCase.verifyEqual(result.CompareData, [2; 4; 6], ...
                AbsTol=1e-12);
        end

        function testDeletedSdiRunIsRejected(testCase)
            runID = createSdiRun(testCase, ...
                "simcompare deleted", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            Simulink.sdi.deleteRun(runID);
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);

            testCase.verifyError( ...
                @() model.loadBaselineRun(runID), ...
                "simcompare:Model:RunNotFound");
        end

        function testSubscriptParserRejectsInvalidText(testCase)
            testCase.verifyEqual( ...
                simcompare.Models.ComparisonModel.parseSubscripts("2, 3"), ...
                [2, 3], AbsTol=1e-12);
            testCase.verifyError( ...
                @() simcompare.Models.ComparisonModel.parseSubscripts("2,0"), ...
                "simcompare:Model:InvalidSubscripts");
        end
    end
end

function model = loadPair(testCase, baselineFile, compareFile)
model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
model.loadBaseline(baselineFile);
model.loadCompare(compareFile);
end

function folder = makeTemporaryFolder(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
end

function [baselineFile, compareFile] = createBusFiles(testCase)
folder = makeTemporaryFolder(testCase);
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
testsupport.createBusDatasetFile( ...
    baselineFile, "baselineLogs", 1);
testsupport.createBusDatasetFile( ...
    compareFile, "compareLogs", 2);
end

function [baselineFile, compareFile] = createScalarFiles(testCase)
folder = makeTemporaryFolder(testCase);
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
baseline = {testsupport.spec("signal", [0; 1], [1; 2])};
comparison = {testsupport.spec("signal", [0; 1], [2; 3])};
testsupport.createDatasetFile(baselineFile, "logs", baseline);
testsupport.createDatasetFile(compareFile, "logs", comparison);
end

function createUnitDatasetFile(filePath, unit, data)
if nargin < 3
    data = [1; 2];
end
values = timeseries(data, (0:numel(data) - 1).');
if strlength(unit) > 0
    values.DataInfo.Units = Simulink.SimulationData.Unit(char(unit));
end
signal = Simulink.SimulationData.Signal;
signal.Name = "signal";
signal.Values = values;
logs = Simulink.SimulationData.Dataset;
logs = logs.addElement(signal);
save(filePath, "logs");
end

function statuses = statusByName(entries)
statuses = struct;
for index = 1:numel(entries)
    statuses.(entries(index).Name) = entries(index).Status;
end
end

function entry = entryByName(entries, name)
entry = entries(find(string({entries.Name}) == name, 1));
end

function runID = createSdiRun(testCase, runName, specifications)
variables = cell(1, numel(specifications));
for index = 1:numel(specifications)
    specification = specifications{index};
    values = timeseries(specification.Data, specification.Time);
    values.Name = char(specification.Name);
    variables{index} = values;
end
runID = double(Simulink.sdi.createRun( ...
    runName, "vars", variables{:}));
testCase.addTeardown(@() deleteSdiRun(runID));
end

function runID = createSdiFileRun(testCase, runName, filePath)
runID = double(Simulink.sdi.createRun(runName, "file", filePath));
testCase.addTeardown(@() deleteSdiRun(runID));
end

function deleteSdiRun(runID)
if Simulink.sdi.isValidRunID(runID)
    Simulink.sdi.deleteRun(runID);
end
end

function deleteSdiRuns(runIDs)
for runID = runIDs
    deleteSdiRun(runID);
end
end
