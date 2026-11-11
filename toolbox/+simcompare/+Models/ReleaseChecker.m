classdef ReleaseChecker
    %ReleaseChecker - Check the latest published GitHub release

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant, Access = private)
        LatestReleaseURL = ...
            "https://api.github.com/repos/mathworks/" + ...
            "Simulation-Comparison-App/releases/latest"
        ReleasePagePrefix = ...
            "https://github.com/mathworks/Simulation-Comparison-App/releases/tag/"
    end

    methods (Static)
        function result = isDevelopmentVersion(version)
            %isDevelopmentVersion - Identify the development version
            %   TF = isDevelopmentVersion(VERSION) returns true for 0.0.0.

            arguments
                version (1, 1) matlab.mpm.Version
            end

            result = version == matlab.mpm.Version("0.0.0");
        end

        function result = checkForUpdate(currentVersion, options)
            %checkForUpdate - Fetch and compare the latest GitHub release
            %   RESULT = checkForUpdate(currentVersion) checks whether the
            %   latest stable release is newer than currentVersion.
            %
            %   RESULT = checkForUpdate(...,Timeout=SECONDS) sets the request
            %   timeout. The default is 10 seconds.
            %
            %   RESULT = checkForUpdate(...,ReleaseReader=READER) uses READER
            %   instead of WEBREAD to fetch release metadata.

            arguments
                currentVersion (1, 1) matlab.mpm.Version
                options.Timeout (1, 1) {mustBeNumeric, mustBeReal, ...
                    mustBeFinite, mustBePositive} = 10
                options.ReleaseReader (1, 1) function_handle = @webread
            end

            release = simcompare.Models.ReleaseChecker.fetchLatestRelease( ...
                Timeout=options.Timeout, ...
                ReleaseReader=options.ReleaseReader);
            result = simcompare.Models.ReleaseChecker.compareRelease( ...
                currentVersion, release);
        end

        function release = fetchLatestRelease(options)
            %fetchLatestRelease - Fetch public GitHub release metadata
            %   RELEASE = fetchLatestRelease() fetches the latest published
            %   release without authentication.
            %
            %   RELEASE = fetchLatestRelease(Timeout=SECONDS) sets the request
            %   timeout. The default is 10 seconds.
            %
            %   RELEASE = fetchLatestRelease(ReleaseReader=READER) uses READER
            %   instead of WEBREAD to fetch release metadata.

            arguments
                options.Timeout (1, 1) {mustBeNumeric, mustBeReal, ...
                    mustBeFinite, mustBePositive} = 10
                options.ReleaseReader (1, 1) function_handle = @webread
            end

            requestOptions = weboptions( ...
                HeaderFields=[ ...
                    "Accept", "application/vnd.github+json"; ...
                    "X-GitHub-Api-Version", "2022-11-28"], ...
                UserAgent="Simulation-Comparison-App", ...
                ContentType="json", ...
                Timeout=options.Timeout);
            release = options.ReleaseReader( ...
                simcompare.Models.ReleaseChecker.LatestReleaseURL, ...
                requestOptions);
        end

        function result = compareRelease(currentVersion, release)
            %compareRelease - Validate and compare GitHub release metadata
            %   RESULT = compareRelease(currentVersion,RELEASE) compares the
            %   release tag with currentVersion using semantic versions.
            %   Drafts and prereleases never indicate an available update.

            arguments
                currentVersion (1, 1) matlab.mpm.Version
                release (1, 1) struct
            end

            requiredFields = ["tag_name", "html_url", "draft", "prerelease"];
            if ~all(isfield(release, requiredFields)) || ...
                    ~isTextScalar(release.tag_name) || ...
                    ~isTextScalar(release.html_url) || ...
                    ~islogical(release.draft) || ~isscalar(release.draft) || ...
                    ~islogical(release.prerelease) || ...
                    ~isscalar(release.prerelease)
                error("simcompare:ReleaseChecker:InvalidResponse", ...
                    "The GitHub release response has invalid required fields.");
            end

            tag = string(release.tag_name);
            versionText = tag;
            if startsWith(versionText, "v")
                versionText = extractAfter(versionText, 1);
            end
            if isempty(regexp(versionText, "^\d+\.\d+\.\d+(?:[-+].+)?$", "once"))
                error("simcompare:ReleaseChecker:InvalidResponse", ...
                    "The GitHub release tag is not a semantic version.");
            end
            try
                latestVersion = matlab.mpm.Version(versionText);
            catch
                error("simcompare:ReleaseChecker:InvalidResponse", ...
                    "The GitHub release tag is not a semantic version.");
            end
            releaseURL = string(release.html_url);
            prefix = simcompare.Models.ReleaseChecker.ReleasePagePrefix;
            if ~startsWith(releaseURL, prefix) || ...
                    strlength(releaseURL) <= strlength(prefix) || ...
                    ~isempty(regexp(releaseURL, "\s", "once"))
                error("simcompare:ReleaseChecker:InvalidResponse", ...
                    "The GitHub release response has an invalid release URL.");
            end
            releaseName = tag;
            if isfield(release, "name") && isTextScalar(release.name)
                releaseName = string(release.name);
            end

            result = struct( ...
                "IsUpdateAvailable", ~release.draft && ...
                ~release.prerelease && isempty(latestVersion.Prerelease) && ...
                latestVersion > currentVersion, ...
                "CurrentVersion", currentVersion, ...
                "LatestVersion", latestVersion, ...
                "ReleaseName", releaseName, ...
                "ReleaseURL", releaseURL);
        end
    end
end

function result = isTextScalar(value)
result = ((isstring(value) && isscalar(value)) || ...
    (ischar(value) && isrow(value))) && ...
    ~ismissing(string(value)) && strlength(string(value)) > 0;
end
