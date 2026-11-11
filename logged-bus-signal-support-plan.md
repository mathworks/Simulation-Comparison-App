# Implementation Plan: Logged Bus Signal Support

**Architecture:** Existing programmatic UIFigure app with a shared model and
view-model layer.

**Layout:** Existing Explorer layout. Bus leaves appear as ordinary rows in the
signal table; no structural UI changes are required.

## Behavior

- Recursively flatten logged bus values to arbitrary depth into leaf signal
  records.
- Use dotted names such as `Bus.Measurement` and `Parent.Nested.Leaf`.
- Support non-virtual buses represented by scalar structures and virtual buses
  represented by nested `Simulink.SimulationData.Dataset` objects.
- Preserve each leaf's time, data type, dimensions, units, interpolation, and
  element-selection behavior.
- Use the same flattened records for MAT-file and SDI inputs, app filtering and
  selection, plotting, comparison, and the public export API.
- Preserve existing behavior for ordinary signals and unsupported values.

## Files

- `toolbox/+simcompare/+Models/ComparisonModel.m`
  - Add recursive bus-leaf extraction at dataset ingestion.
- `tests/ComparisonModelTest.m`
  - Verify multilevel struct and nested Dataset bus comparison, including an
    SDI import/export round trip.
- `tests/MainViewModelTest.m`
  - Verify flattened names and plotted leaf data in the app-facing model.
- `tests/SimulationComparisonAppTest.m`
  - Verify dotted-name table filtering, selection, and plotted data.
- `tests/ExportSimulationComparisonPlotsTest.m`
  - Verify public API export by dotted bus-leaf name.
- `README.md`
  - Document flattened bus names for the app and API.

## Verification

1. Run focused model, view-model, app, and API tests.
2. Run static MATLAB code analysis on modified MATLAB files.
3. Run the complete project test suite.
4. Verify every changed or created artifact belongs to the MATLAB project.

## References

- `matlab-build-app/references/editing-guide.md` — preserve the existing app
  architecture and edit the shared model/view-model flow.
- `matlab-build-chart/SKILL.md` — keep plotting through existing axes and update
  line data in place.
- `matlab-write-tests/SKILL.md` — add class-based public-interface regression
  coverage.
- `managing-simulink-projects/references/path-and-file-management.md` —
  register this plan and verify project membership.
