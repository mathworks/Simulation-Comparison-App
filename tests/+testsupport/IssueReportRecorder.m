classdef IssueReportRecorder < handle
    %IssueReportRecorder Capture issue-report prompts and browser requests.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Count double = 0
        ExceptionIdentifier string = ""
        Context string = ""
        Figure = []
        PromptMessage string = ""
        OpenedURLs string = strings(0, 1)
    end

    properties
        Choice string = "Not now"
    end

    methods
        function obj = IssueReportRecorder(choice)
            arguments
                choice (1, 1) string {mustBeMember( ...
                    choice, ["Report issue", "Not now"])} = "Not now"
            end
            obj.Choice = choice;
        end

        function report(obj, exception, context, figureHandle)
            obj.Count = obj.Count + 1;
            obj.ExceptionIdentifier = string(exception.identifier);
            obj.Context = string(context);
            obj.Figure = figureHandle;
        end

        function choice = present(obj, figureHandle, message)
            obj.Count = obj.Count + 1;
            obj.Figure = figureHandle;
            obj.PromptMessage = string(message);
            choice = obj.Choice;
        end

        function open(obj, issueURL)
            obj.OpenedURLs(end + 1, 1) = string(issueURL);
        end
    end
end
