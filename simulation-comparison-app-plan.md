# Simulation Comparison App

## Architecture

- Programmatic MATLAB `uifigure` app targeting R2025b.
- Explorer layout with a fixed control sidebar and a resizable plotting area.
- MVVM package structure under `toolbox/+simcompare`:
  - `+Models/ComparisonModel.m` owns MAT-file loading, signal matching,
    element extraction, interpolation, and error calculations.
  - `+ViewModels/MainViewModel.m` owns observable presentation state and
    commands.
  - `+Views/MainView.m` creates the UI and binds it to the ViewModel.
- `toolbox/runSimulationComparisonApp.m` is the public entry point and
  returns the model, ViewModel, and view handles.

## Layout

- Fixed-width left sidebar:
  - baseline and comparison file selectors with load state;
  - unified signal table with a name filter and compact clear button;
  - element-subscript editor and selected signal shapes;
  - time unit, X limits, reset, shift slider, exact shift, and zero controls;
  - status line.
- Resizable right area:
  - source comparison axes;
  - selectable relative- or absolute-error axes in a 3:1 vertical split;
  - linked X axes.

## Behavior

- Discover `Simulink.SimulationData.Dataset` variables in each MAT-file.
  Select a sole dataset automatically and prompt for one when several exist.
- Let either comparison side load any current Simulation Data Inspector run.
  Refresh the available runs when the user opens the chooser, identify each
  run by name, numeric run ID, and signal count, and export the selected run
  in memory as a `Simulink.SimulationData.Dataset` without changing the SDI
  repository.
- Provide a compact clear button beside each selected data source. Clearing
  one source keeps the other source loaded and refreshes the signal table and
  plots; clearing both removes all dataset-dependent presentation state.
- Accept baseline and comparison SDI run IDs as startup options while
  rejecting a file and run ID supplied for the same role.
- Match exact, case-sensitive signal names. Do not guess pairings when either
  side has duplicate candidates.
- Let users clear the signal-name filter with a compact button beside the
  search field and immediately restore all signal rows.
- Accept real numeric, logical, and fixed-point `timeseries` data. Normalize
  time-first and time-last storage and select MATLAB-style one-based element
  subscripts.
- Detect Fixed-Point Designer license availability when the app starts. If it
  is unavailable, show a warning once, keep fixed-point signals visible with
  an unavailable note, prevent their selection, and continue comparing
  standard MATLAB numeric and logical signals.
- Draw baseline samples at native times and comparison samples at
  `comparisonTime + shift`.
- Let users choose relative or absolute error, defaulting to relative, and
  preserve that selection while signals, elements, datasets, or SDI runs
  change.
- Calculate error on baseline timestamps in the shifted overlap. Relative
  error is the signed percentage difference and treats near-zero baseline
  samples as unavailable. Absolute error is the magnitude of the difference
  in the baseline signal's unit.
  Floating-point pairs use linear interpolation; integer, logical, or
  fixed-point pairs use previous-value interpolation. Unavailable
  interpolation produces `NaN`.
- Keep time units, X limits, and shift while changing signals or elements.
- When either dataset or SDI run changes, keep the displayed signal,
  interpretation, element, time unit, shift, and X limits if that exact signal
  remains uniquely matched and the selected element remains valid. Rebind the
  selection by signal name so reordered dataset elements do not change the
  displayed signal.
- If the displayed signal is missing, no longer comparable, or no longer
  supports the selected element, use the fresh-pair behavior: select the first
  comparable signal and reset shift and X limits.
- Let users mark any uniquely matched, supported signals for export directly
  in the signal table, with select-all and clear actions.
- Export one complete two-panel comparison plot per selected signal into one
  destination folder. Support PNG, JPEG, TIFF, PDF, and SVG output, preserve
  the app's time unit, shift, and X view, and use the active element for the
  currently displayed multidimensional signal. Match the app's 3:1 source-to-
  error plot height ratio, show grids on both axes, identify source lines by
  their selected Dataset variable names, and place the legend outside the
  signal data area. Use the error type currently selected in the app.
