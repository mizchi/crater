# crater-network

Reusable network state and encoding helpers shared by Crater adapters.

This module intentionally owns only protocol-neutral state and value shapes.
WebDriver BiDi command dispatch, cookie storage, and browser integration stay in
`mizchi/crater-webdriver-bidi`.
