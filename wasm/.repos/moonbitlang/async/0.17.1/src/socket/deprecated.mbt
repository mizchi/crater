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
pub impl Show for InvalidAddr

///|
pub impl Show for InvalidAddr with output(_self, logger) {
  logger.write_string("InvalidAddr")
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for ResolveHostnameError

///|
pub impl Show for ResolveHostnameError with output(self, logger) {
  match self {
    ResolveHostnameError(msg) =>
      logger
      ..write_string("ResolveHostnameError(")
      ..write_object(msg)
      .write_string(")")
  }
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for IpProtocolPreference

///|
pub impl Show for IpProtocolPreference with output(self, logger) {
  match self {
    OnlyV4 => logger.write_string("OnlyV4")
    OnlyV6 => logger.write_string("OnlyV6")
    FavorV4 => logger.write_string("FavorV4")
    FavorV6 => logger.write_string("FavorV6")
    NoPreference => logger.write_string("NoPreference")
  }
}
