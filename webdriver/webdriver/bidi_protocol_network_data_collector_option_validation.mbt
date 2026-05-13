///|
/// Validate the `dataTypes` option for network.addDataCollector.
fn BidiProtocol::validate_network_data_collector_data_types(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
) -> Json? {
  let raw_data_types = match
    get_map_field_with_alias(map, "dataTypes", "data_types") {
    Some(raw) => raw
    None => {
      self.send_error(request_id, "invalid argument", "Missing dataTypes")
      return None
    }
  }
  let data_types : Array[Json] = []
  match raw_data_types {
    Array(items) =>
      if items.length() == 0 {
        self.send_error(
          request_id, "invalid argument", "dataTypes must not be an empty array",
        )
        return None
      } else {
        for item in items {
          match item {
            String(name) =>
              if name == "request" || name == "response" {
                data_types.push(Json::string(name))
              } else {
                self.send_error(
                  request_id, "invalid argument", "dataTypes entry is invalid",
                )
                return None
              }
            _ => {
              self.send_error(
                request_id, "invalid argument", "dataTypes entries must be strings",
              )
              return None
            }
          }
        }
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "dataTypes must be an array",
      )
      return None
    }
  }
  Some(Json::array(data_types))
}

///|
/// Validate the `maxEncodedDataSize` option for network.addDataCollector.
fn BidiProtocol::validate_network_data_collector_max_encoded_data_size(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
) -> Json? {
  let raw_max_encoded_data_size = match
    get_map_field_with_alias(map, "maxEncodedDataSize", "max_encoded_data_size") {
    Some(raw) => raw
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing maxEncodedDataSize",
      )
      return None
    }
  }
  let max_encoded_data_size = match raw_max_encoded_data_size {
    Number(n, ..) => {
      let as_int = n.to_int()
      if as_int.to_double() != n || as_int <= 0 {
        self.send_error(
          request_id, "invalid argument", "maxEncodedDataSize must be a positive integer",
        )
        return None
      }
      if as_int > 1000000000 {
        self.send_error(
          request_id, "invalid argument", "maxEncodedDataSize exceeds the implementation limit",
        )
        return None
      }
      as_int
    }
    _ => {
      self.send_error(
        request_id, "invalid argument", "maxEncodedDataSize must be a positive integer",
      )
      return None
    }
  }
  Some(Json::number(max_encoded_data_size.to_double()))
}

///|
/// Validate the `collectorType` option for network.addDataCollector.
fn BidiProtocol::validate_network_data_collector_type(
  self : BidiProtocol,
  request_id : Int,
  map : Map[String, Json],
) -> Json? {
  let collector_type = match
    get_map_field_with_alias(map, "collectorType", "collector_type") {
    Some(String(name)) =>
      if name == "blob" || name == "base64" {
        name
      } else {
        self.send_error(
          request_id, "invalid argument", "collectorType is invalid",
        )
        return None
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "collectorType must be a string",
      )
      return None
    }
    None => "blob"
  }
  Some(Json::string(collector_type))
}
