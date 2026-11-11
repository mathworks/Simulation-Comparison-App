# Version Display Plan

## Architecture

- Keep the existing programmatic UIFigure and MVVM structure.
- Display the release beside the app name in the native window title bar:
  `Simulation Comparison — vX.Y.Z`.
- Read the value from a MATLAB function so dependency analysis includes it
  when the app is compiled for standalone deployment.

## Build Integration

- Add `simcompare.toolboxVersion` with `0.0.0` as the source-checkout value.
- During `packageTask`, normalize the supplied version once and use that same
  value for both `ToolboxOptions.ToolboxVersion` and the runtime version
  function.
- Restore the source-checkout version file after packaging, including when
  packaging fails, so a release build does not dirty the working tree.

## Verification

- Add a UIFigure test that injects a known version and verifies the complete
  window title.
- Add a test that verifies the default title uses
  `simcompare.toolboxVersion`.
- Run Code Analyzer and the app test suite in MATLAB.
