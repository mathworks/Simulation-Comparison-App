function createDatasetFile(filePath, variableName, specifications)
%createDatasetFile Save a synthetic SimulationData Dataset to a MAT-file.
% Copyright 2026 The MathWorks, Inc.

arguments
    filePath (1, 1) string
    variableName (1, 1) string
    specifications (1, :) cell
end

payload = struct;
payload.(variableName) = testsupport.makeDataset(specifications);
save(filePath, "-struct", "payload");
end
