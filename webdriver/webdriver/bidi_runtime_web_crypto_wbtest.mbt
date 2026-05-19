///|
/// Web Crypto API surface in the BiDi runtime realm (#178).
///
/// Node 22+ exposes `globalThis.crypto` (Crypto interface) with
/// `randomUUID`, `getRandomValues`, AND the `subtle` namespace
/// (SubtleCrypto: `digest`, `encrypt`, `decrypt`, `sign`, `verify`,
/// `generateKey`, `importKey`, etc). The BiDi runtime keeps `crypto`
/// in its reserved-properties set so the per-evaluate window →
/// globalThis sync doesn't overwrite Node's native binding.
///
/// These tests pin that surface so a regression in the reserved set
/// (or a stub install path) can't silently strip SubtleCrypto out
/// from under a page that relies on it for auth / passkeys / signed
/// payload verification.

///|
test "crypto.randomUUID returns a valid UUID v4" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__uuid = String(crypto.randomUUID());",
  )
  let resp = read_global_string(proto, 3, "__uuid")
  // UUID v4 shape: 8-4-4-4-12 hex chars with hyphens. Cheap regex
  // substring check: look for the canonical structure marker.
  assert_true(resp.contains("-4"))
  // 36 chars (32 hex + 4 hyphens). Length is part of the JSON-wrapped
  // value, so we check that the string field is at least the UUID
  // length (the outer JSON wrapper adds more).
  assert_true(resp.length() > 36)
}

///|
test "crypto.getRandomValues fills a Uint8Array with non-zero values" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "const a = new Uint8Array(8); crypto.getRandomValues(a); globalThis.__hasNonZero = String(Array.from(a).some(v => v !== 0));",
  )
  let resp = read_global_string(proto, 3, "__hasNonZero")
  // 8 bytes of CSPRNG output — vanishingly unlikely to be all zero.
  assert_true(resp.contains("\"true\""))
}

///|
test "crypto.subtle namespace is exposed (not stubbed away by the realm sync)" {
  let proto = make_proto_with_session()
  run_sync_in_context(
    proto, 2, "globalThis.__subtleType = String(typeof crypto.subtle); globalThis.__digestType = String(typeof (crypto.subtle && crypto.subtle.digest));",
  )
  let subtle_type = read_global_string(proto, 3, "__subtleType")
  assert_true(subtle_type.contains("\"object\""))
  let digest_type = read_global_string(proto, 4, "__digestType")
  assert_true(digest_type.contains("\"function\""))
}

///|
async test "crypto.subtle.digest('SHA-256') round-trips a known vector" {
  let proto = make_proto_with_session()
  // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  // Standard NIST FIPS 180-4 test vector. Pin it through Crater's
  // BiDi realm so an accidental shim of crypto.subtle would
  // immediately diverge from the published vector.
  run_sync_in_context(
    proto, 2, "(async () => { const enc = new TextEncoder().encode('abc'); const buf = await crypto.subtle.digest('SHA-256', enc); const hex = Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join(''); globalThis.__digestHex = hex; })()",
  )
  // The async digest call schedules onto the microtask queue; sleep
  // briefly to drain.
  @async.sleep(20)
  let resp = read_global_string(proto, 3, "__digestHex")
  assert_true(
    resp.contains(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    ),
  )
}

///|
async test "crypto.subtle.generateKey + sign + verify HMAC-SHA-256 round-trip" {
  let proto = make_proto_with_session()
  // Generate an HMAC key, sign a message, verify the signature.
  // This is a representative end-to-end SubtleCrypto path — exercises
  // generateKey, sign, AND verify in one shot. Auth flows that rely on
  // signed payloads (JWS, CSRF tokens, webhook verification) follow
  // exactly this shape.
  run_sync_in_context(
    proto, 2, "(async () => { const key = await crypto.subtle.generateKey({ name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']); const data = new TextEncoder().encode('hello'); const sig = await crypto.subtle.sign('HMAC', key, data); const ok = await crypto.subtle.verify('HMAC', key, sig, data); globalThis.__hmacOk = String(ok); })()",
  )
  @async.sleep(30)
  let resp = read_global_string(proto, 3, "__hmacOk")
  // sign / verify on the same key + data must round-trip to true.
  assert_true(resp.contains("\"true\""))
}