- Provide a signal-plot context-menu action for editing legend labels. Prefill
  its editor from the current legend text, apply accepted non-empty entries
  to the app legend immediately, retain them for the app session, and leave
  the current labels unchanged when the editor is dismissed. Always identify
  lines in app exports as `datasetName | legendLabel`, including with the
  default Baseline and Comparison labels.
- Provide a quick-export action in the export panel that writes the currently
  selected signal directly to the current working directory in the selected
  format, without opening a folder chooser. Enable it only while a comparable
  signal is selected and no export is already running.
- Show a progress dialog for both export actions. Update batch-export progress
  after each file using the completed-file fraction and report quick export as
  one completed file out of one.
- Restore focus to the comparison app immediately after the native export-folder
  chooser closes so that the app returns to the foreground on Windows, including
  when the chooser is canceled.
- Restore focus after the native SDI run chooser closes, including when run
  selection is canceled.
- Provide `exportSimulationComparisonPlots` as a non-UI API for exporting
  exact signal names from two MAT-files. The API creates a missing output
  folder, uses each signal's default element, accepts optional baseline and
  comparison legend labels defaulting to Baseline and Comparison, formats
  entries as `datasetName | legendLabel`, accepts relative or absolute error
  with relative as the default, and returns the generated paths.
- Catch errors at app callback and public CLI boundaries and ask the user
  whether to report them. When accepted, open a prefilled GitHub issue in the
  user's browser so their authenticated GitHub identity remains the reporter.
  Keep the project URL and default assignee in one reusable issue-reporting
  component, and never read the packaged API credential for this workflow.
- Update existing line objects in place and throttle slider previews.
- Clean up View and ViewModel listeners when their owners are deleted.

## Files

```text
toolbox/
  runSimulationComparisonApp.m
  exportSimulationComparisonPlots.m
  +simcompare/
    IssueReporter.m
    +Exporters/ComparisonPlotExporter.m
    +Models/ComparisonModel.m
    +ViewModels/MainViewModel.m
    +Views/MainView.m
  doc/GettingStarted.m
  examples/openSimulationComparisonApp.m
  resources/functionSignatures.json
tests/
  ComparisonModelTest.m
  ExportSimulationComparisonPlotsTest.m
  MainViewModelTest.m
  IssueReporterTest.m
  SimulationComparisonAppTest.m
  +testsupport/
    createDatasetFile.m
    deleteApp.m
    ExportProgressRecorder.m
    IssueReportRecorder.m
    makeDataset.m
    spec.m
    WarningRecorder.m
buildfile.m
```

## Verification

- Supplied-file integration check: 28 matched entries and six baseline-only
  assertions.
- Model tests: matching, ambiguity, unsupported values, dimensions,
  subscripts, duplicate timestamps, interpolation rules, shifting, overlap,
  near-zero handling, fixed-point license fallback, transactional
  invalid-file behavior, SDI run discovery, SDI loading, and stale run IDs.
- ViewModel tests: selection state, element validation, unit conversion,
  limits, dataset-reload preservation, missing-signal reset behavior, SDI
  source presentation, export figure layout and labels, and progress callbacks
  for both batch and quick export.
- Visible UIFigure smoke test: creation, control gestures, plot updates,
  signal-filter clearing, quick-export button state, SDI-backed startup,
  resize, and cleanup.

## Implementation references

- `matlab-build-app/references/archetypes/explorer.md`
- `matlab-build-app/references/uifigure/guide.md`
- `matlab-build-app/references/uifigure/grid-layout.md`
- `matlab-build-app/references/uifigure/containers.md`
- `matlab-build-app/references/uifigure/components.md`
- `matlab-build-app/references/uifigure/callbacks.md`
- `matlab-build-app/references/uifigure/layout-patterns.md`
- `matlab-build-app/references/uifigure/mvvm-guide.md`
- `matlab-build-app/references/uifigure/mvvm-view-binding.md`
- `matlab-build-app/references/uifigure/mvvm-testing.md`
- `matlab-build-chart/references/axes-config.md`
- `matlab-build-chart/references/multiple-axes.md`
- `matlab-build-chart/references/performance.md`
- `matlab-write-test/reference/app-testing-guidance.md`
- Installed R2025b help for `Simulink.sdi.getAllRunIDs`,
  `Simulink.sdi.getRun`, and `Simulink.sdi.exportRun`
