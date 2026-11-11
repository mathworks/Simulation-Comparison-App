classdef UpdatePromptRecorder < handle
    %UpdatePromptRecorder Record update prompt and URL-open requests.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Count double = 0
        Figure = []
        Result struct = struct.empty
        OpenedURLs string = strings(0, 1)
    end

    properties
        Choice string = "Later"
    end

    methods
        function obj = UpdatePromptRecorder(choice)
            arguments
                choice (1, 1) string {mustBeMember( ...
                    choice, ["Download", "Later"])} = "Later"
            end
            obj.Choice = choice;
        end

        function choice = present(obj, figureHandle, result)
            obj.Count = obj.Count + 1;
            obj.Figure = figureHandle;
            obj.Result = result;
            choice = obj.Choice;
        end

        function open(obj, url)
            obj.OpenedURLs(end + 1, 1) = string(url);
        end
    end
end
