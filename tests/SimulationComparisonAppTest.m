classdef SimulationComparisonAppTest < matlab.uitest.TestCase
    %SimulationComparisonAppTest Visible UIFigure smoke test.
    % Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        SilentUpdateScenario = {"failure", "unauthorized", "rateLimited", ...
            "notFound", "invalid", "current", "older", "prerelease", "draft"}
        RestoreAxes = struct( ...
            Source="SourceAxes", Error="ErrorAxes")
    end

    methods (TestClassSetup)
        function disableWarnings(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture

            % Delegate to SuppressedWarningsFixture to suppress display of warnings.
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:handle_graphics:exceptions:SceneNode'));
        end
    end

    methods (Test)
        function testClosingViewDuringUpdateDoesNotPresentOrOpenRelease(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.UpdatePromptRecorder("Download");
            view = simcompare.Views.MainView(viewModel, ...
                Version=matlab.mpm.Version("1.2.2"), ...
                UpdateChecker=@testsupport.UpdateCheckStub.delayedAvailable, ...
                UpdatePresenter=@recorder.present, UrlOpener=@recorder.open);
            testCase.addTeardown(@() deleteValidView(view));
            figureHandle = view.Figure;

            view.show();
            delete(view);

            testCase.verifyFalse(waitUntil(@() recorder.Count > 0, 2));
            testCase.verifyEmpty(recorder.OpenedURLs);
            testCase.verifyFalse(isvalid(figureHandle));
        end

        function testCreationInteractionResizeAndCleanup(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            time = [0; 1; 2];
            baseline = { ...
                testsupport.spec("scalar", time, [1; 2; 3]), ...
                testsupport.spec("vector", time, ...
                [1, 10; 2, 20; 3, 30])};
            comparison = { ...
                testsupport.spec("scalar", time, [1; 2; 3]), ...
                testsupport.spec("vector", time, ...
                [2, 11; 3, 21; 4, 31])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            app = runSimulationComparisonApp( ...
                BaselineFile=baselineFile, ...
                CompareFile=compareFile, ...
                CheckForUpdates=false);
            testCase.addTeardown(@() testsupport.deleteApp(app));
            drawnow;
            baselineLine = app.view.BaselineLine;

            testCase.verifyEqual( ...
                string(app.view.Figure.Name), ...
                "Simulation Comparison — v" + ...
                string(simcompare.toolboxVersion()));
            testCase.verifyClass( ...
                app.view.XMinField, "matlab.ui.control.Spinner");
            testCase.verifyClass( ...
                app.view.XMaxField, "matlab.ui.control.Spinner");
            testCase.verifyClass( ...
                app.view.ShiftField, "matlab.ui.control.Spinner");
            signalsPanel = app.view.SignalTable.Parent.Parent;
            testCase.verifyClass( ...
                signalsPanel, "matlab.ui.container.Panel");
            testCase.verifyEqual(string(signalsPanel.Title), "Signals");
            testCase.verifyEqual( ...
                string(app.view.SignalTable.ColumnName(4:5)), ...
                ["Base type"; "Compare type"]);
            testCase.verifyClass( ...
                app.view.SignalSearchField, ...
                "matlab.ui.control.EditField");
            testCase.verifyClass( ...
                app.view.SignalSearchClearButton, ...
                "matlab.ui.control.Button");
            testCase.verifySubstring( ...
                string(app.view.BaselineBrowseButton.Tooltip), ...
                "saved SDI session");
            testCase.verifySubstring( ...
                string(app.view.CompareBrowseButton.Tooltip), ...
                "saved SDI session");
            testCase.verifyEqual( ...
                numel(app.view.BaselineBrowseButton.Parent.ColumnWidth), 5);
            testCase.verifyEqual( ...
                string(app.view.BaselineClearButton.Text), "×");
            testCase.verifyEqual( ...
                string(app.view.CompareClearButton.Text), "×");
            testCase.verifyEqual( ...
                string(app.view.SignalSearchClearButton.Text), "×");
            app.viewModel.setXLimitsCommand(0, 23);
            testCase.verifyEqual( ...
                [app.view.XMinField.Step, ...
                app.view.XMaxField.Step, ...
                app.view.ShiftField.Step], ...
                [1, 1, 1], AbsTol=1e-12);
            app.viewModel.setXLimitsCommand(0, 8);
            testCase.verifyEqual( ...
                [app.view.XMinField.Step, ...
                app.view.XMaxField.Step, ...
                app.view.ShiftField.Step], ...
                [0.1, 0.1, 0.1], AbsTol=1e-12);
            testCase.verifyEqual(app.view.ElementField.Editable, ...
                matlab.lang.OnOffSwitchState.off);
            press(testCase, app.view.SelectAllExportButton);
            testCase.verifyTrue(all(app.viewModel.SignalTable.Export));
            testCase.verifyEqual( ...
                app.view.ExportButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual( ...
                app.view.QuickExportButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            press(testCase, app.view.ClearExportButton);
            testCase.verifyFalse(any(app.viewModel.SignalTable.Export));
            testCase.verifyEqual( ...
                app.view.QuickExportButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);

            choose(testCase, app.view.SignalTable, [1, 2]);
            type(testCase, app.view.SignalSearchField, "VCT");
            testCase.verifyEqual( ...
                app.view.SignalTable.Data.Name, "vector");
            testCase.verifyEmpty(app.view.SignalTable.Selection);
            press(testCase, app.view.SignalSearchClearButton);
            testCase.verifyEqual( ...
                string(app.view.SignalSearchField.Value), "");
            testCase.verifyEqual( ...
                app.view.SignalTable.Data.Name, ["scalar"; "vector"]);
            type(testCase, app.view.SignalSearchField, "VCT");
            drawnow;
            choose(testCase, app.view.SignalTable, [1, 2]);
            testCase.assertTrue(waitUntil( ...
                @() app.viewModel.SelectedRow == 2 && ...
                app.view.ElementField.Editable == ...
                matlab.lang.OnOffSwitchState.on, 30), ...
                "The filtered vector signal was not selected.");
            type(testCase, app.view.ElementField, "2");
            choose(testCase, app.view.TimeUnitDropdown, "ms");
            type(testCase, app.view.ShiftField, 500);
            drawnow;

            testCase.verifyEqual(app.viewModel.SelectedRow, 2);
            testCase.verifyEqual(app.viewModel.ElementText, "2");
            testCase.verifyEqual(app.view.CompareLine.XData, ...
                [500, 1500, 2500], AbsTol=1e-10);
            testCase.verifyEqual(numel(app.view.ErrorLine.XData), 2);

            press(testCase, app.view.ZeroShiftButton);
            app.view.Figure.Position(3:4) = [1000, 620];
            app.view.SourceAxes.YTick = [1, 2];
            app.view.SourceAxes.YTickLabel = { ...
                "-12345678901234567890", ...
                "12345678901234567890"};
            app.view.ErrorAxes.YTick = [0, 1];
            app.view.ErrorAxes.YTickLabel = {"0", "1"};
            drawnow;

            testCase.verifyEqual(app.viewModel.getTimeShiftSeconds(), 0, ...
                AbsTol=1e-12);
            testCase.verifyEqual(app.view.Figure.Position(3:4), ...
                [1000, 620], AbsTol=1e-12);
            testCase.verifyTrue(isvalid(app.view.BaselineLine));
            testCase.verifyEqual(app.view.BaselineLine, baselineLine);
            testCase.verifyEqual( ...
                app.view.SourceAxes.InnerPosition([1, 3]), ...
                app.view.ErrorAxes.InnerPosition([1, 3]), ...
                AbsTol=1e-10);

            figureHandle = app.view.Figure;
            delete(app.view);

            testCase.verifyFalse(isvalid(figureHandle));
        end

        function testSourceClearButtonsRefreshApp(testCase)
            [viewModel, view] = createLoadedView(testCase);
            view.show();
            drawnow;

            testCase.verifyEqual( ...
                view.BaselineClearButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual( ...
                view.CompareClearButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            press(testCase, view.BaselineClearButton);
            drawnow;

            testCase.verifyEqual(string(view.BaselineFileField.Value), "");
            testCase.verifyEqual( ...
                string(view.BaselineStatusLabel.Text), "Not loaded");
            testCase.verifyEmpty(view.BaselineLine.YData);
            testCase.verifyNotEmpty(view.CompareLine.YData);
            testCase.verifyEmpty(view.ErrorLine.YData);
            testCase.verifyEqual( ...
                string(view.SignalTable.Data.Status), "Compare only");
            testCase.verifyEqual( ...
                view.BaselineClearButton.Enable, ...
                matlab.lang.OnOffSwitchState.off);
            press(testCase, view.CompareClearButton);
            drawnow;

            testCase.verifyEqual(string(view.CompareFileField.Value), "");
            testCase.verifyEqual( ...
                string(view.CompareStatusLabel.Text), "Not loaded");
            testCase.verifyEqual(height(view.SignalTable.Data), 0);
            testCase.verifyEmpty(view.CompareLine.YData);
            testCase.verifyFalse(viewModel.CanCompare);
            testCase.verifyEqual( ...
                view.CompareClearButton.Enable, ...
                matlab.lang.OnOffSwitchState.off);
        end

        function testDisplaysInjectedVersionInTitle(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            view = simcompare.Views.MainView( ...
                viewModel, ...
                Version=matlab.mpm.Version("1.2.3"), ...
                CheckForUpdates=false);
            testCase.addTeardown(@delete, view);

            testCase.verifyEqual( ...
                string(view.Figure.Name), ...
                "Simulation Comparison — v1.2.3");
        end

        function testErrorTypeDropdownUpdatesErrorPlot(testCase)
            [viewModel, view] = createLoadedView(testCase);
            view.show();
            drawnow;

            testCase.verifyEqual( ...
                string(view.ErrorTypeDropdown.Value), "Relative");
            testCase.verifyEqual(viewModel.ErrorType, "Relative");
            choose(testCase, view.ErrorTypeDropdown, "Absolute");
            drawnow;

            testCase.verifyEqual(viewModel.ErrorType, "Absolute");
            testCase.verifyEqual( ...
                string(view.ErrorAxes.Title.String), ...
                "Absolute error (linear interpolation)");
            testCase.verifyEqual( ...
                string(view.ErrorAxes.YLabel.String), "Error");
            testCase.verifyEqual( ...
                string(view.ErrorLine.DisplayName), "Absolute error");
            testCase.verifyEqual( ...
                view.ErrorLine.YData, [0, 0, 0], AbsTol=1e-12);
        end

        function testDisplaysAssumedLoggedSignalUnitOnSourceAxis(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            createUnitDatasetFile(baselineFile, "velocity", "");
            createUnitDatasetFile(compareFile, "velocity", "m/s");

            app = runSimulationComparisonApp( ...
                BaselineFile=baselineFile, ...
                CompareFile=compareFile, ...
                CheckForUpdates=false);
            testCase.addTeardown(@() testsupport.deleteApp(app));
            drawnow;

            testCase.verifyEqual( ...
                string(app.view.SourceAxes.YLabel.String), "Value (m/s)");
        end

        function testConvertsCompatibleSignalUnitsForPlot(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, "s"));
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            createUnitDatasetFile( ...
                baselineFile, "distance", "m", [1; 2; 3]);
            createUnitDatasetFile( ...
                compareFile, "distance", "cm", [100; 200; 300]);

            app = runSimulationComparisonApp( ...
                BaselineFile=baselineFile, ...
                CompareFile=compareFile, ...
                CheckForUpdates=false);
            testCase.addTeardown(@() testsupport.deleteApp(app));
            drawnow;

            testCase.verifyEqual( ...
                string(app.view.SourceAxes.YLabel.String), "Value (m)");
            testCase.verifyEqual( ...
                app.view.CompareLine.YData, [1, 2, 3], AbsTol=1e-12);
            testCase.verifySubstring( ...
                app.viewModel.SignalTable.Details, ...
                "Implicitly converting comparison unit 'cm' to baseline unit 'm'.");
        end

        function testSkipsUpdateCheckForDevelopmentVersion(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.UpdatePromptRecorder();
            view = simcompare.Views.MainView( ...
                viewModel, ...
                Version=matlab.mpm.Version("0.0.0"), ...
                UpdateChecker= ...
                    @testsupport.UpdateCheckStub.delayedAvailable, ...
                UpdatePresenter=@recorder.present);
            testCase.addTeardown(@delete, view);

            view.show();

            testCase.verifyFalse(waitUntil( ...
                @() recorder.Count > 0, 5), ...
                "Development mode unexpectedly checked for updates.");
            testCase.verifyTrue(isvalid(view.Figure));
        end

        function testPromptsForNewReleaseAndOpensDownloadPage(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.UpdatePromptRecorder("Download");
            releaseURL = "https://github.com/mathworks/Simulation-Comparison-App/releases/tag/v1.2.3";
            view = simcompare.Views.MainView( ...
                viewModel, ...
                Version=matlab.mpm.Version("1.2.2"), ...
                UpdateChecker= ...
                    @testsupport.UpdateCheckStub.delayedAvailable, ...
                UpdatePresenter=@recorder.present, ...
                UrlOpener=@recorder.open);
            testCase.addTeardown(@delete, view);

            view.show();
            view.show();

            testCase.assertTrue(waitUntil( ...
                @() recorder.Count == 1, 30), ...
                "The asynchronous update check did not complete.");
            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual(recorder.Figure, view.Figure);
            testCase.verifyEqual( ...
                recorder.Result.LatestVersion, ...
                matlab.mpm.Version("1.2.3"));
            testCase.verifyEqual(recorder.OpenedURLs, releaseURL);
        end

        function testIgnoresUnavailableUpdate(testCase, SilentUpdateScenario)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.UpdatePromptRecorder();
            errorRecorder = testsupport.IssueReportRecorder("Not now");
            view = simcompare.Views.MainView( ...
                viewModel, ...
                Version=matlab.mpm.Version("1.2.2"), ...
                UpdateChecker=@() testsupport.UpdateCheckStub.delayedResponse( ...
                    SilentUpdateScenario), ...
                UpdatePresenter=@recorder.present, ...
                UrlOpener=@recorder.open, ...
                ErrorReporter=@errorRecorder.report);
            testCase.addTeardown(@delete, view);

            view.show();

            testCase.verifyFalse(waitUntil(@() recorder.Count > 0, 2));
            testCase.verifyEqual(recorder.Count, 0);
            testCase.verifyEqual(errorRecorder.Count, 0);
            testCase.verifyEmpty(recorder.OpenedURLs);
            testCase.verifyTrue(isvalid(view.Figure));
        end

        function testLaterDoesNotOpenDownloadPage(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.UpdatePromptRecorder("Later");
            view = simcompare.Views.MainView( ...
                viewModel, ...
                Version=matlab.mpm.Version("1.2.2"), ...
                UpdateChecker= ...
                    @testsupport.UpdateCheckStub.delayedAvailable, ...
                UpdatePresenter=@recorder.present, ...
                UrlOpener=@recorder.open);
            testCase.addTeardown(@delete, view);

            view.show();

            testCase.assertTrue(waitUntil( ...
                @() recorder.Count == 1, 30), ...
                "The asynchronous update check did not complete.");
            testCase.verifyEqual(recorder.Figure, view.Figure);
            testCase.verifyEmpty(recorder.OpenedURLs);
        end

        function testSkipsUpdateCheckWhenDisabled(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.UpdatePromptRecorder();
            view = simcompare.Views.MainView( ...
                viewModel, Version=matlab.mpm.Version("1.2.2"), ...
                CheckForUpdates=false, ...
                UpdateChecker=@testsupport.UpdateCheckStub.delayedAvailable, ...
                UpdatePresenter=@recorder.present);
            testCase.addTeardown(@delete, view);

            view.show();

            testCase.verifyFalse(waitUntil(@() recorder.Count > 0, 2));
            testCase.verifyTrue(isvalid(view.Figure));
        end

        function testNoLicenseWarningIsPresentedOnce(testCase)
            recorder = testsupport.WarningRecorder();
            testCase.addTeardown(@delete, recorder);
            model = simcompare.Models.ComparisonModel( ...
                FixedPointAvailable=false);
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            view = simcompare.Views.MainView( ...
                viewModel, ...
                WarningPresenter=@recorder.present, ...
                CheckForUpdates=false);
            testCase.addTeardown(@delete, view);

            testCase.verifyEqual( ...
                view.QuickExportButton.Enable, ...
                matlab.lang.OnOffSwitchState.off);
            view.show();
            view.show();

            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual(recorder.Figure, view.Figure);
            testCase.verifySubstring( ...
                recorder.Message, "Fixed-Point Designer license");
        end

        function testPlotsBaselineOnlySourceWithoutLegend(testCase)
            app = createSingleSourceApp(testCase, "baseline");
            drawnow;

            testCase.verifyEqual(app.view.BaselineLine.XData, [0, 1, 2], ...
                AbsTol=1e-12);
            testCase.verifyEqual(app.view.BaselineLine.YData, [1, 2, 3], ...
                AbsTol=1e-12);
            testCase.verifyEmpty(app.view.CompareLine.XData);
            testCase.verifyEqual(app.view.SourceLegend.Visible, ...
                matlab.lang.OnOffSwitchState.off);
        end

        function testPlotsComparisonOnlySourceWithoutLegend(testCase)
            app = createSingleSourceApp(testCase, "compare");
            drawnow;

            testCase.verifyEmpty(app.view.BaselineLine.XData);
            testCase.verifyEqual(app.view.CompareLine.XData, [0, 1, 2], ...
                AbsTol=1e-12);
            testCase.verifyEqual(app.view.CompareLine.YData, [1, 2, 3], ...
                AbsTol=1e-12);
            testCase.verifyEqual(app.view.SourceLegend.Visible, ...
                matlab.lang.OnOffSwitchState.off);
        end

        function testFrameBasedInterpretationControlExpandsSignal(testCase)
            app = createFrameBasedApp(testCase);
            drawnow;

            testCase.verifyEqual( ...
                app.view.SignalInterpretationDropdown.Layout.Row, 1);
            testCase.verifyEqual( ...
                app.view.SignalInterpretationDropdown.Layout.Column, 2);
            testCase.verifyEqual(app.view.ElementField.Layout.Row, 1);
            testCase.verifyEqual(app.view.ElementField.Layout.Column, 4);
            testCase.verifyEqual(app.view.SelectionLabel.Layout.Row, 2);
            testCase.verifyEqual( ...
                app.view.SelectionLabel.Layout.Column, [1, 4]);

            choose(testCase, app.view.SignalInterpretationDropdown, ...
                "Frame-based");
            drawnow;

            testCase.verifyEqual( ...
                string(app.view.SignalInterpretationDropdown.Value), ...
                "Frame-based");
            testCase.verifyEqual(app.view.ElementField.Editable, ...
                matlab.lang.OnOffSwitchState.off);
            testCase.verifyEqual(app.view.CompareLine.XData(:), ...
                (0:0.1:0.5).', AbsTol=1e-12);
            testCase.verifyEqual(app.view.CompareLine.YData(:), ...
                (1:6).', AbsTol=1e-12);
        end

        function testQuickExportWritesCurrentSignalToCurrentFolder(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            folder = string(pwd);
            baselineFile = fullfile(folder, "baseline.mat");
            compareFile = fullfile(folder, "compare.mat");
            time = [0; 1; 2];
            baseline = { ...
                testsupport.spec("signal", time, [1; 2; 3])};
            comparison = { ...
                testsupport.spec("signal", time, [2; 3; 4])};
            testsupport.createDatasetFile( ...
                baselineFile, "logs", baseline);
            testsupport.createDatasetFile( ...
                compareFile, "logs", comparison);
            app = runSimulationComparisonApp( ...
                BaselineFile=baselineFile, ...
                CompareFile=compareFile, ...
                CheckForUpdates=false);
            testCase.addTeardown(@() testsupport.deleteApp(app));
            drawnow;

            choose(testCase, app.view.ExportFormatDropdown, "JPEG");
            press(testCase, app.view.QuickExportButton);

            expectedFile = fullfile(folder, "signal.jpg");
            testCase.verifyTrue(isfile(expectedFile));
            testCase.verifySubstring( ...
                app.viewModel.StatusMessage, folder);
        end

        function testRestoresFocusAfterFolderChooserCloses(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.WarningRecorder();
            view = simcompare.Views.MainView( ...
                viewModel, ...
                CheckForUpdates=false, ...
                FolderSelector=@(~, ~) 0, ...
                FigureActivator=@(figureHandle) ...
                    recorder.present(figureHandle, ""));
            testCase.addTeardown(@delete, view);

            view.ExportButton.ButtonPushedFcn( ...
                view.ExportButton, []);

            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual(recorder.Figure, view.Figure);
        end

        function testRestoresFocusAfterSdiRunChooserCloses(testCase)
            createSdiRun(testCase, "Focus test", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.WarningRecorder();
            view = simcompare.Views.MainView( ...
                viewModel, ...
                CheckForUpdates=false, ...
                SdiRunSelector=@(~, ~) NaN, ...
                FigureActivator=@(figureHandle) ...
                    recorder.present(figureHandle, ""));
            testCase.addTeardown(@delete, view);

            view.BaselineSdiButton.ButtonPushedFcn( ...
                view.BaselineSdiButton, []);

            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual(recorder.Figure, view.Figure);
        end

        function testSdiSessionImportExplainsRunReuse(testCase)
            recorder = testsupport.WarningRecorder();
            runs = struct( ...
                "RunID", 1, ...
                "Name", "Imported session run", ...
                "SignalCount", 1, ...
                "DisplayName", "Imported session run — run 1 (1 signal)");
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            view = simcompare.Views.MainView( ...
                viewModel, ...
                CheckForUpdates=false, ...
                SdiRunSelector=@(~, ~) NaN, ...
                SdiSessionImporter=@(~) runs, ...
                SdiSessionImportPresenter=@recorder.present, ...
                FileSelector=@(~, ~) deal("session.mldatx", ""), ...
                FigureActivator=@(~) []);
            testCase.addTeardown(@delete, view);
            view.show();
            drawnow;

            view.BaselineBrowseButton.ButtonPushedFcn( ...
                view.BaselineBrowseButton, []);

            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual(recorder.Figure, view.Figure);
            testCase.verifySubstring(recorder.Message, "SDI... button");
            testCase.verifySubstring( ...
                recorder.Message, "do not need to browse");
        end

        function testLegendContextMenuUpdatesLabelsAndCancelKeepsThem( ...
                testCase)
            editor = testsupport.LegendTextEditorStub( ...
                {["Reference", "Candidate"], ["Ignored", "Ignored"]}, ...
                [true, false]);
            app = createLegendEditorApp(testCase, @editor.present);
            drawnow;

            testCase.verifyEqual( ...
                string(app.view.BaselineLine.DisplayName), "Baseline");
            testCase.verifyEqual( ...
                string(app.view.CompareLine.DisplayName), "Comparison");

            invokeMenu( ...
                app.view.SourceAxesContextMenu, ...
                "Edit legend labels...");

            testCase.verifyEqual( ...
                string(app.view.BaselineLine.DisplayName), "Reference");
            testCase.verifyEqual( ...
                string(app.view.CompareLine.DisplayName), "Candidate");
            testCase.verifyEqual( ...
                editor.Defaults{1}, ["Baseline", "Comparison"]);

            invokeMenu( ...
                app.view.SourceAxesContextMenu, ...
                "Edit legend labels...");

            testCase.verifyEqual( ...
                editor.Defaults{2}, ["Reference", "Candidate"]);
            testCase.verifyEqual( ...
                string(app.view.SourceLegend.String), ...
                ["Reference", "Candidate"]);
        end

        function testPlotContextMenuActions(testCase)
            [viewModel, view] = createLoadedView(testCase);

            sourceMenu = view.SourceAxesContextMenu;
            testCase.verifyEqual(view.SourceAxes.ContextMenu, sourceMenu);
            testCase.verifyEqual( ...
                view.BaselineLine.ContextMenu, sourceMenu);
            testCase.verifyEqual( ...
                view.CompareLine.ContextMenu, sourceMenu);
            testCase.verifyEqual( ...
                view.ErrorAxes.ContextMenu, view.ErrorAxesContextMenu);
            testCase.verifyEqual( ...
                view.ErrorLine.ContextMenu, view.ErrorAxesContextMenu);
            menuLabels = string({sourceMenu.Children.Text});
            testCase.verifyTrue(all(ismember( ...
                ["Set X-min here", "Set X-max here", ...
                "Set time shift here", "Zero time shift", "Reset view", ...
                "Edit legend labels..."], ...
                menuLabels)));
            errorMenuLabels = string( ...
                {view.ErrorAxesContextMenu.Children.Text});
            testCase.verifyFalse(any( ...
                errorMenuLabels == "Set time shift here"));
            testCase.verifyFalse(any( ...
                errorMenuLabels == "Edit legend labels..."));

            setContextPoint(sourceMenu, 0.5, NaN);
            invokeMenu(sourceMenu, "Set X-min here");
            testCase.verifyEqual(viewModel.XMin, 0.5, AbsTol=1e-12);

            setContextPoint(sourceMenu, 1.8, NaN);
            invokeMenu(sourceMenu, "Set X-max here");
            testCase.verifyEqual(viewModel.XMax, 1.8, AbsTol=1e-12);

            setContextPoint(sourceMenu, 1.75, 2.1);
            invokeMenu(sourceMenu, "Set time shift here");
            testCase.verifyEqual(viewModel.ShiftValue, 0.65, ...
                AbsTol=1e-12);

            invokeMenu(sourceMenu, "Zero time shift");
            testCase.verifyEqual(viewModel.ShiftValue, 0, ...
                AbsTol=1e-12);
        end

        function testAxesZoomUpdatesTimeAndViewPanel(testCase)
            [viewModel, view] = createLoadedView(testCase);

            view.SourceAxes.XLim = [0.25, 1.25];
            drawnow;

            testCase.verifyEqual( ...
                [view.XMinField.Value, view.XMaxField.Value], ...
                [0.25, 1.25], AbsTol=1e-12);
            testCase.verifyEqual( ...
                viewModel.getXLimitsSeconds(), ...
                [0.25, 1.25], AbsTol=1e-12);
            testCase.verifyEqual(view.ShiftSlider.Limits, [-1, 1], ...
                AbsTol=1e-12);
            testCase.verifyEqual(view.ShiftField.Limits, [-1, 1], ...
                AbsTol=1e-12);

            viewModel.setTimeUnitCommand("ms");
            view.ErrorAxes.XLim = [500, 1500];
            drawnow;

            testCase.verifyEqual( ...
                [view.XMinField.Value, view.XMaxField.Value], ...
                [500, 1500], AbsTol=1e-12);
            testCase.verifyEqual( ...
                viewModel.getXLimitsSeconds(), ...
                [0.5, 1.5], AbsTol=1e-12);
            testCase.verifyEqual( ...
                view.SourceAxes.XLim, view.ErrorAxes.XLim, ...
                AbsTol=1e-12);
            testCase.verifyEqual( ...
                view.ShiftSlider.Limits, [-1000, 1000], ...
                AbsTol=1e-12);
        end

        function testAxesRestoreViewUpdatesTimeAndViewPanel( ...
                testCase, RestoreAxes)
            [viewModel, view] = createLoadedView(testCase);
            axesHandle = view.(RestoreAxes);

            originalLimits = axesHandle.XLim;
            zoom(axesHandle, 2);
            drawnow;
            testCase.assertNotEqual(axesHandle.XLim, originalLimits);
            % Use the supported restore operation without creating a toolbar.
            zoom(axesHandle, "out");
            drawnow;
            testCase.assertTrue(waitUntil( ...
                @() isequal(viewModel.getXLimitsSeconds(), originalLimits), ...
                5), "Restored limits were not synchronized.");

            restoredLimits = view.SourceAxes.XLim;
            testCase.verifyEqual( ...
                restoredLimits, originalLimits, AbsTol=1e-12);
            testCase.verifyEqual( ...
                [view.XMinField.Value, view.XMaxField.Value], ...
                restoredLimits, AbsTol=1e-12);
            testCase.verifyEqual( ...
                viewModel.getXLimitsSeconds(), ...
                restoredLimits, AbsTol=1e-12);
            testCase.verifyEqual( ...
                view.ErrorAxes.XLim, restoredLimits, AbsTol=1e-12);
        end

        function testLoadsCurrentSdiRunsAtStartup(testCase)
            baselineRunID = createSdiRun(testCase, ...
                "app baseline", ...
                {testsupport.spec("signal", [0; 1], [1; 2])});
            compareRunID = createSdiRun(testCase, ...
                "app comparison", ...
                {testsupport.spec("signal", [0; 1], [2; 3])});

            app = runSimulationComparisonApp( ...
                BaselineRunID=baselineRunID, ...
                CompareRunID=compareRunID, ...
                CheckForUpdates=false);
            testCase.addTeardown(@() testsupport.deleteApp(app));
            drawnow;

            testCase.verifyEqual( ...
                app.model.BaselineRunID, baselineRunID);
            testCase.verifyEqual( ...
                app.model.CompareRunID, compareRunID);
            testCase.verifySubstring( ...
                string(app.view.BaselineFileField.Value), ...
                "app baseline");
            testCase.verifySubstring( ...
                string(app.view.CompareFileField.Value), ...
                "app comparison");
            testCase.verifyEqual( ...
                app.view.BaselineSdiButton.Enable, ...
                matlab.lang.OnOffSwitchState.on);
            testCase.verifyTrue(app.viewModel.CanCompare);
            testCase.verifyEqual(app.view.BaselineLine.YData, ...
                [1, 2], AbsTol=1e-12);
            testCase.verifyEqual(app.view.CompareLine.YData, ...
                [2, 3], AbsTol=1e-12);
        end

        function testRejectsConflictingStartupSources(testCase)
            recorder = testsupport.IssueReportRecorder();

            testCase.verifyError( ...
                @() runSimulationComparisonApp( ...
                BaselineFile="baseline.mat", ...
                BaselineRunID=1, ...
                IssueReporter=@recorder.report), ...
                "simcompare:App:ConflictingBaselineSource");
            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual( ...
                recorder.ExceptionIdentifier, ...
                "simcompare:App:ConflictingBaselineSource");
            testCase.verifyEqual(recorder.Context, "App startup");
        end

        function testCallbackErrorOffersIssueReporting(testCase)
            model = simcompare.Models.ComparisonModel();
            testCase.addTeardown(@delete, model);
            viewModel = simcompare.ViewModels.MainViewModel(model);
            testCase.addTeardown(@delete, viewModel);
            recorder = testsupport.IssueReportRecorder();
            view = simcompare.Views.MainView( ...
                viewModel, ...
                CheckForUpdates=false, ...
                FileSelector=@failFileSelection, ...
                ErrorReporter=@recorder.report);
            testCase.addTeardown(@delete, view);
            view.show();
            drawnow;

            press(testCase, view.BaselineBrowseButton);

            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEqual( ...
                recorder.ExceptionIdentifier, ...
                "simcompare:Test:FileSelectionFailed");
            testCase.verifyEqual( ...
                recorder.Context, "Browse baseline source");
            testCase.verifyEqual(recorder.Figure, view.Figure);
        end

        function testFiltersSelectsAndPlotsFlattenedBusLeaf(testCase)
            app = createBusApp(testCase);
            app.view.Figure.Position(3:4) = [1024, 744];
            nonVirtualName = ...
                "NonVirtualBus.Controller.Measurements.Scalar";
            virtualName = ...
                "VirtualBus.Controller.Measurements.Scalar";
            drawnow;

            type(testCase, app.view.SignalSearchField, nonVirtualName);
            drawnow;
            choose(testCase, app.view.SignalTable, [1, 2]);
            testCase.assertTrue(waitUntil( ...
                @() app.viewModel.PlotData.Name == nonVirtualName, 30), ...
                "The filtered nonvirtual bus leaf was not selected.");

            testCase.verifyEqual( ...
                app.view.SignalTable.Data.Name, nonVirtualName);
            testCase.verifyEqual( ...
                app.viewModel.PlotData.Name, nonVirtualName);
            testCase.verifyEqual( ...
                app.view.BaselineLine.YData, [1, 2, 3], ...
                AbsTol=1e-12);
            testCase.verifyEqual( ...
                app.view.CompareLine.YData, [2, 4, 6], ...
                AbsTol=1e-12);
            testCase.verifyEqual( ...
                string(app.view.SourceAxes.Title.String), nonVirtualName);

            press(testCase, app.view.SignalSearchClearButton);
            testCase.verifyEmpty(app.view.SignalTable.Selection);
            type(testCase, app.view.SignalSearchField, virtualName);
            drawnow;
            testCase.verifyEmpty(app.view.SignalTable.Selection);
            choose(testCase, app.view.SignalTable, [2, 2]);
            testCase.assertTrue(waitUntil( ...
                @() app.viewModel.PlotData.Name == virtualName, 30), ...
                "The filtered virtual bus leaf was not selected.");

            testCase.verifyEqual( ...
                app.view.SignalTable.Data.Name, ...
                [nonVirtualName; virtualName]);
            testCase.verifyEqual(app.viewModel.PlotData.Name, virtualName);
        end
    end
end

function [viewModel, view] = createLoadedView(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
time = [0; 1; 2];
signals = {testsupport.spec("signal", time, [1; 2; 3])};
testsupport.createDatasetFile(baselineFile, "logs", signals);
testsupport.createDatasetFile(compareFile, "logs", signals);

model = simcompare.Models.ComparisonModel();
testCase.addTeardown(@delete, model);
viewModel = simcompare.ViewModels.MainViewModel(model);
testCase.addTeardown(@delete, viewModel);
view = simcompare.Views.MainView( ...
    viewModel, CheckForUpdates=false);
testCase.addTeardown(@delete, view);
viewModel.loadBaselineCommand(baselineFile);
viewModel.loadCompareCommand(compareFile);
end

function createUnitDatasetFile(filePath, signalName, unit, data)
if nargin < 4
    data = [1; 2; 3];
end
values = timeseries(data, (0:numel(data) - 1).');
if strlength(unit) > 0
    values.DataInfo.Units = Simulink.SimulationData.Unit(char(unit));
end
signal = Simulink.SimulationData.Signal;
signal.Name = char(signalName);
signal.Values = values;
logs = Simulink.SimulationData.Dataset;
logs = logs.addElement(signal);
save(filePath, "logs");
end

function app = createFrameBasedApp(testCase)
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
app = runSimulationComparisonApp( ...
    BaselineFile=baselineFile, ...
    CompareFile=compareFile, ...
    CheckForUpdates=false);
testCase.addTeardown(@() testsupport.deleteApp(app));
end

function app = createBusApp(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
testsupport.createBusDatasetFile( ...
    baselineFile, "baselineLogs", 1);
testsupport.createBusDatasetFile( ...
    compareFile, "compareLogs", 2);
app = runSimulationComparisonApp( ...
    BaselineFile=baselineFile, ...
    CompareFile=compareFile, ...
    CheckForUpdates=false);
testCase.addTeardown(@() testsupport.deleteApp(app));
end

function app = createSingleSourceApp(testCase, role)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
filePath = fullfile(folder, role + ".mat");
signals = {testsupport.spec("signal", [0; 1; 2], [1; 2; 3])};
testsupport.createDatasetFile(filePath, "logs", signals);
if role == "baseline"
    app = runSimulationComparisonApp( ...
        BaselineFile=filePath, CheckForUpdates=false);
else
    app = runSimulationComparisonApp( ...
        CompareFile=filePath, CheckForUpdates=false);
end
testCase.addTeardown(@() testsupport.deleteApp(app));
end

function app = createLegendEditorApp(testCase, legendTextPresenter)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, "s"));
baselineFile = fullfile(folder, "baseline.mat");
compareFile = fullfile(folder, "compare.mat");
signal = {testsupport.spec("signal", [0; 1], [1; 2])};
testsupport.createDatasetFile(baselineFile, "baselineSet", signal);
testsupport.createDatasetFile(compareFile, "comparisonSet", signal);

model = simcompare.Models.ComparisonModel();
viewModel = simcompare.ViewModels.MainViewModel(model);
view = simcompare.Views.MainView( ...
    viewModel, ...
    CheckForUpdates=false, ...
    LegendTextPresenter=legendTextPresenter);
app = struct("model", model, "viewModel", viewModel, "view", view);
testCase.addTeardown(@() testsupport.deleteApp(app));
view.show();
view.loadFile("baseline", baselineFile);
view.loadFile("compare", compareFile);
end

function setContextPoint(contextMenu, x, y)
context = contextMenu.UserData;
context.X = x;
context.Y = y;
contextMenu.UserData = context;
end

function invokeMenu(contextMenu, label)
menuItem = findobj(contextMenu.Children, "Text", label);
menuItem.MenuSelectedFcn(menuItem, []);
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

function [fileName, folder] = failFileSelection(varargin)
error("simcompare:Test:FileSelectionFailed", ...
    "Injected file selection failure.");
end

function deleteValidView(view)
if isvalid(view)
    delete(view);
end
end

function completed = waitUntil(condition, timeout)
started = tic;
while ~condition() && toc(started) < timeout
    pause(0.01);
    drawnow;
end
completed = condition();
end
