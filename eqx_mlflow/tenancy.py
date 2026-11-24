"""Mapping between Equanimo tenant IDs and MLflow workspace names.

Equanimo tenant IDs look like ``t_acme`` (see ``TENANT_ID_PATTERN`` in apc-auth-sdk).
MLflow workspace names follow Kubernetes naming rules and cannot contain underscores, so
``t_acme`` is stored as the workspace ``t-acme``. The mapping is reversible because tenant
IDs never contain hyphens.
"""

import re

from mlflow.exceptions import MlflowException
from mlflow.store.workspace.abstract_store import WorkspaceNameValidator

# Keep in sync with TENANT_ID_PATTERN in apc-auth-sdk/src/core/tenant.ts.
_TENANT_ID_PATTERN = re.compile(r"t_[a-z0-9_]+")


class InvalidTenantIdError(ValueError):
    pass


def tenant_id_to_workspace(tenant_id: str) -> str:
    if not isinstance(tenant_id, str) or not _TENANT_ID_PATTERN.fullmatch(tenant_id):
        raise InvalidTenantIdError(
            f"Invalid tenant id {tenant_id!r}: expected 't_' followed by lowercase "
            "letters, digits or underscores."
        )
    workspace = tenant_id.replace("_", "-")
    try:
        WorkspaceNameValidator.validate(workspace)
    except MlflowException as e:
        raise InvalidTenantIdError(
            f"Invalid tenant id {tenant_id!r}: it does not map to a valid workspace name. "
            f"{e.message}"
        ) from e
    return workspace


def workspace_to_tenant_id(workspace: str) -> str:
    tenant_id = workspace.replace("-", "_") if isinstance(workspace, str) else None
    try:
        if tenant_id is None or tenant_id_to_workspace(tenant_id) != workspace:
            raise InvalidTenantIdError(workspace)
    except InvalidTenantIdError as e:
        raise InvalidTenantIdError(
            f"Workspace {workspace!r} is not an Equanimo tenant workspace."
        ) from e
    return tenant_id
