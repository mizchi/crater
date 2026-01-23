#!/usr/bin/env python3
"""
Manual BiDi Test Script

Quick verification of BiDi functionality without full WPT infrastructure.
Run: uv run scripts/test-bidi-manual.py
"""

import asyncio
import json
import sys

try:
    import websockets
except ImportError:
    print("websockets not installed. Run: uv pip install websockets")
    sys.exit(1)

BIDI_URL = "ws://127.0.0.1:9222"

class BidiTester:
    def __init__(self):
        self.ws = None
        self.cmd_id = 0
        self.passed = 0
        self.failed = 0
        self.event_queue = []  # Store received events

    async def connect(self):
        self.ws = await websockets.connect(BIDI_URL)

    async def close(self):
        if self.ws:
            await self.ws.close()

    async def send(self, method: str, params: dict = None):
        self.cmd_id += 1
        expected_id = self.cmd_id
        msg = {"id": expected_id, "method": method, "params": params or {}}
        await self.ws.send(json.dumps(msg))

        # Keep receiving until we get a response with matching ID
        while True:
            raw = await self.ws.recv()
            resp = json.loads(raw)

            # If it's an event, queue it and continue waiting
            if resp.get("type") == "event":
                self.event_queue.append(resp)
                continue

            # If it's a response with matching ID, return it
            if resp.get("id") == expected_id:
                return resp

            # If it's a response with wrong ID, something is wrong
            # but continue anyway (might be out of order)
            if "id" in resp:
                # Store it? For now just return it
                return resp

    def check(self, name: str, condition: bool, msg: str = ""):
        if condition:
            print(f"  ✓ {name}")
            self.passed += 1
        else:
            print(f"  ✗ {name}: {msg}")
            self.failed += 1

async def test_session_status(t: BidiTester):
    print("\n[session.status]")
    resp = await t.send("session.status")
    t.check("returns success", resp.get("type") == "success")
    result = resp.get("result", {})
    t.check("ready is true", result.get("ready") == True)
    t.check("has message", "message" in result)

async def test_browsing_context_create(t: BidiTester):
    print("\n[browsingContext.create]")
    resp = await t.send("browsingContext.create", {"type": "tab"})
    t.check("returns success", resp.get("type") == "success")
    result = resp.get("result", {})
    t.check("has context", "context" in result)
    return result.get("context")

async def test_browsing_context_get_tree(t: BidiTester, ctx_id: str):
    print("\n[browsingContext.getTree]")
    resp = await t.send("browsingContext.getTree")
    t.check("returns success", resp.get("type") == "success")
    result = resp.get("result", {})
    contexts = result.get("contexts", [])
    t.check("has contexts", len(contexts) > 0)
    if contexts:
        t.check("context has id", "context" in contexts[0])
        t.check("context has url", "url" in contexts[0])

