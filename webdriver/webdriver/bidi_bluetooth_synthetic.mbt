///|
/// Dispatch bluetooth domain.
fn BidiProtocol::dispatch_bluetooth(
  self : BidiProtocol,
  request : BidiRequest,
  action : String,
) -> Result[Unit, String] {
  match action {
    "simulateAdapter" =>
      match
        self.resolve_bluetooth_simulate_adapter(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "disableSimulation" =>
      match
        self.resolve_bluetooth_disable_simulation(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulatePreconnectedPeripheral" =>
      match
        self.resolve_bluetooth_simulate_preconnected_peripheral(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "handleRequestDevicePrompt" =>
      match
        self.resolve_bluetooth_handle_request_device_prompt(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateGATTConnectionResponse" =>
      match
        self.resolve_bluetooth_simulate_gatt_connection_response(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateGATTDisconnection" =>
      match
        self.resolve_bluetooth_simulate_gatt_disconnection(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateService" =>
      match
        self.resolve_bluetooth_simulate_service(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateCharacteristic" =>
      match
        self.resolve_bluetooth_simulate_characteristic(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateCharacteristicResponse" =>
      match
        self.resolve_bluetooth_simulate_characteristic_response(
          request.id,
          request.params,
        ) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateDescriptor" =>
      match
        self.resolve_bluetooth_simulate_descriptor(request.id, request.params) {
        Some(_) => {
          self.send_success(request.id, Some(make_object({})))
          Ok(())
        }
        None => Ok(())
      }
    "simulateDescriptorResponse" =>
      match
        self.resolve_bluetooth_simulate_descriptor_response(
          request.id,
          request.params,
        ) {
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
fn BidiProtocol::resolve_bluetooth_simulate_adapter(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let state = match get_param_raw(params, "state") {
    Some(String(state)) =>
      if state == "absent" || state == "powered-off" || state == "powered-on" {
        state
      } else {
        self.send_error(request_id, "invalid argument", "state is invalid")
        return None
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "state must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing state")
      return None
    }
  }
  self.bluetooth_adapter_state_by_context[ctx_id] = state
  self.bluetooth_simulation_disabled_by_context.remove(ctx_id)
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_disable_simulation(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  self.bluetooth_simulation_disabled_by_context[ctx_id] = true
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_preconnected_peripheral(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  if self.bluetooth_simulation_disabled_by_context.get(ctx_id).unwrap_or(false) {
    self.send_error(
      request_id, "unknown error", "Bluetooth simulation is disabled for this context",
    )
    return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  let name = match get_param_raw(params, "name") {
    Some(String(name)) => name
    Some(_) => {
      self.send_error(request_id, "invalid argument", "name must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing name")
      return None
    }
  }
  let manufacturer_data = match
    self.validate_bluetooth_manufacturer_data(request_id, params) {
    Some(data) => data
    None => return None
  }
  let known_service_uuids = match
    self.validate_bluetooth_known_service_uuids(request_id, params) {
    Some(uuids) => uuids
    None => return None
  }
  let device = make_object({
    "address": Json::string(address),
    "name": Json::string(name),
    "manufacturerData": Json::array(manufacturer_data),
    "knownServiceUuids": Json::array(known_service_uuids),
  })
  let devices = self.bluetooth_preconnected_devices_by_context
    .get(ctx_id)
    .unwrap_or([])
  self.bluetooth_preconnected_devices_by_context[ctx_id] = upsert_bluetooth_device(
    devices, device, address,
  )
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_handle_request_device_prompt(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let prompt_id = match get_param_raw(params, "prompt") {
    Some(String(prompt_id)) => prompt_id
    Some(_) => {
      self.send_error(request_id, "invalid argument", "prompt must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing prompt")
      return None
    }
  }
  let accept = match get_param_raw(params, "accept") {
    Some(True) => true
    Some(False) => false
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "accept must be a boolean",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing accept")
      return None
    }
  }
  match self.bluetooth_pending_prompt_id.get(ctx_id) {
    Some(current_prompt_id) if current_prompt_id == prompt_id => ()
    _ => {
      self.send_error(
        request_id, "invalid argument", "Unknown bluetooth prompt",
      )
      return None
    }
  }
  let selected_address = match get_param_raw(params, "device") {
    Some(String(device_id)) => device_id
    Some(_) => {
      self.send_error(request_id, "invalid argument", "device must be a string")
      return None
    }
    None =>
      self.bluetooth_pending_prompt_device_address.get(ctx_id).unwrap_or("")
  }
  let selected_name = self.bluetooth_pending_prompt_device_name
    .get(ctx_id)
    .unwrap_or("")
  let pending_request_id = self.bluetooth_pending_prompt_request.get(ctx_id)
  let pending_realm = self.bluetooth_pending_prompt_realm.get(ctx_id)
  let unwrap_result = self.bluetooth_pending_prompt_unwrap_result
    .get(ctx_id)
    .unwrap_or(false)
  self.bluetooth_pending_prompt_request.remove(ctx_id)
  self.bluetooth_pending_prompt_realm.remove(ctx_id)
  self.bluetooth_pending_prompt_unwrap_result.remove(ctx_id)
  self.bluetooth_pending_prompt_id.remove(ctx_id)
  self.bluetooth_pending_prompt_device_address.remove(ctx_id)
  self.bluetooth_pending_prompt_device_name.remove(ctx_id)

  match (pending_request_id, pending_realm) {
    (Some(pending_request_id), Some(realm_id)) =>
      if accept {
        let device = self
          .find_bluetooth_device_descriptor(ctx_id, selected_address)
          .unwrap_or(
            make_object({
              "address": Json::string(selected_address),
              "name": Json::string(selected_name),
              "manufacturerData": Json::array([]),
              "knownServiceUuids": Json::array([]),
            }),
          )
        let granted_devices = self.bluetooth_granted_devices_by_context
          .get(ctx_id)
          .unwrap_or([])
        self.bluetooth_granted_devices_by_context[ctx_id] = upsert_bluetooth_device(
          granted_devices, device, selected_address,
        )
        self.send_script_remote_value_response(
          pending_request_id,
          realm_id,
          make_bluetooth_requested_device_remote_value(
            selected_address, selected_name,
          ),
          unwrap_result,
        )
      } else {
        self.send_error(
          pending_request_id, "unknown error", "Bluetooth request device canceled",
        )
      }
    _ => ()
  }
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_gatt_connection_response(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  let code = match get_param_raw(params, "code") {
    Some(Number(code, ..)) if code.floor() == code => code.to_int()
    Some(_) => {
      self.send_error(request_id, "invalid argument", "code must be an integer")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing code")
      return None
    }
  }
  let connected = code == 0
  self.bluetooth_gatt_connected_by_scope[bluetooth_scope_key(ctx_id, address)] = connected
  let pending_request_id = self.bluetooth_pending_gatt_request.get(ctx_id)
  let pending_realm = self.bluetooth_pending_gatt_realm.get(ctx_id)
  let unwrap_result = self.bluetooth_pending_gatt_unwrap_result
    .get(ctx_id)
    .unwrap_or(false)
  let pending_address = self.bluetooth_pending_gatt_address
    .get(ctx_id)
    .unwrap_or("")
  let response_kind = self.bluetooth_pending_gatt_response_kind
    .get(ctx_id)
    .unwrap_or("undefined")
  self.bluetooth_pending_gatt_request.remove(ctx_id)
  self.bluetooth_pending_gatt_realm.remove(ctx_id)
  self.bluetooth_pending_gatt_unwrap_result.remove(ctx_id)
  self.bluetooth_pending_gatt_address.remove(ctx_id)
  self.bluetooth_pending_gatt_response_kind.remove(ctx_id)
  match (pending_request_id, pending_realm) {
    (Some(pending_request_id), Some(realm_id)) if pending_address == address =>
      if response_kind == "connected" {
        self.send_script_remote_value_response(
          pending_request_id,
          realm_id,
          make_object({
            "type": Json::string("boolean"),
            "value": Json::boolean(connected),
          }),
          unwrap_result,
        )
      } else {
        self.send_script_undefined_response(
          pending_request_id, realm_id, unwrap_result,
        )
      }
    _ => ()
  }
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_gatt_disconnection(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  self.bluetooth_gatt_connected_by_scope[bluetooth_scope_key(ctx_id, address)] = false
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_service(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  if !self.has_bluetooth_device_descriptor(ctx_id, address) {
    self.send_error(
      request_id, "invalid argument", "Unknown bluetooth device address",
    )
    return None
  }
  let uuid = match get_param_raw(params, "uuid") {
    Some(String(uuid)) => uuid
    Some(_) => {
      self.send_error(request_id, "invalid argument", "uuid must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing uuid")
      return None
    }
  }
  let action_type = match get_param_raw(params, "type") {
    Some(String(action_type)) =>
      if action_type == "add" || action_type == "remove" {
        action_type
      } else {
        self.send_error(request_id, "invalid argument", "type is invalid")
        return None
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing type")
      return None
    }
  }
  let scope_key = bluetooth_scope_key(ctx_id, address)
  let services = self.bluetooth_services_by_scope.get(scope_key).unwrap_or([])
  if action_type == "add" {
    if array_contains(services, uuid) {
      self.send_error(request_id, "invalid argument", "Service already exists")
      return None
    }
    let next_services : Array[String] = []
    for service_uuid in services {
      next_services.push(service_uuid)
    }
    next_services.push(uuid)
    self.bluetooth_services_by_scope[scope_key] = next_services
    return Some(true)
  }
  if !array_contains(services, uuid) {
    self.send_error(request_id, "invalid argument", "Service does not exist")
    return None
  }
  let next_services : Array[String] = []
  for service_uuid in services {
    if service_uuid != uuid {
      next_services.push(service_uuid)
    }
  }
  self.bluetooth_services_by_scope[scope_key] = next_services
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_characteristic(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  if !self.has_bluetooth_device_descriptor(ctx_id, address) {
    self.send_error(
      request_id, "invalid argument", "Unknown bluetooth device address",
    )
    return None
  }
  let service_uuid = match
    get_param_raw_with_alias(params, "serviceUuid", "service_uuid") {
    Some(String(service_uuid)) => service_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serviceUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing serviceUuid")
      return None
    }
  }
  let service_scope_key = bluetooth_scope_key(ctx_id, address)
  let services = self.bluetooth_services_by_scope
    .get(service_scope_key)
    .unwrap_or([])
  if !array_contains(services, service_uuid) {
    self.send_error(request_id, "invalid argument", "Unknown service uuid")
    return None
  }
  let characteristic_uuid = match
    get_param_raw_with_alias(
      params, "characteristicUuid", "characteristic_uuid",
    ) {
    Some(String(characteristic_uuid)) => characteristic_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "characteristicUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing characteristicUuid",
      )
      return None
    }
  }
  let action_type = match get_param_raw(params, "type") {
    Some(String(action_type)) =>
      if action_type == "add" || action_type == "remove" {
        action_type
      } else {
        self.send_error(request_id, "invalid argument", "type is invalid")
        return None
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing type")
      return None
    }
  }
  let characteristic_scope_key = bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  )
  let existing = self.bluetooth_characteristics_by_scope.get(
    characteristic_scope_key,
  )
  if action_type == "add" {
    let properties = match
      self.validate_bluetooth_characteristic_properties(request_id, params) {
      Some(properties) => properties
      None => return None
    }
    if existing != None {
      self.send_error(
        request_id, "invalid argument", "Characteristic already exists",
      )
      return None
    }
    self.bluetooth_characteristics_by_scope[characteristic_scope_key] = properties
    return Some(true)
  }
  match
    get_param_raw_with_alias(
      params, "characteristicProperties", "characteristic_properties",
    ) {
    Some(Null) | None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "characteristicProperties must be absent for remove",
      )
      return None
    }
  }
  if existing == None {
    self.send_error(
      request_id, "invalid argument", "Characteristic does not exist",
    )
    return None
  }
  self.bluetooth_characteristics_by_scope.remove(characteristic_scope_key)
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_characteristic_response(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  if !self.has_bluetooth_device_descriptor(ctx_id, address) {
    self.send_error(
      request_id, "invalid argument", "Unknown bluetooth device address",
    )
    return None
  }
  let service_uuid = match
    get_param_raw_with_alias(params, "serviceUuid", "service_uuid") {
    Some(String(service_uuid)) => service_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serviceUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing serviceUuid")
      return None
    }
  }
  let services = self.bluetooth_services_by_scope
    .get(bluetooth_scope_key(ctx_id, address))
    .unwrap_or([])
  if !array_contains(services, service_uuid) {
    self.send_error(request_id, "invalid argument", "Unknown service uuid")
    return None
  }
  let characteristic_uuid = match
    get_param_raw_with_alias(
      params, "characteristicUuid", "characteristic_uuid",
    ) {
    Some(String(characteristic_uuid)) => characteristic_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "characteristicUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing characteristicUuid",
      )
      return None
    }
  }
  let characteristic_scope_key = bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  )
  if self.bluetooth_characteristics_by_scope.get(characteristic_scope_key) ==
    None {
    self.send_error(
      request_id, "invalid argument", "Unknown characteristic uuid",
    )
    return None
  }
  let response_type = match get_param_raw(params, "type") {
    Some(String(response_type)) =>
      if response_type == "write" ||
        response_type == "read" ||
        response_type == "subscribe-to-notifications" ||
        response_type == "unsubscribe-from-notifications" {
        response_type
      } else {
        self.send_error(request_id, "invalid argument", "type is invalid")
        return None
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing type")
      return None
    }
  }
  let code = match get_param_raw(params, "code") {
    Some(Number(code, ..)) if code.floor() == code => code.to_int()
    Some(_) => {
      self.send_error(request_id, "invalid argument", "code must be an integer")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing code")
      return None
    }
  }
  let data = match
    self.validate_bluetooth_response_data(
      request_id,
      params,
      response_type == "read",
    ) {
    Some(data) => data
    None => return None
  }
  let pending_request_id = self.bluetooth_pending_characteristic_request.get(
    ctx_id,
  )
  let pending_realm = self.bluetooth_pending_characteristic_realm.get(ctx_id)
  let unwrap_result = self.bluetooth_pending_characteristic_unwrap_result
    .get(ctx_id)
    .unwrap_or(false)
  let pending_address = self.bluetooth_pending_characteristic_address
    .get(ctx_id)
    .unwrap_or("")
  let pending_service_uuid = self.bluetooth_pending_characteristic_service_uuid
    .get(ctx_id)
    .unwrap_or("")
  let pending_characteristic_uuid = self.bluetooth_pending_characteristic_uuid
    .get(ctx_id)
    .unwrap_or("")
  let pending_type = self.bluetooth_pending_characteristic_type
    .get(ctx_id)
    .unwrap_or("")
  self.clear_pending_bluetooth_characteristic(ctx_id)
  match (pending_request_id, pending_realm) {
    (Some(pending_request_id), Some(realm_id)) =>
      if pending_address != address ||
        pending_service_uuid != service_uuid ||
        pending_characteristic_uuid != characteristic_uuid ||
        pending_type != response_type {
        self.send_error(
          request_id, "invalid argument", "No pending characteristic response",
        )
        None
      } else {
        if code == 0 {
          if response_type == "read" {
            self.send_script_remote_value_response(
              pending_request_id,
              realm_id,
              make_bluetooth_byte_remote_value(data),
              unwrap_result,
            )
          } else {
            self.send_script_undefined_response(
              pending_request_id, realm_id, unwrap_result,
            )
          }
        } else {
          self.send_error(
            pending_request_id, "unknown error", "Bluetooth characteristic request failed",
          )
        }
        Some(true)
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "No pending characteristic response",
      )
      None
    }
  }
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_descriptor(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  if !self.has_bluetooth_device_descriptor(ctx_id, address) {
    self.send_error(
      request_id, "invalid argument", "Unknown bluetooth device address",
    )
    return None
  }
  let service_uuid = match
    get_param_raw_with_alias(params, "serviceUuid", "service_uuid") {
    Some(String(service_uuid)) => service_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serviceUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing serviceUuid")
      return None
    }
  }
  let services = self.bluetooth_services_by_scope
    .get(bluetooth_scope_key(ctx_id, address))
    .unwrap_or([])
  if !array_contains(services, service_uuid) {
    self.send_error(request_id, "invalid argument", "Unknown service uuid")
    return None
  }
  let characteristic_uuid = match
    get_param_raw_with_alias(
      params, "characteristicUuid", "characteristic_uuid",
    ) {
    Some(String(characteristic_uuid)) => characteristic_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "characteristicUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing characteristicUuid",
      )
      return None
    }
  }
  let characteristic_scope_key = bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  )
  if self.bluetooth_characteristics_by_scope.get(characteristic_scope_key) ==
    None {
    self.send_error(
      request_id, "invalid argument", "Unknown characteristic uuid",
    )
    return None
  }
  let descriptor_uuid = match
    get_param_raw_with_alias(params, "descriptorUuid", "descriptor_uuid") {
    Some(String(descriptor_uuid)) => descriptor_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "descriptorUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing descriptorUuid")
      return None
    }
  }
  let action_type = match get_param_raw(params, "type") {
    Some(String(action_type)) =>
      if action_type == "add" || action_type == "remove" {
        action_type
      } else {
        self.send_error(request_id, "invalid argument", "type is invalid")
        return None
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing type")
      return None
    }
  }
  let descriptor_scope_key = bluetooth_descriptor_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid, descriptor_uuid,
  )
  let existing = self.bluetooth_descriptors_by_scope.get(descriptor_scope_key)
  if action_type == "add" {
    if existing != None {
      self.send_error(
        request_id, "invalid argument", "Descriptor already exists",
      )
      return None
    }
    self.bluetooth_descriptors_by_scope[descriptor_scope_key] = true
    return Some(true)
  }
  if existing == None {
    self.send_error(request_id, "invalid argument", "Descriptor does not exist")
    return None
  }
  self.bluetooth_descriptors_by_scope.remove(descriptor_scope_key)
  Some(true)
}

///|
fn BidiProtocol::resolve_bluetooth_simulate_descriptor_response(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Bool? {
  let ctx_id = match self.validate_input_context(request_id, params) {
    Some(ctx_id) => ctx_id
    None => return None
  }
  let address = match get_param_raw(params, "address") {
    Some(String(address)) => address
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "address must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing address")
      return None
    }
  }
  if !self.has_bluetooth_device_descriptor(ctx_id, address) {
    self.send_error(
      request_id, "invalid argument", "Unknown bluetooth device address",
    )
    return None
  }
  let service_uuid = match
    get_param_raw_with_alias(params, "serviceUuid", "service_uuid") {
    Some(String(service_uuid)) => service_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "serviceUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing serviceUuid")
      return None
    }
  }
  let services = self.bluetooth_services_by_scope
    .get(bluetooth_scope_key(ctx_id, address))
    .unwrap_or([])
  if !array_contains(services, service_uuid) {
    self.send_error(request_id, "invalid argument", "Unknown service uuid")
    return None
  }
  let characteristic_uuid = match
    get_param_raw_with_alias(
      params, "characteristicUuid", "characteristic_uuid",
    ) {
    Some(String(characteristic_uuid)) => characteristic_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "characteristicUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing characteristicUuid",
      )
      return None
    }
  }
  let descriptor_uuid = match
    get_param_raw_with_alias(params, "descriptorUuid", "descriptor_uuid") {
    Some(String(descriptor_uuid)) => descriptor_uuid
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "descriptorUuid must be a string",
      )
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing descriptorUuid")
      return None
    }
  }
  let descriptor_scope_key = bluetooth_descriptor_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid, descriptor_uuid,
  )
  if self.bluetooth_descriptors_by_scope.get(descriptor_scope_key) == None {
    self.send_error(request_id, "invalid argument", "Unknown descriptor uuid")
    return None
  }
  let response_type = match get_param_raw(params, "type") {
    Some(String(response_type)) =>
      if response_type == "write" || response_type == "read" {
        response_type
      } else {
        self.send_error(request_id, "invalid argument", "type is invalid")
        return None
      }
    Some(_) => {
      self.send_error(request_id, "invalid argument", "type must be a string")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing type")
      return None
    }
  }
  let code = match get_param_raw(params, "code") {
    Some(Number(code, ..)) if code.floor() == code => code.to_int()
    Some(_) => {
      self.send_error(request_id, "invalid argument", "code must be an integer")
      return None
    }
    None => {
      self.send_error(request_id, "invalid argument", "Missing code")
      return None
    }
  }
  let data = match
    self.validate_bluetooth_response_data(
      request_id,
      params,
      response_type == "read",
    ) {
    Some(data) => data
    None => return None
  }
  let pending_request_id = self.bluetooth_pending_descriptor_request.get(ctx_id)
  let pending_realm = self.bluetooth_pending_descriptor_realm.get(ctx_id)
  let unwrap_result = self.bluetooth_pending_descriptor_unwrap_result
    .get(ctx_id)
    .unwrap_or(false)
  let pending_address = self.bluetooth_pending_descriptor_address
    .get(ctx_id)
    .unwrap_or("")
  let pending_service_uuid = self.bluetooth_pending_descriptor_service_uuid
    .get(ctx_id)
    .unwrap_or("")
  let pending_characteristic_uuid = self.bluetooth_pending_descriptor_characteristic_uuid
    .get(ctx_id)
    .unwrap_or("")
  let pending_descriptor_uuid = self.bluetooth_pending_descriptor_uuid
    .get(ctx_id)
    .unwrap_or("")
  let pending_type = self.bluetooth_pending_descriptor_type
    .get(ctx_id)
    .unwrap_or("")
  self.clear_pending_bluetooth_descriptor(ctx_id)
  match (pending_request_id, pending_realm) {
    (Some(pending_request_id), Some(realm_id)) =>
      if pending_address != address ||
        pending_service_uuid != service_uuid ||
        pending_characteristic_uuid != characteristic_uuid ||
        pending_descriptor_uuid != descriptor_uuid ||
        pending_type != response_type {
        self.send_error(
          request_id, "invalid argument", "No pending descriptor response",
        )
        None
      } else {
        if code == 0 {
          if response_type == "read" {
            self.send_script_remote_value_response(
              pending_request_id,
              realm_id,
              make_bluetooth_byte_remote_value(data),
              unwrap_result,
            )
          } else {
            self.send_script_undefined_response(
              pending_request_id, realm_id, unwrap_result,
            )
          }
        } else {
          self.send_error(
            pending_request_id, "unknown error", "Bluetooth descriptor request failed",
          )
        }
        Some(true)
      }
    _ => {
      self.send_error(
        request_id, "invalid argument", "No pending descriptor response",
      )
      None
    }
  }
}

