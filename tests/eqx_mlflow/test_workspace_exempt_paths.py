import pytest

from mlflow.environment_variables import MLFLOW_ENABLE_WORKSPACES
from mlflow.exceptions import MlflowException
from mlflow.server import STATIC_PREFIX_ENV_VAR
from mlflow.server.workspace_helpers import resolve_workspace_for_request_if_enabled


@pytest.fixture
def resolutions(monkeypatch):
    """Record workspace resolutions, rejecting each one like a store that needs a header."""
    monkeypatch.setenv(MLFLOW_ENABLE_WORKSPACES.name, "true")
    calls = []

    def _reject(header_workspace):
        calls.append(header_workspace)
        raise MlflowException.invalid_parameter_value("Active workspace is required.")

    monkeypatch.setattr("mlflow.server.workspace_helpers.resolve_workspace_from_header", _reject)
    return calls


@pytest.mark.parametrize("path", ["/health", "/health/", "/version"])
def test_health_and_version_skip_workspace_resolution(path, resolutions):
    assert resolve_workspace_for_request_if_enabled(path, None) is None
    assert resolutions == []


@pytest.mark.parametrize(
    "path",
    [
        "/gateway/proxy/my-endpoint/health",
        "/gateway/proxy/my-endpoint/version",
        "/api/2.0/mlflow/experiments/health",
        "/healthz",
        "/health/details",
    ],
)
def test_other_paths_that_resemble_health_still_resolve_the_workspace(path, resolutions):
    with pytest.raises(MlflowException, match="Active workspace is required"):
        resolve_workspace_for_request_if_enabled(path, None)

    assert resolutions == [None]


def test_health_skip_honours_the_static_prefix(monkeypatch, resolutions):
    monkeypatch.setenv(STATIC_PREFIX_ENV_VAR, "/mlflow-ui/")

    assert resolve_workspace_for_request_if_enabled("/mlflow-ui/health", None) is None
    assert resolutions == []

    with pytest.raises(MlflowException, match="Active workspace is required"):
        resolve_workspace_for_request_if_enabled("/health", None)
