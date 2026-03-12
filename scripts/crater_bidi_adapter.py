"""
Crater BiDi Adapter for WPT WebDriver BiDi Tests

This adapter allows running WPT WebDriver BiDi tests directly against
Crater's BiDi server implementation.

Usage:
    pytest wpt/webdriver/tests/bidi/session/status/ \
        --confcutdir=. \
        -p scripts.crater_bidi_adapter
"""

import asyncio
import base64
import copy
import functools
import json
import math
import os
import subprocess
import sys
import time
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Mapping
import pytest
import pytest_asyncio
import websockets
from webdriver.error import TimeoutException
import webdriver.bidi.error as bidi_error
from webdriver.bidi.modules.script import ContextTarget, ScriptEvaluateResultException
from tests.support.helpers import deep_update


CRATER_BIDI_URL = os.environ.get("CRATER_BIDI_URL", "ws://127.0.0.1:9222")
_UNSET = object()
_REPO_ROOT = Path(__file__).resolve().parent.parent


def _base64_text_from_any(value: str | bytes | bytearray) -> str:
    if isinstance(value, (bytes, bytearray)):
        return base64.b64encode(bytes(value)).decode("ascii")
    return str(value)


@functools.lru_cache(maxsize=1)
def _chrome_extension_data() -> dict[str, Any]:
    extension_root = (
        _REPO_ROOT
        / "wpt"
        / "webdriver"
        / "tests"
        / "support"
        / "webextensions"
        / "chrome"
    )
    archive_path = extension_root / "packed.crx"
    return {
        "id": None,
        "path": str(extension_root / "unpacked"),
        "archivePath": str(archive_path),
        "archivePathInvalid": str(extension_root / "invalid"),
        "base64": base64.b64encode(archive_path.read_bytes()).decode("ascii"),
    }


class CraterBidiSession:
    """
    WebSocket-based BiDi session that connects directly to Crater's BiDi server.
    Implements the interface expected by WPT tests.
    """

    def __init__(self, url: str):
        self.url = url
        self._ws = None
        self._command_id = 0
        self._pending_commands = {}
        self._pending_print_commands: dict[int, str] = {}
        self._event_listeners = {}
        self._event_backlog = {}
        self._receive_task = None
        self.event_loop = None
        self._trace_enabled = os.environ.get("CRATER_BIDI_TRACE", "0") == "1"

        # Module proxies (lazily initialized)
        self._browsing_context = None
        self._session_module = None
        self._script = None
        self._network = None
        self._storage = None
        self._input = None
        self._browser = None
        self._emulation = None
        self._bluetooth = None
        self._permissions = None
        self._web_extension = None

    def _trace(self, message: str):
        if self._trace_enabled:
            print(f"[bidi] {message}", flush=True)

    async def start(self):
        """Establish WebSocket connection to the BiDi server."""
        self._ws = await websockets.connect(self.url)
        self.event_loop = asyncio.get_event_loop()
        self._receive_task = asyncio.create_task(self._receive_messages())

    async def end(self):
        """Close the WebSocket connection."""
        if self._receive_task:
            self._receive_task.cancel()
            try:
                await self._receive_task
            except asyncio.CancelledError:
                pass
        if self._ws:
            await self._ws.close()
            await self._ws.wait_closed()
            self._ws = None

    async def _receive_messages(self):
        """Receive and dispatch messages from the server."""
        try:
            async for message in self._ws:
                data = json.loads(message)
                if "id" in data:
                    # Command response
                    cmd_id = data["id"]
                    response_type = data.get("type", "success")
                    self._trace(f"<- #{cmd_id} {response_type}")
                    if cmd_id in self._pending_commands:
                        future = self._pending_commands.pop(cmd_id)
                        if data.get("type") == "error":
                            # Convert BiDi error to proper exception
                            error_code = data.get("error", "unknown error")
                            error_msg = data.get("message", "Unknown error")
                            stacktrace = data.get("stacktrace", "")
                            exc = bidi_error.from_error_details(error_code, error_msg, stacktrace)
                            future.set_exception(exc)
                        else:
                            future.set_result(data.get("result", {}))
                        self._pending_print_commands.pop(cmd_id, None)
                else:
                    # Event
                    method = data.get("method")
                    if method:
                        params = data.get("params", {})
                        if self._trace_enabled and method in (
                            "script.realmCreated",
                            "script.realmDestroyed",
                        ):
                            self._trace(
                                f"<- event {method} {json.dumps(params, sort_keys=True)}"
                            )
                        else:
                            self._trace(f"<- event {method}")
                        if method not in self._event_backlog:
                            self._event_backlog[method] = []
                        self._event_backlog[method].append(params)
                    if method and method in self._event_listeners:
                        for handler in self._event_listeners[method]:
                            try:
                                await handler(method, params)
                            except Exception as e:
                                print(f"Event handler error: {e}")
        except websockets.exceptions.ConnectionClosed:
            self._trace("receive loop closed")
            pass
        except asyncio.CancelledError:
            self._trace("receive loop cancelled")
            pass
        except Exception as e:
            self._trace(f"receive loop exception: {e}")

    async def send_command(self, method: str, params: Mapping[str, Any]) -> asyncio.Future:
        """Send a BiDi command and return a future for the response."""
        self._command_id += 1
        cmd_id = self._command_id

        normalized_params = self._normalize_params(params)
        if method == "browsingContext.print" and isinstance(normalized_params, Mapping):
            context_id = normalized_params.get("context")
            if isinstance(context_id, str):
                self._pending_print_commands[cmd_id] = context_id
        message = json.dumps({
            "id": cmd_id,
            "method": method,
            "params": normalized_params
        })

        future = self.event_loop.create_future()
        self._pending_commands[cmd_id] = future

        self._trace(f"-> #{cmd_id} {method}")
        await self._ws.send(message)
        return future

    async def command(self, method: str, params: Mapping[str, Any] | None = None):
        future = await self.send_command(method, {} if params is None else params)
        return await future

    def clear_event_backlog(self, event_name: str) -> None:
        self._event_backlog[event_name] = []

    def clear_all_event_backlog(self) -> None:
        self._event_backlog.clear()

    def consume_latest_event_backlog(self, event_name: str):
        backlog = self._event_backlog.get(event_name, [])
        if not backlog:
            return None
        latest = backlog[-1]
        self._event_backlog[event_name] = []
        return latest

    def listen_once(self, event_name: str, *, accept_latest_backlog: bool = False):
        loop = asyncio.get_running_loop()
        future = loop.create_future()

        if accept_latest_backlog:
            latest = self.consume_latest_event_backlog(event_name)
            if latest is not None:
                future.set_result(latest)
                return future, (lambda: None)

        # Match WPT expectation: observe events after listener registration.
        self.clear_event_backlog(event_name)

        remove_ref = None

        async def on_event(_, data):
            if future.done():
                return
            if remove_ref is not None:
                remove_ref()
            future.set_result(data)

        remove_ref = self.add_event_listener(event_name, on_event)
        return future, remove_ref

    def listen_many(self, event_names, handler):
        remove_listeners = []
        for event_name in event_names:
            remove_listener = self.add_event_listener(event_name, handler)
            remove_listeners.append(remove_listener)

        def remove_all():
            for remove_listener in remove_listeners:
                remove_listener()
            remove_listeners.clear()

        return remove_all

    def collect_events(self, event_names, *, timeout_multiplier: float = 1.0):
        return _BiDiEventCollector(self, event_names, timeout_multiplier)

    def capture_named_events(self, event_names):
        buffer = _BiDiNamedEventBuffer(self, event_names)
        buffer.start()
        return buffer

    def track_subscriptions(self):
        return _BiDiSubscriptionTracker(self)

    def fail_pending_print_requests_for_context(self, context_id: str) -> None:
        if not isinstance(context_id, str) or context_id == "":
            return
        to_fail = [
            cmd_id
            for cmd_id, print_context in self._pending_print_commands.items()
            if print_context == context_id
        ]
        for cmd_id in to_fail:
            self._pending_print_commands.pop(cmd_id, None)
            future = self._pending_commands.pop(cmd_id, None)
            if future is not None and not future.done():
                future.set_exception(
                    bidi_error.UnknownErrorException(
                        "Printing failed because the browsing context was closed"
                    )
                )

    def _normalize_params(self, value: Any):
        """Normalize params for JSON transport.

        webdriver's UNDEFINED sentinel is represented by omitting map keys.
        """
        if hasattr(value, "to_json"):
            return self._normalize_params(value.to_json())
        if hasattr(value, "to_dict"):
            return self._normalize_params(value.to_dict())
        if isinstance(value, Mapping):
            out = {}
            for k, v in value.items():
                if self._is_undefined(v):
                    continue
                out[k] = self._normalize_params(v)
            return out
        if isinstance(value, (list, tuple)):
            out = []
            for item in value:
                if self._is_undefined(item):
                    out.append(None)
                else:
                    out.append(self._normalize_params(item))
            return out
        if hasattr(value, "__dict__") and not isinstance(value, type):
            public_fields = {
                key: field_value
                for key, field_value in value.__dict__.items()
                if not key.startswith("_")
            }
            return self._normalize_params(public_fields)
        return value

    def _is_undefined(self, value: Any) -> bool:
        cls = value.__class__
        return cls.__name__ == "Undefined" and cls.__module__.endswith("webdriver.bidi.undefined")

    async def is_known_context(self, context_id: str) -> bool:
        if not isinstance(context_id, str) or context_id == "":
            return False
        return bool(
            await self.command(
                "browsingContext.isKnownContext",
                {"context": context_id},
            )
        )

    async def has_user_context(self, user_context: str) -> bool:
        if not isinstance(user_context, str) or user_context == "":
            return False
        return bool(
            await self.command(
                "browser.hasUserContextValue",
                {"userContext": user_context},
            )
        )

    async def remember_document_cookie(self, context_id: str, cookie_assignment: str) -> None:
        if not isinstance(context_id, str) or not isinstance(cookie_assignment, str):
            return
        future = await self.send_command("storage.rememberDocumentCookie", {
            "context": context_id,
            "cookie": cookie_assignment,
        })
        await future

    async def blocked_request_phase(self, request_id: str) -> str | None:
        if not isinstance(request_id, str) or request_id == "":
            return None
        result = await self.command(
            "network.getBlockedRequestPhaseValue",
            {"request": request_id},
        )
        return result if isinstance(result, str) else None

    async def blocked_request_navigation(self, request_id: str) -> str | None:
        if not isinstance(request_id, str) or request_id == "":
            return None
        result = await self.command(
            "network.getBlockedRequestNavigationValue",
            {"request": request_id},
        )
        return result if isinstance(result, str) else None

    def add_event_listener(self, event_name: str, handler):
        """Add an event listener."""
        if event_name not in self._event_listeners:
            self._event_listeners[event_name] = []
        self._event_listeners[event_name].append(handler)

        def remove():
            if handler in self._event_listeners.get(event_name, []):
                self._event_listeners[event_name].remove(handler)

        return remove

    def latest_navigation_id_for_context(self, context_id: str) -> str | None:
        if not isinstance(context_id, str):
            return None
        queue = self._event_backlog.get("browsingContext.navigationStarted", [])
        if not isinstance(queue, list):
            return None
        for event in reversed(queue):
            if not isinstance(event, Mapping):
                continue
            if event.get("context") != context_id:
                continue
            candidate = event.get("navigation")
            if isinstance(candidate, str):
                return candidate
        return None

    @property
    def browsing_context(self):
        if self._browsing_context is None:
            self._browsing_context = BrowsingContextModule(self)
        return self._browsing_context

    @property
    def session(self):
        if self._session_module is None:
            self._session_module = SessionModule(self)
        return self._session_module

    @property
    def script(self):
        if self._script is None:
            self._script = ScriptModule(self)
        return self._script

    @property
    def network(self):
        if self._network is None:
            self._network = NetworkModule(self)
        return self._network

    @property
    def storage(self):
        if self._storage is None:
            self._storage = StorageModule(self)
        return self._storage

    @property
    def input(self):
        if self._input is None:
            self._input = InputModule(self)
        return self._input

    @property
    def browser(self):
        if self._browser is None:
            self._browser = BrowserModule(self)
        return self._browser

    @property
    def emulation(self):
        if self._emulation is None:
            self._emulation = EmulationModule(self)
        return self._emulation

    @property
    def bluetooth(self):
        if self._bluetooth is None:
            self._bluetooth = BluetoothModule(self)
        return self._bluetooth

    @property
    def permissions(self):
        if self._permissions is None:
            self._permissions = PermissionsModule(self)
        return self._permissions

    @property
    def web_extension(self):
        if self._web_extension is None:
            self._web_extension = WebExtensionModule(self)
        return self._web_extension


