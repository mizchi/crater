# Crater Web Vitals

MoonBit helpers for browser-facing Web Vitals signals in Crater.

The public root package currently exposes:

- CLS helpers: `compute_element_shift`, `compute_total`, and `LayoutShift`
- LCP helpers: `LCPCandidate`, `LCPTracker`, `extract_lcp_candidates`
- readiness helpers: `ContentReadiness`

Use this module when you need metric calculations over Crater layout output
without depending on the broader browser shell.
