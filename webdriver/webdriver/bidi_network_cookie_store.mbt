///|
fn BidiProtocol::store_synthetic_response_cookie(
  self : BidiProtocol,
  context_id : String,
  cookie : StoredCookie,
) -> Unit {
  let stored_cookie : StoredCookie = {
    ..cookie,
    context_id: Some(context_id),
    user_context: Some(self.resolve_storage_user_context(context_id)),
    source_origin: storage_cookie_origin_from_base_url(
      self.get_context_cookie_base_url(context_id),
    ),
  }
  match stored_cookie.expiry {
    Some(expiry) =>
      if expiry <= storage_now_seconds() {
        self.delete_matching_storage_cookie_identity(
          stored_cookie.context_id,
          stored_cookie.user_context,
          stored_cookie.source_origin,
          stored_cookie.name,
          stored_cookie.domain,
          stored_cookie.path,
        )
      } else {
        self.store_storage_cookie(stored_cookie)
      }
    None => self.store_storage_cookie(stored_cookie)
  }
}