class _BiDiEventCollector:
    def __init__(self, session: CraterBidiSession, event_names, timeout_multiplier: float):
        self._session = session
        self._event_names = list(event_names)
        self._timeout_multiplier = timeout_multiplier
        self._remove_all = None
        self.events = []

    async def get_events(self, predicate, timeout: float = 2.0):
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout * self._timeout_multiplier
        while True:
            if predicate(self.events):
                return self.events
            if loop.time() >= deadline:
                raise TimeoutException("Timed out waiting for expected events")
            await asyncio.sleep(0.01)

    def __enter__(self):
        async def on_event(method, data):
            self.events.append((method, data))

        self._remove_all = self._session.listen_many(self._event_names, on_event)
        return self

    def __exit__(self, *args):
        if self._remove_all is not None:
            self._remove_all()
            self._remove_all = None


class _BiDiNamedEventBuffer:
    def __init__(self, session: CraterBidiSession, event_names):
        self._session = session
        self._event_names = list(event_names)
        self._remove_all = None
        self.events = {event_name: [] for event_name in self._event_names}

    def start(self):
        async def on_event(method, data):
            if method not in self.events:
                self.events[method] = []
            self.events[method].append(data)

        self._remove_all = self._session.listen_many(self._event_names, on_event)
        return self.events

    def close(self):
        if self._remove_all is not None:
            self._remove_all()
            self._remove_all = None


class _BiDiSubscriptionTracker:
    def __init__(self, session: CraterBidiSession):
        self._session = session
        self._subscriptions = []

    def add(self, subscription_id):
        if isinstance(subscription_id, str) and subscription_id != "":
            self._subscriptions.append(subscription_id)

    async def close(self):
        if not self._subscriptions:
            return
        for subscription_id in reversed(self._subscriptions):
            try:
                await self._session.session.unsubscribe(subscriptions=[subscription_id])
            except Exception:
                pass
        self._subscriptions.clear()


def _require_context_info(value: Any, source: str):
    if isinstance(value, Mapping) and isinstance(value.get("context"), str):
        return value
    raise bidi_error.UnknownErrorException(f"{source} returned invalid context info")


def _context_id(context):
    return context.get("context") if isinstance(context, Mapping) else context


def _current_platform_name() -> str:
    if sys.platform == "darwin":
        return "mac"
    if sys.platform.startswith("win"):
        return "windows"
    return "linux"


def _fixture_default_capabilities():
    return {}


