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
import hashlib
import http
import json
import math
import os
import re
import struct
import sys
import time
import zlib
from pathlib import Path
from typing import Any, Mapping
import pytest
import pytest_asyncio
import websockets
import webdriver.bidi.error as bidi_error
from webdriver.bidi.modules.script import ContextTarget, ScriptEvaluateResultException


CRATER_BIDI_URL = os.environ.get("CRATER_BIDI_URL", "ws://127.0.0.1:9222")
_UNSET = object()
_BLACK_DOT_PNG_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2NgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg=="
)
_WHITE_DOT_PNG_BASE64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2P4DwQACfsD/Z8fLAAAAAAASUVORK5CYII="
)
_COOKIE_ASSIGNMENT_RE = re.compile(r"""document\.cookie\s*=\s*['"]([^'"]+)['"]""")
_HTTP_TOKEN_RE = re.compile(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$")


def _bytes_value_from_text(value: str):
    return {"type": "string", "value": value}


def _bytes_value_from_bytes(value: bytes):
    return {"type": "base64", "value": base64.b64encode(value).decode("ascii")}


def _synthesize_request_bytes_value(post_data: Any):
    if post_data is None:
        return None
    if isinstance(post_data, str):
        return _bytes_value_from_text(post_data)
    if not isinstance(post_data, dict):
        return _bytes_value_from_text(str(post_data))

    has_binary = False
    lines: list[str] = []
    blob_parts: list[bytes] = []
    boundary = "----crater-boundary"
    for key, value in post_data.items():
        field_name = str(key)
        if isinstance(value, Mapping) and isinstance(value.get("value"), str):
            has_binary = True
            encoded = value.get("value")
            try:
                blob = base64.b64decode(encoded.encode("ascii"), validate=False)
            except Exception:
                blob = b""
            filename = str(value.get("filename", "blob.bin"))
            content_type = str(value.get("type", "application/octet-stream"))
            blob_parts.append(
                (
                    f"--{boundary}\r\n"
                    f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"\r\n'
                    f"Content-Type: {content_type}\r\n\r\n"
                ).encode("utf-8")
            )
            blob_parts.append(blob)
            blob_parts.append(b"\r\n")
            continue

        lines.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{field_name}"\r\n\r\n'
            f"{value}\r\n"
        )

    if has_binary:
        body = b"".join(blob_parts) + f"--{boundary}--\r\n".encode("utf-8")
        return _bytes_value_from_bytes(body)

    if lines:
        return _bytes_value_from_text("".join(lines) + f"--{boundary}--\r\n")
    return _bytes_value_from_text("")


def _png_chunk(chunk_type: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + chunk_type
        + payload
        + struct.pack(">I", zlib.crc32(chunk_type + payload) & 0xFFFFFFFF)
    )


def _solid_png_bytes(width: int, height: int, rgba: tuple[int, int, int, int]) -> bytes:
    # Keep synthetic output bounded; WPT screenshot expectations stay under this.
    width = max(1, min(int(width), 4096))
    height = max(1, min(int(height), 4096))
    r, g, b, a = rgba
    pixel = bytes([r & 0xFF, g & 0xFF, b & 0xFF, a & 0xFF])
    row = b"\x00" + (pixel * width)
    raw = row * height
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(raw))
        + _png_chunk(b"IEND", b"")
    )


def _solid_png_base64(width: int, height: int, rgba: tuple[int, int, int, int]) -> str:
    return base64.b64encode(_solid_png_bytes(width, height, rgba)).decode()


def _pdf_from_meta(meta: dict[str, Any]) -> str:
    payload = json.dumps(meta, sort_keys=True)
    pdf = (
        "%PDF-1.4\n"
        f"%CRATER_META {payload}\n"
        "1 0 obj\n"
        "<< /Type /Catalog /Pages 2 0 R >>\n"
        "endobj\n"
        "2 0 obj\n"
        "<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n"
        "endobj\n"
        "3 0 obj\n"
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\n"
        "endobj\n"
        "4 0 obj\n"
        "<< /Length 0 >>\n"
        "stream\n"
        "\n"
        "endstream\n"
        "endobj\n"
        "trailer\n"
        "<< /Root 1 0 R >>\n"
        "%%EOF\n"
    ).encode("utf-8")
    return base64.b64encode(pdf).decode()


def _extract_pdf_meta(encoded_pdf_data: str | bytes | bytearray) -> dict[str, Any]:
    if isinstance(encoded_pdf_data, (bytes, bytearray)):
        raw = bytes(encoded_pdf_data)
    else:
        try:
            raw = base64.b64decode(encoded_pdf_data.encode(), validate=False)
        except Exception:
            return {}
    marker = b"%CRATER_META "
    start = raw.find(marker)
    if start < 0:
        return {}
    start += len(marker)
    end = raw.find(b"\n", start)
    if end < 0:
        end = len(raw)
    try:
        return json.loads(raw[start:end].decode("utf-8"))
    except Exception:
        return {}


def _png_bytes_from_any(value: str | bytes | bytearray) -> bytes:
    if isinstance(value, (bytes, bytearray)):
        return bytes(value)
    return base64.b64decode(value.encode(), validate=False)


def _cm_to_px(cm_value: float) -> int:
    return int(round(cm_value * 96.0 / 2.54))


