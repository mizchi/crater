name = "mizchi/crater-browser-native"

version = "0.19.0"

import {
  "mizchi/crater-browser-runtime@0.19.0",
  "mizchi/crater-dom@0.19.0",
  "mizchi/v8@0.3.0",
  // This module is its own single-member workspace (`browser/native/moon.work`),
  // so it resolves deps independently of the root workspace. State the async
  // floor here rather than inheriting whatever mizchi/v8 happens to pin.
  "moonbitlang/async@0.21.3",
}

readme = "README.md"

repository = "https://github.com/mizchi/crater"

license = "Apache-2.0"

description = "Native V8 host adapter for crater browser runtime"

preferred_target = "native"

options(
  "--moonbit-unstable-prebuild": "../scripts/mizchi-v8-consumer-prebuild.mjs",
)
