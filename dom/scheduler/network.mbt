///|
/// Network Types - CDP Network domain の内部表現
/// ブラウザの非同期IOレイヤーとの通信に使用

// =============================================================================
// Request ID
// =============================================================================

///|
/// ネットワークリクエストの一意識別子
pub(all) struct RequestId(Int) derive(Eq, Hash, Debug)

///|
/// ID generator
priv struct RequestIdGenerator {
  mut next_id : Int
}

///|
let request_id_gen : RequestIdGenerator = { next_id: 0 }

///|
pub fn RequestId::next() -> RequestId {
  let id = request_id_gen.next_id
  request_id_gen.next_id += 1
  RequestId(id)
}

///|
/// Reset request ID counter (for testing)
pub fn reset_request_id_counter() -> Unit {
  request_id_gen.next_id = 0
}

// =============================================================================
// HTTP Method
// =============================================================================

///|
/// HTTP メソッド
pub(all) enum HttpMethod {
  GET
  POST
  PUT
  DELETE
  HEAD
  OPTIONS
  PATCH
} derive(Eq, Debug)

///|
pub fn HttpMethod::from_string(s : String) -> HttpMethod {
  match s.to_upper() {
    "GET" => GET
    "POST" => POST
    "PUT" => PUT
    "DELETE" => DELETE
    "HEAD" => HEAD
    "OPTIONS" => OPTIONS
    "PATCH" => PATCH
    _ => GET
  }
}

///|
pub fn HttpMethod::to_string(self : HttpMethod) -> String {
  match self {
    GET => "GET"
    POST => "POST"
    PUT => "PUT"
    DELETE => "DELETE"
    HEAD => "HEAD"
    OPTIONS => "OPTIONS"
    PATCH => "PATCH"
  }
}

// =============================================================================
// Network Request
// =============================================================================

///|
/// ネットワークリクエスト
pub(all) struct NetworkRequest {
  /// リクエストID
  id : RequestId
  /// リクエストURL
  url : String
  /// HTTP メソッド
  http_method : HttpMethod
  /// リソースタイプ
  resource_type : ResourceType
  /// リクエストヘッダー
  headers : Map[String, String]
  /// ドキュメントURL（リクエスト元）
  document_url : String
  /// フレームID
  frame_id : String
  /// ローダーID
  loader_id : String
  /// タイムスタンプ（ミリ秒）
  timestamp : Double
} derive(Debug)

///|
pub fn NetworkRequest::new(
  url : String,
  resource_type : ResourceType,
  document_url? : String = "",
  frame_id? : String = "main",
  http_method? : HttpMethod = GET,
) -> NetworkRequest {
  let id = RequestId::next()
  {
    id,
    url,
    http_method,
    resource_type,
    headers: {},
    document_url,
    frame_id,
    loader_id: "loader-\{id}",
    timestamp: 0.0,
  }
}

///|
pub fn NetworkRequest::with_headers(
  self : NetworkRequest,
  headers : Map[String, String],
) -> NetworkRequest {
  { ..self, headers, }
}

///|
pub fn NetworkRequest::with_timestamp(
  self : NetworkRequest,
  timestamp : Double,
) -> NetworkRequest {
  { ..self, timestamp, }
}

///|
pub fn NetworkRequest::with_loader_id(
  self : NetworkRequest,
  loader_id : String,
) -> NetworkRequest {
  { ..self, loader_id, }
}

// =============================================================================
// Network Response
// =============================================================================

///|
/// ネットワークレスポンス
pub(all) struct NetworkResponse {
  /// 対応するリクエストID
  request_id : RequestId
  /// レスポンスURL（リダイレクト後の最終URL）
  url : String
  /// HTTP ステータスコード
  status : Int
  /// ステータステキスト
  status_text : String
  /// MIME タイプ
  mime_type : String
  /// レスポンスヘッダー
  headers : Map[String, String]
  /// レスポンスボディ（オプショナル）
  body : String?
  /// コンテンツ長
  content_length : Int
  /// タイムスタンプ（ミリ秒）
  timestamp : Double
  /// ローダーID（オプショナル）
  loader_id : String
} derive(Debug)