///|
fn BidiProtocol::try_handle_synthetic_bluetooth_availability_eval(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  expression : String,
  unwrap_result : Bool,
) -> Bool {
  if expression.trim().to_string() != "navigator.bluetooth.getAvailability()" {
    return false
  }
  let adapter_state = self.bluetooth_adapter_state_by_context
    .get(ctx_id)
    .unwrap_or("absent")
  let simulation_disabled = self.bluetooth_simulation_disabled_by_context
    .get(ctx_id)
    .unwrap_or(false)
  let available = !simulation_disabled &&
    (adapter_state == "powered-off" || adapter_state == "powered-on")
  self.send_script_remote_value_response(
    request_id,
    realm_id,
    make_object({
      "type": Json::string("boolean"),
      "value": Json::boolean(available),
    }),
    unwrap_result,
  )
  true
}

///|
fn BidiProtocol::try_handle_synthetic_bluetooth_request_device_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  params : Json?,
  unwrap_result : Bool,
) -> Bool {
  if !function_declaration.contains("navigator.bluetooth.requestDevice(") {
    return false
  }
  let devices = self.bluetooth_preconnected_devices_by_context
    .get(ctx_id)
    .unwrap_or([])
  if devices.length() == 0 {
    self.send_error(
      request_id, "unknown error", "No simulated bluetooth device is available",
    )
    return true
  }
  let expected_name = extract_first_bluetooth_string_argument(params)
  let selected = find_bluetooth_device_for_name(devices, expected_name)
  let address = bluetooth_device_field_string(selected, "address").unwrap_or("")
  let name = bluetooth_device_field_string(selected, "name").unwrap_or("")
  if address == "" {
    self.send_error(
      request_id, "unknown error", "Simulated bluetooth device address is missing",
    )
    return true
  }
  let prompt_id = "bluetooth-prompt-" +
    self.next_bluetooth_prompt_id.to_string()
  self.next_bluetooth_prompt_id += 1
  self.bluetooth_pending_prompt_request[ctx_id] = request_id
  self.bluetooth_pending_prompt_realm[ctx_id] = realm_id
  self.bluetooth_pending_prompt_unwrap_result[ctx_id] = unwrap_result
  self.bluetooth_pending_prompt_id[ctx_id] = prompt_id
  self.bluetooth_pending_prompt_device_address[ctx_id] = address
  self.bluetooth_pending_prompt_device_name[ctx_id] = name
  self.emit_bluetooth_request_device_prompt_updated(ctx_id, prompt_id, address)
  true
}

