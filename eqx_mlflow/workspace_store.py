from __future__ import annotations

from eqx_mlflow.tenancy import (
    InvalidTenantIdError,
    tenant_id_to_workspace,
    workspace_to_tenant_id,
)
from mlflow.entities.workspace import Workspace
from mlflow.exceptions import MlflowException
from mlflow.protos.databricks_pb2 import (
    RESOURCE_ALREADY_EXISTS,
    RESOURCE_DOES_NOT_EXIST,
    ErrorCode,
)
from mlflow.store.db.db_types import DATABASE_ENGINES
from mlflow.store.workspace.sqlalchemy_store import SqlAlchemyStore

_EQX_SCHEME_PREFIX = "eqx+"

# One entry point per scheme: MLflow selects a workspace provider by the exact URI scheme, so
# a driver suffix such as ``eqx+postgresql+psycopg2`` is not selectable. Point
# ``MLFLOW_WORKSPACE_STORE_URI`` at e.g. ``eqx+postgresql://...``; without it MLflow falls back
# to the plain tracking URI and uses its default workspace store.
WORKSPACE_PROVIDER_SCHEMES = tuple(f"{_EQX_SCHEME_PREFIX}{engine}" for engine in DATABASE_ENGINES)


class TenantWorkspaceStore(SqlAlchemyStore):
    """Workspace store where every workspace belongs to an Equanimo tenant."""

    def ensure_tenant_workspace(self, tenant_id: str) -> Workspace:
        """Return the tenant's workspace, creating it on first use."""
        name = tenant_id_to_workspace(tenant_id)
        try:
            return self.get_workspace(name)
        except MlflowException as e:
            if e.error_code != ErrorCode.Name(RESOURCE_DOES_NOT_EXIST):
                raise
        try:
            return self.create_workspace(Workspace(name=name))
        except MlflowException as e:
            if e.error_code != ErrorCode.Name(RESOURCE_ALREADY_EXISTS):
                raise
            return self.get_workspace(name)

    def create_workspace(self, workspace: Workspace) -> Workspace:
        try:
            workspace_to_tenant_id(workspace.name)
        except InvalidTenantIdError as e:
            raise MlflowException.invalid_parameter_value(str(e)) from e
        return super().create_workspace(workspace)

    def get_workspace(self, workspace_name: str) -> Workspace:
        # Only tenant workspaces are visible to requests. Without this, a request naming the
        # shared ``default`` workspace in its workspace header would resolve successfully.
        # ``mlflow db move-workspace`` also reads through this store; to move data out of
        # ``default`` into a tenant, run it with MLFLOW_WORKSPACE_STORE_URI unset.
        try:
            workspace_to_tenant_id(workspace_name)
        except InvalidTenantIdError:
            raise MlflowException(
                f"Workspace {workspace_name!r} does not exist.", RESOURCE_DOES_NOT_EXIST
            ) from None
        return super().get_workspace(workspace_name)

    def get_default_workspace(self) -> Workspace:
        raise MlflowException.invalid_parameter_value(
            "Requests must specify an explicit workspace; there is no default tenant workspace."
        )


def build_tenant_workspace_store(workspace_uri: str) -> TenantWorkspaceStore:
    """Registry builder for ``eqx+<database>://`` workspace store URIs."""
    if not workspace_uri.startswith(_EQX_SCHEME_PREFIX):
        raise MlflowException.invalid_parameter_value(
            f"Workspace store URI must start with 'eqx+<database>://' to use the Equanimo "
            f"tenant workspace store, e.g. 'eqx+postgresql://...'; got a URI with scheme "
            f"{workspace_uri.split(':', 1)[0]!r}."
        )
    return TenantWorkspaceStore(workspace_uri[len(_EQX_SCHEME_PREFIX) :])
