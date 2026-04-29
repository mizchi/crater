///|
test "text-overflow is reported as supported" {
  inspect(get_support_level("text-overflow"), content="Supported")
}

///|
test "supported text-overflow stays informational" {
  inspect(
    support_to_severity(get_support_level("text-overflow")),
    content="Info",
  )
}

///|
test "clip-path reports supported basic shape subset" {
  inspect(
    get_support_level("clip-path"),
    content="Partial(basic shapes plus path M/L/H/V/Q/T/C/S/A/Z polygon subset)",
  )
}

///|
test "transform reports supported 2d visual subset" {
  inspect(
    get_support_level("transform"),
    content="Partial(translate/scale/2D rotate/skew/matrix/matrix3d 2D projection)",
  )
}
