classdef ExportProgressRecorder < handle
    %ExportProgressRecorder Capture plot-export progress callbacks.
    % Copyright 2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Indices double = zeros(0, 1)
        Counts double = zeros(0, 1)
        Fractions double = zeros(0, 1)
        Files string = strings(0, 1)
        FigureThemes string = strings(0, 1)
        SourceTileSpans double = zeros(0, 2)
        ErrorTileSpans double = zeros(0, 2)
        ErrorXGrids string = strings(0, 1)
        ErrorYGrids string = strings(0, 1)
        ErrorTitles string = strings(0, 1)
        ErrorYLabels string = strings(0, 1)
        ErrorDisplayNames string = strings(0, 1)
        ErrorYData cell = cell(0, 1)
        BaselineDisplayNames string = strings(0, 1)
        CompareDisplayNames string = strings(0, 1)
        LegendStrings cell = cell(0, 1)
        LegendTiles string = strings(0, 1)
    end

    methods
        function record(obj, index, count, filePath)
            obj.Indices(end + 1, 1) = index;
            obj.Counts(end + 1, 1) = count;
            obj.Fractions(end + 1, 1) = index / count;
            obj.Files(end + 1, 1) = string(filePath);
            figureHandle = gcf;
            obj.FigureThemes(end + 1, 1) = figureTheme(figureHandle);
            [sourceAxes, errorAxes] = exportAxes(figureHandle);
            obj.SourceTileSpans(end + 1, :) = ...
                sourceAxes.Layout.TileSpan;
            obj.ErrorTileSpans(end + 1, :) = ...
                errorAxes.Layout.TileSpan;
            obj.ErrorXGrids(end + 1, 1) = string(errorAxes.XGrid);
            obj.ErrorYGrids(end + 1, 1) = string(errorAxes.YGrid);
            obj.ErrorTitles(end + 1, 1) = ...
                string(errorAxes.Title.String);
            obj.ErrorYLabels(end + 1, 1) = ...
                string(errorAxes.YLabel.String);
            errorLine = findobj(errorAxes, "Type", "line");
            obj.ErrorDisplayNames(end + 1, 1) = ...
                string(errorLine.DisplayName);
            obj.ErrorYData{end + 1, 1} = errorLine.YData(:);
            baselineLine = findobj( ...
                sourceAxes, "Type", "line", "LineStyle", "-");
            compareLine = findobj( ...
                sourceAxes, "Type", "line", "LineStyle", "--");
            obj.BaselineDisplayNames(end + 1, 1) = ...
                string(baselineLine.DisplayName);
            obj.CompareDisplayNames(end + 1, 1) = ...
                string(compareLine.DisplayName);
            legendHandle = findobj(figureHandle, "Type", "legend");
            obj.LegendStrings{end + 1, 1} = ...
                string(legendHandle.String);
            obj.LegendTiles(end + 1, 1) = ...
                string(legendHandle.Layout.Tile);
        end
    end
end

function [sourceAxes, errorAxes] = exportAxes(figureHandle)
sourceAxes = findobj( ...
    figureHandle, "Type", "axes", "Tag", "ComparisonSourceAxes");
errorAxes = findobj( ...
    figureHandle, "Type", "axes", "Tag", "ComparisonErrorAxes");
end

function value = figureTheme(figureHandle)
theme = figureHandle.Theme;
if isprop(theme, "BaseColorStyle")
    value = string(theme.BaseColorStyle);
elseif isequal(figureHandle.Color, [1, 1, 1])
    value = "light";
else
    value = "dark";
end
end
