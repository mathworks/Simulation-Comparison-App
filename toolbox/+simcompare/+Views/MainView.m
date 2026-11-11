classdef MainView < handle
    %MainView UIFigure view for simulation comparison.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Figure
        FileMenu
        ViewMenu
        ExportMenu
        FeedbackMenu
        HelpMenu
        BaselineFileField
        CompareFileField
        BaselineBrowseButton
        CompareBrowseButton
        BaselineSdiButton
        CompareSdiButton
        BaselineClearButton
        CompareClearButton
        BaselineStatusLabel
        CompareStatusLabel
        SignalSearchField
        SignalSearchClearButton
        SignalTable
        SignalInterpretationDropdown
        ElementField
        SelectionLabel
        ErrorTypeDropdown
        TimeUnitDropdown
        XMinField
        XMaxField
        ResetViewButton
        ShiftSlider
        ShiftField
        ZeroShiftButton
        SelectAllExportButton
        ClearExportButton
        ExportFormatDropdown
        ExportButton
        QuickExportButton
        StatusLabel
        SourceAxes
        ErrorAxes
        SourceAxesContextMenu
        ErrorAxesContextMenu
        BaselineLine
        CompareLine
        ErrorLine
        SourceLegend
    end

    properties (Access = private)
        ViewModel simcompare.ViewModels.MainViewModel
        Listeners cell = {}
        ButtonMenus cell = cell(0, 2)
        LastPreviewTick = []
        IsDeleting logical = false
        WarningPresenter function_handle
        FixedPointWarningShown logical = false
        CurrentVersion matlab.mpm.Version
        CheckForUpdates logical
        UpdatePresenter function_handle
        UrlOpener function_handle
        LegendTextPresenter function_handle
        SdiRunSelector function_handle
        SdiSessionImporter function_handle
        SdiSessionImportPresenter function_handle
        FileSelector function_handle
        FolderSelector function_handle
        FigureActivator function_handle
        ErrorReporter function_handle
        LegendText (1, 2) string = ["Baseline", "Comparison"]
        UpdateCheckStarted logical = false
        UpdateChecker function_handle
        UpdateCheckFuture = []
        UpdateCheckCompletionFuture = []
        VisibleSignalRows double = zeros(0, 1)
        IsApplyingAxesLimits logical = false
        AxesRestoreTimer = []
        IsReportingError logical = false
    end

    methods
        function obj = MainView(viewModel, options)
            arguments
                viewModel simcompare.ViewModels.MainViewModel
                options.WarningPresenter (1, 1) function_handle = ...
                    @presentFixedPointWarning
                options.Version (1, 1) matlab.mpm.Version = ...
                    simcompare.toolboxVersion()
                options.CheckForUpdates (1, 1) logical = true
                options.UpdateChecker (1, 1) function_handle = ...
                    @simcompare.Models.ReleaseChecker.fetchLatestRelease
                options.UpdatePresenter (1, 1) function_handle = ...
                    @presentAvailableUpdate
                options.UrlOpener (1, 1) function_handle = @openReleasePage
                options.LegendTextPresenter (1, 1) function_handle = ...
                    @presentLegendTextEditor
                options.SdiRunSelector (1, 1) function_handle = ...
                    @presentSdiRunSelector
                options.SdiSessionImporter (1, 1) function_handle = ...
                    @(filePath) ...
                    viewModel.importSdiSessionCommand(filePath)
                options.SdiSessionImportPresenter (1, 1) function_handle = ...
                    @presentSdiSessionImportInfo
                options.FileSelector (1, 1) function_handle = @uigetfile
                options.FolderSelector (1, 1) function_handle = @uigetdir
                options.FigureActivator (1, 1) function_handle = @focus
                options.ErrorReporter (1, 1) function_handle = ...
                    @simcompare.IssueReporter.prompt
            end
            obj.ViewModel = viewModel;
            obj.WarningPresenter = options.WarningPresenter;
            obj.CurrentVersion = options.Version;
            obj.CheckForUpdates = options.CheckForUpdates;
            obj.UpdatePresenter = options.UpdatePresenter;
            obj.UrlOpener = options.UrlOpener;
            obj.LegendTextPresenter = options.LegendTextPresenter;
            obj.SdiRunSelector = options.SdiRunSelector;
            obj.SdiSessionImporter = options.SdiSessionImporter;
            obj.SdiSessionImportPresenter = ...
                options.SdiSessionImportPresenter;
            obj.FileSelector = options.FileSelector;
            obj.FolderSelector = options.FolderSelector;
            obj.FigureActivator = options.FigureActivator;
            obj.ErrorReporter = options.ErrorReporter;
            obj.UpdateChecker = options.UpdateChecker;
            obj.createUI(options.Version);
            obj.AxesRestoreTimer = timer( ...
                ExecutionMode="singleShot", StartDelay=0.01, ...
                TimerFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onAxesXLimitsChanged(obj.AxesRestoreTimer.UserData), ...
                "Synchronize restored plot limits"));
            obj.bindToViewModel();
            obj.syncFromViewModel();
        end

        function show(obj)
            obj.Figure.Visible = matlab.lang.OnOffSwitchState.on;
            drawnow;
            obj.showFixedPointWarning();
            obj.checkForAvailableUpdate();
        end

        function loadFile(obj, role, filePath)
            arguments
                obj
                role (1, 1) string {mustBeMember(role, ...
                    ["baseline", "compare"])}
                filePath (1, 1) string
            end
            names = obj.ViewModel.inspectDatasetNamesCommand(filePath);
            if isempty(names)
                return
            end
            if isscalar(names)
                datasetName = names(1);
            else
                [selection, accepted] = listdlg( ...
                    ListString=cellstr(names), ...
                    SelectionMode="single", ...
                    PromptString="Select a Dataset variable", ...
                    Name="Simulation Dataset");
                if ~accepted
                    return
                end
                datasetName = names(selection);
            end
            if role == "baseline"
                obj.ViewModel.loadBaselineCommand(filePath, datasetName);
            else
                obj.ViewModel.loadCompareCommand(filePath, datasetName);
            end
        end

        function loadRun(obj, role, runID)
            arguments
                obj
                role (1, 1) string {mustBeMember(role, ...
                    ["baseline", "compare"])}
                runID (1, 1) double {mustBeInteger, mustBePositive}
            end
            if role == "baseline"
                obj.ViewModel.loadBaselineRunCommand(runID);
            else
                obj.ViewModel.loadCompareRunCommand(runID);
            end
        end

        function loadSdiSession(obj, role, filePath)
            arguments
                obj
                role (1, 1) string {mustBeMember(role, ...
                    ["baseline", "compare"])}
                filePath (1, 1) string
            end
            runs = obj.SdiSessionImporter(filePath);
            obj.finishSdiSessionImport( ...
                role, runs, "Select a run imported from the SDI session");
        end

        function delete(obj)
            if obj.IsDeleting
                return
            end
            obj.IsDeleting = true;
            if ~isempty(obj.AxesRestoreTimer) && isvalid(obj.AxesRestoreTimer)
                stop(obj.AxesRestoreTimer);
                delete(obj.AxesRestoreTimer);
            end
            if ~isempty(obj.UpdateCheckFuture)
                cancel(obj.UpdateCheckFuture);
            end
            if ~isempty(obj.UpdateCheckCompletionFuture)
                cancel(obj.UpdateCheckCompletionFuture);
            end
            for index = 1:numel(obj.Listeners)
                listener = obj.Listeners{index};
                if isvalid(listener)
                    delete(listener);
                end
            end
            obj.Listeners = {};
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                obj.Figure.CloseRequestFcn = [];
                delete(obj.Figure);
            end
        end
    end

    methods (Access = private)
        function runGuarded(obj, callback, context)
            try
                callback();
            catch exception
                obj.reportError(exception, context);
            end
        end

        function reportError(obj, exception, context)
            if obj.IsDeleting || obj.IsReportingError
                return
            end
            obj.IsReportingError = true;
            reportingCleanup = onCleanup(@() obj.finishReportingError());
            simcompare.IssueReporter.notify( ...
                obj.ErrorReporter, exception, context, obj.Figure);
        end

        function finishReportingError(obj)
            obj.IsReportingError = false;
        end

        function createUI(obj, version)
            obj.Figure = uifigure( ...
                Name="Simulation Comparison — v" + string(version), ...
                Position=[100, 100, 1320, 780], ...
                AutoResizeChildren=matlab.lang.OnOffSwitchState.off, ...
                Visible=matlab.lang.OnOffSwitchState.off, ...
                CloseRequestFcn=@(~, ~) delete(obj));

            rootGrid = uigridlayout(obj.Figure, [1, 2]);
            rootGrid.ColumnWidth = {455, "1x"};
            rootGrid.Padding = [0, 0, 0, 0];
            rootGrid.ColumnSpacing = 6;

            sidebar = uipanel(rootGrid, Title="Comparison Controls");
            sidebar.Layout.Row = 1;
            sidebar.Layout.Column = 1;
            sidebarGrid = uigridlayout(sidebar, [6, 1]);
            sidebarGrid.RowHeight = { ...
                135, "1x", 75, 210, 92, 44};
            sidebarGrid.Scrollable = matlab.lang.OnOffSwitchState.on;
            sidebarGrid.Padding = [8, 8, 8, 8];
            sidebarGrid.RowSpacing = 7;
            obj.Figure.SizeChangedFcn = @(~, ~) ...
                updateSidebarLayout(sidebarGrid, obj.Figure);
            updateSidebarLayout(sidebarGrid, obj.Figure);

            obj.createFilePanel(sidebarGrid);
            obj.createSignalPanel(sidebarGrid);

            obj.createElementPanel(sidebarGrid);
            obj.createViewPanel(sidebarGrid);
            obj.createExportPanel(sidebarGrid);

            obj.StatusLabel = uilabel(sidebarGrid, ...
                Text="", ...
                WordWrap=matlab.lang.OnOffSwitchState.on, ...
                VerticalAlignment="center");
            obj.StatusLabel.Layout.Row = 6;

            plotPanel = uipanel(rootGrid, BorderType="none");
            plotPanel.Layout.Row = 1;
            plotPanel.Layout.Column = 2;
            plotLayout = tiledlayout(plotPanel, 4, 1, ...
                TileSpacing="compact", ...
                Padding="compact");

            obj.SourceAxes = uiaxes(plotLayout);
            obj.SourceAxes.Layout.Tile = 1;
            obj.SourceAxes.Layout.TileSpan = [3, 1];
            obj.SourceAxes.Title.String = "Source signals";
            obj.SourceAxes.YLabel.String = "Value";
            grid(obj.SourceAxes, matlab.lang.OnOffSwitchState.on);
            hold(obj.SourceAxes, matlab.lang.OnOffSwitchState.on);
            obj.BaselineLine = plot(obj.SourceAxes, NaN, NaN, ...
                DisplayName="Baseline", LineWidth=1.1);
            obj.CompareLine = plot(obj.SourceAxes, NaN, NaN, "--", ...
                DisplayName="Comparison", LineWidth=1.1);
            hold(obj.SourceAxes, matlab.lang.OnOffSwitchState.off);
            obj.SourceLegend = legend(obj.SourceAxes, Location="best");

            obj.ErrorAxes = uiaxes(plotLayout);
            obj.ErrorAxes.Layout.Tile = 4;
            obj.ErrorAxes.Title.String = "Relative error";
            obj.ErrorAxes.YLabel.String = "Error (%)";
            grid(obj.ErrorAxes, matlab.lang.OnOffSwitchState.on);
            obj.ErrorLine = plot(obj.ErrorAxes, NaN, NaN, ...
                DisplayName="Percent error", LineWidth=1.1);
            linkaxes([obj.SourceAxes, obj.ErrorAxes], "x");

            obj.SourceAxesContextMenu = ...
                obj.createPlotContextMenu(obj.SourceAxes, true);
            obj.SourceAxes.ContextMenu = obj.SourceAxesContextMenu;
            obj.BaselineLine.ContextMenu = obj.SourceAxesContextMenu;
            obj.CompareLine.ContextMenu = obj.SourceAxesContextMenu;

            obj.ErrorAxesContextMenu = ...
                obj.createPlotContextMenu(obj.ErrorAxes, false);
            obj.ErrorAxes.ContextMenu = obj.ErrorAxesContextMenu;
            obj.ErrorLine.ContextMenu = obj.ErrorAxesContextMenu;
            obj.createMenuBar();
        end

        function createMenuBar(obj)
            obj.FileMenu = uimenu(obj.Figure, Text="File");
            baselineMenu = uimenu(obj.FileMenu, Text="Baseline");
            obj.addButtonMenu(baselineMenu, ...
                "Load file or SDI session...", obj.BaselineBrowseButton);
            obj.addButtonMenu(baselineMenu, ...
                "Choose SDI run...", obj.BaselineSdiButton);
            obj.addButtonMenu(baselineMenu, ...
                "Clear source", obj.BaselineClearButton);
            comparisonMenu = uimenu(obj.FileMenu, Text="Comparison");
            obj.addButtonMenu(comparisonMenu, ...
                "Load file or SDI session...", obj.CompareBrowseButton);
            obj.addButtonMenu(comparisonMenu, ...
                "Choose SDI run...", obj.CompareSdiButton);
            obj.addButtonMenu(comparisonMenu, ...
                "Clear source", obj.CompareClearButton);
            uimenu(obj.FileMenu, Text="Close", Separator="on", ...
                MenuSelectedFcn=@(~, ~) delete(obj));

            obj.ViewMenu = uimenu(obj.Figure, Text="View");
            obj.addButtonMenu(obj.ViewMenu, ...
                "Reset view", obj.ResetViewButton);
            obj.addButtonMenu(obj.ViewMenu, ...
                "Zero time shift", obj.ZeroShiftButton);
            uimenu(obj.ViewMenu, Text="Edit legend labels...", ...
                Separator="on", ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onEditLegendText(), "Edit legend labels"));

            obj.ExportMenu = uimenu(obj.Figure, Text="Export");
            obj.addButtonMenu(obj.ExportMenu, ...
                "Select all signals", obj.SelectAllExportButton);
            obj.addButtonMenu(obj.ExportMenu, ...
                "Clear selection", obj.ClearExportButton);
            exportMenu = obj.addButtonMenu(obj.ExportMenu, ...
                "Export selected to folder...", obj.ExportButton);
            exportMenu.Separator = "on";
            obj.addButtonMenu(obj.ExportMenu, ...
                "Quick export current", obj.QuickExportButton);

            projectURL = simcompare.IssueReporter.ProjectURL;
            fileExchangeURL = "https://www.mathworks.com/matlabcentral/" + ...
                "fileexchange/185218-simulation-comparison-app";
            obj.FeedbackMenu = uimenu(obj.Figure, Text="Feedback");
            obj.addUrlMenu(obj.FeedbackMenu, "Report a bug", ...
                projectURL + "/issues/new?template=bug_report.md");
            obj.addUrlMenu(obj.FeedbackMenu, "Request a feature", ...
                projectURL + "/issues/new?template=feature_request.md");
            obj.addUrlMenu(obj.FeedbackMenu, "Write a review", ...
                fileExchangeURL + "#reviews_tab");

            obj.HelpMenu = uimenu(obj.Figure, Text="Help");
            uimenu(obj.HelpMenu, Text="Getting started", ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.openGettingStarted(), "Open getting started guide"));
            obj.addUrlMenu(obj.HelpMenu, "GitHub repository", projectURL);
            obj.addUrlMenu(obj.HelpMenu, "File Exchange", fileExchangeURL);
            uimenu(obj.HelpMenu, Text="About Simulation Comparison App", ...
                Separator="on", ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.showAbout(), "Show app information"));
        end

        function menu = addButtonMenu(obj, parent, text, button)
            menu = uimenu(parent, Text=text, Enable=button.Enable, ...
                MenuSelectedFcn=button.ButtonPushedFcn);
            obj.ButtonMenus(end + 1, :) = {menu, button};
        end

        function syncMenuEnabledState(obj)
            for index = 1:size(obj.ButtonMenus, 1)
                menu = obj.ButtonMenus{index, 1};
                button = obj.ButtonMenus{index, 2};
                menu.Enable = button.Enable;
            end
        end

        function addUrlMenu(obj, parent, text, url)
            uimenu(parent, Text=text, ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.UrlOpener(url), text));
        end

        function openGettingStarted(~)
            toolboxFolder = fileparts(fileparts(fileparts( ...
                mfilename("fullpath"))));
            open(fullfile(toolboxFolder, "doc", "GettingStarted.m"));
        end

        function showAbout(obj)
            uialert(obj.Figure, ...
                "Simulation Comparison App" + newline + ...
                "Version " + string(obj.CurrentVersion) + newline + newline + ...
                "Explore, align, and export signals from simulation " + ...
                "datasets and Simulation Data Inspector runs.", ...
                "About Simulation Comparison App", Icon="info");
        end

        function createFilePanel(obj, parent)
            panel = uipanel(parent, Title="Data sources");
            panel.Layout.Row = 1;
            gridLayout = uigridlayout(panel, [4, 5]);
            gridLayout.RowHeight = {"fit", "fit", "fit", "fit"};
            gridLayout.ColumnWidth = {72, "1x", 68, 56, 24};
            gridLayout.Padding = [6, 5, 6, 5];
            gridLayout.RowSpacing = 3;

            baselineLabel = uilabel(gridLayout, Text="Baseline");
            baselineLabel.Layout.Row = 1;
            baselineLabel.Layout.Column = 1;
            obj.BaselineFileField = uieditfield(gridLayout, "text", ...
                Editable=matlab.lang.OnOffSwitchState.off);
            obj.BaselineFileField.Layout.Row = 1;
            obj.BaselineFileField.Layout.Column = 2;
            obj.BaselineBrowseButton = uibutton(gridLayout, "push", ...
                Text="Browse...", ...
                Tooltip="Choose a MAT-file or saved SDI session", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onBrowse("baseline"), "Browse baseline source"));
            obj.BaselineBrowseButton.Layout.Row = 1;
            obj.BaselineBrowseButton.Layout.Column = 3;
            obj.BaselineSdiButton = uibutton(gridLayout, "push", ...
                Text="SDI...", ...
                Tooltip="Choose from current Simulation Data Inspector runs", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onChooseSdi("baseline"), ...
                "Choose baseline SDI run"));
            obj.BaselineSdiButton.Layout.Row = 1;
            obj.BaselineSdiButton.Layout.Column = 4;
            obj.BaselineClearButton = uibutton(gridLayout, "push", ...
                Text="×", ...
                Tooltip="Clear baseline source", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.clearBaselineCommand(), ...
                "Clear baseline source"));
            obj.BaselineClearButton.Layout.Row = 1;
            obj.BaselineClearButton.Layout.Column = 5;
            obj.BaselineStatusLabel = uilabel(gridLayout, Text="Not loaded");
            obj.BaselineStatusLabel.Layout.Row = 2;
            obj.BaselineStatusLabel.Layout.Column = [2, 5];

            compareLabel = uilabel(gridLayout, Text="Compare");
            compareLabel.Layout.Row = 3;
            compareLabel.Layout.Column = 1;
            obj.CompareFileField = uieditfield(gridLayout, "text", ...
                Editable=matlab.lang.OnOffSwitchState.off);
            obj.CompareFileField.Layout.Row = 3;
            obj.CompareFileField.Layout.Column = 2;
            obj.CompareBrowseButton = uibutton(gridLayout, "push", ...
                Text="Browse...", ...
                Tooltip="Choose a MAT-file or saved SDI session", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onBrowse("compare"), "Browse comparison source"));
            obj.CompareBrowseButton.Layout.Row = 3;
            obj.CompareBrowseButton.Layout.Column = 3;
            obj.CompareSdiButton = uibutton(gridLayout, "push", ...
                Text="SDI...", ...
                Tooltip="Choose from current Simulation Data Inspector runs", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onChooseSdi("compare"), ...
                "Choose comparison SDI run"));
            obj.CompareSdiButton.Layout.Row = 3;
            obj.CompareSdiButton.Layout.Column = 4;
            obj.CompareClearButton = uibutton(gridLayout, "push", ...
                Text="×", ...
                Tooltip="Clear comparison source", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.clearCompareCommand(), ...
                "Clear comparison source"));
            obj.CompareClearButton.Layout.Row = 3;
            obj.CompareClearButton.Layout.Column = 5;
            obj.CompareStatusLabel = uilabel(gridLayout, Text="Not loaded");
            obj.CompareStatusLabel.Layout.Row = 4;
            obj.CompareStatusLabel.Layout.Column = [2, 5];
        end

        function createSignalPanel(obj, parent)
            panel = uipanel(parent, Title="Signals");
            panel.Layout.Row = 2;
            gridLayout = uigridlayout(panel, [2, 3]);
            gridLayout.RowHeight = {"fit", "1x"};
            gridLayout.ColumnWidth = {48, "1x", 24};
            gridLayout.Padding = [6, 5, 6, 5];
            gridLayout.ColumnSpacing = 4;

            searchLabel = uilabel(gridLayout, Text="Search");
            searchLabel.Layout.Row = 1;
            searchLabel.Layout.Column = 1;
            obj.SignalSearchField = uieditfield(gridLayout, "text", ...
                Placeholder="Filter signal names", ...
                ValueChangingFcn=@(~, event) obj.runGuarded( ...
                @() obj.updateSignalTable(event.Value), ...
                "Filter signals"), ...
                ValueChangedFcn=@(~, event) obj.runGuarded( ...
                @() obj.updateSignalTable(event.Value), ...
                "Filter signals"));
            obj.SignalSearchField.Layout.Row = 1;
            obj.SignalSearchField.Layout.Column = 2;
            obj.SignalSearchClearButton = uibutton( ...
                gridLayout, "push", ...
                Text="×", ...
                Tooltip="Clear signal filter", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.clearSignalSearch(), "Clear signal filter"));
            obj.SignalSearchClearButton.Layout.Row = 1;
            obj.SignalSearchClearButton.Layout.Column = 3;

            obj.SignalTable = uitable(gridLayout, ...
                ColumnName={ ...
                "Export", "Name", "Status", "Base type", ...
                "Compare type", "Base shape", "Compare shape", "Details"}, ...
                ColumnWidth={50, 125, 85, 75, 90, 70, 85, 240}, ...
                ColumnEditable=[ ...
                true, false, false, false, false, false, false, false], ...
                RowName=[], ...
                Multiselect=matlab.lang.OnOffSwitchState.off, ...
                SelectionChangedFcn=@(~, event) obj.runGuarded( ...
                @() obj.onTableSelection(event), "Select signal"), ...
                CellEditCallback=@(~, event) obj.runGuarded( ...
                @() obj.onTableEdit(event), "Change export selection"));
            obj.SignalTable.Layout.Row = 2;
            obj.SignalTable.Layout.Column = [1, 3];
        end

        function createElementPanel(obj, parent)
            panel = uipanel(parent, Title="Selected element");
            panel.Layout.Row = 3;
            gridLayout = uigridlayout(panel, [2, 4]);
            gridLayout.RowHeight = {"fit", "fit"};
            gridLayout.ColumnWidth = {80, "1x", 68, "1x"};
            gridLayout.Padding = [6, 4, 6, 4];

            interpretationLabel = uilabel( ...
                gridLayout, Text="Interpret as");
            interpretationLabel.Layout.Row = 1;
            interpretationLabel.Layout.Column = 1;
            obj.SignalInterpretationDropdown = uidropdown(gridLayout, ...
                Items=["Sample-based", "Frame-based"], ...
                Value="Sample-based", ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.setSignalInterpretationCommand( ...
                string(obj.SignalInterpretationDropdown.Value)), ...
                "Change signal interpretation"));
            obj.SignalInterpretationDropdown.Layout.Row = 1;
            obj.SignalInterpretationDropdown.Layout.Column = 2;

            label = uilabel(gridLayout, Text="Subscripts");
            label.Layout.Row = 1;
            label.Layout.Column = 3;
            obj.ElementField = uieditfield(gridLayout, "text", ...
                Value="1", ...
                Tooltip="Comma-separated one-based subscripts, e.g. 2 or 2,3", ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.setElementCommand( ...
                string(obj.ElementField.Value)), ...
                "Change selected element"));
            obj.ElementField.Layout.Row = 1;
            obj.ElementField.Layout.Column = 4;
            obj.SelectionLabel = uilabel(gridLayout, ...
                Text="Select a matched signal.", ...
                WordWrap=matlab.lang.OnOffSwitchState.on);
            obj.SelectionLabel.Layout.Row = 2;
            obj.SelectionLabel.Layout.Column = [1, 4];
        end

        function createViewPanel(obj, parent)
            panel = uipanel(parent, Title="Time and view");
            panel.Layout.Row = 4;
            gridLayout = uigridlayout(panel, [5, 4]);
            gridLayout.RowHeight = {"fit", "fit", "fit", "fit", 42};
            gridLayout.ColumnWidth = {52, "1x", 52, "1x"};
            gridLayout.Padding = [6, 5, 6, 5];
            gridLayout.RowSpacing = 7;

            errorLabel = uilabel(gridLayout, Text="Error");
            errorLabel.Layout.Row = 1;
            errorLabel.Layout.Column = 1;
            obj.ErrorTypeDropdown = uidropdown(gridLayout, ...
                Items=["Relative", "Absolute"], ...
                Value="Relative", ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.setErrorTypeCommand( ...
                string(obj.ErrorTypeDropdown.Value)), ...
                "Change error type"));
            obj.ErrorTypeDropdown.Layout.Row = 1;
            obj.ErrorTypeDropdown.Layout.Column = [2, 4];

            unitLabel = uilabel(gridLayout, Text="Unit");
            unitLabel.Layout.Row = 2;
            unitLabel.Layout.Column = 1;
            obj.TimeUnitDropdown = uidropdown(gridLayout, ...
                Items=["s", "ms", "µs"], ...
                Value="s", ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.setTimeUnitCommand( ...
                string(obj.TimeUnitDropdown.Value)), ...
                "Change time unit"));
            obj.TimeUnitDropdown.Layout.Row = 2;
            obj.TimeUnitDropdown.Layout.Column = 2;
            obj.ResetViewButton = uibutton(gridLayout, "push", ...
                Text="Reset view", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.resetViewCommand(), "Reset plot view"));
            obj.ResetViewButton.Layout.Row = 2;
            obj.ResetViewButton.Layout.Column = [3, 4];

            xMinLabel = uilabel(gridLayout, Text="X-min");
            xMinLabel.Layout.Row = 3;
            xMinLabel.Layout.Column = 1;
            obj.XMinField = uispinner(gridLayout, ...
                Limits=[-Inf, Inf], ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onXLimitsChanged(), "Change plot limits"));
            obj.XMinField.Layout.Row = 3;
            obj.XMinField.Layout.Column = 2;
            xMaxLabel = uilabel(gridLayout, Text="X-max");
            xMaxLabel.Layout.Row = 3;
            xMaxLabel.Layout.Column = 3;
            obj.XMaxField = uispinner(gridLayout, ...
                Limits=[-Inf, Inf], ...
                Value=1, ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onXLimitsChanged(), "Change plot limits"));
            obj.XMaxField.Layout.Row = 3;
            obj.XMaxField.Layout.Column = 4;

            shiftLabel = uilabel(gridLayout, Text="Shift");
            shiftLabel.Layout.Row = 4;
            shiftLabel.Layout.Column = 1;
            obj.ShiftField = uispinner(gridLayout, ...
                Limits=[-Inf, Inf], ...
                ValueChangedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.setTimeShiftCommand( ...
                obj.ShiftField.Value), "Change time shift"));
            obj.ShiftField.Layout.Row = 4;
            obj.ShiftField.Layout.Column = 2;
            obj.ZeroShiftButton = uibutton(gridLayout, "push", ...
                Text="Zero shift", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.zeroShiftCommand(), "Reset time shift"));
            obj.ZeroShiftButton.Layout.Row = 4;
            obj.ZeroShiftButton.Layout.Column = [3, 4];

            obj.ShiftSlider = uislider(gridLayout, ...
                Limits=[-1, 1], ...
                Value=0, ...
                ValueChangingFcn=@(~, event) obj.runGuarded( ...
                @() obj.onShiftPreview(event.Value), ...
                "Preview time shift"), ...
                ValueChangedFcn=@(~, event) obj.runGuarded( ...
                @() obj.ViewModel.setTimeShiftCommand(event.Value), ...
                "Change time shift"));
            obj.ShiftSlider.Layout.Row = 5;
            obj.ShiftSlider.Layout.Column = [1, 4];
        end

        function createExportPanel(obj, parent)
            panel = uipanel(parent, Title="Export comparison plots");
            panel.Layout.Row = 5;
            gridLayout = uigridlayout(panel, [2, 4]);
            gridLayout.RowHeight = {"fit", "fit"};
            gridLayout.ColumnWidth = {"1x", "1x", "1x", "1x"};
            gridLayout.Padding = [6, 4, 6, 4];
            gridLayout.RowSpacing = 5;

            obj.SelectAllExportButton = uibutton(gridLayout, "push", ...
                Text="All", ...
                Tooltip="Select all matched signals for export", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.selectAllForExportCommand(), ...
                "Select all exports"));
            obj.SelectAllExportButton.Layout.Row = 1;
            obj.SelectAllExportButton.Layout.Column = 1;

            obj.ClearExportButton = uibutton(gridLayout, "push", ...
                Text="None", ...
                Tooltip="Clear the export selection", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.clearExportSelectionCommand(), ...
                "Clear export selection"));
            obj.ClearExportButton.Layout.Row = 1;
            obj.ClearExportButton.Layout.Column = 2;

            formatLabel = uilabel(gridLayout, Text="Format");
            formatLabel.Layout.Row = 1;
            formatLabel.Layout.Column = 3;
            obj.ExportFormatDropdown = uidropdown(gridLayout, ...
                Items=["PNG", "JPEG", "TIFF", "PDF", "SVG"], ...
                ItemsData=["png", "jpg", "tif", "pdf", "svg"], ...
                Value="png");
            obj.ExportFormatDropdown.Layout.Row = 1;
            obj.ExportFormatDropdown.Layout.Column = 4;

            obj.ExportButton = uibutton(gridLayout, "push", ...
                Text="Export selected to folder...", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onExport(), "Export selected plots"));
            obj.ExportButton.Layout.Row = 2;
            obj.ExportButton.Layout.Column = [1, 2];

            obj.QuickExportButton = uibutton(gridLayout, "push", ...
                Text="Quick export current", ...
                Tooltip="Export the current signal to the current " + ...
                "working directory", ...
                ButtonPushedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.onQuickExport(), "Quick export current plot"));
            obj.QuickExportButton.Layout.Row = 2;
            obj.QuickExportButton.Layout.Column = [3, 4];
        end

        function contextMenu = createPlotContextMenu( ...
                obj, axesHandle, allowTimeShift)
            contextMenu = uicontextmenu(obj.Figure, ...
                ContextMenuOpeningFcn=@(menu, ~) obj.runGuarded( ...
                @() obj.capturePlotContext(menu, axesHandle), ...
                "Open plot context menu"));
            contextMenu.UserData = struct( ...
                "Axes", axesHandle, ...
                "X", NaN, ...
                "Y", NaN);
            uimenu(contextMenu, ...
                Text="Set X-min here", ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.applyPlotContextAction(contextMenu, "x-min"), ...
                "Set minimum plot time"));
            uimenu(contextMenu, ...
                Text="Set X-max here", ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.applyPlotContextAction(contextMenu, "x-max"), ...
                "Set maximum plot time"));
            if allowTimeShift
                uimenu(contextMenu, ...
                    Text="Set time shift here", ...
                    MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                    @() obj.applyPlotContextAction( ...
                    contextMenu, "shift"), "Align time shift"));
            end
            uimenu(contextMenu, ...
                Text="Zero time shift", ...
                Separator=matlab.lang.OnOffSwitchState.on, ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.zeroShiftCommand(), "Reset time shift"));
            uimenu(contextMenu, ...
                Text="Reset view", ...
                MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                @() obj.ViewModel.resetViewCommand(), "Reset plot view"));
            if allowTimeShift
                uimenu(contextMenu, ...
                    Text="Edit legend labels...", ...
                    Separator=matlab.lang.OnOffSwitchState.on, ...
                    MenuSelectedFcn=@(~, ~) obj.runGuarded( ...
                    @() obj.onEditLegendText(), "Edit legend labels"));
            end
        end

        function bindToViewModel(obj)
            vm = obj.ViewModel;
            obj.addBinding("BaselineFileDisplay", ...
                @() obj.updateFileControls());
            obj.addBinding("CompareFileDisplay", ...
                @() obj.updateFileControls());
            obj.addBinding("BaselineStatus", ...
                @() obj.updateFileControls());
            obj.addBinding("CompareStatus", ...
                @() obj.updateFileControls());
            obj.addBinding("SignalTable", ...
                @() obj.updateSignalTable());
            obj.addBinding("SignalInterpretation", ...
                @() set(obj.SignalInterpretationDropdown, "Value", ...
                char(vm.SignalInterpretation)));
            obj.addBinding("ElementText", ...
                @() set(obj.ElementField, "Value", char(vm.ElementText)));
            obj.addBinding("SelectionSummary", ...
                @() set(obj.SelectionLabel, "Text", ...
                char(vm.SelectionSummary)));
            obj.addBinding("ErrorType", ...
                @() set(obj.ErrorTypeDropdown, "Value", ...
                char(vm.ErrorType)));
            obj.addBinding("StatusMessage", ...
                @() set(obj.StatusLabel, "Text", ...
                char(vm.StatusMessage)));
            obj.addBinding("TimeUnit", ...
                @() obj.updateTimeUnit());
            obj.addBinding("XMin", ...
                @() obj.updateXControls());
            obj.addBinding("XMax", ...
                @() obj.updateXControls());
            obj.addBinding("ShiftValue", ...
                @() obj.updateShiftControls());
            obj.addBinding("ShiftLimits", ...
                @() obj.updateShiftControls());
            obj.addBinding("PlotData", ...
                @() obj.updatePlot());
            obj.addBinding("CanCompare", ...
                @() obj.updateEnabledState());
            obj.addBinding("IsSelectedSignalScalar", ...
                @() obj.updateEnabledState());
            obj.addBinding("CanExport", ...
                @() obj.updateEnabledState());
            obj.addBinding("IsExporting", ...
                @() obj.updateEnabledState());
            obj.addAxesLimitsBinding(obj.SourceAxes);
            obj.addAxesLimitsBinding(obj.ErrorAxes);
        end

        function addBinding(obj, propertyName, callback)
            obj.Listeners{end + 1} = addlistener( ...
                obj.ViewModel, propertyName, "PostSet", ...
                @(~, ~) obj.runGuarded( ...
                callback, "Update " + propertyName + " display"));
        end

        function addAxesLimitsBinding(obj, axesHandle)
            obj.Listeners{end + 1} = addlistener( ...
                axesHandle, "XLim", "PostSet", ...
                @(~, ~) obj.runGuarded( ...
                @() obj.onAxesXLimitsChanged(axesHandle), ...
                "Synchronize plot limits"));
            % Restore View reapplies the limit mode without setting XLim.
            obj.Listeners{end + 1} = addlistener( ...
                axesHandle, "XLimMode", "PostSet", ...
                @(~, ~) obj.runGuarded( ...
                @() obj.scheduleAxesRestore(axesHandle), ...
                "Synchronize restored plot limits"));
        end

        function scheduleAxesRestore(obj, axesHandle)
            if obj.IsApplyingAxesLimits || obj.IsDeleting
                return
            end
            % Read restored limits after the graphics operation completes.
            stop(obj.AxesRestoreTimer);
            obj.AxesRestoreTimer.UserData = axesHandle;
            start(obj.AxesRestoreTimer);
        end

        function syncFromViewModel(obj)
            obj.updateFileControls();
            obj.updateSignalTable();
            obj.SignalInterpretationDropdown.Value = char( ...
                obj.ViewModel.SignalInterpretation);
            obj.ElementField.Value = char(obj.ViewModel.ElementText);
            obj.SelectionLabel.Text = char( ...
                obj.ViewModel.SelectionSummary);
            obj.ErrorTypeDropdown.Value = char(obj.ViewModel.ErrorType);
            obj.StatusLabel.Text = char(obj.ViewModel.StatusMessage);
            obj.updateTimeUnit();
            obj.updateXControls();
            obj.updateShiftControls();
            obj.updatePlot();
            obj.updateEnabledState();
        end

        function updateFileControls(obj)
            obj.BaselineFileField.Value = char( ...
                obj.ViewModel.BaselineFileDisplay);
            obj.BaselineFileField.Tooltip = char( ...
                obj.ViewModel.BaselineFileDisplay);
            obj.CompareFileField.Value = char( ...
                obj.ViewModel.CompareFileDisplay);
            obj.CompareFileField.Tooltip = char( ...
                obj.ViewModel.CompareFileDisplay);
            obj.BaselineStatusLabel.Text = char( ...
                obj.ViewModel.BaselineStatus);
            obj.CompareStatusLabel.Text = char( ...
                obj.ViewModel.CompareStatus);
            obj.BaselineClearButton.Enable = ...
                matlab.lang.OnOffSwitchState( ...
                strlength(obj.ViewModel.BaselineFileDisplay) > 0);
            obj.CompareClearButton.Enable = ...
                matlab.lang.OnOffSwitchState( ...
                strlength(obj.ViewModel.CompareFileDisplay) > 0);
            obj.syncMenuEnabledState();
        end

        function updateSignalTable(obj, query)
            if nargin < 2
                query = obj.SignalSearchField.Value;
            end
            tableData = obj.ViewModel.SignalTable;
            matches = fuzzyNameMatches(tableData.Name, string(query));
            visibleRows = find(matches);
            if ~isequal(obj.VisibleSignalRows, visibleRows)
                % Filtered cells can now refer to different source signals.
                obj.SignalTable.Selection = [];
            end
            obj.VisibleSignalRows = visibleRows;
            obj.SignalTable.Data = tableData(matches, :);
        end

        function clearSignalSearch(obj)
            obj.SignalSearchField.Value = "";
            obj.updateSignalTable("");
        end

        function updateTimeUnit(obj)
            obj.TimeUnitDropdown.Value = char(obj.ViewModel.TimeUnit);
            obj.SourceAxes.XLabel.String = ...
                "Time (" + obj.ViewModel.TimeUnit + ")";
            obj.ErrorAxes.XLabel.String = ...
                "Time (" + obj.ViewModel.TimeUnit + ")";
        end

        function updateXControls(obj)
            obj.XMinField.Value = obj.ViewModel.XMin;
            obj.XMaxField.Value = obj.ViewModel.XMax;
            limits = [obj.ViewModel.XMin, obj.ViewModel.XMax];
            if all(isfinite(limits)) && limits(1) < limits(2)
                step = spinnerStepForSpan(limits);
                obj.XMinField.Step = step;
                obj.XMaxField.Step = step;
                obj.ShiftField.Step = step;
                if ~obj.IsApplyingAxesLimits
                    obj.IsApplyingAxesLimits = true;
                    cleanup = onCleanup( ...
                        @() obj.finishApplyingAxesLimits());
                    xlim(obj.SourceAxes, limits);
                    xlim(obj.ErrorAxes, limits);
                end
            end
        end

        function updateShiftControls(obj)
            limits = obj.ViewModel.ShiftLimits;
            value = obj.ViewModel.ShiftValue;
            if limits(1) >= limits(2)
                limits = [-1, 1];
            end
            value = min(max(value, limits(1)), limits(2));
            obj.ShiftSlider.Limits = limits;
            obj.ShiftSlider.Value = value;
            obj.ShiftField.Limits = limits;
            obj.ShiftField.Value = value;
        end

        function updatePlot(obj)
            data = obj.ViewModel.PlotData;
            set(obj.BaselineLine, ...
                XData=data.BaselineTime, YData=data.BaselineData);
            set(obj.CompareLine, ...
                XData=data.CompareTime, YData=data.CompareData);
            set(obj.ErrorLine, ...
                XData=data.ErrorTime, ...
                YData=data.ErrorData, ...
                DisplayName=data.ErrorType + " error");
            obj.SourceLegend.Visible = matlab.lang.OnOffSwitchState( ...
                ~isempty(data.BaselineTime) && ~isempty(data.CompareTime));
            obj.SourceAxes.Title.String = sourceTitle(data);
            obj.SourceAxes.Title.Interpreter = "none";
            obj.SourceAxes.YLabel.String = sourceYAxisLabel(data);
            obj.ErrorAxes.Title.String = errorTitle(data);
            obj.ErrorAxes.YLabel.String = errorYAxisLabel(data);
            ylim(obj.SourceAxes, "auto");
            ylim(obj.ErrorAxes, "auto");
            obj.updateXControls();
            % Keep queued UI events from re-entering this graphics update.
            drawnow limitrate nocallbacks
        end

        function updateEnabledState(obj)
            compareEnabled = matlab.lang.OnOffSwitchState( ...
                obj.ViewModel.CanCompare);
            obj.SignalInterpretationDropdown.Enable = compareEnabled;
            obj.ElementField.Enable = compareEnabled;
            obj.ElementField.Editable = matlab.lang.OnOffSwitchState( ...
                obj.ViewModel.CanCompare && ...
                ~obj.ViewModel.IsSelectedSignalScalar);
            obj.ResetViewButton.Enable = compareEnabled;
            obj.ShiftSlider.Enable = compareEnabled;
            obj.ShiftField.Enable = compareEnabled;
            obj.ZeroShiftButton.Enable = compareEnabled;

            hasSignals = height(obj.ViewModel.SignalTable) > 0;
            selectionEnabled = hasSignals && ~obj.ViewModel.IsExporting;
            obj.SelectAllExportButton.Enable = ...
                matlab.lang.OnOffSwitchState(selectionEnabled);
            obj.ClearExportButton.Enable = ...
                matlab.lang.OnOffSwitchState(selectionEnabled);
            obj.ExportFormatDropdown.Enable = ...
                matlab.lang.OnOffSwitchState(~obj.ViewModel.IsExporting);
            obj.ExportButton.Enable = matlab.lang.OnOffSwitchState( ...
                obj.ViewModel.CanExport && ~obj.ViewModel.IsExporting);
            obj.QuickExportButton.Enable = matlab.lang.OnOffSwitchState( ...
                obj.ViewModel.CanCompare && ~obj.ViewModel.IsExporting);
            obj.syncMenuEnabledState();
        end

        function showFixedPointWarning(obj)
            if obj.FixedPointWarningShown || ...
                    obj.ViewModel.FixedPointAvailable
                return
            end
            obj.FixedPointWarningShown = true;
            obj.WarningPresenter( ...
                obj.Figure, obj.ViewModel.FixedPointWarningMessage);
        end

        function checkForAvailableUpdate(obj)
            if obj.UpdateCheckStarted || ~obj.CheckForUpdates || ...
                    simcompare.Models.ReleaseChecker.isDevelopmentVersion( ...
                    obj.CurrentVersion)
                return
            end
            obj.UpdateCheckStarted = true;
            try
                obj.UpdateCheckFuture = parfeval( ...
                    backgroundPool, obj.UpdateChecker, 1);
                obj.UpdateCheckCompletionFuture = afterAll(obj.UpdateCheckFuture, ...
                    @obj.finishUpdateCheck, 0, PassFuture=true);
            catch
                if ~isempty(obj.UpdateCheckFuture)
                    cancel(obj.UpdateCheckFuture);
                end
                obj.UpdateCheckFuture = [];
                obj.UpdateCheckCompletionFuture = [];
            end
        end

        function onUpdateCheckComplete( ...
                obj, result, error)
            if obj.IsDeleting
                return
            end
            if ~isempty(error)
                return
            end
            if isempty(result)
                return
            end
            try
                result = simcompare.Models.ReleaseChecker.compareRelease( ...
                    obj.CurrentVersion, result);
            catch
                return
            end
            if ~result.IsUpdateAvailable
                return
            end
            selection = string(obj.UpdatePresenter(obj.Figure, result));
            if isvalid(obj) && ~obj.IsDeleting && selection == "Download"
                obj.UrlOpener(result.ReleaseURL);
            end
        end

        function finishUpdateCheck(obj, future)
            if ~isvalid(obj) || obj.IsDeleting
                return
            end
            obj.UpdateCheckFuture = [];
            obj.UpdateCheckCompletionFuture = [];
            try
                if ~isempty(future.Error)
                    obj.onUpdateCheckComplete([], future.Error);
                else
                    obj.onUpdateCheckComplete(fetchOutputs(future), []);
                end
            catch exception
                obj.reportError(exception, "Complete update check");
            end
        end

        function onBrowse(obj, role)
            [fileName, folder] = obj.FileSelector( ...
                { ...
                "*.mat;*.mldatx", ...
                "Simulation data (*.mat, *.mldatx)"; ...
                "*.mat", "MAT-files (*.mat)"; ...
                "*.mldatx", "SDI session files (*.mldatx)"}, ...
                "Select " + role + " simulation data");
            if isequal(fileName, 0)
                return
            end
            filePath = string(fullfile(folder, fileName));
            [~, ~, extension] = fileparts(filePath);
            if strcmpi(extension, ".mldatx")
                progress = obj.createLoadProgress(role, "SDI session");
                progressCleanup = onCleanup( ...
                    @() deleteValidProgress(progress));
                runs = obj.SdiSessionImporter(filePath);
                deleteValidProgress(progress);
                obj.finishSdiSessionImport( ...
                    role, runs, ...
                    "Select a run imported from the SDI session");
            else
                progress = obj.createLoadProgress(role, "MAT-file");
                progressCleanup = onCleanup( ...
                    @() deleteValidProgress(progress));
                obj.loadFile(role, filePath);
            end
        end

        function onChooseSdi(obj, role)
            runs = obj.ViewModel.inspectSdiRunsCommand();
            obj.chooseSdiRun(role, runs, "Select a current SDI run");
        end

        function chooseSdiRun(obj, role, runs, prompt)
            if isempty(runs)
                return
            end
            runID = obj.SdiRunSelector(runs, prompt);
            obj.restoreFigureFocus();
            if ~isfinite(runID)
                return
            end
            progress = obj.createLoadProgress(role, "SDI run");
            progressCleanup = onCleanup( ...
                @() deleteValidProgress(progress));
            obj.loadRun(role, runID);
        end

        function finishSdiSessionImport(obj, role, runs, prompt)
            if isempty(runs)
                return
            end
            obj.chooseSdiRun(role, runs, prompt);
            message = "The SDI session is now imported. To select " + ...
                "another run from it, click the SDI... button next to " + ...
                "the baseline or comparison source. You do not need to " + ...
                "browse to and import the session again.";
            obj.SdiSessionImportPresenter(obj.Figure, message);
        end

        function progress = createLoadProgress(obj, role, source)
            progress = uiprogressdlg(obj.Figure, ...
                Title="Loading Simulation Data", ...
                Message="Loading " + role + " " + source + "...", ...
                Indeterminate=matlab.lang.OnOffSwitchState.on);
            drawnow;
        end

        function onTableSelection(obj, event)
            if isempty(event.Selection)
                return
            end
            visibleRow = event.Selection(1, 1);
            if visibleRow > numel(obj.VisibleSignalRows)
                return
            end
            signalRow = obj.VisibleSignalRows(visibleRow);
            progress = obj.createSignalDisplayProgress( ...
                obj.ViewModel.SignalTable.Name(signalRow));
            progressCleanup = onCleanup( ...
                @() deleteValidProgress(progress));
            obj.ViewModel.selectRowCommand( ...
                signalRow);
        end

        function onTableEdit(obj, event)
            if isempty(event.Indices) || event.Indices(1, 2) ~= 1
                return
            end
            visibleRow = event.Indices(1, 1);
            if visibleRow > numel(obj.VisibleSignalRows)
                return
            end
            obj.ViewModel.setExportSelectionCommand( ...
                obj.VisibleSignalRows(visibleRow), logical(event.NewData));
        end

        function onXLimitsChanged(obj)
            obj.ViewModel.setXLimitsCommand( ...
                obj.XMinField.Value, obj.XMaxField.Value);
        end

        function onAxesXLimitsChanged(obj, axesHandle)
            if obj.IsApplyingAxesLimits || obj.IsDeleting || ...
                    ~isvalid(axesHandle)
                return
            end
            limits = axesHandle.XLim;
            currentLimits = [obj.ViewModel.XMin, obj.ViewModel.XMax];
            if ~all(isfinite(limits)) || limits(1) >= limits(2) || ...
                    isequal(limits, currentLimits)
                return
            end

            obj.IsApplyingAxesLimits = true;
            cleanup = onCleanup(@() obj.finishApplyingAxesLimits());
            obj.ViewModel.setXLimitsCommand(limits(1), limits(2));
        end

        function finishApplyingAxesLimits(obj)
            obj.IsApplyingAxesLimits = false;
        end

        function onShiftPreview(obj, value)
            if isempty(obj.LastPreviewTick) || ...
                    toc(obj.LastPreviewTick) >= 0.05
                obj.LastPreviewTick = tic;
                obj.ViewModel.setTimeShiftCommand(value);
                drawnow limitrate
            end
        end

        function capturePlotContext(~, contextMenu, axesHandle)
            point = axesHandle.CurrentPoint;
            xLimits = axesHandle.XLim;
            yLimits = axesHandle.YLim;
            context = contextMenu.UserData;
            context.X = min(max(point(1, 1), xLimits(1)), xLimits(2));
            context.Y = min(max(point(1, 2), yLimits(1)), yLimits(2));
            contextMenu.UserData = context;
        end

        function applyPlotContextAction(obj, contextMenu, action)
            context = contextMenu.UserData;
            x = context.X;
            if ~isfinite(x)
                return
            end
            limits = context.Axes.XLim;
            switch action
                case "x-min"
                    obj.ViewModel.setXLimitsCommand(x, limits(2));
                case "x-max"
                    obj.ViewModel.setXLimitsCommand(limits(1), x);
                case "shift"
                    if isfinite(context.Y)
                        obj.ViewModel.alignComparisonAtPointCommand( ...
                            x, context.Y);
                    end
            end
        end

        function onExport(obj)
            startFolder = pwd;
            baselineFile = obj.ViewModel.BaselineFileDisplay;
            if isfile(baselineFile)
                startFolder = fileparts(baselineFile);
            end
            folder = obj.FolderSelector(startFolder, ...
                "Select a folder for comparison plots");
            obj.restoreFigureFocus();
            if isequal(folder, 0)
                return
            end

            progress = obj.createExportProgress();
            progressCleanup = onCleanup( ...
                @() deleteValidProgress(progress));
            try
                obj.ViewModel.exportSelectedPlots( ...
                    string(folder), ...
                    string(obj.ExportFormatDropdown.Value), ...
                    BaselineLegendText=obj.LegendText(1), ...
                    CompareLegendText=obj.LegendText(2), ...
                    ProgressFcn=@(index, count, filePath) ...
                    obj.updateExportProgress( ...
                    progress, index, count, filePath));
            catch exception
                obj.reportError(exception, "Export selected plots");
            end
        end

        function restoreFigureFocus(obj)
            if obj.IsDeleting || isempty(obj.Figure) || ...
                    ~isvalid(obj.Figure)
                return
            end
            obj.FigureActivator(obj.Figure);
            drawnow;
        end

        function onQuickExport(obj)
            progress = obj.createExportProgress();
            progressCleanup = onCleanup( ...
                @() deleteValidProgress(progress));
            try
                obj.ViewModel.exportCurrentPlot( ...
                    string(pwd), ...
                    string(obj.ExportFormatDropdown.Value), ...
                    BaselineLegendText=obj.LegendText(1), ...
                    CompareLegendText=obj.LegendText(2), ...
                    ProgressFcn=@(index, count, filePath) ...
                    obj.updateExportProgress( ...
                    progress, index, count, filePath));
            catch exception
                obj.reportError(exception, "Quick export current plot");
            end
        end

        function onEditLegendText(obj)
            [legendText, accepted] = obj.LegendTextPresenter( ...
                obj.Figure, obj.LegendText);
            if ~accepted
                return
            end
            legendText = strtrim(string(legendText));
            if numel(legendText) ~= 2 || any(strlength(legendText) == 0)
                error("simcompare:View:InvalidLegendText", ...
                    "Specify non-empty baseline and comparison legend text.");
            end
            obj.applyLegendText(reshape(legendText, 1, 2));
        end

        function applyLegendText(obj, legendText)
            obj.LegendText = legendText;
            obj.BaselineLine.DisplayName = legendText(1);
            obj.CompareLine.DisplayName = legendText(2);
            obj.SourceLegend.String = cellstr(legendText);
        end

        function progress = createExportProgress(obj)
            progress = uiprogressdlg(obj.Figure, ...
                Title="Exporting Comparison Plots", ...
                Message="Preparing plots...", ...
                Value=0);
            drawnow;
        end

        function progress = createSignalDisplayProgress(obj, signalName)
            progress = uiprogressdlg(obj.Figure, ...
                Title="Displaying Signal", ...
                Message="Displaying " + string(signalName) + "...", ...
                Indeterminate=matlab.lang.OnOffSwitchState.on);
            drawnow;
        end

        function updateExportProgress( ...
                ~, progress, index, count, filePath)
            if ~isvalid(progress)
                return
            end
            [~, name, extension] = fileparts(filePath);
            progress.Value = index / count;
            progress.Message = sprintf( ...
                "Exported %s%s (%d of %d)", ...
                name, extension, index, count);
            drawnow limitrate
        end
    end
