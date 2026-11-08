name = "mizchi/crater-testing"

version = "0.19.2"

import {
  "mizchi/crater-core@0.19.2",
  "mizchi/crater-browser@0.19.2",
  "mizchi/crater-browser-native@0.19.2",
  "mizchi/crater-browser-runtime@0.19.2",
  "mizchi/css@0.8.0",
  "mizchi/crater-dom@0.19.2",
  "mizchi/crater-layout@0.19.2",
}

repository = "https://github.com/mizchi/crater"

license = "Apache-2.0"

description = "WPT runtime and MoonBit test packages for crater"

preferred_target = "js"

options(
  "--moonbit-unstable-prebuild": "../browser/scripts/mizchi-v8-consumer-prebuild.mjs",
)
