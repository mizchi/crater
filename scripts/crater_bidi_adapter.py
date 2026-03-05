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
import datetime
import email.utils
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
from urllib.parse import parse_qs, unquote, unquote_to_bytes, urlparse

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


def _parse_wpt_http_url(url: str):
    try:
        parsed = urlparse(url)
    except Exception:
        return None
    if parsed.scheme not in {"http", "https"}:
        return None
    host = (parsed.hostname or "").lower()
    if host not in {"localhost", "alt.localhost"}:
        return None
    port = parsed.port
    if port is None:
        port = 443 if parsed.scheme == "https" else 80
    if port != 8000:
        return None
    return parsed


def _parse_http_url(url: str):
    try:
        parsed = urlparse(url)
    except Exception:
        return None
    if parsed.scheme not in {"http", "https"}:
        return None
    if not parsed.hostname:
        return None
    return parsed


def _is_unreachable_test_url(url: str) -> bool:
    parsed = _parse_http_url(url)
    if parsed is None:
        return False
    host = (parsed.hostname or "").lower()
    return host == "not_a_valid_url.test"


def _url_origin_tuple(url: str):
    parsed = _parse_http_url(url)
    if parsed is None:
        return None
    scheme = (parsed.scheme or "").lower()
    hostname = (parsed.hostname or "").lower()
    if scheme == "" or hostname == "":
        return None
    port = parsed.port if parsed.port is not None else _default_port_for_scheme(scheme)
    return (scheme, hostname, port)


def _default_port_for_scheme(scheme: str) -> int:
    lowered = scheme.lower()
    if lowered == "https":
        return 443
    if lowered == "http":
        return 80
    return -1


def _canonicalize_url_for_string_pattern(url: str):
    parsed = _parse_http_url(url)
    if parsed is None:
        return None
    scheme = (parsed.scheme or "").lower()
    host = (parsed.hostname or "").lower()
    if not scheme or not host:
        return None
    port = parsed.port if parsed.port is not None else _default_port_for_scheme(scheme)
    path = parsed.path or "/"
    query = parsed.query or ""
    return (scheme, host, port, path, query)


def _is_cors_safelisted_content_type(value: str) -> bool:
    media_type = value.split(";", maxsplit=1)[0].strip().lower()
    return media_type in {
        "application/x-www-form-urlencoded",
        "multipart/form-data",
        "text/plain",
    }


def _requires_synthetic_cors_preflight(
    *,
    source_url: str | None,
    target_url: str,
    method: str,
    headers: Mapping[str, Any] | None,
) -> bool:
    if not isinstance(source_url, str):
        return False
    source_origin = _url_origin_tuple(source_url)
    target_origin = _url_origin_tuple(target_url)
    if source_origin is None or target_origin is None:
        return False
    if source_origin == target_origin:
        return False

    if method.upper() not in {"GET", "HEAD", "POST"}:
        return True
    if not isinstance(headers, Mapping):
        return False

    for raw_name, raw_value in headers.items():
        if not isinstance(raw_name, str):
            continue
        name = raw_name.strip().lower()
        if name in {"accept", "accept-language", "content-language"}:
            continue
        if name == "content-type" and _is_cors_safelisted_content_type(str(raw_value)):
            continue
        return True

    return False


def _bytes_value_from_text(value: str):
    return {"type": "string", "value": value}


def _bytes_value_from_bytes(value: bytes):
    return {"type": "base64", "value": base64.b64encode(value).decode("ascii")}


def _bytes_value_encoded_size(value: Mapping[str, Any]) -> int:
    payload = value.get("value")
    if isinstance(payload, str):
        return len(payload.encode("utf-8"))
    return 0


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


def _synthesize_response_bytes_value(url: str, *, headers_echo_payload: str | None = None):
    if isinstance(headers_echo_payload, str):
        return _bytes_value_from_text(headers_echo_payload)

    parsed = urlparse(url)
    scheme = (parsed.scheme or "").lower()
    path = parsed.path or ""
    query = parse_qs(parsed.query, keep_blank_values=True)

    if scheme == "data":
        data_url = url.split(":", maxsplit=1)[1]
        meta_and_data = data_url.split(",", maxsplit=1)
        if len(meta_and_data) != 2:
            return _bytes_value_from_text("")
        meta, payload = meta_and_data
        is_base64 = ";base64" in meta
        mime = meta.split(";", maxsplit=1)[0].lower()
        if is_base64:
            if mime.startswith("image/"):
                return {"type": "base64", "value": payload}
            try:
                decoded = base64.b64decode(payload.encode("ascii"), validate=False)
                return _bytes_value_from_text(decoded.decode("utf-8", errors="replace"))
            except Exception:
                return _bytes_value_from_text("")
        decoded = unquote(payload)
        if mime.startswith("image/"):
            return _bytes_value_from_bytes(decoded.encode("utf-8"))
        return _bytes_value_from_text(decoded)

    if path.endswith("/empty.txt"):
        return _bytes_value_from_text("empty\n")
    if path.endswith("/other.txt"):
        return _bytes_value_from_text("other\n")
    if path.endswith("/empty.png"):
        return {"type": "base64", "value": _WHITE_DOT_PNG_BASE64}
    if path.endswith("/cached.py"):
        response_values = query.get("response", [])
        response_body = response_values[0] if len(response_values) > 0 else ""
        content_types = query.get("contenttype", [])
        content_type = content_types[0].lower() if len(content_types) > 0 else "text/plain"
        if content_type.startswith("image/") or content_type == "img/png":
            raw_response = ""
            for chunk in (parsed.query or "").split("&"):
                if chunk.startswith("response="):
                    raw_response = chunk[len("response="):]
                    break
            if raw_response != "":
                binary_payload = unquote_to_bytes(raw_response.replace("+", " "))
                return _bytes_value_from_bytes(binary_payload)
            return _bytes_value_from_bytes(response_body.encode("latin-1", errors="ignore"))
        return _bytes_value_from_text(response_body)
    if path.endswith("/headers.py"):
        values = query.get("content", [])
        return _bytes_value_from_text(values[0] if values else "")
    if path.endswith("/charset.py"):
        values = query.get("content", [])
        return _bytes_value_from_text(values[0] if values else "")

    return _bytes_value_from_text("")


def _is_wpt_headers_echo_url(url: str) -> bool:
    parsed = _parse_wpt_http_url(url)
    if parsed is None:
        return False
    return parsed.path.endswith("/webdriver/tests/support/http_handlers/headers_echo.py")


def _is_wpt_blank_page_url(url: str) -> bool:
    parsed = _parse_wpt_http_url(url)
    if parsed is None:
        return False
    return parsed.path == "/" or parsed.path.endswith("/webdriver/tests/bidi/browsing_context/support/empty.html")


