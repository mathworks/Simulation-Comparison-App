function dataset = makeDataset(specifications)
%makeDataset Build a Dataset from scalar signal specification structures.
% Copyright 2026 The MathWorks, Inc.

arguments
    specifications (1, :) cell
end

dataset = Simulink.SimulationData.Dataset;
for index = 1:numel(specifications)
    specification = specifications{index};
    values = timeseries(specification.Data, specification.Time);
    signal = Simulink.SimulationData.Signal;
    signal.Name = char(specification.Name);
    signal.Values = values;
    dataset = dataset.addElement(signal);
end
end
