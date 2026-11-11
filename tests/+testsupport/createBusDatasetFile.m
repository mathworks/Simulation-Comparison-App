function createBusDatasetFile(filePath, variableName, scale)
%createBusDatasetFile Save synthetic multilevel logged buses to a MAT-file.
% Copyright 2026 The MathWorks, Inc.

arguments
    filePath (1, 1) string
    variableName (1, 1) string
    scale (1, 1) double = 1
end

time = [0; 1; 2];
scalarValues = timeseries(scale .* [1; 2; 3], time);
scalarValues.Name = "Scalar";
vectorValues = timeseries( ...
    scale .* [1, 10; 2, 20; 3, 30], time);
vectorValues.Name = "Vector";

nonVirtualValues = struct;
nonVirtualValues.Controller = struct;
nonVirtualValues.Controller.Measurements = struct( ...
    Scalar=scalarValues, ...
    Vector=vectorValues);
nonVirtualBus = Simulink.SimulationData.Signal;
nonVirtualBus.Name = "NonVirtualBus";
nonVirtualBus.Values = nonVirtualValues;

scalarSignal = Simulink.SimulationData.Signal;
scalarSignal.Name = "Scalar";
scalarSignal.Values = scalarValues;
vectorSignal = Simulink.SimulationData.Signal;
vectorSignal.Name = "Vector";
vectorSignal.Values = vectorValues;

measurements = Simulink.SimulationData.Dataset;
measurements.Name = "Measurements";
measurements = measurements.addElement(scalarSignal);
measurements = measurements.addElement(vectorSignal);
controller = Simulink.SimulationData.Dataset;
controller.Name = "Controller";
controller = controller.addElement(measurements);
virtualBus = Simulink.SimulationData.Dataset;
virtualBus.Name = "VirtualBus";
virtualBus = virtualBus.addElement(controller);

dataset = Simulink.SimulationData.Dataset;
dataset = dataset.addElement(nonVirtualBus);
dataset = dataset.addElement(virtualBus);
payload = struct;
payload.(variableName) = dataset;
save(filePath, "-struct", "payload");
end
