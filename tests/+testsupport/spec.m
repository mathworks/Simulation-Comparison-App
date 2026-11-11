function specification = spec(name, time, data)
%spec Create one synthetic signal specification.
% Copyright 2026 The MathWorks, Inc.

arguments
    name (1, 1) string
    time
    data
end

specification = struct( ...
    "Name", name, ...
    "Time", time, ...
    "Data", data);
end
