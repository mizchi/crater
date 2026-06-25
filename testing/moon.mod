name = "mizchi/crater-testing"

version = "0.18.0"

import {
  "mizchi/crater-core@0.18.0",
  "mizchi/crater-browser@0.18.0",
  "mizchi/crater-browser-native@0.18.0",
  "mizchi/crater-browser-runtime@0.18.0",
  "mizchi/css@0.5.4",
  "mizchi/crater-dom@0.18.0",
  "mizchi/crater-layout@0.18.0",
}

repository = "https://github.com/mizchi/crater"

license = "Apache-2.0"

description = "WPT runtime and MoonBit test packages for crater"

preferred_target = "js"

options(
  "--moonbit-unstable-prebuild": "../browser/scripts/mizchi-v8-consumer-prebuild.mjs",
)
