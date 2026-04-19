// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for FileKind

///|
pub impl Show for FileKind with output(self, logger) {
  match self {
    Unknown => logger.write_string("Unknown")
    Regular => logger.write_string("Regular")
    Directory => logger.write_string("Directory")
    SymLink => logger.write_string("SymLink")
    Socket => logger.write_string("Socket")
    Pipe => logger.write_string("Pipe")
    BlockDevice => logger.write_string("BlockDevice")
    CharDevice => logger.write_string("CharDevice")
  }
}
