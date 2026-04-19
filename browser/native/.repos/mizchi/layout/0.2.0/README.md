# mizchi/layout

Reusable pure layout core extracted from `mizchi/crater`.

## Packages

- `mizchi/layout`: Pure alignment/sizing/inset core logic
- `mizchi/layout/types`: Minimal value types used by the core (`Alignment`, `AlignSelf`, `FlexDirection`, `Rect`, `Dimension`)
- `mizchi/layout/tree`: Incremental layout tree facade (dirty bits, cache stats, dirty rect collection)
- `mizchi/layout/node`: Node facade
- `mizchi/layout/style`: Style facade
- `mizchi/layout/engine_types`: Engine-level value types facade
- `mizchi/layout/engine`: Layout compute facade

## Commands

```bash
just        # moon check + moon test
just fmt    # moon fmt
just test   # moon test
just info   # moon info
```

## License

Apache-2.0
