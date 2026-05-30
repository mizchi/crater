name = "mizchi/crater-browser-native"

version = "0.18.0"

import {
  "mizchi/crater-browser-runtime@0.18.0",
  "mizchi/crater-dom@0.18.0",
  "mizchi/v8@0.2.0",
}

readme = "README.md"

repository = "https://github.com/mizchi/crater"

license = "Apache-2.0"

description = "Native V8 host adapter for crater browser runtime"

preferred_target = "native"

options(
  "--moonbit-unstable-prebuild": "../scripts/mizchi-v8-consumer-prebuild.mjs",
)