///|
fn BidiProtocol::try_handle_synthetic_bluetooth_gatt_call(
  self : BidiProtocol,
  request_id : Int,
  ctx_id : String,
  realm_id : String,
  function_declaration : String,
  unwrap_result : Bool,
) -> Bool {
  if !function_declaration.contains("navigator.bluetooth.getDevices()") {
    return false
  }
  let granted_devices = self.bluetooth_granted_devices_by_context
    .get(ctx_id)
    .unwrap_or([])
  if granted_devices.length() == 0 {
    self.send_error(
      request_id, "unknown error", "No granted bluetooth device is available",
    )
    return true
  }
  let address = bluetooth_device_field_string(granted_devices[0], "address").unwrap_or(
    "",
  )
  if address == "" {
    self.send_error(
      request_id, "unknown error", "Granted bluetooth device address is missing",
    )
    return true
  }
  let trimmed = function_declaration.trim().to_string()
  if trimmed.contains("await device.gatt.connect();") {
    let response_kind = if trimmed.contains("return device.gatt.connected;") {
      "connected"
    } else {
      "undefined"
    }
    self.bluetooth_pending_gatt_request[ctx_id] = request_id
    self.bluetooth_pending_gatt_realm[ctx_id] = realm_id
    self.bluetooth_pending_gatt_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_gatt_address[ctx_id] = address
    self.bluetooth_pending_gatt_response_kind[ctx_id] = response_kind
    self.emit_bluetooth_gatt_connection_attempted(ctx_id, address)
    return true
  }
  if trimmed.contains("return device.gatt.connected;") {
    let connected = self.bluetooth_gatt_connected_by_scope
      .get(bluetooth_scope_key(ctx_id, address))
      .unwrap_or(false)
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("boolean"),
        "value": Json::boolean(connected),
      }),
      unwrap_result,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryServices()") &&
    trimmed.contains("return services.map(s => s.uuid)") {
    let services = self.bluetooth_services_by_scope
      .get(bluetooth_scope_key(ctx_id, address))
      .unwrap_or([])
    let items : Array[Json] = []
    for service_uuid in services {
      items.push(
        make_object({
          "type": Json::string("string"),
          "value": Json::string(service_uuid),
        }),
      )
    }
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({ "type": Json::string("array"), "value": Json::array(items) }),
      unwrap_result,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristics()") &&
    trimmed.contains("return characteristics.map(c => c.uuid)") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let prefix = bluetooth_characteristic_prefix_key(
      ctx_id, address, service_uuid,
    )
    let items : Array[Json] = []
    for key, properties in self.bluetooth_characteristics_by_scope {
      ignore(properties)
      if key.has_prefix(prefix) {
        let characteristic_uuid = key.unsafe_substring(
          start=prefix.length(),
          end=key.length(),
        )
        if characteristic_uuid != "" {
          items.push(
            make_object({
              "type": Json::string("string"),
              "value": Json::string(characteristic_uuid),
            }),
          )
        }
      }
    }
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({ "type": Json::string("array"), "value": Json::array(items) }),
      unwrap_result,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("characteristic.getDescriptors()") &&
    trimmed.contains("return descriptors.map(d => d.uuid)") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    let prefix = bluetooth_descriptor_prefix_key(
      ctx_id, address, service_uuid, characteristic_uuid,
    )
    let items : Array[Json] = []
    for key, exists in self.bluetooth_descriptors_by_scope {
      if exists && key.has_prefix(prefix) {
        let descriptor_uuid = key.unsafe_substring(
          start=prefix.length(),
          end=key.length(),
        )
        if descriptor_uuid != "" {
          items.push(
            make_object({
              "type": Json::string("string"),
              "value": Json::string(descriptor_uuid),
            }),
          )
        }
      }
    }
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({ "type": Json::string("array"), "value": Json::array(items) }),
      unwrap_result,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristic(") &&
    trimmed.contains("writeValueWithoutResponse(") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    let data = extract_bluetooth_uint8_array_data(trimmed)
    self.bluetooth_pending_characteristic_request[ctx_id] = request_id
    self.bluetooth_pending_characteristic_realm[ctx_id] = realm_id
    self.bluetooth_pending_characteristic_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_characteristic_address[ctx_id] = address
    self.bluetooth_pending_characteristic_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_characteristic_type[ctx_id] = "write"
    self.emit_bluetooth_characteristic_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      "write-without-response",
      Some(Json::array(data)),
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristic(") &&
    trimmed.contains("writeValueWithResponse(") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    let data = extract_bluetooth_uint8_array_data(trimmed)
    self.bluetooth_pending_characteristic_request[ctx_id] = request_id
    self.bluetooth_pending_characteristic_realm[ctx_id] = realm_id
    self.bluetooth_pending_characteristic_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_characteristic_address[ctx_id] = address
    self.bluetooth_pending_characteristic_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_characteristic_type[ctx_id] = "write"
    self.emit_bluetooth_characteristic_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      "write-with-response",
      Some(Json::array(data)),
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristic(") &&
    trimmed.contains("const value = await characteristic.readValue();") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    self.bluetooth_pending_characteristic_request[ctx_id] = request_id
    self.bluetooth_pending_characteristic_realm[ctx_id] = realm_id
    self.bluetooth_pending_characteristic_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_characteristic_address[ctx_id] = address
    self.bluetooth_pending_characteristic_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_characteristic_type[ctx_id] = "read"
    self.emit_bluetooth_characteristic_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      "read",
      None,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristic(") &&
    trimmed.contains("startNotifications();") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    self.bluetooth_pending_characteristic_request[ctx_id] = request_id
    self.bluetooth_pending_characteristic_realm[ctx_id] = realm_id
    self.bluetooth_pending_characteristic_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_characteristic_address[ctx_id] = address
    self.bluetooth_pending_characteristic_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_characteristic_type[ctx_id] = "subscribe-to-notifications"
    self.emit_bluetooth_characteristic_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      "subscribe-to-notifications",
      None,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristic(") &&
    trimmed.contains("stopNotifications();") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    self.bluetooth_pending_characteristic_request[ctx_id] = request_id
    self.bluetooth_pending_characteristic_realm[ctx_id] = realm_id
    self.bluetooth_pending_characteristic_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_characteristic_address[ctx_id] = address
    self.bluetooth_pending_characteristic_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_characteristic_type[ctx_id] = "unsubscribe-from-notifications"
    self.emit_bluetooth_characteristic_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      "unsubscribe-from-notifications",
      None,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getDescriptor(") &&
    trimmed.contains("descriptor.writeValue(") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    let descriptor_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getDescriptor",
    )
    let data = extract_bluetooth_uint8_array_data(trimmed)
    self.bluetooth_pending_descriptor_request[ctx_id] = request_id
    self.bluetooth_pending_descriptor_realm[ctx_id] = realm_id
    self.bluetooth_pending_descriptor_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_descriptor_address[ctx_id] = address
    self.bluetooth_pending_descriptor_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_descriptor_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_descriptor_uuid[ctx_id] = descriptor_uuid
    self.bluetooth_pending_descriptor_type[ctx_id] = "write"
    self.emit_bluetooth_descriptor_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      descriptor_uuid,
      "write",
      Some(Json::array(data)),
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getDescriptor(") &&
    trimmed.contains("const value = await descriptor.readValue();") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    let descriptor_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getDescriptor",
    )
    self.bluetooth_pending_descriptor_request[ctx_id] = request_id
    self.bluetooth_pending_descriptor_realm[ctx_id] = realm_id
    self.bluetooth_pending_descriptor_unwrap_result[ctx_id] = unwrap_result
    self.bluetooth_pending_descriptor_address[ctx_id] = address
    self.bluetooth_pending_descriptor_service_uuid[ctx_id] = service_uuid
    self.bluetooth_pending_descriptor_characteristic_uuid[ctx_id] = characteristic_uuid
    self.bluetooth_pending_descriptor_uuid[ctx_id] = descriptor_uuid
    self.bluetooth_pending_descriptor_type[ctx_id] = "read"
    self.emit_bluetooth_descriptor_event_generated(
      ctx_id,
      address,
      service_uuid,
      characteristic_uuid,
      descriptor_uuid,
      "read",
      None,
    )
    return true
  }
  if trimmed.contains("device.gatt.getPrimaryService(") &&
    trimmed.contains("getCharacteristic(") &&
    trimmed.contains("return toPropertyStrings(characteristic.properties);") {
    let service_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getPrimaryService",
    )
    let characteristic_uuid = extract_bluetooth_call_string_argument(
      trimmed, "getCharacteristic",
    )
    let scope_key = bluetooth_characteristic_scope_key(
      ctx_id, address, service_uuid, characteristic_uuid,
    )
    let property_items : Array[Json] = []
    match self.bluetooth_characteristics_by_scope.get(scope_key) {
      Some(Object(map)) =>
        for key, value in map {
          match value {
            True =>
              property_items.push(
                make_object({
                  "type": Json::string("string"),
                  "value": Json::string(key),
                }),
              )
            _ => ()
          }
        }
      _ => ()
    }
    self.send_script_remote_value_response(
      request_id,
      realm_id,
      make_object({
        "type": Json::string("array"),
        "value": Json::array(property_items),
      }),
      unwrap_result,
    )
    return true
  }
  false
}

///|
fn BidiProtocol::emit_bluetooth_request_device_prompt_updated(
  self : BidiProtocol,
  ctx_id : String,
  prompt_id : String,
  address : String,
) -> Unit {
  let event_name = "bluetooth.requestDevicePromptUpdated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  self.outbox.push(
    Event({
      event_method: event_name,
      params: make_object({
        "context": Json::string(ctx_id),
        "prompt": Json::string(prompt_id),
        "devices": Json::array([
          make_object({ "id": Json::string(address), "name": Json::string("") }),
        ]),
      }),
    }),
  )
}

///|
fn BidiProtocol::emit_bluetooth_gatt_connection_attempted(
  self : BidiProtocol,
  ctx_id : String,
  address : String,
) -> Unit {
  let event_name = "bluetooth.gattConnectionAttempted"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  self.outbox.push(
    Event({
      event_method: event_name,
      params: make_object({
        "context": Json::string(ctx_id),
        "address": Json::string(address),
      }),
    }),
  )
}

///|
fn BidiProtocol::emit_bluetooth_characteristic_event_generated(
  self : BidiProtocol,
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
  event_type : String,
  data : Json?,
) -> Unit {
  let event_name = "bluetooth.characteristicEventGenerated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "address": Json::string(address),
    "serviceUuid": Json::string(service_uuid),
    "characteristicUuid": Json::string(characteristic_uuid),
    "type": Json::string(event_type),
  }
  match data {
    Some(data) => params["data"] = data
    None => ()
  }
  self.outbox.push(
    Event({ event_method: event_name, params: make_object(params) }),
  )
}

///|
fn BidiProtocol::emit_bluetooth_descriptor_event_generated(
  self : BidiProtocol,
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
  descriptor_uuid : String,
  event_type : String,
  data : Json?,
) -> Unit {
  let event_name = "bluetooth.descriptorEventGenerated"
  if !self.is_subscribed_for_context(event_name, ctx_id) {
    return
  }
  let params : Map[String, Json] = {
    "context": Json::string(ctx_id),
    "address": Json::string(address),
    "serviceUuid": Json::string(service_uuid),
    "characteristicUuid": Json::string(characteristic_uuid),
    "descriptorUuid": Json::string(descriptor_uuid),
    "type": Json::string(event_type),
  }
  match data {
    Some(data) => params["data"] = data
    None => ()
  }
  self.outbox.push(
    Event({ event_method: event_name, params: make_object(params) }),
  )
}

///|
fn BidiProtocol::validate_bluetooth_manufacturer_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Array[Json]? {
  match
    get_param_raw_with_alias(params, "manufacturerData", "manufacturer_data") {
    Some(Array(entries)) => {
      let out : Array[Json] = []
      for entry in entries {
        match entry {
          Object(map) =>
            match map.get("key") {
              Some(Number(key, ..)) =>
                if key >= 0 && key.floor() == key {
                  match map.get("data") {
                    Some(String(data)) =>
                      out.push(
                        make_object({
                          "key": Json::number(key),
                          "data": Json::string(data),
                        }),
                      )
                    Some(_) => {
                      self.send_error(
                        request_id, "invalid argument", "manufacturerData.data must be a string",
                      )
                      return None
                    }
                    None => {
                      self.send_error(
                        request_id, "invalid argument", "manufacturerData entry is invalid",
                      )
                      return None
                    }
                  }
                } else {
                  self.send_error(
                    request_id, "invalid argument", "manufacturerData.key must be a non-negative integer",
                  )
                  return None
                }
              Some(_) => {
                self.send_error(
                  request_id, "invalid argument", "manufacturerData.key must be a non-negative integer",
                )
                return None
              }
              None => {
                self.send_error(
                  request_id, "invalid argument", "manufacturerData entry is invalid",
                )
                return None
              }
            }
          _ => {
            self.send_error(
              request_id, "invalid argument", "manufacturerData must contain objects",
            )
            return None
          }
        }
      }
      Some(out)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "manufacturerData must be an array",
      )
      None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing manufacturerData",
      )
      None
    }
  }
}