end

function text = sourceTitle(data)
if strlength(data.Name) == 0
    text = "Source signals";
else
    text = data.Name;
end
end

function text = sourceYAxisLabel(data)
baselineUnit = strtrim(data.BaselineUnit);
compareUnit = strtrim(data.CompareUnit);
if strlength(baselineUnit) == 0 && strlength(compareUnit) == 0
    text = "Value";
elseif strlength(baselineUnit) == 0
    text = "Value (" + compareUnit + ")";
elseif strlength(compareUnit) == 0 || baselineUnit == compareUnit
    text = "Value (" + baselineUnit + ")";
else
    text = "Value (baseline: " + baselineUnit + ...
        "; comparison: " + compareUnit + ")";
end
end

function text = errorTitle(data)
if strlength(data.Interpolation) == 0
    text = data.ErrorType + " error";
else
    text = data.ErrorType + " error (" + data.Interpolation + ...
        " interpolation)";
end
end

function text = errorYAxisLabel(data)
if data.ErrorType == "Relative"
    text = "Error (%)";
elseif strlength(strtrim(data.ErrorUnit)) == 0
    text = "Error";
else
    text = "Error (" + data.ErrorUnit + ")";
end
end

function [legendText, accepted] = presentLegendTextEditor( ...
        parentFigure, initialText)