///|
pub fn NetworkResponse::new(
  request_id : RequestId,
  url : String,
  status : Int,
) -> NetworkResponse {
  let RequestId(id) = request_id
  {
    request_id,
    url,
    status,
    status_text: status_to_text(status),
    mime_type: "text/html",
    headers: {},
    body: None,
    content_length: 0,
    timestamp: 0.0,
    loader_id: "loader-\{id}",
  }
}

///|
fn status_to_text(status : Int) -> String {
  match status {
    200 => "OK"
    201 => "Created"
    204 => "No Content"
    301 => "Moved Permanently"
    302 => "Found"
    304 => "Not Modified"
    400 => "Bad Request"
    401 => "Unauthorized"
    403 => "Forbidden"
    404 => "Not Found"
    500 => "Internal Server Error"
    502 => "Bad Gateway"
    503 => "Service Unavailable"
    _ => "Unknown"
  }
}

///|
pub fn NetworkResponse::with_body(
  self : NetworkResponse,
  body : String,
) -> NetworkResponse {
  { ..self, body: Some(body), content_length: body.length() }
}

///|
pub fn NetworkResponse::with_headers(
  self : NetworkResponse,
  headers : Map[String, String],
) -> NetworkResponse {
  { ..self, headers, }
}

///|
pub fn NetworkResponse::with_mime_type(
  self : NetworkResponse,
  mime_type : String,
) -> NetworkResponse {
  { ..self, mime_type, }
}

///|
pub fn NetworkResponse::with_timestamp(
  self : NetworkResponse,
  timestamp : Double,
) -> NetworkResponse {
  { ..self, timestamp, }
}

///|
pub fn NetworkResponse::with_loader_id(
  self : NetworkResponse,
  loader_id : String,
) -> NetworkResponse {
  { ..self, loader_id, }
}

// =============================================================================
// Network Events (CDP互換)
// =============================================================================

///|
/// ネットワークイベント - CDP Network domain のイベントに対応
pub(all) enum NetworkEvent {
  /// リクエスト送信前
  RequestWillBeSent(NetworkRequest)
  /// レスポンス受信
  ResponseReceived(NetworkResponse)
  /// ロード完了
  LoadingFinished(request_id~ : RequestId, encoded_data_length~ : Int)
  /// ロード失敗
  LoadingFailed(request_id~ : RequestId, error~ : String)
} derive(Debug)

///|
pub fn NetworkEvent::request_id(self : NetworkEvent) -> RequestId {
  match self {
    RequestWillBeSent(req) => req.id
    ResponseReceived(res) => res.request_id
    LoadingFinished(request_id~, ..) => request_id
    LoadingFailed(request_id~, ..) => request_id
  }
}

// =============================================================================
// Fetch Task Result
// =============================================================================

///|
/// FetchResource タスクの結果
pub(all) enum FetchResult {
  /// 成功
  Success(response~ : NetworkResponse)
  /// リダイレクト
  Redirect(location~ : String, status~ : Int)
  /// 失敗
  Failure(error~ : String)
} derive(Debug)

///|
pub impl Show for RequestId with output(self, logger) {
  logger.write_string("RequestId(\{self.0})")
}

///|
pub impl Show for HttpMethod with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Show for NetworkRequest with output(self, logger) {
  logger.write_string("{id: \{self.id}, url: ")
  logger.write_string("\"")
  logger.write_string(self.url)
  logger.write_string("\"")
  logger.write_string(", http_method: \{self.http_method}, ")
  logger.write_string(
    "resource_type: \{self.resource_type}, headers: \{self.headers}, ",
  )
  logger.write_string("document_url: ")
  logger.write_string("\"")
  logger.write_string(self.document_url)
  logger.write_string("\"")
  logger.write_string(", frame_id: ")
  logger.write_string("\"")
  logger.write_string(self.frame_id)
  logger.write_string("\"")
  logger.write_string(", loader_id: ")
  logger.write_string("\"")
  logger.write_string(self.loader_id)
  logger.write_string("\"")
  logger.write_string(", timestamp: \{self.timestamp}}")
}

