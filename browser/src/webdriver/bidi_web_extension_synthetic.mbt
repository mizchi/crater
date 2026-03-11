///|
/// Dispatch webExtension domain.
fn BidiProtocol::dispatch_web_extension(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "install" =>
      match self.resolve_web_extension_install(request.id, request.params) {
        Some(extension_id) => {
          self.send_success(
            request.id,
            Some(make_object({ "extension": Json::string(extension_id) })),
          )
          Ok(())
        }
        None => Ok(())
      }
    "uninstall" =>
      match self.resolve_web_extension_uninstall(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    _ => {
      self.send_error(
        request.id,
        "unknown command",
        "Unknown method: " + request.method_name,
      )
      Ok(())
    }
  }
}

///|
fn BidiProtocol::resolve_web_extension_install(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> String? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  let extension_data = match
    get_map_field_with_alias(map, "extensionData", "extension_data") {
    Some(Object(extension_data)) => extension_data
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "extensionData must be an object",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "extensionData must be an object",
      )
      return None
    }
  }

  let data_type = match extension_data.get("type") {
    Some(String(data_type)) =>
      if data_type == "base64" ||
        data_type == "path" ||
        data_type == "archivePath" {
        data_type
      } else {
        self.send_error(
          request_id, "invalid argument", "extensionData.type is invalid",
        )
        return None
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "extensionData.type must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "extensionData.type is required",
      )
      return None
    }
  }

  match data_type {
    "base64" =>
      match extension_data.get("value") {
        Some(String(encoded_value)) =>
          if encoded_value == "" {
            self.send_error(
              request_id, "invalid web extension", "Invalid web extension payload",
            )
            None
          } else if not(js_is_valid_web_extension_base64(encoded_value)) {
            self.send_error(
              request_id, "unknown error", "Unable to decode base64 extension payload",
            )
            None
          } else {
            let decoded = decode_base64(encoded_value)
            if decoded == "" {
              self.send_error(
                request_id, "unknown error", "Unable to decode base64 extension payload",
              )
              None
            } else if not(is_valid_web_extension_archive_payload(decoded)) {
              self.send_error(
                request_id, "invalid web extension", "Invalid web extension payload",
              )
              None
            } else {
              Some(self.install_web_extension_entry("base64"))
            }
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "extensionData.value must be a string",
          )
          None
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "extensionData.value is required",
          )
          None
        }
      }
    "path" =>
      match extension_data.get("path") {
        Some(String(extension_path)) =>
          match
            self.validate_web_extension_path_value(
              request_id, data_type, extension_path,
            ) {
            Some(kind) => Some(self.install_web_extension_entry(kind))
            None => None
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "extensionData.path must be a string",
          )
          None
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "extensionData.path is required",
          )
          None
        }
      }
    "archivePath" =>
      match extension_data.get("path") {
        Some(String(extension_path)) =>
          match
            self.validate_web_extension_path_value(
              request_id, data_type, extension_path,
            ) {
            Some(kind) => Some(self.install_web_extension_entry(kind))
            None => None
          }
        Some(_) => {
          self.send_error(
            request_id, "invalid argument", "extensionData.path must be a string",
          )
          None
        }
        None => {
          self.send_error(
            request_id, "invalid argument", "extensionData.path is required",
          )
          None
        }
      }
    _ => None
  }
}

///|
fn BidiProtocol::validate_web_extension_path_value(
  self : BidiProtocol,
  request_id : Int,
  data_type : String,
  extension_path : String,
) -> String? {
  if extension_path == "" {
    self.send_error(
      request_id, "unknown error", "Unable to read extension path",
    )
    return None
  }

  if extension_path.contains("/invalid") || extension_path.contains("\\invalid") {
    self.send_error(
      request_id, "invalid web extension", "Invalid web extension payload",
    )
    return None
  }

  let path_kind = js_web_extension_path_kind(extension_path)
  match data_type {
    "path" =>
      if path_kind != "dir" {
        if path_kind == "file" {
          self.send_error(
            request_id, "invalid web extension", "Invalid web extension payload",
          )
        } else {
          self.send_error(
            request_id, "unknown error", "Unable to read extension path",
          )
        }
        None
      } else if not(js_web_extension_dir_has_manifest(extension_path)) {
        self.send_error(
          request_id, "invalid web extension", "Invalid web extension payload",
        )
        None
      } else {
        Some("path")
      }
    "archivePath" =>
      if path_kind != "file" {
        self.send_error(
          request_id, "unknown error", "Unable to read extension path",
        )
        None
      } else if not(js_web_extension_archive_is_valid(extension_path)) {
        self.send_error(
          request_id, "invalid web extension", "Invalid web extension payload",
        )
        None
      } else {
        Some("archivePath")
      }
    _ => None
  }
}

///|
fn BidiProtocol::install_web_extension_entry(
  self : BidiProtocol,
  source_kind : String,
) -> String {
  let extension_id = "web-extension-" + self.next_web_extension_id.to_string()
  self.next_web_extension_id += 1
  self.installed_web_extensions[extension_id] = source_kind
  extension_id
}

///|
fn BidiProtocol::resolve_web_extension_uninstall(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Unit? {
  let map = match params {
    Some(Object(map)) => map
    _ => {
      self.send_error(
        request_id, "invalid argument", "params must be an object",
      )
      return None
    }
  }

  match map.get("extension") {
    Some(String(extension_id)) =>
      if extension_id == "" ||
        not(self.installed_web_extensions.contains(extension_id)) {
        self.send_error(
          request_id,
          "no such web extension",
          "Unknown web extension: " + extension_id,
        )
        None
      } else {
        self.installed_web_extensions.remove(extension_id)
        Some(())
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "extension must be a string",
      )
      None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing extension")
      None
    }
  }
}

///|
fn is_valid_web_extension_archive_payload(decoded : String) -> Bool {
  decoded.has_prefix("Cr24") || decoded.has_prefix("PK")
}

///|
extern "js" fn js_is_valid_web_extension_base64(value : String) -> Bool =
  #| (value) => {
  #|   try {
  #|     const normalized = String(value).replace(/\s+/g, "");
  #|     if (normalized.length === 0 || normalized.length % 4 !== 0) return false;
  #|     if (!/^[A-Za-z0-9+/]+={0,2}$/.test(normalized)) return false;
  #|     return btoa(atob(normalized)) === normalized;
  #|   } catch (_) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn js_web_extension_path_kind(path : String) -> String =
  #| (path) => {
  #|   try {
  #|     const stat = Deno.statSync(String(path));
  #|     if (stat && stat.isDirectory) return "dir";
  #|     if (stat && stat.isFile) return "file";
  #|     return "other";
  #|   } catch (_) {
  #|     return "missing";
  #|   }
  #| }

///|
extern "js" fn js_web_extension_dir_has_manifest(path : String) -> Bool =
  #| (path) => {
  #|   try {
  #|     const manifestPath = String(path).replace(/[\\\/]+$/, "") + "/manifest.json";
  #|     const stat = Deno.statSync(manifestPath);
  #|     return !!(stat && stat.isFile);
  #|   } catch (_) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn js_web_extension_archive_is_valid(path : String) -> Bool =
  #| (path) => {
  #|   try {
  #|     const bytes = Deno.readFileSync(String(path));
  #|     if (!bytes || bytes.length < 2) return false;
  #|     const magic = String.fromCharCode(...bytes.slice(0, 4));
  #|     return magic === "Cr24" || magic.startsWith("PK");
  #|   } catch (_) {
  #|     return false;
  #|   }
  #| }
