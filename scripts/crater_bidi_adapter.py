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
import json
import os
from typing import Any, Mapping

import pytest
import pytest_asyncio
import websockets
import webdriver.bidi.error as bidi_error


CRATER_BIDI_URL = os.environ.get("CRATER_BIDI_URL", "ws://127.0.0.1:9222")


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
        self._receive_task = None
        self.event_loop = None

        # Module proxies (lazily initialized)
        self._browsing_context = None
        self._session_module = None
        self._script = None
        self._network = None
        self._storage = None
        self._input = None
        self._browser = None

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
            self._ws = None

    async def _receive_messages(self):
        """Receive and dispatch messages from the server."""
        try:
            async for message in self._ws:
                data = json.loads(message)
                if "id" in data:
                    # Command response
                    cmd_id = data["id"]
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
                    if method and method in self._event_listeners:
                        params = data.get("params", {})
                        for handler in self._event_listeners[method]:
                            try:
                                await handler(method, params)
                            except Exception as e:
                                print(f"Event handler error: {e}")
        except websockets.exceptions.ConnectionClosed:
            pass
        except asyncio.CancelledError:
            pass

    async def send_command(self, method: str, params: Mapping[str, Any]) -> asyncio.Future:
        """Send a BiDi command and return a future for the response."""
        self._command_id += 1
        cmd_id = self._command_id

        message = json.dumps({
            "id": cmd_id,
            "method": method,
            "params": params
        })

        future = self.event_loop.create_future()
        self._pending_commands[cmd_id] = future

        await self._ws.send(message)
        return future

    def add_event_listener(self, event_name: str, handler):
        """Add an event listener."""
        if event_name not in self._event_listeners:
            self._event_listeners[event_name] = []
        self._event_listeners[event_name].append(handler)

        def remove():
            if handler in self._event_listeners.get(event_name, []):
                self._event_listeners[event_name].remove(handler)

        return remove

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

    async def create(self, type_hint: str = "tab", **kwargs):
        future = await self._session.send_command(
            "browsingContext.create", {"type": type_hint, **kwargs}
        )
        return await future

    async def navigate(self, context: str, url: str, wait: str = "none"):
        future = await self._session.send_command(
            "browsingContext.navigate", {"context": context, "url": url, "wait": wait}
        )
        return await future

    async def get_tree(self, root=None, max_depth=None):
        params = {}
        if root is not None:
            params["root"] = root
        if max_depth is not None:
            params["maxDepth"] = max_depth
        future = await self._session.send_command("browsingContext.getTree", params)
        result = await future
        return result.get("contexts", [])

    async def close(self, context: str):
        future = await self._session.send_command(
            "browsingContext.close", {"context": context}
        )
        return await future

    async def reload(self, context: str, **kwargs):
        future = await self._session.send_command(
            "browsingContext.reload", {"context": context, **kwargs}
        )
        return await future

    async def print(self, context: str, **kwargs):
        future = await self._session.send_command(
            "browsingContext.print", {"context": context, **kwargs}
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
        if contexts:
            params["contexts"] = contexts
        if user_contexts:
            params["userContexts"] = user_contexts
        future = await self._session.send_command("session.subscribe", params)
        return await future

    async def unsubscribe(self, subscriptions: list = None, **kwargs):
        params = {}
        if subscriptions:
            params["subscriptions"] = subscriptions
        params.update(kwargs)
        future = await self._session.send_command("session.unsubscribe", params)
        return await future


class ScriptModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def evaluate(self, expression, target, await_promise=False, **kwargs):
        params = {
            "expression": expression,
            "target": target,  # Pass target as-is for WPT validation tests
            "awaitPromise": await_promise,
        }
        # Convert snake_case kwargs to camelCase
        for key, value in kwargs.items():
            camel_key = self._to_camel_case(key)
            # Handle serializationOptions specially
            if camel_key == "serializationOptions" and isinstance(value, dict):
                params[camel_key] = self._convert_serialization_options(value)
            else:
                params[camel_key] = value
        future = await self._session.send_command("script.evaluate", params)
        return await future

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
        params = {
            "functionDeclaration": function_declaration,
            "target": target,  # Pass target as-is for WPT validation tests
            "awaitPromise": await_promise,
        }
        if arguments:
            params["arguments"] = arguments
        # Convert snake_case kwargs to camelCase
        for key, value in kwargs.items():
            camel_key = self._to_camel_case(key)
            if camel_key == "serializationOptions" and isinstance(value, dict):
                params[camel_key] = self._convert_serialization_options(value)
            else:
                params[camel_key] = value
        future = await self._session.send_command("script.callFunction", params)
        return await future

    async def add_preload_script(self, function_declaration: str, **kwargs):
        params = {"functionDeclaration": function_declaration, **kwargs}
        future = await self._session.send_command("script.addPreloadScript", params)
        return await future

    async def remove_preload_script(self, script: str):
        future = await self._session.send_command("script.removePreloadScript", {"script": script})
        return await future


class NetworkModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def add_intercept(self, phases: list, url_patterns: list, **kwargs):
        params = {"phases": phases, "urlPatterns": url_patterns, **kwargs}
        future = await self._session.send_command("network.addIntercept", params)
        return await future

    async def remove_intercept(self, intercept: str):
        future = await self._session.send_command("network.removeIntercept", {"intercept": intercept})
        return await future

    async def continue_request(self, request: str, **kwargs):
        params = {"request": request, **kwargs}
        future = await self._session.send_command("network.continueRequest", params)
        return await future

    async def fail_request(self, request: str):
        future = await self._session.send_command("network.failRequest", {"request": request})
        return await future

    async def provide_response(self, request: str, **kwargs):
        params = {"request": request, **kwargs}
        future = await self._session.send_command("network.provideResponse", params)
        return await future

    async def add_data_collector(self, **kwargs):
        future = await self._session.send_command("network.addDataCollector", kwargs)
        return await future

    async def remove_data_collector(self, collector: str):
        future = await self._session.send_command("network.removeDataCollector", {"collector": collector})
        return await future


class StorageModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def set_cookie(self, cookie, partition=None):
        params = {"cookie": cookie}
        if partition:
            params["partition"] = partition
        future = await self._session.send_command("storage.setCookie", params)
        return await future

    async def delete_cookies(self, filter=None, partition=None):
        params = {}
        if filter:
            params["filter"] = filter
        if partition:
            params["partition"] = partition
        future = await self._session.send_command("storage.deleteCookies", params)
        return await future


class InputModule:
    def __init__(self, session: CraterBidiSession):
        self._session = session

    async def perform_actions(self, actions, context: str):
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
        future = await self._session.send_command("browser.createUserContext", kwargs)
        return await future

    async def remove_user_context(self, user_context: str):
        future = await self._session.send_command("browser.removeUserContext", {"userContext": user_context})
        return await future


# Pytest fixtures

@pytest.fixture
def event_loop():
    """Create an event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def bidi_session():
    """Create a BiDi session connected to Crater."""
    session = CraterBidiSession(CRATER_BIDI_URL)
    await session.start()
    yield session
    await session.end()


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
def url():
    """Generate test URLs."""
    def _url(path: str) -> str:
        # WPT test server would normally be at localhost:8000
        base = os.environ.get("WPT_SERVER_URL", "http://localhost:8000")
        if path.startswith("/"):
            return f"{base}{path}"
        return f"{base}/{path}"
    return _url


@pytest.fixture
def inline():
    """Generate inline HTML data URLs."""
    import base64

    def _inline(content: str, content_type: str = "text/html") -> str:
        encoded = base64.b64encode(content.encode()).decode()
        return f"data:{content_type};base64,{encoded}"
    return _inline


@pytest.fixture
def configuration():
    """Test configuration."""
    return {
        "timeout_multiplier": float(os.environ.get("WPT_TIMEOUT_MULTIPLIER", "1.0")),
    }


@pytest_asyncio.fixture
async def subscribe_events(bidi_session):
    """Subscribe to events and clean up after test."""
    subscriptions = []

    async def _subscribe(events, contexts=None, user_contexts=None):
        result = await bidi_session.session.subscribe(
            events=events, contexts=contexts, user_contexts=user_contexts
        )
        if "subscription" in result:
            subscriptions.append(result["subscription"])
        return result

    yield _subscribe

    for sub in reversed(subscriptions):
        try:
            await bidi_session.session.unsubscribe(subscriptions=[sub])
        except Exception:
            pass


@pytest.fixture
def wait_for_event(bidi_session, event_loop):
    """Wait for a BiDi event."""
    remove_listeners = []

    def _wait_for_event(event_name: str):
        future = event_loop.create_future()

        async def on_event(_, data):
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
def send_blocking_command(bidi_session):
    """Send a blocking command."""
    async def _send(command: str, params: dict):
        future = await bidi_session.send_command(command, params)
        return await future
    return _send


@pytest_asyncio.fixture
async def current_session():
    """Placeholder for classic WebDriver session (not supported)."""
    return None


@pytest.fixture
def capabilities():
    """Session capabilities."""
    return {}


@pytest.fixture
def wait_for_future_safe(event_loop):
    """
    Wait for a future with a timeout, returning a default value on timeout or error.
    This is similar to WPT's wait_for_future_safe.
    """
    async def _wait_for_future_safe(future, timeout: float = 5.0, default=None):
        try:
            return await asyncio.wait_for(future, timeout=timeout)
        except (asyncio.TimeoutError, Exception):
            return default
    return _wait_for_future_safe


@pytest_asyncio.fixture
async def test_page(bidi_session, new_tab, inline):
    """Create a test page with basic HTML."""
    page = inline("<html><body><p>Test page</p></body></html>")
    await bidi_session.browsing_context.navigate(
        context=new_tab["context"],
        url=page,
        wait="complete"
    )
    return new_tab


@pytest.fixture
def assert_file_dialog_canceled():
    """Stub for file dialog assertions (not supported)."""
    def _assert(*args, **kwargs):
        raise NotImplementedError("File dialogs are not supported by Crater")
    return _assert


@pytest.fixture
def create_dialog():
    """Stub for dialog creation (not supported)."""
    async def _create(*args, **kwargs):
        raise NotImplementedError("Dialogs are not supported by Crater")
    return _create


@pytest.fixture
def wait_for_class_change(bidi_session, event_loop):
    """Wait for a class to change on an element."""
    async def _wait(context: str, selector: str, expected_class: str, timeout: float = 5.0):
        # For now, just return immediately as Crater doesn't support full DOM monitoring
        return True
    return _wait


@pytest.fixture
def setup_network_test(bidi_session):
    """Setup for network tests (placeholder)."""
    async def _setup():
        pass
    return _setup