///|
fn BidiProtocol::validate_bluetooth_known_service_uuids(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Array[Json]? {
  match
    get_param_raw_with_alias(params, "knownServiceUuids", "known_service_uuids") {
    Some(Array(entries)) => {
      let out : Array[Json] = []
      for entry in entries {
        match entry {
          String(uuid) => out.push(Json::string(uuid))
          _ => {
            self.send_error(
              request_id, "invalid argument", "knownServiceUuids entries must be strings",
            )
            return None
          }
        }
      }
      Some(out)
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "knownServiceUuids must be an array",
      )
      None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "Missing knownServiceUuids",
      )
      None
    }
  }
}

///|
fn BidiProtocol::find_bluetooth_device_descriptor(
  self : BidiProtocol,
  ctx_id : String,
  address : String,
) -> Json? {
  match self.bluetooth_preconnected_devices_by_context.get(ctx_id) {
    Some(devices) =>
      for device in devices {
        match bluetooth_device_field_string(device, "address") {
          Some(device_address) if device_address == address =>
            return Some(device)
          _ => ()
        }
      }
    None => ()
  }
  None
}

///|
fn BidiProtocol::has_bluetooth_device_descriptor(
  self : BidiProtocol,
  ctx_id : String,
  address : String,
) -> Bool {
  self.find_bluetooth_device_descriptor(ctx_id, address) != None
}