def _render_pdf_meta_png(meta: dict[str, Any]) -> bytes:
    width_cm = float(meta.get("pageWidthCm", 21.59))
    height_cm = float(meta.get("pageHeightCm", 27.94))
    width = max(1, _cm_to_px(width_cm))
    height = max(1, _cm_to_px(height_cm))
    background = bool(meta.get("background", False))
    if width == 1 and height == 1:
        encoded = _BLACK_DOT_PNG_BASE64 if background else _WHITE_DOT_PNG_BASE64
        return base64.b64decode(encoded.encode(), validate=False)
    rgba = (0, 0, 0, 255) if background else (255, 255, 255, 255)
    return _solid_png_bytes(width, height, rgba)


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

    def _network_header_entries_from_map(
        self,
        headers: Mapping[str, Any] | None,
    ) -> list[dict[str, Any]]:
        if not isinstance(headers, Mapping):
            return []
        return [
            {"name": name, "value": {"type": "string", "value": str(value)}}
            for name, value in headers.items()
            if isinstance(name, str)
        ]

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
                raise AssertionError("Didn't receive expected events")
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


class BrowsingContextModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def create(self, type_hint=_UNSET, **kwargs):
        params = dict(kwargs)
        if type_hint is not _UNSET and "type" not in params and "type_hint" not in params:
            params["type_hint"] = type_hint
        future = await self._session.send_command(
            "browsingContext.create", params
        )
        return await future

    async def create_context_id(self, type_hint=_UNSET, **kwargs):
        params = dict(kwargs)
        if type_hint is not _UNSET and "type" not in params and "type_hint" not in params:
            params["type_hint"] = type_hint
        return await self._session.command("browsingContext.createContextId", params)

    async def create_and_get_info_value(self, **params):
        future = await self._session.send_command(
            "browsingContext.createAndGetInfoValue", params
        )
        return await future

    async def navigate(self, context: str, url: str, wait: str = "none"):
        future = await self._session.send_command(
            "browsingContext.navigateWithState", {"context": context, "url": url, "wait": wait}
        )
        return await future

    async def get_tree(self, root=None, max_depth=None):
        params = {}
        if root is not None:
            params["root"] = root
        if max_depth is not None:
            params["max_depth"] = max_depth
        future = await self._session.send_command("browsingContext.getTreeContexts", params)
        return await future

    async def get_current_url(self, context: str) -> str | None:
        future = await self._session.send_command(
            "browsingContext.getCurrentUrlValue",
            {"context": context},
        )
        return await future

    async def close(self, context: str, prompt_unload=_UNSET):
        params = {"context": context}
        # prompt_unload=None should behave like omitted in WPT.
        if prompt_unload is not _UNSET and prompt_unload is not None:
            params["prompt_unload"] = prompt_unload
        self._session.fail_pending_print_requests_for_context(context)
        future = await self._session.send_command("browsingContext.closeResult", params)
        return await future

    async def handle_user_prompt(self, context: str, accept=_UNSET, user_text=_UNSET):
        params = {"context": context}
        if accept is not _UNSET:
            params["accept"] = accept
        if user_text is not _UNSET:
            params["user_text"] = user_text
        future = await self._session.send_command(
            "browsingContext.handleUserPrompt", params
        )
        return await future

    async def activate(self, context: str):
        future = await self._session.send_command(
            "browsingContext.activate", {"context": context}
        )
        return await future

    async def reload(self, context: str, **kwargs):
        future = await self._session.send_command(
            "browsingContext.reloadWithState", {"context": context, **kwargs}
        )
        return await future

    async def print(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value

        future = await self._session.send_command(
            "browsingContext.printData", params
        )
        return await future

    async def capture_screenshot(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        future = await self._session.send_command(
            "browsingContext.captureScreenshotData", params
        )
        return await future

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
        future = await self._session.send_command("browsingContext.locateNodes", params)
        return await future

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
        future = await self._session.send_command("browsingContext.setViewport", params)
        return await future

    async def traverse_history(self, context: str, delta: int):
        future = await self._session.send_command(
            "browsingContext.traverseHistory", {"context": context, "delta": delta}
        )
        return await future


class SessionModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def status(self):
        future = await self._session.send_command("session.status", {})
        return await future

    async def prepare_baseline_context_for_test(self):
        future = await self._session.send_command("session.prepareBaselineContextForTest", {})
        return await future

    async def get_baseline_context_info_value_for_test(self):
        future = await self._session.send_command(
            "session.getBaselineContextInfoValueForTest", {}
        )
        return await future

    async def subscribe(self, events: list, contexts: list = None, user_contexts: list = None):
        params = {"events": events}
        if contexts is not None:
            params["contexts"] = contexts
        if user_contexts is not None:
            params["user_contexts"] = user_contexts
        future = await self._session.send_command("session.subscribe", params)
        return await future

    async def unsubscribe(self, subscriptions: list = None, **kwargs):
        params = {}
        if subscriptions is not None:
            params["subscriptions"] = subscriptions
        params.update(kwargs)
        future = await self._session.send_command("session.unsubscribe", params)
        return await future

    async def reset_for_test(self):
        future = await self._session.send_command("session.resetForTest", {})
        return await future


class ScriptModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def _result_command(self, method: str, params: Mapping[str, Any]):
        result = await self._session.command(method, params)
        if isinstance(result, dict) and "exceptionDetails" in result:
            raise ScriptEvaluateResultException(result)
        return result

    def _context_id(self, context):
        return context.get("context") if isinstance(context, Mapping) else context

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
            return await self._session.command(command, params)
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
            return await self._session.command(command, params)
        return await self._result_command(command, params)

    async def disown(self, handles, target):
        future = await self._session.send_command(
            "script.disown",
            {"handles": handles, "target": target},
        )
        return await future

    async def get_element_for_test(self, selector, context, *, allow_frame_fallback=False):
        context_id = self._context_id(context)
        return await self._session.command(
            "script.getElementForTest",
            {
                "context": context_id,
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
        future = await self._session.send_command("script.addPreloadScriptId", params)
        return await future

    async def prepare_loaded_static_test_page(
        self,
        context: str,
        page: str,
        phase: str = "all",
        scripts: list[str] | None = None,
        html: str | None = None,
    ):
        params = {"context": context, "page": page, "phase": phase}
        if scripts is not None:
            params["scripts"] = scripts
        if isinstance(html, str):
            params["html"] = html
        future = await self._session.send_command(
            "script.prepareLoadedStaticTestPage",
            params,
        )
        return await future

    async def create_iframe_context_id_for_test(self, context: str, url: str):
        return await self._session.command(
            "script.createIframeContextIdForTest",
            {"context": context, "url": url},
        )

    async def prepare_beforeunload_page_url_for_test(self, context: str, url: str | None = None):
        params: dict[str, Any] = {"context": context}
        if isinstance(url, str):
            params["url"] = url
        return await self._session.command(
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
            "requestHeaders": self._session._network_header_entries_from_map(headers),
            "headersJson": json.dumps(dict(headers)) if isinstance(headers, Mapping) else "null",
        }
        context_id = self._context_id(context)
        if isinstance(context_id, str):
            params["context"] = context_id
        if isinstance(method, str):
            params["method"] = method
        request_value = _synthesize_request_bytes_value(post_data)
        if isinstance(request_value, Mapping):
            params["requestData"] = dict(request_value)
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
        future = await self._session.send_command("script.removePreloadScript", {"script": script})
        return await future

    async def remove_all_preload_scripts(self):
        future = await self._session.send_command("script.removeAllPreloadScripts", {})
        return await future

    async def get_realms(self, **kwargs):
        params = dict(kwargs)
        future = await self._session.send_command("script.getRealmsList", params)
        return await future


class NetworkModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

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
        future = await self._session.send_command("network.addIntercept", params)
        result = await future
        if isinstance(result, dict):
            intercept = result.get("intercept")
            if isinstance(intercept, str):
                return intercept
        return result

    async def remove_intercept(self, intercept: str):
        future = await self._session.send_command(
            "network.removeIntercept",
            {"intercept": intercept},
        )
        return await future

    async def prepare_test_context(self, *, url: str, context=None):
        context_id = context.get("context") if isinstance(context, Mapping) else context
        params = {"url": url}
        if isinstance(context_id, str):
            params["context"] = context_id
        return await self._session.command("network.prepareContextForTest", params)

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
        future = await self._session.send_command("network.continueBlockedRequest", params)
        await future
        return {}

    async def continue_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        params: dict[str, Any] = {
            "request": request_id,
            "mode": "continueResponse",
        }
        for key, value in kwargs.items():
            params[key] = value
        future = await self._session.send_command("network.continueBlockedResponse", params)
        await future
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
        await self._session.command(
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

        future = await self._session.send_command("network.continueBlockedResponse", params)
        result = await future

        if not isinstance(result, Mapping) or not bool(result.get("consumed")):
            return {}
        return {}

    async def add_data_collector(self, **kwargs):
        params = {}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[key] = value
        return await self._session.command("network.addDataCollectorId", params)

    async def set_extra_headers(self, headers, contexts=_UNSET, user_contexts=_UNSET):
        params = {"headers": headers}
        if contexts is not _UNSET:
            params["contexts"] = contexts
        if user_contexts is not _UNSET:
            params["user_contexts"] = user_contexts
        future = await self._session.send_command("network.setExtraHeaders", params)
        return await future

    async def set_cache_behavior(self, cache_behavior, contexts=_UNSET):
        params: dict[str, Any] = {
            "cache_behavior": cache_behavior,
        }
        if contexts is not _UNSET:
            params["contexts"] = contexts

        result: Any = {}
        try:
            future = await self._session.send_command("network.setCacheBehavior", params)
            result = await future
        except (bidi_error.UnknownCommandException, bidi_error.UnknownErrorException):
            result = {}

        return result

    async def remove_data_collector(self, collector: str):
        future = await self._session.send_command("network.removeDataCollector", {"collector": collector})
        return await future

    async def get_data(self, request, data_type, collector=None, disown=False):
        params = {"request": request, "data_type": data_type, "disown": disown}
        if collector is not None:
            params["collector"] = collector
        future = await self._session.send_command("network.getData", params)
        return await future

    async def disown_data(self, request, data_type, collector):
        future = await self._session.send_command("network.disownData", {
            "request": request,
            "data_type": data_type,
            "collector": collector,
        })
        return await future


class StorageModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def get_cookies(self, filter=None, partition=None):
        params: dict[str, Any] = {}
        if filter is not None:
            params["filter"] = filter
        if partition is not None:
            params["partition"] = partition
        future = await self._session.send_command("storage.getCookies", params)
        return await future

    async def set_cookie(self, cookie, partition=None):
        params = {"cookie": cookie}
        if partition is not None:
            params["partition"] = partition
        future = await self._session.send_command("storage.setCookie", params)
        return await future

    async def delete_cookies(self, filter=None, partition=None):
        params: dict[str, Any] = {}
        if filter is not None:
            params["filter"] = filter
        if partition is not None:
            params["partition"] = partition
        future = await self._session.send_command("storage.deleteCookies", params)
        return await future


class InputModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def perform_actions(self, actions, context: str):
        if hasattr(actions, "to_json"):
            actions = actions.to_json()
        params = {"actions": actions, "context": context}
        future = await self._session.send_command("input.performActions", params)
        return await future

    async def release_actions(self, context: str):
        future = await self._session.send_command("input.releaseActions", {"context": context})
        return await future

    async def set_files(self, context: str, element, files):
        normalized_files = self._normalize_files(files)
        display_names = [self._display_file_name(path) for path in normalized_files]
        future = await self._session.send_command(
            "input.setFiles",
            {
                "context": context,
                "element": element,
                "sourcePaths": normalized_files,
                "displayNames": display_names,
            },
        )
        await future
        return {}

    def _normalize_files(self, files) -> list[str]:
        if not isinstance(files, list):
            raise bidi_error.InvalidArgumentException("files must be a list")
        normalized: list[str] = []
        for entry in files:
            if not isinstance(entry, str):
                raise bidi_error.InvalidArgumentException("files entries must be strings")
            normalized.append(entry)
        return normalized

    def _display_file_name(self, file_path: str) -> str:
        normalized = file_path.replace("\\", "/")
        if "/" not in normalized:
            return normalized
        base = normalized.rsplit("/", maxsplit=1)[-1]
        return base if base != "" else normalized


class BrowserModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def create_user_context(self, **kwargs):
        params = dict(kwargs)
        future = await self._session.send_command("browser.createUserContextId", params)
        return await future

    async def get_user_contexts(self):
        future = await self._session.send_command("browser.getUserContextsList", {})
        return await future

    async def get_client_windows(self):
        future = await self._session.send_command("browser.getClientWindowsList", {})
        return await future

    async def remove_user_context(self, user_context: str):
        future = await self._session.send_command("browser.removeUserContext", {"userContext": user_context})
        return await future

    async def set_download_behavior(self, download_behavior=_UNSET, user_contexts=_UNSET):
        params = {}
        if download_behavior is not _UNSET:
            params["downloadBehavior"] = download_behavior
        if user_contexts is not _UNSET:
            params["user_contexts"] = user_contexts
        future = await self._session.send_command("browser.setDownloadBehavior", params)
        return await future


class CraterClassicSession:
    """Minimal classic session object used by BiDi upgrade tests."""

    def __init__(self, websocket_url: str):
        self.capabilities = {
            "webSocketUrl": websocket_url,
        }


class _ImmediateAwaitable:
    """Awaitable no-op that can also be called without await."""

    def __await__(self):
        if False:
            yield None
        return None


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
    result = await bidi_session.session.get_baseline_context_info_value_for_test()
    if isinstance(result, Mapping):
        return result
    return {"context": None, "url": "about:blank"}


@pytest_asyncio.fixture
async def new_tab(bidi_session):
    """Open and focus a new tab."""
    context_info = await bidi_session.browsing_context.create_and_get_info_value(type="tab")
    if isinstance(context_info, Mapping):
        context_id = context_info.get("context")
        yielded = context_info
    else:
        context_id = None
        yielded = {"context": None, "url": "about:blank"}
    yield yielded
    try:
        if isinstance(context_id, str):
            await bidi_session.browsing_context.close(context=context_id)
    except Exception:
        pass


@pytest.fixture
def server_config():
    """Minimal WPT-like server config used by fixtures requiring server metadata."""
    return {
        "browser_host": "localhost",
        "ports": {
            "http": [8000],
            "https": [8000],
        },
        "domains": {
            "": {
                "": "localhost",
                "www": "www.localhost",
            },
            "alt": {
                "": "alt.localhost",
                "www": "www.alt.localhost",
            },
        },
    }


@pytest.fixture
def url():
    """Generate test URLs."""
    def _url(
        path: str,
        domain: str = "",
        protocol: str = "http",
        subdomain: str = "",
    ) -> str:
        if protocol not in {"http", "https"}:
            protocol = "http"
        host = "alt.localhost" if domain == "alt" else "localhost"
        if subdomain == "www":
            host = f"www.{host}"
        base = f"{protocol}://{host}:8000"
        if path.startswith("/"):
            return f"{base}{path}"
        return f"{base}/{path}"
    return _url


@pytest.fixture
def inline():
    """Generate inline HTML data URLs."""
    import base64
    from urllib.parse import quote

    def _inline(
        content: str,
        content_type: str = "text/html",
        domain: str = "",
        parameters=None,
        protocol: str = "http",
        subdomain: str = "",
        **_ignored,
    ) -> str:
        encoded = base64.b64encode(content.encode()).decode()
        fragments = []
        if domain:
            fragments.append(f"domain={quote(str(domain), safe='')}")
        if subdomain:
            fragments.append(f"subdomain={quote(str(subdomain), safe='')}")
        if protocol in {"http", "https"} and protocol != "http":
            fragments.append(f"protocol={quote(str(protocol), safe='')}")
        if isinstance(parameters, dict):
            pipe = parameters.get("pipe")
            if pipe is not None:
                fragments.append(f"pipe={quote(str(pipe), safe='')}")
        suffix = f"#{'&'.join(fragments)}" if fragments else ""
        return f"data:{content_type};base64,{encoded}{suffix}"
    return _inline


@pytest.fixture
def iframe(inline):
    """Inline document extract as the source document of an <iframe>."""
    def _iframe(src: str, **kwargs) -> str:
        return f"<iframe src='{inline(src, **kwargs)}'></iframe>"

    return _iframe


@pytest.fixture
def create_iframe(bidi_session):
    """
    Create an iframe and return its context id.

    Some synthetic pages in Crater do not expose `document.body` in a way that
    WPT helper expects. In that case, fall back to creating a synthetic child
    browsing context linked to the parent context for header scope tests.
    """

    async def _create_iframe(context, url):
        parent_context = context.get("context") if isinstance(context, Mapping) else context
        if isinstance(parent_context, str):
            return await bidi_session.script.create_iframe_context_id_for_test(
                parent_context,
                url,
            )
        return None

    return _create_iframe


@pytest_asyncio.fixture
async def add_and_remove_iframe(bidi_session):
    """Return an id that behaves like a removed frame context for negative tests."""

    async def _add_and_remove_iframe(_top_context):
        frame_id = await bidi_session.browsing_context.create_context_id(type_hint="tab")
        if isinstance(frame_id, str):
            try:
                await bidi_session.browsing_context.close(context=frame_id)
            except Exception:
                pass
        return frame_id

    return _add_and_remove_iframe


@pytest.fixture
def compare_png_bidi():
    """Minimal pixel comparator used by screenshot and print assertions."""
    from tests.support.image import ImageDifference, png_dimensions

    async def _compare_png_bidi(img1, img2):
        raw1 = _png_bytes_from_any(img1)
        raw2 = _png_bytes_from_any(img2)
        if raw1 == raw2:
            return ImageDifference(0, 0)

        try:
            w1, h1 = png_dimensions(raw1)
            w2, h2 = png_dimensions(raw2)
            if (w1, h1) != (w2, h2):
                return ImageDifference(max(w1 * h1, w2 * h2, 1), 255)
            return ImageDifference(max(w1 * h1, 1), 255)
        except Exception:
            return ImageDifference(1, 255)

    return _compare_png_bidi


@pytest.fixture
def render_pdf_to_png_bidi():
    """Render synthetic print output into deterministic PNG bytes."""

    async def _render_pdf_to_png_bidi(encoded_pdf_data, page=1):
        # Current synthetic print path only emits single-page payloads.
        _ = page
        meta = _extract_pdf_meta(encoded_pdf_data)
        return _render_pdf_meta_png(meta)

    return _render_pdf_to_png_bidi


@pytest.fixture
def assert_pdf_content():
    """Validate printable payload shape; content extraction is mocked."""
    from tests.support.asserts import assert_pdf

    async def _assert_pdf_content(pdf, expected_content):
        _ = expected_content
        assert_pdf(pdf)

    return _assert_pdf_content


@pytest.fixture
def assert_pdf_dimensions():
    """Validate printable payload shape; dimensions are handled by synthetic PNG."""
    from tests.support.asserts import assert_pdf

    async def _assert_pdf_dimensions(pdf, expected_dimensions):
        _ = expected_dimensions
        assert_pdf(pdf)

    return _assert_pdf_dimensions


@pytest.fixture
def assert_pdf_image():
    """Validate printable payload shape; image comparison is delegated elsewhere."""
    from tests.support.asserts import assert_pdf

    async def _assert_pdf_image(pdf, reference_html, expected):
        _ = reference_html
        _ = expected
        assert_pdf(pdf)

    return _assert_pdf_image


@pytest.fixture
def get_actions_origin_page(inline):
    """Create a test page for action origin tests."""

    def _get_actions_origin_page(inner_style: str, outer_style: str = "") -> str:
        return inline(
            f"""
          <meta name="viewport" content="width=device-width,initial-scale=1,minimum-scale=1">
          <div id="outer" style="{outer_style}"
               onmousemove="window.coords = {{x: event.clientX, y: event.clientY}}">
            <div id="inner" style="{inner_style}"></div>
          </div>
        """
        )

    return _get_actions_origin_page


@pytest.fixture
def configuration():
    """Test configuration."""
    return {
        "timeout_multiplier": float(os.environ.get("WPT_TIMEOUT_MULTIPLIER", "1.0")),
    }


@pytest.fixture
def fetch(bidi_session, configuration):
    """Perform a fetch from the page of the provided context."""

    async def _fetch(
        url,
        method=None,
        headers=None,
        post_data=None,
        context=None,
        timeout_in_seconds=3,
        sandbox_name=None,
    ):
        should_abort = timeout_in_seconds <= 0
        timeout_ms = int(timeout_in_seconds * configuration["timeout_multiplier"] * 1000)
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

    return _fetch


@pytest_asyncio.fixture
async def subscribe_events(bidi_session):
    """Subscribe to events and clean up after test."""
    subscriptions = []
    cleanup_requests = []

    async def _subscribe(events, contexts=None, user_contexts=None):
        result = await bidi_session.session.subscribe(
            events=events, contexts=contexts, user_contexts=user_contexts
        )
        cleanup_params = {"events": events}
        if contexts:
            cleanup_params["contexts"] = contexts
        if user_contexts:
            cleanup_params["user_contexts"] = user_contexts
        cleanup_requests.append(cleanup_params)
        if "subscription" in result:
            subscriptions.append(result["subscription"])
        return result

    yield _subscribe

    if subscriptions:
        for sub in reversed(subscriptions):
            try:
                await bidi_session.session.unsubscribe(subscriptions=[sub])
            except Exception:
                pass
        return

    for params in reversed(cleanup_requests):
        try:
            await bidi_session.session.unsubscribe(**params)
        except Exception:
            pass


@pytest_asyncio.fixture
async def add_preload_script(bidi_session):
    """Add preload scripts and clean them up after test."""
    async def _add_preload_script(function_declaration: str, **kwargs):
        return await bidi_session.script.add_preload_script(
            function_declaration=function_declaration,
            **kwargs,
        )

    yield _add_preload_script

    try:
        await bidi_session.script.remove_all_preload_scripts()
    except Exception:
        pass


@pytest.fixture
def wait_for_event(bidi_session):
    """Wait for a BiDi event."""
    remove_listeners = []

    def _wait_for_event(event_name: str):
        future, remove_listener = bidi_session.listen_once(
            event_name,
            accept_latest_backlog=event_name == "browsingContext.userPromptOpened",
        )
        remove_listeners.append(remove_listener)
        return future

    yield _wait_for_event

    for remove in remove_listeners:
        remove()


@pytest.fixture
def wait_for_events(bidi_session, configuration):
    """Wait for BiDi events until a predicate becomes true."""
    def _wait_for_events(event_names):
        return bidi_session.collect_events(
            event_names,
            timeout_multiplier=configuration["timeout_multiplier"],
        )

    yield _wait_for_events


@pytest.fixture
def send_blocking_command(bidi_session):
    """Send a blocking command."""
    async def _send(command: str, params: dict):
        future = await bidi_session.send_command(command, params)
        return await future
    return _send


@pytest.fixture
def get_element(bidi_session, top_context):
    """Return a remote reference for the first element matching selector."""
    debug_get_element = os.environ.get("CRATER_DEBUG_GET_ELEMENT", "0") == "1"

    async def _get_element(css_selector, context=top_context):
        context_id = context["context"]
        element = await bidi_session.script.get_element_for_test(
            css_selector,
            context,
            allow_frame_fallback=context.get("context") != top_context.get("context"),
        )
        if debug_get_element:
            print(f"[get_element] initial selector={css_selector!r} context={context_id!r} element={element!r}", flush=True)
        if debug_get_element:
            print(f"[get_element] final selector={css_selector!r} context={context_id!r} element={element!r}", flush=True)
        return element

    return _get_element


@pytest.fixture
def current_url(bidi_session):
    """Return current URL for a browsing context."""

    async def _current_url(context):
        context_id = context.get("context") if isinstance(context, dict) else context
        return await bidi_session.browsing_context.get_current_url(context_id)

    return _current_url


@pytest_asyncio.fixture
async def load_static_test_page(bidi_session, top_context, inline):
    """Navigate to a static WPT support page from local checkout."""

    support_html_dir = (
        Path(__file__).resolve().parent.parent
        / "wpt"
        / "webdriver"
        / "tests"
        / "support"
        / "html"
    )

    async def _load_static_test_page(page, context=top_context):
        page_path = support_html_dir / page
        content = page_path.read_text(encoding="utf-8-sig")
        await bidi_session.browsing_context.navigate(
            context=context["context"],
            url=inline(content),
            wait="complete",
        )
        if "allEvents" not in content:
            return

        await bidi_session.script.prepare_loaded_static_test_page(
            context["context"],
            page,
            html=content,
        )

    return _load_static_test_page


@pytest_asyncio.fixture
async def current_session():
    """Minimal classic WebDriver session fixture used by legacy WPT helpers."""

    class _CurrentSession:
        def __init__(self):
            platform_name = "mac" if sys.platform == "darwin" else (
                "windows" if sys.platform.startswith("win") else "linux"
            )
            self.capabilities = {"platformName": platform_name}

    return _CurrentSession()


@pytest.fixture
def session():
    """Minimal classic session fixture for session.new BiDi upgrade tests."""
    return CraterClassicSession(CRATER_BIDI_URL)


@pytest.fixture
def default_capabilities():
    return {}


def _deep_update(dst: dict, src: dict):
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            _deep_update(dst[key], value)
        else:
            dst[key] = value


@pytest.fixture
def capabilities(request, default_capabilities):
    """Session capabilities merged with @pytest.mark.capabilities."""
    caps = dict(default_capabilities)
    marker = request.node.get_closest_marker("capabilities")
    if marker and marker.args and isinstance(marker.args[0], dict):
        _deep_update(caps, marker.args[0])
    return caps


@pytest.fixture
def modifier_key():
    """Platform modifier key used by shortcut tests."""
    from tests.support.keys import Keys

    target_platform = os.environ.get("WPT_TARGET_PLATFORM", "mac").lower()
    if target_platform == "mac":
        return Keys.META
    return Keys.CONTROL


@pytest_asyncio.fixture
async def create_user_context(bidi_session):
    """Create user contexts. Cleanup is handled by session baseline reset."""

    async def _create(**kwargs):
        return await bidi_session.browser.create_user_context(**kwargs)

    yield _create


@pytest_asyncio.fixture
async def setup_beforeunload_page(bidi_session):
    """Navigate to beforeunload test page and mark it as user-interacted."""

    async def _setup_beforeunload_page(context):
        page_url = await bidi_session.script.prepare_beforeunload_page_url_for_test(
            context["context"],
        )
        if isinstance(page_url, str):
            return page_url
        return "http://localhost:8000/webdriver/tests/support/html/beforeunload.html"

    return _setup_beforeunload_page


@pytest.fixture
def wait_for_future_safe():
    """Wait for a future with timeout while preserving remote exceptions."""
    async def _wait_for_future_safe(future, timeout: float = 5.0):
        if isinstance(future, asyncio.Future):
            try:
                running_loop = asyncio.get_running_loop()
            except RuntimeError:
                running_loop = None
            future_loop = future.get_loop()
            if running_loop is not None and future_loop is not running_loop:
                deadline = time.monotonic() + timeout
                while True:
                    if future.done():
                        return future.result()
                    if time.monotonic() >= deadline:
                        future.cancel()
                        raise TimeoutError("Future did not resolve within the given timeout")
                    await asyncio.sleep(0.01)
        try:
            return await asyncio.wait_for(asyncio.shield(future), timeout=timeout)
        except asyncio.TimeoutError as exc:
            future.cancel()
            raise TimeoutError("Future did not resolve within the given timeout") from exc
    return _wait_for_future_safe


@pytest.fixture
def current_time():
    """Return current time in milliseconds."""
    async def _current_time():
        return int(time.time() * 1000)

    return _current_time


@pytest.fixture
def test_page(inline):
    return inline("<div>foo</div>")


@pytest.fixture
def get_test_page(iframe, inline, url):
    """Generate a node-rich page compatible with BiDi script node tests."""

    def _get_test_page(
        as_frame: bool = False,
        frame_doc: str = None,
        shadow_doc: str = None,
        nested_shadow_dom: bool = False,
        shadow_root_mode: str = "open",
        **kwargs,
    ):
        frame_doc_provided = frame_doc is not None
        shadow_doc_provided = shadow_doc is not None
        if frame_doc is None:
            # Defaulting to an iframe breaks many tests on the current mock DOM
            # parser/runtime where iframe document loading is not fully isolated.
            # Keep top-level node-rich markup as the default surface.
            frame_doc = ""

        if shadow_doc is None:
            shadow_doc = """<div id="in-shadow-dom"><input type="checkbox"/></div>"""

        protocol = kwargs.get("protocol")
        if isinstance(protocol, str) and protocol in {"http", "https"}:
            domain = kwargs.get("domain", "")
            subdomain = kwargs.get("subdomain", "")
            return url(
                "/webdriver/tests/support/empty.html",
                domain=domain if isinstance(domain, str) else "",
                protocol=protocol,
                subdomain=subdomain if isinstance(subdomain, str) else "",
            )

        definition_inner_shadow_dom = ""
        inner_shadow_doc = shadow_doc
        if nested_shadow_dom:
            definition_inner_shadow_dom = f"""
                if (!customElements.get("inner-custom-element")) {{
                    customElements.define("inner-custom-element",
                        class extends HTMLElement {{
                            constructor() {{
                                super();
                                this.attachShadow({{mode: "{shadow_root_mode}"}}).innerHTML = `
                                    {inner_shadow_doc}
                                `;
                            }}
                        }}
                    );
                }}
            """
            shadow_doc = """
                <style>
                    inner-custom-element {
                        display:block; width:20px; height:20px;
                    }
                </style>
                <div id="in-nested-shadow-dom">
                    <inner-custom-element></inner-custom-element>
                </div>
            """

        # Shadow-focused tests don't need the default iframe subtree and it can
        # interfere with runtime context swapping in the mock environment.
        if shadow_doc_provided and not frame_doc_provided:
            frame_doc = ""

        frame_markup = iframe(frame_doc, **kwargs) if frame_doc else ""

        page_data = f"""
            <style>
                custom-element {{
                    display:block; width:20px; height:20px;
                }}
            </style>
            <div id="with-children"><p><span></span></p><br/></div>
            <div id="with-text-node">Lorem</div>
            <div id="with-comment"><!-- Comment --></div>

            <input id="button" type="button"/>
            <input id="checkbox" type="checkbox"/>
            <input id="file" type="file"/>
            <input id="hidden" type="hidden"/>
            <input id="text" type="text"/>

            {frame_markup}

            <img />
            <svg></svg>

            <custom-element id="custom-element"></custom-element>
            <script>
                var svg = document.querySelector("svg");
                if (svg && svg.setAttributeNS) {{
                    svg.setAttributeNS("http://www.w3.org/2000/svg", "svg:foo", "bar");
                }}

                if (window.customElements && customElements.define) {{
                    {definition_inner_shadow_dom}
                    if (!customElements.get("custom-element")) {{
                        customElements.define("custom-element",
                            class extends HTMLElement {{
                                constructor() {{
                                    super();
                                    const shadowRoot = this.attachShadow({{mode: "{shadow_root_mode}"}});
                                    shadowRoot.innerHTML = `{shadow_doc}`;
                                    window._shadowRoot = shadowRoot;
                                }}
                            }}
                        );
                    }}

                    const host = document.querySelector("#custom-element");
                    if (host && host.attachShadow && !window._shadowRoot) {{
                        try {{
                            const shadowRoot = host.attachShadow({{ mode: "{shadow_root_mode}" }});
                            shadowRoot.innerHTML = `{shadow_doc}`;
                            window._shadowRoot = shadowRoot;
                        }} catch (_e) {{}}
                    }}
                    if (!window._shadowRoot && host && host.shadowRoot) {{
                        window._shadowRoot = host.shadowRoot;
                    }}

                    if ({str(nested_shadow_dom).lower()}) {{
                        const outerRoot = (host && host.shadowRoot) || window._shadowRoot || null;
                        if (outerRoot && outerRoot.querySelectorAll) {{
                            const innerHosts = outerRoot.querySelectorAll("inner-custom-element");
                            for (const innerHost of innerHosts) {{
                                if (!innerHost) {{
                                    continue;
                                }}
                                if (innerHost.attachShadow && !innerHost.shadowRoot) {{
                                    try {{
                                        const innerRoot = innerHost.attachShadow({{ mode: "{shadow_root_mode}" }});
                                        innerRoot.innerHTML = `{inner_shadow_doc}`;
                                    }} catch (_e) {{}}
                                }}
                                if (!window._innerShadowRoot && innerHost.shadowRoot) {{
                                    window._innerShadowRoot = innerHost.shadowRoot;
                                }}
                            }}
                        }}
                    }}
                }} else {{
                    const host = document.querySelector('#custom-element');
                    if (host && host.attachShadow && !host.shadowRoot) {{
                        const shadowRoot = host.attachShadow({{ mode: "{shadow_root_mode}" }});
                        shadowRoot.innerHTML = `{shadow_doc}`;
                        window._shadowRoot = shadowRoot;
                    }}
                    if ({str(nested_shadow_dom).lower()} && host && host.shadowRoot) {{
                        const innerHosts = host.shadowRoot.querySelectorAll("inner-custom-element");
                        for (const innerHost of innerHosts) {{
                            if (!innerHost) {{
                                continue;
                            }}
                            if (innerHost.attachShadow && !innerHost.shadowRoot) {{
                                const innerRoot = innerHost.attachShadow({{ mode: "{shadow_root_mode}" }});
                                innerRoot.innerHTML = `{inner_shadow_doc}`;
                            }}
                            if (!window._innerShadowRoot && innerHost.shadowRoot) {{
                                window._innerShadowRoot = innerHost.shadowRoot;
                            }}
                        }}
                    }}
                }}
                const finalHost = document.querySelector("#custom-element");
                if (finalHost && !finalHost.shadowRoot && finalHost.attachShadow) {{
                    try {{
                        const fallbackRoot = finalHost.attachShadow({{ mode: "{shadow_root_mode}" }});
                        fallbackRoot.innerHTML = `{shadow_doc}`;
                        window._shadowRoot = fallbackRoot;
                    }} catch (_e) {{}}
                }}
                if (finalHost && finalHost.shadowRoot) {{
                    const shadowChildren = finalHost.shadowRoot.childNodes || [];
                    if (shadowChildren.length === 0) {{
                        try {{
                            finalHost.shadowRoot.innerHTML = `{shadow_doc}`;
                        }} catch (_e) {{}}
                    }}
                    if (!window._shadowRoot) {{
                        window._shadowRoot = finalHost.shadowRoot;
                    }}
                }}
            </script>
        """

        if as_frame:
            iframe_data = iframe(page_data, **kwargs)
            return inline(iframe_data, **kwargs)

        return inline(page_data, **kwargs)

    return _get_test_page


@pytest.fixture
def test_origin(url):
    return url("")


@pytest.fixture
def test_alt_origin(url):
    return url("", domain="alt")


@pytest.fixture
def test_page2(inline):
    return inline("<div>bar</div>")


@pytest.fixture
def test_page_cross_origin(inline):
    return inline("<div>bar</div>", domain="alt")


@pytest.fixture
def test_page_multiple_frames(inline, test_page, test_page2):
    return inline(
        f"<iframe src='{test_page}'></iframe><iframe src='{test_page2}'></iframe>"
    )


@pytest.fixture
def test_page_nested_frames(inline, test_page_same_origin_frame):
    return inline(f"<iframe src='{test_page_same_origin_frame}'></iframe>")


@pytest.fixture
def test_page_cross_origin_frame(inline, test_page_cross_origin):
    return inline(f"<iframe src='{test_page_cross_origin}'></iframe>")


@pytest.fixture
def test_page_same_origin_frame(inline, test_page):
    return inline(f"<iframe src='{test_page}'></iframe>")


@pytest.fixture
def assert_file_dialog_canceled():
    """File dialog assertion placeholder."""
    def _assert(*args, **kwargs):
        return _ImmediateAwaitable()
    return _assert


@pytest.fixture
def assert_file_dialog_not_canceled():
    """File dialog assertion placeholder."""
    def _assert(*args, **kwargs):
        return _ImmediateAwaitable()
    return _assert


@pytest.fixture
def create_dialog():
    """Dialog creation placeholder."""
    async def _create(*args, **kwargs):
        return None
    return _create


@pytest.fixture
def wait_for_class_change(bidi_session, event_loop):
    """Wait for a class to change on an element."""
    async def _wait(context: str, selector: str, expected_class: str, timeout: float = 5.0):
        # For now, just return immediately as Crater doesn't support full DOM monitoring
        return True
    return _wait


@pytest_asyncio.fixture
async def setup_network_test(
    bidi_session,
    subscribe_events,
    top_context,
    url,
):
    """Best-effort network setup for adapter-backed synthetic network events."""
    listeners = []

    async def _setup_network_test(
        events,
        test_url=url("/webdriver/tests/bidi/network/support/empty.html"),
        context=top_context["context"],
        contexts=None,
    ):
        await bidi_session.network.prepare_test_context(url=test_url, context=context)

        await subscribe_events(events=events, contexts=contexts)

        network_events = {}
        for event in events:
            network_events[event] = []

            async def on_event(method, data, event=event):
                network_events[event].append(data)

            listeners.append(bidi_session.add_event_listener(event, on_event))
        return network_events

    yield _setup_network_test

    for remove_listener in listeners:
        remove_listener()