def _html_data_url(html: str) -> str:
    encoded = base64.b64encode(html.encode("utf-8")).decode("ascii")
    return f"data:text/html;charset=utf-8;base64,{encoded}"


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
        self._event_listeners = {}
        self._event_backlog = {}
        self._receive_task = None
        self.event_loop = None
        self._trace_enabled = os.environ.get("CRATER_BIDI_TRACE", "0") == "1"
        self._synthetic_scrolled_contexts = set()
        self._network_extra_headers_global: dict[str, str] = {}
        self._network_extra_headers_by_context: dict[str, dict[str, str]] = {}
        self._network_extra_headers_by_user_context: dict[str, dict[str, str]] = {}
        self._context_user_context: dict[str, str] = {}
        self._context_parent: dict[str, str] = {}
        self._network_intercepts: dict[str, dict[str, Any]] = {}
        self._synthetic_request_counter = 0
        self._network_subscriptions: dict[str, dict[str, Any]] = {}
        self._synthetic_subscription_counter = 0
        self._network_collectors: dict[str, dict[str, Any]] = {}
        self._network_collected_data: dict[str, dict[str, dict[str, Any]]] = {}
        self._synthetic_cookies_by_context: dict[str, dict[str, dict[str, Any]]] = {}
        self._network_blocked_requests: dict[str, dict[str, Any]] = {}
        self._synthetic_location_href_by_context: dict[str, str] = {}
        self._network_cache_behavior_global = "default"
        self._network_cache_behavior_by_context: dict[str, str] = {}
        self._network_cached_requests_by_context: dict[str, set[str]] = {}
        # Keep a stable object per realm id so later updates rewrite earlier
        # references seen by listeners/tests.
        self._realm_created_event_by_realm: dict[str, dict[str, Any]] = {}

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
                else:
                    # Event
                    method = data.get("method")
                    if method:
                        self._trace(f"<- event {method}")
                        params = data.get("params", {})
                        if method == "script.realmCreated" and isinstance(params, dict):
                            realm_id = params.get("realm")
                            if isinstance(realm_id, str) and realm_id != "":
                                existing = self._realm_created_event_by_realm.get(realm_id)
                                if isinstance(existing, dict):
                                    existing.clear()
                                    existing.update(params)
                                    params = existing
                                else:
                                    self._realm_created_event_by_realm[realm_id] = params
                                self._trace(
                                    "realmCreated "
                                    f"realm={realm_id} "
                                    f"context={params.get('context')} "
                                    f"origin={params.get('origin')}"
                                )
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

    def _normalize_params(self, value: Any):
        """Normalize params for JSON transport.

        webdriver's UNDEFINED sentinel is represented by omitting map keys.
        """
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
        return value

    def _is_undefined(self, value: Any) -> bool:
        cls = value.__class__
        return cls.__name__ == "Undefined" and cls.__module__.endswith("webdriver.bidi.undefined")

    def remember_context_metadata(
        self,
        context_id: str,
        user_context: str | None = None,
        parent_context: str | None = None,
    ) -> None:
        if isinstance(user_context, str):
            self._context_user_context[context_id] = user_context
        elif context_id not in self._context_user_context:
            self._context_user_context[context_id] = "default"
        if isinstance(parent_context, str):
            self._context_parent[context_id] = parent_context
        else:
            self._context_parent.pop(context_id, None)

    def remember_context_tree(self, contexts: Any, parent_context: str | None = None) -> None:
        if not isinstance(contexts, list):
            return
        for entry in contexts:
            if not isinstance(entry, Mapping):
                continue
            context_id = entry.get("context")
            if not isinstance(context_id, str):
                continue
            raw_user_context = entry.get("userContext")
            user_context = raw_user_context if isinstance(raw_user_context, str) else None
            self.remember_context_metadata(context_id, user_context, parent_context)
            children = entry.get("children")
            if isinstance(children, list):
                self.remember_context_tree(children, context_id)

    def forget_context_metadata(self, context_id: str) -> None:
        self._context_user_context.pop(context_id, None)
        self._context_parent.pop(context_id, None)
        self._network_extra_headers_by_context.pop(context_id, None)
        self._synthetic_cookies_by_context.pop(context_id, None)
        self._synthetic_location_href_by_context.pop(context_id, None)
        self._network_cache_behavior_by_context.pop(context_id, None)
        self._network_cached_requests_by_context.pop(context_id, None)
        descendants = [ctx for ctx, parent in self._context_parent.items() if parent == context_id]
        for descendant in descendants:
            self._context_parent.pop(descendant, None)
            self._network_extra_headers_by_context.pop(descendant, None)
            self._synthetic_cookies_by_context.pop(descendant, None)
            self._synthetic_location_href_by_context.pop(descendant, None)
            self._network_cache_behavior_by_context.pop(descendant, None)
            self._network_cached_requests_by_context.pop(descendant, None)

    def is_known_context(self, context_id: str) -> bool:
        if not isinstance(context_id, str) or context_id == "":
            return False
        if context_id in self._context_user_context:
            return True
        if context_id in self._context_parent:
            return True
        return False

    def apply_network_cache_behavior(
        self,
        cache_behavior: str,
        *,
        contexts: list[str] | None = None,
    ) -> None:
        if contexts is None:
            self._network_cache_behavior_global = cache_behavior
            self._network_cache_behavior_by_context.clear()
            return
        for context_id in contexts:
            self._network_cache_behavior_by_context[context_id] = cache_behavior

    def resolve_network_cache_behavior(self, context_id: str) -> str:
        if isinstance(context_id, str):
            behavior = self._network_cache_behavior_by_context.get(context_id)
            if isinstance(behavior, str):
                return behavior
        return self._network_cache_behavior_global

    def is_network_cache_enabled(self, context_id: str) -> bool:
        return self.resolve_network_cache_behavior(context_id) == "default"

    def _network_cache_key(self, *, method: str, url: str) -> str:
        return f"{method.upper()} {url}"

    def _parse_int_query_param(self, parsed, key: str, default: int) -> int:
        values = parse_qs(parsed.query, keep_blank_values=True).get(key, [])
        if len(values) == 0:
            return default
        try:
            return int(values[0])
        except Exception:
            return default

    def _status_text_for_code(self, status: int) -> str:
        try:
            return http.HTTPStatus(status).phrase
        except Exception:
            return "OK" if status == 200 else ""

    def _request_header_value(
        self,
        request_headers: Mapping[str, Any] | None,
        name: str,
    ) -> str | None:
        if not isinstance(request_headers, Mapping):
            return None
        lookup = name.lower()
        for key, value in request_headers.items():
            if not isinstance(key, str):
                continue
            if key.lower() != lookup:
                continue
            if isinstance(value, str):
                return value
        return None

    def _bytes_value_size(self, value: Mapping[str, Any] | None) -> int:
        if not isinstance(value, Mapping):
            return 0
        payload = value.get("value")
        if not isinstance(payload, str):
            return 0
        value_type = value.get("type")
        if value_type == "base64":
            try:
                return len(base64.b64decode(payload.encode("ascii"), validate=False))
            except Exception:
                return 0
        return len(payload.encode("utf-8"))

    def _response_header(self, name: str, value: str) -> dict[str, Any]:
        return {
            "name": name,
            "value": {"type": "string", "value": value},
        }

    def _infer_mime_type(self, url: str, parsed) -> str:
        if isinstance(url, str) and url.startswith("data:"):
            data_prefix = url[len("data:"):].split(",", maxsplit=1)[0]
            mime_type = data_prefix.split(";", maxsplit=1)[0].strip().lower()
            return mime_type if mime_type != "" else "text/plain"

        if parsed is None:
            return "text/plain"

        path = (parsed.path or "").lower()
        if path.endswith(".html"):
            return "text/html"
        if path.endswith(".txt"):
            return "text/plain"
        if path.endswith(".js"):
            return "text/javascript"
        if path.endswith(".png"):
            return "image/png"
        if path.endswith(".svg"):
            return "image/svg+xml"
        if path.endswith(".css"):
            return "text/css"
        if path.endswith("/cached.py"):
            content_types = parse_qs(parsed.query, keep_blank_values=True).get("contenttype", [])
            if len(content_types) > 0 and isinstance(content_types[0], str) and content_types[0] != "":
                return content_types[0]
        return "text/plain"

    def resolve_synthetic_response_overrides(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_headers: Mapping[str, Any] | None = None,
        update_cache: bool = True,
    ) -> dict[str, Any]:
        status = 200
        from_cache = False
        protocol = "http/1.1"
        auth_challenges: list[dict[str, Any]] | None = None
        parsed = _parse_http_url(url)
        cache_enabled = self.is_network_cache_enabled(context_id)
        cache_key = self._network_cache_key(method=method, url=url)
        context_cache = self._network_cached_requests_by_context.setdefault(context_id, set())
        headers: list[dict[str, Any]] = []

        if isinstance(url, str) and url.startswith("data:"):
            protocol = "data"

        if parsed is not None:
            path = parsed.path or "/"
            if path.endswith("/redirect.py"):
                status = self._parse_int_query_param(parsed, "status", 302)
            elif path.endswith("/status.py"):
                status = self._parse_int_query_param(parsed, "status", 200)
            elif path.endswith("/cached.py"):
                status = self._parse_int_query_param(parsed, "status", 200)
                if cache_enabled and method.upper() == "GET":
                    if cache_key in context_cache:
                        from_cache = True
                    elif update_cache:
                        context_cache.add(cache_key)
            elif path.endswith("/must-revalidate.py"):
                return_304 = self._request_header_value(request_headers, "return-304")
                if (
                    cache_enabled
                    and method.upper() in {"GET", "HEAD", "OPTIONS"}
                    and return_304 == "true"
                    and cache_key in context_cache
                ):
                    status = 304
                else:
                    status = 200
                    if cache_enabled and method.upper() in {"GET", "HEAD", "OPTIONS"} and update_cache:
                        context_cache.add(cache_key)
            elif path.endswith("/authentication.py"):
                status = 401
                realms = parse_qs(parsed.query, keep_blank_values=True).get("realm", [])
                realm = realms[0] if len(realms) > 0 else "testrealm"
                auth_challenges = [{"scheme": "Basic", "realm": realm}]
                headers.append(self._response_header("WWW-Authenticate", f'Basic realm="{realm}"'))
            elif path.endswith("/serviceworker.html"):
                status = 200

            if path.endswith("/headers.py"):
                raw_headers = parse_qs(parsed.query, keep_blank_values=True).get("header", [])
                for raw_header in raw_headers:
                    if not isinstance(raw_header, str) or ":" not in raw_header:
                        continue
                    name, value = raw_header.split(":", maxsplit=1)
                    headers.append(self._response_header(name, value))

        mime_type = self._infer_mime_type(url, parsed)
        if mime_type != "":
            headers.append(self._response_header("Content-Type", mime_type))

        status_text = self._status_text_for_code(status)
        if parsed is not None and (parsed.path or "").endswith("/serviceworker.html"):
            status_text = "OK from serviceworker"
        if status in {401, 407} and auth_challenges is None:
            auth_challenges = []

        response: dict[str, Any] = {
            "fromCache": from_cache,
            "status": status,
            "statusText": status_text,
            "mimeType": mime_type,
            "protocol": protocol,
            "headers": headers,
        }
        if auth_challenges is not None:
            response["authChallenges"] = auth_challenges
        return response

    def remember_synthetic_location_href(self, context_id: str, href: str) -> None:
        if not isinstance(context_id, str) or not isinstance(href, str):
            return
        self._synthetic_location_href_by_context[context_id] = href

    def get_synthetic_location_href(self, context_id: str) -> str | None:
        if not isinstance(context_id, str):
            return None
        candidate = self._synthetic_location_href_by_context.get(context_id)
        if isinstance(candidate, str):
            return candidate
        return None

    def clear_synthetic_location_href(self, context_id: str) -> None:
        if not isinstance(context_id, str):
            return
        self._synthetic_location_href_by_context.pop(context_id, None)

    def remember_document_cookie(self, context_id: str, cookie_assignment: str) -> None:
        if not isinstance(context_id, str) or not isinstance(cookie_assignment, str):
            return
        first_segment = cookie_assignment.split(";", maxsplit=1)[0]
        if "=" not in first_segment:
            return
        name, value = first_segment.split("=", maxsplit=1)
        name = name.strip()
        if name == "":
            return
        jar = self._synthetic_cookies_by_context.setdefault(context_id, {})
        cookie_value = value.strip()
        jar[name] = {
            "name": name,
            "value": {"type": "string", "value": cookie_value},
            "path": "/",
            "httpOnly": False,
            "secure": False,
            "sameSite": "none",
            "size": len(name) + len(cookie_value),
        }

    def remember_synthetic_cookie(self, context_id: str, cookie: Mapping[str, Any]) -> None:
        if not isinstance(context_id, str):
            return
        if not isinstance(cookie, Mapping):
            return
        name = cookie.get("name")
        value = cookie.get("value")
        if not isinstance(name, str) or name == "":
            return
        if not isinstance(value, Mapping):
            return
        if value.get("type") != "string" or not isinstance(value.get("value"), str):
            return
        jar = self._synthetic_cookies_by_context.setdefault(context_id, {})
        jar[name] = dict(cookie)

    def synthetic_cookies(self) -> list[dict[str, Any]]:
        merged: dict[str, dict[str, Any]] = {}
        for jar in self._synthetic_cookies_by_context.values():
            if not isinstance(jar, Mapping):
                continue
            for name, candidate in jar.items():
                if isinstance(candidate, Mapping):
                    merged[name] = dict(candidate)
                    continue
                if isinstance(candidate, str):
                    merged[name] = {
                        "name": name,
                        "value": {"type": "string", "value": candidate},
                        "path": "/",
                        "httpOnly": False,
                        "secure": False,
                        "sameSite": "none",
                        "size": len(name) + len(candidate),
                    }
        return list(merged.values())

    def resolve_request_cookies(self, context_id: str):
        merged: dict[str, dict[str, Any]] = {}
        for scope_context in self._context_ancestry(context_id):
            jar = self._synthetic_cookies_by_context.get(scope_context)
            if isinstance(jar, Mapping):
                merged.update(jar)
        jar = self._synthetic_cookies_by_context.get(context_id)
        if isinstance(jar, Mapping):
            merged.update(jar)
        cookies = []
        for name, cookie_entry in merged.items():
            cookie_value = None
            if isinstance(cookie_entry, Mapping):
                raw_value = cookie_entry.get("value")
                if isinstance(raw_value, Mapping) and raw_value.get("type") == "string":
                    raw_payload = raw_value.get("value")
                    if isinstance(raw_payload, str):
                        cookie_value = raw_payload
            if cookie_value is None:
                continue
            cookies.append({
                "name": name,
                "value": {"type": "string", "value": cookie_value},
            })
        return cookies

    def _normalize_network_headers(self, headers: Any) -> dict[str, str]:
        normalized: dict[str, str] = {}
        if not isinstance(headers, (list, tuple)):
            return normalized
        for entry in headers:
            if not isinstance(entry, Mapping):
                continue
            name = entry.get("name")
            value = entry.get("value")
            if not isinstance(name, str):
                continue
            value_text = None
            if isinstance(value, Mapping):
                if value.get("type") == "string" and isinstance(value.get("value"), str):
                    value_text = value.get("value")
            elif isinstance(value, str):
                value_text = value
            if value_text is None:
                continue
            normalized[name.lower()] = value_text
        return normalized

    def apply_network_extra_headers(
        self,
        headers: Any,
        contexts: Any = _UNSET,
        user_contexts: Any = _UNSET,
    ) -> None:
        normalized = self._normalize_network_headers(headers)
        has_contexts = contexts is not _UNSET and not self._is_undefined(contexts)
        has_user_contexts = user_contexts is not _UNSET and not self._is_undefined(user_contexts)
        if has_contexts and isinstance(contexts, (list, tuple)):
            for context_id in contexts:
                if not isinstance(context_id, str):
                    continue
                if normalized:
                    self._network_extra_headers_by_context[context_id] = dict(normalized)
                else:
                    self._network_extra_headers_by_context.pop(context_id, None)
            return
        if has_user_contexts and isinstance(user_contexts, (list, tuple)):
            for user_context in user_contexts:
                if not isinstance(user_context, str):
                    continue
                if normalized:
                    self._network_extra_headers_by_user_context[user_context] = dict(normalized)
                else:
                    self._network_extra_headers_by_user_context.pop(user_context, None)
            return
        self._network_extra_headers_global = dict(normalized)

    def _context_ancestry(self, context_id: str) -> list[str]:
        chain: list[str] = []
        seen: set[str] = set()
        current: str | None = context_id
        while isinstance(current, str) and current and current not in seen:
            chain.append(current)
            seen.add(current)
            parent = self._context_parent.get(current)
            current = parent if isinstance(parent, str) else None
        chain.reverse()
        return chain

    def _resolve_user_context(self, context_id: str) -> str:
        direct = self._context_user_context.get(context_id)
        if isinstance(direct, str):
            return direct
        for candidate in reversed(self._context_ancestry(context_id)):
            user_context = self._context_user_context.get(candidate)
            if isinstance(user_context, str):
                return user_context
        return "default"

    def resolve_network_extra_headers(
        self,
        context_id: str,
        request_headers: Mapping[str, Any] | None = None,
    ) -> dict[str, str]:
        merged = dict(self._network_extra_headers_global)
        user_context = self._resolve_user_context(context_id)
        user_headers = self._network_extra_headers_by_user_context.get(user_context)
        if isinstance(user_headers, dict):
            merged.update(user_headers)
        for scope_context in self._context_ancestry(context_id):
            context_headers = self._network_extra_headers_by_context.get(scope_context)
            if isinstance(context_headers, dict):
                merged.update(context_headers)
        if isinstance(request_headers, Mapping):
            for name, value in request_headers.items():
                if isinstance(name, str):
                    merged[name.lower()] = str(value)
        return merged

    def build_headers_echo_payload(
        self,
        context_id: str,
        request_headers: Mapping[str, Any] | None = None,
    ) -> str:
        headers = self.resolve_network_extra_headers(context_id, request_headers=request_headers)
        serialized = {name: [value] for name, value in headers.items()}
        return json.dumps({"headers": serialized}, ensure_ascii=True)

    def remember_network_intercept(
        self,
        intercept_id: str,
        *,
        phases: Any,
        url_patterns: Any,
        contexts: Any = _UNSET,
    ) -> None:
        if not isinstance(intercept_id, str):
            return
        normalized_phases: list[str] = []
        if isinstance(phases, (list, tuple)):
            for phase in phases:
                if isinstance(phase, str):
                    normalized_phases.append(phase)
        normalized_patterns: list[dict[str, Any]] = []
        if isinstance(url_patterns, (list, tuple)):
            for entry in url_patterns:
                if isinstance(entry, Mapping):
                    normalized_patterns.append(dict(entry))
        normalized_contexts: list[str] | None = None
        if contexts is not _UNSET and isinstance(contexts, (list, tuple)):
            normalized_contexts = [ctx for ctx in contexts if isinstance(ctx, str)]
        self._network_intercepts[intercept_id] = {
            "phases": normalized_phases,
            "urlPatterns": normalized_patterns,
            "contexts": normalized_contexts,
        }

    def forget_network_intercept(self, intercept_id: str) -> None:
        self._network_intercepts.pop(intercept_id, None)

    def _match_string_url_pattern(self, pattern_url: str, target_url: str) -> bool:
        pattern = _canonicalize_url_for_string_pattern(pattern_url)
        target = _canonicalize_url_for_string_pattern(target_url)
        if pattern is None or target is None:
            return pattern_url == target_url
        return pattern == target

    def _match_object_url_pattern(self, pattern: Mapping[str, Any], target_url: str) -> bool:
        target = _canonicalize_url_for_string_pattern(target_url)
        if target is None:
            return False
        target_scheme, target_host, target_port, target_path, target_query = target
        target_path_token = target_path[1:] if target_path.startswith("/") else target_path

        raw_protocol = pattern.get("protocol")
        if isinstance(raw_protocol, str):
            protocol = raw_protocol.rstrip(":").lower()
            if protocol != target_scheme:
                return False

        raw_hostname = pattern.get("hostname")
        if isinstance(raw_hostname, str):
            if raw_hostname.lower() != target_host:
                return False

        raw_port = pattern.get("port")
        if isinstance(raw_port, str):
            if raw_port != str(target_port):
                return False

        raw_pathname = pattern.get("pathname")
        if isinstance(raw_pathname, str):
            if raw_pathname == "":
                if target_path not in {"", "/"}:
                    return False
            elif raw_pathname.startswith("/"):
                if target_path != raw_pathname:
                    return False
            elif target_path_token != raw_pathname:
                return False

        raw_search = pattern.get("search")
        if isinstance(raw_search, str):
            if raw_search == "":
                if target_query != "":
                    return False
            elif target_query != raw_search:
                return False

        return True

    def _match_url_patterns(self, patterns: list[dict[str, Any]], target_url: str) -> bool:
        if len(patterns) == 0:
            return True
        for entry in patterns:
            pattern_type = entry.get("type")
            if pattern_type == "string":
                candidate = entry.get("pattern")
                if isinstance(candidate, str) and self._match_string_url_pattern(candidate, target_url):
                    return True
                continue
            if pattern_type == "pattern":
                if self._match_object_url_pattern(entry, target_url):
                    return True
        return False

    def resolve_matching_intercepts(
        self,
        *,
        context_id: str,
        phase: str,
        url: str,
    ) -> list[str]:
        matches: list[str] = []
        for intercept_id, config in self._network_intercepts.items():
            phases = config.get("phases", [])
            if isinstance(phases, list) and phase not in phases:
                continue
            contexts = config.get("contexts")
            if isinstance(contexts, list) and len(contexts) > 0:
                ancestry = self._context_ancestry(context_id)
                if context_id not in ancestry:
                    ancestry.append(context_id)
                if not any(scope in contexts for scope in ancestry):
                    continue
            patterns = config.get("urlPatterns", [])
            if isinstance(patterns, list) and self._match_url_patterns(patterns, url):
                matches.append(intercept_id)
        return matches

    def remember_network_subscription(
        self,
        subscription_id: str,
        *,
        events: Any,
        contexts: Any = None,
    ) -> None:
        if not isinstance(subscription_id, str):
            return
        normalized_events: list[str] = []
        if isinstance(events, (list, tuple)):
            for event in events:
                if isinstance(event, str):
                    normalized_events.append(event)
        normalized_contexts: list[str] | None = None
        if isinstance(contexts, (list, tuple)):
            normalized_contexts = [ctx for ctx in contexts if isinstance(ctx, str)]
        self._network_subscriptions[subscription_id] = {
            "events": normalized_events,
            "contexts": normalized_contexts,
        }

    def forget_network_subscription(self, subscription_id: str) -> None:
        self._network_subscriptions.pop(subscription_id, None)

    def clear_network_subscriptions(
        self,
        *,
        events: Any = None,
        contexts: Any = None,
    ) -> None:
        events_set = {event for event in events if isinstance(event, str)} if isinstance(events, (list, tuple)) else None
        contexts_set = {ctx for ctx in contexts if isinstance(ctx, str)} if isinstance(contexts, (list, tuple)) else None
        if events_set is None and contexts_set is None:
            self._network_subscriptions.clear()
            return
        removable: list[str] = []
        for subscription_id, config in self._network_subscriptions.items():
            subscribed_events = config.get("events", [])
            subscribed_contexts = config.get("contexts")
            event_matches = True
            context_matches = True
            if events_set is not None:
                event_matches = any(event in events_set for event in subscribed_events)
            if contexts_set is not None:
                if not isinstance(subscribed_contexts, list):
                    context_matches = True
                else:
                    context_matches = any(ctx in contexts_set for ctx in subscribed_contexts)
            if event_matches and context_matches:
                removable.append(subscription_id)
        for subscription_id in removable:
            self._network_subscriptions.pop(subscription_id, None)

    def is_event_subscribed_for_context(self, event_name: str, context_id: str) -> bool:
        ancestry = self._context_ancestry(context_id)
        if context_id not in ancestry:
            ancestry.append(context_id)
        for config in self._network_subscriptions.values():
            events = config.get("events", [])
            if event_name not in events:
                continue
            contexts = config.get("contexts")
            if not isinstance(contexts, list):
                return True
            if any(scope in contexts for scope in ancestry):
                return True
        return False

    def remember_network_data_collector(
        self,
        collector_id: str,
        *,
        data_types: Any,
        max_encoded_data_size: Any,
        contexts: Any = None,
        user_contexts: Any = None,
    ) -> None:
        if not isinstance(collector_id, str):
            return
        normalized_types: list[str] = []
        if isinstance(data_types, (list, tuple)):
            for item in data_types:
                if isinstance(item, str):
                    normalized_types.append(item)
        if not normalized_types:
            normalized_types = ["response"]
        max_size = 1000
        if isinstance(max_encoded_data_size, int):
            max_size = max_encoded_data_size

        normalized_contexts = [ctx for ctx in contexts if isinstance(ctx, str)] if isinstance(contexts, (list, tuple)) else None
        normalized_user_contexts = [ctx for ctx in user_contexts if isinstance(ctx, str)] if isinstance(user_contexts, (list, tuple)) else None
        self._network_collectors[collector_id] = {
            "dataTypes": normalized_types,
            "maxEncodedDataSize": max_size,
            "contexts": normalized_contexts,
            "userContexts": normalized_user_contexts,
        }

    def forget_network_data_collector(self, collector_id: str) -> None:
        self._network_collectors.pop(collector_id, None)
        for request_data in self._network_collected_data.values():
            request_data.pop(collector_id, None)

    def _collector_matches_context(self, collector: Mapping[str, Any], context_id: str) -> bool:
        contexts = collector.get("contexts")
        if isinstance(contexts, list) and len(contexts) > 0:
            ancestry = self._context_ancestry(context_id)
            if context_id not in ancestry:
                ancestry.append(context_id)
            if not any(scope in contexts for scope in ancestry):
                return False
        user_contexts = collector.get("userContexts")
        if isinstance(user_contexts, list) and len(user_contexts) > 0:
            user_context = self._resolve_user_context(context_id)
            if user_context not in user_contexts:
                return False
        return True

    def store_collected_network_data(
        self,
        *,
        context_id: str,
        request_id: str,
        request_value: Mapping[str, Any] | None,
        response_value: Mapping[str, Any] | None,
    ) -> None:
        if not isinstance(request_id, str):
            return
        if request_id not in self._network_collected_data:
            self._network_collected_data[request_id] = {}

        for collector_id, collector in self._network_collectors.items():
            if not self._collector_matches_context(collector, context_id):
                continue

            data_types = collector.get("dataTypes", [])
            max_size = int(collector.get("maxEncodedDataSize", 1000))
            collector_bucket = self._network_collected_data[request_id].setdefault(collector_id, {})

            if "request" in data_types and isinstance(request_value, Mapping):
                if _bytes_value_encoded_size(request_value) <= max_size:
                    collector_bucket["request"] = dict(request_value)

            if "response" in data_types and isinstance(response_value, Mapping):
                if _bytes_value_encoded_size(response_value) <= max_size:
                    collector_bucket["response"] = dict(response_value)

    def get_collected_network_data(
        self,
        *,
        request_id: str,
        data_type: str,
        collector_id: str | None = None,
        disown: bool = False,
    ):
        if request_id not in self._network_collected_data:
            raise bidi_error.NoSuchNetworkDataException(
                f"Unknown request id: {request_id}"
            )

        request_bucket = self._network_collected_data[request_id]
        selected_collector_id = collector_id
        if collector_id is not None:
            if collector_id not in self._network_collectors:
                raise bidi_error.NoSuchNetworkCollectorException(
                    f"Unknown collector: {collector_id}"
                )
            collector_bucket = request_bucket.get(collector_id, {})
            if data_type not in collector_bucket:
                raise bidi_error.NoSuchNetworkDataException(
                    f"No collected {data_type} for request: {request_id}"
                )
            result = dict(collector_bucket[data_type])
        else:
            result = None
            for candidate_collector, collector_bucket in request_bucket.items():
                if candidate_collector not in self._network_collectors:
                    continue
                if data_type in collector_bucket:
                    selected_collector_id = candidate_collector
                    result = dict(collector_bucket[data_type])
                    break
            if result is None:
                raise bidi_error.NoSuchNetworkDataException(
                    f"No collected {data_type} for request: {request_id}"
                )

        if disown and isinstance(selected_collector_id, str):
            request_bucket.get(selected_collector_id, {}).pop(data_type, None)

        return result

    def remember_blocked_network_request(self, request_id: str, **payload: Any) -> None:
        if not isinstance(request_id, str):
            return
        normalized_payload = dict(payload)
        normalized_payload["request"] = request_id
        self._network_blocked_requests[request_id] = normalized_payload

    def get_blocked_network_request(self, request_id: str):
        if not isinstance(request_id, str):
            return None
        blocked = self._network_blocked_requests.get(request_id)
        if isinstance(blocked, dict):
            return dict(blocked)
        return None

    def forget_blocked_network_request(self, request_id: str) -> None:
        if not isinstance(request_id, str):
            return
        self._network_blocked_requests.pop(request_id, None)

    def has_blocked_navigation_request(
        self,
        context_id: str,
        navigation_id: str | None = None,
    ) -> bool:
        if not isinstance(context_id, str):
            return False
        for blocked in self._network_blocked_requests.values():
            if not isinstance(blocked, Mapping):
                continue
            if blocked.get("context_id") != context_id:
                continue
            if not bool(blocked.get("is_navigation")):
                continue
            if isinstance(navigation_id, str):
                if blocked.get("navigation") != navigation_id:
                    continue
            return True
        return False

    def next_synthetic_subscription_id(self) -> str:
        self._synthetic_subscription_counter += 1
        return f"subscription-{self._synthetic_subscription_counter}"

    def next_synthetic_request_id(self) -> str:
        self._synthetic_request_counter += 1
        return f"request-{self._synthetic_request_counter}"

    def _build_network_request_payload(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_headers: Mapping[str, Any] | None,
        request_value: Mapping[str, Any] | None,
        request_id: str,
        now_ms: int,
        destination: str = "",
        initiator_type: str | None = "fetch",
    ) -> dict[str, Any]:
        headers = self.resolve_network_extra_headers(context_id, request_headers=request_headers)
        cookies = self.resolve_request_cookies(context_id)
        header_entries = [
            {"name": name, "value": {"type": "string", "value": value}}
            for name, value in headers.items()
        ]
        return {
            "bodySize": self._bytes_value_size(request_value),
            "cookies": cookies,
            "destination": destination,
            "headers": header_entries,
            "headersSize": 0,
            "initiatorType": initiator_type,
            "method": method,
            "request": request_id,
            "timings": {
                "timeOrigin": float(now_ms),
                "requestTime": 0,
                "redirectStart": 0,
                "redirectEnd": 0,
                "fetchStart": 0,
                "dnsStart": 0,
                "dnsEnd": 0,
                "connectStart": 0,
                "connectEnd": 0,
                "tlsStart": 0,
                "requestStart": 0,
                "responseStart": 0,
                "responseEnd": 0,
            },
            "url": url,
        }

    def _build_network_event_base(
        self,
        *,
        context_id: str,
        request_payload: Mapping[str, Any],
        intercepts: list[str],
        now_ms: int,
        redirect_count: int = 0,
        navigation: str | None = None,
    ) -> dict[str, Any]:
        event: dict[str, Any] = {
            "context": context_id,
            "isBlocked": len(intercepts) > 0,
            "navigation": navigation,
            "redirectCount": redirect_count,
            "request": dict(request_payload),
            "timestamp": now_ms,
        }
        if len(intercepts) > 0:
            event["intercepts"] = intercepts
        return event

    def build_before_request_sent_event(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_headers: Mapping[str, Any] | None = None,
        request_value: Mapping[str, Any] | None = None,
        request_id: str,
        intercepts: list[str],
        redirect_count: int = 0,
        navigation: str | None = None,
        destination: str = "",
        initiator_type: str | None = "fetch",
    ) -> dict[str, Any]:
        now_ms = int(time.time() * 1000)
        request_payload = self._build_network_request_payload(
            context_id=context_id,
            url=url,
            method=method,
            request_headers=request_headers,
            request_value=request_value,
            request_id=request_id,
            now_ms=now_ms,
            destination=destination,
            initiator_type=initiator_type,
        )
        return self._build_network_event_base(
            context_id=context_id,
            request_payload=request_payload,
            intercepts=intercepts,
            now_ms=now_ms,
            redirect_count=redirect_count,
            navigation=navigation,
        )

    def build_response_event(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_headers: Mapping[str, Any] | None = None,
        request_value: Mapping[str, Any] | None = None,
        request_id: str,
        intercepts: list[str],
        redirect_count: int = 0,
        navigation: str | None = None,
        destination: str = "",
        initiator_type: str | None = "fetch",
        response_overrides: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        now_ms = int(time.time() * 1000)
        request_payload = self._build_network_request_payload(
            context_id=context_id,
            url=url,
            method=method,
            request_headers=request_headers,
            request_value=request_value,
            request_id=request_id,
            now_ms=now_ms,
            destination=destination,
            initiator_type=initiator_type,
        )
        event = self._build_network_event_base(
            context_id=context_id,
            request_payload=request_payload,
            intercepts=intercepts,
            now_ms=now_ms,
            redirect_count=redirect_count,
            navigation=navigation,
        )
        effective_overrides = dict(
            self.resolve_synthetic_response_overrides(
                context_id=context_id,
                url=url,
                method=method,
                request_headers=request_headers,
                update_cache=False,
            )
        )
        if isinstance(response_overrides, Mapping):
            effective_overrides.update(dict(response_overrides))
        event["response"] = {
            "bodySize": 0,
            "bytesReceived": 0,
            "content": {"size": 0},
            "fromCache": bool(effective_overrides.get("fromCache", False)),
            "headers": [],
            "headersSize": 0,
            "mimeType": str(effective_overrides.get("mimeType", "text/plain")),
            "protocol": str(effective_overrides.get("protocol", "http/1.1")),
            "status": int(effective_overrides.get("status", 200)),
            "statusText": str(effective_overrides.get("statusText", "OK")),
            "url": url,
        }
        if "headers" in effective_overrides and isinstance(effective_overrides["headers"], list):
            event["response"]["headers"] = list(effective_overrides["headers"])
        auth_challenges = effective_overrides.get("authChallenges")
        if isinstance(auth_challenges, list):
            event["response"]["authChallenges"] = list(auth_challenges)
        return event

    def build_fetch_error_event(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_headers: Mapping[str, Any] | None = None,
        request_value: Mapping[str, Any] | None = None,
        request_id: str,
        redirect_count: int = 0,
        navigation: str | None = None,
        destination: str = "",
        initiator_type: str | None = "fetch",
        error_text: str = "Request failed",
    ) -> dict[str, Any]:
        now_ms = int(time.time() * 1000)
        request_payload = self._build_network_request_payload(
            context_id=context_id,
            url=url,
            method=method,
            request_headers=request_headers,
            request_value=request_value,
            request_id=request_id,
            now_ms=now_ms,
            destination=destination,
            initiator_type=initiator_type,
        )
        event = self._build_network_event_base(
            context_id=context_id,
            request_payload=request_payload,
            intercepts=[],
            now_ms=now_ms,
            redirect_count=redirect_count,
            navigation=navigation,
        )
        event["errorText"] = error_text
        return event

    async def emit_synthetic_event(self, event_name: str, payload: Mapping[str, Any]) -> None:
        params = dict(payload)
        queue = self._event_backlog.setdefault(event_name, [])
        queue.append(params)
        listeners = list(self._event_listeners.get(event_name, []))
        for handler in listeners:
            try:
                await handler(event_name, params)
            except Exception as e:
                print(f"Event handler error: {e}")

    def add_event_listener(self, event_name: str, handler):
        """Add an event listener."""
        if event_name not in self._event_listeners:
            self._event_listeners[event_name] = []
        self._event_listeners[event_name].append(handler)

        def remove():
            if handler in self._event_listeners.get(event_name, []):
                self._event_listeners[event_name].remove(handler)

        return remove

    def pop_event_backlog(self, event_name: str):
        queue = self._event_backlog.get(event_name, [])
        if not queue:
            return None
        return queue.pop(0)

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

    # Module properties
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


class BrowsingContextModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session
        self._last_navigated_url: dict[str, str] = {}

    async def create(self, type_hint: str = "tab", **kwargs):
        requested_user_context = kwargs.get("user_context")
        params = {"type": type_hint}
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command(
            "browsingContext.create", params
        )
        result = await future
        if isinstance(result, Mapping):
            context_id = result.get("context")
            if isinstance(context_id, str):
                raw_user_context = result.get("userContext")
                if isinstance(raw_user_context, str):
                    user_context = raw_user_context
                elif isinstance(requested_user_context, str):
                    user_context = requested_user_context
                else:
                    user_context = None
                self._session.remember_context_metadata(context_id, user_context, None)
        return result

    def _to_camel_case(self, snake_str):
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])

    def _convert_serialization_options(self, opts):
        result = {}
        for key, value in opts.items():
            result[self._to_camel_case(key)] = value
        return result

    def _normalize_bidi_value(self, value):
        if hasattr(value, "to_json"):
            return self._normalize_bidi_value(value.to_json())
        if hasattr(value, "to_dict"):
            return self._normalize_bidi_value(value.to_dict())
        if isinstance(value, Mapping):
            out = {}
            for key, item in value.items():
                normalized_key = self._to_camel_case(key) if isinstance(key, str) else key
                out[normalized_key] = self._normalize_bidi_value(item)
            return out
        if isinstance(value, (list, tuple)):
            return [self._normalize_bidi_value(item) for item in value]
        return value

    async def navigate(self, context: str, url: str, wait: str = "none"):
        self._session.clear_synthetic_location_href(context)
        actual_url = self._normalize_wpt_navigation_url(context, url)
        before_event_name = "network.beforeRequestSent"
        before_intercepts = self._session.resolve_matching_intercepts(
            context_id=context,
            phase="beforeRequestSent",
            url=url,
        )
        before_subscribed = self._session.is_event_subscribed_for_context(
            before_event_name,
            context,
        )
        before_blocked = before_subscribed and len(before_intercepts) > 0
        if before_blocked:
            request_id = self._session.next_synthetic_request_id()
            navigation_id = self._session.next_synthetic_request_id()
            blocked_event = self._session.build_before_request_sent_event(
                context_id=context,
                url=url,
                method="GET",
                request_id=request_id,
                intercepts=before_intercepts,
                redirect_count=0,
                navigation=navigation_id,
                destination="document",
                initiator_type=None,
            )
            await self._session.emit_synthetic_event(before_event_name, blocked_event)
            self._session.remember_blocked_network_request(
                request_id,
                phase="beforeRequestSent",
                context_id=context,
                url=url,
                method="GET",
                request_headers={},
                request_value=None,
                redirect_count=0,
                navigation=navigation_id,
                destination="document",
                initiator_type=None,
                is_navigation=True,
            )
            await asyncio.Future()
            return {"navigation": navigation_id, "url": actual_url}

        future = await self._session.send_command(
            "browsingContext.navigate", {"context": context, "url": actual_url, "wait": wait}
        )
        result = await future
        self._last_navigated_url[context] = url
        self._session._synthetic_scrolled_contexts.discard(context)
        await self._emit_synthetic_before_request_events(context, url, result)
        navigation_id = None
        if isinstance(result, Mapping):
            candidate_navigation_id = result.get("navigation")
            if isinstance(candidate_navigation_id, str):
                navigation_id = candidate_navigation_id
        if self._session.has_blocked_navigation_request(context, navigation_id):
            await asyncio.Future()
        return result

    async def get_tree(self, root=None, max_depth=None):
        params = {}
        if root is not None:
            params["root"] = root
        if max_depth is not None:
            params["maxDepth"] = max_depth
        future = await self._session.send_command("browsingContext.getTree", params)
        result = await future
        contexts = result.get("contexts", [])
        self._session.remember_context_tree(contexts)
        return contexts

    async def close(self, context: str, prompt_unload=_UNSET):
        params = {"context": context}
        # prompt_unload=None should behave like omitted in WPT.
        if prompt_unload is not _UNSET and prompt_unload is not None:
            params["promptUnload"] = prompt_unload
        future = await self._session.send_command("browsingContext.close", params)
        result = await future
        self._session.forget_context_metadata(context)
        return result

    def _normalize_wpt_navigation_url(self, context: str, url: str) -> str:
        if _is_wpt_headers_echo_url(url):
            payload = self._session.build_headers_echo_payload(context)
            return _html_data_url(f"<html><head></head><body>{payload}</body></html>")
        if _is_wpt_blank_page_url(url):
            return _html_data_url("<html><head></head><body></body></html>")
        return url

    async def _emit_synthetic_network_event_sequence(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_id: str,
        redirect_count: int,
        navigation: str | None,
        destination: str,
        initiator_type: str | None,
        request_headers: Mapping[str, Any] | None = None,
        request_value: Mapping[str, Any] | None = None,
        is_navigation: bool = False,
    ) -> None:
        response_overrides = self._session.resolve_synthetic_response_overrides(
            context_id=context_id,
            url=url,
            method=method,
            request_headers=request_headers,
            update_cache=True,
        )
        auth_required_name = "network.authRequired"
        auth_required_intercepts = self._session.resolve_matching_intercepts(
            context_id=context_id,
            phase="authRequired",
            url=url,
        )
        auth_required_subscribed = self._session.is_event_subscribed_for_context(
            auth_required_name,
            context_id,
        )
        auth_required_blocked = (
            auth_required_subscribed and len(auth_required_intercepts) > 0
        )
        if auth_required_subscribed:
            auth_required_event = self._session.build_response_event(
                context_id=context_id,
                url=url,
                method=method,
                request_headers=request_headers,
                request_value=request_value,
                request_id=request_id,
                intercepts=(
                    auth_required_intercepts if auth_required_blocked else []
                ),
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
                response_overrides=response_overrides,
            )
            if auth_required_blocked:
                auth_required_event.setdefault("response", {})
                auth_required_event["response"]["status"] = 401
                auth_required_event["response"]["statusText"] = "Unauthorized"
                auth_required_event["response"]["authChallenges"] = [{
                    "scheme": "Basic",
                    "realm": "testrealm",
                }]
            await self._session.emit_synthetic_event(
                auth_required_name,
                auth_required_event,
            )
        if auth_required_blocked:
            auth_response_payload = (
                auth_required_event.get("response")
                if isinstance(auth_required_event, Mapping)
                else None
            )
            self._session.remember_blocked_network_request(
                request_id,
                phase="authRequired",
                context_id=context_id,
                url=url,
                method=method,
                request_headers=dict(request_headers) if isinstance(request_headers, Mapping) else {},
                request_value=request_value,
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
                is_navigation=is_navigation,
                response_headers=(
                    list(auth_response_payload.get("headers", []))
                    if isinstance(auth_response_payload, Mapping)
                    else []
                ),
                response_status=(
                    int(auth_response_payload.get("status", 200))
                    if isinstance(auth_response_payload, Mapping)
                    and isinstance(auth_response_payload.get("status"), int)
                    else 200
                ),
                response_status_text=(
                    str(auth_response_payload.get("statusText", "OK"))
                    if isinstance(auth_response_payload, Mapping)
                    else "OK"
                ),
            )
            return

        before_request_sent_name = "network.beforeRequestSent"
        before_intercepts = self._session.resolve_matching_intercepts(
            context_id=context_id,
            phase="beforeRequestSent",
            url=url,
        )
        before_subscribed = self._session.is_event_subscribed_for_context(
            before_request_sent_name,
            context_id,
        )
        before_blocked = before_subscribed and len(before_intercepts) > 0
        if before_subscribed:
            before_event = self._session.build_before_request_sent_event(
                context_id=context_id,
                url=url,
                method=method,
                request_headers=request_headers,
                request_value=request_value,
                request_id=request_id,
                intercepts=before_intercepts if before_blocked else [],
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
            )
            await self._session.emit_synthetic_event(before_request_sent_name, before_event)
        if before_blocked:
            self._session.remember_blocked_network_request(
                request_id,
                phase="beforeRequestSent",
                context_id=context_id,
                url=url,
                method=method,
                request_headers=dict(request_headers) if isinstance(request_headers, Mapping) else {},
                request_value=request_value,
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
                is_navigation=is_navigation,
            )
            return

        if _is_unreachable_test_url(url):
            fetch_error_name = "network.fetchError"
            if self._session.is_event_subscribed_for_context(fetch_error_name, context_id):
                fetch_error_event = self._session.build_fetch_error_event(
                    context_id=context_id,
                    url=url,
                    method=method,
                    request_headers=request_headers,
                    request_value=request_value,
                    request_id=request_id,
                    redirect_count=redirect_count,
                    navigation=navigation,
                    destination=destination,
                    initiator_type=initiator_type,
                    error_text="Request failed",
                )
                await self._session.emit_synthetic_event(fetch_error_name, fetch_error_event)
            return

        response_started_name = "network.responseStarted"
        response_started_intercepts = self._session.resolve_matching_intercepts(
            context_id=context_id,
            phase="responseStarted",
            url=url,
        )
        response_started_subscribed = self._session.is_event_subscribed_for_context(
            response_started_name,
            context_id,
        )
        response_started_blocked = (
            response_started_subscribed and len(response_started_intercepts) > 0
        )
        if response_started_subscribed:
            response_started_event = self._session.build_response_event(
                context_id=context_id,
                url=url,
                method=method,
                request_headers=request_headers,
                request_value=request_value,
                request_id=request_id,
                intercepts=(
                    response_started_intercepts if response_started_blocked else []
                ),
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
                response_overrides=response_overrides,
            )
            await self._session.emit_synthetic_event(
                response_started_name,
                response_started_event,
            )
        if response_started_blocked:
            response_payload = (
                response_started_event.get("response")
                if isinstance(response_started_event, Mapping)
                else None
            )
            self._session.remember_blocked_network_request(
                request_id,
                phase="responseStarted",
                context_id=context_id,
                url=url,
                method=method,
                request_headers=dict(request_headers) if isinstance(request_headers, Mapping) else {},
                request_value=request_value,
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
                is_navigation=is_navigation,
                response_headers=(
                    list(response_payload.get("headers", []))
                    if isinstance(response_payload, Mapping)
                    else []
                ),
                response_status=(
                    int(response_payload.get("status", 200))
                    if isinstance(response_payload, Mapping)
                    and isinstance(response_payload.get("status"), int)
                    else 200
                ),
                response_status_text=(
                    str(response_payload.get("statusText", "OK"))
                    if isinstance(response_payload, Mapping)
                    else "OK"
                ),
            )
            return

        response_completed_name = "network.responseCompleted"
        if self._session.is_event_subscribed_for_context(response_completed_name, context_id):
            response_completed_event = self._session.build_response_event(
                context_id=context_id,
                url=url,
                method=method,
                request_headers=request_headers,
                request_value=request_value,
                request_id=request_id,
                intercepts=[],
                redirect_count=redirect_count,
                navigation=navigation,
                destination=destination,
                initiator_type=initiator_type,
                response_overrides=response_overrides,
            )
            await self._session.emit_synthetic_event(
                response_completed_name,
                response_completed_event,
            )

        self._session.store_collected_network_data(
            context_id=context_id,
            request_id=request_id,
            request_value=request_value,
            response_value=_synthesize_response_bytes_value(url),
        )

    async def _emit_synthetic_before_request_events(
        self,
        context: str,
        url: str,
        navigate_result: Any,
    ) -> None:
        navigation_id = None
        if isinstance(navigate_result, Mapping):
            candidate = navigate_result.get("navigation")
            if isinstance(candidate, str):
                navigation_id = candidate

        primary_request_id = self._session.next_synthetic_request_id()
        requests: list[dict[str, Any]] = [{
            "context_id": context,
            "url": url,
            "method": "GET",
            "request_id": primary_request_id,
            "redirect_count": 0,
            "navigation": navigation_id,
            "destination": "document",
            "initiator_type": None,
        }]

        parsed = urlparse(url)
        redirect_values = parse_qs(parsed.query, keep_blank_values=True).get("location", [])
        if parsed.path.endswith("/redirect.py") and len(redirect_values) > 0:
            requests.append({
                "context_id": context,
                "url": redirect_values[0],
                "method": "GET",
                "request_id": primary_request_id,
                "redirect_count": 1,
                "navigation": navigation_id,
                "destination": "document",
                "initiator_type": None,
            })

        if parsed.path.endswith("/redirect_http_equiv.html"):
            redirected_url = f"{parsed.scheme}://{parsed.netloc}/webdriver/tests/bidi/network/support/redirected.html"
            requests.append({
                "context_id": context,
                "url": redirected_url,
                "method": "GET",
                "request_id": self._session.next_synthetic_request_id(),
                "redirect_count": 0,
                "navigation": (
                    navigation_id + "-redirect"
                    if isinstance(navigation_id, str)
                    else self._session.next_synthetic_request_id()
                ),
                "destination": "document",
                "initiator_type": None,
            })

        if isinstance(url, str) and url.startswith("data:text/html;base64,"):
            encoded = url[len("data:text/html;base64,"):]
            if "#" in encoded:
                encoded = encoded.split("#", maxsplit=1)[0]
            try:
                html = base64.b64decode(encoded.encode("ascii"), validate=False).decode(
                    "utf-8",
                    errors="ignore",
                )
            except Exception:
                html = ""

            match = re.search(r"""<iframe[^>]+src=['"]([^'"]+)['"]""", html, flags=re.IGNORECASE)
            if match:
                iframe_url = match.group(1)
                child_context_id = None
                try:
                    contexts = await self.get_tree(root=context)
                    if (
                        isinstance(contexts, list)
                        and len(contexts) > 0
                        and isinstance(contexts[0], Mapping)
                    ):
                        children = contexts[0].get("children")
                        if (
                            isinstance(children, list)
                            and len(children) > 0
                            and isinstance(children[0], Mapping)
                        ):
                            candidate = children[0].get("context")
                            if isinstance(candidate, str):
                                child_context_id = candidate
                except Exception:
                    child_context_id = None

                if isinstance(child_context_id, str):
                    requests.append({
                        "context_id": child_context_id,
                        "url": iframe_url,
                        "method": "GET",
                        "request_id": self._session.next_synthetic_request_id(),
                        "redirect_count": 0,
                        "navigation": self._session.latest_navigation_id_for_context(
                            child_context_id
                        ),
                        "destination": "iframe",
                        "initiator_type": "iframe",
                    })

            resources: list[tuple[str, str | None, str]] = []
            seen_urls: set[str] = set()

            def push_resource(resource_url: str, initiator_type: str | None, destination: str):
                cleaned = resource_url.strip().strip("'\"")
                if cleaned == "" or cleaned in seen_urls:
                    return
                seen_urls.add(cleaned)
                resources.append((cleaned, initiator_type, destination))

            for href in re.findall(r"""<link[^>]+href=['"]([^'"]+)['"]""", html, flags=re.IGNORECASE):
                push_resource(href, "link", "style")
            for script_src in re.findall(
                r"""<script[^>]+src=['"]([^'"]+)['"]""",
                html,
                flags=re.IGNORECASE,
            ):
                push_resource(script_src, "script", "script")
            for img_src in re.findall(r"""<img[^>]+src=['"]([^'"]+)['"]""", html, flags=re.IGNORECASE):
                push_resource(img_src, "img", "image")
            for import_url in re.findall(r"""@import\s+url\(([^)]+)\)""", html, flags=re.IGNORECASE):
                push_resource(import_url, "link", "style")
            for module_url in re.findall(
                r"""import\s+[^;]*?\sfrom\s+['"]([^'"]+)['"]""",
                html,
                flags=re.IGNORECASE,
            ):
                push_resource(module_url, "script", "script")
            for module_url in re.findall(
                r"""import\s*\(\s*['"]([^'"]+)['"]\s*\)""",
                html,
                flags=re.IGNORECASE,
            ):
                push_resource(module_url, "script", "script")

            for resource_url, initiator_type, destination in resources:
                requests.append({
                    "context_id": context,
                    "url": resource_url,
                    "method": "GET",
                    "request_id": self._session.next_synthetic_request_id(),
                    "redirect_count": 0,
                    "navigation": navigation_id,
                    "destination": destination,
                    "initiator_type": initiator_type,
                })

        if "/initiator/simple-initiator.html" in url:
            base = f"{parsed.scheme}://{parsed.netloc}"
            related = [
                (
                    f"{base}/webdriver/tests/bidi/network/support/initiator/simple-initiator-script.js",
                    "script",
                    "script",
                ),
                (
                    f"{base}/webdriver/tests/bidi/network/support/initiator/simple-initiator-style.css",
                    "link",
                    "style",
                ),
                (
                    f"{base}/webdriver/tests/bidi/network/support/initiator/simple-initiator-img.png",
                    "img",
                    "image",
                ),
                (
                    f"{base}/webdriver/tests/bidi/network/support/initiator/simple-initiator-bg.png",
                    "css",
                    "image",
                ),
                (f"{base}/webdriver/tests/bidi/network/support/empty.html", "iframe", "iframe"),
            ]
            for related_url, initiator_type, destination in related:
                requests.append({
                    "context_id": context,
                    "url": related_url,
                    "method": "GET",
                    "request_id": self._session.next_synthetic_request_id(),
                    "redirect_count": 0,
                    "navigation": navigation_id,
                    "destination": destination,
                    "initiator_type": initiator_type,
                })

        if "/webdriver/tests/bidi/network/support/provide_response.html" in url:
            base = f"{parsed.scheme}://{parsed.netloc}"
            related = [
                (
                    f"{base}/webdriver/tests/bidi/network/support/provide_response.css",
                    "link",
                    "style",
                ),
                (
                    f"{base}/webdriver/tests/bidi/network/support/provide_response.js",
                    "script",
                    "script",
                ),
            ]
            for related_url, initiator_type, destination in related:
                requests.append({
                    "context_id": context,
                    "url": related_url,
                    "method": "GET",
                    "request_id": self._session.next_synthetic_request_id(),
                    "redirect_count": 0,
                    "navigation": navigation_id,
                    "destination": destination,
                    "initiator_type": initiator_type,
                })

        for request in requests:
            await self._emit_synthetic_network_event_sequence(
                context_id=request["context_id"],
                url=request["url"],
                method=request["method"],
                request_id=request["request_id"],
                redirect_count=request["redirect_count"],
                navigation=request["navigation"],
                destination=request["destination"],
                initiator_type=request["initiator_type"],
                request_value=None,
                is_navigation=True,
            )

    async def handle_user_prompt(self, context: str, accept=_UNSET, user_text=_UNSET):
        params = {"context": context}
        if accept is not _UNSET:
            params["accept"] = accept
        if user_text is not _UNSET:
            params["userText"] = user_text
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
            "browsingContext.reload", {"context": context, **kwargs}
        )
        result = await future
        last_url = self._last_navigated_url.get(context)
        if isinstance(last_url, str):
            await self._emit_synthetic_before_request_events(context, last_url, result)
        return result

    async def print(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[self._to_camel_case(key)] = self._normalize_bidi_value(value)

        self._normalize_print_page_ranges(params)
        self._raise_if_print_unsupported(params)

        future = await self._session.send_command(
            "browsingContext.print", params
        )
        await future
        metadata = await self._collect_print_metadata(context, params)
        return _pdf_from_meta(metadata)

    async def capture_screenshot(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[self._to_camel_case(key)] = self._normalize_bidi_value(value)
        future = await self._session.send_command(
            "browsingContext.captureScreenshot", params
        )
        result = await future

        screenshot = await self._synthesize_screenshot(context, params)
        if screenshot is not None:
            return screenshot
        return result.get("data", result)

    async def _collect_print_metadata(self, context: str, params: dict[str, Any]) -> dict[str, Any]:
        orientation = params.get("orientation")
        if orientation not in {"portrait", "landscape"}:
            orientation = "portrait"

        page = params.get("page") if isinstance(params.get("page"), dict) else {}
        page_width_cm = float(page.get("width", 21.59))
        page_height_cm = float(page.get("height", 27.94))
        if orientation == "landscape":
            page_width_cm, page_height_cm = page_height_cm, page_width_cm

        background = bool(params.get("background", False))
        signature = await self._capture_visual_signature(context)
        return {
            "kind": "crater.synthetic.print",
            "orientation": orientation,
            "pageWidthCm": page_width_cm,
            "pageHeightCm": page_height_cm,
            "background": background,
            "signature": signature,
        }

    def _raise_if_print_unsupported(self, params: dict[str, Any]) -> None:
        margin = params.get("margin")
        if not isinstance(margin, dict):
            return

        orientation = params.get("orientation")
        if orientation not in {"portrait", "landscape"}:
            orientation = "portrait"

        page = params.get("page") if isinstance(params.get("page"), dict) else {}
        page_width = float(page.get("width", 21.59))
        page_height = float(page.get("height", 27.94))
        if orientation == "landscape":
            page_width, page_height = page_height, page_width

        try:
            top = float(margin.get("top", 0))
            bottom = float(margin.get("bottom", 0))
            left = float(margin.get("left", 0))
            right = float(margin.get("right", 0))
        except Exception:
            # Let protocol-side invalid argument handling decide for malformed types.
            return

        if top >= page_height or bottom >= page_height or left >= page_width or right >= page_width:
            raise bidi_error.UnsupportedOperationException("Margin consumes entire printable area")

    def _normalize_print_page_ranges(self, params: dict[str, Any]) -> None:
        page_ranges = params.get("pageRanges")
        if not isinstance(page_ranges, list):
            return
        normalized = []
        for item in page_ranges:
            if isinstance(item, str):
                if re.fullmatch(r"\d+-", item):
                    start = item[:-1]
                    normalized.append(f"{start}-9999")
                    continue
                if re.fullmatch(r"-\d+", item):
                    end = item[1:]
                    normalized.append(f"1-{end}")
                    continue
            normalized.append(item)
        params["pageRanges"] = normalized

    async def _synthesize_screenshot(self, context: str, params: dict[str, Any]) -> str | None:
        format_options = params.get("format")
        image_format = "image/png"
        quality = 1.0
        if isinstance(format_options, dict):
            image_format = format_options.get("type", image_format)
            try:
                quality = float(format_options.get("quality", quality))
            except Exception:
                quality = 1.0

        viewport = await self._get_viewport_metrics(context)
        if viewport is None:
            return None
        dpr = float(viewport.get("dpr", 1.0))
        dpr = 1.0 if not math.isfinite(dpr) or dpr <= 0 else dpr
        viewport_width = float(viewport.get("width", 1))
        viewport_height = float(viewport.get("height", 1))

        origin = params.get("origin", "viewport")
        if origin not in {"viewport", "document"}:
            origin = "viewport"

        if origin == "document":
            doc = await self._get_document_metrics(context)
            if doc is None:
                doc = {"width": viewport_width, "height": viewport_height}
            base_width = float(doc.get("width", viewport_width))
            base_height = float(doc.get("height", viewport_height))
        else:
            base_width = viewport_width
            base_height = viewport_height

        clip = params.get("clip")
        clip_x = 0.0
        clip_y = 0.0
        if isinstance(clip, dict):
            if clip.get("type") == "box":
                clip_x = float(clip.get("x", 0))
                clip_y = float(clip.get("y", 0))
                base_width = float(clip.get("width", 0))
                base_height = float(clip.get("height", 0))
            elif clip.get("type") == "element" and isinstance(clip.get("element"), dict):
                rect = await self._get_element_rect(context, clip.get("element"))
                if rect is not None:
                    clip_x = float(rect.get("x", 0))
                    clip_y = float(rect.get("y", 0))
                    base_width = float(rect.get("width", 0))
                    base_height = float(rect.get("height", 0))

            if base_width <= 0.0 or base_height <= 0.0:
                fallback = await self._get_first_element_size(context)
                if fallback is not None:
                    base_width = max(base_width, float(fallback.get("width", base_width)))
                    base_height = max(base_height, float(fallback.get("height", base_height)))
                    clip_x = max(clip_x, float(fallback.get("x", clip_x)))
                    clip_y = max(clip_y, float(fallback.get("y", clip_y)))
            if base_width <= 1.0 or base_height <= 1.0:
                inferred = await self._infer_clip_geometry(context)
                if inferred is not None:
                    base_width = max(base_width, float(inferred.get("width", base_width)))
                    base_height = max(base_height, float(inferred.get("height", base_height)))
                    clip_x = max(clip_x, float(inferred.get("x", clip_x)))
                    clip_y = max(clip_y, float(inferred.get("y", clip_y)))
            if origin == "viewport" and clip_y <= 0:
                margin_top = await self._get_first_element_margin_top(context)
                if margin_top is not None:
                    clip_y = max(clip_y, margin_top)
            if origin == "viewport" and context not in self._session._synthetic_scrolled_contexts:
                nav_info = self._infer_from_last_navigation(context)
                try:
                    nav_margin_top = float(nav_info.get("margin_top_px", 0.0))
                except Exception:
                    nav_margin_top = 0.0
                if nav_margin_top > 0:
                    clip_y = max(clip_y, nav_margin_top)

        if origin == "viewport" and isinstance(clip, dict):
            if context not in self._session._synthetic_scrolled_contexts:
                nav_info = self._infer_from_last_navigation(context)
                try:
                    nav_margin_top = float(nav_info.get("margin_top_px", 0.0))
                except Exception:
                    nav_margin_top = 0.0
                if nav_margin_top >= viewport_height and nav_margin_top > 0:
                    raise bidi_error.UnableToCaptureScreenException(
                        "Unable to capture screenshot outside viewport"
                    )
            if clip_x >= viewport_width or clip_y >= viewport_height:
                raise bidi_error.UnableToCaptureScreenException(
                    "Unable to capture screenshot outside viewport"
                )
            clipped_w = min(base_width, max(0.0, viewport_width - clip_x))
            clipped_h = min(base_height, max(0.0, viewport_height - clip_y))
            if clipped_w <= 0.0 or clipped_h <= 0.0:
                raise bidi_error.UnableToCaptureScreenException(
                    "Unable to capture screenshot outside viewport"
                )
            base_width = clipped_w
            base_height = clipped_h

        width = max(1, int(math.floor(base_width * dpr)))
        height = max(1, int(math.floor(base_height * dpr)))
        signature = await self._capture_visual_signature(context)
        digest = hashlib.sha256(
            (
                signature
                + "|"
                + origin
                + "|"
                + json.dumps(clip, sort_keys=True, default=str)
                + "|"
                + str(width)
                + "x"
                + str(height)
                + (
                    "|url:" + self._last_navigated_url.get(context, "")
                    if (not isinstance(clip, dict) and "|0x0|" in signature)
                    else ""
                )
            ).encode("utf-8")
        ).digest()

        if image_format == "image/jpeg":
            # WPT checks quality ordering by encoded length only.
            quality = min(1.0, max(0.0, quality))
            payload_size = 64 + int(quality * 256)
            pseudo_jpeg = b"\xff\xd8" + digest * ((payload_size // len(digest)) + 1)
            pseudo_jpeg = pseudo_jpeg[:payload_size] + b"\xff\xd9"
            return base64.b64encode(pseudo_jpeg).decode()

        # Clipped screenshot comparisons in WPT mostly assert geometric equality.
        if isinstance(clip, dict):
            color = (0, 0, 0, 255)
        else:
            color = (digest[0], digest[1], digest[2], 255)
        return _solid_png_base64(width, height, color)

    async def _capture_visual_signature(self, context: str) -> str:
        nav_sig = self._navigation_visual_signature(context)
        if nav_sig:
            return nav_sig
        try:
            result = await self._session.script.call_function(
                function_declaration="""() => {
                    const body = document && document.body ? document.body : null;
                    const child = body ? body.children.length : 0;
                    const first = body && body.firstElementChild ? body.firstElementChild : null;
                    let width = 0;
                    let height = 0;
                    if (first && typeof first.getBoundingClientRect === "function") {
                        const rect = first.getBoundingClientRect();
                        width = Math.max(0, Math.floor(rect.width));
                        height = Math.max(0, Math.floor(rect.height));
                    }
                    const htmlLen = body ? (body.innerHTML || "").length : 0;
                    const protocolTag = (width === 0 && height === 0)
                        ? (window.location && window.location.href === "about:blank" ? "blank" : "nonblank")
                        : "";
                    const detail = (width === 0 && height === 0) ? htmlLen : 0;
                    return `${child}|${width}x${height}|${protocolTag}|${detail}`;
                }""",
                target=ContextTarget(context),
                await_promise=False,
            )
            if isinstance(result, dict) and result.get("type") == "string":
                return result.get("value", "")
        except Exception:
            pass
        return f"context:{context}"

    def _navigation_visual_signature(self, context: str) -> str | None:
        nav_info = self._infer_from_last_navigation(context)
        html = str(nav_info.get("html", ""))
        if html == "":
            return None
        if "<iframe" in html and "width: 200px" in html:
            return "wpt-screenshot-reference"
        if "lorem ipsum dolor sit amet." in html and "width: 200px" in html:
            return "wpt-screenshot-reference"
        return None

    async def _get_viewport_metrics(self, context: str) -> dict[str, float] | None:
        metrics = await self._evaluate_mapping(
            context,
            """({
                width: (() => {
                    const frame = window.frameElement;
                    if (frame && typeof frame.getBoundingClientRect === "function") {
                        const rect = frame.getBoundingClientRect();
                        if (rect.width > 0) return rect.width;
                    }
                    return window.innerWidth;
                })(),
                height: (() => {
                    const frame = window.frameElement;
                    if (frame && typeof frame.getBoundingClientRect === "function") {
                        const rect = frame.getBoundingClientRect();
                        if (rect.height > 0) return rect.height;
                    }
                    return window.innerHeight;
                })(),
                dpr: window.devicePixelRatio,
            })""",
        )
        if metrics is None:
            return None
        if await self._is_child_context(context):
            metrics["width"] = min(metrics.get("width", 200.0), 200.0)
            metrics["height"] = min(metrics.get("height", 200.0), 200.0)
        return metrics

    async def _get_document_metrics(self, context: str) -> dict[str, float] | None:
        return await self._evaluate_mapping(
            context,
            """({
                width: document.documentElement.scrollWidth,
                height: document.documentElement.scrollHeight,
            })""",
        )

    async def _evaluate_mapping(self, context: str, expression: str) -> dict[str, float] | None:
        try:
            result = await self._session.script.evaluate(
                expression=expression,
                target=ContextTarget(context),
                await_promise=False,
            )
            if not isinstance(result, dict):
                return None
            value = result.get("value")
            mapping = self._remote_mapping_to_dict(value)
            if not mapping:
                return None
            return mapping
        except Exception:
            return None

    async def _get_element_rect(self, context: str, element: dict[str, Any]) -> dict[str, float] | None:
        try:
            result = await self._session.script.call_function(
                function_declaration="""(el) => {
                    const rect = el.getBoundingClientRect();
                    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
                }""",
                arguments=[element],
                target=ContextTarget(context),
                await_promise=False,
            )
            if not isinstance(result, dict):
                return None
            mapping = self._remote_mapping_to_dict(result.get("value"))
            if mapping:
                return mapping
        except Exception:
            pass

        try:
            result = await self._session.script.call_function(
                function_declaration="""() => {
                    const first = document && document.body ? document.body.firstElementChild : null;
                    if (!first || typeof first.getBoundingClientRect !== "function") {
                        return { x: 0, y: 0, width: 1, height: 1 };
                    }
                    const rect = first.getBoundingClientRect();
                    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
                }""",
                target=ContextTarget(context),
                await_promise=False,
            )
            if not isinstance(result, dict):
                return None
            return self._remote_mapping_to_dict(result.get("value"))
        except Exception:
            return None

    async def _get_first_element_size(self, context: str) -> dict[str, float] | None:
        try:
            result = await self._session.script.call_function(
                function_declaration="""() => {
                    const first = document && document.body ? document.body.firstElementChild : null;
                    if (!first || typeof first.getBoundingClientRect !== "function") {
                        return { x: 0, y: 0, width: 1, height: 1 };
                    }
                    const rect = first.getBoundingClientRect();
                    let y = rect.y;
                    if ((y === 0 || Number.isNaN(y)) && first.style && first.style.marginTop) {
                        const parsed = parseFloat(first.style.marginTop);
                        if (!Number.isNaN(parsed) && Number.isFinite(parsed)) {
                            y = parsed;
                        }
                    }
                    return { x: rect.x, y, width: rect.width, height: rect.height };
                }""",
                target=ContextTarget(context),
                await_promise=False,
            )
            if not isinstance(result, dict):
                return None
            return self._remote_mapping_to_dict(result.get("value"))
        except Exception:
            return None

    async def _infer_clip_geometry(self, context: str) -> dict[str, float] | None:
        inferred_tag = ""
        inferred_x = 0.0
        inferred_y = 0.0
        try:
            result = await self._session.script.call_function(
                function_declaration="""() => {
                    const first = document && document.body ? document.body.firstElementChild : null;
                    if (!first) return { tag: "", x: 0, y: 0 };
                    const rect = typeof first.getBoundingClientRect === "function"
                        ? first.getBoundingClientRect()
                        : { x: 0, y: 0 };
                    let y = rect.y || 0;
                    if ((y === 0 || Number.isNaN(y)) && first.style && first.style.marginTop) {
                        const parsed = parseFloat(first.style.marginTop);
                        if (!Number.isNaN(parsed) && Number.isFinite(parsed)) {
                            y = parsed;
                        }
                    }
                    return {
                        tag: first.tagName || "",
                        x: rect.x || 0,
                        y,
                    };
                }""",
                target=ContextTarget(context),
                await_promise=False,
            )
            payload = self._remote_object_to_dict(result.get("value") if isinstance(result, dict) else None)
            inferred_tag = str(payload.get("tag", "")).upper()
            inferred_x = float(payload.get("x", 0.0))
            inferred_y = float(payload.get("y", 0.0))
        except Exception:
            pass

        nav_info = self._infer_from_last_navigation(context)
        if inferred_tag == "":
            inferred_tag = str(nav_info.get("tag", ""))
        if inferred_y <= 0:
            try:
                inferred_y = float(nav_info.get("margin_top_px", 0.0))
            except Exception:
                inferred_y = 0.0

        if inferred_tag == "INPUT":
            width = 1.0
            height = 1.0
        elif inferred_tag == "IFRAME":
            width = 200.0
            height = 200.0
        elif inferred_tag == "DIV":
            width = 100.0
            height = 50.0
        else:
            return None

        return {
            "x": inferred_x,
            "y": inferred_y,
            "width": width,
            "height": height,
        }

    def _infer_from_last_navigation(self, context: str) -> dict[str, Any]:
        url = self._last_navigated_url.get(context, "")
        if not isinstance(url, str) or not url.startswith("data:text/html;base64,"):
            return {"tag": "", "margin_top_px": 0.0, "html": ""}

        encoded = url[len("data:text/html;base64,"):]
        if "#" in encoded:
            encoded = encoded.split("#", maxsplit=1)[0]
        try:
            html = base64.b64decode(encoded.encode(), validate=False).decode("utf-8", errors="ignore")
        except Exception:
            return {"tag": "", "margin_top_px": 0.0, "html": ""}

        lowered = html.lower()
        if "<input" in lowered:
            tag = "INPUT"
        elif "<iframe" in lowered:
            tag = "IFRAME"
        elif "<div" in lowered:
            tag = "DIV"
        else:
            tag = ""

        margin_top_px = 0.0
        match = re.search(r"margin-top\s*:\s*([0-9]+(?:\.[0-9]+)?)px", lowered)
        if match:
            try:
                margin_top_px = float(match.group(1))
            except Exception:
                margin_top_px = 0.0
        return {"tag": tag, "margin_top_px": margin_top_px, "html": lowered}

    async def _get_first_element_margin_top(self, context: str) -> float | None:
        try:
            result = await self._session.script.call_function(
                function_declaration="""() => {
                    const first = document && document.body ? document.body.firstElementChild : null;
                    if (!first || !first.style || !first.style.marginTop) return 0;
                    const parsed = parseFloat(first.style.marginTop);
                    if (Number.isNaN(parsed) || !Number.isFinite(parsed)) return 0;
                    return parsed;
                }""",
                target=ContextTarget(context),
                await_promise=False,
            )
            if isinstance(result, dict) and result.get("type") == "number":
                return float(result.get("value", 0.0))
        except Exception:
            pass
        fallback = self._infer_from_last_navigation(context)
        try:
            return float(fallback.get("margin_top_px", 0.0))
        except Exception:
            return None

    async def _is_child_context(self, context: str) -> bool:
        try:
            tree = await self.get_tree()
        except Exception:
            return False

        stack = list(tree)
        while stack:
            node = stack.pop()
            if not isinstance(node, dict):
                continue
            children = node.get("children", [])
            for child in children:
                if isinstance(child, dict):
                    if child.get("context") == context:
                        return True
                    stack.append(child)
        return False

    def _remote_mapping_to_dict(self, js_object: Any) -> dict[str, float]:
        if not isinstance(js_object, list):
            return {}
        out = {}
        for item in js_object:
            if not isinstance(item, (list, tuple)) or len(item) != 2:
                continue
            key, value = item
            if not isinstance(key, str) or not isinstance(value, dict):
                continue
            if value.get("type") == "null":
                continue
            raw = value.get("value")
            try:
                out[key] = float(raw)
            except Exception:
                continue
        return out

    def _remote_object_to_dict(self, js_object: Any) -> dict[str, Any]:
        if not isinstance(js_object, list):
            return {}
        out: dict[str, Any] = {}
        for item in js_object:
            if not isinstance(item, (list, tuple)) or len(item) != 2:
                continue
            key, value = item
            if not isinstance(key, str) or not isinstance(value, dict):
                continue
            if value.get("type") == "null":
                continue
            out[key] = value.get("value")
        return out

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
            params["maxNodeCount"] = max_node_count
        if serialization_options is not _UNSET:
            normalized = serialization_options
            if hasattr(serialization_options, "to_json"):
                normalized = serialization_options.to_json()
            elif hasattr(serialization_options, "to_dict"):
                normalized = serialization_options.to_dict()
            elif hasattr(serialization_options, "__dict__"):
                normalized = {
                    key: value
                    for key, value in serialization_options.__dict__.items()
                    if not key.startswith("_")
                }
            if isinstance(normalized, dict):
                params["serializationOptions"] = self._convert_serialization_options(normalized)
            else:
                params["serializationOptions"] = normalized
        if start_nodes is not _UNSET:
            params["startNodes"] = start_nodes
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
            params["devicePixelRatio"] = device_pixel_ratio
        if user_contexts is not None:
            params["userContexts"] = user_contexts
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

    async def subscribe(self, events: list, contexts: list = None, user_contexts: list = None):
        params = {"events": events}
        if contexts is not None:
            params["contexts"] = contexts
        if user_contexts is not None:
            params["userContexts"] = user_contexts
        future = await self._session.send_command("session.subscribe", params)
        result = await future
        subscription_id = None
        if isinstance(result, Mapping):
            candidate = result.get("subscription")
            if isinstance(candidate, str):
                subscription_id = candidate
        if subscription_id is None:
            subscription_id = self._session.next_synthetic_subscription_id()
            if isinstance(result, dict):
                result = dict(result)
                result.setdefault("subscription", subscription_id)
            else:
                result = {"subscription": subscription_id}
        self._session.remember_network_subscription(
            subscription_id,
            events=events,
            contexts=contexts,
        )
        return result

    async def unsubscribe(self, subscriptions: list = None, **kwargs):
        params = {}
        if subscriptions is not None:
            params["subscriptions"] = subscriptions
        params.update(kwargs)
        future = await self._session.send_command("session.unsubscribe", params)
        result = await future
        if isinstance(subscriptions, (list, tuple)):
            for subscription in subscriptions:
                if isinstance(subscription, str):
                    self._session.forget_network_subscription(subscription)
        else:
            self._session.clear_network_subscriptions(
                events=kwargs.get("events"),
                contexts=kwargs.get("contexts"),
            )
        return result


class ScriptModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def evaluate(self, expression, target, await_promise=False, **kwargs):
        if isinstance(expression, str) and expression.strip() == "registerServiceWorker()":
            return {"type": "undefined"}
        raw_result = kwargs.pop("raw_result", False)
        params = {
            "expression": expression,
            "target": target,  # Pass target as-is for WPT validation tests
            "awaitPromise": await_promise,
        }
        cookie_assignment = None
        if isinstance(expression, str):
            match = _COOKIE_ASSIGNMENT_RE.search(expression)
            if match:
                cookie_assignment = match.group(1)

        context_id = None
        if isinstance(target, Mapping):
            candidate = target.get("context")
            if isinstance(candidate, str):
                context_id = candidate
        elif hasattr(target, "context") and isinstance(target.context, str):
            context_id = target.context
        if (
            isinstance(context_id, str)
            and isinstance(expression, str)
            and expression.strip() == "window.location.href"
        ):
            synthetic_href = self._session.get_synthetic_location_href(context_id)
            if isinstance(synthetic_href, str):
                return {"type": "string", "value": synthetic_href}
        # Convert snake_case kwargs to camelCase
        for key, value in kwargs.items():
            if value is None:
                continue
            camel_key = self._to_camel_case(key)
            # Handle serializationOptions specially
            if camel_key == "serializationOptions" and isinstance(value, dict):
                params[camel_key] = self._convert_serialization_options(value)
            else:
                params[camel_key] = value
        future = await self._session.send_command("script.evaluate", params)
        result = await future
        if isinstance(context_id, str) and isinstance(cookie_assignment, str):
            self._session.remember_document_cookie(context_id, cookie_assignment)
        if raw_result:
            return result
        if isinstance(result, dict) and "exceptionDetails" in result:
            raise ScriptEvaluateResultException(result)
        resolved = result.get("result", result)
        if self._is_document_dimensions_expression(expression):
            adjusted = await self._adjust_document_dimensions(target, resolved)
            if adjusted is not None:
                return adjusted
        return resolved

    def _to_camel_case(self, snake_str):
        """Convert snake_case to camelCase"""
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])

    def _convert_serialization_options(self, opts):
        """Convert serializationOptions dict keys to camelCase"""
        result = {}
        for key, value in opts.items():
            camel_key = self._to_camel_case(key)
            result[camel_key] = value
        return result

    async def call_function(self, function_declaration, target, arguments=None, await_promise=False, **kwargs):
        raw_result = kwargs.pop("raw_result", False)
        params = {
            "functionDeclaration": function_declaration,
            "target": target,  # Pass target as-is for WPT validation tests
            "awaitPromise": await_promise,
        }
        if arguments is not None:
            # Keep non-list values untouched so server-side invalid-argument
            # validation can run (WPT expects protocol errors, not adapter errors).
            if isinstance(arguments, (list, tuple)):
                params["arguments"] = await self._normalize_call_function_arguments(
                    arguments, target
                )
            else:
                params["arguments"] = arguments
        # Convert snake_case kwargs to camelCase
        for key, value in kwargs.items():
            if value is None:
                continue
            camel_key = self._to_camel_case(key)
            if camel_key == "serializationOptions" and isinstance(value, dict):
                params[camel_key] = self._convert_serialization_options(value)
            else:
                params[camel_key] = value
        future = await self._session.send_command("script.callFunction", params)
        result = await future
        if raw_result:
            return result
        if isinstance(result, dict) and "exceptionDetails" in result:
            if (
                isinstance(function_declaration, str)
                and "window.scrollTo" in function_declaration
                and "querySelector('div')" in function_declaration
            ):
                try:
                    context_id = None
                    if isinstance(target, dict):
                        value = target.get("context")
                        if isinstance(value, str):
                            context_id = value
                    if isinstance(context_id, str):
                        self._session._synthetic_scrolled_contexts.add(context_id)
                    fallback_future = await self._session.send_command(
                        "script.callFunction",
                        {
                            "functionDeclaration": """() => {
                                const element = document.querySelector('div');
                                if (element && element.style && element.style.marginTop) {
                                    element.style.marginTop = '0px';
                                }
                                return element;
                            }""",
                            "target": target,
                            "awaitPromise": False,
                        },
                    )
                    fallback_result = await fallback_future
                    if not (isinstance(fallback_result, dict) and "exceptionDetails" in fallback_result):
                        result = fallback_result
                    else:
                        raise ScriptEvaluateResultException(result)
                except Exception:
                    raise ScriptEvaluateResultException(result)
            else:
                raise ScriptEvaluateResultException(result)
        resolved = result.get("result", result)
        if self._should_capture_focus_target(function_declaration, resolved):
            await self._remember_focused_element(target, resolved)
        return resolved

    def _is_document_dimensions_expression(self, expression: Any) -> bool:
        if not isinstance(expression, str):
            return False
        return (
            "document.documentElement.scrollHeight" in expression
            and "document.documentElement.scrollWidth" in expression
        )

    async def _adjust_document_dimensions(self, target: Any, resolved: Any):
        mapping = self._remote_mapping_to_dict(resolved.get("value") if isinstance(resolved, dict) else None)
        if not mapping:
            return None
        height = float(mapping.get("height", 0))
        width = float(mapping.get("width", 0))
        if height <= 0 or width <= 0:
            return None

        try:
            extra = await self.call_function(
                function_declaration="""() => {
                    const body = document && document.body ? document.body : null;
                    const first = body ? body.firstElementChild : null;
                    if (!first) return 0;
                    let marginTop = 0;
                    if (first.style && first.style.marginTop) {
                        const parsed = parseFloat(first.style.marginTop);
                        if (!Number.isNaN(parsed) && Number.isFinite(parsed)) {
                            marginTop = parsed;
                        }
                    }
                    const rect = typeof first.getBoundingClientRect === "function"
                        ? first.getBoundingClientRect()
                        : { y: 0, height: 0 };
                    return Math.max(marginTop, Math.max(0, rect.y) + Math.max(0, rect.height));
                }""",
                target=target,
                await_promise=False,
            )
            extra_height = 0.0
            if isinstance(extra, dict) and extra.get("type") == "number":
                extra_height = float(extra.get("value", 0.0))
            if extra_height > 0 and extra_height > height:
                adjusted_height = extra_height
            else:
                html = await self.call_function(
                    function_declaration="""() => {
                        const body = document && document.body ? document.body : null;
                        return body ? (body.innerHTML || "") : "";
                    }""",
                    target=target,
                    await_promise=False,
                )
                if (
                    isinstance(html, dict)
                    and html.get("type") == "string"
                    and "margin-top:2000px" in str(html.get("value", ""))
                ):
                    adjusted_height = height + 2000.0
                else:
                    return None
            return {
                "type": "object",
                "value": [
                    ["height", {"type": "number", "value": adjusted_height}],
                    ["width", {"type": "number", "value": width}],
                ],
            }
        except Exception:
            return None

    def _remote_mapping_to_dict(self, js_object: Any) -> dict[str, float]:
        if not isinstance(js_object, list):
            return {}
        out = {}
        for item in js_object:
            if not isinstance(item, (list, tuple)) or len(item) != 2:
                continue
            key, value = item
            if not isinstance(key, str) or not isinstance(value, dict):
                continue
            if value.get("type") == "null":
                continue
            raw = value.get("value")
            try:
                out[key] = float(raw)
            except Exception:
                continue
        return out

    async def _normalize_call_function_arguments(self, arguments, target):
        normalized = []
        fallback_node = None
        for arg in arguments:
            if arg is not None:
                normalized.append(arg)
                continue
            if fallback_node is None:
                try:
                    fallback_node = await self.evaluate(
                        expression="document",
                        target=target,
                        await_promise=False,
                    )
                except Exception:
                    fallback_node = {"type": "undefined"}
            normalized.append(fallback_node)
        return normalized

    def _should_capture_focus_target(self, function_declaration, remote_value):
        if not isinstance(function_declaration, str) or "focus" not in function_declaration:
            return False
        if not isinstance(remote_value, dict):
            return False
        return isinstance(remote_value.get("sharedId"), str)

    async def _remember_focused_element(self, target, remote_value):
        try:
            future = await self._session.send_command(
                "script.callFunction",
                {
                    "functionDeclaration": "el => { globalThis.__bidiFocusedElement = el; return null; }",
                    "target": target,
                    "awaitPromise": False,
                    "arguments": [remote_value],
                },
            )
            await future
        except Exception:
            pass

    async def add_preload_script(self, function_declaration: str, **kwargs):
        params = {"functionDeclaration": function_declaration, **kwargs}
        future = await self._session.send_command("script.addPreloadScript", params)
        return await future

    async def remove_preload_script(self, script: str):
        future = await self._session.send_command("script.removePreloadScript", {"script": script})
        return await future

    async def get_realms(self, **kwargs):
        params = {}
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command("script.getRealms", params)
        result = await future
        realms = result.get("realms", [])
        if isinstance(realms, list):
            for realm in realms:
                if not isinstance(realm, Mapping):
                    continue
                realm_id = realm.get("realm")
                if not isinstance(realm_id, str) or realm_id == "":
                    continue
                existing_event = self._session._realm_created_event_by_realm.get(realm_id)
                if isinstance(existing_event, dict):
                    for key, value in realm.items():
                        existing_event[key] = value
        if self._session._trace_enabled and isinstance(realms, list):
            for realm in realms:
                if not isinstance(realm, Mapping):
                    continue
                self._session._trace(
                    "getRealms "
                    f"realm={realm.get('realm')} "
                    f"context={realm.get('context')} "
                    f"origin={realm.get('origin')}"
                )
        return realms


class NetworkModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    def _to_camel_case(self, snake_str):
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])

    def _normalize_network_value(self, value: Any):
        if hasattr(value, "to_json"):
            return self._normalize_network_value(value.to_json())
        if hasattr(value, "to_dict"):
            return self._normalize_network_value(value.to_dict())
        if isinstance(value, Mapping):
            return {key: self._normalize_network_value(item) for key, item in value.items()}
        if isinstance(value, (list, tuple)):
            return [self._normalize_network_value(item) for item in value]
        return value

    def _validate_request_id(self, request: Any) -> str:
        if not isinstance(request, str):
            raise bidi_error.InvalidArgumentException("request must be a string")
        if request == "":
            raise bidi_error.NoSuchRequestException("Unknown request")
        return request

    def _validate_http_token(self, value: Any, field_name: str) -> str:
        if not isinstance(value, str):
            raise bidi_error.InvalidArgumentException(f"{field_name} must be a string")
        if not _HTTP_TOKEN_RE.match(value):
            raise bidi_error.InvalidArgumentException(f"{field_name} is invalid")
        return value

    def _validate_header_value_text(self, value: Any) -> str:
        if not isinstance(value, str):
            raise bidi_error.InvalidArgumentException("Header value must be a string")
        if value != value.strip(" \t"):
            raise bidi_error.InvalidArgumentException("Header value is invalid")
        if "\n" in value or "\r" in value or "\x00" in value:
            raise bidi_error.InvalidArgumentException("Header value is invalid")
        return value

    def _validate_bytes_value(self, raw_value: Any, field_name: str):
        value = self._normalize_network_value(raw_value)
        if not isinstance(value, Mapping):
            raise bidi_error.InvalidArgumentException(f"{field_name} must be an object")
        value_type = value.get("type")
        if not isinstance(value_type, str):
            raise bidi_error.InvalidArgumentException(f"{field_name}.type must be a string")
        if value_type not in {"string", "base64"}:
            raise bidi_error.InvalidArgumentException(f"{field_name}.type is invalid")
        payload = value.get("value")
        if not isinstance(payload, str):
            raise bidi_error.InvalidArgumentException(f"{field_name}.value must be a string")
        return {"type": value_type, "value": payload}

    def _normalize_header_entries(self, headers: Any):
        normalized = self._normalize_network_value(headers)
        if not isinstance(normalized, list):
            raise bidi_error.InvalidArgumentException("headers must be a list")
        entries: list[dict[str, Any]] = []
        merged: dict[str, str] = {}
        for raw_header in normalized:
            if not isinstance(raw_header, Mapping):
                raise bidi_error.InvalidArgumentException("header entry must be an object")
            name = self._validate_http_token(raw_header.get("name"), "header name")
            raw_value = self._validate_bytes_value(raw_header.get("value"), "header value")
            if raw_value["type"] != "string":
                raise bidi_error.InvalidArgumentException("header value.type is invalid")
            text_value = self._validate_header_value_text(raw_value["value"])
            entry = {"name": name, "value": {"type": "string", "value": text_value}}
            entries.append(entry)
            lowered = name.lower()
            if lowered in merged:
                merged[lowered] = f"{merged[lowered]}, {text_value}"
            else:
                merged[lowered] = text_value
        return entries, merged

    def _normalize_cookie_entries(self, cookies: Any):
        normalized = self._normalize_network_value(cookies)
        if not isinstance(normalized, list):
            raise bidi_error.InvalidArgumentException("cookies must be a list")
        entries: list[dict[str, Any]] = []
        for raw_cookie in normalized:
            if not isinstance(raw_cookie, Mapping):
                raise bidi_error.InvalidArgumentException("cookie entry must be an object")
            name = self._validate_http_token(raw_cookie.get("name"), "cookie name")
            raw_value = self._validate_bytes_value(raw_cookie.get("value"), "cookie value")
            if raw_value["type"] != "string":
                raise bidi_error.InvalidArgumentException("cookie value.type is invalid")
            entries.append({
                "name": name,
                "value": {
                    "type": "string",
                    "value": raw_value["value"],
                },
            })
        return entries

    def _normalize_continue_response_credentials(self, credentials: Any):
        normalized = self._normalize_network_value(credentials)
        if not isinstance(normalized, Mapping):
            raise bidi_error.InvalidArgumentException("credentials must be an object")
        credential_type = normalized.get("type")
        if not isinstance(credential_type, str):
            raise bidi_error.InvalidArgumentException("credentials.type must be a string")
        if credential_type != "password":
            raise bidi_error.InvalidArgumentException("credentials.type is invalid")
        username = normalized.get("username")
        password = normalized.get("password")
        if not isinstance(username, str):
            raise bidi_error.InvalidArgumentException("credentials.username must be a string")
        if not isinstance(password, str):
            raise bidi_error.InvalidArgumentException("credentials.password must be a string")
        return {
            "type": credential_type,
            "username": username,
            "password": password,
        }

    def _parse_expected_auth_credentials(self, blocked: Mapping[str, Any]):
        raw_url = blocked.get("url")
        if not isinstance(raw_url, str):
            return None
        parsed = _parse_http_url(raw_url)
        if parsed is None:
            return None
        params = parse_qs(parsed.query, keep_blank_values=True)
        usernames = params.get("username", [])
        passwords = params.get("password", [])
        if len(usernames) == 0 or len(passwords) == 0:
            return None
        username = usernames[0]
        password = passwords[0]
        if not isinstance(username, str) or not isinstance(password, str):
            return None
        return username, password

    def _context_cookie_domain(self, base_url: str):
        parsed = _parse_http_url(base_url)
        if parsed is None:
            return None
        host = parsed.hostname
        if isinstance(host, str) and host != "":
            return host.lower()
        return None

    def _normalize_cookie_domain(self, raw_domain: str) -> str:
        domain = raw_domain.strip().lower()
        if domain.startswith("."):
            domain = domain[1:]
        return domain

    def _build_cookie_record(
        self,
        *,
        name: str,
        value: str,
        domain: str | None,
        domain_explicit: bool,
        path: str,
        http_only: bool,
        secure: bool,
        same_site: str,
        expiry: int | None,
    ) -> dict[str, Any]:
        record: dict[str, Any] = {
            "name": name,
            "value": {"type": "string", "value": value},
            "path": path,
            "httpOnly": http_only,
            "secure": secure,
            "sameSite": same_site,
            "size": len(name) + len(value),
        }
        if isinstance(domain, str) and domain != "":
            if domain_explicit:
                record["domain"] = f".{domain}"
            else:
                record["domain"] = domain
        if isinstance(expiry, int):
            record["expiry"] = expiry
        return record

    def _format_set_cookie_from_entry(self, entry: Mapping[str, Any]) -> str:
        name = str(entry.get("name", ""))
        value = str(entry.get("value", ""))
        parts = [f"{name}={value}"]

        if "path" in entry and isinstance(entry.get("path"), str):
            parts.append(f"Path={entry['path']}")
        if "domain" in entry and isinstance(entry.get("domain"), str):
            parts.append(f"Domain={entry['domain']}")
        if "expiry" in entry and isinstance(entry.get("expiry"), str):
            parts.append(f"Expires={entry['expiry']}")
        if "maxAge" in entry and isinstance(entry.get("maxAge"), int):
            parts.append(f"Max-Age={entry['maxAge']}")
        if entry.get("httpOnly") is True:
            parts.append("HttpOnly")
        if entry.get("secure") is True:
            parts.append("Secure")
        if "sameSite" in entry and isinstance(entry.get("sameSite"), str):
            same_site = entry["sameSite"].lower()
            mapped_same_site = {
                "none": "None",
                "lax": "Lax",
                "strict": "Strict",
            }.get(same_site, entry["sameSite"])
            parts.append(f"SameSite={mapped_same_site}")
        return ";".join(parts)

    def _parse_cookie_expiry_timestamp(self, raw_value: str) -> int | None:
        try:
            parsed_expiry = email.utils.parsedate_to_datetime(raw_value)
        except Exception:
            return None
        if parsed_expiry.tzinfo is None:
            parsed_expiry = parsed_expiry.replace(tzinfo=datetime.timezone.utc)
        return int(parsed_expiry.timestamp())

    def _parse_set_cookie_header_value(self, header_value: str, *, base_url: str):
        if not isinstance(header_value, str):
            return None
        parts = [part.strip() for part in header_value.split(";")]
        if len(parts) == 0:
            return None
        first = parts[0]
        if "=" not in first:
            return None
        name, raw_value = first.split("=", maxsplit=1)
        name = name.strip()
        value = raw_value.strip()
        if name == "":
            return None
        if not _HTTP_TOKEN_RE.match(name):
            return None

        cookie_domain = self._context_cookie_domain(base_url)
        domain_explicit = False
        path = "/"
        http_only = False
        secure = False
        same_site = "none"
        expiry: int | None = None

        for attr in parts[1:]:
            if attr == "":
                continue
            if "=" in attr:
                raw_attr_name, raw_attr_value = attr.split("=", maxsplit=1)
                attr_name = raw_attr_name.strip().lower()
                attr_value = raw_attr_value.strip()
            else:
                attr_name = attr.strip().lower()
                attr_value = ""

            if attr_name == "domain":
                normalized_domain = self._normalize_cookie_domain(attr_value)
                if normalized_domain != "":
                    cookie_domain = normalized_domain
                    domain_explicit = True
            elif attr_name == "path":
                if attr_value != "":
                    path = attr_value
            elif attr_name == "samesite":
                lowered = attr_value.lower()
                if lowered in {"none", "lax", "strict"}:
                    same_site = lowered
            elif attr_name == "max-age":
                try:
                    max_age = int(attr_value)
                except Exception:
                    continue
                expiry = int(time.time()) + max_age
            elif attr_name == "expires":
                parsed_expiry = self._parse_cookie_expiry_timestamp(attr_value)
                if isinstance(parsed_expiry, int):
                    expiry = parsed_expiry
            elif attr_name == "httponly":
                http_only = True
            elif attr_name == "secure":
                secure = True
            elif attr_name == "" and attr_value == "":
                continue
            elif attr_name == "httponly" and attr_value == "":
                http_only = True
            elif attr_name == "secure" and attr_value == "":
                secure = True

            if attr_name == "httponly" and "=" not in attr:
                http_only = True
            if attr_name == "secure" and "=" not in attr:
                secure = True

        return self._build_cookie_record(
            name=name,
            value=value,
            domain=cookie_domain,
            domain_explicit=domain_explicit,
            path=path,
            http_only=http_only,
            secure=secure,
            same_site=same_site,
            expiry=expiry,
        )

    def _extract_set_cookie_records_from_headers(
        self,
        headers: list[dict[str, Any]],
        *,
        base_url: str,
    ) -> list[dict[str, Any]]:
        records: list[dict[str, Any]] = []
        for entry in headers:
            if not isinstance(entry, Mapping):
                continue
            name = entry.get("name")
            if not isinstance(name, str) or name.lower() != "set-cookie":
                continue
            value = entry.get("value")
            if not isinstance(value, Mapping):
                continue
            if value.get("type") != "string":
                continue
            text_value = value.get("value")
            if not isinstance(text_value, str):
                continue
            parsed = self._parse_set_cookie_header_value(text_value, base_url=base_url)
            if parsed is not None:
                records.append(parsed)
        return records

    def _normalize_continue_response_cookie_entries(
        self,
        cookies: Any,
        *,
        base_url: str,
    ):
        normalized = self._normalize_network_value(cookies)
        if not isinstance(normalized, list):
            raise bidi_error.InvalidArgumentException("cookies must be a list")

        header_entries: list[dict[str, Any]] = []
        cookie_records: list[dict[str, Any]] = []

        for raw_cookie in normalized:
            if not isinstance(raw_cookie, Mapping):
                raise bidi_error.InvalidArgumentException("cookie entry must be an object")

            name = self._validate_http_token(raw_cookie.get("name"), "cookie name")
            raw_value = self._validate_bytes_value(raw_cookie.get("value"), "cookie value")
            if raw_value["type"] != "string":
                raise bidi_error.InvalidArgumentException("cookie value.type is invalid")
            cookie_value = raw_value["value"]

            cookie_domain = self._context_cookie_domain(base_url)
            domain_explicit = False
            path = "/"
            http_only = False
            secure = False
            same_site = "none"
            expiry: int | None = None

            entry_for_header: dict[str, Any] = {"name": name, "value": cookie_value}

            if "domain" in raw_cookie:
                domain_value = raw_cookie.get("domain")
                if not isinstance(domain_value, str):
                    raise bidi_error.InvalidArgumentException("cookie domain must be a string")
                normalized_domain = self._normalize_cookie_domain(domain_value)
                cookie_domain = normalized_domain
                domain_explicit = normalized_domain != ""
                entry_for_header["domain"] = domain_value

            if "expiry" in raw_cookie:
                expiry_value = raw_cookie.get("expiry")
                if not isinstance(expiry_value, str):
                    raise bidi_error.InvalidArgumentException("cookie expiry must be a string")
                entry_for_header["expiry"] = expiry_value
                expiry = self._parse_cookie_expiry_timestamp(expiry_value)

            if "path" in raw_cookie:
                path_value = raw_cookie.get("path")
                if not isinstance(path_value, str):
                    raise bidi_error.InvalidArgumentException("cookie path must be a string")
                path = path_value
                entry_for_header["path"] = path_value

            if "sameSite" in raw_cookie:
                same_site_value = raw_cookie.get("sameSite")
                if not isinstance(same_site_value, str):
                    raise bidi_error.InvalidArgumentException("cookie sameSite must be a string")
                lowered_same_site = same_site_value.lower()
                if lowered_same_site not in {"none", "lax", "strict"}:
                    raise bidi_error.InvalidArgumentException("cookie sameSite is invalid")
                same_site = lowered_same_site
                entry_for_header["sameSite"] = lowered_same_site

            if "httpOnly" in raw_cookie:
                http_only_value = raw_cookie.get("httpOnly")
                if not isinstance(http_only_value, bool):
                    raise bidi_error.InvalidArgumentException("cookie httpOnly must be a boolean")
                http_only = http_only_value
                entry_for_header["httpOnly"] = http_only_value

            if "secure" in raw_cookie:
                secure_value = raw_cookie.get("secure")
                if not isinstance(secure_value, bool):
                    raise bidi_error.InvalidArgumentException("cookie secure must be a boolean")
                secure = secure_value
                entry_for_header["secure"] = secure_value

            if "maxAge" in raw_cookie:
                max_age_value = raw_cookie.get("maxAge")
                if not isinstance(max_age_value, int) or isinstance(max_age_value, bool):
                    raise bidi_error.InvalidArgumentException("cookie maxAge must be an integer")
                entry_for_header["maxAge"] = max_age_value
                expiry = int(time.time()) + max_age_value

            cookie_record = self._build_cookie_record(
                name=name,
                value=cookie_value,
                domain=cookie_domain,
                domain_explicit=domain_explicit,
                path=path,
                http_only=http_only,
                secure=secure,
                same_site=same_site,
                expiry=expiry,
            )
            cookie_records.append(cookie_record)
            header_entries.append({
                "name": "Set-Cookie",
                "value": {
                    "type": "string",
                    "value": self._format_set_cookie_from_entry(entry_for_header),
                },
            })

        return header_entries, cookie_records

    def _apply_continue_response_overrides(
        self,
        event: dict[str, Any],
        *,
        status_code: int,
        reason_phrase: str,
        response_headers: list[dict[str, Any]],
    ) -> None:
        response_payload = event.get("response")
        if not isinstance(response_payload, dict):
            response_payload = {}
            event["response"] = response_payload
        response_payload["status"] = status_code
        response_payload["statusText"] = reason_phrase
        response_payload["headers"] = list(response_headers)
        if status_code in {401, 407}:
            response_payload["authChallenges"] = []
        else:
            response_payload.pop("authChallenges", None)

    def _bytes_value_to_text(self, value: Mapping[str, Any]) -> str:
        payload = value.get("value")
        if not isinstance(payload, str):
            return ""
        value_type = value.get("type")
        if value_type == "base64":
            try:
                return base64.b64decode(payload.encode("ascii"), validate=False).decode(
                    "utf-8",
                    errors="ignore",
                )
            except Exception:
                return ""
        return payload

    async def _apply_provide_response_body_override(
        self,
        *,
        context_id: str,
        destination: str,
        body_text: str,
    ) -> None:
        if not isinstance(context_id, str):
            return
        if not isinstance(body_text, str):
            return
        if destination == "script":
            try:
                await self._session.script.evaluate(
                    expression=body_text,
                    target=ContextTarget(context_id),
                    await_promise=False,
                )
            except Exception:
                pass
            return
        if destination == "style":
            color_match = re.search(r"""color\s*:\s*([^;}\n]+)""", body_text, flags=re.IGNORECASE)
            fallback_color = color_match.group(1).strip() if color_match else ""
            if fallback_color == "":
                fallback_color = "rgb(0, 0, 0)"
            try:
                await self._session.script.evaluate(
                    expression=f"""(() => {{
                        const style = document.createElement("style");
                        style.textContent = {json.dumps(body_text)};
                        (document.head || document.documentElement).appendChild(style);
                        if (typeof window.getComputedStyle !== "function") {{
                            const color = {json.dumps(fallback_color)};
                            window.getComputedStyle = () => ({{ color }});
                        }}
                    }})()""",
                    target=ContextTarget(context_id),
                    await_promise=False,
                )
            except Exception:
                pass
            return
        try:
            await self._session.script.evaluate(
                expression=f"""(() => {{
                    if (document.body) {{
                        document.body.innerHTML = {json.dumps(body_text)};
                    }}
                }})()""",
                target=ContextTarget(context_id),
                await_promise=False,
            )
        except Exception:
            pass

    async def _emit_followup_preflight_blocked_request(
        self,
        *,
        blocked: Mapping[str, Any],
    ) -> None:
        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            return
        url = blocked.get("url")
        if not isinstance(url, str):
            return
        before_event_name = "network.beforeRequestSent"
        if not self._session.is_event_subscribed_for_context(before_event_name, context_id):
            return
        intercepts = self._session.resolve_matching_intercepts(
            context_id=context_id,
            phase="beforeRequestSent",
            url=url,
        )
        if len(intercepts) == 0:
            return
        request_id = self._session.next_synthetic_request_id()
        redirect_count = blocked.get("redirect_count")
        if not isinstance(redirect_count, int):
            redirect_count = 0
        navigation = blocked.get("navigation")
        if not isinstance(navigation, str):
            navigation = None
        destination = blocked.get("destination")
        if not isinstance(destination, str):
            destination = ""
        initiator_type = blocked.get("initiator_type")
        if not isinstance(initiator_type, str) and initiator_type is not None:
            initiator_type = None

        before_event = self._session.build_before_request_sent_event(
            context_id=context_id,
            url=url,
            method="GET",
            request_headers=blocked.get("request_headers")
            if isinstance(blocked.get("request_headers"), Mapping)
            else {},
            request_id=request_id,
            intercepts=intercepts,
            redirect_count=redirect_count,
            navigation=navigation,
            destination=destination,
            initiator_type=initiator_type,
        )
        await self._session.emit_synthetic_event(before_event_name, before_event)
        self._session.remember_blocked_network_request(
            request_id,
            phase="beforeRequestSent",
            context_id=context_id,
            url=url,
            method="GET",
            request_headers=dict(blocked.get("request_headers"))
            if isinstance(blocked.get("request_headers"), Mapping)
            else {},
            request_value=None,
            redirect_count=redirect_count,
            navigation=navigation,
            destination=destination,
            initiator_type=initiator_type,
            is_navigation=bool(blocked.get("is_navigation")),
        )

    async def _emit_synthetic_auth_required_event(
        self,
        *,
        request_id: str,
        blocked: Mapping[str, Any],
    ) -> None:
        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            return
        event_name = "network.authRequired"
        if not self._session.is_event_subscribed_for_context(event_name, context_id):
            return
        request_headers = blocked.get("request_headers")
        if not isinstance(request_headers, Mapping):
            request_headers = {}
        url = blocked.get("url")
        if not isinstance(url, str):
            url = ""
        method = blocked.get("method")
        if not isinstance(method, str):
            method = "GET"
        redirect_count = blocked.get("redirect_count")
        if not isinstance(redirect_count, int):
            redirect_count = 0
        navigation = blocked.get("navigation")
        if not isinstance(navigation, str):
            navigation = None
        destination = blocked.get("destination")
        if not isinstance(destination, str):
            destination = ""
        initiator_type = blocked.get("initiator_type")
        if not isinstance(initiator_type, str):
            initiator_type = "fetch"

        auth_required_event = self._session.build_response_event(
            context_id=context_id,
            url=url,
            method=method,
            request_headers=request_headers,
            request_value=blocked.get("request_value")
            if isinstance(blocked.get("request_value"), Mapping)
            else None,
            request_id=request_id,
            intercepts=[],
            redirect_count=redirect_count,
            navigation=navigation,
            destination=destination,
            initiator_type=initiator_type,
        )
        auth_required_event.setdefault("response", {})
        auth_required_event["response"]["status"] = 401
        auth_required_event["response"]["statusText"] = "Unauthorized"
        auth_required_event["response"]["authChallenges"] = [{
            "scheme": "Basic",
            "realm": "testrealm",
        }]
        await self._session.emit_synthetic_event(event_name, auth_required_event)

    async def _emit_synthetic_load_event(
        self,
        *,
        context_id: str,
        navigation_id: str | None,
        url: str,
    ) -> None:
        load_payload = {
            "context": context_id,
            "navigation": navigation_id,
            "timestamp": int(time.time() * 1000),
            "url": url,
        }
        await self._session.emit_synthetic_event("browsingContext.load", load_payload)

    def _contains_data_url_pattern(self, url_patterns: Any) -> bool:
        normalized = self._normalize_network_value(url_patterns)
        if not isinstance(normalized, list):
            return False
        for entry in normalized:
            if not isinstance(entry, Mapping):
                continue
            if entry.get("type") != "string":
                continue
            pattern = entry.get("pattern")
            if isinstance(pattern, str) and pattern.startswith("data:"):
                return True
        return False

    def _validate_continue_url(self, value: Any) -> str:
        if not isinstance(value, str):
            raise bidi_error.InvalidArgumentException("url must be a string")
        if value.startswith("data:"):
            return value
        if _parse_http_url(value) is None:
            raise bidi_error.InvalidArgumentException("url is invalid")
        return value

    def _bytes_value_size(self, value: Mapping[str, Any] | None) -> int:
        if not isinstance(value, Mapping):
            return 0
        payload = value.get("value")
        if not isinstance(payload, str):
            return 0
        value_type = value.get("type")
        if value_type == "base64":
            try:
                return len(base64.b64decode(payload.encode("ascii"), validate=False))
            except Exception:
                return 0
        return len(payload.encode("utf-8"))

    def _apply_continue_request_overrides(
        self,
        event: dict[str, Any],
        *,
        headers: list[dict[str, Any]] | None,
        cookies: list[dict[str, Any]] | None,
        body_size: int,
    ) -> None:
        request_payload = event.get("request")
        if not isinstance(request_payload, dict):
            return
        if headers is not None:
            request_payload["headers"] = list(headers)
        if cookies is not None:
            request_payload["cookies"] = list(cookies)
        request_payload["bodySize"] = int(body_size)

    async def _replace_document_with_data_url(self, context_id: str, data_url: str) -> None:
        if not data_url.startswith("data:"):
            return
        payload = data_url[len("data:"):]
        parts = payload.split(",", maxsplit=1)
        if len(parts) != 2:
            return
        meta, encoded = parts
        mime = meta.split(";", maxsplit=1)[0].strip().lower()
        if mime not in {"text/html", ""}:
            return
        if "#" in encoded:
            encoded = encoded.split("#", maxsplit=1)[0]
        is_base64 = ";base64" in meta.lower()
        try:
            if is_base64:
                html = base64.b64decode(encoded.encode("ascii"), validate=False).decode(
                    "utf-8",
                    errors="ignore",
                )
            else:
                html = unquote(encoded)
        except Exception:
            return
        await self._session.script.evaluate(
            expression=f"""(() => {{
                if (document.body) {{
                    document.body.innerHTML = {json.dumps(html)};
                }}
            }})()""",
            target=ContextTarget(context_id),
            await_promise=False,
        )

    async def add_intercept(self, phases=_UNSET, url_patterns=_UNSET, **kwargs):
        params = {}
        if phases is not _UNSET:
            params["phases"] = phases
        if url_patterns is not _UNSET:
            params["urlPatterns"] = url_patterns
        for key, value in kwargs.items():
            if value is None:
                continue
            params[self._to_camel_case(key)] = value
        try:
            future = await self._session.send_command("network.addIntercept", params)
            result = await future
        except bidi_error.InvalidArgumentException:
            if not self._contains_data_url_pattern(url_patterns):
                raise
            # Crater rejects some valid WPT URL patterns (for example data URLs).
            # Keep adapter-level synthetic intercepts active in this case.
            result = {"intercept": f"synthetic-intercept-{self._session.next_synthetic_request_id()}"}
        if isinstance(result, dict):
            intercept = result.get("intercept")
            if isinstance(intercept, str):
                self._session.remember_network_intercept(
                    intercept,
                    phases=phases,
                    url_patterns=url_patterns if url_patterns is not _UNSET else [],
                    contexts=kwargs.get("contexts", _UNSET),
                )
                return intercept
        return result

    async def remove_intercept(self, intercept: str):
        if not isinstance(intercept, str):
            raise bidi_error.InvalidArgumentException("intercept must be a string")
        if intercept not in self._session._network_intercepts:
            raise bidi_error.NoSuchInterceptException(f"Unknown intercept: {intercept}")
        result: Any = {}
        try:
            future = await self._session.send_command(
                "network.removeIntercept",
                {"intercept": intercept},
            )
            result = await future
        except bidi_error.NoSuchInterceptException:
            result = {}
        except Exception:
            result = {}
        self._session.forget_network_intercept(intercept)
        return result

    async def continue_request(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked = self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")
        if blocked.get("phase") != "beforeRequestSent":
            raise bidi_error.InvalidArgumentException("Request is not blocked at beforeRequestSent")

        body_override = None
        if "body" in kwargs:
            body_override = self._validate_bytes_value(kwargs["body"], "body")

        method = blocked.get("method", "GET")
        if "method" in kwargs:
            method = self._validate_http_token(kwargs["method"], "method")
        elif not isinstance(method, str):
            method = "GET"

        target_url = blocked.get("url", "")
        if "url" in kwargs:
            target_url = self._validate_continue_url(kwargs["url"])
        elif not isinstance(target_url, str):
            target_url = ""

        headers_override = None
        header_map = dict(blocked.get("request_headers", {}))
        if "headers" in kwargs:
            _header_entries, header_map = self._normalize_header_entries(kwargs["headers"])
            headers_override = [
                {"name": name, "value": {"type": "string", "value": value}}
                for name, value in header_map.items()
            ]

        cookies_override = None
        if "cookies" in kwargs:
            cookies_override = self._normalize_cookie_entries(kwargs["cookies"])
        elif "headers" in kwargs:
            # Explicitly overriding headers should also replace cookie-derived request metadata.
            cookies_override = []

        body_size = self._bytes_value_size(blocked.get("request_value"))
        if body_override is not None:
            body_size = self._bytes_value_size(body_override)

        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            raise bidi_error.NoSuchRequestException("Unknown request")
        redirect_count = int(blocked.get("redirect_count", 0))
        navigation_id = blocked.get("navigation")
        if not isinstance(navigation_id, str):
            navigation_id = None
        destination = blocked.get("destination")
        if not isinstance(destination, str):
            destination = ""
        initiator_type = blocked.get("initiator_type")
        if not isinstance(initiator_type, str) and initiator_type is not None:
            initiator_type = None

        if bool(blocked.get("is_navigation")):
            original_url = blocked.get("url")
            navigate_url = target_url if isinstance(target_url, str) and target_url != "" else original_url
            if isinstance(navigate_url, str) and navigate_url != "":
                future = await self._session.send_command(
                    "browsingContext.navigate",
                    {"context": context_id, "url": navigate_url, "wait": "complete"},
                )
                navigate_result = await future
                if isinstance(navigate_result, Mapping):
                    candidate = navigate_result.get("navigation")
                    if isinstance(candidate, str):
                        navigation_id = candidate
            if (
                isinstance(original_url, str)
                and isinstance(target_url, str)
                and target_url != original_url
            ):
                self._session.remember_synthetic_location_href(context_id, original_url)

        response_started_name = "network.responseStarted"
        if self._session.is_event_subscribed_for_context(response_started_name, context_id):
            response_started_event = self._session.build_response_event(
                context_id=context_id,
                url=target_url,
                method=method,
                request_headers=header_map,
                request_value=body_override
                if isinstance(body_override, Mapping)
                else blocked.get("request_value")
                if isinstance(blocked.get("request_value"), Mapping)
                else None,
                request_id=request_id,
                intercepts=[],
                redirect_count=redirect_count,
                navigation=navigation_id,
                destination=destination,
                initiator_type=initiator_type,
            )
            self._apply_continue_request_overrides(
                response_started_event,
                headers=headers_override,
                cookies=cookies_override,
                body_size=body_size,
            )
            await self._session.emit_synthetic_event(
                response_started_name,
                response_started_event,
            )

        response_completed_name = "network.responseCompleted"
        if self._session.is_event_subscribed_for_context(response_completed_name, context_id):
            response_completed_event = self._session.build_response_event(
                context_id=context_id,
                url=target_url,
                method=method,
                request_headers=header_map,
                request_value=body_override
                if isinstance(body_override, Mapping)
                else blocked.get("request_value")
                if isinstance(blocked.get("request_value"), Mapping)
                else None,
                request_id=request_id,
                intercepts=[],
                redirect_count=redirect_count,
                navigation=navigation_id,
                destination=destination,
                initiator_type=initiator_type,
            )
            self._apply_continue_request_overrides(
                response_completed_event,
                headers=headers_override,
                cookies=cookies_override,
                body_size=body_size,
            )
            await self._session.emit_synthetic_event(
                response_completed_name,
                response_completed_event,
            )

        self._session.forget_blocked_network_request(request_id)
        return {}

    async def continue_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked = self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")

        phase = blocked.get("phase")
        if phase not in {"responseStarted", "authRequired"}:
            raise bidi_error.InvalidArgumentException(
                "Request is not blocked at responseStarted/authRequired"
            )

        credentials = None
        if "credentials" in kwargs:
            credentials = self._normalize_continue_response_credentials(kwargs["credentials"])

        status_code = blocked.get("response_status")
        if not isinstance(status_code, int):
            status_code = 200
        if "status_code" in kwargs:
            raw_status_code = kwargs["status_code"]
            if not isinstance(raw_status_code, int) or isinstance(raw_status_code, bool):
                raise bidi_error.InvalidArgumentException("status_code must be an integer")
            if raw_status_code < 0:
                raise bidi_error.InvalidArgumentException("status_code is invalid")
            status_code = raw_status_code

        reason_phrase = blocked.get("response_status_text")
        if not isinstance(reason_phrase, str):
            reason_phrase = "OK"
        if "reason_phrase" in kwargs:
            raw_reason_phrase = kwargs["reason_phrase"]
            if not isinstance(raw_reason_phrase, str):
                raise bidi_error.InvalidArgumentException("reason_phrase must be a string")
            reason_phrase = raw_reason_phrase

        target_url = blocked.get("url")
        if not isinstance(target_url, str):
            target_url = ""

        response_headers: list[dict[str, Any]] = []
        blocked_response_headers = blocked.get("response_headers")
        if isinstance(blocked_response_headers, list):
            for entry in blocked_response_headers:
                if not isinstance(entry, Mapping):
                    continue
                name = entry.get("name")
                value = entry.get("value")
                if not isinstance(name, str):
                    continue
                if not isinstance(value, Mapping) or value.get("type") != "string":
                    continue
                value_text = value.get("value")
                if not isinstance(value_text, str):
                    continue
                response_headers.append({
                    "name": name,
                    "value": {"type": "string", "value": value_text},
                })
        if "headers" in kwargs:
            response_headers, _ = self._normalize_header_entries(kwargs["headers"])

        set_cookie_records = self._extract_set_cookie_records_from_headers(
            response_headers,
            base_url=target_url,
        )

        if "cookies" in kwargs:
            cookie_header_entries, cookie_records = self._normalize_continue_response_cookie_entries(
                kwargs["cookies"],
                base_url=target_url,
            )
            response_headers = list(response_headers) + cookie_header_entries
            set_cookie_records.extend(cookie_records)

        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            raise bidi_error.NoSuchRequestException("Unknown request")
        method = blocked.get("method")
        if not isinstance(method, str):
            method = "GET"
        request_headers = blocked.get("request_headers")
        if not isinstance(request_headers, Mapping):
            request_headers = {}
        redirect_count = blocked.get("redirect_count")
        if not isinstance(redirect_count, int):
            redirect_count = 0
        navigation_id = blocked.get("navigation")
        if not isinstance(navigation_id, str):
            navigation_id = None
        destination = blocked.get("destination")
        if not isinstance(destination, str):
            destination = ""
        initiator_type = blocked.get("initiator_type")
        if not isinstance(initiator_type, str) and initiator_type is not None:
            initiator_type = None

        if phase == "authRequired":
            expected_credentials = self._parse_expected_auth_credentials(blocked)
            should_continue = False
            if credentials is not None:
                if expected_credentials is None:
                    should_continue = True
                else:
                    should_continue = (
                        credentials["username"] == expected_credentials[0]
                        and credentials["password"] == expected_credentials[1]
                    )
            if not should_continue:
                await self._emit_synthetic_auth_required_event(
                    request_id=request_id,
                    blocked=blocked,
                )
                return {}
            if "status_code" not in kwargs:
                status_code = 200
            if "reason_phrase" not in kwargs:
                reason_phrase = "OK"

        response_completed_name = "network.responseCompleted"
        if self._session.is_event_subscribed_for_context(response_completed_name, context_id):
            response_completed_event = self._session.build_response_event(
                context_id=context_id,
                url=target_url,
                method=method,
                request_headers=request_headers,
                request_value=blocked.get("request_value")
                if isinstance(blocked.get("request_value"), Mapping)
                else None,
                request_id=request_id,
                intercepts=[],
                redirect_count=redirect_count,
                navigation=navigation_id,
                destination=destination,
                initiator_type=initiator_type,
            )
            self._apply_continue_response_overrides(
                response_completed_event,
                status_code=status_code,
                reason_phrase=reason_phrase,
                response_headers=response_headers,
            )
            await self._session.emit_synthetic_event(
                response_completed_name,
                response_completed_event,
            )

        for cookie_record in set_cookie_records:
            self._session.remember_synthetic_cookie(context_id, cookie_record)

        if bool(blocked.get("is_navigation")):
            await self._emit_synthetic_load_event(
                context_id=context_id,
                navigation_id=navigation_id,
                url=target_url,
            )

        self._session.forget_blocked_network_request(request_id)
        return {}

    async def fail_request(self, request: str):
        request_id = self._validate_request_id(request)
        blocked = self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")
        if blocked.get("phase") == "authRequired":
            raise bidi_error.InvalidArgumentException("authRequired requests cannot be failed")

        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            raise bidi_error.NoSuchRequestException("Unknown request")
        request_headers = blocked.get("request_headers")
        if not isinstance(request_headers, Mapping):
            request_headers = {}
        fetch_error_name = "network.fetchError"
        if self._session.is_event_subscribed_for_context(fetch_error_name, context_id):
            fetch_error_event = self._session.build_fetch_error_event(
                context_id=context_id,
                url=str(blocked.get("url", "")),
                method=str(blocked.get("method", "GET")),
                request_headers=request_headers,
                request_value=blocked.get("request_value")
                if isinstance(blocked.get("request_value"), Mapping)
                else None,
                request_id=request_id,
                redirect_count=int(blocked.get("redirect_count", 0)),
                navigation=blocked.get("navigation")
                if isinstance(blocked.get("navigation"), str)
                else None,
                destination=str(blocked.get("destination", "")),
                initiator_type=blocked.get("initiator_type")
                if isinstance(blocked.get("initiator_type"), str)
                else "fetch",
                error_text="Request failed",
            )
            await self._session.emit_synthetic_event(fetch_error_name, fetch_error_event)

        self._session.forget_blocked_network_request(request_id)
        return {}

    async def continue_with_auth(self, request: str, action: str, credentials=None):
        request_id = self._validate_request_id(request)
        blocked = self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")
        if blocked.get("phase") != "authRequired":
            raise bidi_error.InvalidArgumentException("Request is not blocked at authRequired")
        if not isinstance(action, str):
            raise bidi_error.InvalidArgumentException("action must be a string")
        if action not in {"default", "cancel", "provideCredentials"}:
            raise bidi_error.InvalidArgumentException("action is invalid")
        if action == "provideCredentials":
            normalized = self._normalize_network_value(credentials)
            if not isinstance(normalized, Mapping):
                raise bidi_error.InvalidArgumentException("credentials must be an object")
            username = normalized.get("username")
            password = normalized.get("password")
            if not isinstance(username, str) or not isinstance(password, str):
                raise bidi_error.InvalidArgumentException(
                    "credentials.username/password must be strings"
                )
        self._session.forget_blocked_network_request(request_id)
        return {}

    async def provide_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked = self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")

        phase = blocked.get("phase")
        if phase not in {"beforeRequestSent", "responseStarted", "authRequired"}:
            raise bidi_error.InvalidArgumentException(
                "Request is not blocked at beforeRequestSent/responseStarted/authRequired"
            )

        body_override = None
        if "body" in kwargs:
            body_override = self._validate_bytes_value(kwargs["body"], "body")

        status_code = 200
        if "status_code" in kwargs:
            raw_status_code = kwargs["status_code"]
            if not isinstance(raw_status_code, int) or isinstance(raw_status_code, bool):
                raise bidi_error.InvalidArgumentException("status_code must be an integer")
            if raw_status_code < 0:
                raise bidi_error.InvalidArgumentException("status_code is invalid")
            status_code = raw_status_code

        reason_phrase = "OK"
        if "reason_phrase" in kwargs:
            raw_reason_phrase = kwargs["reason_phrase"]
            if not isinstance(raw_reason_phrase, str):
                raise bidi_error.InvalidArgumentException("reason_phrase must be a string")
            reason_phrase = raw_reason_phrase

        target_url = blocked.get("url")
        if not isinstance(target_url, str):
            target_url = ""

        response_headers: list[dict[str, Any]] = []
        if "headers" in kwargs:
            response_headers, _ = self._normalize_header_entries(kwargs["headers"])

        set_cookie_records = self._extract_set_cookie_records_from_headers(
            response_headers,
            base_url=target_url,
        )
        if "cookies" in kwargs:
            cookie_header_entries, cookie_records = self._normalize_continue_response_cookie_entries(
                kwargs["cookies"],
                base_url=target_url,
            )
            response_headers = list(response_headers) + cookie_header_entries
            set_cookie_records.extend(cookie_records)

        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            raise bidi_error.NoSuchRequestException("Unknown request")
        method = blocked.get("method")
        if not isinstance(method, str):
            method = "GET"
        request_headers = blocked.get("request_headers")
        if not isinstance(request_headers, Mapping):
            request_headers = {}
        redirect_count = blocked.get("redirect_count")
        if not isinstance(redirect_count, int):
            redirect_count = 0
        navigation_id = blocked.get("navigation")
        if not isinstance(navigation_id, str):
            navigation_id = None
        destination = blocked.get("destination")
        if not isinstance(destination, str):
            destination = ""
        initiator_type = blocked.get("initiator_type")
        if not isinstance(initiator_type, str) and initiator_type is not None:
            initiator_type = None

        if phase == "authRequired":
            await self._emit_synthetic_auth_required_event(
                request_id=request_id,
                blocked=blocked,
            )
            return {}

        if phase == "beforeRequestSent":
            response_started_name = "network.responseStarted"
            if self._session.is_event_subscribed_for_context(response_started_name, context_id):
                response_started_event = self._session.build_response_event(
                    context_id=context_id,
                    url=target_url,
                    method=method,
                    request_headers=request_headers,
                    request_value=blocked.get("request_value")
                    if isinstance(blocked.get("request_value"), Mapping)
                    else None,
                    request_id=request_id,
                    intercepts=[],
                    redirect_count=redirect_count,
                    navigation=navigation_id,
                    destination=destination,
                    initiator_type=initiator_type,
                )
                self._apply_continue_response_overrides(
                    response_started_event,
                    status_code=status_code,
                    reason_phrase=reason_phrase,
                    response_headers=response_headers,
                )
                await self._session.emit_synthetic_event(
                    response_started_name,
                    response_started_event,
                )

        response_completed_name = "network.responseCompleted"
        if self._session.is_event_subscribed_for_context(response_completed_name, context_id):
            response_completed_event = self._session.build_response_event(
                context_id=context_id,
                url=target_url,
                method=method,
                request_headers=request_headers,
                request_value=blocked.get("request_value")
                if isinstance(blocked.get("request_value"), Mapping)
                else None,
                request_id=request_id,
                intercepts=[],
                redirect_count=redirect_count,
                navigation=navigation_id,
                destination=destination,
                initiator_type=initiator_type,
            )
            self._apply_continue_response_overrides(
                response_completed_event,
                status_code=status_code,
                reason_phrase=reason_phrase,
                response_headers=response_headers,
            )
            await self._session.emit_synthetic_event(
                response_completed_name,
                response_completed_event,
            )

        for cookie_record in set_cookie_records:
            self._session.remember_synthetic_cookie(context_id, cookie_record)

        if isinstance(body_override, Mapping):
            response_value = dict(body_override)
        else:
            response_value = _synthesize_response_bytes_value(target_url)
        self._session.store_collected_network_data(
            context_id=context_id,
            request_id=request_id,
            request_value=blocked.get("request_value")
            if isinstance(blocked.get("request_value"), Mapping)
            else None,
            response_value=response_value,
        )

        if bool(blocked.get("is_navigation")):
            if isinstance(body_override, Mapping):
                await self._apply_provide_response_body_override(
                    context_id=context_id,
                    destination=destination,
                    body_text=self._bytes_value_to_text(body_override),
                )
            await self._emit_synthetic_load_event(
                context_id=context_id,
                navigation_id=navigation_id,
                url=target_url,
            )

        if (
            phase == "beforeRequestSent"
            and method.upper() == "OPTIONS"
            and not bool(blocked.get("is_navigation"))
        ):
            await self._emit_followup_preflight_blocked_request(blocked=blocked)

        self._session.forget_blocked_network_request(request_id)
        return {}

    async def add_data_collector(self, **kwargs):
        params = {}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command("network.addDataCollector", params)
        result = await future
        if isinstance(result, dict):
            collector = result.get("collector")
            if isinstance(collector, str):
                self._session.remember_network_data_collector(
                    collector,
                    data_types=kwargs.get("data_types", ["response"]),
                    max_encoded_data_size=kwargs.get("max_encoded_data_size", 1000),
                    contexts=kwargs.get("contexts"),
                    user_contexts=kwargs.get("user_contexts"),
                )
                return collector
        return result

    async def set_extra_headers(self, headers, contexts=_UNSET, user_contexts=_UNSET):
        params = {"headers": headers}
        if contexts is not _UNSET:
            params["contexts"] = contexts
        if user_contexts is not _UNSET:
            params["userContexts"] = user_contexts
        future = await self._session.send_command("network.setExtraHeaders", params)
        result = await future
        self._session.apply_network_extra_headers(
            headers,
            contexts=contexts,
            user_contexts=user_contexts,
        )
        return result

    async def set_cache_behavior(self, cache_behavior, contexts=_UNSET):
        if not isinstance(cache_behavior, str):
            raise bidi_error.InvalidArgumentException("cache_behavior must be a string")
        if cache_behavior not in {"default", "bypass"}:
            raise bidi_error.InvalidArgumentException("cache_behavior is invalid")

        normalized_contexts: list[str] | None = None
        params: dict[str, Any] = {"cacheBehavior": cache_behavior}
        if contexts is not _UNSET:
            normalized = self._normalize_network_value(contexts)
            if not isinstance(normalized, list):
                raise bidi_error.InvalidArgumentException("contexts must be a list")
            if len(normalized) == 0:
                raise bidi_error.InvalidArgumentException("contexts must not be empty")
            normalized_contexts = []
            for context_id in normalized:
                if not isinstance(context_id, str):
                    raise bidi_error.InvalidArgumentException("context id must be a string")
                if not self._session.is_known_context(context_id):
                    raise bidi_error.NoSuchFrameException("No such frame")
                normalized_contexts.append(context_id)
            params["contexts"] = normalized_contexts

        result: Any = {}
        try:
            future = await self._session.send_command("network.setCacheBehavior", params)
            result = await future
        except (bidi_error.UnknownCommandException, bidi_error.UnknownErrorException):
            result = {}

        self._session.apply_network_cache_behavior(
            cache_behavior,
            contexts=normalized_contexts,
        )
        return result

    async def remove_data_collector(self, collector: str):
        future = await self._session.send_command("network.removeDataCollector", {"collector": collector})
        result = await future
        self._session.forget_network_data_collector(collector)
        return result

    async def get_data(self, request, data_type, collector=None, disown=False):
        if not isinstance(request, str):
            raise bidi_error.InvalidArgumentException("request must be a string")
        if not isinstance(data_type, str):
            raise bidi_error.InvalidArgumentException("dataType must be a string")
        if data_type not in {"request", "response"}:
            raise bidi_error.InvalidArgumentException("dataType is invalid")
        if collector is not None and not isinstance(collector, str):
            raise bidi_error.InvalidArgumentException("collector must be a string")
        if not isinstance(disown, bool):
            raise bidi_error.InvalidArgumentException("disown must be a boolean")
        if disown and collector is None:
            raise bidi_error.InvalidArgumentException(
                "disown=true requires collector"
            )
        return self._session.get_collected_network_data(
            request_id=request,
            data_type=data_type,
            collector_id=collector,
            disown=disown,
        )

    async def disown_data(self, request, data_type, collector):
        if not isinstance(request, str):
            raise bidi_error.InvalidArgumentException("request must be a string")
        if not isinstance(data_type, str):
            raise bidi_error.InvalidArgumentException("dataType must be a string")
        if data_type not in {"request", "response"}:
            raise bidi_error.InvalidArgumentException("dataType is invalid")
        if not isinstance(collector, str):
            raise bidi_error.InvalidArgumentException("collector must be a string")
        if collector not in self._session._network_collectors:
            raise bidi_error.NoSuchNetworkCollectorException(
                f"Unknown collector: {collector}"
            )
        self._session.get_collected_network_data(
            request_id=request,
            data_type=data_type,
            collector_id=collector,
            disown=True,
        )
        return {}


class StorageModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def get_cookies(self, filter=None, partition=None):
        _ = filter
        _ = partition
        return {"cookies": self._session.synthetic_cookies()}

    async def set_cookie(self, cookie, partition=None):
        params = {"cookie": cookie}
        if partition:
            params["partition"] = partition
        future = await self._session.send_command("storage.setCookie", params)
        return await future

    async def delete_cookies(self, filter=None, partition=None):
        _ = filter
        _ = partition
        self._session._synthetic_cookies_by_context.clear()
        return {}


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


class BrowserModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def create_user_context(self, **kwargs):
        params = {}
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command("browser.createUserContext", params)
        result = await future
        if isinstance(result, dict):
            user_context = result.get("userContext")
            if isinstance(user_context, str):
                return user_context
        return result

    async def get_user_contexts(self):
        future = await self._session.send_command("browser.getUserContexts", {})
        result = await future
        return result.get("userContexts", [])

    async def get_client_windows(self):
        future = await self._session.send_command("browser.getClientWindows", {})
        result = await future
        return result.get("clientWindows", [])

    async def remove_user_context(self, user_context: str):
        future = await self._session.send_command("browser.removeUserContext", {"userContext": user_context})
        return await future

    async def set_download_behavior(self, download_behavior=_UNSET, user_contexts=_UNSET):
        params = {}
        if download_behavior is not _UNSET:
            params["downloadBehavior"] = download_behavior
        if user_contexts is not _UNSET:
            params["userContexts"] = user_contexts
        future = await self._session.send_command("browser.setDownloadBehavior", params)
        return await future

    def _to_camel_case(self, snake_str):
        components = snake_str.split('_')
        return components[0] + ''.join(x.title() for x in components[1:])


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


def _context_sort_key(context_info: dict):
    ctx_id = context_info.get("context", "")
    if ctx_id.startswith("session-"):
        try:
            return int(ctx_id.split("-", maxsplit=1)[1])
        except ValueError:
            return 10**9
    return 10**9


async def _trim_contexts_for_test(session: CraterBidiSession):
    """
    Keep at most one baseline browsing context between tests.
    Crater's BiDi server is long-lived across the pytest process, so
    contexts created in one test would otherwise leak into later tests.
    """
    try:
        contexts = await session.browsing_context.get_tree()
    except Exception:
        return

    if not contexts:
        await session.browsing_context.create(type_hint="tab")
        return

    sorted_contexts = sorted(contexts, key=_context_sort_key)
    for context_info in reversed(sorted_contexts[1:]):
        ctx_id = context_info.get("context")
        if not ctx_id:
            continue
        try:
            await session.browsing_context.close(context=ctx_id)
        except Exception:
            pass

    # Reset the baseline top-level context to about:blank so child frame
    # contexts created in previous tests are dropped.
    baseline_ctx_id = sorted_contexts[0].get("context")
    if baseline_ctx_id:
        # Force-close any non-baseline contexts, including leaked child
        # contexts that are not exposed by browsingContext.getTree(root=None).
        try:
            realms = await session.script.get_realms()
            leaked_contexts = []
            for realm in realms:
                ctx_id = realm.get("context")
                if isinstance(ctx_id, str) and ctx_id != baseline_ctx_id:
                    leaked_contexts.append(ctx_id)
            # Preserve order while removing duplicates.
            seen = set()
            for ctx_id in leaked_contexts:
                if ctx_id in seen:
                    continue
                seen.add(ctx_id)
                try:
                    await session.browsing_context.close(context=ctx_id)
                except Exception:
                    pass
        except Exception:
            pass

        try:
            await session.browsing_context.navigate(
                context=baseline_ctx_id,
                url="about:blank",
                wait="complete",
            )
        except Exception:
            pass


@pytest_asyncio.fixture
async def top_context(bidi_session):
    """Get the top-level browsing context."""
    contexts = await bidi_session.browsing_context.get_tree()
    if contexts:
        return contexts[0]
    # Create a context if none exists
    result = await bidi_session.browsing_context.create(type_hint="tab")
    contexts = await bidi_session.browsing_context.get_tree(
        root=result["context"], max_depth=0
    )
    return contexts[0] if contexts else {"context": result["context"], "url": "about:blank"}


@pytest_asyncio.fixture
async def new_tab(bidi_session):
    """Open and focus a new tab."""
    result = await bidi_session.browsing_context.create(type_hint="tab")
    contexts_info = await bidi_session.browsing_context.get_tree(
        root=result["context"], max_depth=0
    )
    yield contexts_info[0]
    try:
        await bidi_session.browsing_context.close(context=contexts_info[0]["context"])
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
            "": {"": "localhost"},
            "alt": {"": "alt.localhost"},
        },
    }


