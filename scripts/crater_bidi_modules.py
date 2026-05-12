"""WebDriver BiDi module proxies for crater_bidi_adapter.

This module intentionally contains protocol-shaped command adapters while
crater_bidi_adapter.py stays focused on pytest fixtures and transport glue.
"""

from typing import Any, Mapping

import webdriver.bidi.error as bidi_error
from webdriver.bidi.modules.script import ScriptEvaluateResultException


_UNSET = object()


def _require_context_info(value: Any, source: str):
    if isinstance(value, Mapping) and isinstance(value.get("context"), str):
        return value
    raise bidi_error.UnknownErrorException(f"{source} returned invalid context info")



def _context_id(context):
    return context.get("context") if isinstance(context, Mapping) else context



class _CommandProxy:
    def __init__(self, session: Any):
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
        }
        context_id = _context_id(context)
        if isinstance(context_id, str):
            params["context"] = context_id
        if isinstance(method, str):
            params["method"] = method
        if isinstance(headers, Mapping):
            params["headers"] = dict(headers)
        if isinstance(post_data, dict):
            params["postData"] = post_data
            params["postDataMode"] = "formData"
        elif post_data is not None:
            params["postData"] = post_data
            params["postDataMode"] = "value"
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
        params: dict[str, Any] = {"request": request_id}
        for key, value in kwargs.items():
            params[key] = value

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
        params = {"request": request, "action": action}
        if credentials is not None:
            params["credentials"] = credentials
        await self._command("network.continueAuthRequest", params)
        return {}

    async def provide_response(self, request: str, **kwargs):
        request_id = self._validate_request_id(request)
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
        return await self._command(
            "webExtension.installId",
            {"extensionData": extension_data},
        )

    async def uninstall(self, extension):
        return await self._command(
            "webExtension.uninstall",
            {"extension": extension},
        )

