classdef LegendTextEditorStub < handle
    %LegendTextEditorStub Supply legend editor responses in UI tests.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Defaults cell = {}
        Count double = 0
    end

    properties (Access = private)
        Responses cell
        Acceptances logical
    end

    methods
        function obj = LegendTextEditorStub(responses, acceptances)
            arguments
                responses (1, :) cell
                acceptances (1, :) logical
            end
            if numel(responses) ~= numel(acceptances)
                error("testsupport:LegendTextEditorStub:SizeMismatch", ...
                    "Responses and acceptances must have the same size.");
            end
            obj.Responses = responses;
            obj.Acceptances = acceptances;
        end

        function [legendText, accepted] = present( ...
                obj, ~, defaultText)
            obj.Count = obj.Count + 1;
            obj.Defaults{obj.Count, 1} = string(defaultText);
            legendText = string(obj.Responses{obj.Count});
            accepted = obj.Acceptances(obj.Count);
        end
    end
end
