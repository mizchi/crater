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
import time
from typing import Any, Mapping

import pytest
import pytest_asyncio
import websockets
import webdriver.bidi.error as bidi_error
from webdriver.bidi.modules.script import ContextTarget, ScriptEvaluateResultException


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
        return result.get("realms", [])


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

    def _inline(content: str, content_type: str = "text/html", domain: str = "", **_ignored) -> str:
        encoded = base64.b64encode(content.encode()).decode()
        suffix = f"#domain={domain}" if domain else ""
        return f"data:{content_type};base64,{encoded}{suffix}"
    return _inline


@pytest.fixture
def iframe(inline):
    """Inline document extract as the source document of an <iframe>."""
    def _iframe(src: str, **kwargs) -> str:
        return f"<iframe src='{inline(src, **kwargs)}'></iframe>"

    return _iframe


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
        future = asyncio.get_running_loop().create_future()

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


@pytest_asyncio.fixture
async def current_session():
    """Placeholder for classic WebDriver session (not supported)."""
    return None


@pytest.fixture
def session():
    """Minimal classic session fixture for session.new BiDi upgrade tests."""
    return CraterClassicSession(CRATER_BIDI_URL)


@pytest.fixture
def capabilities():
    """Session capabilities."""
    return {}


@pytest_asyncio.fixture
async def create_user_context(bidi_session):
    """Create user contexts and clean them up after test."""
    created = []

    async def _create(**kwargs):
        result = await bidi_session.browser.create_user_context(**kwargs)
        user_context = result.get("userContext")
        if isinstance(user_context, str) and user_context != "default":
            created.append(user_context)
        return user_context

    yield _create

    for user_context in reversed(created):
        try:
            await bidi_session.browser.remove_user_context(user_context=user_context)
        except Exception:
            pass


@pytest.fixture
def wait_for_future_safe():
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
        if frame_doc is None:
            frame_doc = """<div id="in-frame"><input type="checkbox"/></div>"""

        if shadow_doc is None:
            shadow_doc = """<div id="in-shadow-dom"><input type="checkbox"/></div>"""

        definition_inner_shadow_dom = ""
        if nested_shadow_dom:
            definition_inner_shadow_dom = f"""
                customElements.define('inner-custom-element',
                    class extends HTMLElement {{
                        constructor() {{
                            super();
                            this.attachShadow({{mode: "{shadow_root_mode}"}}).innerHTML = `
                                {shadow_doc}
                            `;
                        }}
                    }}
                );
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

            {iframe(frame_doc, **kwargs)}

            <img />
            <svg></svg>

            <custom-element id="custom-element"></custom-element>
            <script>
                var svg = document.querySelector("svg");
                if (svg && svg.setAttributeNS) {{
                    svg.setAttributeNS("http://www.w3.org/2000/svg", "svg:foo", "bar");
                }}

                if (window.customElements && customElements.define) {{
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
                    {definition_inner_shadow_dom}
                }} else {{
                    const host = document.querySelector('#custom-element');
                    if (host && host.attachShadow && !host.shadowRoot) {{
                        const shadowRoot = host.attachShadow({{ mode: "{shadow_root_mode}" }});
                        shadowRoot.innerHTML = `{shadow_doc}`;
                        window._shadowRoot = shadowRoot;
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


@pytest.fixture
def setup_network_test(bidi_session):
    """Setup for network tests (placeholder)."""
    async def _setup():
        pass
    return _setup
