# Terminal protocol compatibility source

The ansi, kitty and sixel encoders come from `mizchi/tui-terminal-protocol@0.1.2`
([mizchi/tui.mbt](https://github.com/mizchi/tui.mbt)), declared **MIT** in the
published module manifest. Its archive only provides the removed JSON manifest
format, so Crater carries the encoder implementation inside its terminal
protocol module. The public Crater wrappers and color types remain unchanged.

Only MoonBit syntax/API compatibility changes are made here. Keep the existing
`terminal_protocol/{ansi,kitty,sixel}` tests as the output compatibility gate.
The upstream module is no longer a registry dependency or a workspace release.

Upstream release archive SHA-256: `0cddcf31397a8d34e640fc5ee0558bdc1e679dd3c2d9f9348fd9a97d5d9a7a2c`.
