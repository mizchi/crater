///|
/// Local contract / rpc aliases for the webdriver kitchen-sink package.
///
/// `webdriver/top.mbt` re-exports the contract / rpc types directly to
/// downstream consumers, so this file only pulls the names actually
/// referenced from internal code into scope, and keeps the rpc helpers that
/// are still called without the `@rpc.` prefix from handler / protocol /
/// transport code.
using @contract {type ApiError, type ApiMethod, type ApiResult}

///|
using @rpc {type RpcErrorCode, type RpcId, type RpcRequest, type RpcResponse}

///|
fn escape_json_string(s : String) -> String {
  @contract.escape_json_string(s)
}

///|
fn rpc_success_null(id : RpcId) -> RpcResponse {
  @rpc.rpc_success_null(id)
}

///|
fn rpc_success_string(id : RpcId, value : String) -> RpcResponse {
  @rpc.rpc_success_string(id, value)
}

///|
fn rpc_success_json(id : RpcId, json : String) -> RpcResponse {
  @rpc.rpc_success_json(id, json)
}

///|
fn rpc_error(id : RpcId, code : RpcErrorCode, message : String) -> RpcResponse {
  @rpc.rpc_error(id, code, message)
}

///|
fn api_error_to_rpc(id : RpcId, err : ApiError) -> RpcResponse {
  @rpc.api_error_to_rpc(id, err)
}

///|
pub fn parse_method(name : String) -> ApiMethod? {
  @rpc.parse_method(name)
}

///|
fn parse_json_object(json : String) -> Map[String, String] {
  @rpc.parse_json_object(json)
}
