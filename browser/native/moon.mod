name = "mizchi/crater-browser-native"

version = "0.19.2"

import {
  "mizchi/crater-browser-runtime@0.19.2",
  "mizchi/crater-dom@0.19.2",
  "mizchi/v8@0.3.0",
  // Keep external dependency floors explicit in this standalone workspace.
  "moonbitlang/async@0.22.7",
  "moonbitlang/x@0.5.7",
}

readme = "README.md"

repository = "https://github.com/mizchi/crater"

license = "Apache-2.0"

description = "Native V8 host adapter for crater browser runtime"

preferred_target = "native"

options(
  "--moonbit-unstable-prebuild": "scripts/mizchi-v8-consumer-prebuild.mjs",
)