dialogSize = [420, 180];
parentPosition = parentFigure.Position;
dialogPosition = [ ...
    parentPosition(1) + (parentPosition(3) - dialogSize(1)) / 2, ...
    parentPosition(2) + (parentPosition(4) - dialogSize(2)) / 2, ...
    dialogSize];
dialog = uifigure( ...
    Name="Legend Labels", ...
    Position=dialogPosition, ...
    Resize=matlab.lang.OnOffSwitchState.off, ...
    WindowStyle="modal", ...
    Visible=matlab.lang.OnOffSwitchState.off);
dialog.UserData = struct( ...
    "LegendText", initialText, ...
    "Accepted", false);
dialog.CloseRequestFcn = @(~, ~) cancel();

gridLayout = uigridlayout(dialog, [4, 2]);
gridLayout.RowHeight = {"fit", "fit", "fit", "fit"};
gridLayout.ColumnWidth = {100, "1x"};
gridLayout.Padding = [12, 12, 12, 12];

instructions = uilabel(gridLayout, ...
    Text="Set the labels shown in the app and included in exports.");
instructions.Layout.Row = 1;
instructions.Layout.Column = [1, 2];

baselineLabel = uilabel(gridLayout, Text="Baseline");
baselineLabel.Layout.Row = 2;
baselineLabel.Layout.Column = 1;
baselineField = uieditfield(gridLayout, "text", ...
    Value=char(initialText(1)));
