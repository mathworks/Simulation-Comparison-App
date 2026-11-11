---
name: Simulation Comparison App bug report
about: Report an installation, data import, comparison, or export problem
title: ''
labels: bug
assignees: ''
---

<!-- Replace the prompts with your details. Omit fields that do not apply.
Remove private information from datasets, code, and diagnostic logs. -->

## Problem

Describe what failed and whether the problem occurs consistently.

## Environment

- MATLAB release and update:
- Simulink version:
- Operating system and architecture:
- App version or source commit:
- Installation method: `.mltbx` or source clone with `SimulationComparisonApp.prj` open:
- Data source: MAT-file, live SDI run, or saved SDI session:

These commands can help collect environment details:

```matlab
version
computer
ver('simulink')
string(simcompare.toolboxVersion())
```

## Minimal reproduction

List the setup steps and the exact app actions or MATLAB commands that reproduce
the problem. Include a small synthetic dataset when the problem involves signal
data, with its data types, dimensions, units, and sample or frame interpretation.

```matlab
% Paste a minimal reproduction here, including the options used.
```

## Expected and actual behavior

Describe the expected result and what happened instead.

## Error messages

Paste the full MATLAB error message, error identifier, and stack trace as text.

```text
```

## Additional context

Include the last working app or MATLAB version, recent environment changes, and
any workaround you have tried. Attach screenshots when they explain a visual issue.
