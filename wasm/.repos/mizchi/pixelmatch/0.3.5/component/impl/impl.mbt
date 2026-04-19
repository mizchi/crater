///|
fn bytes_to_image(data : Array[Byte], width : UInt, height : UInt) -> @pm.Image {
  let w = width.reinterpret_as_int()
  let h = height.reinterpret_as_int()
  let len = data.length()
  let int_data : Array[Int] = Array::new(capacity=len)
  for b in data {
    int_data.push(b.to_int())
  }
  { width: w, height: h, data: int_data }
}

///|
fn image_to_bytes(img : @pm.Image) -> Array[Byte] {
  let data : Array[Byte] = Array::new(capacity=img.data.length())
  for v in img.data {
    data.push(v.to_byte())
  }
  data
}

///|
fn make_pm_opts(
  threshold : Double,
  include_aa : Int,
  alpha : Double,
  diff_mask : Int,
) -> @pm.Options {
  {
    threshold,
    include_aa: include_aa != 0,
    alpha,
    aa_color: @pm.Color::rgba(255, 255, 0, 255),
    diff_color: @pm.Color::rgba(255, 0, 0, 255),
    diff_color_alt: None,
    diff_mask: diff_mask != 0,
  }
}

///|
fn pixelmatch(
  img1_data : Array[Byte],
  img2_data : Array[Byte],
  width : UInt,
  height : UInt,
  include_output : Int,
  threshold : Double,
  include_aa : Int,
  alpha : Double,
  diff_mask : Int,
) -> MatchResult {
  let img1 = bytes_to_image(img1_data, width, height)
  let img2 = bytes_to_image(img2_data, width, height)
  let opts = make_pm_opts(threshold, include_aa, alpha, diff_mask)
  if include_output != 0 {
    let w = width.reinterpret_as_int()
    let h = height.reinterpret_as_int()
    let out = @pm.Image::new(w, h)
    let diff_count = @pm.pixelmatch(img1, img2, Some(out), opts)
    {
      diff_count: diff_count.reinterpret_as_uint(),
      output: Some(image_to_bytes(out)),
    }
  } else {
    let diff_count = @pm.pixelmatch(img1, img2, None, opts)
    { diff_count: diff_count.reinterpret_as_uint(), output: None }
  }
}

///|
fn pixelmatch_simple(
  img1_data : Array[Byte],
  img2_data : Array[Byte],
  width : UInt,
  height : UInt,
  threshold : Double,
) -> UInt {
  let img1 = bytes_to_image(img1_data, width, height)
  let img2 = bytes_to_image(img2_data, width, height)
  @pm.pixelmatch_simple(img1, img2, threshold).reinterpret_as_uint()
}

///|
fn match_ratio(
  img1_data : Array[Byte],
  img2_data : Array[Byte],
  width : UInt,
  height : UInt,
  threshold : Double,
  include_aa : Int,
  alpha : Double,
  diff_mask : Int,
) -> Double {
  let img1 = bytes_to_image(img1_data, width, height)
  let img2 = bytes_to_image(img2_data, width, height)
  let opts = make_pm_opts(threshold, include_aa, alpha, diff_mask)
  @pm.match_ratio(img1, img2, opts)
}