///|
pub impl Show for NetworkResponse with output(self, logger) {
  logger.write_string("{request_id: \{self.request_id}, url: ")
  logger.write_string("\"")
  logger.write_string(self.url)
  logger.write_string("\"")
  logger.write_string(", status: \{self.status}, status_text: ")
  logger.write_string("\"")
  logger.write_string(self.status_text)
  logger.write_string("\"")
  logger.write_string(", mime_type: ")
  logger.write_string("\"")
  logger.write_string(self.mime_type)
  logger.write_string("\"")
  logger.write_string(", headers: \{self.headers}, body: \{self.body}, ")
  logger.write_string(
    "content_length: \{self.content_length}, timestamp: \{self.timestamp}, ",
  )
  logger.write_string("loader_id: ")
  logger.write_string("\"")
  logger.write_string(self.loader_id)
  logger.write_string("\"")
  logger.write_string("}")
}

///|
pub impl Show for NetworkEvent with output(self, logger) {
  match self {
    RequestWillBeSent(request) =>
      logger.write_string("RequestWillBeSent(\{request})")
    ResponseReceived(response) =>
      logger.write_string("ResponseReceived(\{response})")
    LoadingFinished(request_id~, encoded_data_length~) =>
      logger.write_string(
        "LoadingFinished(request_id=\{request_id}, encoded_data_length=\{encoded_data_length})",
      )
    LoadingFailed(request_id~, error~) => {
      logger.write_string("LoadingFailed(request_id=\{request_id}, error=")
      logger.write_string("\"")
      logger.write_string(error)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for FetchResult with output(self, logger) {
  match self {
    Success(response~) => logger.write_string("Success(response=\{response})")
    Redirect(location~, status~) => {
      logger.write_string("Redirect(location=")
      logger.write_string("\"")
      logger.write_string(location)
      logger.write_string("\"")
      logger.write_string(", status=\{status})")
    }
    Failure(error~) => {
      logger.write_string("Failure(error=")
      logger.write_string("\"")
      logger.write_string(error)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

// =============================================================================
// Network Manager
// =============================================================================

///|
/// ネットワークリクエストを管理
pub struct NetworkManager {
  /// 進行中のリクエスト
  pending_requests : Map[Int, NetworkRequest]
  /// 発行されたイベント（外部に通知するため）
  mut pending_events : Array[NetworkEvent]
  /// Network.enable が呼ばれたか
  mut enabled : Bool
}

///|
pub fn NetworkManager::new() -> NetworkManager {
  { pending_requests: {}, pending_events: [], enabled: false }
}

///|
/// Network を有効化
pub fn NetworkManager::enable(self : NetworkManager) -> Unit {
  self.enabled = true
}

///|
/// Network を無効化
pub fn NetworkManager::disable(self : NetworkManager) -> Unit {
  self.enabled = false
}

///|
/// リクエスト開始を記録
pub fn NetworkManager::start_request(
  self : NetworkManager,
  request : NetworkRequest,
) -> Unit {
  let RequestId(id) = request.id
  self.pending_requests[id] = request
  if self.enabled {
    self.pending_events.push(RequestWillBeSent(request))
  }
}

///|
/// レスポンス受信を記録
pub fn NetworkManager::receive_response(
  self : NetworkManager,
  response : NetworkResponse,
) -> Unit {
  if self.enabled {
    self.pending_events.push(ResponseReceived(response))
  }
}

///|
/// ロード完了を記録
pub fn NetworkManager::finish_loading(
  self : NetworkManager,
  request_id : RequestId,
  encoded_data_length : Int,
) -> Unit {
  let RequestId(id) = request_id
  self.pending_requests.remove(id)
  if self.enabled {
    self.pending_events.push(LoadingFinished(request_id~, encoded_data_length~))
  }
}

///|
/// ロード失敗を記録
pub fn NetworkManager::fail_loading(
  self : NetworkManager,
  request_id : RequestId,
  error : String,
) -> Unit {
  let RequestId(id) = request_id
  self.pending_requests.remove(id)
  if self.enabled {
    self.pending_events.push(LoadingFailed(request_id~, error~))
  }
}

///|
/// pending イベントを取得してクリア
pub fn NetworkManager::drain_events(
  self : NetworkManager,
) -> Array[NetworkEvent] {
  let events = self.pending_events
  self.pending_events = []
  events
}

///|
/// pending イベントがあるか
pub fn NetworkManager::has_pending_events(self : NetworkManager) -> Bool {
  !self.pending_events.is_empty()
}

///|
/// 進行中のリクエスト数
pub fn NetworkManager::pending_count(self : NetworkManager) -> Int {
  self.pending_requests.length()
}
