classdef WarningRecorder < handle
    %WarningRecorder Capture warning presentations in UI tests.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Count double = 0
        Figure = []
        Message string = ""
    end

    methods
        function present(obj, figureHandle, message)
            obj.Count = obj.Count + 1;
            obj.Figure = figureHandle;
            obj.Message = string(message);
        end
    end
end
