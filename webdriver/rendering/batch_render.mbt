///|
pub(all) struct BatchRenderOptions {
  base_html : String
  viewport : @types.Size[Double]
  variants : Array[@vrt.RenderVariant]
}

///|
pub fn normalize_batch_render_options(
  params : Map[String, Json],
  fallback_base_html : String,
) -> Result[BatchRenderOptions, RenderingValidationError] {
  let base_html = match params.get("baseHtml") {
    Some(String(html)) => html
    None => fallback_base_html
    Some(_) => return Err(InvalidArgument("baseHtml must be a string"))
  }
  let viewport = normalize_batch_render_viewport(params.get("viewport"))
  let variants = match normalize_batch_render_variants(params.get("variants")) {
    Ok(variants) => variants
    Err(error) => return Err(error)
  }
  Ok({ base_html, viewport, variants })
}

///|
fn normalize_batch_render_viewport(raw_viewport : Json?) -> @types.Size[Double] {
  let width = match raw_viewport {
    Some(Object(viewport)) =>
      match viewport.get("width") {
        Some(Number(value, ..)) => value
        _ => 1280.0
      }
    _ => 1280.0
  }
  let height = match raw_viewport {
    Some(Object(viewport)) =>
      match viewport.get("height") {
        Some(Number(value, ..)) => value
        _ => 900.0
      }
    _ => 900.0
  }
  @types.Size::new(width, height)
}

///|
fn normalize_batch_render_variants(
  raw_variants : Json?,
) -> Result[Array[@vrt.RenderVariant], RenderingValidationError] {
  match raw_variants {
    Some(Array(items)) => {
      let variants : Array[@vrt.RenderVariant] = []
      for item in items {
        match normalize_batch_render_variant(item) {
          Some(variant) => variants.push(variant)
          None => ()
        }
      }
      Ok(variants)
    }
    _ => Err(InvalidArgument("variants must be an array"))
  }
}

///|
fn normalize_batch_render_variant(raw_variant : Json) -> @vrt.RenderVariant? {
  match raw_variant {
    Object(variant) => {
      let id = match variant.get("id") {
        Some(String(value)) => value
        _ => ""
      }
      let mutations = normalize_batch_render_mutations(variant.get("mutations"))
      Some({ id, mutations })
    }
    _ => None
  }
}

///|
fn normalize_batch_render_mutations(
  raw_mutations : Json?,
) -> Array[@vrt.CssMutation] {
  let mutations : Array[@vrt.CssMutation] = []
  match raw_mutations {
    Some(Array(items)) =>
      for item in items {
        match normalize_batch_render_mutation(item) {
          Some(mutation) => mutations.push(mutation)
          None => ()
        }
      }
    _ => ()
  }
  mutations
}

///|
fn normalize_batch_render_mutation(raw_mutation : Json) -> @vrt.CssMutation? {
  match raw_mutation {
    Object(mutation) => {
      let selector = match mutation.get("selector") {
        Some(String(value)) => value
        _ => return None
      }
      let property = match mutation.get("property") {
        Some(String(value)) => value
        _ => return None
      }
      let action = normalize_batch_render_mutation_action(
        mutation.get("action"),
      )
      Some({ selector, property, action })
    }
    _ => None
  }
}

///|
fn normalize_batch_render_mutation_action(
  raw_action : Json?,
) -> @vrt.CssMutationAction {
  match raw_action {
    Some(String("remove")) => @vrt.CssMutationAction::Remove
    Some(Object(action)) =>
      match action.get("override") {
        Some(String(value)) => @vrt.CssMutationAction::Override(value)
        _ => @vrt.CssMutationAction::Remove
      }
    _ => @vrt.CssMutationAction::Remove
  }
}
