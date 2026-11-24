from __future__ import annotations

import enum
from collections.abc import Mapping
from dataclasses import dataclass


class InvalidSettingError(ValueError):
    pass


class EventPublisherMode(str, enum.Enum):
    NONE = "none"
    LOG = "log"
    KINESIS = "kinesis"


class BudgetSourceMode(str, enum.Enum):
    NONE = "none"
    FILE = "file"
    COST_EXPLORER = "cost_explorer"


class PolicyActionsMode(str, enum.Enum):
    NONE = "none"
    SQS = "sqs"


class AuthMode(str, enum.Enum):
    BASIC = "basic"
    EQUANIMO = "equanimo"


_TRUE_VALUES = {"true", "1"}
_FALSE_VALUES = {"false", "0", ""}


def _parse_bool(name: str, env: Mapping[str, str]) -> bool:
    value = env.get(name, "").strip().lower()
    if value in _TRUE_VALUES:
        return True
    if value in _FALSE_VALUES:
        return False
    raise InvalidSettingError(f"{name} must be one of true, false, 1, 0; got {env[name]!r}.")


def _parse_enum(name: str, enum_cls: type[enum.Enum], env: Mapping[str, str], default):
    value = env.get(name, "").strip().lower()
    if not value:
        return default
    try:
        return enum_cls(value)
    except ValueError:
        allowed = ", ".join(member.value for member in enum_cls)
        raise InvalidSettingError(f"{name} must be one of: {allowed}; got {env[name]!r}.") from None


def _parse_replicas(name: str, env: Mapping[str, str]) -> int:
    raw = env.get(name, "").strip()
    if not raw:
        return 1
    try:
        value = int(raw)
    except ValueError:
        value = 0
    if value < 1:
        raise InvalidSettingError(f"{name} must be a positive integer; got {env[name]!r}.")
    return value


@dataclass(frozen=True)
class EqxSettings:
    tenancy_enabled: bool = False
    usage_ledger_enabled: bool = False
    event_publisher: EventPublisherMode = EventPublisherMode.NONE
    budget_source: BudgetSourceMode = BudgetSourceMode.NONE
    policy_actions: PolicyActionsMode = PolicyActionsMode.NONE
    auth_mode: AuthMode = AuthMode.BASIC
    expected_replicas: int = 1

    @classmethod
    def from_env(cls, env: Mapping[str, str]) -> EqxSettings:
        settings = cls(
            tenancy_enabled=_parse_bool("EQX_TENANCY_ENABLED", env),
            usage_ledger_enabled=_parse_bool("EQX_USAGE_LEDGER_ENABLED", env),
            event_publisher=_parse_enum(
                "EQX_EVENT_PUBLISHER", EventPublisherMode, env, EventPublisherMode.NONE
            ),
            budget_source=_parse_enum(
                "EQX_BUDGET_SOURCE", BudgetSourceMode, env, BudgetSourceMode.NONE
            ),
            policy_actions=_parse_enum(
                "EQX_POLICY_ACTIONS", PolicyActionsMode, env, PolicyActionsMode.NONE
            ),
            auth_mode=_parse_enum("EQX_AUTH_MODE", AuthMode, env, AuthMode.BASIC),
            expected_replicas=_parse_replicas("EQX_EXPECTED_REPLICAS", env),
        )
        if (
            settings.event_publisher is not EventPublisherMode.NONE
            and not settings.usage_ledger_enabled
        ):
            raise InvalidSettingError(
                "EQX_EVENT_PUBLISHER publishes events from the usage ledger, so it requires "
                "EQX_USAGE_LEDGER_ENABLED=true."
            )
        return settings