baselineField.Layout.Row = 2;
baselineField.Layout.Column = 2;

compareLabel = uilabel(gridLayout, Text="Comparison");
compareLabel.Layout.Row = 3;
compareLabel.Layout.Column = 1;
compareField = uieditfield(gridLayout, "text", ...
    Value=char(initialText(2)));
compareField.Layout.Row = 3;
compareField.Layout.Column = 2;

buttonGrid = uigridlayout(gridLayout, [1, 3]);
buttonGrid.Layout.Row = 4;
buttonGrid.Layout.Column = [1, 2];
buttonGrid.ColumnWidth = {"1x", 80, 80};
buttonGrid.Padding = [0, 0, 0, 0];
cancelButton = uibutton(buttonGrid, "push", ...
    Text="Cancel", ...
    ButtonPushedFcn=@(~, ~) cancel());
cancelButton.Layout.Column = 2;
applyButton = uibutton(buttonGrid, "push", ...
    Text="Apply", ...
    ButtonPushedFcn=@(~, ~) applyChanges());
applyButton.Layout.Column = 3;

dialog.Visible = matlab.lang.OnOffSwitchState.on;
uiwait(dialog);
if isvalid(dialog)
    result = dialog.UserData;
    legendText = result.LegendText;
    accepted = result.Accepted;
    delete(dialog);