def _fixture_capabilities_for_request(request, default_capabilities):
    marker = request.node.get_closest_marker("capabilities")
    if marker and marker.args:
        assert isinstance(
            marker.args[0], dict
        ), "capabilities marker must use a dictionary"
        caps = copy.deepcopy(default_capabilities)
        deep_update(caps, marker.args[0])
        return caps
    return default_capabilities


class _CommandProxy:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def _command(self, method: str, params: Mapping[str, Any] | None = None):
        return await self._session.command(method, {} if params is None else params)


class BrowsingContextModule(_CommandProxy):

    async def create(self, type_hint=_UNSET, **kwargs):
        params = dict(kwargs)
        if type_hint is not _UNSET and "type" not in params and "type_hint" not in params:
            params["type_hint"] = type_hint
        return await self._command("browsingContext.create", params)

    async def create_context_id(self, type_hint=_UNSET, **kwargs):
        params = dict(kwargs)
        if type_hint is not _UNSET and "type" not in params and "type_hint" not in params:
            params["type_hint"] = type_hint
        return await self._command("browsingContext.createContextId", params)

    async def create_and_get_info_value(self, **params):
        return await self._command("browsingContext.createAndGetInfoValue", params)

    async def create_and_get_info_required(self, **params):
        result = await self.create_and_get_info_value(**params)
        return _require_context_info(
            result,
            "browsingContext.createAndGetInfoValue",
        )

    async def navigate(self, context: str, url: str, wait: str = "none"):
        return await self._command(
            "browsingContext.navigateWithState",
            {"context": context, "url": url, "wait": wait},
        )

    async def get_tree(self, root=None, max_depth=None):
        params = {}
        if root is not None:
            params["root"] = root
        if max_depth is not None:
            params["max_depth"] = max_depth
        return await self._command("browsingContext.getTreeContexts", params)

    async def get_current_url(self, context) -> str | None:
        return await self._command(
            "browsingContext.getCurrentUrlValue",
            {"context": _context_id(context)},
        )

    async def close(self, context: str, prompt_unload=_UNSET):
        params = {"context": context}
        # prompt_unload=None should behave like omitted in WPT.
        if prompt_unload is not _UNSET and prompt_unload is not None:
            params["prompt_unload"] = prompt_unload
        self._session.fail_pending_print_requests_for_context(context)
        return await self._command("browsingContext.closeResult", params)

    async def handle_user_prompt(self, context: str, accept=_UNSET, user_text=_UNSET):
        params = {"context": context}
        if accept is not _UNSET:
            params["accept"] = accept
        if user_text is not _UNSET:
            params["user_text"] = user_text
        return await self._command("browsingContext.handleUserPrompt", params)

    async def activate(self, context: str):
        return await self._command("browsingContext.activate", {"context": context})

    async def reload(self, context: str, **kwargs):
        return await self._command(
            "browsingContext.reloadWithState", {"context": context, **kwargs}
        )

    async def print(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        return await self._command("browsingContext.printData", params)

    async def capture_screenshot(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        return await self._command("browsingContext.captureScreenshotData", params)

    async def locate_nodes(
        self,
        context: str,
        locator,
        max_node_count=_UNSET,
        serialization_options=_UNSET,
        start_nodes=_UNSET,
    ):
        params = {
            "context": context,
            "locator": locator,
        }
        if max_node_count is not _UNSET:
            params["max_node_count"] = max_node_count
        if serialization_options is not _UNSET:
            params["serialization_options"] = serialization_options
        if start_nodes is not _UNSET:
            params["start_nodes"] = start_nodes
        return await self._command("browsingContext.locateNodes", params)

    async def set_viewport(
        self,
        context=None,
        viewport=_UNSET,
        device_pixel_ratio=_UNSET,
        user_contexts=None,
    ):
        params = {}
        if context is not None:
            params["context"] = context
        if viewport is not _UNSET:
            params["viewport"] = viewport
        if device_pixel_ratio is not _UNSET:
            params["device_pixel_ratio"] = device_pixel_ratio
        if user_contexts is not None:
            params["user_contexts"] = user_contexts
        return await self._command("browsingContext.setViewport", params)

    async def traverse_history(self, context: str, delta: int):
        return await self._command(
            "browsingContext.traverseHistory", {"context": context, "delta": delta}
        )


class SessionModule(_CommandProxy):

    async def status(self):
        return await self._command("session.status")

    async def prepare_baseline_context_for_test(self):
        return await self._command("session.prepareBaselineContextForTest")

    async def get_baseline_context_info_value_for_test(self):
        return await self._command("session.getBaselineContextInfoValueForTest")

    async def require_baseline_context_info_value_for_test(self):
        result = await self.get_baseline_context_info_value_for_test()
        return _require_context_info(
            result,
            "session.getBaselineContextInfoValueForTest",
        )

    async def subscribe(self, events: list, contexts: list = None, user_contexts: list = None):
        params = {"events": events}
        if contexts is not None:
            params["contexts"] = contexts
        if user_contexts is not None:
            params["user_contexts"] = user_contexts
        return await self._command("session.subscribe", params)

    async def subscribe_id(self, events: list, contexts: list = None, user_contexts: list = None):
        params = {"events": events}
        if contexts is not None:
            params["contexts"] = contexts
        if user_contexts is not None:
            params["user_contexts"] = user_contexts
        return await self._command("session.subscribeId", params)

    async def unsubscribe(self, subscriptions: list = None, **kwargs):
        params = {}
        if subscriptions is not None:
            params["subscriptions"] = subscriptions
        params.update(kwargs)
        return await self._command("session.unsubscribe", params)

    async def reset_for_test(self):
        return await self._command("session.resetForTest")


class ScriptModule(_CommandProxy):

    async def _result_command(self, method: str, params: Mapping[str, Any]):
        result = await self._command(method, params)
        if isinstance(result, dict) and "exceptionDetails" in result:
            raise ScriptEvaluateResultException(result)
        return result

    async def evaluate(self, expression, target, await_promise=False, **kwargs):
        raw_result = kwargs.pop("raw_result", False)
        params = {
            "expression": expression,
            "target": target,  # Pass target as-is for WPT validation tests
            "await_promise": await_promise,
        }
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        command = "script.evaluate" if raw_result else "script.evaluateResult"
        if raw_result:
            return await self._command(command, params)
        return await self._result_command(command, params)

    async def call_function(self, function_declaration, target, arguments=None, await_promise=False, **kwargs):
        raw_result = kwargs.pop("raw_result", False)
        params = {
            "function_declaration": function_declaration,
            "target": target,  # Pass target as-is for WPT validation tests
            "await_promise": await_promise,
        }
        if arguments is not None:
            params["arguments"] = arguments
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        command = "script.callFunction" if raw_result else "script.callFunctionResult"
        if raw_result:
            return await self._command(command, params)
        return await self._result_command(command, params)

    async def disown(self, handles, target):
        return await self._command(
            "script.disown",
            {"handles": handles, "target": target},
        )

    async def get_element_for_test(self, selector, context, *, allow_frame_fallback=False):
        return await self._command(
            "script.getElementForTest",
            {
                "context": _context_id(context),
                "selector": selector,
                "allowFrameFallback": allow_frame_fallback,
            },
        )

    async def add_preload_script(self, function_declaration: str, **kwargs):
        params = {"function_declaration": function_declaration}
        for key, value in kwargs.items():
            if value is None or self._session._is_undefined(value):
                continue
            params[key] = value
        return await self._command("script.addPreloadScriptId", params)

    async def load_static_test_page_for_test(self, context: str, page: str, html: str):
        return await self._command(
            "script.loadStaticTestPageForTest",
            {"context": context, "page": page, "html": html},
        )

    async def create_iframe_context_id_for_test(self, context, url: str):
        return await self._command(
            "script.createIframeContextIdForTest",
            {"context": _context_id(context), "url": url},
        )

    async def prepare_beforeunload_page_url_for_test(self, context, url: str | None = None):
        params: dict[str, Any] = {"context": _context_id(context)}
        if isinstance(url, str):
            params["url"] = url
        return await self._command(
            "script.prepareBeforeunloadPageUrlForTest",
            params,
        )

    async def fetch_for_test(
        self,
        url: str,
        *,
        context=None,
        method: str | None = None,
        headers: Mapping[str, Any] | None = None,
        post_data: Any = None,
        timeout_ms: int = 0,
        should_abort: bool = False,
        sandbox: str | None = None,
    ):
        params: dict[str, Any] = {
            "url": url,
            "timeoutMs": int(timeout_ms),
            "shouldAbort": should_abort,
            "headersJson": json.dumps(dict(headers)) if isinstance(headers, Mapping) else "null",
        }
        context_id = _context_id(context)
        if isinstance(context_id, str):
            params["context"] = context_id
        if isinstance(method, str):
            params["method"] = method
        if isinstance(post_data, dict):
            params["postDataMode"] = "formData"
            params["postDataJson"] = json.dumps(post_data)
        elif post_data is not None:
            params["postDataMode"] = "value"
            params["postDataJson"] = json.dumps(post_data)
        if isinstance(sandbox, str):
            params["sandbox"] = sandbox
        return await self._result_command("script.fetchForTest", params)

    async def remove_preload_script(self, script: str):
        return await self._command("script.removePreloadScript", {"script": script})

    async def remove_all_preload_scripts(self):
        return await self._command("script.removeAllPreloadScripts")

    async def get_realms(self, **kwargs):
        params = dict(kwargs)
        return await self._command("script.getRealmsList", params)


class NetworkModule(_CommandProxy):

    def _validate_request_id(self, request: Any) -> str:
        if not isinstance(request, str):
            raise bidi_error.InvalidArgumentException("request must be a string")
        if request == "":
            raise bidi_error.NoSuchRequestException("Unknown request")
        return request


    async def add_intercept(self, phases=_UNSET, url_patterns=_UNSET, **kwargs):
        params = {}
        if phases is not _UNSET:
            params["phases"] = phases
        if url_patterns is not _UNSET:
            params["url_patterns"] = url_patterns
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        return await self._command("network.addInterceptId", params)

    async def remove_intercept(self, intercept: str):
        return await self._command("network.removeIntercept", {"intercept": intercept})

    async def prepare_test_context(self, *, url: str, context=None):
        context_id = context.get("context") if isinstance(context, Mapping) else context
        params = {"url": url}
        if isinstance(context_id, str):
            params["context"] = context_id
        return await self._command("network.prepareContextForTest", params)

    async def continue_request(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked_phase = await self._session.blocked_request_phase(request_id)
        if not isinstance(blocked_phase, str):
            raise bidi_error.NoSuchRequestException("Unknown request")
        params: dict[str, Any] = {"request": request_id}
        for key, value in kwargs.items():
            params[key] = value

        navigation_id = await self._session.blocked_request_navigation(request_id)
        if isinstance(navigation_id, str) and "navigation" not in params:
            params["navigation"] = navigation_id
        await self._command("network.continueBlockedRequest", params)
        return {}

    async def continue_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        params: dict[str, Any] = {
            "request": request_id,
            "mode": "continueResponse",
        }
        for key, value in kwargs.items():
            params[key] = value
        await self._command("network.continueBlockedResponse", params)
        return {}

    async def fail_request(self, request: str):
        request_id = self._validate_request_id(request)
        await self._session.command(
            "network.failBlockedRequest",
            {"request": request_id, "errorText": "Request failed"},
        )
        return {}

    async def continue_with_auth(self, request: str, action: str, credentials=None):
        request_id = self._validate_request_id(request)
        if action == "provideCredentials":
            return await self.continue_response(
                request=request,
                credentials=credentials,
            )
        await self._command(
            "network.continueAuthRequest",
            {"request": request_id, "action": action},
        )
        return {}

    async def provide_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked_phase = await self._session.blocked_request_phase(request_id)
        if not isinstance(blocked_phase, str):
            raise bidi_error.NoSuchRequestException("Unknown request")
        params: dict[str, Any] = {
            "request": request_id,
            "mode": "provideResponse",
        }
        for key, value in kwargs.items():
            params[key] = value

        await self._command("network.continueBlockedResponse", params)
        return {}

    async def add_data_collector(self, **kwargs):
        params = {}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        return await self._command("network.addDataCollectorId", params)

    async def set_extra_headers(self, headers, contexts=_UNSET, user_contexts=_UNSET):
        params = {"headers": headers}
        if contexts is not _UNSET:
            params["contexts"] = contexts
        if user_contexts is not _UNSET:
            params["user_contexts"] = user_contexts
        return await self._command("network.setExtraHeaders", params)

    async def set_cache_behavior(self, cache_behavior, contexts=_UNSET):
        params: dict[str, Any] = {
            "cache_behavior": cache_behavior,
        }
        if contexts is not _UNSET:
            params["contexts"] = contexts

        try:
            await self._command("network.setCacheBehavior", params)
        except (bidi_error.UnknownCommandException, bidi_error.UnknownErrorException):
            return {}
        return {}

    async def remove_data_collector(self, collector: str):
        return await self._command("network.removeDataCollector", {"collector": collector})

    async def get_data(self, request, data_type, collector=None, disown=False):
        params = {"request": request, "data_type": data_type, "disown": disown}
        if collector is not None:
            params["collector"] = collector
        return await self._command("network.getData", params)

    async def disown_data(self, request, data_type, collector):
        return await self._command("network.disownData", {
            "request": request,
            "data_type": data_type,
            "collector": collector,
        })


class StorageModule(_CommandProxy):

    async def get_cookies(self, filter=None, partition=None):
        params: dict[str, Any] = {}
        if filter is not None:
            params["filter"] = filter
        if partition is not None:
            params["partition"] = partition
        return await self._command("storage.getCookies", params)

    async def set_cookie(self, cookie, partition=None):
        params = {"cookie": cookie}
        if partition is not None:
            params["partition"] = partition
        return await self._command("storage.setCookie", params)

    async def delete_cookies(self, filter=None, partition=None):
        params: dict[str, Any] = {}
        if filter is not None:
            params["filter"] = filter
        if partition is not None:
            params["partition"] = partition
        return await self._command("storage.deleteCookies", params)


class InputModule(_CommandProxy):

    async def perform_actions(self, actions, context: str):
        if hasattr(actions, "to_json"):
            actions = actions.to_json()
        params = {"actions": actions, "context": context}
        return await self._command("input.performActions", params)

    async def release_actions(self, context: str):
        return await self._command("input.releaseActions", {"context": context})

    async def set_files(self, context: str, element, files):
        await self._command(
            "input.setFiles",
            {
                "context": context,
                "element": element,
                "files": files,
            },
        )
        return {}

    async def is_file_dialog_canceled_for_test(self, context):
        return await self._command(
            "input.isFileDialogCanceledForTest",
            {"context": _context_id(context)},
        )


class BrowserModule(_CommandProxy):

    async def create_user_context(self, **kwargs):
        params = dict(kwargs)
        return await self._command("browser.createUserContextId", params)

    async def get_user_contexts(self):
        return await self._command("browser.getUserContextsList")

    async def get_client_windows(self):
        return await self._command("browser.getClientWindowsList")

    async def remove_user_context(self, user_context: str):
        return await self._command("browser.removeUserContext", {"userContext": user_context})

    async def set_download_behavior(self, download_behavior=_UNSET, user_contexts=_UNSET):
        params = {}
        if download_behavior is not _UNSET:
            params["downloadBehavior"] = download_behavior
        if user_contexts is not _UNSET:
            params["user_contexts"] = user_contexts
        return await self._command("browser.setDownloadBehavior", params)


class EmulationModule(_CommandProxy):

    async def set_user_agent_override(self, user_agent, **kwargs):
        params = {"user_agent": user_agent}
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setUserAgentOverride", params)

    async def set_locale_override(self, locale, **kwargs):
        params = {"locale": locale}
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setLocaleOverride", params)

    async def set_timezone_override(self, timezone, **kwargs):
        params = {"timezone": timezone}
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setTimezoneOverride", params)

    async def set_geolocation_override(self, coordinates=_UNSET, error=_UNSET, **kwargs):
        params = {}
        if coordinates is not _UNSET:
            params["coordinates"] = coordinates
        if error is not _UNSET:
            params["error"] = error
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setGeolocationOverride", params)

    async def set_network_conditions(self, network_conditions=_UNSET, **kwargs):
        params = {}
        if network_conditions is not _UNSET:
            params["network_conditions"] = network_conditions
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setNetworkConditions", params)

    async def set_screen_orientation_override(
        self,
        screen_orientation=_UNSET,
        **kwargs,
    ):
        params = {}
        if screen_orientation is not _UNSET:
            params["screen_orientation"] = screen_orientation
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setScreenOrientationOverride", params)

    async def set_screen_settings_override(
        self,
        screen_area=_UNSET,
        **kwargs,
    ):
        params = {}
        if screen_area is not _UNSET:
            params["screen_area"] = screen_area
        for key, value in kwargs.items():
            params[key] = value
        return await self._command("emulation.setScreenSettingsOverride", params)


class PermissionsModule(_CommandProxy):

    async def set_permission(self, descriptor, state, origin, **kwargs):
        params = {
            "descriptor": descriptor,
            "state": state,
            "origin": origin,
        }
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        await self._command("permissions.setPermission", params)
        return {}


class BluetoothModule(_CommandProxy):

    async def simulate_adapter(self, context, state):
        await self._command(
            "bluetooth.simulateAdapter",
            {"context": _context_id(context), "state": state},
        )
        return {}

    async def disable_simulation(self, context):
        await self._command(
            "bluetooth.disableSimulation",
            {"context": _context_id(context)},
        )
        return {}

    async def simulate_preconnected_peripheral(self, context, **kwargs):
        params = {"context": _context_id(context)}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        await self._command("bluetooth.simulatePreconnectedPeripheral", params)
        return {}

    async def handle_request_device_prompt(self, context, prompt, accept, device=None):
        params = {
            "context": _context_id(context),
            "prompt": prompt,
            "accept": accept,
        }
        if device is not None:
            params["device"] = device
        await self._command("bluetooth.handleRequestDevicePrompt", params)
        return {}

    async def simulate_gatt_connection_response(self, context, address, code):
        await self._command(
            "bluetooth.simulateGATTConnectionResponse",
            {"context": _context_id(context), "address": address, "code": code},
        )
        return {}

    async def simulate_gatt_disconnection(self, context, address):
        await self._command(
            "bluetooth.simulateGATTDisconnection",
            {"context": _context_id(context), "address": address},
        )
        return {}

    async def simulate_service(self, context, address, uuid, type):
        await self._command(
            "bluetooth.simulateService",
            {
                "context": _context_id(context),
                "address": address,
                "uuid": uuid,
                "type": type,
            },
        )
        return {}

    async def simulate_characteristic(
        self,
        context,
        address,
        service_uuid,
        characteristic_uuid,
        characteristic_properties,
        type,
    ):
        await self._command(
            "bluetooth.simulateCharacteristic",
            {
                "context": _context_id(context),
                "address": address,
                "service_uuid": service_uuid,
                "characteristic_uuid": characteristic_uuid,
                "characteristic_properties": characteristic_properties,
                "type": type,
            },
        )
        return {}

    async def simulate_characteristic_response(
        self,
        context,
        address,
        service_uuid,
        characteristic_uuid,
        type,
        code,
        data,
    ):
        params = {
            "context": _context_id(context),
            "address": address,
            "service_uuid": service_uuid,
            "characteristic_uuid": characteristic_uuid,
            "type": type,
            "code": code,
            "data": data,
        }
        await self._command("bluetooth.simulateCharacteristicResponse", params)
        return {}

    async def simulate_descriptor(
        self,
        context,
        address,
        service_uuid,
        characteristic_uuid,
        descriptor_uuid,
        type,
    ):
        await self._command(
            "bluetooth.simulateDescriptor",
            {
                "context": _context_id(context),
                "address": address,
                "service_uuid": service_uuid,
                "characteristic_uuid": characteristic_uuid,
                "descriptor_uuid": descriptor_uuid,
                "type": type,
            },
        )
        return {}

    async def simulate_descriptor_response(
        self,
        context,
        address,
        service_uuid,
        characteristic_uuid,
        descriptor_uuid,
        type,
        code,
        data,
    ):
        params = {
            "context": _context_id(context),
            "address": address,
            "service_uuid": service_uuid,
            "characteristic_uuid": characteristic_uuid,
            "descriptor_uuid": descriptor_uuid,
            "type": type,
            "code": code,
            "data": data,
        }
        await self._command("bluetooth.simulateDescriptorResponse", params)
        return {}


class WebExtensionModule(_CommandProxy):

    async def install(self, extension_data):
        result = await self._command(
            "webExtension.install",
            {"extensionData": extension_data},
        )
        if isinstance(result, Mapping):
            return result.get("extension")
        return result

    async def uninstall(self, extension):
        return await self._command(
            "webExtension.uninstall",
            {"extension": extension},
        )


class _TrackedTask:
    """Track whether a scheduled task was explicitly awaited by the test."""

    def __init__(self, task: asyncio.Task):
        self.task = task
        self.awaited = False

    def __await__(self):
        self.awaited = True
        return self.task.__await__()


class _TrackedTaskGroup:
    """Own tracked tasks and await only the ones the test left pending."""

    def __init__(self):
        self._tasks: list[_TrackedTask] = []

    def spawn(self, coro):
        tracked = _TrackedTask(asyncio.create_task(coro))
        self._tasks.append(tracked)
        return tracked

    async def wait_unawaited(self):
        for tracked in self._tasks:
            if tracked.awaited:
                continue
            await tracked.task


class _CollectorGroup:
    """Own named event collectors created during a single fixture lifetime."""

    def __init__(self):
        self._collectors = []

    def add(self, collector):
        self._collectors.append(collector)
        return collector

    def close(self):
        for collector in self._collectors:
            collector.close()


class _ListenerGroup:
    """Own event listener removers created during a single fixture lifetime."""

    def __init__(self):
        self._removers = []

    def add(self, remove_listener):
        self._removers.append(remove_listener)

    def close(self):
        for remove_listener in self._removers:
            remove_listener()
        self._removers.clear()


# Pytest fixtures

def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "capabilities: mark test to use capabilities",
    )

@pytest.fixture
def event_loop():
    """Create an event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def bidi_session(capabilities):
    """Create a BiDi session connected to Crater."""
    session = CraterBidiSession(CRATER_BIDI_URL)
    session.capabilities = {"browserName": "crater", **capabilities}
    await session.start()
    # Reinitialize protocol state per test with requested capabilities.
    session_new = await session.send_command(
        "session.new",
        {"capabilities": {"alwaysMatch": capabilities}},
    )
    await session_new
    await _trim_contexts_for_test(session)
    yield session
    await _trim_contexts_for_test(session)
    await session.end()


@pytest_asyncio.fixture(autouse=True)
async def _reset_context_state_per_test(bidi_session):
    """
    Enforce browsing context cleanup for every test regardless of which
    plugin-provided `bidi_session` fixture gets selected.
    """
    await _trim_contexts_for_test(bidi_session)
    yield
    await _trim_contexts_for_test(bidi_session)


async def _trim_contexts_for_test(session: CraterBidiSession):
    try:
        await session.session.prepare_baseline_context_for_test()
    except Exception:
        pass
    session.clear_all_event_backlog()


@pytest_asyncio.fixture
async def top_context(bidi_session):
    """Get the top-level browsing context."""
    return await bidi_session.session.require_baseline_context_info_value_for_test()


@pytest_asyncio.fixture
async def new_tab(bidi_session):
    """Open and focus a new tab."""
    context_info = await bidi_session.browsing_context.create_and_get_info_required(
        type="tab"
    )
    context_id = context_info["context"]
    yield context_info
    try:
        await bidi_session.browsing_context.close(context=context_id)
    except Exception:
        pass


@pytest.fixture
def server_config():
    """Minimal WPT-like server config used by fixtures requiring server metadata."""
    return _fixture_server_config()


@pytest.fixture
def url():
    """Generate test URLs."""
    return _fixture_url


@pytest.fixture
def inline():
    """Generate inline HTML data URLs."""
    return _fixture_inline


@pytest.fixture
def iframe():
    """Inline document extract as the source document of an <iframe>."""
    return _fixture_iframe


@pytest.fixture
def create_iframe(bidi_session):
    """
    Create an iframe and return a context mapping.

    Some synthetic pages in Crater do not expose `document.body` in a way that
    WPT helper expects. In that case, fall back to creating a synthetic child
    browsing context linked to the parent context for header scope tests.
    """
    async def create_iframe(context, url):
        context_id = await bidi_session.script.create_iframe_context_id_for_test(
            context,
            url,
        )
        return {"context": context_id}

    return create_iframe


@pytest_asyncio.fixture
async def add_and_remove_iframe(bidi_session):
    """Return an id that behaves like a removed frame context for negative tests."""
    return functools.partial(_add_and_remove_iframe_impl, bidi_session)


@pytest.fixture
def compare_png_bidi():
    """Minimal pixel comparator used by screenshot and print assertions."""
    return _compare_png_bidi_impl


@pytest.fixture
def render_pdf_to_png_bidi():
    """Render synthetic print output into deterministic PNG bytes."""
    return _render_pdf_to_png_bidi_impl


@pytest.fixture
def assert_pdf_content():
    """Validate printable payload shape and synthetic content metadata."""
    return _assert_pdf_content_impl


@pytest.fixture
def assert_pdf_dimensions():
    """Validate printable payload shape and synthetic PDF dimensions."""
    return _assert_pdf_dimensions_impl


@pytest.fixture
def assert_pdf_image(get_reference_png, render_pdf_to_png_bidi, compare_png_bidi):
    """Validate printable payload shape and compare synthetic rendered image."""
    return functools.partial(
        _assert_pdf_image_impl,
        get_reference_png,
        render_pdf_to_png_bidi,
        compare_png_bidi,
    )


@pytest.fixture
def get_actions_origin_page():
    """Create a test page for action origin tests."""
    return _fixture_get_actions_origin_page


@pytest.fixture
def timeout_multiplier():
    return _fixture_timeout_multiplier()


@pytest.fixture
def configuration(timeout_multiplier):
    """Test configuration."""
    return _fixture_configuration(timeout_multiplier)


@pytest.fixture
def fetch(bidi_session, timeout_multiplier):
    """Perform a fetch from the page of the provided context."""
    return functools.partial(
        _fetch_impl,
        bidi_session,
        timeout_multiplier,
    )


@pytest_asyncio.fixture
async def subscribe_events(bidi_session):
    """Subscribe to events and clean up after test."""
    tracker = bidi_session.track_subscriptions()
    yield functools.partial(_subscribe_events_impl, bidi_session, tracker)

    await tracker.close()


@pytest_asyncio.fixture
async def add_preload_script(bidi_session):
    """Add preload scripts and clean them up after test."""
    yield functools.partial(_add_preload_script_impl, bidi_session)

    try:
        await bidi_session.script.remove_all_preload_scripts()
    except Exception:
        pass


@pytest.fixture
def wait_for_event(bidi_session):
    """Wait for a BiDi event."""
    listeners = _ListenerGroup()
    yield functools.partial(_wait_for_event_impl, bidi_session, listeners)
    listeners.close()


@pytest.fixture
def wait_for_events(bidi_session, timeout_multiplier):
    """Wait for BiDi events until a predicate becomes true."""
    yield functools.partial(
        bidi_session.collect_events,
        timeout_multiplier=timeout_multiplier,
    )


@pytest.fixture
def send_blocking_command(bidi_session):
    """Send a blocking command."""
    return bidi_session.command


@pytest.fixture
def get_element(bidi_session, top_context):
    """Return a remote reference for the first element matching selector."""
    debug_get_element = os.environ.get("CRATER_DEBUG_GET_ELEMENT", "0") == "1"
    return functools.partial(
        _get_element_impl,
        bidi_session,
        top_context,
        debug_get_element,
    )


@pytest.fixture
def current_url(bidi_session):
    """Return current URL for a browsing context."""
    return bidi_session.browsing_context.get_current_url


@pytest_asyncio.fixture
async def load_static_test_page(bidi_session, top_context):
    """Navigate to a static WPT support page from local checkout."""
    return functools.partial(
        _load_static_test_page_impl,
        bidi_session,
        _support_html_dir(),
        top_context,
    )


@pytest.fixture
def current_session():
    """Minimal classic WebDriver session fixture used by legacy WPT helpers."""
    return _fixture_current_session()


@pytest.fixture
def session():
    """Minimal classic session fixture for session.new BiDi upgrade tests."""
    return _fixture_classic_session()


@pytest.fixture
def default_capabilities():
    return _fixture_default_capabilities()


@pytest.fixture
def capabilities(request, default_capabilities):
    """Session capabilities merged with @pytest.mark.capabilities."""
    return _fixture_capabilities_for_request(request, default_capabilities)


@pytest.fixture
def modifier_key():
    """Platform modifier key used by shortcut tests."""
    return _fixture_modifier_key()


@pytest_asyncio.fixture
async def create_user_context(bidi_session):
    """Create user contexts. Cleanup is handled by session baseline reset."""
    yield bidi_session.browser.create_user_context


@pytest_asyncio.fixture
async def setup_beforeunload_page(bidi_session):
    """Navigate to beforeunload test page and mark it as user-interacted."""
    return bidi_session.script.prepare_beforeunload_page_url_for_test


@pytest.fixture
def wait_for_future_safe():
    """Wait for a future with timeout while preserving remote exceptions."""
    return _fixture_wait_for_future_safe


@pytest.fixture
def current_time():
    """Return current time in milliseconds."""
    return _fixture_current_time


@pytest.fixture
def extension_data():
    return _chrome_extension_data()


@pytest.fixture
def test_page():
    return _fixture_named_bidi_fixture("test_page")


def _webdriver_fixture_builder_path() -> Path:
    root = Path(__file__).resolve().parent.parent
    candidates = [
        root / "browser" / "jsbidi" / "_build" / "js" / "release" / "build" / "webdriver_fixture_builder" / "webdriver_fixture_builder.js",
        root / "browser" / "target" / "js" / "release" / "build" / "webdriver_fixture_builder" / "webdriver_fixture_builder.js",
        root / "browser" / "_build" / "js" / "release" / "build" / "webdriver_fixture_builder" / "webdriver_fixture_builder.js",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(
        "MoonBit webdriver fixture builder is not built. Run: just build-bidi"
    )


@functools.lru_cache(maxsize=None)
def _build_webdriver_fixture_from_json(payload_json: str) -> str:
    builder_path = _webdriver_fixture_builder_path()
    proc = subprocess.run(
        ["deno", "run", "-A", str(builder_path), payload_json],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip()
        raise RuntimeError(
            f"webdriver_fixture_builder failed with code {proc.returncode}: {detail}"
        )
    return proc.stdout.strip()


def _build_webdriver_fixture(payload: Mapping[str, Any]) -> str:
    return _build_webdriver_fixture_from_json(
        json.dumps(dict(payload), sort_keys=True, separators=(",", ":"))
    )


def _parse_webdriver_fixture_json(
    payload: Mapping[str, Any],
    *,
    default: Any,
):
    try:
        parsed = json.loads(_build_webdriver_fixture(payload))
    except Exception:
        return default
    return parsed


def _fixture_server_config() -> dict[str, Any]:
    parsed = _parse_webdriver_fixture_json(
        {"op": "buildServerConfig"},
        default={},
    )
    return parsed if isinstance(parsed, dict) else {}


def _fixture_classic_session():
    return SimpleNamespace(capabilities={"webSocketUrl": CRATER_BIDI_URL})


def _fixture_current_session():
    return SimpleNamespace(capabilities={"platformName": _current_platform_name()})


def _fixture_timeout_multiplier() -> float:
    return float(os.environ.get("WPT_TIMEOUT_MULTIPLIER", "1.0"))


def _fixture_configuration(timeout_multiplier: float) -> dict[str, float]:
    return {"timeout_multiplier": timeout_multiplier}


def _fixture_url(
    path: str,
    domain: str = "",
    protocol: str = "http",
    subdomain: str = "",
    query: str = "",
    fragment: str = "",
) -> str:
    return _build_webdriver_fixture(
        {
            "op": "buildUrl",
            "path": str(path),
            "domain": str(domain),
            "protocol": str(protocol),
            "subdomain": str(subdomain),
            "query": str(query),
            "fragment": str(fragment),
        }
    )


def _fixture_inline(
    content: str,
    content_type: str = "text/html",
    domain: str = "",
    parameters=None,
    protocol: str = "http",
    subdomain: str = "",
    **_ignored,
) -> str:
    payload: dict[str, Any] = {
        "op": "buildInlineUrl",
        "content": str(content),
        "contentType": str(content_type),
        "domain": str(domain),
        "protocol": str(protocol),
        "subdomain": str(subdomain),
    }
    if isinstance(parameters, dict):
        pipe = parameters.get("pipe")
        if pipe is not None:
            payload["pipe"] = str(pipe)
    return _build_webdriver_fixture(payload)


def _fixture_iframe(src: str, **kwargs) -> str:
    payload: dict[str, Any] = {
        "op": "buildIframeMarkup",
        "src": str(src),
    }
    content_type = kwargs.get("content_type")
    if content_type is not None:
        payload["contentType"] = str(content_type)
    domain = kwargs.get("domain")
    if domain is not None:
        payload["domain"] = str(domain)
    protocol = kwargs.get("protocol")
    if protocol is not None:
        payload["protocol"] = str(protocol)
    subdomain = kwargs.get("subdomain")
    if subdomain is not None:
        payload["subdomain"] = str(subdomain)
    parameters = kwargs.get("parameters")
    if isinstance(parameters, dict):
        pipe = parameters.get("pipe")
        if pipe is not None:
            payload["pipe"] = str(pipe)
    return _build_webdriver_fixture(payload)


def _extract_pdf_meta_for_test(encoded_pdf_data: str | bytes | bytearray) -> dict[str, Any]:
    parsed = _parse_webdriver_fixture_json(
        {
            "op": "extractPdfMeta",
            "encodedPdfData": _base64_text_from_any(encoded_pdf_data),
        },
        default={},
    )
    return parsed if isinstance(parsed, dict) else {}


def _extract_pdf_content_for_test(encoded_pdf_data: str | bytes | bytearray) -> dict[str, Any]:
    parsed = _parse_webdriver_fixture_json(
        {
            "op": "extractPdfContent",
            "encodedPdfData": _base64_text_from_any(encoded_pdf_data),
        },
        default={},
    )
    return parsed if isinstance(parsed, dict) else {}


def _fixture_get_test_page(
    as_frame: bool = False,
    frame_doc: str = None,
    shadow_doc: str = None,
    nested_shadow_dom: bool = False,
    shadow_root_mode: str = "open",
    **kwargs,
):
    payload: dict[str, Any] = {
        "asFrame": as_frame,
        "nestedShadowDom": nested_shadow_dom,
        "shadowRootMode": shadow_root_mode,
    }
    if isinstance(frame_doc, str):
        payload["frameDoc"] = frame_doc
    if isinstance(shadow_doc, str):
        payload["shadowDoc"] = shadow_doc
    protocol = kwargs.get("protocol")
    if isinstance(protocol, str):
        payload["protocol"] = protocol
    payload["op"] = "buildNodeTestPageUrl"
    return _build_webdriver_fixture(payload)


def _fixture_get_actions_origin_page(inner_style: str, outer_style: str = "") -> str:
    return _build_webdriver_fixture(
        {
            "op": "buildActionsOriginPage",
            "innerStyle": str(inner_style),
            "outerStyle": str(outer_style),
        }
    )


def _fixture_named_bidi_fixture(name: str) -> str:
    return _build_webdriver_fixture(
        {
            "op": "buildNamedBidiFixture",
            "name": str(name),
        }
    )


async def _compare_png_bidi_impl(img1, img2):
    from tests.support.image import ImageDifference

    result = _parse_webdriver_fixture_json(
        {
            "op": "comparePng",
            "left": _base64_text_from_any(img1),
            "right": _base64_text_from_any(img2),
        },
        default={},
    )
    return ImageDifference(
        int(result.get("totalPixels", 1)),
        int(result.get("maxDifference", 255)),
    )


async def _render_pdf_to_png_bidi_impl(encoded_pdf_data, page=1):
    _ = page
    encoded_png = _build_webdriver_fixture(
        {
            "op": "renderPdfToPng",
            "encodedPdfData": _base64_text_from_any(encoded_pdf_data),
        }
    )
    return base64.b64decode(encoded_png.encode(), validate=False)


async def _assert_pdf_content_impl(pdf, expected_content):
    from tests.support.asserts import assert_pdf

    assert_pdf(pdf)
    pdf_content = _extract_pdf_content_for_test(pdf)
    assert pdf_content == {
        "type": "array",
        "value": expected_content,
    }


async def _assert_pdf_dimensions_impl(pdf, expected_dimensions):
    from tests.support.asserts import assert_pdf

    assert_pdf(pdf)
    meta = _extract_pdf_meta_for_test(pdf)
    assert "pageWidthCm" in meta
    assert "pageHeightCm" in meta
    assert math.isclose(
        float(meta["pageWidthCm"]),
        float(expected_dimensions["width"]),
        rel_tol=0.0,
        abs_tol=0.05,
    )
    assert math.isclose(
        float(meta["pageHeightCm"]),
        float(expected_dimensions["height"]),
        rel_tol=0.0,
        abs_tol=0.05,
    )


async def _assert_pdf_image_impl(
    get_reference_png,
    render_pdf_to_png_bidi,
    compare_png_bidi,
    pdf,
    reference_html,
    expected,
):
    from tests.support.asserts import assert_pdf

    assert_pdf(pdf)
    reference_png = await get_reference_png(reference_html)
    page_png = await render_pdf_to_png_bidi(pdf)
    comparison = await compare_png_bidi(reference_png, page_png)
    assert comparison.equal() == expected


async def _fetch_impl(
    bidi_session,
    timeout_multiplier: float,
    url,
    method=None,
    headers=None,
    post_data=None,
    context=None,
    timeout_in_seconds=3,
    sandbox_name=None,
):
    should_abort = timeout_in_seconds <= 0
    timeout_ms = int(timeout_in_seconds * timeout_multiplier * 1000)
    return await bidi_session.script.fetch_for_test(
        url,
        context=context,
        method=method,
        headers=headers if isinstance(headers, Mapping) else None,
        post_data=post_data,
        timeout_ms=timeout_ms,
        should_abort=should_abort,
        sandbox=sandbox_name,
    )


async def _add_and_remove_iframe_impl(bidi_session, _top_context):
    frame_id = await bidi_session.browsing_context.create_context_id(type_hint="tab")
    if isinstance(frame_id, str):
        try:
            await bidi_session.browsing_context.close(context=frame_id)
        except Exception:
            pass
    return frame_id


async def _subscribe_events_impl(
    bidi_session,
    tracker: _BiDiSubscriptionTracker,
    events,
    contexts=None,
    user_contexts=None,
):
    subscription_id = await bidi_session.session.subscribe_id(
        events=events,
        contexts=contexts,
        user_contexts=user_contexts,
    )
    tracker.add(subscription_id)
    return {"subscription": subscription_id}


async def _add_preload_script_impl(bidi_session, function_declaration: str, **kwargs):
    return await bidi_session.script.add_preload_script(
        function_declaration=function_declaration,
        **kwargs,
    )


def _wait_for_event_impl(
    bidi_session,
    listeners: _ListenerGroup,
    event_name: str,
):
    future, remove_listener = bidi_session.listen_once(
        event_name,
        accept_latest_backlog=event_name == "browsingContext.userPromptOpened",
    )
    listeners.add(remove_listener)
    return future


def _resolve_context_info(context, default_context):
    return context if context is not None else default_context


def _support_html_dir() -> Path:
    return (
        Path(__file__).resolve().parent.parent
        / "wpt"
        / "webdriver"
        / "tests"
        / "support"
        / "html"
    )


async def _get_element_impl(
    bidi_session,
    top_context,
    debug_get_element: bool,
    css_selector,
    context=None,
):
    resolved_context = _resolve_context_info(context, top_context)
    context_id = resolved_context["context"]
    element = await bidi_session.script.get_element_for_test(
        css_selector,
        resolved_context,
        allow_frame_fallback=context_id != top_context["context"],
    )
    if debug_get_element:
        print(
            f"[get_element] selector={css_selector!r} context={context_id!r} element={element!r}",
            flush=True,
        )
    return element


async def _load_static_test_page_impl(
    bidi_session,
    support_html_dir: Path,
    default_context,
    page,
    context=None,
):
    resolved_context = _resolve_context_info(context, default_context)
    page_path = support_html_dir / page
    content = page_path.read_text(encoding="utf-8-sig")
    await bidi_session.script.load_static_test_page_for_test(
        resolved_context["context"],
        page,
        content,
    )


async def _assert_file_dialog_cancel_state_impl(
    bidi_session,
    top_context,
    expected_canceled: bool,
    context=None,
):
    resolved_context = _resolve_context_info(context, top_context)
    canceled = await bidi_session.input.is_file_dialog_canceled_for_test(
        resolved_context["context"]
    )
    assert canceled is expected_canceled


async def _setup_network_test_impl(
    bidi_session,
    subscribe_events,
    collectors: _CollectorGroup,
    default_test_url: str,
    default_context_id: str,
    events,
    test_url=None,
    context=None,
    contexts=None,
):
    resolved_test_url = test_url or default_test_url
    resolved_context_id = context or default_context_id
    await bidi_session.network.prepare_test_context(
        url=resolved_test_url,
        context=resolved_context_id,
    )
    await subscribe_events(events=events, contexts=contexts)
    collector = collectors.add(bidi_session.capture_named_events(events))
    return collector.events


def _future_timeout_error() -> TimeoutError:
    return TimeoutError("Future did not resolve within the given timeout")


async def _wait_for_foreign_loop_future(future: asyncio.Future, timeout: float):
    deadline = time.monotonic() + timeout
    while True:
        if future.done():
            return future.result()
        if time.monotonic() >= deadline:
            future.cancel()
            raise _future_timeout_error()
        await asyncio.sleep(0.01)


async def _fixture_wait_for_future_safe(future, timeout: float = 5.0):
    if isinstance(future, asyncio.Future):
        try:
            running_loop = asyncio.get_running_loop()
        except RuntimeError:
            running_loop = None
        future_loop = future.get_loop()
        if running_loop is not None and future_loop is not running_loop:
            return await _wait_for_foreign_loop_future(future, timeout)
    try:
        return await asyncio.wait_for(asyncio.shield(future), timeout=timeout)
    except asyncio.TimeoutError as exc:
        future.cancel()
        raise _future_timeout_error() from exc


async def _fixture_current_time():
    return int(time.time() * 1000)


def _fixture_modifier_key():
    from tests.support.keys import Keys

    target_platform = os.environ.get("WPT_TARGET_PLATFORM", "mac").lower()
    if target_platform == "mac":
        return Keys.META
    return Keys.CONTROL


@pytest.fixture
def get_test_page():
    """Generate a node-rich page compatible with BiDi script node tests."""
    return _fixture_get_test_page


@pytest.fixture
def test_origin():
    return _fixture_named_bidi_fixture("test_origin")


@pytest.fixture
def test_alt_origin():
    return _fixture_named_bidi_fixture("test_alt_origin")


@pytest.fixture
def test_page2():
    return _fixture_named_bidi_fixture("test_page2")


@pytest.fixture
def test_page_cross_origin():
    return _fixture_named_bidi_fixture("test_page_cross_origin")


@pytest.fixture
def test_page_multiple_frames():
    return _fixture_named_bidi_fixture("test_page_multiple_frames")


@pytest.fixture
def test_page_nested_frames():
    return _fixture_named_bidi_fixture("test_page_nested_frames")


@pytest.fixture
def test_page_cross_origin_frame():
    return _fixture_named_bidi_fixture("test_page_cross_origin_frame")


@pytest.fixture
def test_page_same_origin_frame():
    return _fixture_named_bidi_fixture("test_page_same_origin_frame")


@pytest_asyncio.fixture
async def assert_file_dialog_canceled(bidi_session, top_context):
    """Assert that a synthetic file picker is canceled by prompt behavior."""
    pending_tasks = _TrackedTaskGroup()

    yield lambda context=None: pending_tasks.spawn(
        _assert_file_dialog_cancel_state_impl(
            bidi_session,
            top_context,
            True,
            context,
        )
    )

    await pending_tasks.wait_unawaited()


@pytest_asyncio.fixture
async def assert_file_dialog_not_canceled(bidi_session, top_context):
    """Assert that a synthetic file picker remains pending."""
    pending_tasks = _TrackedTaskGroup()

    yield lambda context=None: pending_tasks.spawn(
        _assert_file_dialog_cancel_state_impl(
            bidi_session,
            top_context,
            False,
            context,
        )
    )

    await pending_tasks.wait_unawaited()


@pytest_asyncio.fixture
async def setup_network_test(
    bidi_session,
    subscribe_events,
    top_context,
    url,
):
    """Best-effort network setup for adapter-backed synthetic network events."""
    collectors = _CollectorGroup()
    yield functools.partial(
        _setup_network_test_impl,
        bidi_session,
        subscribe_events,
        collectors,
        url("/webdriver/tests/bidi/network/support/empty.html"),
        top_context["context"],
    )
    collectors.close()
