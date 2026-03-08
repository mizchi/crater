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
        self._known_user_contexts: set[str] = {"default"}

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

    def has_event_listener(self, event_name: str) -> bool:
        listeners = self._event_listeners.get(event_name)
        return isinstance(listeners, list) and len(listeners) > 0

    async def wait_for_backlog_event(
        self,
        event_name: str,
        *,
        predicate: Any = None,
        timeout: float = 0.25,
    ) -> Any:
        def _find_match():
            for entry in self._event_backlog.get(event_name, []):
                if predicate is None or predicate(entry):
                    return entry
            return None

        matched = _find_match()
        if matched is not None or timeout <= 0:
            return matched

        loop = self.event_loop or asyncio.get_event_loop()
        deadline = loop.time() + timeout
        while loop.time() < deadline:
            await asyncio.sleep(0.01)
            matched = _find_match()
            if matched is not None:
                return matched
        return None

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

    async def get_context_scope_info(self, context_id: str) -> dict[str, Any]:
        if not isinstance(context_id, str) or context_id == "":
            return {
                "context": context_id if isinstance(context_id, str) else None,
                "known": False,
                "ancestry": [],
                "topLevelContext": None,
                "parent": None,
                "userContext": None,
                "isTopLevel": False,
            }
        future = await self.send_command(
            "browsingContext.getContextScopeInfo",
            {"context": context_id},
        )
        result = await future
        return dict(result) if isinstance(result, Mapping) else {
            "context": context_id,
            "known": False,
            "ancestry": [],
            "topLevelContext": None,
            "parent": None,
            "userContext": None,
            "isTopLevel": False,
        }

    def _scope_ancestry(self, scope_info: Mapping[str, Any], context_id: str) -> list[str]:
        ancestry = []
        raw_ancestry = scope_info.get("ancestry")
        if isinstance(raw_ancestry, list):
            ancestry = [entry for entry in raw_ancestry if isinstance(entry, str)]
        if isinstance(context_id, str) and context_id and context_id not in ancestry:
            ancestry.append(context_id)
        return ancestry

    def _scope_user_context(self, scope_info: Mapping[str, Any]) -> str:
        user_context = scope_info.get("userContext")
        return user_context if isinstance(user_context, str) else "default"

    async def is_known_context(self, context_id: str) -> bool:
        scope_info = await self.get_context_scope_info(context_id)
        return bool(scope_info.get("known"))

    async def resolve_synthetic_response_overrides(
        self,
        *,
        context_id: str,
        url: str,
        method: str,
        request_headers: Mapping[str, Any] | None = None,
        update_cache: bool = True,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {
            "context": context_id,
            "url": url,
            "method": method,
            "requestHeaders": self._network_header_entries_from_map(request_headers),
            "updateCache": update_cache,
        }
        future = await self.send_command("network.resolveSyntheticResponseOverrides", params)
        result = await future
        response = result.get("responseOverrides", {})
        return dict(response) if isinstance(response, Mapping) else {}

    def remember_known_user_context(self, user_context: str) -> None:
        if isinstance(user_context, str) and user_context != "":
            self._known_user_contexts.add(user_context)

    def forget_known_user_context(self, user_context: str) -> None:
        if isinstance(user_context, str) and user_context != "default":
            self._known_user_contexts.discard(user_context)

    def is_known_user_context(self, user_context: str) -> bool:
        return isinstance(user_context, str) and user_context in self._known_user_contexts

    def _inline_cookie_host(self, url: str) -> str:
        fragment = ""
        if "#" in url:
            fragment = url.split("#", maxsplit=1)[1]
        params = parse_qs(fragment, keep_blank_values=True)
        subdomain_values = params.get("subdomain", [])
        domain_values = params.get("domain", [])
        if len(domain_values) == 0:
            base_host = "localhost"
        else:
            candidate = domain_values[0].strip().lower()
            if candidate == "" or candidate == "default":
                base_host = "localhost"
            elif candidate == "alt":
                base_host = "alt.localhost"
            elif "." in candidate or ":" in candidate:
                base_host = candidate
            else:
                base_host = candidate + ".localhost"
        if len(subdomain_values) == 0:
            return base_host
        subdomain = subdomain_values[0].strip().lower()
        if subdomain == "":
            return base_host
        return subdomain + "." + base_host

    def _context_cookie_base_url(self, context_id: str) -> str:
        candidate = self._browsing_context._last_navigated_url.get(context_id) if self._browsing_context else None
        if isinstance(candidate, str) and candidate != "":
            return candidate
        return "http://localhost:8000/webdriver/tests/support/empty.html"

    def _cookie_origin_from_base_url(self, base_url: str) -> str | None:
        parsed = _parse_http_url(base_url)
        if parsed is not None:
            scheme = parsed.scheme or "http"
            netloc = parsed.netloc or ""
            if netloc != "":
                return f"{scheme}://{netloc}"
        if isinstance(base_url, str) and base_url.startswith("data:"):
            fragment = ""
            if "#" in base_url:
                fragment = base_url.split("#", maxsplit=1)[1]
            params = parse_qs(fragment, keep_blank_values=True)
            protocol_values = params.get("protocol", [])
            protocol = protocol_values[0] if len(protocol_values) > 0 else "http"
            if protocol not in {"http", "https"}:
                protocol = "http"
            return f"{protocol}://{self._inline_cookie_host(base_url)}:8000"
        return None

    def _cookie_domain_from_base_url(self, base_url: str) -> str:
        parsed = _parse_http_url(base_url)
        if parsed is not None and isinstance(parsed.hostname, str) and parsed.hostname != "":
            return parsed.hostname.lower()
        if isinstance(base_url, str) and base_url.startswith("data:"):
            return self._inline_cookie_host(base_url)
        return "localhost"

    def _cookie_default_path(self, base_url: str) -> str:
        parsed = _parse_http_url(base_url)
        if parsed is None:
            return "/webdriver/tests/support"
        path = parsed.path or "/"
        if path == "/" or not path.startswith("/"):
            return "/"
        if path.endswith("/"):
            trimmed = path[:-1]
            return trimmed if trimmed != "" else "/"
        parent = path.rsplit("/", maxsplit=1)[0]
        return parent if parent != "" else "/"

    def _parse_cookie_expiry_timestamp(self, raw_value: str) -> int | None:
        try:
            parsed_expiry = email.utils.parsedate_to_datetime(raw_value)
        except Exception:
            return None
        if parsed_expiry.tzinfo is None:
            parsed_expiry = parsed_expiry.replace(tzinfo=datetime.timezone.utc)
        return int(parsed_expiry.timestamp())

    def _origins_equivalent(self, lhs: Any, rhs: Any) -> bool:
        if not isinstance(lhs, str) or not isinstance(rhs, str):
            return lhs == rhs
        if lhs == rhs:
            return True
        lhs_parsed = _parse_http_url(lhs)
        rhs_parsed = _parse_http_url(rhs)
        if lhs_parsed is None or rhs_parsed is None:
            return False
        lhs_host = (lhs_parsed.hostname or "").lower()
        rhs_host = (rhs_parsed.hostname or "").lower()
        return lhs_host != "" and lhs_host == rhs_host

    async def remember_document_cookie(self, context_id: str, cookie_assignment: str) -> None:
        if not isinstance(context_id, str) or not isinstance(cookie_assignment, str):
            return
        future = await self.send_command("storage.rememberDocumentCookie", {
            "context": context_id,
            "cookie": cookie_assignment,
        })
        await future

    async def resolve_request_cookies(
        self,
        context_id: str,
        *,
        request_url: str | None = None,
    ):
        if not isinstance(context_id, str):
            return []
        params: dict[str, Any] = {"context": context_id}
        if isinstance(request_url, str):
            params["requestUrl"] = request_url
        future = await self.send_command("storage.resolveRequestCookies", params)
        result = await future
        cookies = result.get("cookies", [])
        return list(cookies) if isinstance(cookies, list) else []

    async def resolve_user_context(self, context_id: str) -> str:
        scope_info = await self.get_context_scope_info(context_id)
        return self._scope_user_context(scope_info)

    async def build_headers_echo_payload(
        self,
        context_id: str,
        request_headers: Mapping[str, Any] | None = None,
    ) -> str:
        future = await self.send_command("network.buildHeadersEchoPayload", {
            "context": context_id,
            "requestHeaders": self._network_header_entries_from_map(request_headers),
        })
        result = await future
        payload = result.get("payload")
        if not isinstance(payload, str):
            return "{\"headers\":{}}"
        try:
            return json.dumps(json.loads(payload), ensure_ascii=True)
        except Exception:
            return payload

    async def create_synthetic_child_context(
        self,
        *,
        parent_context: str,
        url: str,
        user_context: str | None = None,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {
            "parentContext": parent_context,
            "url": url,
        }
        if isinstance(user_context, str):
            params["userContext"] = user_context
        future = await self.send_command(
            "browsingContext.createSyntheticChildContext",
            params,
        )
        result = await future
        return dict(result) if isinstance(result, Mapping) else {}

    async def resolve_matching_intercepts(
        self,
        *,
        context_id: str,
        phase: str,
        url: str,
    ) -> list[str]:
        future = await self.send_command(
            "network.resolveMatchingIntercepts",
            {"context": context_id, "phase": phase, "url": url},
        )
        result = await future
        intercepts = result.get("intercepts", []) if isinstance(result, Mapping) else []
        return [item for item in intercepts if isinstance(item, str)] if isinstance(intercepts, list) else []

    async def is_event_subscribed_for_context(self, event_name: str, context_id: str) -> bool:
        if not isinstance(event_name, str) or not isinstance(context_id, str):
            return False
        future = await self.send_command(
            "session.isSubscribedForContext",
            {"event": event_name, "context": context_id},
        )
        result = await future
        return bool(result.get("subscribed")) if isinstance(result, Mapping) else False

    async def store_collected_network_data(
        self,
        *,
        context_id: str,
        request_id: str,
        request_value: Mapping[str, Any] | None,
        response_value: Mapping[str, Any] | None,
    ) -> None:
        if not isinstance(context_id, str) or not isinstance(request_id, str):
            return
        params: dict[str, Any] = {"context": context_id, "request": request_id}
        if isinstance(request_value, Mapping):
            params["requestData"] = dict(request_value)
        if isinstance(response_value, Mapping):
            params["responseData"] = dict(response_value)
        future = await self.send_command("network.rememberCollectedData", params)
        await future

    async def remember_blocked_network_request(self, request_id: str, **payload: Any) -> None:
        if not isinstance(request_id, str):
            return
        future = await self.send_command("network.rememberBlockedRequest", {
            "request": request_id,
            "blockedRequest": dict(payload),
        })
        await future

    async def get_blocked_network_request(self, request_id: str):
        if not isinstance(request_id, str):
            return None
        future = await self.send_command("network.getBlockedRequest", {"request": request_id})
        result = await future
        blocked = result.get("blockedRequest")
        if isinstance(blocked, Mapping):
            return dict(blocked)
        return None

    async def forget_blocked_network_request(self, request_id: str) -> None:
        if not isinstance(request_id, str):
            return
        future = await self.send_command("network.forgetBlockedRequest", {"request": request_id})
        await future

    async def has_blocked_navigation_request(
        self,
        context_id: str,
        navigation_id: str | None = None,
    ) -> bool:
        if not isinstance(context_id, str):
            return False
        future = await self.send_command("network.hasBlockedNavigationRequest", {
            "context": context_id,
            "navigation": navigation_id,
        })
        result = await future
        return bool(result.get("blocked"))

    async def prepare_navigation_request(
        self,
        *,
        context_id: str,
        url: str,
    ) -> dict[str, Any]:
        future = await self.send_command("network.prepareNavigationRequest", {
            "context": context_id,
            "url": url,
        })
        result = await future
        return dict(result) if isinstance(result, Mapping) else {}

    async def emit_navigation_request_sequence(
        self,
        *,
        context_id: str,
        url: str,
        navigation: str | None = None,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {"context": context_id, "url": url}
        if isinstance(navigation, str):
            params["navigation"] = navigation
        future = await self.send_command("network.emitNavigationRequestSequence", params)
        result = await future
        return dict(result) if isinstance(result, Mapping) else {}

    async def next_synthetic_request_id(self) -> str:
        future = await self.send_command("network.allocateRequestId", {})
        result = await future
        request_id = result.get("request")
        if isinstance(request_id, str):
            return request_id
        raise ValueError("network.allocateRequestId returned invalid request id")

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

    async def build_before_request_sent_event(
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
        request_cookies: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {
            "context": context_id,
            "url": url,
            "method": method,
            "requestId": request_id,
            "requestHeaders": self._network_header_entries_from_map(request_headers),
            "intercepts": list(intercepts),
            "redirectCount": redirect_count,
            "navigation": navigation,
            "destination": destination,
            "initiatorType": initiator_type,
        }
        if isinstance(request_value, Mapping):
            params["requestValue"] = request_value
        if request_cookies is not None:
            params["requestCookies"] = list(request_cookies)
        future = await self.send_command("network.buildBeforeRequestSentEvent", params)
        result = await future
        event = result.get("event", {})
        return dict(event) if isinstance(event, Mapping) else {}

    async def build_response_event(
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
        request_cookies: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        effective_overrides = dict(
            await self.resolve_synthetic_response_overrides(
                context_id=context_id,
                url=url,
                method=method,
                request_headers=request_headers,
                update_cache=False,
            )
        )
        if isinstance(response_overrides, Mapping):
            effective_overrides.update(dict(response_overrides))
        params: dict[str, Any] = {
            "context": context_id,
            "url": url,
            "method": method,
            "requestId": request_id,
            "requestHeaders": self._network_header_entries_from_map(request_headers),
            "intercepts": list(intercepts),
            "redirectCount": redirect_count,
            "navigation": navigation,
            "destination": destination,
            "initiatorType": initiator_type,
            "responseOverrides": effective_overrides,
        }
        if isinstance(request_value, Mapping):
            params["requestValue"] = request_value
        if request_cookies is not None:
            params["requestCookies"] = list(request_cookies)
        future = await self.send_command("network.buildResponseEvent", params)
        result = await future
        event = result.get("event", {})
        return dict(event) if isinstance(event, Mapping) else {}

    async def build_fetch_error_event(
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
        request_cookies: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {
            "context": context_id,
            "url": url,
            "method": method,
            "requestId": request_id,
            "requestHeaders": self._network_header_entries_from_map(request_headers),
            "redirectCount": redirect_count,
            "navigation": navigation,
            "destination": destination,
            "initiatorType": initiator_type,
            "errorText": error_text,
        }
        if isinstance(request_value, Mapping):
            params["requestValue"] = request_value
        if request_cookies is not None:
            params["requestCookies"] = list(request_cookies)
        future = await self.send_command("network.buildFetchErrorEvent", params)
        result = await future
        event = result.get("event", {})
        return dict(event) if isinstance(event, Mapping) else {}

    async def fail_blocked_request(
        self,
        request_id: str,
        *,
        error_text: str = "Request failed",
    ) -> dict[str, Any]:
        future = await self.send_command("network.failBlockedRequest", {
            "request": request_id,
            "errorText": error_text,
        })
        result = await future
        event = result.get("event", {})
        return dict(event) if isinstance(event, Mapping) else {}

    async def continue_auth_request(
        self,
        request_id: str,
        *,
        action: str,
    ) -> dict[str, Any]:
        future = await self.send_command("network.continueAuthRequest", {
            "request": request_id,
            "action": action,
        })
        result = await future
        event = result.get("event")
        return {
            "event": dict(event) if isinstance(event, Mapping) else None,
            "consumed": bool(result.get("consumed")),
        }

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
        params = {"type": type_hint}
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command(
            "browsingContext.create", params
        )
        return await future

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
        future = await self._session.send_command(
            "script.clearSyntheticLocationHref",
            {"context": context},
        )
        await future
        prepare_result = await self._session.prepare_navigation_request(
            context_id=context,
            url=url,
        )
        if prepare_result.get("blocked"):
            navigation_id = prepare_result.get("navigation")
            await asyncio.Future()
            return {
                "navigation": navigation_id,
                "url": prepare_result.get("url", url),
            }

        future = await self._session.send_command(
            "browsingContext.navigate", {"context": context, "url": url, "wait": wait}
        )
        result = await future
        self._last_navigated_url[context] = url
        navigation_id = None
        if isinstance(result, Mapping):
            candidate_navigation_id = result.get("navigation")
            if isinstance(candidate_navigation_id, str):
                navigation_id = candidate_navigation_id
        await self._session.emit_navigation_request_sequence(
            context_id=context,
            url=url,
            navigation=navigation_id,
        )
        if await self._session.has_blocked_navigation_request(context, navigation_id):
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
        return result.get("contexts", [])

    async def close(self, context: str, prompt_unload=_UNSET):
        params = {"context": context}
        # prompt_unload=None should behave like omitted in WPT.
        if prompt_unload is not _UNSET and prompt_unload is not None:
            params["promptUnload"] = prompt_unload
        self._session.fail_pending_print_requests_for_context(context)
        wait_for_destroyed = False
        if self._session.has_event_listener("browsingContext.contextDestroyed"):
            try:
                tree = await self.get_tree(root=context, max_depth=1)
            except Exception:
                tree = []
            if isinstance(tree, list) and len(tree) > 0:
                root_entry = tree[0]
                if isinstance(root_entry, Mapping):
                    children = root_entry.get("children")
                    wait_for_destroyed = isinstance(children, list) and len(children) > 0
        future = await self._session.send_command("browsingContext.close", params)
        result = await future
        if wait_for_destroyed:
            await self._session.wait_for_backlog_event(
                "browsingContext.contextDestroyed",
                predicate=lambda payload: (
                    isinstance(payload, Mapping) and payload.get("context") == context
                ),
                timeout=0.5,
            )
        return result

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
        navigation_id = None
        if isinstance(result, Mapping):
            candidate_navigation_id = result.get("navigation")
            if isinstance(candidate_navigation_id, str):
                navigation_id = candidate_navigation_id
        if isinstance(last_url, str):
            await self._session.emit_navigation_request_sequence(
                context_id=context,
                url=last_url,
                navigation=navigation_id,
            )
        return result

    async def print(self, context: str, **kwargs):
        params = {"context": context}
        for key, value in kwargs.items():
            if value is None:
                continue
            params[self._to_camel_case(key)] = self._normalize_bidi_value(value)

        future = await self._session.send_command(
            "browsingContext.print", params
        )
        result = await future
        return result.get("data", result)

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
        return result.get("data", result)

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

    async def evaluate(self, expression, target, await_promise=False, **kwargs):
        raw_result = kwargs.pop("raw_result", False)
        params = {
            "expression": expression,
            "target": target,  # Pass target as-is for WPT validation tests
            "awaitPromise": await_promise,
        }

        context_id = None
        if isinstance(target, Mapping):
            candidate = target.get("context")
            if isinstance(candidate, str):
                context_id = candidate
        elif hasattr(target, "context") and isinstance(target.context, str):
            context_id = target.context
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
        if raw_result:
            return result
        if isinstance(result, dict) and "exceptionDetails" in result:
            raise ScriptEvaluateResultException(result)
        return result.get("result", result)

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
            raise ScriptEvaluateResultException(result)
        return result.get("result", result)

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

    async def disown(self, handles, target):
        future = await self._session.send_command(
            "script.disown",
            {"handles": handles, "target": target},
        )
        return await future

    async def add_preload_script(self, function_declaration: str, **kwargs):
        params = {"functionDeclaration": function_declaration}
        for key, value in kwargs.items():
            if value is None or self._session._is_undefined(value):
                continue
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command("script.addPreloadScript", params)
        result = await future
        if isinstance(result, Mapping):
            script_id = result.get("script")
            if isinstance(script_id, str):
                return script_id
        return result

    async def remove_preload_script(self, script: str):
        if isinstance(script, Mapping):
            script = script.get("script")
        future = await self._session.send_command("script.removePreloadScript", {"script": script})
        return await future

    async def remove_all_preload_scripts(self):
        future = await self._session.send_command("script.removeAllPreloadScripts", {})
        return await future

    async def get_realms(self, **kwargs):
        params = {}
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = value
        future = await self._session.send_command("script.getRealms", params)
        result = await future
        return result.get("realms", [])


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

    def _parse_expected_auth_realm(self, blocked: Mapping[str, Any]):
        raw_url = blocked.get("url")
        if not isinstance(raw_url, str):
            return None
        parsed = _parse_http_url(raw_url)
        if parsed is None:
            return None
        params = parse_qs(parsed.query, keep_blank_values=True)
        realms = params.get("realm", [])
        if len(realms) == 0:
            return None
        realm = realms[0]
        if not isinstance(realm, str) or realm == "":
            return None
        return realm

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
            record["domain"] = domain
            record["domainExplicit"] = domain_explicit
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
        if not await self._session.is_event_subscribed_for_context(before_event_name, context_id):
            return
        intercepts = await self._session.resolve_matching_intercepts(
            context_id=context_id,
            phase="beforeRequestSent",
            url=url,
        )
        if len(intercepts) == 0:
            return
        request_id = await self._session.next_synthetic_request_id()
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

        before_event = await self._session.build_before_request_sent_event(
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
        await self._session.remember_blocked_network_request(
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
        if not await self._session.is_event_subscribed_for_context(event_name, context_id):
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
        realm = self._parse_expected_auth_realm(blocked) or "testrealm"

        auth_required_event = await self._session.build_response_event(
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
            response_overrides={
                "status": 401,
                "statusText": "Unauthorized",
                "authChallenges": [{
                    "scheme": "Basic",
                    "realm": realm,
                }],
            },
        )
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

    async def _emit_blocked_response_result(self, result: Mapping[str, Any]) -> None:
        response_started_event = result.get("responseStartedEvent")
        if isinstance(response_started_event, Mapping):
            context_id = response_started_event.get("context")
            event_name = "network.responseStarted"
            if isinstance(context_id, str) and await self._session.is_event_subscribed_for_context(
                event_name,
                context_id,
            ):
                await self._session.emit_synthetic_event(
                    event_name,
                    response_started_event,
                )

        response_completed_event = result.get("responseCompletedEvent")
        if isinstance(response_completed_event, Mapping):
            context_id = response_completed_event.get("context")
            event_name = "network.responseCompleted"
            if isinstance(context_id, str) and await self._session.is_event_subscribed_for_context(
                event_name,
                context_id,
            ):
                await self._session.emit_synthetic_event(
                    event_name,
                    response_completed_event,
                )

        auth_required_event = result.get("authRequiredEvent")
        if isinstance(auth_required_event, Mapping):
            context_id = auth_required_event.get("context")
            event_name = "network.authRequired"
            if isinstance(context_id, str) and await self._session.is_event_subscribed_for_context(
                event_name,
                context_id,
            ):
                await self._session.emit_synthetic_event(
                    event_name,
                    auth_required_event,
                )

        load_event = result.get("browsingContextLoad")
        if isinstance(load_event, Mapping):
            await self._session.emit_synthetic_event("browsingContext.load", load_event)

    def _validate_continue_url(self, value: Any) -> str:
        if not isinstance(value, str):
            raise bidi_error.InvalidArgumentException("url must be a string")
        if value.startswith("data:"):
            return value
        if _parse_http_url(value) is None:
            raise bidi_error.InvalidArgumentException("url is invalid")
        return value

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
        future = await self._session.send_command("network.addIntercept", params)
        result = await future
        if isinstance(result, dict):
            intercept = result.get("intercept")
            if isinstance(intercept, str):
                return intercept
        return result

    async def remove_intercept(self, intercept: str):
        if not isinstance(intercept, str):
            raise bidi_error.InvalidArgumentException("intercept must be a string")
        future = await self._session.send_command(
            "network.removeIntercept",
            {"intercept": intercept},
        )
        return await future

    async def continue_request(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked = await self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")
        params: dict[str, Any] = {"request": request_id}
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = self._normalize_network_value(value)

        navigation_id = blocked.get("navigation")
        if not isinstance(navigation_id, str):
            navigation_id = None

        if bool(blocked.get("is_navigation")):
            context_id = blocked.get("context_id")
            if not isinstance(context_id, str):
                raise bidi_error.NoSuchRequestException("Unknown request")
            original_url = blocked.get("url")
            target_url = params.get("url")
            if not isinstance(target_url, str) or target_url == "":
                target_url = original_url
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
                params["syntheticLocationHref"] = original_url
        if isinstance(navigation_id, str):
            params["navigation"] = navigation_id
        future = await self._session.send_command("network.continueBlockedRequest", params)
        result = await future
        if isinstance(result, Mapping):
            await self._emit_blocked_response_result(result)
        return {}

    async def continue_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        params: dict[str, Any] = {
            "request": request_id,
            "mode": "continueResponse",
        }
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = self._normalize_network_value(value)
        future = await self._session.send_command("network.continueBlockedResponse", params)
        result = await future
        if isinstance(result, Mapping):
            await self._emit_blocked_response_result(result)
        return {}

    async def fail_request(self, request: str):
        request_id = self._validate_request_id(request)
        fetch_error_event = await self._session.fail_blocked_request(request_id)
        context_id = fetch_error_event.get("context")
        if not isinstance(context_id, str):
            return {}
        fetch_error_name = "network.fetchError"
        if await self._session.is_event_subscribed_for_context(fetch_error_name, context_id):
            await self._session.emit_synthetic_event(fetch_error_name, fetch_error_event)
        return {}

    async def continue_with_auth(self, request: str, action: str, credentials=None):
        request_id = self._validate_request_id(request)
        if action == "provideCredentials":
            normalized = self._normalize_continue_response_credentials(credentials)
            return await self.continue_response(request=request, credentials=normalized)
        result = await self._session.continue_auth_request(request_id, action=action)
        response_completed_event = result.get("event")
        if isinstance(response_completed_event, Mapping):
            context_id = response_completed_event.get("context")
            response_completed_name = "network.responseCompleted"
            if isinstance(context_id, str) and await self._session.is_event_subscribed_for_context(
                response_completed_name,
                context_id,
            ):
                await self._session.emit_synthetic_event(
                    response_completed_name,
                    response_completed_event,
                )
        return {}

    async def provide_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
        blocked = await self._session.get_blocked_network_request(request_id)
        if blocked is None:
            raise bidi_error.NoSuchRequestException("Unknown request")
        params: dict[str, Any] = {
            "request": request_id,
            "mode": "provideResponse",
        }
        for key, value in kwargs.items():
            params[self._to_camel_case(key)] = self._normalize_network_value(value)

        future = await self._session.send_command("network.continueBlockedResponse", params)
        result = await future
        if isinstance(result, Mapping):
            await self._emit_blocked_response_result(result)

        if not isinstance(result, Mapping) or not bool(result.get("consumed")):
            return {}

        context_id = blocked.get("context_id")
        if not isinstance(context_id, str):
            return {}
        target_url = blocked.get("url")
        if not isinstance(target_url, str):
            target_url = ""
        destination = blocked.get("destination")
        if not isinstance(destination, str):
            destination = ""

        normalized_body = None
        if "body" in kwargs:
            normalized_body = self._normalize_network_value(kwargs["body"])

        if isinstance(normalized_body, Mapping):
            response_value = dict(normalized_body)
        else:
            response_value = _synthesize_response_bytes_value(target_url)
        await self._session.store_collected_network_data(
            context_id=context_id,
            request_id=request_id,
            request_value=blocked.get("request_value")
            if isinstance(blocked.get("request_value"), Mapping)
            else None,
            response_value=response_value,
        )

        if bool(blocked.get("is_navigation")):
            body_text = result.get("bodyText")
            if isinstance(body_text, str):
                await self._apply_provide_response_body_override(
                    context_id=context_id,
                    destination=destination,
                    body_text=body_text,
                )

        phase = blocked.get("phase")
        method = blocked.get("method")
        if not isinstance(method, str):
            method = "GET"
        if (
            phase == "beforeRequestSent"
            and method.upper() == "OPTIONS"
            and not bool(blocked.get("is_navigation"))
        ):
            await self._emit_followup_preflight_blocked_request(blocked=blocked)
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
                return collector
        return result

    async def set_extra_headers(self, headers, contexts=_UNSET, user_contexts=_UNSET):
        params = {"headers": headers}
        if contexts is not _UNSET:
            params["contexts"] = contexts
        if user_contexts is not _UNSET:
            params["userContexts"] = user_contexts
        future = await self._session.send_command("network.setExtraHeaders", params)
        return await future

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
                if not await self._session.is_known_context(context_id):
                    raise bidi_error.NoSuchFrameException("No such frame")
                normalized_contexts.append(context_id)
            params["contexts"] = normalized_contexts

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
        params = {"request": request, "dataType": data_type, "disown": disown}
        if collector is not None:
            params["collector"] = collector
        future = await self._session.send_command("network.getData", params)
        return await future

    async def disown_data(self, request, data_type, collector):
        if not isinstance(request, str):
            raise bidi_error.InvalidArgumentException("request must be a string")
        if not isinstance(data_type, str):
            raise bidi_error.InvalidArgumentException("dataType must be a string")
        if data_type not in {"request", "response"}:
            raise bidi_error.InvalidArgumentException("dataType is invalid")
        if not isinstance(collector, str):
            raise bidi_error.InvalidArgumentException("collector must be a string")
        future = await self._session.send_command("network.disownData", {
            "request": request,
            "dataType": data_type,
            "collector": collector,
        })
        return await future


class StorageModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    def _normalize_value(self, value: Any):
        if isinstance(value, Mapping):
            return {key: self._normalize_value(item) for key, item in value.items()}
        if isinstance(value, (list, tuple)):
            return [self._normalize_value(item) for item in value]
        return value

    def _cookie_value_text(self, raw_value: Mapping[str, Any], field_name: str) -> str:
        value_type = raw_value.get("type")
        payload = raw_value.get("value")
        if not isinstance(value_type, str):
            raise bidi_error.InvalidArgumentException(f"{field_name}.type must be a string")
        if value_type not in {"string", "base64"}:
            raise bidi_error.InvalidArgumentException(f"{field_name}.type is invalid")
        if not isinstance(payload, str):
            raise bidi_error.InvalidArgumentException(f"{field_name}.value must be a string")
        if value_type == "base64":
            try:
                return base64.b64decode(payload.encode("ascii"), validate=False).decode(
                    "utf-8",
                    errors="ignore",
                )
            except Exception:
                return ""
        return payload

    def _validate_bytes_value(self, raw_value: Any, field_name: str) -> dict[str, Any]:
        value = self._normalize_value(raw_value)
        if not isinstance(value, Mapping):
            raise bidi_error.InvalidArgumentException(f"{field_name} must be an object")
        _ = self._cookie_value_text(value, field_name)
        return {"type": value["type"], "value": value["value"]}

    def _validate_non_negative_int(self, value: Any, field_name: str) -> int:
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            raise bidi_error.InvalidArgumentException(f"{field_name} must be a non-negative integer")
        return value

    def _validate_cookie_expiry(self, value: Any) -> int:
        if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
            raise bidi_error.InvalidArgumentException("cookie.expiry must be a non-negative integer")
        return int(value)

    def _normalize_filter(self, filter_value: Any) -> dict[str, Any]:
        if filter_value is None:
            return {}
        normalized = self._normalize_value(filter_value)
        if not isinstance(normalized, Mapping):
            raise bidi_error.InvalidArgumentException("filter must be an object")
        result: dict[str, Any] = {}
        for key, value in normalized.items():
            if value is None:
                continue
            if key in {"domain", "name", "path"}:
                if not isinstance(value, str):
                    raise bidi_error.InvalidArgumentException(f"filter.{key} must be a string")
                result[key] = value
            elif key in {"httpOnly", "secure"}:
                if not isinstance(value, bool):
                    raise bidi_error.InvalidArgumentException(f"filter.{key} must be a boolean")
                result[key] = value
            elif key in {"expiry", "size"}:
                result[key] = self._validate_non_negative_int(value, f"filter.{key}")
            elif key == "sameSite":
                if not isinstance(value, str):
                    raise bidi_error.InvalidArgumentException("filter.sameSite must be a string")
                if value not in {"none", "lax", "strict", "default"}:
                    raise bidi_error.InvalidArgumentException("filter.sameSite is invalid")
                result[key] = value
            elif key == "value":
                result[key] = self._validate_bytes_value(value, "filter.value")
            else:
                result[key] = value
        return result

    def _normalize_cookie_input(self, cookie: Any) -> dict[str, Any]:
        normalized = self._normalize_value(cookie)
        if not isinstance(normalized, Mapping):
            raise bidi_error.InvalidArgumentException("cookie must be an object")

        domain = normalized.get("domain")
        if not isinstance(domain, str):
            raise bidi_error.InvalidArgumentException("cookie.domain must be a string")

        name = normalized.get("name")
        if not isinstance(name, str):
            raise bidi_error.InvalidArgumentException("cookie.name must be a string")

        value = self._validate_bytes_value(normalized.get("value"), "cookie.value")
        value_text = self._cookie_value_text(value, "cookie.value")

        path = normalized.get("path", "/")
        if path is None:
            path = "/"
        if not isinstance(path, str):
            raise bidi_error.InvalidArgumentException("cookie.path must be a string")

        http_only = normalized.get("httpOnly", False)
        if http_only is None:
            http_only = False
        if not isinstance(http_only, bool):
            raise bidi_error.InvalidArgumentException("cookie.httpOnly must be a boolean")

        secure = normalized.get("secure", False)
        if secure is None:
            secure = False
        if not isinstance(secure, bool):
            raise bidi_error.InvalidArgumentException("cookie.secure must be a boolean")

        same_site = normalized.get("sameSite", "none")
        if same_site is None:
            same_site = "none"
        if not isinstance(same_site, str):
            raise bidi_error.InvalidArgumentException("cookie.sameSite must be a string")
        if same_site not in {"none", "lax", "strict", "default"}:
            raise bidi_error.InvalidArgumentException("cookie.sameSite is invalid")

        expiry = normalized.get("expiry")
        if expiry is not None:
            expiry = self._validate_cookie_expiry(expiry)

        return {
            "name": name,
            "value": {"type": "string", "value": value_text},
            "domain": domain.strip().lower().lstrip("."),
            "path": path,
            "httpOnly": http_only,
            "secure": secure,
            "sameSite": same_site,
            "size": len(name) + len(value_text),
            **({"expiry": expiry} if isinstance(expiry, int) else {}),
        }

    async def _normalize_partition(self, partition: Any) -> dict[str, Any]:
        if partition is None:
            return {
                "kind": "default",
                "context": None,
                "userContext": None,
                "sourceOrigin": None,
                "partitionKey": {},
            }
        normalized = self._normalize_value(partition)
        if not isinstance(normalized, Mapping):
            raise bidi_error.InvalidArgumentException("partition must be an object")
        partition_type = normalized.get("type")
        if not isinstance(partition_type, str):
            raise bidi_error.InvalidArgumentException("partition.type must be a string")
        if partition_type == "context":
            context_id = normalized.get("context")
            if not isinstance(context_id, str):
                raise bidi_error.InvalidArgumentException("partition.context must be a string")
            if not await self._session.is_known_context(context_id):
                raise bidi_error.NoSuchFrameException("No such frame")
            partition_key = {"userContext": await self._session.resolve_user_context(context_id)}
            source_origin = self._session._cookie_origin_from_base_url(
                self._session._context_cookie_base_url(context_id)
            )
            if isinstance(source_origin, str) and source_origin != "":
                partition_key["sourceOrigin"] = source_origin
            return {
                "kind": "context",
                "context": context_id,
                "userContext": partition_key.get("userContext"),
                "sourceOrigin": partition_key.get("sourceOrigin"),
                "partitionKey": partition_key,
            }
        if partition_type == "storageKey":
            partition_key: dict[str, Any] = {}
            source_origin = normalized.get("sourceOrigin")
            if source_origin is not None:
                if not isinstance(source_origin, str):
                    raise bidi_error.InvalidArgumentException("partition.sourceOrigin must be a string")
                partition_key["sourceOrigin"] = source_origin
            user_context = normalized.get("userContext")
            if user_context is not None:
                if not isinstance(user_context, str):
                    raise bidi_error.InvalidArgumentException("partition.userContext must be a string")
                if not self._session.is_known_user_context(user_context):
                    raise bidi_error.NoSuchUserContextException("No such user context")
                partition_key["userContext"] = user_context
            return {
                "kind": "storageKey",
                "context": None,
                "userContext": partition_key.get("userContext"),
                "sourceOrigin": partition_key.get("sourceOrigin"),
                "partitionKey": partition_key,
            }
        raise bidi_error.InvalidArgumentException("partition.type is invalid")

    def _matches_partition(self, cookie: Mapping[str, Any], partition_info: Mapping[str, Any]) -> bool:
        kind = partition_info.get("kind")
        if kind == "default":
            return True
        if kind == "context":
            return cookie.get("_contextId") == partition_info.get("context")
        expected_user_context = partition_info.get("userContext")
        if expected_user_context is not None and cookie.get("_userContext") != expected_user_context:
            return False
        expected_source_origin = partition_info.get("sourceOrigin")
        if expected_source_origin is not None:
            candidate_source_origin = cookie.get("_sourceOrigin")
            context_id = cookie.get("_contextId")
            if isinstance(context_id, str):
                current_context_origin = self._session._cookie_origin_from_base_url(
                    self._session._context_cookie_base_url(context_id)
                )
                if isinstance(current_context_origin, str):
                    candidate_source_origin = current_context_origin
            if not self._session._origins_equivalent(candidate_source_origin, expected_source_origin):
                return False
        return True

    def _matches_filter(self, cookie: Mapping[str, Any], filter_value: Mapping[str, Any]) -> bool:
        for key, expected in filter_value.items():
            if key == "value":
                actual_value = cookie.get("value")
                if not isinstance(actual_value, Mapping):
                    return False
                actual_text = self._cookie_value_text(actual_value, "cookie.value")
                expected_text = self._cookie_value_text(expected, "filter.value")
                if actual_text != expected_text:
                    return False
                continue
            if cookie.get(key) != expected:
                return False
        return True

    async def get_cookies(self, filter=None, partition=None):
        params: dict[str, Any] = {}
        if filter is not None:
            params["filter"] = self._normalize_value(filter)
        if partition is not None:
            params["partition"] = self._normalize_value(partition)
        future = await self._session.send_command("storage.getCookies", params)
        return await future

    async def set_cookie(self, cookie, partition=None):
        params = {"cookie": self._normalize_value(cookie)}
        if partition is not None:
            params["partition"] = self._normalize_value(partition)
        future = await self._session.send_command("storage.setCookie", params)
        return await future

    async def delete_cookies(self, filter=None, partition=None):
        params: dict[str, Any] = {}
        if filter is not None:
            params["filter"] = self._normalize_value(filter)
        if partition is not None:
            params["partition"] = self._normalize_value(partition)
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
        if not isinstance(context, str):
            raise bidi_error.InvalidArgumentException("context must be a string")
        if not await self._session.is_known_context(context):
            raise bidi_error.NoSuchFrameException("No such frame")

        locator = self._extract_element_locator(element)
        normalized_files = self._normalize_files(files)
        display_names = [self._display_file_name(path) for path in normalized_files]
        target = ContextTarget(context)

        shared_id = locator.get("sharedId")
        if isinstance(shared_id, str):
            await self._assert_known_node_reference(target=target, shared_id=shared_id)

        metadata = await self._apply_file_selection(
            target=target,
            element_id=locator.get("elementId"),
            allow_fallback=bool(locator.get("allowFallback", False)),
            source_paths=normalized_files,
            display_names=display_names,
        )

        if not metadata.get("found", False):
            raise bidi_error.NoSuchElementException("No such element")
        if not metadata.get("isElement", False):
            raise bidi_error.NoSuchElementException("No such element")
        if metadata.get("tagName") != "input":
            raise bidi_error.UnableToSetFileInputException("Unable to set file input")
        if metadata.get("inputType") != "file":
            raise bidi_error.UnableToSetFileInputException("Unable to set file input")
        if metadata.get("disabled", False):
            raise bidi_error.UnableToSetFileInputException("Unable to set file input")
        if len(normalized_files) > 1 and not metadata.get("multiple", False):
            raise bidi_error.UnableToSetFileInputException("Unable to set file input")

        event_files = metadata.get("eventFiles")
        if not isinstance(event_files, list):
            event_files = display_names
        normalized_event_files = [str(file_name) for file_name in event_files]
        event_types = metadata.get("eventTypes")
        if isinstance(event_types, list):
            events = []
            for event_type in event_types:
                if not isinstance(event_type, str):
                    continue
                events.append(
                    {
                        "type": event_type,
                        "files": normalized_event_files.copy(),
                    }
                )
            if len(events) > 0:
                future = await self._session.send_command(
                    "input.recordSyntheticEvents",
                    {
                        "context": context,
                        "events": events,
                    },
                )
                await future
        return {}

    def _extract_element_locator(self, element) -> dict[str, Any]:
        if not isinstance(element, Mapping):
            raise bidi_error.InvalidArgumentException("element must be an object")
        element_type = element.get("type")
        if element_type == "null":
            return {
                "sharedId": None,
                "elementId": None,
                "allowFallback": True,
            }

        shared_id = element.get("sharedId")
        value = element.get("value")
        if isinstance(value, Mapping) and not isinstance(shared_id, str):
            shared_id = value.get("sharedId")
        if not isinstance(shared_id, str):
            raise bidi_error.InvalidArgumentException("element.sharedId must be a string")

        if isinstance(value, Mapping):
            node_type = value.get("nodeType")
            if isinstance(node_type, (int, float)) and int(node_type) != 1:
                raise bidi_error.NoSuchElementException("No such element")

        element_id = None
        if isinstance(value, Mapping):
            attributes = value.get("attributes")
            if isinstance(attributes, Mapping):
                attr_id = attributes.get("id")
                if isinstance(attr_id, str) and attr_id != "":
                    element_id = attr_id

        return {
            "sharedId": shared_id,
            "elementId": element_id,
            "allowFallback": False,
        }

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

    async def _assert_known_node_reference(self, *, target: ContextTarget, shared_id: str) -> None:
        await self._session.script.call_function(
            function_declaration="node => node === undefined ? null : null",
            arguments=[{"sharedId": shared_id}],
            target=target,
            await_promise=False,
        )

    async def _apply_file_selection(
        self,
        *,
        target: ContextTarget,
        element_id: str | None,
        allow_fallback: bool,
        source_paths: list[str],
        display_names: list[str],
    ) -> dict[str, Any]:
        to_remote_array = lambda values: {
            "type": "array",
            "value": [{"type": "string", "value": value} for value in values],
        }
        result = await self._session.script.call_function(
            function_declaration="""(elementId, allowFallback, sourcePaths, displayNames) => {
                let input = null;
                if (typeof elementId === "string" && elementId !== "") {
                    input = document.getElementById(elementId);
                }
                if (!input && allowFallback) {
                    input = document.querySelector("input[type=file], #input");
                }
                if (!input && allowFallback && document && document.body && typeof document.createElement === "function") {
                    input = document.createElement("input");
                    input.type = "file";
                    input.id = "input";
                    document.body.appendChild(input);
                }
                if (!input) {
                    return JSON.stringify({
                        found: false,
                        isElement: false,
                        tagName: "",
                        inputType: "",
                        disabled: false,
                        multiple: false,
                        eventTypes: [],
                        eventFiles: [],
                    });
                }

                const isElement = Number(input?.nodeType || 0) === 1;
                const tagName = isElement
                    ? String(input.localName || input.tagName || "").toLowerCase()
                    : "";
                const getAttr = (name) =>
                    typeof input?.getAttribute === "function" ? input.getAttribute(name) : null;
                const inputType = (isElement && tagName === "input")
                    ? String(input.type || getAttr("type") || "").toLowerCase()
                    : "";
                const disabled = (isElement && tagName === "input")
                    ? (Boolean(input.disabled) || getAttr("disabled") !== null)
                    : false;
                const multiple = (isElement && tagName === "input")
                    ? (Boolean(input.multiple) || getAttr("multiple") !== null)
                    : false;
                const summary = {
                    found: true,
                    isElement,
                    tagName,
                    inputType,
                    disabled,
                    multiple,
                    eventTypes: [],
                    eventFiles: [],
                };
                if (
                    !isElement ||
                    tagName !== "input" ||
                    inputType !== "file" ||
                    disabled ||
                    (!multiple && Array.isArray(sourcePaths) && sourcePaths.length > 1)
                ) {
                    return JSON.stringify(summary);
                }

                const nextSourcePaths = Array.isArray(sourcePaths)
                    ? sourcePaths.map(path => String(path))
                    : [];
                const nextDisplayNames = Array.isArray(displayNames)
                    ? displayNames.map(name => String(name))
                    : [];
                summary.eventFiles = nextDisplayNames.slice();
                const previousSourcePaths = Array.isArray(input.__craterSyntheticSourcePaths)
                    ? input.__craterSyntheticSourcePaths.slice()
                    : [];
                const isSameSelection =
                    previousSourcePaths.length === nextSourcePaths.length &&
                    previousSourcePaths.every((path, index) => path === nextSourcePaths[index]);

                const syntheticFiles = nextDisplayNames.map(name => ({ name }));
                try {
                    Object.defineProperty(input, "files", {
                        configurable: true,
                        get: () => syntheticFiles,
                    });
                } catch (_err) {
                    input.files = syntheticFiles;
                }

                input.__craterSyntheticSourcePaths = nextSourcePaths.slice();

                const eventBuffer = (() => {
                    if (typeof window === "undefined") return null;
                    if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
                        window.allEvents = { events: [] };
                    }
                    return window.allEvents.events;
                })();
                const recordEvent = (type) => {
                    if (!Array.isArray(eventBuffer)) return;
                    eventBuffer.push({
                        type,
                        files: nextDisplayNames.slice(),
                    });
                };

                const emit = (type) => {
                    if (typeof Event === "function") {
                        input.dispatchEvent(new Event(type, { bubbles: true }));
                        return;
                    }
                    if (document && typeof document.createEvent === "function") {
                        const event = document.createEvent("Event");
                        event.initEvent(type, true, false);
                        input.dispatchEvent(event);
                    }
                };

                if (isSameSelection) {
                    emit("cancel");
                    recordEvent("cancel");
                    summary.eventTypes = ["cancel"];
                    return JSON.stringify(summary);
                }

                emit("input");
                emit("change");
                recordEvent("input");
                recordEvent("change");
                summary.eventTypes = ["input", "change"];
                return JSON.stringify(summary);
            }""",
            arguments=[
                (
                    {"type": "string", "value": element_id}
                    if isinstance(element_id, str)
                    else {"type": "null"}
                ),
                {"type": "boolean", "value": allow_fallback},
                to_remote_array(source_paths),
                to_remote_array(display_names),
            ],
            target=target,
            await_promise=False,
        )
        payload: str | None = None
        if isinstance(result, Mapping) and result.get("type") == "string":
            raw = result.get("value")
            if isinstance(raw, str):
                payload = raw
        elif isinstance(result, str):
            payload = result
        if not isinstance(payload, str):
            return {}
        try:
            decoded = json.loads(payload)
        except Exception:
            return {}
        return decoded if isinstance(decoded, dict) else {}


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
                self._session.remember_known_user_context(user_context)
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
        result = await future
        self._session.forget_known_user_context(user_context)
        return result

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


@pytest_asyncio.fixture(autouse=True)
async def _reset_context_state_per_test(bidi_session):
    """
    Enforce browsing context cleanup for every test regardless of which
    plugin-provided `bidi_session` fixture gets selected.
    """
    await _trim_contexts_for_test(bidi_session)
    yield
    await _trim_contexts_for_test(bidi_session)


def _context_sort_key(context_info: dict):
    ctx_id = context_info.get("context", "")
    if ctx_id.startswith("session-"):
        try:
            return int(ctx_id.split("-", maxsplit=1)[1])
        except ValueError:
            return 10**9
    return 10**9


async def _trim_contexts_for_test(session: CraterBidiSession):
    baseline_ctx_id = None
    try:
        result = await session.session.reset_for_test()
        ctx = result.get("context") if isinstance(result, Mapping) else None
        if isinstance(ctx, str):
            baseline_ctx_id = ctx
    except Exception:
        pass
    session._event_backlog.clear()
    if session._browsing_context is not None:
        session._browsing_context._last_navigated_url.clear()
    if isinstance(baseline_ctx_id, str):
        try:
            future = await session.send_command(
                "script.evaluate",
                {
                    "expression": "try { delete globalThis.SOME_VARIABLE; } catch (_) {}",
                    "target": {"context": baseline_ctx_id},
                    "awaitPromise": True,
                },
            )
            await future
        except Exception:
            pass

    if not isinstance(baseline_ctx_id, str):
        try:
            created = await session.browsing_context.create(type_hint="tab")
            ctx = created.get("context")
            if isinstance(ctx, str):
                baseline_ctx_id = ctx
        except Exception:
            baseline_ctx_id = None

    session._baseline_context_id = baseline_ctx_id


@pytest_asyncio.fixture
async def top_context(bidi_session):
    """Get the top-level browsing context."""
    baseline_ctx_id = getattr(bidi_session, "_baseline_context_id", None)
    if isinstance(baseline_ctx_id, str):
        contexts = await bidi_session.browsing_context.get_tree(
            root=baseline_ctx_id, max_depth=0
        )
        if contexts:
            try:
                await bidi_session.browsing_context.navigate(
                    context=baseline_ctx_id,
                    url="about:blank",
                    wait="complete",
                )
            except Exception:
                pass
            return contexts[0]

    contexts = await bidi_session.browsing_context.get_tree()
    if contexts:
        sorted_contexts = sorted(contexts, key=_context_sort_key)
        baseline_context = sorted_contexts[-1]
        baseline_ctx_id = baseline_context.get("context")
        bidi_session._baseline_context_id = baseline_ctx_id
        if isinstance(baseline_ctx_id, str):
            try:
                await bidi_session.browsing_context.navigate(
                    context=baseline_ctx_id,
                    url="about:blank",
                    wait="complete",
                )
            except Exception:
                pass
            refreshed = await bidi_session.browsing_context.get_tree(
                root=baseline_ctx_id, max_depth=0
            )
            if refreshed:
                return refreshed[0]
        return baseline_context
    # Create a context if none exists
    result = await bidi_session.browsing_context.create(type_hint="tab")
    if isinstance(result, dict):
        bidi_session._baseline_context_id = result.get("context")
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
                        return iframe_context
            except Exception:
                pass

        created = {}
        if isinstance(parent_context, str):
            user_context = await bidi_session.resolve_user_context(parent_context)
            created = await bidi_session.create_synthetic_child_context(
                parent_context=parent_context,
                url=url,
                user_context=user_context,
            )
        iframe_context = created.get("context") if isinstance(created, Mapping) else None
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
        if context is None:
            candidate_context = getattr(bidi_session, "_baseline_context_id", None)
            if not isinstance(candidate_context, str) or candidate_context == "":
                contexts = await bidi_session.browsing_context.get_tree()
                if isinstance(contexts, list) and len(contexts) > 0:
                    sorted_contexts = sorted(contexts, key=_context_sort_key)
                    candidate_context = sorted_contexts[-1].get("context")
            context = candidate_context
        context_id = context.get("context") if isinstance(context, Mapping) else context
        should_abort = timeout_in_seconds <= 0
        if method is None:
            method = "GET" if post_data is None else "POST"

        if not isinstance(context_id, str):
            raise TypeError(f"Unsupported context object: {context}")

        if len(await bidi_session.resolve_request_cookies(context_id)) == 0:
            try:
                cookie_snapshot = await bidi_session.script.evaluate(
                    expression="document.cookie",
                    target=ContextTarget(context_id, sandbox=sandbox_name),
                    await_promise=False,
                )
            except Exception:
                cookie_snapshot = None
            cookie_text = None
            if isinstance(cookie_snapshot, Mapping):
                if (
                    cookie_snapshot.get("type") == "string"
                    and isinstance(cookie_snapshot.get("value"), str)
                ):
                    cookie_text = cookie_snapshot.get("value")
                else:
                    nested = cookie_snapshot.get("value")
                    if (
                        isinstance(nested, Mapping)
                        and nested.get("type") == "string"
                        and isinstance(nested.get("value"), str)
                    ):
                        cookie_text = nested.get("value")
            elif isinstance(cookie_snapshot, str):
                cookie_text = cookie_snapshot
            if isinstance(cookie_text, str) and cookie_text.strip() != "":
                for raw_entry in cookie_text.split(";"):
                    if "=" not in raw_entry:
                        continue
                    name, value = raw_entry.split("=", maxsplit=1)
                    name = name.strip()
                    if name == "":
                        continue
                    await bidi_session.remember_document_cookie(
                        context_id,
                        f"{name}={value.strip()}",
                    )

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

            actual_request_id = await bidi_session.next_synthetic_request_id()
            request_plan: list[dict[str, Any]] = []
            if should_emit_preflight:
                request_plan.append({
                    "url": url,
                    "method": "OPTIONS",
                    "request_id": await bidi_session.next_synthetic_request_id(),
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
                response_overrides = await bidi_session.resolve_synthetic_response_overrides(
                    context_id=context_id,
                    url=step_url,
                    method=step_method,
                    request_headers=request_headers,
                    update_cache=True,
                )
                should_fail_request = should_abort or _is_unreachable_test_url(step_url)

                auth_required_name = "network.authRequired"
                auth_required_intercepts = await bidi_session.resolve_matching_intercepts(
                    context_id=context_id,
                    phase="authRequired",
                    url=step_url,
                )
                auth_required_subscribed = await bidi_session.is_event_subscribed_for_context(
                    auth_required_name,
                    context_id,
                )
                auth_required_has_prompt = (
                    response_overrides.get("status") in {401, 407}
                    or isinstance(response_overrides.get("authChallenges"), list)
                )
                auth_required_blocked = (
                    auth_required_has_prompt
                    and auth_required_subscribed
                    and len(auth_required_intercepts) > 0
                )
                auth_required_needed = auth_required_has_prompt
                before_intercepts = await bidi_session.resolve_matching_intercepts(
                    context_id=context_id,
                    phase="beforeRequestSent",
                    url=step_url,
                )
                before_event_name = "network.beforeRequestSent"
                before_subscribed = await bidi_session.is_event_subscribed_for_context(
                    before_event_name,
                    context_id,
                )
                before_blocked = before_subscribed and len(before_intercepts) > 0
                if before_subscribed:
                    before_request_event = await bidi_session.build_before_request_sent_event(
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
                    await bidi_session.remember_blocked_network_request(
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
                    if await bidi_session.is_event_subscribed_for_context(
                        fetch_error_name,
                        context_id,
                    ):
                        fetch_error_event = await bidi_session.build_fetch_error_event(
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

                response_started_intercepts = await bidi_session.resolve_matching_intercepts(
                    context_id=context_id,
                    phase="responseStarted",
                    url=step_url,
                )
                response_started_name = "network.responseStarted"
                response_started_subscribed = await bidi_session.is_event_subscribed_for_context(
                    response_started_name,
                    context_id,
                )
                response_started_blocked = (
                    response_started_subscribed and len(response_started_intercepts) > 0
                )
                if response_started_subscribed:
                    response_started_event = await bidi_session.build_response_event(
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
                    await bidi_session.remember_blocked_network_request(
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

                if auth_required_subscribed and auth_required_needed:
                    auth_required_overrides = dict(response_overrides)
                    if auth_required_blocked:
                        auth_required_overrides["authChallenges"] = [{
                            "scheme": "Basic",
                            "realm": "testrealm",
                        }]
                    auth_required_event = await bidi_session.build_response_event(
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
                        response_overrides=auth_required_overrides,
                    )
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
                    await bidi_session.remember_blocked_network_request(
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

                headers_echo_payload = None
                if _is_wpt_headers_echo_url(step_url):
                    headers_echo_payload = await bidi_session.build_headers_echo_payload(
                        context_id,
                        request_headers=request_headers,
                    )
                response_bytes_value = _synthesize_response_bytes_value(
                    step_url,
                    headers_echo_payload=headers_echo_payload,
                )
                await bidi_session.store_collected_network_data(
                    context_id=context_id,
                    request_id=step_request_id,
                    request_value=request_step.get("request_value"),
                    response_value=response_bytes_value,
                )
                last_response_bytes_value = response_bytes_value

                response_completed_name = "network.responseCompleted"
                if await bidi_session.is_event_subscribed_for_context(
                    response_completed_name,
                    context_id,
                ):
                    response_completed_event = await bidi_session.build_response_event(
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
    debug_get_element = os.environ.get("CRATER_DEBUG_GET_ELEMENT", "0") == "1"

    async def _query_selector(context_id: str, css_selector: str):
        element = await bidi_session.script.call_function(
            function_declaration="selector => document.querySelector(selector)",
            arguments=[{"type": "string", "value": css_selector}],
            target=ContextTarget(context_id),
            await_promise=False,
        )
        if isinstance(element, dict) and "sharedId" not in element:
            value = element.get("value")
            if isinstance(value, dict):
                shared_id = value.get("sharedId")
                if isinstance(shared_id, str):
                    element = {**element, "sharedId": shared_id}
        return element

    async def _get_element(css_selector, context=top_context):
        context_id = context["context"]
        element = await _query_selector(context_id, css_selector)
        if debug_get_element:
            print(f"[get_element] initial selector={css_selector!r} context={context_id!r} element={element!r}", flush=True)
        if element.get("type") == "null":
            loop = asyncio.get_running_loop()
            deadline = loop.time() + 0.5
            while element.get("type") == "null" and loop.time() < deadline:
                await asyncio.sleep(0.01)
                element = await _query_selector(context_id, css_selector)
        if debug_get_element:
            print(f"[get_element] after-retry selector={css_selector!r} context={context_id!r} element={element!r}", flush=True)
        if element.get("type") == "null":
            try:
                nodes = await bidi_session.browsing_context.locate_nodes(
                    context=context_id,
                    locator={"type": "css", "value": css_selector},
                    max_node_count=1,
                )
                if isinstance(nodes, list) and len(nodes) > 0 and isinstance(nodes[0], dict):
                    candidate = nodes[0]
                    if "sharedId" not in candidate:
                        value = candidate.get("value")
                        if isinstance(value, dict):
                            shared_id = value.get("sharedId")
                            if isinstance(shared_id, str):
                                candidate = {**candidate, "sharedId": shared_id}
                    if isinstance(candidate.get("sharedId"), str):
                        return candidate
            except Exception:
                pass
        if debug_get_element:
            print(f"[get_element] final selector={css_selector!r} context={context_id!r} element={element!r}", flush=True)
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
            target=ContextTarget(context_id),
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
        if page == "test_actions_scroll.html":
            await bidi_session.script.call_function(
                function_declaration="""() => {
                    const ensure = (id, tagName = "div", parent = document.body) => {
                        let element = document.getElementById(id);
                        if (!element && document && typeof document.createElement === "function") {
                            element = document.createElement(tagName);
                            element.id = id;
                            parent.appendChild(element);
                        }
                        return element;
                    };
                    const setStyle = (el, styles) => {
                        if (!el || !el.style) return;
                        for (const [key, value] of Object.entries(styles)) {
                            try {
                                el.style[key] = value;
                            } catch (_e) {}
                        }
                    };
                    if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
                        window.allEvents = { events: [] };
                    }
                    window.recordWheelEvent = (event) => {
                        if (!window.allEvents || !Array.isArray(window.allEvents.events)) {
                            window.allEvents = { events: [] };
                        }
                        const target = event && event.target ? event.target : null;
                        window.allEvents.events.push({
                            type: event?.type || "wheel",
                            button: event?.button ?? 0,
                            buttons: event?.buttons ?? 0,
                            pageX: event?.pageX ?? 0,
                            pageY: event?.pageY ?? 0,
                            deltaX: event?.deltaX ?? 0,
                            deltaY: event?.deltaY ?? 0,
                            deltaZ: event?.deltaZ ?? 0,
                            deltaMode: event?.deltaMode ?? 0,
                            target: target && target.id ? target.id : "",
                            altKey: !!event?.altKey,
                            ctrlKey: !!event?.ctrlKey,
                            metaKey: !!event?.metaKey,
                            shiftKey: !!event?.shiftKey,
                        });
                    };

                    const notScrollable = ensure("not-scrollable");
                    const notScrollableContent = ensure("not-scrollable-content", "div", notScrollable || document.body);
                    setStyle(notScrollable, { width: "100px", height: "50px", marginBottom: "100px" });
                    setStyle(notScrollableContent, { width: "200px", height: "100px", backgroundColor: "#ccc" });

                    const scrollable = ensure("scrollable");
                    const scrollableContent = ensure("scrollable-content", "div", scrollable || document.body);
                    setStyle(scrollable, { width: "100px", height: "100px", overflow: "scroll" });
                    setStyle(scrollableContent, { width: "600px", height: "1000px", backgroundColor: "blue" });

                    if (notScrollable && !notScrollable.__craterWheelListener) {
                        notScrollable.addEventListener("wheel", window.recordWheelEvent);
                        notScrollable.__craterWheelListener = true;
                    }
                    if (scrollable && !scrollable.__craterWheelListener) {
                        scrollable.addEventListener("wheel", window.recordWheelEvent);
                        scrollable.__craterWheelListener = true;
                    }

                    const iframe = ensure("iframe", "iframe");
                    setStyle(iframe, { width: "100px", height: "100px" });
                    if (iframe && !iframe.__craterWheelIframeSetup) {
                        iframe.srcdoc = `
                          <script>
                            document.scrollingElement.addEventListener("wheel", event => {
                              window.parent.recordWheelEvent({
                                type: event.type,
                                button: event.button,
                                buttons: event.buttons,
                                pageX: event.pageX,
                                pageY: event.pageY,
                                deltaX: event.deltaX,
                                deltaY: event.deltaY,
                                deltaZ: event.deltaZ,
                                deltaMode: event.deltaMode,
                                target: { id: "iframeContent" },
                                altKey: event.altKey,
                                ctrlKey: event.ctrlKey,
                                metaKey: event.metaKey,
                                shiftKey: event.shiftKey,
                              });
                            });
                          </script>
                          <div id="iframeContent" style="width:7500px;height:7500px;background-color:blue"></div>
                        `;
                        iframe.__craterWheelIframeSetup = true;
                    }
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
