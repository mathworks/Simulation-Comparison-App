# Simulation Comparison App menu bar

Retain the programmatic UIFigure and existing MVVM Explorer layout.
Create native `uimenu` entries above the comparison controls and plots.

- File: load a baseline or comparison from a file or SDI session, choose an
  SDI run, clear either source, and close the app.
- View: reset the plot view, zero the time shift, and edit legend labels.
- Export: select all signals, clear the selection, export selected plots,
  and quickly export the current signal using the sidebar's chosen format.
- Feedback: open the repository's bug report or feature request template,
  or the File Exchange listing's Reviews tab.
- Help: open the packaged Getting Started guide, repository, File Exchange
  listing, or an About dialog with the running app version.

Reuse existing button callbacks and synchronize their Enable properties during
source and selection state updates. Use the existing guarded
callback and URL opener for additional actions.

References: `matlab-build-app/references/editing-guide.md` establishes the
programmatic editing approach; `references/uifigure/components.md` and
`references/uifigure/callbacks.md` provide component ownership and callback
patterns.

Update the README, register the plan in the existing MATLAB project, run
Code Analyzer and the existing app tests, and check menu callbacks and URL
destinations with the existing injected URL recorder.
