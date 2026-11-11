# SDI Session Import Plan

## Architecture

- Keep the existing programmatic UIFigure MVVM structure.
- Let the existing Browse action accept MAT and MLDATX files.
- Import through `Simulink.sdi.load` without opening the SDI application.
- Show an indeterminate progress dialog while MATLAB imports the session.
- Resume with the existing SDI run-selection and run-loading flow.

## Behavior

1. The user clicks `Browse...` and chooses a MAT or `.mldatx` file.
2. The model records current SDI run IDs, loads the session, and identifies
   only the newly imported runs.
3. The view closes the progress dialog and asks the user to select one of
   those imported runs.
4. The selected run is copied into the comparison model as a
   `Simulink.SimulationData.Dataset`.
5. Existing SDI runs remain available.

`Simulink.sdi.load` is intentionally run on the MATLAB client. The API is not
supported on `backgroundPool` thread workers, so the progress dialog provides
feedback while the hidden import completes.

## Verification

- Develop against `DummySession.mldatx` without registering or modifying it.
- Create regression data in a temporary folder by creating test-owned SDI
  runs and exporting the session with `Simulink.sdi.save`.
- Verify imported run discovery, existing-run preservation, run loading, and
  invalid file rejection.
- Run Code Analyzer and the MATLAB test suites.
