# API Documentation

This file contains executable doc tests using `mbt check` blocks.

## compute_justify

Compute `(start_offset, gap_between_items)` for content distribution.

```mbt check
///|
test {
  inspect(compute_justify(@types.SpaceBetween, 90.0, 4), content="(0, 30)")
  inspect(compute_justify(@types.Center, 40.0, 2), content="(20, 0)")
}
```

## clamp_size_with_box_min

Clamp width/height by min/max constraints with an absolute box-min lower bound.

```mbt check
///|
test {
  inspect(
    clamp_size_with_box_min(5.0, 3.0, 0.0, 100.0, 0.0, 100.0, 12.0, 8.0),
    content="(12, 8)",
  )
}
```
