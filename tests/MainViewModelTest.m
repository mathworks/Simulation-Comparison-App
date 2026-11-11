classdef MainViewModelTest < matlab.unittest.TestCase
    %MainViewModelTest Tests presentation state without creating a UI.
    % Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        InvalidLimits = struct(Equal=[1, 1], Reversed=[2, 1], ...
            Infinite=[0, Inf], Missing=[NaN, 1])
        UnselectedCommand = struct( ...
            Element=@(vm) vm.setElementCommand("2"), ...
            Interpretation=@(vm) vm.setSignalInterpretationCommand("Frame-based"), ...
            Reset=@(vm) vm.resetViewCommand(), ...
            Alignment=@(vm) vm.alignComparisonAtPointCommand(0, 1))
        InvalidExportNames = struct( ...
            None=struct("Names", strings(1, 0), "Identifier", "simcompare:ViewModel:NoExportSelection"), ...
            Empty=struct("Names", "", "Identifier", "simcompare:ViewModel:EmptySignalName"), ...
            Missing=struct("Names", "missing", "Identifier", "simcompare:ViewModel:SignalNotFound"))
        SingleSource = struct( ...
            Baseline=struct( ...
            "Role", "baseline", ...
            "ExpectedLegendText", "logs | Baseline"), ...
            Comparison=struct( ...
            "Role", "compare", ...
            "ExpectedLegendText", "logs | Comparison"))
        ReloadSource = struct( ...
            Baseline=struct( ...
            "FileName", "replacementBaseline.mat", ...
            "LoadFcn", @(viewModel, filePath) ...
            viewModel.loadBaselineCommand(filePath)), ...
            Comparison=struct( ...
            "FileName", "replacementComparison.mat", ...
            "LoadFcn", @(viewModel, filePath) ...
            viewModel.loadCompareCommand(filePath)))
    end

    methods (TestClassSetup)
        function disableWarnings(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture

            % Delegate to SuppressedWarningsFixture to suppress display of warnings.
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:hg:AutoSoftwareOpenGL'));
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:graphics:HardwareUnavailable'));
        end
    end

    methods (Test)
        function testInvalidLimitsPreserveView(testCase, InvalidLimits)
            [viewModel, ~] = createLoadedViewModel(testCase);
            originalLimits = viewModel.getXLimitsSeconds();
            originalData = viewModel.PlotData;

            viewModel.setXLimitsCommand(InvalidLimits(1), InvalidLimits(2));

            testCase.verifyEqual(viewModel.getXLimitsSeconds(), originalLimits);
            testCase.verifyEqual(viewModel.PlotData, originalData);
            testCase.verifySubstring(viewModel.StatusMessage, "X limits must be finite");
        end

        function testUnselectedCommandsReportRequiredSelection(testCase, UnselectedCommand)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);

            UnselectedCommand(viewModel);

            testCase.verifyEqual(viewModel.StatusMessage, "Select a matched signal first.");
            testCase.verifyFalse(viewModel.CanCompare);
            testCase.verifyEmpty(viewModel.PlotData.BaselineData);
        end

        function testInvalidExportNamesAreRejected(testCase, InvalidExportNames)
            [viewModel, files] = createLoadedViewModel(testCase);

            testCase.verifyError(@() viewModel.exportSignals( ...
                InvalidExportNames.Names, files.Folder, "png"), ...
                InvalidExportNames.Identifier);
            testCase.verifyFalse(viewModel.IsExporting);
        end

        function testFailedExportAllowsRetry(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);

            testCase.verifyError(@() viewModel.exportSignals( ...
                "scalar", files.Folder, "unsupported"), ...
                "simcompare:Export:UnsupportedFormat");
            testCase.verifyFalse(viewModel.IsExporting);
            testCase.verifySubstring(viewModel.StatusMessage, "Export failed:");

            exported = viewModel.exportSignals("scalar", files.Folder, "png");

            testCase.verifyTrue(isfile(exported));
            testCase.verifyFalse(viewModel.IsExporting);
        end

        function testNonfiniteShiftPreservesPlot(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            originalPlot = viewModel.PlotData;

            viewModel.setTimeShiftCommand(Inf);

            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), 0);
            testCase.verifyEqual(viewModel.PlotData, originalPlot);
            testCase.verifyEqual(viewModel.StatusMessage, "Time shift must be finite.");
        end

        function testDatasetInspectionReportsMissingAndEmptyFiles(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            filePath = fullfile(files.Folder, "numeric.mat");
            numericData = 1;
            save(filePath, "numericData");

            names = viewModel.inspectDatasetNamesCommand(filePath);

            testCase.verifyEmpty(names);
            testCase.verifySubstring(viewModel.StatusMessage, "contains no SimulationData Dataset");

            names = viewModel.inspectDatasetNamesCommand(fullfile(files.Folder, "missing.mat"));

            testCase.verifyEmpty(names);
            testCase.verifySubstring(viewModel.StatusMessage, "Load failed:");
            testCase.verifyTrue(viewModel.CanCompare);
        end

        function testSelectionPreservesViewState(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);

            testCase.verifyTrue(viewModel.IsSelectedSignalScalar);
            viewModel.setTimeShiftCommand(0.25);
            viewModel.setXLimitsCommand(0.5, 1.5);
            viewModel.setTimeUnitCommand("ms");
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("2");

            testCase.verifyFalse(viewModel.IsSelectedSignalScalar);
            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), 0.25, ...
                AbsTol=1e-12);
            testCase.verifyEqual(viewModel.getXLimitsSeconds(), ...
                [0.5, 1.5], AbsTol=1e-12);
            testCase.verifyEqual(viewModel.ShiftValue, 250, ...
                AbsTol=1e-10);
            testCase.verifyEqual([viewModel.XMin, viewModel.XMax], ...
                [500, 1500], AbsTol=1e-10);
            testCase.verifyEqual(viewModel.ElementText, "2");
            testCase.verifyEqual( ...
                viewModel.SignalTable.BaselineDataType, ...
                ["double"; "double"]);
            testCase.verifyEqual( ...
                viewModel.SignalTable.CompareDataType, ...
                ["double"; "double"]);
        end

        function testErrorTypePersistsAcrossSignalAndDatasetChanges(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            replacementFile = fullfile( ...
                files.Folder, "replacementBaseline.mat");
            replacement = { ...
                testsupport.spec("vector", [0; 1; 2], ...
                [10, 40, 70; 20, 50, 80; 30, 60, 90]), ...
                testsupport.spec("scalar", [0; 1; 2], [4; 5; 6])};
            testsupport.createDatasetFile( ...
                replacementFile, "logs", replacement);

            testCase.verifyEqual(viewModel.ErrorType, "Relative");
            viewModel.setErrorTypeCommand("Absolute");
            viewModel.selectRowCommand(vectorRow);
            success = viewModel.loadBaselineCommand(replacementFile);

            testCase.verifyTrue(success);
            testCase.verifyEqual(viewModel.ErrorType, "Absolute");
            testCase.verifyEqual(viewModel.PlotData.ErrorType, "Absolute");
            testCase.verifyEqual(viewModel.PlotData.ErrorData, ...
                abs(viewModel.PlotData.CompareData - ...
                viewModel.PlotData.BaselineData), AbsTol=1e-12);
        end

        function testInvalidElementLeavesSelectionUnchanged(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("2");
            originalData = viewModel.PlotData.BaselineData;

            viewModel.setElementCommand("99");

            testCase.verifyEqual(viewModel.ElementText, "2");
            testCase.verifyEqual(viewModel.PlotData.BaselineData, ...
                originalData, AbsTol=1e-12);
            testCase.verifyTrue(startsWith( ...
                viewModel.StatusMessage, "Element error:"));
        end

        function testFrameBasedInterpretationExpandsSelectedSignal(testCase)
            viewModel = createLoadedFrameViewModel(testCase);

            viewModel.setSignalInterpretationCommand("Frame-based");

            testCase.verifyEqual( ...
                viewModel.SignalInterpretation, "Frame-based");
            testCase.verifyEqual(viewModel.ElementText, "1");
            testCase.verifyTrue(viewModel.IsSelectedSignalScalar);
            testCase.verifyEqual(viewModel.PlotData.CompareTime, ...
                (0:0.1:0.5).', AbsTol=1e-12);
            testCase.verifyEqual(viewModel.PlotData.CompareData, ...
                (1:6).', AbsTol=1e-12);
        end

        function testReloadedDatasetPreservesSelectedSignalAndView(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("2");
            viewModel.setTimeShiftCommand(0.5);
            viewModel.setXLimitsCommand(0.25, 0.75);
            viewModel.setTimeUnitCommand("ms");
            replacementFile = fullfile( ...
                files.Folder, "replacementBaseline.mat");
            time = [0; 1; 2];
            replacement = { ...
                testsupport.spec("vector", time, ...
                [10, 40, 70; 20, 50, 80; 30, 60, 90]), ...
                testsupport.spec("scalar", time, [4; 5; 6])};
            testsupport.createDatasetFile( ...
                replacementFile, "logs", replacement);

            success = viewModel.loadBaselineCommand(replacementFile);

            testCase.verifyTrue(success);
            testCase.verifyEqual( ...
                viewModel.SignalTable.Name(viewModel.SelectedRow), "vector");
            testCase.verifyEqual(viewModel.SelectedRow, 1);
            testCase.verifyEqual(viewModel.SignalInterpretation, ...
                "Sample-based");
            testCase.verifyEqual(viewModel.ElementText, "2");
            testCase.verifyEqual(viewModel.TimeUnit, "ms");
            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), 0.5, ...
                AbsTol=1e-12);
            testCase.verifyEqual(viewModel.getXLimitsSeconds(), ...
                [0.25, 0.75], AbsTol=1e-12);
            testCase.verifyEqual(viewModel.PlotData.BaselineData, ...
                [40; 50; 60], AbsTol=1e-12);
        end

        function testReloadedDatasetResetsMissingSelection(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("2");
            viewModel.setTimeShiftCommand(0.5);
            viewModel.setXLimitsCommand(0.25, 0.75);
            replacementFile = fullfile( ...
                files.Folder, "replacementBaseline.mat");
            replacement = { ...
                testsupport.spec("scalar", [0; 1; 2], [4; 5; 6])};
            testsupport.createDatasetFile( ...
                replacementFile, "logs", replacement);

            success = viewModel.loadBaselineCommand(replacementFile);

            testCase.verifyTrue(success);
            testCase.verifyEqual( ...
                viewModel.SignalTable.Name(viewModel.SelectedRow), "scalar");
            testCase.verifyEqual(viewModel.SignalInterpretation, ...
                "Sample-based");
            testCase.verifyEqual(viewModel.ElementText, "1");
            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), 0, ...
                AbsTol=1e-12);
            testCase.verifyEqual(viewModel.getXLimitsSeconds(), [0, 2], ...
                AbsTol=1e-12);
        end

        function testReloadedDatasetPreservesExportSelection( ...
                testCase, ReloadSource)
            [viewModel, files] = createLoadedViewModel(testCase);
            viewModel.selectAllForExportCommand();
            replacementFile = fullfile( ...
                files.Folder, ReloadSource.FileName);
            replacement = {testsupport.spec( ...
                "scalar", [0; 1; 2], [4; 5; 6])};
            testsupport.createDatasetFile( ...
                replacementFile, "logs", replacement);

            success = ReloadSource.LoadFcn(viewModel, replacementFile);

            testCase.verifyTrue(success);
            testCase.verifyEqual( ...
                viewModel.SignalTable.Name(viewModel.SignalTable.Export), ...
                "scalar");
            testCase.verifyTrue(viewModel.CanExport);
        end

        function testFailedLoadRetainsPresentation(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            originalFile = viewModel.BaselineFileDisplay;
            originalTable = viewModel.SignalTable;
            invalidFile = fullfile(files.Folder, "invalid.mat");
            ordinaryValue = 1;
            save(invalidFile, "ordinaryValue");

            success = viewModel.loadBaselineCommand(invalidFile);

            testCase.verifyFalse(success);
            testCase.verifyEqual(viewModel.BaselineFileDisplay, originalFile);
            testCase.verifyEqual(viewModel.SignalTable, originalTable);
            testCase.verifyTrue(startsWith( ...
                viewModel.StatusMessage, "Load failed:"));
        end

        function testClearSourceRefreshesDependentState(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("2");
            viewModel.setErrorTypeCommand("Absolute");
            viewModel.setExportSelectionCommand(vectorRow, true);

            viewModel.clearBaselineCommand();

            testCase.verifyEqual(viewModel.BaselineFileDisplay, "");
            testCase.verifyEqual(viewModel.BaselineStatus, "Not loaded");
            testCase.verifyEqual(viewModel.CompareStatus, ...
                "Loaded comparisonLogs (2 signals)");
            testCase.verifyEqual( ...
                viewModel.SignalTable.Status, ...
                repmat("Compare only", 2, 1));
            testCase.verifyEqual( ...
                viewModel.SignalTable.Name(viewModel.SelectedRow), "vector");
            testCase.verifyEmpty(viewModel.PlotData.BaselineData);
            testCase.verifyEqual(viewModel.PlotData.CompareData, ...
                [11; 21; 31], AbsTol=1e-12);
            testCase.verifyEmpty(viewModel.PlotData.ErrorData);
            testCase.verifyEqual(viewModel.ErrorType, "Absolute");
            testCase.verifyFalse(any(viewModel.SignalTable.Export));
            testCase.verifyFalse(viewModel.CanExport);
        end

        function testClearingBothSourcesResetsDependentState(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            viewModel.setTimeShiftCommand(0.5);
            viewModel.setXLimitsCommand(0.5, 1.5);

            viewModel.clearBaselineCommand();
            viewModel.clearCompareCommand();

            testCase.verifyEqual(viewModel.BaselineStatus, "Not loaded");
            testCase.verifyEqual(viewModel.CompareStatus, "Not loaded");
            testCase.verifyEmpty(viewModel.SignalTable);
            testCase.verifyTrue(isnan(viewModel.SelectedRow));
            testCase.verifyFalse(viewModel.CanCompare);
            testCase.verifyFalse(viewModel.CanExport);
            testCase.verifyEmpty(viewModel.PlotData.BaselineData);
            testCase.verifyEmpty(viewModel.PlotData.CompareData);
            testCase.verifyEmpty(viewModel.PlotData.ErrorData);
            testCase.verifyEqual( ...
                viewModel.getTimeShiftSeconds(), 0, AbsTol=1e-12);
            testCase.verifyEqual( ...
                viewModel.getXLimitsSeconds(), [0, 1], AbsTol=1e-12);
        end

        function testShiftMovesComparisonTraceRight(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            originalTime = viewModel.PlotData.CompareTime;

            viewModel.setTimeShiftCommand(0.5);

            testCase.verifyEqual(viewModel.PlotData.CompareTime, ...
                originalTime + 0.5, AbsTol=1e-12);
        end

        function testShiftLimitsFollowDisplayedTimeSpan(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);

            testCase.verifyEqual(viewModel.ShiftLimits, [-2, 2], ...
                AbsTol=1e-12);

            viewModel.setXLimitsCommand(0.5, 1.25);

            testCase.verifyEqual(viewModel.ShiftLimits, [-0.75, 0.75], ...
                AbsTol=1e-12);

            viewModel.setTimeUnitCommand("ms");

            testCase.verifyEqual(viewModel.ShiftLimits, [-750, 750], ...
                AbsTol=1e-12);
        end

        function testAlignComparisonPointInterpolatesAtSelectedY(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);

            viewModel.alignComparisonAtPointCommand(1.75, 2.1);

            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), 0.65, ...
                AbsTol=1e-12);
        end

        function testAlignComparisonPointAddsToCurrentShift(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);
            viewModel.setTimeShiftCommand(0.4);

            viewModel.alignComparisonAtPointCommand(2.2, 2.5);

            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), 0.7, ...
                AbsTol=1e-12);
        end

        function testAlignComparisonPointUsesClosestCrossing(testCase)
            viewModel = createLoadedScalarViewModel( ...
                testCase, [0; 0; 0], [0; 2; 0]);

            viewModel.alignComparisonAtPointCommand(1.4, 1);

            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), -0.1, ...
                AbsTol=1e-12);
        end

        function testAlignComparisonPointFallsBackToNearestValue(testCase)
            [viewModel, ~] = createLoadedViewModel(testCase);

            viewModel.alignComparisonAtPointCommand(1.5, 10);

            testCase.verifyEqual(viewModel.getTimeShiftSeconds(), -0.5, ...
                AbsTol=1e-12);
        end

        function testNoLicensePublishesFixedPointWarning(testCase)
            model = simcompare.Models.ComparisonModel( ...
                FixedPointAvailable=false);
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);

            testCase.verifyFalse(viewModel.FixedPointAvailable);
            testCase.verifySubstring( ...
                viewModel.FixedPointWarningMessage, ...
                "Fixed-point signals are listed but cannot be compared");
            testCase.verifySubstring( ...
                viewModel.FixedPointWarningMessage, ...
                "Standard MATLAB numeric and logical signals remain available");
        end

        function testDiscoversAndLoadsSdiSources(testCase)
            baselineRunID = createSdiRun(testCase, ...
                "view model baseline", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            compareRunID = createSdiRun(testCase, ...
                "view model comparison", ...
                {testsupport.spec("signal", [0; 1], [2; 3])});
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);

            runs = viewModel.inspectSdiRunsCommand();
            baselineLoaded = viewModel.loadBaselineRunCommand( ...
                baselineRunID);
            compareLoaded = viewModel.loadCompareRunCommand(compareRunID);

            testCase.verifyTrue(any([runs.RunID] == baselineRunID));
            testCase.verifyTrue(baselineLoaded);
            testCase.verifyTrue(compareLoaded);
            testCase.verifySubstring( ...
                viewModel.BaselineFileDisplay, "view model baseline");
            testCase.verifySubstring( ...
                viewModel.CompareFileDisplay, "view model comparison");
            testCase.verifySubstring( ...
                viewModel.BaselineStatus, "SDI run");
            testCase.verifyEqual(viewModel.SignalTable.Status, "Matched");
            testCase.verifyTrue(viewModel.CanCompare);
        end

        function testReportsInvalidSdiSessionImport(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            invalidFile = fullfile(folder, "not-a-session.mat");
            ordinaryValue = 42;
            save(invalidFile, "ordinaryValue");
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);

            runs = viewModel.importSdiSessionCommand(invalidFile);

            testCase.verifyEmpty(runs);
            testCase.verifyTrue(startsWith( ...
                viewModel.StatusMessage, ...
                "SDI session import failed:"));
        end

        function testPublishesAndPlotsFlattenedBusLeaves(testCase)
            [viewModel, ~] = createLoadedBusViewModel(testCase);
            signalName = ...
                "NonVirtualBus.Controller.Measurements.Vector";
            row = find(viewModel.SignalTable.Name == signalName, 1);

            viewModel.selectRowCommand(row);
            viewModel.setElementCommand("2");

            testCase.verifyEqual(height(viewModel.SignalTable), 4);
            testCase.verifyEqual( ...
                viewModel.SignalTable.Name(row), signalName);
            testCase.verifyEqual(viewModel.PlotData.Name, signalName);
            testCase.verifyEqual( ...
                viewModel.PlotData.BaselineData, [10; 20; 30], ...
                AbsTol=1e-12);
            testCase.verifyEqual( ...
                viewModel.PlotData.CompareData, [20; 40; 60], ...
                AbsTol=1e-12);
        end

        function testExportSelectionCommands(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);

            viewModel.selectAllForExportCommand();

            testCase.verifyTrue(all(viewModel.SignalTable.Export));
            testCase.verifyTrue(viewModel.CanExport);

            viewModel.clearExportSelectionCommand();

            testCase.verifyFalse(any(viewModel.SignalTable.Export));
            testCase.verifyFalse(viewModel.CanExport);
            testCase.verifyError( ...
                @() viewModel.exportSelectedPlots( ...
                fullfile(files.Folder, "empty"), "png"), ...
                "simcompare:ViewModel:NoExportSelection");
        end

        function testExportUsesActiveElementAndViewState(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            outputFolder = fullfile(files.Folder, "view-model-export");
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("2");
            viewModel.setTimeUnitCommand("ms");
            viewModel.setTimeShiftCommand(250);
            viewModel.setXLimitsCommand(0, 2000);
            viewModel.setExportSelectionCommand(vectorRow, true);

            exported = viewModel.exportSelectedPlots( ...
                outputFolder, "png");

            [~, name, extension] = fileparts(exported);
            testCase.verifyEqual( ...
                string(name) + string(extension), ...
                "vector_element_2.png");
            testCase.verifyTrue(isfile(exported));
            testCase.verifyFalse(viewModel.IsExporting);
            testCase.verifySubstring( ...
                viewModel.StatusMessage, "Exported 1 comparison plot");
        end

        function testQuickExportUsesCurrentSignalAndElement(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            progressRecorder = testsupport.ExportProgressRecorder();
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("3");

            exported = viewModel.exportCurrentPlot( ...
                files.Folder, "png", ...
                ProgressFcn=@progressRecorder.record);

            testCase.verifyEqual( ...
                string(exported), ...
                fullfile(files.Folder, "vector_element_3.png"));
            testCase.verifyTrue(isfile(exported));
            testCase.verifyEqual(progressRecorder.Indices, 1);
            testCase.verifyEqual(progressRecorder.Counts, 1);
            testCase.verifyEqual(progressRecorder.Fractions, 1, ...
                AbsTol=1e-12);
            testCase.verifyEqual(progressRecorder.FigureThemes, "light");
            testCase.verifyEqual( ...
                progressRecorder.SourceTileSpans, [3, 1]);
            testCase.verifyEqual( ...
                progressRecorder.ErrorTileSpans, [1, 1]);
            testCase.verifyEqual(progressRecorder.ErrorXGrids, "on");
            testCase.verifyEqual(progressRecorder.ErrorYGrids, "on");
            testCase.verifyEqual( ...
                progressRecorder.ErrorTitles, ...
                "Relative error (linear interpolation)");
            testCase.verifyEqual(progressRecorder.ErrorYLabels, "Error (%)");
            testCase.verifyEqual( ...
                progressRecorder.ErrorDisplayNames, "Relative error");
            testCase.verifyEqual( ...
                progressRecorder.ErrorYData{1}, [1; 0.5; 1/3], ...
                AbsTol=1e-12);
            testCase.verifyEqual( ...
                progressRecorder.BaselineDisplayNames, ...
                "baselineLogs | Baseline");
            testCase.verifyEqual( ...
                progressRecorder.CompareDisplayNames, ...
                "comparisonLogs | Comparison");
            testCase.verifyEqual( ...
                progressRecorder.LegendStrings{1}, ...
                ["baselineLogs | Baseline", ...
                "comparisonLogs | Comparison"]);
            testCase.verifyEqual(progressRecorder.LegendTiles, "north");
            testCase.verifyFalse(viewModel.IsExporting);
            testCase.verifySubstring( ...
                viewModel.StatusMessage, "Exported 1 comparison plot");
        end

        function testExportUsesSelectedAbsoluteErrorType(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            vectorRow = find(viewModel.SignalTable.Name == "vector", 1);
            progressRecorder = testsupport.ExportProgressRecorder();
            viewModel.selectRowCommand(vectorRow);
            viewModel.setElementCommand("3");
            viewModel.setErrorTypeCommand("Absolute");

            exported = viewModel.exportCurrentPlot( ...
                files.Folder, "png", ...
                ProgressFcn=@progressRecorder.record);

            testCase.verifyTrue(isfile(exported));
            testCase.verifyEqual( ...
                progressRecorder.ErrorTitles, ...
                "Absolute error (linear interpolation)");
            testCase.verifyEqual(progressRecorder.ErrorYLabels, "Error");
            testCase.verifyEqual( ...
                progressRecorder.ErrorDisplayNames, "Absolute error");
            testCase.verifyEqual( ...
                progressRecorder.ErrorYData{1}, [1; 1; 1], ...
                AbsTol=1e-12);
        end

        function testSingleSourceExportLegendMatchesPlot( ...
                testCase, SingleSource)
            [viewModel, folder] = createSingleSourceViewModel( ...
                testCase, SingleSource.Role);
            progressRecorder = testsupport.ExportProgressRecorder();

            exported = viewModel.exportCurrentPlot( ...
                folder, "png", ...
                ProgressFcn=@progressRecorder.record);

            testCase.verifyTrue(isfile(exported));
            testCase.verifyEqual( ...
                progressRecorder.LegendStrings{1}, ...
                SingleSource.ExpectedLegendText);
        end

        function testBatchExportReportsCompletedFileFractions(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            progressRecorder = testsupport.ExportProgressRecorder();
            outputFolder = fullfile(files.Folder, "batch-progress");
            viewModel.selectAllForExportCommand();

            viewModel.exportSelectedPlots( ...
                outputFolder, "png", ...
                ProgressFcn=@progressRecorder.record);

            testCase.verifyEqual(progressRecorder.Indices, [1; 2]);
            testCase.verifyEqual(progressRecorder.Counts, [2; 2]);
            testCase.verifyEqual( ...
                progressRecorder.Fractions, [0.5; 1], AbsTol=1e-12);
        end

        function testExportUsesCustomLegendText(testCase)
            [viewModel, files] = createLoadedViewModel(testCase);
            progressRecorder = testsupport.ExportProgressRecorder();

            viewModel.exportCurrentPlot( ...
                files.Folder, "png", ...
                BaselineLegendText="Reference", ...
                CompareLegendText="Candidate", ...
                ProgressFcn=@progressRecorder.record);

            testCase.verifyEqual( ...
                progressRecorder.BaselineDisplayNames, ...
                "baselineLogs | Reference");
            testCase.verifyEqual( ...
                progressRecorder.CompareDisplayNames, ...
                "comparisonLogs | Candidate");
        end

        function testQuickExportRequiresComparableSelection(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);

            testCase.verifyError( ...
                @() viewModel.exportCurrentPlot(string(tempdir), "png"), ...
                "simcompare:ViewModel:NoSelectedSignal");
        end
    end
end

function [viewModel, folder] = createSingleSourceViewModel(testCase, role)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
filePath = fullfile(folder, role + ".mat");
signals = {testsupport.spec("signal", [0; 1; 2], [1; 2; 3])};
testsupport.createDatasetFile(filePath, "logs", signals);
model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
viewModel = simcompare.ViewModels.MainViewModel(model);
testCase.addTeardown(@delete, viewModel);
if role == "baseline"
    viewModel.loadBaselineCommand(filePath);
else
    viewModel.loadCompareCommand(filePath);
end
end

function [viewModel, files] = createLoadedViewModel(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
time = [0; 1; 2];
baseline = { ...
    testsupport.spec("scalar", time, [1; 2; 3]), ...
    testsupport.spec("vector", time, ...
    [1, 10, 100; 2, 20, 200; 3, 30, 300])};
comparison = { ...
    testsupport.spec("scalar", time, [1; 2; 3]), ...
    testsupport.spec("vector", time, ...
    [2, 11, 101; 3, 21, 201; 4, 31, 301])};
testsupport.createDatasetFile(baselineFile, "baselineLogs", baseline);
testsupport.createDatasetFile(compareFile, "comparisonLogs", comparison);

model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
viewModel = simcompare.ViewModels.MainViewModel(model);
testCase.addTeardown(@delete, viewModel);
viewModel.loadBaselineCommand(baselineFile);
viewModel.loadCompareCommand(compareFile);

files = struct( ...
    "Folder", folder, ...
    "Baseline", baselineFile, ...
    "Compare", compareFile);
end

function viewModel = createLoadedScalarViewModel( ...
        testCase, baselineData, compareData)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
time = (0:numel(baselineData) - 1).';
baseline = {testsupport.spec("signal", time, baselineData)};
comparison = {testsupport.spec("signal", time, compareData)};
testsupport.createDatasetFile(baselineFile, "logs", baseline);
testsupport.createDatasetFile(compareFile, "logs", comparison);

model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
viewModel = simcompare.ViewModels.MainViewModel(model);
testCase.addTeardown(@delete, viewModel);
viewModel.loadBaselineCommand(baselineFile);
viewModel.loadCompareCommand(compareFile);
end

function viewModel = createLoadedFrameViewModel(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
sampleData = (1:6).';
baseline = {testsupport.spec( ...
    "frame", (0:0.1:0.5).', sampleData)};
comparison = {testsupport.spec( ...
    "frame", [0; 0.2; 0.4], reshape(sampleData, [2, 1, 3]))};
testsupport.createDatasetFile(baselineFile, "logs", baseline);
testsupport.createDatasetFile(compareFile, "logs", comparison);

model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
viewModel = simcompare.ViewModels.MainViewModel(model);
testCase.addTeardown(@delete, viewModel);
viewModel.loadBaselineCommand(baselineFile);
viewModel.loadCompareCommand(compareFile);
end

function [viewModel, files] = createLoadedBusViewModel(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
testsupport.createBusDatasetFile( ...
    baselineFile, "baselineLogs", 1);
testsupport.createBusDatasetFile( ...
    compareFile, "compareLogs", 2);

model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
viewModel = simcompare.ViewModels.MainViewModel(model);
testCase.addTeardown(@delete, viewModel);
viewModel.loadBaselineCommand(baselineFile);
viewModel.loadCompareCommand(compareFile);

files = struct( ...
    "Folder", folder, ...
    "Baseline", baselineFile, ...
    "Compare", compareFile);
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

function deleteSdiRun(runID)
if Simulink.sdi.isValidRunID(runID)
    Simulink.sdi.deleteRun(runID);
end
end
