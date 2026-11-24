import pytest

from eqx_mlflow.workspace_store import TenantWorkspaceStore
from mlflow.exceptions import MlflowException
from mlflow.protos.databricks_pb2 import (
    INVALID_PARAMETER_VALUE,
    RESOURCE_DOES_NOT_EXIST,
    ErrorCode,
)
from mlflow.server import workspace_helpers
from mlflow.store.tracking.sqlalchemy_workspace_store import WorkspaceAwareSqlAlchemyStore
from mlflow.store.workspace.dbmodels import SqlWorkspace
from mlflow.tracking._tracking_service import utils as tracking_utils
from mlflow.utils.workspace_utils import DEFAULT_WORKSPACE_NAME

PATH = "/api/2.0/mlflow/experiments/search"


@pytest.fixture
def server_workspaces(db_uri, monkeypatch):
    """Configure the server's own request resolution to use the tenant workspace store."""
    monkeypatch.setenv("MLFLOW_ENABLE_WORKSPACES", "true")
    monkeypatch.setenv("MLFLOW_WORKSPACE_STORE_URI", f"eqx+{db_uri}")
    monkeypatch.setattr(workspace_helpers, "_workspace_store", None)

    store = TenantWorkspaceStore(db_uri)
    try:
        yield store
    finally:
        store._engine.dispose()
        server_store = workspace_helpers._workspace_store
        if server_store is not None:
            server_store._engine.dispose()


def _resolve(header):
    return workspace_helpers.resolve_workspace_for_request_if_enabled(PATH, header)


def _workspace_names(store):
    return {ws.name for ws in store.list_workspaces()}


def test_header_for_a_provisioned_tenant_resolves_to_its_workspace(server_workspaces):
    server_workspaces.ensure_tenant_workspace("t_acme")

    assert _resolve("t-acme").name == "t-acme"


def test_the_server_uses_the_tenant_workspace_store(server_workspaces):
    server_workspaces.ensure_tenant_workspace("t_acme")
    _resolve("t-acme")

    assert isinstance(workspace_helpers._workspace_store, TenantWorkspaceStore)


def test_header_for_an_unprovisioned_tenant_is_rejected_and_creates_nothing(server_workspaces):
    before = _workspace_names(server_workspaces)

    with pytest.raises(MlflowException, match="not found") as exc_info:
        _resolve("t-globex")

    assert exc_info.value.error_code == ErrorCode.Name(RESOURCE_DOES_NOT_EXIST)
    assert _workspace_names(server_workspaces) == before


@pytest.mark.parametrize("header", [None, "", "   "])
def test_request_without_a_workspace_header_is_rejected_rather_than_left_unscoped(
    server_workspaces, header
):
    with pytest.raises(MlflowException, match="explicit workspace") as exc_info:
        _resolve(header)

    assert exc_info.value.error_code == ErrorCode.Name(INVALID_PARAMETER_VALUE)


def test_header_naming_the_default_workspace_is_rejected(server_workspaces):
    with server_workspaces.ManagedSessionMaker(read_only=False) as session:
        if session.get(SqlWorkspace, DEFAULT_WORKSPACE_NAME) is None:
            session.add(SqlWorkspace(name=DEFAULT_WORKSPACE_NAME, description="Default"))

    with pytest.raises(MlflowException, match="does not exist") as exc_info:
        _resolve(DEFAULT_WORKSPACE_NAME)

    assert exc_info.value.error_code == ErrorCode.Name(RESOURCE_DOES_NOT_EXIST)


def test_header_naming_a_workspace_that_is_not_a_tenant_is_rejected(server_workspaces):
    with pytest.raises(MlflowException, match="does not exist") as exc_info:
        _resolve("team-a")

    assert exc_info.value.error_code == ErrorCode.Name(RESOURCE_DOES_NOT_EXIST)


def test_tracking_store_starts_with_the_tenant_workspace_store(server_workspaces, db_uri, tmp_path):
    store = tracking_utils._get_sqlalchemy_store(db_uri, tmp_path.as_uri())
    try:
        assert isinstance(store, WorkspaceAwareSqlAlchemyStore)
        assert isinstance(store._get_workspace_provider_instance(), TenantWorkspaceStore)
    finally:
        store._dispose_engine()
