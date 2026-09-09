name = "mizchi/crater-browser-native"

version = "0.19.0"

import {
  "mizchi/crater-browser-runtime@0.19.0",
  "mizchi/crater-dom@0.19.0",
  // Pinned to the newest published mizchi/v8. It does not compile against the
  // current moonbitlang/core (`@strconv.parse_int` was moved to
  // `moonbitlang/core/string` and `StrConvError` is gone), so
  // `moon check --target native` fails inside `.mooncakes/mizchi/v8`.
  // v8.mbt main already carries the fix and is versioned 0.3.0; bump this pin
  // to 0.3.0 once that is published to mooncakes. See TODO.md External / Blocker.
  "mizchi/v8@0.2.0",
  // mizchi/v8 pins moonbitlang/async 0.16.8, which no longer compiles against
  // the current core (`IterResult` undefined in task_group.mbt). This module is
  // its own single-member workspace (`browser/native/moon.work`), so it resolves
  // deps independently of the root workspace and needs the floor stated here.
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
