# Implementation Plan: Simulation Comparison App Update Check

**Architecture:** Existing programmatic UIFigure MVVM app

**Serialization:** Programmatic MATLAB files

**Layout:** Explorer — preserve the current sidebar-and-plots layout and add
only a startup update prompt when a newer release exists.

## Structure

- Add a model-layer release checker that calls the public GitHub latest-release
  API for `mathworks/Simulation-Comparison-App` without credentials, validates
  `tag_name`, `html_url`, `draft`, and `prerelease`, and compares
  `matlab.mpm.Version` values directly.
- Launch the bounded GitHub request on `backgroundPool` from `MainView`
  during startup.
- Keep request and completion future state in the view and cancel both
  when the app closes.
- Present a Download/Later confirmation from the view after a successful
  check.
- Open the GitHub release page in the system browser when Download is selected.

## Key behaviors

- Queue one asynchronous check after the app becomes visible so startup and
  interaction remain responsive.
- Skip the check when the current version is `0.0.0`, which identifies a
  development checkout.
- Prompt only when the latest stable release is newer than the packaged version.
- Accept release tags with or without a leading `v` and exclude drafts and
  prereleases, including tags with semantic prerelease metadata.
- Continue startup silently if the network or release response is unavailable
  or invalid, including HTTP 404 (no stable release) and API rate limiting.
- Bound the synchronous request with a short timeout.
- Do not bundle credentials or require an environment file for public checks.

## Internal references

| Reference | Role |
|---|---|
| `references/editing-guide.md` | Confirms the existing programmatic app path |
| `references/uifigure/mvvm-guide.md` | Keeps release logic outside the view |
| `references/uifigure/mvvm-view-binding.md` | Preserves current view boundaries |
| `references/background-tasks.md` | Defines background task lifecycle and error routing |
| `references/uifigure/mvvm-background-tasks.md` | Wires `backgroundPool` into the existing MVVM view |

## External skills

- `matlab-write-tests` — covers release parsing and app prompt behavior.
- `matlab-run-tests` — runs focused and full regression tests.

## File organization

```text
toolbox/
  +simcompare/
    +Models/ReleaseChecker.m
    +Views/MainView.m
tests/
  ReleaseCheckerTest.m
  SimulationComparisonAppTest.m
```

## Implementation sequence

1. Add and unit-test release response and semantic-version handling.
2. Add the unauthenticated GitHub request with JSON headers and a short timeout.
3. Wire the bounded release check into the view startup lifecycle through
   `backgroundPool`, including completion and close-time cancellation.
4. Add asynchronous prompt tests using injected checker, presenter, and
   URL-opener callbacks.
5. Run Code Analyzer, focused tests, and the full build test suite.
6. Publish installers with the GitHub release workflow by calling
   `package("<tag>")`; verify live metadata after a stable release is published.
