classdef ReleaseCheckerTest < matlab.unittest.TestCase
    %ReleaseCheckerTest Tests public GitHub release response handling.
    % Copyright 2026 The MathWorks, Inc.

    properties (TestParameter)
        InvalidReleaseURL = struct( ...
            Empty="", Missing=string(missing), ...
            Multiple=["https://example/a", "https://example/b"], ...
            Numeric=42, Insecure="http://github.com/releases/v1.2.3", ...
            OtherRepository="https://github.com/example/app/releases/tag/v1.2.3")
        InvalidTag = struct(Empty="", Missing=string(missing), ...
            Multiple=["v1.2.3", "v2.0.0"], Numeric=123, ...
            Invalid="latest", DoublePrefix="vv1.2.3", Partial="1.2")
        InvalidFlag = struct(Text="false", Numeric=0, Empty=[], ...
            Multiple=[true, false])
        Tag = struct(Prefixed="v1.2.3", Unprefixed="1.2.3")
        ReleaseFlag = {"draft", "prerelease"}
        InvalidTimeout = struct(Zero=0, Negative=-1, Infinite=Inf, ...
            NotANumber=NaN, Complex=1+1i, Text="10", Multiple=[1, 2])
        VersionCase = struct( ...
            "newer", struct( ...
                "Current", matlab.mpm.Version("1.2.2"), ...
                "Latest", matlab.mpm.Version("1.2.3"), "Expected", true), ...
            "equal", struct( ...
                "Current", matlab.mpm.Version("1.2.3"), ...
                "Latest", matlab.mpm.Version("1.2.3"), "Expected", false), ...
            "older", struct( ...
                "Current", matlab.mpm.Version("1.3.0"), ...
                "Latest", matlab.mpm.Version("1.2.3"), "Expected", false), ...
            "numeric", struct( ...
                "Current", matlab.mpm.Version("1.9.0"), ...
                "Latest", matlab.mpm.Version("1.10.0"), "Expected", true))
    end

    methods (Test)
        function testIdentifiesDevelopmentVersion(testCase)
            testCase.verifyTrue( ...
                simcompare.Models.ReleaseChecker.isDevelopmentVersion( ...
                matlab.mpm.Version("0.0.0")));
        end

        function testDoesNotIdentifyPackagedVersionAsDevelopment(testCase)
            testCase.verifyFalse( ...
                simcompare.Models.ReleaseChecker.isDevelopmentVersion( ...
                matlab.mpm.Version("1.2.3")));
        end

        function testComparesSemanticVersions(testCase, VersionCase)
            release = releaseResponse("v" + string(VersionCase.Latest));

            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                VersionCase.Current, release);

            testCase.verifyEqual(result.IsUpdateAvailable, VersionCase.Expected);
            testCase.verifyEqual(result.CurrentVersion, VersionCase.Current);
            testCase.verifyEqual(result.LatestVersion, VersionCase.Latest);
            testCase.verifyEqual(result.ReleaseName, release.name);
            testCase.verifyEqual(result.ReleaseURL, release.html_url);
        end

        function testAcceptsVersionTags(testCase, Tag)
            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), releaseResponse(Tag));

            testCase.verifyTrue(result.IsUpdateAvailable);
            testCase.verifyEqual(result.LatestVersion, matlab.mpm.Version("1.2.3"));
        end

        function testAcceptsDecodedJsonAndUnnamedRelease(testCase)
            release = jsondecode(jsonencode(releaseResponse("v1.2.3")));
            release.name = [];

            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), release);

            testCase.verifyTrue(result.IsUpdateAvailable);
            testCase.verifyEqual(result.ReleaseName, "v1.2.3");
        end

        function testFallsBackToTagWhenNameIsMissing(testCase)
            release = rmfield(releaseResponse("v1.2.3"), "name");

            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), release);

            testCase.verifyEqual(result.ReleaseName, "v1.2.3");
        end

        function testRejectsIncompleteResponse(testCase)
            testCase.verifyError( ...
                @() simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), struct("tag_name", "v1.2.3")), ...
                "simcompare:ReleaseChecker:InvalidResponse");
        end

        function testRejectsInvalidReleaseURL(testCase, InvalidReleaseURL)
            release = releaseResponse("v1.2.3");
            release.html_url = InvalidReleaseURL;

            testCase.verifyError( ...
                @() simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), release), ...
                "simcompare:ReleaseChecker:InvalidResponse");
        end

        function testRejectsInvalidTag(testCase, InvalidTag)
            release = releaseResponse("v1.2.3");
            release.tag_name = InvalidTag;

            testCase.verifyError( ...
                @() simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), release), ...
                "simcompare:ReleaseChecker:InvalidResponse");
        end

        function testRejectsInvalidFlag(testCase, InvalidFlag, ReleaseFlag)
            release = releaseResponse("v1.2.3");
            release.(ReleaseFlag) = InvalidFlag;

            testCase.verifyError( ...
                @() simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), release), ...
                "simcompare:ReleaseChecker:InvalidResponse");
        end

        function testExcludesDraftsAndPrereleases(testCase, ReleaseFlag)
            release = releaseResponse("v1.2.3");
            release.(ReleaseFlag) = true;

            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), release);

            testCase.verifyFalse(result.IsUpdateAvailable);
        end

        function testExcludesPrereleaseVersionEvenIfMarkedStable(testCase)
            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                matlab.mpm.Version("1.2.2"), releaseResponse("v1.3.0-rc.1"));

            testCase.verifyFalse(result.IsUpdateAvailable);
        end

        function testRequestsPublicGitHubReleaseWithoutCredentials(testCase)
            reader = @(url, options) verifyPublicRequest(testCase, url, options, 10);

            result = simcompare.Models.ReleaseChecker.checkForUpdate( ...
                matlab.mpm.Version("1.2.2"), ReleaseReader=reader);

            testCase.verifyTrue(result.IsUpdateAvailable);
        end

        function testForwardsCustomTimeout(testCase)
            reader = @(url, options) verifyPublicRequest(testCase, url, options, 3);

            release = simcompare.Models.ReleaseChecker.fetchLatestRelease( ...
                Timeout=3, ReleaseReader=reader);

            testCase.verifyEqual(release.tag_name, "v1.2.3");
        end

        function testRejectsInvalidTimeout(testCase, InvalidTimeout)
            reader = @(~, ~) releaseResponse("v1.2.3");

            testCase.verifyThat( ...
                @() simcompare.Models.ReleaseChecker.fetchLatestRelease( ...
                Timeout=InvalidTimeout, ReleaseReader=reader), ...
                matlab.unittest.constraints.Throws(?MException));
        end

        function testPropagatesRequestFailureToCaller(testCase)
            testCase.verifyError( ...
                @() simcompare.Models.ReleaseChecker.checkForUpdate( ...
                matlab.mpm.Version("1.2.2"), ReleaseReader=@failRequest), ...
                "testsupport:RequestFailed");
        end
    end
end

function release = releaseResponse(tag)
release = struct( ...
    "tag_name", tag, "name", tag, "draft", false, "prerelease", false, ...
    "html_url", ...
    "https://github.com/mathworks/Simulation-Comparison-App/releases/tag/" + tag);
end

function release = verifyPublicRequest(testCase, url, options, timeout)
testCase.verifyEqual(url, ...
    "https://api.github.com/repos/mathworks/Simulation-Comparison-App/releases/latest");
testCase.verifyEqual(string(options.HeaderFields), [ ...
    "Accept", "application/vnd.github+json"; ...
    "X-GitHub-Api-Version", "2022-11-28"]);
testCase.verifyEqual(string(options.UserAgent), "Simulation-Comparison-App");
testCase.verifyEqual(string(options.ContentType), "json");
testCase.verifyEqual(options.Timeout, timeout);
testCase.verifyEmpty(options.Username);
testCase.verifyEmpty(options.Password);
release = releaseResponse("v1.2.3");
end

function release = failRequest(~, ~)
release = struct.empty; %#ok<NASGU>
error("testsupport:RequestFailed", "Simulated request failure.");
end
