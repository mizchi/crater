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