///|
fn BidiProtocol::validate_bluetooth_characteristic_properties(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Json? {
  match
    get_param_raw_with_alias(
      params, "characteristicProperties", "characteristic_properties",
    ) {
    Some(Object(map)) => {
      let out : Map[String, Json] = {}
      for key, value in map {
        match value {
          True => out[key] = Json::boolean(true)
          False => out[key] = Json::boolean(false)
          _ => {
            self.send_error(
              request_id, "invalid argument", "characteristicProperties values must be booleans",
            )
            return None
          }
        }
      }
      Some(make_object(out))
    }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "characteristicProperties must be an object",
      )
      None
    }
    None => {
      self.send_error(
        request_id, "invalid argument", "characteristicProperties must be present for add",
      )
      None
    }
  }
}

///|
fn find_bluetooth_device_for_name(
  devices : Array[Json],
  expected_name : String?,
) -> Json {
  match expected_name {
    Some(expected_name) =>
      for device in devices {
        match bluetooth_device_field_string(device, "name") {
          Some(name) if name == expected_name => return device
          _ => ()
        }
      }
    None => ()
  }
  devices[0]
}

///|
fn bluetooth_device_field_string(device : Json, field : String) -> String? {
  match device {
    Object(map) =>
      match map.get(field) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn upsert_bluetooth_device(
  devices : Array[Json],
  next_device : Json,
  address : String,
) -> Array[Json] {
  let out : Array[Json] = []
  let mut replaced = false
  for device in devices {
    match bluetooth_device_field_string(device, "address") {
      Some(current_address) if current_address == address => {
        out.push(next_device)
        replaced = true
      }
      _ => out.push(device)
    }
  }
  if !replaced {
    out.push(next_device)
  }
  out
}

///|
fn extract_first_bluetooth_string_argument(params : Json?) -> String? {
  match get_param_raw(params, "arguments") {
    Some(Array(args)) if args.length() > 0 =>
      match args[0] {
        Object(map) =>
          match (map.get("type"), map.get("value")) {
            (Some(String("string")), Some(String(value))) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn make_bluetooth_requested_device_remote_value(
  address : String,
  name : String,
) -> Json {
  make_object({
    "type": Json::string("object"),
    "value": Json::array([
      Json::array([
        Json::string("id"),
        make_object({
          "type": Json::string("string"),
          "value": Json::string(address),
        }),
      ]),
      Json::array([
        Json::string("name"),
        make_object({
          "type": Json::string("string"),
          "value": Json::string(name),
        }),
      ]),
    ]),
  })
}

///|
fn bluetooth_scope_key(ctx_id : String, address : String) -> String {
  ctx_id + "|" + address
}

///|
fn bluetooth_characteristic_scope_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
) -> String {
  bluetooth_characteristic_prefix_key(ctx_id, address, service_uuid) +
  characteristic_uuid
}

///|
fn bluetooth_characteristic_prefix_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
) -> String {
  ctx_id + "|" + address + "|" + service_uuid + "|"
}

///|
fn extract_bluetooth_call_string_argument(
  source : String,
  method_name : String,
) -> String {
  let single_prefix = method_name + "('"
  match find_substring(source, single_prefix, 0) {
    Some(start_idx) => {
      let value_start = start_idx + single_prefix.length()
      match find_substring(source, "')", value_start) {
        Some(end_idx) if end_idx >= value_start =>
          source.unsafe_substring(start=value_start, end=end_idx)
        _ => ""
      }
    }
    None => {
      let double_prefix = method_name + "(\""
      match find_substring(source, double_prefix, 0) {
        Some(start_idx) => {
          let value_start = start_idx + double_prefix.length()
          match find_substring(source, "\")", value_start) {
            Some(end_idx) if end_idx >= value_start =>
              source.unsafe_substring(start=value_start, end=end_idx)
            _ => ""
          }
        }
        None => ""
      }
    }
  }
}

///|
fn BidiProtocol::validate_bluetooth_response_data(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
  required : Bool,
) -> Array[Json]? {
  match get_param_raw(params, "data") {
    Some(Array(entries)) =>
      if !required {
        self.send_error(
          request_id, "invalid argument", "data must be absent for this response type",
        )
        None
      } else {
        let out : Array[Json] = []
        for entry in entries {
          match entry {
            Number(n, ..) if n >= 0.0 && n <= 255.0 && n.floor() == n =>
              out.push(Json::number(n))
            _ => {
              self.send_error(
                request_id, "invalid argument", "data must be an array of bytes",
              )
              return None
            }
          }
        }
        Some(out)
      }
    Some(Null) | None =>
      if required {
        self.send_error(
          request_id, "invalid argument", "data must be present for read",
        )
        None
      } else {
        Some([])
      }
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "data must be an array of bytes",
      )
      None
    }
  }
}

///|
fn BidiProtocol::clear_pending_bluetooth_characteristic(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.bluetooth_pending_characteristic_request.remove(ctx_id)
  self.bluetooth_pending_characteristic_realm.remove(ctx_id)
  self.bluetooth_pending_characteristic_unwrap_result.remove(ctx_id)
  self.bluetooth_pending_characteristic_address.remove(ctx_id)
  self.bluetooth_pending_characteristic_service_uuid.remove(ctx_id)
  self.bluetooth_pending_characteristic_uuid.remove(ctx_id)
  self.bluetooth_pending_characteristic_type.remove(ctx_id)
}

///|
fn BidiProtocol::clear_pending_bluetooth_descriptor(
  self : BidiProtocol,
  ctx_id : String,
) -> Unit {
  self.bluetooth_pending_descriptor_request.remove(ctx_id)
  self.bluetooth_pending_descriptor_realm.remove(ctx_id)
  self.bluetooth_pending_descriptor_unwrap_result.remove(ctx_id)
  self.bluetooth_pending_descriptor_address.remove(ctx_id)
  self.bluetooth_pending_descriptor_service_uuid.remove(ctx_id)
  self.bluetooth_pending_descriptor_characteristic_uuid.remove(ctx_id)
  self.bluetooth_pending_descriptor_uuid.remove(ctx_id)
  self.bluetooth_pending_descriptor_type.remove(ctx_id)
}

///|
fn make_bluetooth_byte_remote_value(data : Array[Json]) -> Json {
  let items : Array[Json] = []
  for entry in data {
    match entry {
      Number(value, ..) =>
        items.push(
          make_object({
            "type": Json::string("number"),
            "value": Json::number(value),
          }),
        )
      _ => ()
    }
  }
  make_object({ "type": Json::string("array"), "value": Json::array(items) })
}

///|
fn extract_bluetooth_uint8_array_data(source : String) -> Array[Json] {
  let prefix = "new Uint8Array("
  match find_substring(source, prefix, 0) {
    Some(start_idx) => {
      let data_start = start_idx + prefix.length()
      match find_substring(source, ")", data_start) {
        Some(end_idx) if end_idx >= data_start => {
          let raw = source.unsafe_substring(start=data_start, end=end_idx)
          extract_bluetooth_byte_array_literal(raw.trim().to_string())
        }
        _ => []
      }
    }
    None => []
  }
}

///|
fn extract_bluetooth_byte_array_literal(raw : String) -> Array[Json] {
  if raw.length() < 2 || !raw.has_prefix("[") || !raw.has_suffix("]") {
    return []
  }
  let body = raw.unsafe_substring(start=1, end=raw.length() - 1)
  if body.trim().to_string() == "" {
    return []
  }
  let out : Array[Json] = []
  for part in body.split(",") {
    let value_text = part.trim().to_string()
    if value_text == "" {
      continue
    }
    let value = @string.parse_int(value_text) catch { _ => -1 }
    if value >= 0 && value <= 255 {
      out.push(Json::number(value.to_double()))
    }
  }
  out
}

///|
fn bluetooth_descriptor_scope_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
  descriptor_uuid : String,
) -> String {
  bluetooth_descriptor_prefix_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  ) +
  descriptor_uuid
}

///|
fn bluetooth_descriptor_prefix_key(
  ctx_id : String,
  address : String,
  service_uuid : String,
  characteristic_uuid : String,
) -> String {
  bluetooth_characteristic_scope_key(
    ctx_id, address, service_uuid, characteristic_uuid,
  ) +
  "|"
}
