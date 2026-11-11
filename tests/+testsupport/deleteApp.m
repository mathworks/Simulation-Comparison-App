function deleteApp(app)
%deleteApp Delete all live handles returned by the app entry point.
% Copyright 2026 The MathWorks, Inc.

if isfield(app, "view") && isvalid(app.view)
    delete(app.view);
end
if isfield(app, "viewModel") && isvalid(app.viewModel)
    delete(app.viewModel);
end
if isfield(app, "model") && isvalid(app.model)
    delete(app.model);
end
end
