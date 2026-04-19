set shell := ["bash", "-cu"]

wpt-svg-gen *args:
  node scripts/generate-wpt-svg.mjs {{args}}

wpt-svg *args:
  just wpt-svg-gen {{args}}
  moon run src/cmd/wpt-svg
