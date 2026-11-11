classdef IssueReporterTest < matlab.unittest.TestCase
    %IssueReporterTest Tests prefilled GitHub issue reporting.
    % Copyright 2026 The MathWorks, Inc.

    methods (Test)
        function testReportingFailureWarnsWithoutThrowing(testCase)
            exception = MException("simcompare:Test:Failure", "Original error");

            testCase.verifyWarning(@() simcompare.IssueReporter.notify( ...
                @failReporter, exception, "Export"), ...
                "simcompare:IssueReporter:Failed");
        end

        function testLongMessageIsTruncatedInPromptAndIssueDraft(testCase)
            recorder = testsupport.IssueReportRecorder("Report issue");
            exception = MException("simcompare:Test:Failure", "%s", repmat('x', 1, 6000));

            simcompare.IssueReporter.prompt(exception, "Export", [], ...
                PromptFcn=@recorder.present, UrlOpener=@recorder.open);

            testCase.verifySubstring(recorder.PromptMessage, string(repmat('x', 1, 600)) + "…");
            uri = matlab.net.URI(recorder.OpenedURLs);
            query = matlab.net.QueryParameter(uri.EncodedQuery);
            queryNames = string({query.Name});
            title = string(query(queryNames == "title").Value);
            description = string(query(queryNames == "body").Value);
            testCase.verifyLessThanOrEqual(strlength(title), 200);
            testCase.verifyTrue(endsWith(title, "…"));
            testCase.verifySubstring(description, "[Diagnostic report truncated]");
        end

        function testDraftHandlesUnidentifiedErrorAndCodeFences(testCase)
            exception = MException("", "Failure with ``` and whitespace");

            issueURL = simcompare.IssueReporter.buildIssueURL(exception, "");

            uri = matlab.net.URI(issueURL);
            query = matlab.net.QueryParameter(uri.EncodedQuery);
            queryNames = string({query.Name});
            title = string(query(queryNames == "title").Value);
            description = string(query(queryNames == "body").Value);
            testCase.verifyTrue(startsWith(title, "MATLAB error: "));
            testCase.verifySubstring(description, "**Identifier:** `unidentified`");
            testCase.verifySubstring(description, "Failure with ''' and whitespace");
        end

        function testBuildsPrefilledIssueURL(testCase)
            exception = MException( ...
                "simcompare:Test:Failure", ...
                "Could not compare A & B.");

            issueURL = simcompare.IssueReporter.buildIssueURL( ...
                exception, "CLI export");

            testCase.verifyTrue(startsWith( ...
                issueURL, "https://github.com/mathworks/Simulation-Comparison-App/issues/new?"));
            testCase.verifySubstring( ...
                issueURL, "template=bug_report.md");
            testCase.verifySubstring( ...
                issueURL, "title=MATLAB+error");
            testCase.verifySubstring( ...
                issueURL, "body=");
            testCase.verifySubstring( ...
                issueURL, "simcompare:Test:Failure");
            testCase.verifySubstring(issueURL, "CLI+export");
        end

        function testConfirmationOpensIssuePage(testCase)
            recorder = testsupport.IssueReportRecorder("Report issue");
            exception = MException( ...
                "simcompare:Test:Failure", "Test failure");

            opened = simcompare.IssueReporter.prompt( ...
                exception, "App callback", [], ...
                PromptFcn=@recorder.present, ...
                UrlOpener=@recorder.open);

            testCase.verifyTrue(opened);
            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifySubstring( ...
                recorder.PromptMessage, "Test failure");
            testCase.verifySubstring(recorder.PromptMessage, "GitHub issue");
            testCase.verifyNumElements(recorder.OpenedURLs, 1);
        end

        function testDecliningDoesNotOpenIssuePage(testCase)
            recorder = testsupport.IssueReportRecorder("Not now");
            exception = MException( ...
                "simcompare:Test:Failure", "Test failure");

            opened = simcompare.IssueReporter.prompt( ...
                exception, "App callback", [], ...
                PromptFcn=@recorder.present, ...
                UrlOpener=@recorder.open);

            testCase.verifyFalse(opened);
            testCase.verifyEqual(recorder.Count, 1);
            testCase.verifyEmpty(recorder.OpenedURLs);
        end
    end
end

function failReporter(~, ~, ~)
error("testsupport:ReporterFailed", "Injected reporter failure.");
end