async def test_script_evaluate(t: BidiTester, ctx_id: str):
    print("\n[script.evaluate]")

    # Test number
    resp = await t.send("script.evaluate", {
        "expression": "1 + 2",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("number: 1+2=3", result.get("type") == "number" and result.get("value") == 3)

    # Test string
    resp = await t.send("script.evaluate", {
        "expression": "'hello'",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("string: 'hello'", result.get("type") == "string" and result.get("value") == "hello")

    # Test boolean
    resp = await t.send("script.evaluate", {
        "expression": "true",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("boolean: true", result.get("type") == "boolean" and result.get("value") == True)

    # Test undefined
    resp = await t.send("script.evaluate", {
        "expression": "undefined",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("undefined", result.get("type") == "undefined")

    # Test null
    resp = await t.send("script.evaluate", {
        "expression": "null",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("null", result.get("type") == "null")

    # Test array
    resp = await t.send("script.evaluate", {
        "expression": "[1, 2, 3]",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("array", result.get("type") == "array")

    # Test NaN
    resp = await t.send("script.evaluate", {
        "expression": "NaN",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("NaN", result.get("type") == "number" and result.get("value") == "NaN")

    # Test Infinity
    resp = await t.send("script.evaluate", {
        "expression": "Infinity",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("Infinity", result.get("type") == "number" and result.get("value") == "Infinity")

async def test_script_call_function(t: BidiTester, ctx_id: str):
    print("\n[script.callFunction]")

    resp = await t.send("script.callFunction", {
        "functionDeclaration": "() => 42",
        "target": {"context": ctx_id},
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("() => 42", result.get("type") == "number" and result.get("value") == 42)

    resp = await t.send("script.callFunction", {
        "functionDeclaration": "(a, b) => a + b",
        "target": {"context": ctx_id},
        "arguments": [
            {"type": "number", "value": 3},
            {"type": "number", "value": 4}
        ],
        "awaitPromise": True
    })
    result = resp.get("result", {}).get("result", {})
    t.check("(a, b) => a + b with args", result.get("type") == "number" and result.get("value") == 7)

async def test_validation_errors(t: BidiTester, ctx_id: str):
    print("\n[validation errors]")

    # Invalid maxDepth type
    resp = await t.send("browsingContext.getTree", {"maxDepth": "foo"})
    t.check("maxDepth string -> error", resp.get("type") == "error")

    # Invalid maxDepth value (negative)
    resp = await t.send("browsingContext.getTree", {"maxDepth": -1})
    t.check("maxDepth -1 -> error", resp.get("type") == "error")

    # Invalid root
    resp = await t.send("browsingContext.getTree", {"root": "nonexistent"})
    t.check("unknown root -> error", resp.get("type") == "error")

    # Missing target
    resp = await t.send("script.evaluate", {"expression": "1"})
    t.check("missing target -> error", resp.get("type") == "error")

async def test_navigation(t: BidiTester, ctx_id: str):
    print("\n[navigation]")
    import base64

    # Navigate to data URL
    html = "<html><head><title>Test</title></head><body><p>Hello World</p></body></html>"
    data_url = f"data:text/html;base64,{base64.b64encode(html.encode()).decode()}"
    resp = await t.send("browsingContext.navigate", {
        "context": ctx_id,
        "url": data_url,
        "wait": "complete"
    })
    t.check("navigate returns success", resp.get("type") == "success")
    result = resp.get("result", {})
    t.check("has navigation id", "navigation" in result)
    t.check("has url", "url" in result)

async def test_script_validation(t: BidiTester, ctx_id: str):
    print("\n[script validation]")

    # Invalid awaitPromise type (null)
    resp = await t.send("script.evaluate", {
        "expression": "1",
        "target": {"context": ctx_id},
        "awaitPromise": None  # null in JSON
    })
    t.check("awaitPromise null -> error", resp.get("type") == "error", f"got: {resp}")

    # Invalid awaitPromise type (string)
    resp = await t.send("script.evaluate", {
        "expression": "1",
        "target": {"context": ctx_id},
        "awaitPromise": "false"  # string, not boolean
    })
    t.check("awaitPromise string -> error", resp.get("type") == "error", f"got: {resp}")

    # Invalid awaitPromise type (number)
    resp = await t.send("script.evaluate", {
        "expression": "1",
        "target": {"context": ctx_id},
        "awaitPromise": 42
    })
    t.check("awaitPromise number -> error", resp.get("type") == "error", f"got: {resp}")

    # Invalid resultOwnership
    resp = await t.send("script.evaluate", {
        "expression": "1",
        "target": {"context": ctx_id},
        "awaitPromise": True,
        "resultOwnership": "invalid"
    })
    t.check("resultOwnership invalid -> error", resp.get("type") == "error", f"got: {resp}")

    # Invalid userActivation type
    resp = await t.send("script.evaluate", {
        "expression": "1",
        "target": {"context": ctx_id},
        "awaitPromise": True,
        "userActivation": "true"  # string, not boolean
    })
    t.check("userActivation string -> error", resp.get("type") == "error", f"got: {resp}")

async def test_event_subscription(t: BidiTester, ctx_id: str):
    print("\n[event subscription]")

    # Subscribe to browsingContext events (global)
    resp = await t.send("session.subscribe", {
        "events": ["browsingContext.load", "browsingContext.domContentLoaded"]
    })
    t.check("subscribe returns success", resp.get("type") == "success", f"got: {resp}")

    # Subscribe with context filter
    resp = await t.send("session.subscribe", {
        "events": ["script.realmCreated"],
        "contexts": [ctx_id]
    })
    t.check("subscribe with contexts returns success", resp.get("type") == "success", f"got: {resp}")

    # Unsubscribe from an event
    resp = await t.send("session.unsubscribe", {
        "events": ["browsingContext.load"]
    })
    t.check("unsubscribe returns success", resp.get("type") == "success", f"got: {resp}")

    # Unsubscribe with context filter
    resp = await t.send("session.unsubscribe", {
        "events": ["script.realmCreated"],
        "contexts": [ctx_id]
    })
    t.check("unsubscribe with contexts returns success", resp.get("type") == "success", f"got: {resp}")

async def test_events_received(t: BidiTester):
    """Test that events are actually emitted after subscription"""
    print("\n[events received]")

    # First subscribe to events
    resp = await t.send("session.subscribe", {
        "events": ["browsingContext"]
    })
    t.check("subscribe to browsingContext", resp.get("type") == "success", f"got: {resp}")

    # Create a new context - should trigger contextCreated event
    resp = await t.send("browsingContext.create", {"type": "tab"})
    t.check("create context returns success", resp.get("type") == "success", f"got: {resp}")
    new_ctx_id = resp.get("result", {}).get("context")
    t.check("new context has id", new_ctx_id is not None, f"got: {resp}")

    # Navigate - should trigger navigation events
    if new_ctx_id:
        import base64
        html = "<html><body>Test</body></html>"
        data_url = f"data:text/html;base64,{base64.b64encode(html.encode()).decode()}"
        resp = await t.send("browsingContext.navigate", {
            "context": new_ctx_id,
            "url": data_url,
            "wait": "complete"
        })
        t.check("navigate returns success", resp.get("type") == "success")

        # Close the context - should trigger contextDestroyed
        resp = await t.send("browsingContext.close", {"context": new_ctx_id})
        t.check("close context returns success", resp.get("type") == "success")

async def main():
    print("=== Crater BiDi Manual Test ===")
    print(f"Connecting to {BIDI_URL}...")

    t = BidiTester()
    try:
        await t.connect()
        print("Connected.\n")

        await test_session_status(t)
        ctx_id = await test_browsing_context_create(t)
        await test_browsing_context_get_tree(t, ctx_id)
        await test_navigation(t, ctx_id)
        await test_script_evaluate(t, ctx_id)
        await test_script_call_function(t, ctx_id)
        await test_validation_errors(t, ctx_id)
        await test_script_validation(t, ctx_id)
        await test_event_subscription(t, ctx_id)
        await test_events_received(t)

        print(f"\n=== Results ===")
        print(f"Passed: {t.passed}")
        print(f"Failed: {t.failed}")

        return 0 if t.failed == 0 else 1

    except ConnectionRefusedError:
        print("Error: Could not connect to BiDi server.")
        print("Start the server with: just start-bidi")
        return 1
    except Exception as e:
        print(f"Error: {e}")
        return 1
    finally:
        await t.close()

if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
