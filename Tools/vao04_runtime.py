#!/usr/bin/env python3
"""Deterministic, declarative VAO 0.4.0 interaction reference interpreter."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


@dataclass
class PCG32:
    state: int
    increment: int

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "PCG32":
        seed = int(record["seed"], 16) & ((1 << 64) - 1)
        stream = int(record["stream"])
        generator = cls(0, ((stream << 1) | 1) & ((1 << 64) - 1))
        generator.next_uint32()
        generator.state = (generator.state + seed) & ((1 << 64) - 1)
        generator.next_uint32()
        return generator

    def next_uint32(self) -> int:
        old = self.state
        self.state = (old * 6364136223846793005 + self.increment) & ((1 << 64) - 1)
        xorshifted = (((old >> 18) ^ old) >> 27) & 0xFFFFFFFF
        rotation = (old >> 59) & 31
        return ((xorshifted >> rotation) | (xorshifted << ((-rotation) & 31))) & 0xFFFFFFFF

    def uniform(self) -> float:
        return self.next_uint32() / 4294967296.0


def condition_matches(condition: dict[str, Any], state: dict[str, Any]) -> bool:
    actual = state.get(condition["stateVariableId"])
    expected = condition.get("value")
    operation = condition["operator"]
    if operation == "equals": return actual == expected
    if operation == "not-equals": return actual != expected
    if operation == "less-than": return actual is not None and actual < expected
    if operation == "less-or-equal": return actual is not None and actual <= expected
    if operation == "greater-than": return actual is not None and actual > expected
    if operation == "greater-or-equal": return actual is not None and actual >= expected
    if operation == "contains": return isinstance(actual, (list, str)) and expected in actual
    return False


class RuntimeError04(ValueError):
    pass


class Interpreter:
    def __init__(self, manifest: dict[str, Any]):
        self.manifest = manifest
        self.model = manifest.get("interactionModel") or {}
        self.runtime = manifest["runtime"]
        self.semantics = self.runtime["executionSemantics"]
        self.events = {x["id"]: x for x in self.model.get("eventTypes", [])}
        self.transitions = sorted(self.model.get("transitions", []), key=lambda x: (-x.get("priority", 0), x["id"]))
        self.processes = {x["id"]: x for x in self.model.get("processModels", [])}
        self.routes = {x["id"]: x for x in self.model.get("routingRules", [])}
        self.renders = self.model.get("renderBindings", [])
        random_records = {x["id"]: x for x in self.runtime.get("randomSources", [])}
        random_records.update({x["id"]: x for x in self.model.get("randomSources", [])})
        self.random = {key: PCG32.from_record(value) for key, value in random_records.items() if value["algorithm"] == "pcg32"}
        self.maximum_microsteps = self.semantics.get("maximumMicrosteps", 10_000)

    def initial_state(self, override: dict[str, Any] | None = None) -> dict[str, Any]:
        state = {record["id"]: record["defaultValue"] for record in self.model.get("stateVariables", [])}
        state.update(override or {})
        return state

    def _process_actions(self, process: dict[str, Any]) -> list[dict[str, Any]]:
        actions = list(process.get("actions", []))
        for child in process.get("childProcessIds", []):
            actions.extend(self._process_actions(self.processes[child]))
        if process.get("processKind") != "stochastic":
            return actions
        generator = self.random.get(process.get("randomSourceId"))
        if generator is None:
            raise RuntimeError04(f"Missing reproducible random source for {process['id']}")
        distribution = process["probabilityDistribution"]
        if distribution["kind"] == "categorical":
            weights = [distribution["parameters"].get(str(index), 0.0) for index in range(len(actions))]
            total = sum(weights)
            if total <= 0:
                raise RuntimeError04(f"Categorical process {process['id']} has no positive weight")
            threshold = generator.uniform() * total
            running = 0.0
            for action, weight in zip(actions, weights):
                running += weight
                if threshold < running:
                    return [action]
            return [actions[-1]]
        index = min(int(generator.uniform() * len(actions)), len(actions) - 1)
        return [actions[index]]

    def execute(self, events: list[dict[str, Any]], initial_state: dict[str, Any] | None = None) -> dict[str, Any]:
        state = self.initial_state(initial_state)
        emitted: list[dict[str, Any]] = []
        selected: list[str] = []
        ordered = sorted(events, key=lambda event: (
            event["timestamp"], -event.get("priority", 0), event["eventTypeId"], event["sequence"]
        ))
        microsteps = 0
        for event in ordered:
            snapshot = dict(state)
            matching = [transition for transition in self.transitions
                        if transition["eventTypeId"] == event["eventTypeId"]
                        and (transition.get("controlId") is None or transition.get("controlId") == event.get("controlId"))
                        and all(condition_matches(c, snapshot) for c in transition.get("conditions", []))]
            writes: dict[str, Any] = {}
            actions: list[tuple[str, int, dict[str, Any], dict[str, Any]]] = []
            for transition in matching:
                for index, action in enumerate(transition["actions"]):
                    actions.append((action.get("executionGroup", ""), index, action, transition))
            for _, _, action, transition in sorted(actions, key=lambda item: (item[0], item[1], item[3]["id"])):
                microsteps += 1
                if microsteps > self.maximum_microsteps:
                    raise RuntimeError04("maximumMicrosteps exceeded")
                operation, target = action["operation"], action["targetId"]
                if operation in {"set-state", "toggle-state", "increment-state"}:
                    current = writes.get(target, snapshot.get(target))
                    value = action.get("value")
                    if operation == "toggle-state": value = not bool(current)
                    if operation == "increment-state": value = current + value
                    if target in writes and writes[target] != value and transition.get("conflictPolicy") == "reject":
                        raise RuntimeError04(f"Rejected conflicting write to {target}")
                    writes[target] = value
                elif operation == "emit-event":
                    emitted.append({"eventTypeId": target, "timestamp": event["timestamp"], "sourceTransitionId": transition["id"]})
                elif operation == "route-event":
                    emitted.append({"routeId": target, "timestamp": event["timestamp"], "sourceTransitionId": transition["id"]})
                elif operation == "start-process":
                    for process_action in self._process_actions(self.processes[target]):
                        emitted.append({"processId": target, "operation": process_action["operation"], "targetId": process_action["targetId"], "timestamp": event["timestamp"]})
                elif operation == "select-render-binding":
                    selected.append(target)
            state.update(writes)
            for binding in self.renders:
                if binding.get("eventTypeId") not in (None, event["eventTypeId"]): continue
                if all(condition_matches(c, state) for c in binding.get("conditions", [])):
                    selected.append(binding["id"])
        result = {
            "state": state,
            "emittedEvents": emitted,
            "renderBindingIds": list(dict.fromkeys(selected)),
        }
        return result


def trace_digest(initial_state: dict[str, Any], input_events: list[dict[str, Any]], expected: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_bytes({"initialState": initial_state, "inputEvents": input_events, "expected": expected})).hexdigest()


def verify_trace(manifest: dict[str, Any], trace: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    expected_digest = trace_digest(trace.get("initialState", {}), trace["inputEvents"], trace["expected"])
    digest = trace["digest"]
    if digest["algorithm"] != "sha256" or digest["value"] != expected_digest:
        errors.append(f"Conformance trace {trace['id']} has a non-canonical digest.")
    try:
        actual = Interpreter(manifest).execute(trace["inputEvents"], trace.get("initialState"))
    except (KeyError, TypeError, RuntimeError04) as exc:
        errors.append(f"Conformance trace {trace['id']} cannot execute: {exc}")
        return errors
    if actual != trace["expected"]:
        errors.append(f"Conformance trace {trace['id']} does not match deterministic execution.")
    return errors