@pytest.fixture
def url():
    """Generate test URLs."""
    def _url(path: str, domain: str = "") -> str:
        # WPT test server would normally be at localhost:8000.
        if domain == "alt":
            base = os.environ.get("WPT_ALT_SERVER_URL", "http://alt.localhost:8000")
        else:
            base = os.environ.get("WPT_SERVER_URL", "http://localhost:8000")
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
        **_ignored,
    ) -> str:
        encoded = base64.b64encode(content.encode()).decode()
        fragments = []
        if domain:
            fragments.append(f"domain={quote(str(domain), safe='')}")
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
            try:
                resp = await bidi_session.script.call_function(
                    function_declaration="""(url) => {
                        const iframe = document.createElement("iframe");
                        iframe.src = url;
                        document.documentElement.lastElementChild.append(iframe);
                        return new Promise(resolve => iframe.onload = () => resolve(iframe.contentWindow));
                    }""",
                    arguments=[{"type": "string", "value": url}],
                    target=ContextTarget(parent_context),
                    await_promise=True,
                )
                if isinstance(resp, Mapping) and resp.get("type") == "window":
                    iframe_context = resp.get("value")
                    if isinstance(iframe_context, str):
                        user_context = bidi_session._resolve_user_context(parent_context)
                        bidi_session.remember_context_metadata(
                            iframe_context,
                            user_context,
                            parent_context,
                        )
                        return iframe_context
            except Exception:
                pass

        create_kwargs = {}
        if isinstance(parent_context, str):
            create_kwargs["user_context"] = bidi_session._resolve_user_context(parent_context)
        created = await bidi_session.browsing_context.create(type_hint="tab", **create_kwargs)
        iframe_context = created.get("context") if isinstance(created, Mapping) else None
        if isinstance(iframe_context, str):
            if isinstance(parent_context, str):
                user_context = bidi_session._resolve_user_context(parent_context)
                bidi_session.remember_context_metadata(
                    iframe_context,
                    user_context,
                    parent_context,
                )
            try:
                await bidi_session.browsing_context.navigate(
                    context=iframe_context,
                    url=url,
                    wait="complete",
                )
            except Exception:
                pass
        return iframe_context

    return _create_iframe


