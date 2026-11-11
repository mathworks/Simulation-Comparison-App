function outputFile = generateSimulationComparisonDemoGif()
%generateSimulationComparisonDemoGif Create the README feature demo GIF.
%
%   OUTPUTFILE = generateSimulationComparisonDemoGif() creates a
%   seven-frame demo using synthetic comparison datasets. The frames exercise
%   the current app layout and its primary interactive workflows.
%   See docs/UpdatingDemoGif.md before changing the sequence or styling.
% Copyright 2026 The MathWorks, Inc.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
project = currentProject;
assert(~isempty(project) && strcmpi(project.RootFolder, projectRoot), ...
    "Open the Simulation Comparison App project before generating the GIF.");
outputFile = fullfile(projectRoot, "docs", "images", ...
    "simulation-comparison-app-demo.gif");

workFolder = tempname;
mkdir(workFolder);
cleanup = onCleanup(@() cleanUp(workFolder));

[baselineFile, comparisonFile] = writeDemoDatasets(workFolder);
app = runSimulationComparisonApp( ...
    BaselineFile=baselineFile, CompareFile=comparisonFile);
appCleanup = onCleanup(@() closeApp(app));
app.view.Figure.Position = [100, 100, 1320, 780];
app.view.Figure.Theme = "light";
drawnow;

dataSourcesPanel = findPanel(app.view.Figure, "Data sources");
signalsPanel = findPanel(app.view.Figure, "Signals");
selectedElementPanel = findPanel(app.view.Figure, "Selected element");
timeViewPanel = findPanel(app.view.Figure, "Time and view");
exportPanel = findPanel(app.view.Figure, "Export comparison plots");

frames = cell(7, 1);
frames{1} = captureFrame(app.view.Figure, ...
    "1 / 7   Load MAT-files or live Simulation Data Inspector runs", ...
    dataSourcesPanel);

selectSignal(app, "Motor torque");
app.view.SignalSearchField.Value = "mtrtq";
app.view.SignalSearchField.ValueChangedFcn( ...
    app.view.SignalSearchField, struct("Value", "mtrtq"));
frames{2} = captureFrame(app.view.Figure, ...
    "2 / 7   Find matching signals with fuzzy search", signalsPanel);

app.view.SignalSearchField.Value = "";
app.view.SignalSearchField.ValueChangedFcn( ...
    app.view.SignalSearchField, struct("Value", ""));
app.viewModel.setErrorTypeCommand("Absolute");
frames{3} = captureFrame(app.view.Figure, ...
    "3 / 7   Compare overlaid traces with relative or absolute error", ...
    [app.view.SourceAxes, app.view.ErrorAxes]);

app.viewModel.setElementCommand("2");
frames{4} = captureFrame(app.view.Figure, ...
    "4 / 7   Inspect any element of a multidimensional signal", ...
    selectedElementPanel);

selectSignal(app, "Frame vibration");
app.viewModel.setSignalInterpretationCommand("Frame-based");
frames{5} = captureFrame(app.view.Figure, ...
    "5 / 7   Expand frame-based signals into a scalar stream", ...
    selectedElementPanel);

selectSignal(app, "Engine speed");
app.viewModel.setSignalInterpretationCommand("Sample-based");
app.viewModel.setTimeShiftCommand(-0.18);
app.viewModel.setTimeUnitCommand("ms");
app.viewModel.setXLimitsCommand(2500, 6500);
frames{6} = captureFrame(app.view.Figure, ...
    "6 / 7   Align traces and keep both plots on one time view", ...
    timeViewPanel);

app.view.BaselineLine.DisplayName = "Reference";
app.view.CompareLine.DisplayName = "Candidate";
app.view.SourceLegend.String = ["Reference", "Candidate"];
app.viewModel.selectAllForExportCommand();
app.view.ExportFormatDropdown.Value = "svg";
frames{7} = captureFrame(app.view.Figure, ...
    "7 / 7   Customize labels and export selected signals in five formats", ...
    exportPanel);

writeGif(frames, outputFile);
fprintf("Wrote %s\n", outputFile);
end

function [baselineFile, comparisonFile] = writeDemoDatasets(workFolder)
time = (0:0.02:10).';
speed = 1950 + 245 * sin(1.3 * time) + 64 * sin(5.7 * time);
torque = [110 + 45 * sin(2.2 * time), 95 + 38 * cos(1.8 * time)];
voltage = 400 + 14 * sin(4 * time);
state = int16(mod(floor(time), 3));

frameTime = (0:0.2:10).';
frameSamples = 4;
frameData = zeros(frameSamples, 1, numel(frameTime));
comparisonFrameData = frameData;
for frameIndex = 1:numel(frameTime)
    sampleTime = frameTime(frameIndex) + (0:frameSamples - 1) / frameSamples * 0.2;
    frameData(:, 1, frameIndex) = ...
        0.45 * sin(2 * pi * 0.8 * sampleTime) + 0.05 * cos(2 * pi * 2 * sampleTime);
    comparisonFrameData(:, 1, frameIndex) = ...
        0.47 * sin(2 * pi * 0.8 * (sampleTime - 0.03)) + ...
        0.05 * cos(2 * pi * 2 * sampleTime);