else
    legendText = initialText;
    accepted = false;
end

    function applyChanges()
        candidate = strtrim(string( ...
            [baselineField.Value, compareField.Value]));
        if any(strlength(candidate) == 0)
            uialert( ...
                dialog, ...
                "Enter text for both legend labels.", ...
                "Legend Labels Required");
            return
        end
        dialog.UserData = struct( ...
            "LegendText", candidate, ...
            "Accepted", true);
        uiresume(dialog);
    end

    function cancel()
        dialog.UserData = struct( ...
            "LegendText", initialText, ...
            "Accepted", false);
        uiresume(dialog);
    end
end

function runID = presentSdiRunSelector(runs, prompt)
[selection, accepted] = listdlg( ...
    ListString=cellstr(string({runs.DisplayName})), ...
    ListSize=[440, 300], ...
    SelectionMode="single", ...
    PromptString=prompt, ...
    Name="Simulation Data Inspector Runs");
if accepted
    runID = runs(selection).RunID;
else
    runID = NaN;
end
end

function presentSdiSessionImportInfo(figureHandle, message)
uialert( ...
    figureHandle, ...
    message, ...
    "SDI Session Imported", ...
    Icon="info", ...
    Modal=false);
end

function presentFixedPointWarning(figureHandle, message)
uialert( ...
    figureHandle, ...
    message, ...
    "Fixed-Point Signals Unavailable", ...
    Icon="warning", ...
    Modal=false);
