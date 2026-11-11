# Frame-Based Signal Support Plan

**Architecture:** Existing programmatic UIFigure MVVM app
**Layout:** Explorer — retain the sidebar and extend the Selected element panel

## Behavior

- Default every selected signal to **Sample-based** so existing comparisons are
  unchanged.
- Let the user choose **Frame-based** in the Selected element panel when SDI
  metadata does not identify a signal's interpretation.
- In frame-based mode, expand each frame into a scalar sample stream before
  comparison, plotting, and current-plot export.  The frame timestamps define
  the start of each frame; each frame is subdivided evenly using the following
  frame timestamp (or the prior interval for the final frame).
- Treat the converted stream as scalar, so element selection is disabled in
  frame-based mode.

## Implementation

1. Extend `ComparisonModel` comparison, subscript validation, and scalar checks
   with an optional signal-interpretation argument.  Add a pure frame-expansion
   helper that preserves the original SDI runs and MAT-file data.
2. Add observable `SignalInterpretation` state and a command to
   `MainViewModel`; use it for plot updates and export selections.
3. Add a Sample-based / Frame-based dropdown to `MainView` and bind it through
   the ViewModel.
4. Add model, ViewModel, and UI regression tests for frame expansion and the
   new control.

## Layout Refinement

- Put the interpretation label/dropdown and the subscript label/field in one
  horizontal control row. Keep the selection summary on the row below.

## References Applied

- `matlab-build-app`: existing programmatic UIFigure/MVVM edit; the Selected
  element panel remains in the Explorer sidebar.
- `matlab-read-documentation`: `Simulink.sdi.Signal` provides
  `convertToFrames` but no frame-status property, so the interpretation remains
  an explicit user choice.
- `matlab-write-test`: use public model/ViewModel interfaces and a
  `matlab.uitest` dropdown gesture.