end

baseline = createDataset({ ...
    signalSpec("Engine speed", time, speed), ...
    signalSpec("Motor torque", time, torque), ...
    signalSpec("DC link voltage", time, voltage), ...
    signalSpec("Controller state", time, state), ...
    signalSpec("Frame vibration", frameTime, frameData)});
comparison = createDataset({ ...
    signalSpec("Engine speed", time, 1.01 * (1950 + ...
    245 * sin(1.3 * (time - 0.18)) + 64 * sin(5.7 * (time - 0.18))) + ...
    8 * sin(0.9 * (time - 0.18))), ...
    signalSpec("Motor torque", time, torque .* [1.025, 0.975] + 2), ...
    signalSpec("DC link voltage", time, voltage + 5 * sin(1.2 * time)), ...
    signalSpec("Controller state", time, state), ...
    signalSpec("Frame vibration", frameTime, comparisonFrameData)});

baselineFile = fullfile(workFolder, "baseline-demo.mat");
comparisonFile = fullfile(workFolder, "comparison-demo.mat");
save(baselineFile, "baseline");
save(comparisonFile, "comparison");
end

function specification = signalSpec(name, time, data)
specification = struct("Name", string(name), "Time", time, "Data", data);
end

function dataset = createDataset(specifications)
dataset = Simulink.SimulationData.Dataset;
for index = 1:numel(specifications)
    specification = specifications{index};
    signal = Simulink.SimulationData.Signal;
    signal.Name = char(specification.Name);
    signal.Values = timeseries(specification.Data, specification.Time);
    dataset = dataset.addElement(signal);
end
end

function selectSignal(app, name)
row = find(app.viewModel.SignalTable.Name == name, 1);
assert(~isempty(row), "Demo signal '%s' is unavailable.", name);
app.viewModel.selectRowCommand(row);
drawnow;
end

function frame = captureFrame(figureHandle, caption, highlightedComponents)
drawnow;
pause(0.15);
image = getframe(figureHandle).cdata;
image = addHighlight(image, figureHandle, highlightedComponents);
bannerHeight = 54;
banner = repmat(reshape(uint8([18, 29, 49]), 1, 1, 3), ...
    bannerHeight, size(image, 2));
frame = [banner; image];
frame = insertText(frame, [20, 11], caption, ...
    FontSize=21, TextColor="white", BoxOpacity=0);
end

function panel = findPanel(figureHandle, title)
panel = findall(figureHandle, Type="uipanel", Title=title);
assert(isscalar(panel), "Expected one panel titled '%s'.", title);
end

function image = addHighlight(image, figureHandle, components)
positions = zeros(numel(components), 4);
for index = 1:numel(components)
    positions(index, :) = getpixelposition(components(index), true);
end
left = floor(min(positions(:, 1))) - 5;
right = ceil(max(positions(:, 1) + positions(:, 3))) + 5;
bottom = floor(min(positions(:, 2))) - 5;
top = ceil(max(positions(:, 2) + positions(:, 4))) + 5;

figureHeight = figureHandle.Position(4);
top = figureHeight - top + 1;
bottom = figureHeight - bottom + 1;
left = max(1, left);
top = max(1, top);
right = min(size(image, 2), right);
bottom = min(size(image, 1), bottom);

orange = uint8([242, 135, 0]);
lineWidth = 4;
for colorIndex = 1:3
    image(top:top + lineWidth - 1, left:right, colorIndex) = ...
        orange(colorIndex);
    image(bottom - lineWidth + 1:bottom, left:right, colorIndex) = ...
        orange(colorIndex);
    image(top:bottom, left:left + lineWidth - 1, colorIndex) = ...
        orange(colorIndex);
    image(top:bottom, right - lineWidth + 1:right, colorIndex) = ...
        orange(colorIndex);
end
end

function writeGif(frames, outputFile)
if isfile(outputFile)
    delete(outputFile);
end
delays = [1.7, 1.6, 1.7, 1.8, 1.8, 1.7, 2.2];
for index = 1:numel(frames)
    [indexedFrame, colorMap] = rgb2ind(frames{index}, 256, "nodither");
    if index == 1
        imwrite(indexedFrame, colorMap, outputFile, "gif", ...
            LoopCount=Inf, DelayTime=delays(index));
    else
        imwrite(indexedFrame, colorMap, outputFile, "gif", ...
            WriteMode="append", DelayTime=delays(index));
    end
end
end

function closeApp(app)
if isfield(app, "view") && isvalid(app.view)
    delete(app.view);
end
if isfield(app, "viewModel") && isvalid(app.viewModel)
    delete(app.viewModel);
end
if isfield(app, "model") && isvalid(app.model)
    delete(app.model);
end
end

function cleanUp(workFolder)
if isfolder(workFolder)
    rmdir(workFolder, "s");
end
end
