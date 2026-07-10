name = "mizchi/crater"

version = "0.19.0"

import {
  "mizchi/css@0.7.3",
  "mizchi/crater-dom@0.19.0",
  "mizchi/crater-layout@0.19.0",
  "mizchi/crater-webvitals@0.19.0",
  "mizchi/crater-painter@0.19.0",
  "mizchi/crater-renderer@0.19.0",
}

readme = "README.mbt.md"

repository = "https://github.com/mizchi/crater"

license = "Apache-2.0"

keywords = [ "css", "browser" ]

description = "CSS Layout Engine that implements Box/Flex/Grid"

preferred_target = "js"

options(
  exclude: [
    "wpt",
    "_build",
    "node_modules",
    "browser",
    "js",
    "wasm",
    "tests",
    "wpt-tests",
    "scripts",
    "docs",
  ],
)