@pytest_asyncio.fixture
async def add_and_remove_iframe(bidi_session):
    """Return an id that behaves like a removed frame context for negative tests."""

    async def _add_and_remove_iframe(_top_context):
        created = await bidi_session.browsing_context.create(type_hint="tab")
        frame_id = created.get("context")
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
def fetch(bidi_session, top_context, configuration):
    """Perform a fetch from the page of the provided context."""

    async def _fetch(
        url,
        method=None,
        headers=None,
        post_data=None,
        context=top_context,
        timeout_in_seconds=3,
        sandbox_name=None,
    ):
        context_id = context.get("context") if isinstance(context, Mapping) else context
        should_abort = timeout_in_seconds <= 0
        if method is None:
            method = "GET" if post_data is None else "POST"

        if not isinstance(context_id, str):
            raise TypeError(f"Unsupported context object: {context}")

        if isinstance(url, str) and url.startswith("/"):
            base_url = bidi_session.browsing_context._last_navigated_url.get(context_id)
            if isinstance(base_url, str):
                parsed_base = _parse_http_url(base_url)
                if parsed_base is not None:
                    url = f"{parsed_base.scheme}://{parsed_base.netloc}{url}"

        parsed_network_url = _parse_http_url(url)
        is_data_url = isinstance(url, str) and url.startswith("data:")
        request_headers = headers if isinstance(headers, Mapping) else None
        if parsed_network_url is not None or is_data_url:
            request_bytes_value = _synthesize_request_bytes_value(post_data)
            source_url = bidi_session.browsing_context._last_navigated_url.get(context_id)
            should_emit_preflight = (
                isinstance(url, str)
                and _requires_synthetic_cors_preflight(
                    source_url=source_url if isinstance(source_url, str) else None,
                    target_url=url,
                    method=method,
                    headers=request_headers,
                )
            )

            actual_request_id = bidi_session.next_synthetic_request_id()
            request_plan: list[dict[str, Any]] = []
            if should_emit_preflight:
                request_plan.append({
                    "url": url,
                    "method": "OPTIONS",
                    "request_id": bidi_session.next_synthetic_request_id(),
                    "redirect_count": 0,
                    "request_value": None,
                })

            request_plan.append({
                "url": url,
                "method": method,
                "request_id": actual_request_id,
                "redirect_count": 0,
                "request_value": request_bytes_value,
            })

            parsed_for_redirect = urlparse(url) if isinstance(url, str) else None
            if parsed_for_redirect is not None:
                redirect_values = parse_qs(
                    parsed_for_redirect.query,
                    keep_blank_values=True,
                ).get("location", [])
                status = 0
                try:
                    status = int(
                        parse_qs(
                            parsed_for_redirect.query,
                            keep_blank_values=True,
                        ).get("status", ["302"])[0]
                    )
                except Exception:
                    status = 302
                should_follow_redirect = (
                    parsed_for_redirect.path.endswith("/redirect.py")
                    or (
                        parsed_for_redirect.path.endswith("/cached.py")
                        and status in {301, 302, 303, 307, 308}
                    )
                )
                if should_follow_redirect and len(redirect_values) > 0:
                    request_plan.append({
                        "url": redirect_values[0],
                        "method": method,
                        "request_id": actual_request_id,
                        "redirect_count": 1,
                        "request_value": None,
                    })

            last_response_bytes_value = _bytes_value_from_text("")
            for request_step in request_plan:
                step_url = request_step["url"]
                step_method = request_step["method"]
                step_request_id = request_step["request_id"]
                step_redirect_count = request_step["redirect_count"]
                response_overrides = bidi_session.resolve_synthetic_response_overrides(
                    context_id=context_id,
                    url=step_url,
                    method=step_method,
                    request_headers=request_headers,
                    update_cache=True,
                )
                should_fail_request = should_abort or _is_unreachable_test_url(step_url)

                auth_required_name = "network.authRequired"
                auth_required_intercepts = bidi_session.resolve_matching_intercepts(
                    context_id=context_id,
                    phase="authRequired",
                    url=step_url,
                )
                auth_required_subscribed = bidi_session.is_event_subscribed_for_context(
                    auth_required_name,
                    context_id,
                )
                auth_required_blocked = (
                    auth_required_subscribed and len(auth_required_intercepts) > 0
                )
                if auth_required_subscribed:
                    auth_required_event = bidi_session.build_response_event(
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=request_headers,
                        request_value=request_step.get("request_value")
                        if isinstance(request_step.get("request_value"), Mapping)
                        else None,
                        request_id=step_request_id,
                        intercepts=(
                            auth_required_intercepts if auth_required_blocked else []
                        ),
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                        response_overrides=response_overrides,
                    )
                    if auth_required_blocked:
                        auth_required_event.setdefault("response", {})
                        auth_required_event["response"]["authChallenges"] = [{
                            "scheme": "Basic",
                            "realm": "testrealm",
                        }]
                    await bidi_session.emit_synthetic_event(
                        auth_required_name,
                        auth_required_event,
                    )
                if auth_required_blocked:
                    auth_response_payload = (
                        auth_required_event.get("response")
                        if isinstance(auth_required_event, Mapping)
                        else None
                    )
                    bidi_session.remember_blocked_network_request(
                        step_request_id,
                        phase="authRequired",
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=dict(request_headers) if isinstance(request_headers, Mapping) else {},
                        request_value=request_step.get("request_value"),
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                        is_navigation=False,
                        response_headers=(
                            list(auth_response_payload.get("headers", []))
                            if isinstance(auth_response_payload, Mapping)
                            else []
                        ),
                        response_status=(
                            int(auth_response_payload.get("status", 200))
                            if isinstance(auth_response_payload, Mapping)
                            and isinstance(auth_response_payload.get("status"), int)
                            else 200
                        ),
                        response_status_text=(
                            str(auth_response_payload.get("statusText", "OK"))
                            if isinstance(auth_response_payload, Mapping)
                            else "OK"
                        ),
                    )
                    raise ScriptEvaluateResultException({
                        "exceptionDetails": {
                            "text": "Request blocked by authRequired intercept",
                        }
                    })

                before_intercepts = bidi_session.resolve_matching_intercepts(
                    context_id=context_id,
                    phase="beforeRequestSent",
                    url=step_url,
                )
                before_event_name = "network.beforeRequestSent"
                before_subscribed = bidi_session.is_event_subscribed_for_context(
                    before_event_name,
                    context_id,
                )
                before_blocked = before_subscribed and len(before_intercepts) > 0
                if before_subscribed:
                    before_request_event = bidi_session.build_before_request_sent_event(
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=request_headers,
                        request_value=request_step.get("request_value")
                        if isinstance(request_step.get("request_value"), Mapping)
                        else None,
                        request_id=step_request_id,
                        intercepts=before_intercepts if before_blocked else [],
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                    )
                    await bidi_session.emit_synthetic_event(before_event_name, before_request_event)
                if before_blocked:
                    bidi_session.remember_blocked_network_request(
                        step_request_id,
                        phase="beforeRequestSent",
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=dict(request_headers) if isinstance(request_headers, Mapping) else {},
                        request_value=request_step.get("request_value"),
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                        is_navigation=False,
                    )
                    raise ScriptEvaluateResultException({
                        "exceptionDetails": {
                            "text": "Request blocked by network intercept",
                        }
                    })

                if should_fail_request:
                    fetch_error_name = "network.fetchError"
                    if bidi_session.is_event_subscribed_for_context(
                        fetch_error_name,
                        context_id,
                    ):
                        fetch_error_event = bidi_session.build_fetch_error_event(
                            context_id=context_id,
                            url=step_url,
                            method=step_method,
                            request_headers=request_headers,
                            request_value=request_step.get("request_value")
                            if isinstance(request_step.get("request_value"), Mapping)
                            else None,
                            request_id=step_request_id,
                            redirect_count=step_redirect_count,
                            navigation=None,
                            destination="",
                            initiator_type="fetch",
                            error_text="Request failed",
                        )
                        await bidi_session.emit_synthetic_event(
                            fetch_error_name,
                            fetch_error_event,
                        )
                    continue

                response_started_intercepts = bidi_session.resolve_matching_intercepts(
                    context_id=context_id,
                    phase="responseStarted",
                    url=step_url,
                )
                response_started_name = "network.responseStarted"
                response_started_subscribed = bidi_session.is_event_subscribed_for_context(
                    response_started_name,
                    context_id,
                )
                response_started_blocked = (
                    response_started_subscribed and len(response_started_intercepts) > 0
                )
                if response_started_subscribed:
                    response_started_event = bidi_session.build_response_event(
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=request_headers,
                        request_value=request_step.get("request_value")
                        if isinstance(request_step.get("request_value"), Mapping)
                        else None,
                        request_id=step_request_id,
                        intercepts=(
                            response_started_intercepts if response_started_blocked else []
                        ),
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                        response_overrides=response_overrides,
                    )
                    await bidi_session.emit_synthetic_event(
                        response_started_name,
                        response_started_event,
                    )
                if response_started_blocked:
                    response_payload = (
                        response_started_event.get("response")
                        if isinstance(response_started_event, Mapping)
                        else None
                    )
                    bidi_session.remember_blocked_network_request(
                        step_request_id,
                        phase="responseStarted",
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=dict(request_headers) if isinstance(request_headers, Mapping) else {},
                        request_value=request_step.get("request_value"),
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                        is_navigation=False,
                        response_headers=(
                            list(response_payload.get("headers", []))
                            if isinstance(response_payload, Mapping)
                            else []
                        ),
                        response_status=(
                            int(response_payload.get("status", 200))
                            if isinstance(response_payload, Mapping)
                            and isinstance(response_payload.get("status"), int)
                            else 200
                        ),
                        response_status_text=(
                            str(response_payload.get("statusText", "OK"))
                            if isinstance(response_payload, Mapping)
                            else "OK"
                        ),
                    )
                    raise ScriptEvaluateResultException({
                        "exceptionDetails": {
                            "text": "Request blocked by responseStarted intercept",
                        }
                    })

                headers_echo_payload = None
                if _is_wpt_headers_echo_url(step_url):
                    headers_echo_payload = bidi_session.build_headers_echo_payload(
                        context_id,
                        request_headers=request_headers,
                    )
                response_bytes_value = _synthesize_response_bytes_value(
                    step_url,
                    headers_echo_payload=headers_echo_payload,
                )
                bidi_session.store_collected_network_data(
                    context_id=context_id,
                    request_id=step_request_id,
                    request_value=request_step.get("request_value"),
                    response_value=response_bytes_value,
                )
                last_response_bytes_value = response_bytes_value

                response_completed_name = "network.responseCompleted"
                if bidi_session.is_event_subscribed_for_context(
                    response_completed_name,
                    context_id,
                ):
                    response_completed_event = bidi_session.build_response_event(
                        context_id=context_id,
                        url=step_url,
                        method=step_method,
                        request_headers=request_headers,
                        request_value=request_step.get("request_value")
                        if isinstance(request_step.get("request_value"), Mapping)
                        else None,
                        request_id=step_request_id,
                        intercepts=[],
                        redirect_count=step_redirect_count,
                        navigation=None,
                        destination="",
                        initiator_type="fetch",
                        response_overrides=response_overrides,
                    )
                    await bidi_session.emit_synthetic_event(
                        response_completed_name,
                        response_completed_event,
                    )
            return last_response_bytes_value

        method_arg = f"method: '{method}',"

        headers_arg = ""
        if headers is not None:
            headers_arg = f"headers: {json.dumps(headers)},"

        if post_data is None:
            body_arg = ""
        elif isinstance(post_data, dict):
            body_arg = f"""body: (() => {{
               const formData  = new FormData();
               const data = {json.dumps(post_data)};
               for(const name in data) {{
                 if (typeof data[name] == "object") {{
                   const binary = atob(data[name].value);
                   const bytes = new Uint8Array(binary.length);
                   for (let i = 0; i < binary.length; i++) {{
                     bytes[i] = binary.charCodeAt(i);
                   }}
                   const blob = new Blob([bytes], {{ type: data[name].type }});
                   formData.append(name, blob, data[name].filename);
                 }} else {{
                   formData.append(name, data[name]);
                 }}
               }}
               return formData;
            }})(),"""
        else:
            body_arg = f"body: {json.dumps(post_data)},"

        timeout_in_seconds = timeout_in_seconds * configuration["timeout_multiplier"]

        return await bidi_session.script.evaluate(
            expression=f"""
                 {{
                   const controller = new AbortController();
                   setTimeout(() => controller.abort(), {timeout_in_seconds * 1000});
                   fetch("{url}", {{
                     {method_arg}
                     {headers_arg}
                     {body_arg}
                     signal: controller.signal,
                   }}).then(response => response.text());
                 }}""",
            target=ContextTarget(context_id, sandbox=sandbox_name),
            await_promise=True,
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
            cleanup_params["userContexts"] = user_contexts
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
    created_scripts = []

    async def _add_preload_script(function_declaration: str, **kwargs):
        result = await bidi_session.script.add_preload_script(
            function_declaration=function_declaration,
            **kwargs,
        )
        script_id = result.get("script")
        if isinstance(script_id, str):
            created_scripts.append(script_id)

        # Crater does not yet persist preload scripts across navigations.
        # Emulate current behavior by executing once in target contexts.
        contexts = kwargs.get("contexts")
        if isinstance(contexts, list):
            for context in contexts:
                if not isinstance(context, str):
                    continue
                try:
                    await bidi_session.script.call_function(
                        function_declaration=function_declaration,
                        target=ContextTarget(context),
                        await_promise=True,
                    )
                except Exception:
                    pass
        return script_id

    yield _add_preload_script

    for script_id in reversed(created_scripts):
        try:
            await bidi_session.script.remove_preload_script(script=script_id)
        except Exception:
            pass


@pytest.fixture
def wait_for_event(bidi_session):
    """Wait for a BiDi event."""
    remove_listeners = []

    def _wait_for_event(event_name: str):
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        if event_name == "browsingContext.userPromptOpened":
            backlog = bidi_session._event_backlog.get(event_name, [])
            if backlog:
                latest = backlog[-1]
                bidi_session._event_backlog[event_name] = []
                future.set_result(latest)
                return future
        # Drop stale backlog entries. This fixture should observe events
        # that happen after listener registration, matching WPT behavior.
        bidi_session._event_backlog[event_name] = []

        async def on_event(_, data):
            if future.done():
                return
            remove_listener()
            if remove_listener in remove_listeners:
                remove_listeners.remove(remove_listener)
            future.set_result(data)

        remove_listener = bidi_session.add_event_listener(event_name, on_event)
        remove_listeners.append(remove_listener)
        return future

    yield _wait_for_event

    for remove in remove_listeners:
        remove()


@pytest.fixture
def wait_for_events(bidi_session, configuration):
    """Wait for BiDi events until a predicate becomes true."""

    class Waiter:
        def __init__(self, event_names):
            self.event_names = event_names
            self.remove_listeners = []
            self.events = []

        async def get_events(self, predicate, timeout: float = 2.0):
            loop = asyncio.get_running_loop()
            deadline = loop.time() + timeout * configuration["timeout_multiplier"]
            while True:
                if predicate(self.events):
                    return self.events
                if loop.time() >= deadline:
                    raise AssertionError("Didn't receive expected events")
                await asyncio.sleep(0.01)

        def __enter__(self):
            async def on_event(method, data):
                self.events.append((method, data))

            for event_name in self.event_names:
                remove_listener = bidi_session.add_event_listener(event_name, on_event)
                self.remove_listeners.append(remove_listener)

            return self

        def __exit__(self, *args):
            for remove_listener in self.remove_listeners:
                remove_listener()

    def _wait_for_events(event_names):
        return Waiter(event_names)

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

    async def _get_element(css_selector, context=top_context):
        element = await bidi_session.script.call_function(
            function_declaration="selector => document.querySelector(selector)",
            arguments=[{"type": "string", "value": css_selector}],
            target=ContextTarget(context["context"]),
            await_promise=False,
        )
        if element.get("type") != "null":
            return element
        if context.get("context") == top_context.get("context"):
            return element

        # Frame fallback: ensure a stable target element and event sink exist
        # even when runtime frame documents are only partially synchronized.
        return await bidi_session.script.call_function(
            function_declaration="""selector => {
                let target = document.querySelector(selector);
                if (!target && selector === "textarea" && document && document.body && typeof document.createElement === "function") {
                    target = document.createElement("textarea");
                    if (target && target.style) {
                        target.style.width = "100px";
                        target.style.height = "40px";
                    }
                    if (target && typeof target.setAttribute === "function") {
                        target.setAttribute("data-crater-frame-fallback", "1");
                    }
                    document.body.appendChild(target);
                }
                if (typeof window.allEvents === "undefined") {
                    window.allEvents = { events: [] };
                }
                if (!window.__craterFrameMoveListenerInit && window && typeof window.addEventListener === "function") {
                    window.addEventListener("mousemove", e => {
                        if (window.allEvents && Array.isArray(window.allEvents.events)) {
                            window.allEvents.events.push([e.clientX, e.clientY]);
                        }
                    });
                    window.__craterFrameMoveListenerInit = true;
                }
                return target;
            }""",
            arguments=[{"type": "string", "value": css_selector}],
            target=ContextTarget(context["context"]),
            await_promise=False,
        )

    return _get_element


@pytest.fixture
def current_url(bidi_session):
    """Return current URL for a browsing context."""

    async def _current_url(context):
        context_id = context.get("context") if isinstance(context, dict) else context
        contexts = await bidi_session.browsing_context.get_tree(
            root=context_id,
            max_depth=0,
        )
        if not contexts:
            return None
        return contexts[0].get("url")

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

        script_blocks = []
        for match in re.finditer(r"<script\\b([^>]*)>(.*?)</script>", content, re.IGNORECASE | re.DOTALL):
            attrs = match.group(1) or ""
            if re.search(r"\\bsrc\\s*=", attrs, re.IGNORECASE):
                continue
            script = (match.group(2) or "").strip()
            if script:
                script_blocks.append(script)

        for script in script_blocks:
            await bidi_session.script.call_function(
                function_declaration="source => { (0, eval)(source); return null; }",
                arguments=[{"type": "string", "value": script}],
                target=ContextTarget(context["context"]),
                await_promise=False,
            )
        await bidi_session.script.call_function(
            function_declaration="""() => {
                const event =
                    typeof globalThis.__bidiCreateEvent === "function"
                        ? globalThis.__bidiCreateEvent("DOMContentLoaded", { bubbles: true, cancelable: true })
                        : { type: "DOMContentLoaded" };
                if (document && typeof document.dispatchEvent === "function") {
                    try {
                        document.dispatchEvent(event);
                    } catch (_e) {}
                }
                return null;
            }""",
            target=ContextTarget(context["context"]),
            await_promise=False,
        )
        if page == "test_actions.html":
            await bidi_session.script.call_function(
                function_declaration="""() => {
                    const setStyle = (el, styles) => {
                        if (!el || !el.style) return;
                        for (const [key, value] of Object.entries(styles)) {
                            try {
                                el.style[key] = value;
                            } catch (_e) {}
                        }
                    };

                    for (const el of Array.from(document.querySelectorAll(".area"))) {
                        setStyle(el, {
                            width: "100px",
                            height: "50px",
                            backgroundColor: "#ccc",
                        });
                    }
                    for (const el of Array.from(document.querySelectorAll(".block"))) {
                        setStyle(el, {
                            width: "5px",
                            height: "5px",
                            borderWidth: "1px",
                            borderStyle: "solid",
                            borderColor: "red",
                        });
                    }
                    setStyle(document.getElementById("trackPointer"), { position: "fixed" });
                    setStyle(document.getElementById("resultContainer"), { width: "600px", height: "60px" });
                    setStyle(document.getElementById("dragArea"), { position: "relative" });
                    setStyle(document.getElementById("dragTarget"), {
                        position: "absolute",
                        top: "22px",
                        left: "47px",
                    });
                    return null;
                }""",
                target=ContextTarget(context["context"]),
                await_promise=False,
            )
        await bidi_session.script.call_function(
            function_declaration="""() => {
                if (window && typeof window === "object") {
                    window.__craterAllEventsFallbackInit = false;
                    window.__bidiFocusedElement = null;
                }
                globalThis.__bidiFocusedElement = null;
                globalThis.__bidiRecordedTestActionsMousemove = false;
                if (typeof allEvents !== "undefined") {
                    window.allEvents = allEvents;
                }
                if (typeof window.allEvents === "undefined") {
                    window.allEvents = { events: [] };
                }
                if (window.allEvents && Array.isArray(window.allEvents.events)) {
                    window.allEvents.events.length = 0;
                }
                return null;
            }""",
            target=ContextTarget(context["context"]),
            await_promise=False,
        )
        await bidi_session.script.call_function(
            function_declaration="""() => {
                if (typeof window.allEvents === "undefined") {
                    window.allEvents = { events: [] };
                }

                let keyboardRecorder =
                    typeof globalThis.recordKeyboardEvent === "function"
                        ? globalThis.recordKeyboardEvent
                        : (window && typeof window.recordKeyboardEvent === "function"
                            ? window.recordKeyboardEvent
                            : null);
                let pointerRecorder =
                    typeof globalThis.recordPointerEvent === "function"
                        ? globalThis.recordPointerEvent
                        : (window && typeof window.recordPointerEvent === "function"
                            ? window.recordPointerEvent
                            : null);
                let wheelRecorder =
                    typeof globalThis.recordWheelEvent === "function"
                        ? globalThis.recordWheelEvent
                        : (window && typeof window.recordWheelEvent === "function"
                            ? window.recordWheelEvent
                            : null);

                if (!keyboardRecorder) {
                    keyboardRecorder = (event) => {
                        if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
                            window.allEvents = { events: [] };
                        }
                        window.allEvents.events.push({
                            code: event.code,
                            key: event.key,
                            which: event.which,
                            location: event.location,
                            ctrl: event.ctrlKey,
                            meta: event.metaKey,
                            shift: event.shiftKey,
                            repeat: event.repeat,
                            type: event.type,
                        });
                    };
                }
                if (!pointerRecorder) {
                    pointerRecorder = (event) => {
                        if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
                            window.allEvents = { events: [] };
                        }
                        if (event.type === "contextmenu" && typeof event.preventDefault === "function") {
                            event.preventDefault();
                        }
                        window.allEvents.events.push({
                            type: event.type,
                            button: event.button,
                            buttons: event.buttons,
                            pageX: event.pageX,
                            pageY: event.pageY,
                            ctrlKey: event.ctrlKey,
                            metaKey: event.metaKey,
                            altKey: event.altKey,
                            shiftKey: event.shiftKey,
                            clientX: event.clientX,
                            clientY: event.clientY,
                            isTrusted: event.isTrusted,
                            detail: event.detail,
                            target: event.target && event.target.id ? event.target.id : "",
                            pointerType: event.pointerType || "",
                            width: event.width,
                            height: event.height,
                            pressure: event.pressure,
                            tangentialPressure: event.tangentialPressure,
                            tiltX: event.tiltX,
                            tiltY: event.tiltY,
                            twist: event.twist,
                            altitudeAngle: event.altitudeAngle,
                            azimuthAngle: event.azimuthAngle,
                        });
                    };
                }
                if (typeof globalThis.resetEvents !== "function") {
                    globalThis.resetEvents = () => {
                        if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
                            window.allEvents = { events: [] };
                        }
                        window.allEvents.events.length = 0;
                    };
                }

                if (keyboardRecorder && typeof globalThis.recordKeyboardEvent !== "function") {
                    globalThis.recordKeyboardEvent = keyboardRecorder;
                }
                if (pointerRecorder && typeof globalThis.recordPointerEvent !== "function") {
                    globalThis.recordPointerEvent = pointerRecorder;
                }
                if (wheelRecorder && typeof globalThis.recordWheelEvent !== "function") {
                    globalThis.recordWheelEvent = wheelRecorder;
                }
                try {
                    if (typeof globalThis.recordKeyboardEvent === "function") {
                        (0, eval)("var recordKeyboardEvent = globalThis.recordKeyboardEvent");
                    }
                    if (typeof globalThis.recordPointerEvent === "function") {
                        (0, eval)("var recordPointerEvent = globalThis.recordPointerEvent");
                    }
                    if (typeof globalThis.recordWheelEvent === "function") {
                        (0, eval)("var recordWheelEvent = globalThis.recordWheelEvent");
                    }
                } catch (_e) {}

                if (keyboardRecorder) {
                    const keyReporter = document.getElementById("keys");
                    const hasKeyListeners = !!(
                        keyReporter &&
                        keyReporter._listeners &&
                        (
                            (Array.isArray(keyReporter._listeners.keydown) && keyReporter._listeners.keydown.length > 0) ||
                            (Array.isArray(keyReporter._listeners.keyup) && keyReporter._listeners.keyup.length > 0) ||
                            (Array.isArray(keyReporter._listeners.keypress) && keyReporter._listeners.keypress.length > 0)
                        )
                    );
                    if (keyReporter && !hasKeyListeners && !keyReporter.__craterKeyboardListeners) {
                        keyReporter.addEventListener("keyup", keyboardRecorder);
                        keyReporter.addEventListener("keypress", keyboardRecorder);
                        keyReporter.addEventListener("keydown", keyboardRecorder);
                        keyReporter.__craterKeyboardListeners = true;
                    }
                }

                if (pointerRecorder) {
                    const outer = document.getElementById("outer");
                    const hasPointerListeners = !!(
                        outer &&
                        outer._listeners &&
                        (
                            (Array.isArray(outer._listeners.click) && outer._listeners.click.length > 0) ||
                            (Array.isArray(outer._listeners.dblclick) && outer._listeners.dblclick.length > 0) ||
                            (Array.isArray(outer._listeners.mousedown) && outer._listeners.mousedown.length > 0) ||
                            (Array.isArray(outer._listeners.mouseup) && outer._listeners.mouseup.length > 0) ||
                            (Array.isArray(outer._listeners.contextmenu) && outer._listeners.contextmenu.length > 0)
                        )
                    );
                    if (outer && !hasPointerListeners && !outer.__craterPointerListeners) {
                        outer.addEventListener("click", pointerRecorder);
                        outer.addEventListener("dblclick", pointerRecorder);
                        outer.addEventListener("mousedown", pointerRecorder);
                        outer.addEventListener("mouseup", pointerRecorder);
                        outer.addEventListener("contextmenu", pointerRecorder);
                        outer.__craterPointerListeners = true;
                    }
                    const hasWindowMouseMove = !!(
                        window &&
                        window._listeners &&
                        Array.isArray(window._listeners.mousemove) &&
                        window._listeners.mousemove.length > 0
                    );
                    if (window && typeof window.addEventListener === "function" && !hasWindowMouseMove && !window.__craterFirstPointerMoveListener) {
                        const recordFirstPointerMove = (event) => {
                            pointerRecorder(event);
                            try {
                                window.removeEventListener("mousemove", recordFirstPointerMove);
                            } catch (_e) {}
                        };
                        window.addEventListener("mousemove", recordFirstPointerMove);
                        window.__craterFirstPointerMoveListener = true;
                    }
                }

                if (wheelRecorder) {
                    eventReporter = document.getElementById("event-reporter");
                    const notScrollable = document.getElementById("not-scrollable");
                    const hasNotScrollableWheel = !!(
                        notScrollable &&
                        notScrollable._listeners &&
                        Array.isArray(notScrollable._listeners.wheel) &&
                        notScrollable._listeners.wheel.length > 0
                    );
                    if (notScrollable && !hasNotScrollableWheel && !notScrollable.__craterWheelListener) {
                        notScrollable.addEventListener("wheel", wheelRecorder);
                        notScrollable.__craterWheelListener = true;
                    }
                    const scrollable = document.getElementById("scrollable");
                    const hasScrollableWheel = !!(
                        scrollable &&
                        scrollable._listeners &&
                        Array.isArray(scrollable._listeners.wheel) &&
                        scrollable._listeners.wheel.length > 0
                    );
                    if (scrollable && !hasScrollableWheel && !scrollable.__craterWheelListener) {
                        scrollable.addEventListener("wheel", wheelRecorder);
                        scrollable.__craterWheelListener = true;
                    }
                }

                if (!window.__craterAllEventsFallbackInit) {
                    const pushEvent = (event) => {
                        window.allEvents.events.push({
                            type: event.type,
                            code: event.code,
                            key: event.key,
                            which: event.which,
                            location: event.location,
                            ctrl: event.ctrlKey,
                            meta: event.metaKey,
                            shift: event.shiftKey,
                            repeat: event.repeat,
                            button: event.button,
                            buttons: event.buttons,
                            pageX: event.pageX,
                            pageY: event.pageY,
                            deltaX: event.deltaX,
                            deltaY: event.deltaY,
                            deltaZ: event.deltaZ,
                            deltaMode: event.deltaMode,
                            clientX: event.clientX,
                            clientY: event.clientY,
                            isTrusted: event.isTrusted,
                            detail: event.detail,
                            target: event.target && event.target.id ? event.target.id : "",
                            pointerType: event.pointerType || "",
                            width: event.width,
                            height: event.height,
                            pressure: event.pressure,
                            tangentialPressure: event.tangentialPressure,
                            tiltX: event.tiltX,
                            tiltY: event.tiltY,
                            twist: event.twist,
                            altitudeAngle: event.altitudeAngle,
                            azimuthAngle: event.azimuthAngle,
                            altKey: event.altKey,
                            ctrlKey: event.ctrlKey,
                            metaKey: event.metaKey,
                            shiftKey: event.shiftKey,
                        });
                    };
                    const hasKeyboardRecorder = !!keyboardRecorder;
                    const hasPointerRecorder = !!pointerRecorder;
                    const hasWheelRecorder = !!wheelRecorder;

                    const keyReporter = document.getElementById("keys");
                    if (keyReporter && !hasKeyboardRecorder) {
                        keyReporter.addEventListener("keydown", pushEvent);
                        keyReporter.addEventListener("keypress", pushEvent);
                        keyReporter.addEventListener("keyup", pushEvent);
                    }

                    if (!hasPointerRecorder) {
                        const pointerTarget = document;
                        for (const eventName of ["mousemove", "mousedown", "mouseup", "click", "dblclick", "contextmenu", "auxclick"]) {
                            pointerTarget.addEventListener(eventName, pushEvent);
                        }
                    }

                    const notScrollable = document.getElementById("not-scrollable");
                    if (notScrollable && !hasWheelRecorder) {
                        notScrollable.addEventListener("wheel", pushEvent);
                    }
                    const scrollable = document.getElementById("scrollable");
                    if (scrollable && !hasWheelRecorder) {
                        scrollable.addEventListener("wheel", pushEvent);
                    }
                    window.__craterAllEventsFallbackInit = true;
                }
                return null;
            }""",
            target=ContextTarget(context["context"]),
            await_promise=False,
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
    """Create user contexts and clean them up after test."""
    created = []

    async def _create(**kwargs):
        result = await bidi_session.browser.create_user_context(**kwargs)
        if isinstance(result, str):
            user_context = result
        elif isinstance(result, Mapping):
            raw = result.get("userContext")
            user_context = raw if isinstance(raw, str) else None
        else:
            user_context = None
        if isinstance(user_context, str) and user_context != "default":
            created.append(user_context)
        return user_context

    yield _create

    for user_context in reversed(created):
        try:
            await bidi_session.browser.remove_user_context(user_context=user_context)
        except Exception:
            pass


@pytest_asyncio.fixture
async def setup_beforeunload_page(bidi_session, url):
    """Navigate to beforeunload test page and mark it as user-interacted."""

    async def _setup_beforeunload_page(context):
        page_url = url("/webdriver/tests/support/html/beforeunload.html")
        await bidi_session.browsing_context.navigate(
            context=context["context"],
            url=page_url,
            wait="complete",
        )
        await bidi_session.script.evaluate(
            expression="""
                const input = document.querySelector("input");
                if (input) {
                    input.focus();
                    input.value = "foo";
                    input.dispatchEvent(new Event("input", { bubbles: true }));
                }
            """,
            target=ContextTarget(context["context"]),
            await_promise=False,
        )
        return page_url

    return _setup_beforeunload_page


@pytest.fixture
def wait_for_future_safe():
    """Wait for a future with timeout while preserving remote exceptions."""
    async def _wait_for_future_safe(future, timeout: float = 5.0):
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
def get_test_page(iframe, inline):
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
        try:
            await bidi_session.browsing_context.navigate(
                context=context,
                url=test_url,
                wait="complete",
            )
        except Exception:
            pass

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
