///|
test "serialize_dom_to_html uses shadow root composed children instead of light DOM" {
  let dom = @dom.DomTree::new()
  let doc = dom.get_document()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let host = dom.create_element("div")
  let light = dom.create_element("span")
  let light_text = dom.create_text("light")
  let shadow = dom.attach_shadow(host, "open").unwrap()
  let inner = dom.create_element("p")
  let inner_text = dom.create_text("shadow")

  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.set_attribute(host, "id", "host")
  let _ = dom.append_child(body, host)
  let _ = dom.append_child(light, light_text)
  let _ = dom.append_child(host, light)
  let _ = dom.append_child(inner, inner_text)
  let _ = dom.append_child(shadow, inner)

  inspect(
    serialize_dom_to_html(dom),
    content="<html><body><div id=\"host\"><p>shadow</p></div></body></html>",
  )
}

///|
test "serialize_dom_to_html distributes slotted light DOM into shadow content" {
  let dom = @dom.DomTree::new()
  let doc = dom.get_document()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let host = dom.create_element("div")
  let shadow = dom.attach_shadow(host, "open").unwrap()
  let wrapper = dom.create_element("section")
  let default_slot = dom.create_element("slot")
  let named_slot = dom.create_element("slot")
  let plain = dom.create_element("span")
  let plain_text = dom.create_text("plain")
  let named = dom.create_element("em")
  let named_text = dom.create_text("named")

  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, host)
  let _ = dom.set_attribute(wrapper, "id", "wrap")
  let _ = dom.set_attribute(named_slot, "name", "label")
  let _ = dom.append_child(shadow, wrapper)
  let _ = dom.append_child(wrapper, default_slot)
  let _ = dom.append_child(wrapper, named_slot)
  let _ = dom.append_child(plain, plain_text)
  let _ = dom.append_child(named, named_text)
  let _ = dom.set_attribute(named, "slot", "label")
  let _ = dom.append_child(host, plain)
  let _ = dom.append_child(host, named)

  inspect(
    serialize_dom_to_html(dom),
    content="<html><body><div><section id=\"wrap\"><span>plain</span><em slot=\"label\">named</em></section></div></body></html>",
  )
}

///|
test "serialize_dom_to_html flattens nested fallback slots in shadow content" {
  let dom = @dom.DomTree::new()
  let doc = dom.get_document()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let host = dom.create_element("div")
  let shadow = dom.attach_shadow(host, "open").unwrap()
  let outer = dom.create_element("slot")
  let inner = dom.create_element("slot")
  let fallback = dom.create_element("span")
  let fallback_text = dom.create_text("fallback")

  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.append_child(body, host)
  let _ = dom.set_attribute(inner, "name", "inner")
  let _ = dom.append_child(shadow, outer)
  let _ = dom.append_child(outer, inner)
  let _ = dom.append_child(fallback, fallback_text)
  let _ = dom.append_child(inner, fallback)

  inspect(
    serialize_dom_to_html(dom),
    content="<html><body><div><span>fallback</span></div></body></html>",
  )
}

///|
test "serialize_dom_to_html reflects shadow DOM created through JsContext" {
  let dom = @dom.DomTree::new()
  let doc = dom.get_document()
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let host = dom.create_element("div")
  let light = dom.create_element("span")
  let light_text = dom.create_text("light")
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let _ = dom.set_attribute(host, "id", "host")
  let _ = dom.append_child(body, host)
  let _ = dom.append_child(light, light_text)
  let _ = dom.append_child(host, light)

  let ctx = JsContext::new(dom)
  let code =
    #|(() => {
    #|  const host = document.getElementById('host');
    #|  const shadow = host.attachShadow({ mode: 'open' });
    #|  shadow.innerHTML = '<p>shadow-text</p>';
    #|  return host.shadowRoot.firstChild.textContent;
    #|})()
  let result = ctx.execute(code)
  inspect(result.success, content="true")
  inspect(result.value, content="shadow-text")
  inspect(
    serialize_dom_to_html(dom),
    content="<html><body><div id=\"host\"><p>shadow-text</p></div></body></html>",
  )
}