end

function selection = presentAvailableUpdate(figureHandle, result)
message = sprintf( ...
    "Simulation Comparison App %s is available. You are using %s.", ...
    string(result.LatestVersion), string(result.CurrentVersion));
selection = uiconfirm( ...
    figureHandle, ...
    message, ...
    "Update Available", ...
    Options=["Download", "Later"], ...
    DefaultOption=1, ...
    CancelOption=2, ...
    Icon="info");
end

function openReleasePage(releaseURL)
web(releaseURL, "-browser");
end

function deleteValidProgress(progress)
if isvalid(progress)
    delete(progress);
end
end

function updateSidebarLayout(gridLayout, figureHandle)
% Keep signal rows accessible when the window is reduced to fit the screen.
if figureHandle.Position(4) < 810
    gridLayout.RowHeight{2} = 180;
else
    gridLayout.RowHeight{2} = "1x";
end
end

function matches = fuzzyNameMatches(names, query)
names = string(names);
query = lower(regexprep(strtrim(query), "\s+", ""));
matches = false(size(names));
if strlength(query) == 0
    matches(:) = true;
    return
end

queryCharacters = char(query);
for nameIndex = 1:numel(names)
    candidate = char(lower(regexprep(names(nameIndex), "\s+", "")));
    queryIndex = 1;
    for candidateIndex = 1:numel(candidate)
        if candidate(candidateIndex) == queryCharacters(queryIndex)
            queryIndex = queryIndex + 1;
            if queryIndex > numel(queryCharacters)
                matches(nameIndex) = true;
                break
            end
        end
    end
end
end

function step = spinnerStepForSpan(limits)
span = limits(2) - limits(1);
step = 10 ^ (floor(log10(span)) - 1);
if ~isfinite(step) || step <= 0
    step = 1;
end
end
