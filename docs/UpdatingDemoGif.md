# Updating the README demo GIF

Use `generateSimulationComparisonDemoGif.m` to update
`docs/images/simulation-comparison-app-demo.gif`. It drives the actual app
with deterministic synthetic datasets, captures its UI, and writes the GIF
that the README embeds.

## Visual contract

- Design the sequence as a first introduction to the app. Prioritize the
  enduring end-to-end workflow and the features that best explain the app's
  value; do not automatically give the newest feature a frame.
- Force the documentation capture to MATLAB&reg; light mode with
  `app.view.Figure.Theme = "light"`. Do not change the app's normal theme
  behavior merely to affect the GIF.
- Keep the dark navy caption bar, white `N / total` caption, and orange
  callout frame (`[242, 135, 0]`).
- Each frame's orange callout must surround the UI control or panel described
  by its caption. Prefer `findPanel` for a whole feature area and explicit
  component handles for a smaller control group.
- Capture the live 1320-by-780 app at native resolution. Do not replace it
  with a mockup or an image-generated UI.
- Keep the story concise. The current demo has seven frames; add, remove, or
  reorder frames only when that makes the evolving feature story clearer.

## Update workflow

1. Review the app's full current feature set from a new user's perspective.
   Keep the clearest core workflow, replacing a frame only when that improves
   the overall introduction.
2. Extend `writeDemoDatasets` when a feature needs additional signal shapes,
   data types, or timing behavior.
3. Update the frame sequence near the top of
   `generateSimulationComparisonDemoGif.m`. For each frame, set the app state,
   supply a plain-language caption, and pass the relevant callout target to
   `captureFrame`.
4. In MATLAB, from the project root, run:

   ```matlab
   project = openProject(pwd);
   generateSimulationComparisonDemoGif
   ```

   The `docs` folder is persistently registered on the project path. If the
   generator is ever moved, register its new folder with `Project.addPath`;
   do not use `addpath` or `rmpath`.

   The script cleans up its temporary MAT-files, closes the app, and replaces
   only `docs/images/simulation-comparison-app-demo.gif`.
5. Visually review every GIF frame at full size. Check that the light theme is
   used, captions fit, orange frames are accurate, and text remains readable.
6. Run MATLAB Code Analyzer on the generator before committing:

   ```matlab
   checkcode("docs/generateSimulationComparisonDemoGif.m")
   ```

## Current feature sequence

1. Load MAT-files or live SDI runs.
2. Find matching signals with fuzzy search.
3. Compare overlaid source traces with relative or absolute error.
4. Inspect an element of a multidimensional signal.
5. Switch a signal to frame-based interpretation.
6. Align the traces and synchronize the time view.
7. Customize labels and export selected signals.
