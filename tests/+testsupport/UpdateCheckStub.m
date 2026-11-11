classdef UpdateCheckStub
    %UpdateCheckStub Background-compatible release checker test double.
    % Copyright 2026 The MathWorks, Inc.

    methods (Static)
        function result = delayedAvailable()
            pause(0.5);
            result = struct( ...
                "tag_name", "v1.2.3", ...
                "name", "v1.2.3", ...
                "draft", false, ...
                "prerelease", false, ...
                "html_url", ...
                "https://github.com/mathworks/Simulation-Comparison-App/releases/tag/v1.2.3");
        end

        function result = fail()
            result = struct.empty; %#ok<NASGU>
            error("testsupport:UpdateCheckFailed", ...
                "Simulated update-check failure.");
        end

        function result = delayedResponse(scenario)
            result = testsupport.UpdateCheckStub.delayedAvailable();
            switch scenario
                case "failure"
                    error("testsupport:UpdateCheckFailed", "Request failed.");
                case "unauthorized"
                    error("MATLAB:webservices:HTTP401StatusCodeError", ...
                        "Unauthorized request.");
                case "rateLimited"
                    error("MATLAB:webservices:HTTP403StatusCodeError", ...
                        "API rate limit exceeded.");
                case "notFound"
                    error("MATLAB:webservices:HTTP404StatusCodeError", ...
                        "No published release.");
                case "invalid"
                    result = struct("tag_name", "invalid");
                case "current"
                    result.tag_name = "v1.2.2";
                case "older"
                    result.tag_name = "v1.2.1";
                case "prerelease"
                    result.prerelease = true;
                case "draft"
                    result.draft = true;
            end
        end
    end
end
