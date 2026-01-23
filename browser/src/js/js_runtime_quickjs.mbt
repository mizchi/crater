///|
/// JavaScript Runtime - QuickJS implementation
///
/// Uses quickjs-emscripten for sandboxed JavaScript execution.
/// DOM operations are queued and executed after JS completes.

///|
/// Global state for context management
priv struct RuntimeState {
  mut counter : Int
  contexts : Map[Int, @dom.DomTree]
  mut initialized : Bool
}

///|
/// Global runtime state
let runtime_state : RuntimeState = {
  counter: 0,
  contexts: {},
  initialized: false,
}

///|
/// Register a context and return its ID
fn register_context(dom : @dom.DomTree) -> Int {
  let id = runtime_state.counter
  runtime_state.counter = runtime_state.counter + 1
  runtime_state.contexts.set(id, dom)
  id
}

///|
/// Unregister a context
fn unregister_context(id : Int) -> Unit {
  runtime_state.contexts.remove(id)
}

///|
/// FFI: Initialize QuickJS runtime (must be called before execution)
/// Returns true if initialization succeeded
/// Note: QuickJS requires async init, so we fall back to Node.js vm if not pre-initialized
extern "js" fn quickjs_init() -> Bool =
  #| () => {
  #|   // Check if QuickJS was pre-initialized
  #|   if (globalThis.__quickjs_initialized && globalThis.__quickjs) {
  #|     return true;
  #|   }
  #|   // QuickJS requires async init - fall back to Node.js vm for now
  #|   // To use QuickJS, call initQuickJS() before using the runtime
  #|   globalThis.__use_nodejs_vm = true;
  #|   return true;
  #| }

///|
/// FFI: Async initialization of QuickJS (call this from JS before using runtime)
extern "js" fn quickjs_init_async() -> Unit =
  #| async () => {
  #|   if (globalThis.__quickjs_initialized) return;
  #|   const { getQuickJS } = require('quickjs-emscripten');
  #|   globalThis.__quickjs = await getQuickJS();
  #|   globalThis.__quickjs_initialized = true;
  #|   globalThis.__use_nodejs_vm = false;
  #| }

///|
/// FFI: Execute JavaScript code with DOM mock
/// Uses QuickJS if initialized, otherwise falls back to Node.js vm
/// Returns JSON: { success, value, logs, domOps, error? }
extern "js" fn quickjs_execute_with_mock_dom(code : String) -> String =
  #| (code) => {
  #|   // Mock DOM setup code (shared between QuickJS and Node.js vm)
  #|   const setupCode = `
  #|     const logs = [];
  #|     const domOps = [];
  #|     let nodeIdCounter = 1000;
  #|     const mockElements = new Map();
  #|
  #|     // DOMException class
  #|     function DOMException(message, name) {
  #|       Error.call(this, message);
  #|       this.message = message || '';
  #|       this.name = name || 'Error';
  #|       this.code = DOMException[name] || 0;
  #|     }
  #|     DOMException.prototype = Object.create(Error.prototype);
  #|     DOMException.prototype.constructor = DOMException;
  #|     DOMException.INDEX_SIZE_ERR = 1;
  #|     DOMException.HIERARCHY_REQUEST_ERR = 3;
  #|     DOMException.WRONG_DOCUMENT_ERR = 4;
  #|     DOMException.INVALID_CHARACTER_ERR = 5;
  #|     DOMException.NOT_FOUND_ERR = 8;
  #|     DOMException.NOT_SUPPORTED_ERR = 9;
  #|     DOMException.INVALID_STATE_ERR = 11;
  #|     DOMException.SYNTAX_ERR = 12;
  #|     DOMException.INVALID_MODIFICATION_ERR = 13;
  #|     DOMException.NAMESPACE_ERR = 14;
  #|     DOMException.IndexSizeError = 1;
  #|     DOMException.HierarchyRequestError = 3;
  #|     DOMException.WrongDocumentError = 4;
  #|     DOMException.InvalidCharacterError = 5;
  #|     DOMException.NotFoundError = 8;
  #|     DOMException.NotSupportedError = 9;
  #|     DOMException.InvalidStateError = 11;
  #|     DOMException.SyntaxError = 12;
  #|     DOMException.InvalidModificationError = 13;
  #|     DOMException.NamespaceError = 14;
  #|
  #|     // DOMImplementation class
  #|     function DOMImplementation() {}
  #|
  #|     // DOM interface classes for prototype chain
  #|     function Node() {}
  #|     Node.ELEMENT_NODE = 1;
  #|     Node.ATTRIBUTE_NODE = 2;
  #|     Node.TEXT_NODE = 3;
  #|     Node.CDATA_SECTION_NODE = 4;
  #|     Node.PROCESSING_INSTRUCTION_NODE = 7;
  #|     Node.COMMENT_NODE = 8;
  #|     Node.DOCUMENT_NODE = 9;
  #|     Node.DOCUMENT_TYPE_NODE = 10;
  #|     Node.DOCUMENT_FRAGMENT_NODE = 11;
  #|     Node.DOCUMENT_POSITION_DISCONNECTED = 1;
  #|     Node.DOCUMENT_POSITION_PRECEDING = 2;
  #|     Node.DOCUMENT_POSITION_FOLLOWING = 4;
  #|     Node.DOCUMENT_POSITION_CONTAINS = 8;
  #|     Node.DOCUMENT_POSITION_CONTAINED_BY = 16;
  #|     Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 32;
  #|
  #|     function CharacterData() {}
  #|     CharacterData.prototype = Object.create(Node.prototype);
  #|     CharacterData.prototype.constructor = CharacterData;
  #|
  #|     function Element() {}
  #|     Element.prototype = Object.create(Node.prototype);
  #|     Element.prototype.constructor = Element;
  #|
  #|     function HTMLElement() {}
  #|     HTMLElement.prototype = Object.create(Element.prototype);
  #|     HTMLElement.prototype.constructor = HTMLElement;
  #|
  #|     function HTMLHtmlElement() {}
  #|     HTMLHtmlElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHtmlElement.prototype.constructor = HTMLHtmlElement;
  #|
  #|     function HTMLHeadElement() {}
  #|     HTMLHeadElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHeadElement.prototype.constructor = HTMLHeadElement;
  #|
  #|     function HTMLBodyElement() {}
  #|     HTMLBodyElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLBodyElement.prototype.constructor = HTMLBodyElement;
  #|
  #|     function HTMLDivElement() {}
  #|     HTMLDivElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDivElement.prototype.constructor = HTMLDivElement;
  #|
  #|     function HTMLSpanElement() {}
  #|     HTMLSpanElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSpanElement.prototype.constructor = HTMLSpanElement;
  #|
  #|     function HTMLTitleElement() {}
  #|     HTMLTitleElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTitleElement.prototype.constructor = HTMLTitleElement;
  #|
  #|     function HTMLAnchorElement() {}
  #|     HTMLAnchorElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLAnchorElement.prototype.constructor = HTMLAnchorElement;
  #|
  #|     function HTMLAreaElement() {}
  #|     HTMLAreaElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLAreaElement.prototype.constructor = HTMLAreaElement;
  #|
  #|     function HTMLAudioElement() {}
  #|     HTMLAudioElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLAudioElement.prototype.constructor = HTMLAudioElement;
  #|
  #|     function HTMLBaseElement() {}
  #|     HTMLBaseElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLBaseElement.prototype.constructor = HTMLBaseElement;
  #|
  #|     function HTMLBRElement() {}
  #|     HTMLBRElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLBRElement.prototype.constructor = HTMLBRElement;
  #|
  #|     function HTMLButtonElement() {}
  #|     HTMLButtonElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLButtonElement.prototype.constructor = HTMLButtonElement;
  #|
  #|     function HTMLCanvasElement() {}
  #|     HTMLCanvasElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLCanvasElement.prototype.constructor = HTMLCanvasElement;
  #|
  #|     function HTMLDataElement() {}
  #|     HTMLDataElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDataElement.prototype.constructor = HTMLDataElement;
  #|
  #|     function HTMLDataListElement() {}
  #|     HTMLDataListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDataListElement.prototype.constructor = HTMLDataListElement;
  #|
  #|     function HTMLDetailsElement() {}
  #|     HTMLDetailsElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDetailsElement.prototype.constructor = HTMLDetailsElement;
  #|
  #|     function HTMLDialogElement() {}
  #|     HTMLDialogElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDialogElement.prototype.constructor = HTMLDialogElement;
  #|
  #|     function HTMLDListElement() {}
  #|     HTMLDListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDListElement.prototype.constructor = HTMLDListElement;
  #|
  #|     function HTMLEmbedElement() {}
  #|     HTMLEmbedElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLEmbedElement.prototype.constructor = HTMLEmbedElement;
  #|
  #|     function HTMLFieldSetElement() {}
  #|     HTMLFieldSetElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFieldSetElement.prototype.constructor = HTMLFieldSetElement;
  #|
  #|     function HTMLFormElement() {}
  #|     HTMLFormElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFormElement.prototype.constructor = HTMLFormElement;
  #|
  #|     function HTMLHRElement() {}
  #|     HTMLHRElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHRElement.prototype.constructor = HTMLHRElement;
  #|
  #|     function HTMLIFrameElement() {}
  #|     HTMLIFrameElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLIFrameElement.prototype.constructor = HTMLIFrameElement;
  #|
  #|     function HTMLImageElement() {}
  #|     HTMLImageElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLImageElement.prototype.constructor = HTMLImageElement;
  #|
  #|     function HTMLInputElement() {}
  #|     HTMLInputElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLInputElement.prototype.constructor = HTMLInputElement;
  #|
  #|     function HTMLLabelElement() {}
  #|     HTMLLabelElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLabelElement.prototype.constructor = HTMLLabelElement;
  #|
  #|     function HTMLLegendElement() {}
  #|     HTMLLegendElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLegendElement.prototype.constructor = HTMLLegendElement;
  #|
  #|     function HTMLLIElement() {}
  #|     HTMLLIElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLIElement.prototype.constructor = HTMLLIElement;
  #|
  #|     function HTMLLinkElement() {}
  #|     HTMLLinkElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLLinkElement.prototype.constructor = HTMLLinkElement;
  #|
  #|     function HTMLMapElement() {}
  #|     HTMLMapElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMapElement.prototype.constructor = HTMLMapElement;
  #|
  #|     function HTMLMenuElement() {}
  #|     HTMLMenuElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMenuElement.prototype.constructor = HTMLMenuElement;
  #|
  #|     function HTMLMetaElement() {}
  #|     HTMLMetaElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMetaElement.prototype.constructor = HTMLMetaElement;
  #|
  #|     function HTMLMeterElement() {}
  #|     HTMLMeterElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMeterElement.prototype.constructor = HTMLMeterElement;
  #|
  #|     function HTMLModElement() {}
  #|     HTMLModElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLModElement.prototype.constructor = HTMLModElement;
  #|
  #|     function HTMLObjectElement() {}
  #|     HTMLObjectElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLObjectElement.prototype.constructor = HTMLObjectElement;
  #|
  #|     function HTMLOListElement() {}
  #|     HTMLOListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOListElement.prototype.constructor = HTMLOListElement;
  #|
  #|     function HTMLOptGroupElement() {}
  #|     HTMLOptGroupElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOptGroupElement.prototype.constructor = HTMLOptGroupElement;
  #|
  #|     function HTMLOptionElement() {}
  #|     HTMLOptionElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOptionElement.prototype.constructor = HTMLOptionElement;
  #|
  #|     function HTMLOutputElement() {}
  #|     HTMLOutputElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLOutputElement.prototype.constructor = HTMLOutputElement;
  #|
  #|     function HTMLParagraphElement() {}
  #|     HTMLParagraphElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLParagraphElement.prototype.constructor = HTMLParagraphElement;
  #|
  #|     function HTMLPictureElement() {}
  #|     HTMLPictureElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLPictureElement.prototype.constructor = HTMLPictureElement;
  #|
  #|     function HTMLPreElement() {}
  #|     HTMLPreElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLPreElement.prototype.constructor = HTMLPreElement;
  #|
  #|     function HTMLProgressElement() {}
  #|     HTMLProgressElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLProgressElement.prototype.constructor = HTMLProgressElement;
  #|
  #|     function HTMLQuoteElement() {}
  #|     HTMLQuoteElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLQuoteElement.prototype.constructor = HTMLQuoteElement;
  #|
  #|     function HTMLScriptElement() {}
  #|     HTMLScriptElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLScriptElement.prototype.constructor = HTMLScriptElement;
  #|
  #|     function HTMLSelectElement() {}
  #|     HTMLSelectElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSelectElement.prototype.constructor = HTMLSelectElement;
  #|
  #|     function HTMLSlotElement() {}
  #|     HTMLSlotElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSlotElement.prototype.constructor = HTMLSlotElement;
  #|
  #|     function HTMLSourceElement() {}
  #|     HTMLSourceElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLSourceElement.prototype.constructor = HTMLSourceElement;
  #|
  #|     function HTMLStyleElement() {}
  #|     HTMLStyleElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLStyleElement.prototype.constructor = HTMLStyleElement;
  #|
  #|     function HTMLTableElement() {}
  #|     HTMLTableElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableElement.prototype.constructor = HTMLTableElement;
  #|
  #|     function HTMLTableCellElement() {}
  #|     HTMLTableCellElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableCellElement.prototype.constructor = HTMLTableCellElement;
  #|
  #|     function HTMLTableColElement() {}
  #|     HTMLTableColElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableColElement.prototype.constructor = HTMLTableColElement;
  #|
  #|     function HTMLTableRowElement() {}
  #|     HTMLTableRowElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableRowElement.prototype.constructor = HTMLTableRowElement;
  #|
  #|     function HTMLTableSectionElement() {}
  #|     HTMLTableSectionElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableSectionElement.prototype.constructor = HTMLTableSectionElement;
  #|
  #|     function HTMLTemplateElement() {}
  #|     HTMLTemplateElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTemplateElement.prototype.constructor = HTMLTemplateElement;
  #|
  #|     function HTMLTextAreaElement() {}
  #|     HTMLTextAreaElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTextAreaElement.prototype.constructor = HTMLTextAreaElement;
  #|
  #|     function HTMLTimeElement() {}
  #|     HTMLTimeElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTimeElement.prototype.constructor = HTMLTimeElement;
  #|
  #|     function HTMLTrackElement() {}
  #|     HTMLTrackElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTrackElement.prototype.constructor = HTMLTrackElement;
  #|
  #|     function HTMLUListElement() {}
  #|     HTMLUListElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLUListElement.prototype.constructor = HTMLUListElement;
  #|
  #|     function HTMLVideoElement() {}
  #|     HTMLVideoElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLVideoElement.prototype.constructor = HTMLVideoElement;
  #|
  #|     function HTMLUnknownElement() {}
  #|     HTMLUnknownElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLUnknownElement.prototype.constructor = HTMLUnknownElement;
  #|
  #|     function HTMLTableCaptionElement() {}
  #|     HTMLTableCaptionElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLTableCaptionElement.prototype.constructor = HTMLTableCaptionElement;
  #|
  #|     function HTMLDirectoryElement() {}
  #|     HTMLDirectoryElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLDirectoryElement.prototype.constructor = HTMLDirectoryElement;
  #|
  #|     function HTMLFontElement() {}
  #|     HTMLFontElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFontElement.prototype.constructor = HTMLFontElement;
  #|
  #|     function HTMLMarqueeElement() {}
  #|     HTMLMarqueeElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLMarqueeElement.prototype.constructor = HTMLMarqueeElement;
  #|
  #|     function HTMLFrameElement() {}
  #|     HTMLFrameElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFrameElement.prototype.constructor = HTMLFrameElement;
  #|
  #|     function HTMLFrameSetElement() {}
  #|     HTMLFrameSetElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLFrameSetElement.prototype.constructor = HTMLFrameSetElement;
  #|
  #|     function HTMLParamElement() {}
  #|     HTMLParamElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLParamElement.prototype.constructor = HTMLParamElement;
  #|
  #|     function HTMLHeadingElement() {}
  #|     HTMLHeadingElement.prototype = Object.create(HTMLElement.prototype);
  #|     HTMLHeadingElement.prototype.constructor = HTMLHeadingElement;
  #|
  #|     // Tag to constructor mapping
  #|     const tagToConstructor = {
  #|       'html': HTMLHtmlElement,
  #|       'head': HTMLHeadElement,
  #|       'body': HTMLBodyElement,
  #|       'div': HTMLDivElement,
  #|       'span': HTMLSpanElement,
  #|       'title': HTMLTitleElement,
  #|       'a': HTMLAnchorElement,
  #|       'area': HTMLAreaElement,
  #|       'audio': HTMLAudioElement,
  #|       'base': HTMLBaseElement,
  #|       'br': HTMLBRElement,
  #|       'button': HTMLButtonElement,
  #|       'canvas': HTMLCanvasElement,
  #|       'data': HTMLDataElement,
  #|       'datalist': HTMLDataListElement,
  #|       'details': HTMLDetailsElement,
  #|       'dialog': HTMLDialogElement,
  #|       'dl': HTMLDListElement,
  #|       'embed': HTMLEmbedElement,
  #|       'fieldset': HTMLFieldSetElement,
  #|       'form': HTMLFormElement,
  #|       'h1': HTMLHeadingElement,
  #|       'h2': HTMLHeadingElement,
  #|       'h3': HTMLHeadingElement,
  #|       'h4': HTMLHeadingElement,
  #|       'h5': HTMLHeadingElement,
  #|       'h6': HTMLHeadingElement,
  #|       'hr': HTMLHRElement,
  #|       'iframe': HTMLIFrameElement,
  #|       'img': HTMLImageElement,
  #|       'input': HTMLInputElement,
  #|       'label': HTMLLabelElement,
  #|       'legend': HTMLLegendElement,
  #|       'li': HTMLLIElement,
  #|       'link': HTMLLinkElement,
  #|       'map': HTMLMapElement,
  #|       'menu': HTMLMenuElement,
  #|       'meta': HTMLMetaElement,
  #|       'meter': HTMLMeterElement,
  #|       'del': HTMLModElement,
  #|       'ins': HTMLModElement,
  #|       'object': HTMLObjectElement,
  #|       'ol': HTMLOListElement,
  #|       'optgroup': HTMLOptGroupElement,
  #|       'option': HTMLOptionElement,
  #|       'output': HTMLOutputElement,
  #|       'p': HTMLParagraphElement,
  #|       'picture': HTMLPictureElement,
  #|       'pre': HTMLPreElement,
  #|       'progress': HTMLProgressElement,
  #|       'blockquote': HTMLQuoteElement,
  #|       'q': HTMLQuoteElement,
  #|       'script': HTMLScriptElement,
  #|       'select': HTMLSelectElement,
  #|       'slot': HTMLSlotElement,
  #|       'source': HTMLSourceElement,
  #|       'style': HTMLStyleElement,
  #|       'table': HTMLTableElement,
  #|       'td': HTMLTableCellElement,
  #|       'th': HTMLTableCellElement,
  #|       'col': HTMLTableColElement,
  #|       'colgroup': HTMLTableColElement,
  #|       'tr': HTMLTableRowElement,
  #|       'thead': HTMLTableSectionElement,
  #|       'tbody': HTMLTableSectionElement,
  #|       'tfoot': HTMLTableSectionElement,
  #|       'template': HTMLTemplateElement,
  #|       'textarea': HTMLTextAreaElement,
  #|       'time': HTMLTimeElement,
  #|       'track': HTMLTrackElement,
  #|       'ul': HTMLUListElement,
  #|       'video': HTMLVideoElement,
  #|       'caption': HTMLTableCaptionElement,
  #|       'dir': HTMLDirectoryElement,
  #|       'font': HTMLFontElement,
  #|       'marquee': HTMLMarqueeElement,
  #|       'frame': HTMLFrameElement,
  #|       'frameset': HTMLFrameSetElement,
  #|       'param': HTMLParamElement
  #|     };
  #|
  #|     function Document() {}
  #|     Document.prototype = Object.create(Node.prototype);
  #|     Document.prototype.constructor = Document;
  #|
  #|     function DocumentType() {}
  #|     DocumentType.prototype = Object.create(Node.prototype);
  #|     DocumentType.prototype.constructor = DocumentType;
  #|
  #|     function DocumentFragment() {}
  #|     DocumentFragment.prototype = Object.create(Node.prototype);
  #|     DocumentFragment.prototype.constructor = DocumentFragment;
  #|
  #|     // Text constructor
  #|     function Text(data) {
  #|       if (!(this instanceof Text)) throw new TypeError("Failed to construct 'Text': Please use the 'new' operator");
  #|       const str = data === undefined ? '' : String(data);
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createTextNode', id, text: str });
  #|       const node = createMockTextNode(str, id);
  #|       Object.setPrototypeOf(node, Text.prototype);
  #|       return node;
  #|     }
  #|     Text.prototype = Object.create(CharacterData.prototype);
  #|     Text.prototype.constructor = Text;
  #|
  #|     // Comment constructor
  #|     function Comment(data) {
  #|       if (!(this instanceof Comment)) throw new TypeError("Failed to construct 'Comment': Please use the 'new' operator");
  #|       const str = data === undefined ? '' : String(data);
  #|       const id = nodeIdCounter++;
  #|       domOps.push({ op: 'createComment', id, text: str });
  #|       const node = createMockComment(str, id);
  #|       Object.setPrototypeOf(node, Comment.prototype);
  #|       return node;
  #|     }
  #|     Comment.prototype = Object.create(CharacterData.prototype);
  #|     Comment.prototype.constructor = Comment;
  #|
  #|     function createMockElement(tagName, mockId) {
  #|       const el = {
  #|         _mockId: mockId,
  #|         _tagName: tagName.toUpperCase(),
  #|         _attrList: [], // Array of {ns, localName, prefix, name, value}
  #|         _textContent: '',
  #|         _children: [],
  #|         _parent: null,
  #|         _nodeType: 1,
  #|         get nodeType() { return this._nodeType; },
  #|         get nodeName() { return this._tagName; },
  #|         get nodeValue() { return null; },
  #|         set nodeValue(v) {},
  #|         get tagName() { return this._tagName; },
  #|         get localName() { return this._tagName.toLowerCase(); },
  #|         get namespaceURI() { return 'http://www.w3.org/1999/xhtml'; },
  #|         get prefix() { return null; },
  #|         get baseURI() { return 'about:blank'; },
  #|         get ownerDocument() { return document; },
  #|         get isConnected() {
  #|           let node = this;
  #|           while (node._parent) node = node._parent;
  #|           return node._tagName === 'HTML';
  #|         },
  #|         getRootNode() {
  #|           let node = this;
  #|           while (node._parent) node = node._parent;
  #|           return node;
  #|         },
  #|         // Legacy _attrs getter for backwards compatibility
  #|         get _attrs() {
  #|           const obj = {};
  #|           for (const attr of this._attrList) {
  #|             obj[attr.localName] = attr.value;
  #|           }
  #|           return obj;
  #|         },
  #|         get slot() { return this.getAttribute('slot') || ''; },
  #|         set slot(v) { this.setAttribute('slot', v); },
  #|         setAttribute(name, value) {
  #|           // Validate attribute name - empty string is invalid
  #|           if (name === '') {
  #|             throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|           }
  #|           // HTML elements lowercase attribute names (for qualified name matching)
  #|           const lowerName = name.toLowerCase();
  #|           const strValue = String(value);
  #|           // Find first existing attr with matching qualified name (case-insensitive)
  #|           const idx = this._attrList.findIndex(a => a.name.toLowerCase() === lowerName);
  #|           if (idx >= 0) {
  #|             this._attrList[idx].value = strValue;
  #|           } else {
  #|             this._attrList.push({ ns: null, localName: lowerName, prefix: null, name: lowerName, value: strValue });
  #|           }
  #|           domOps.push({ op: 'setAttribute', id: this._mockId, name: lowerName, value: strValue });
  #|         },
  #|         getAttribute(name) {
  #|           const lowerName = name.toLowerCase();
  #|           // Find first attr with matching name (case-insensitive for HTML)
  #|           const attr = this._attrList.find(a => a.name.toLowerCase() === lowerName);
  #|           return attr ? attr.value : null;
  #|         },
  #|         removeAttribute(name) {
  #|           const lowerName = name.toLowerCase();
  #|           // Remove first attr with matching name (case-insensitive for HTML)
  #|           const idx = this._attrList.findIndex(a => a.name.toLowerCase() === lowerName);
  #|           if (idx >= 0) {
  #|             this._attrList.splice(idx, 1);
  #|           }
  #|           domOps.push({ op: 'removeAttribute', id: this._mockId, name: lowerName });
  #|         },
  #|         hasAttribute(name) {
  #|           const lowerName = name.toLowerCase();
  #|           return this._attrList.some(a => a.name.toLowerCase() === lowerName);
  #|         },
  #|         hasAttributes() { return this._attrList.length > 0; },
  #|         getAttributeNames() { return this._attrList.map(a => a.name); },
  #|         get attributes() {
  #|           const self = this;
  #|           const items = this._attrList.map(function(a) {
  #|             const attr = {
  #|               name: a.name,
  #|               value: a.value,
  #|               localName: a.localName,
  #|               nodeName: a.name,
  #|               nodeValue: a.value,
  #|               textContent: a.value,
  #|               namespaceURI: a.ns,
  #|               prefix: a.prefix,
  #|               ownerElement: self,
  #|               specified: true,
  #|               nodeType: 2,
  #|               _nodeType: 2
  #|             };
  #|             attr.isSameNode = function(other) { return this === other; };
  #|             attr.isEqualNode = function(other) { return other && other._nodeType === 2 && other.name === this.name && other.value === this.value && other.namespaceURI === this.namespaceURI; };
  #|             return attr;
  #|           });
  #|           const namedNodeMap = {
  #|             length: items.length,
  #|             item(i) { return items[i] || null; },
  #|             getNamedItem(name) {
  #|               const lowerName = name.toLowerCase();
  #|               return items.find(function(a) { return a.name.toLowerCase() === lowerName; }) || null;
  #|             },
  #|             getNamedItemNS(ns, localName) {
  #|               const normalNs = (ns === '' || ns === null) ? null : ns;
  #|               return items.find(function(a) {
  #|                 const attrNs = (a.namespaceURI === '' || a.namespaceURI === null) ? null : a.namespaceURI;
  #|                 return attrNs === normalNs && a.localName === localName;
  #|               }) || null;
  #|             },
  #|             setNamedItem(attr) { self.setAttribute(attr.name, attr.value); return attr; },
  #|             removeNamedItem(name) { const old = this.getNamedItem(name); self.removeAttribute(name); return old; },
  #|             [Symbol.iterator]() { return items[Symbol.iterator](); }
  #|           };
  #|           // Add numeric index access
  #|           for (let i = 0; i < items.length; i++) {
  #|             namedNodeMap[i] = items[i];
  #|           }
  #|           return namedNodeMap;
  #|         },
  #|         getAttributeNS(ns, localName) {
  #|           // NS methods match by (namespace, localName) - case-sensitive
  #|           // Treat null and "" as equivalent namespace
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           const attr = this._attrList.find(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|           return attr ? attr.value : null;
  #|         },
  #|         setAttributeNS(ns, qualifiedName, value) {
  #|           // Validate qualifiedName - empty string is invalid
  #|           if (qualifiedName === '') {
  #|             throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|           }
  #|           // Normalize namespace (treat "" as null)
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           // Extract localName and prefix from qualifiedName
  #|           const colonIdx = qualifiedName.indexOf(':');
  #|           const localName = colonIdx >= 0 ? qualifiedName.slice(colonIdx + 1) : qualifiedName;
  #|           const prefix = colonIdx >= 0 ? qualifiedName.slice(0, colonIdx) : null;
  #|           const strValue = String(value);
  #|           // Find existing attr with same (namespace, localName)
  #|           const idx = this._attrList.findIndex(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|           if (idx >= 0) {
  #|             this._attrList[idx].value = strValue;
  #|             this._attrList[idx].prefix = prefix;
  #|             this._attrList[idx].name = qualifiedName;
  #|           } else {
  #|             this._attrList.push({ ns: normalNs, localName: localName, prefix: prefix, name: qualifiedName, value: strValue });
  #|           }
  #|           domOps.push({ op: 'setAttribute', id: this._mockId, name: qualifiedName, value: strValue });
  #|         },
  #|         removeAttributeNS(ns, localName) {
  #|           // NS methods match by (namespace, localName) - case-sensitive
  #|           // Treat null and "" as equivalent namespace
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           const idx = this._attrList.findIndex(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|           if (idx >= 0) {
  #|             this._attrList.splice(idx, 1);
  #|           }
  #|           domOps.push({ op: 'removeAttribute', id: this._mockId, name: localName });
  #|         },
  #|         hasAttributeNS(ns, localName) {
  #|           // NS methods match by (namespace, localName) - case-sensitive
  #|           // Treat null and "" as equivalent namespace
  #|           const normalNs = (ns === '' || ns === null) ? null : ns;
  #|           return this._attrList.some(a => {
  #|             const attrNs = (a.ns === '' || a.ns === null) ? null : a.ns;
  #|             return attrNs === normalNs && a.localName === localName;
  #|           });
  #|         },
  #|         getAttributeNode(name) { return this.attributes.getNamedItem(name); },
  #|         getAttributeNodeNS(ns, name) { return this.getAttributeNode(name); },
  #|         setAttributeNode(attr) { this.setAttribute(attr.name, attr.value); return attr; },
  #|         setAttributeNodeNS(attr) { return this.setAttributeNode(attr); },
  #|         removeAttributeNode(attr) { this.removeAttribute(attr.name); return attr; },
  #|         toggleAttribute(name, force) {
  #|           // Validate name - empty string is invalid
  #|           if (name === '') {
  #|             throw new DOMException('Invalid character in attribute name', 'InvalidCharacterError');
  #|           }
  #|           // HTML elements lowercase attribute names
  #|           const lowerName = name.toLowerCase();
  #|           if (force === undefined) {
  #|             if (this.hasAttribute(lowerName)) { this.removeAttribute(lowerName); return false; }
  #|             else { this.setAttribute(lowerName, ''); return true; }
  #|           }
  #|           if (force) { this.setAttribute(lowerName, ''); return true; }
  #|           else { this.removeAttribute(lowerName); return false; }
  #|         },
  #|         get id() { return this.getAttribute('id') || ''; },
  #|         set id(v) { this.setAttribute('id', v); },
  #|         get className() { return this.getAttribute('class') || ''; },
  #|         set className(v) { this.setAttribute('class', v); },
  #|         get classList() {
  #|           const self = this;
  #|           return {
  #|             _getClasses() { return (self.getAttribute('class') || '').split(/\\s+/).filter(Boolean); },
  #|             add(...classes) { const c = new Set(this._getClasses()); classes.forEach(x => c.add(x)); self.className = [...c].join(' '); },
  #|             remove(...classes) { const c = new Set(this._getClasses()); classes.forEach(x => c.delete(x)); self.className = [...c].join(' '); },
  #|             toggle(cls, force) { if (force === undefined) force = !this.contains(cls); if (force) this.add(cls); else this.remove(cls); return force; },
  #|             contains(cls) { return this._getClasses().includes(cls); },
  #|             item(idx) { return this._getClasses()[idx] || null; },
  #|             get length() { return this._getClasses().length; },
  #|             get value() { return self.getAttribute('class') || ''; },
  #|             set value(v) { self.className = v; },
  #|             toString() { return self.getAttribute('class') || ''; },
  #|             [Symbol.iterator]() { return this._getClasses()[Symbol.iterator](); }
  #|           };
  #|         },
  #|         get textContent() {
  #|           // Collect text content from Text node descendants only
  #|           const collectText = (node) => {
  #|             if (node._nodeType === 3) return node._textContent;
  #|             if (!node._children) return '';
  #|             return node._children.map(collectText).join('');
  #|           };
  #|           return collectText(this);
  #|         },
  #|         set textContent(v) {
  #|           const str = (v === null || v === undefined) ? '' : String(v);
  #|           // Remove all children
  #|           this._children.forEach(c => { c._parent = null; });
  #|           this._children = [];
  #|           // If non-empty, add a text node
  #|           if (str !== '') {
  #|             const textNode = document.createTextNode(str);
  #|             textNode._parent = this;
  #|             this._children.push(textNode);
  #|           }
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: str });
  #|         },
  #|         get innerHTML() { return this._children.map(c => c.outerHTML || c.textContent).join(''); },
  #|         get outerHTML() {
  #|           const attrs = this._attrList.map(function(a) { return ' ' + a.name + '="' + a.value + '"'; }).join('');
  #|           const inner = this.innerHTML || this._textContent;
  #|           const tag = this._tagName.toLowerCase();
  #|           return '<' + tag + attrs + '>' + inner + '</' + tag + '>';
  #|         },
  #|         appendChild(child) {
  #|           if (child && child._mockId !== undefined) {
  #|             if (child._parent) child._parent.removeChild(child);
  #|             this._children.push(child);
  #|             child._parent = this;
  #|             domOps.push({ op: 'appendChild', parentId: this._mockId, childId: child._mockId });
  #|           }
  #|           return child;
  #|         },
  #|         insertBefore(newChild, refChild) {
  #|           if (!newChild || newChild._mockId === undefined) return newChild;
  #|           if (refChild === null || refChild === undefined) return this.appendChild(newChild);
  #|           // DOM spec: if refChild === newChild, use newChild's next sibling
  #|           let actualRef = refChild;
  #|           if (refChild === newChild) {
  #|             actualRef = newChild.nextSibling;
  #|           }
  #|           if (newChild._parent) newChild._parent.removeChild(newChild);
  #|           if (actualRef === null || actualRef === undefined) {
  #|             return this.appendChild(newChild);
  #|           }
  #|           const idx = this._children.indexOf(actualRef);
  #|           if (idx >= 0) {
  #|             this._children.splice(idx, 0, newChild);
  #|             newChild._parent = this;
  #|             domOps.push({ op: 'insertBefore', parentId: this._mockId, childId: newChild._mockId, refId: actualRef._mockId });
  #|           } else {
  #|             // refChild not found, append
  #|             return this.appendChild(newChild);
  #|           }
  #|           return newChild;
  #|         },
  #|         removeChild(child) {
  #|           const idx = this._children.indexOf(child);
  #|           if (idx >= 0) {
  #|             this._children.splice(idx, 1);
  #|             child._parent = null;
  #|             domOps.push({ op: 'removeChild', parentId: this._mockId, childId: child._mockId });
  #|           }
  #|           return child;
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (!newChild || newChild._mockId === undefined) return oldChild;
  #|           if (!oldChild || oldChild._mockId === undefined) return oldChild;
  #|           const idx = this._children.indexOf(oldChild);
  #|           if (idx >= 0) {
  #|             if (newChild._parent) newChild._parent.removeChild(newChild);
  #|             this._children.splice(idx, 1, newChild);
  #|             oldChild._parent = null;
  #|             newChild._parent = this;
  #|             domOps.push({ op: 'replaceChild', parentId: this._mockId, childId: newChild._mockId, refId: oldChild._mockId });
  #|           }
  #|           return oldChild;
  #|         },
  #|         cloneNode(deep) {
  #|           const cloneElement = (el, isDeep) => {
  #|             if (el._nodeType === 3) {
  #|               const id = nodeIdCounter++;
  #|               domOps.push({ op: 'createTextNode', id, text: el._textContent });
  #|               return createMockTextNode(el._textContent, id);
  #|             }
  #|             if (el._nodeType === 8) {
  #|               const id = nodeIdCounter++;
  #|               domOps.push({ op: 'createComment', id, text: el._textContent });
  #|               return createMockComment(el._textContent, id);
  #|             }
  #|             if (el._nodeType === 11) {
  #|               const id = nodeIdCounter++;
  #|               domOps.push({ op: 'createDocumentFragment', id });
  #|               const frag = createMockDocumentFragment(id);
  #|               if (isDeep) {
  #|                 for (const child of el._children) {
  #|                   const clonedChild = cloneElement(child, true);
  #|                   frag._children.push(clonedChild);
  #|                   clonedChild._parent = frag;
  #|                 }
  #|               }
  #|               return frag;
  #|             }
  #|             const id = nodeIdCounter++;
  #|             domOps.push({ op: 'createElement', id, tagName: el._tagName });
  #|             const clone = createMockElement(el._tagName, id);
  #|             for (const attr of el._attrList) {
  #|               clone._attrList.push({ ns: attr.ns, localName: attr.localName, prefix: attr.prefix, name: attr.name, value: attr.value });
  #|               domOps.push({ op: 'setAttribute', id, name: attr.name, value: attr.value });
  #|             }
  #|             if (el._textContent && el._children.length === 0) {
  #|               clone._textContent = el._textContent;
  #|               domOps.push({ op: 'setTextContent', id, value: el._textContent });
  #|             }
  #|             if (isDeep && el._children) {
  #|               for (const child of el._children) {
  #|                 const clonedChild = cloneElement(child, true);
  #|                 clone._children.push(clonedChild);
  #|                 clonedChild._parent = clone;
  #|                 domOps.push({ op: 'appendChild', parentId: id, childId: clonedChild._mockId });
  #|               }
  #|             }
  #|             return clone;
  #|           };
  #|           return cloneElement(this, !!deep);
  #|         },
  #|         isEqualNode(other) {
  #|           if (!other) return false;
  #|           if (this._nodeType !== other._nodeType) return false;
  #|           if (this._tagName !== other._tagName) return false;
  #|           const attrs1 = Object.keys(this._attrs).sort();
  #|           const attrs2 = Object.keys(other._attrs || {}).sort();
  #|           if (attrs1.length !== attrs2.length) return false;
  #|           for (let i = 0; i < attrs1.length; i++) {
  #|             if (attrs1[i] !== attrs2[i] || this._attrs[attrs1[i]] !== other._attrs[attrs2[i]]) return false;
  #|           }
  #|           if (this._children.length !== (other._children || []).length) return false;
  #|           for (let i = 0; i < this._children.length; i++) {
  #|             if (!this._children[i].isEqualNode || !this._children[i].isEqualNode(other._children[i])) return false;
  #|           }
  #|           return true;
  #|         },
  #|         isSameNode(other) { return this === other; },
  #|         normalize() {
  #|           for (let i = this._children.length - 1; i >= 0; i--) {
  #|             const child = this._children[i];
  #|             if (child._nodeType === 3 && child._textContent === '') {
  #|               this._children.splice(i, 1);
  #|             } else if (child._nodeType === 3 && i > 0 && this._children[i-1]._nodeType === 3) {
  #|               this._children[i-1]._textContent += child._textContent;
  #|               this._children.splice(i, 1);
  #|             } else if (child.normalize) {
  #|               child.normalize();
  #|             }
  #|           }
  #|         },
  #|         compareDocumentPosition(other) {
  #|           if (this === other) return 0;
  #|           if (this.contains(other)) return 16;
  #|           if (other.contains && other.contains(this)) return 8;
  #|           return 4;
  #|         },
  #|         lookupPrefix(ns) {
  #|           if (ns === 'http://www.w3.org/1999/xhtml') return null;
  #|           return null;
  #|         },
  #|         lookupNamespaceURI(prefix) {
  #|           if (prefix === null || prefix === '') return 'http://www.w3.org/1999/xhtml';
  #|           return null;
  #|         },
  #|         isDefaultNamespace(ns) {
  #|           return ns === 'http://www.w3.org/1999/xhtml';
  #|         },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get firstChild() { return this._children[0] || null; },
  #|         get lastChild() { return this._children[this._children.length - 1] || null; },
  #|         get childNodes() { return [...this._children]; },
  #|         get children() { return this._children.filter(c => c._nodeType === 1); },
  #|         get firstElementChild() { return this._children.find(c => c._nodeType === 1) || null; },
  #|         get lastElementChild() { return [...this._children].reverse().find(c => c._nodeType === 1) || null; },
  #|         get childElementCount() { return this._children.filter(c => c._nodeType === 1).length; },
  #|         hasChildNodes() { return this._children.length > 0; },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return this._parent._children[idx + 1] || null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return idx > 0 ? this._parent._children[idx - 1] : null;
  #|         },
  #|         get nextElementSibling() {
  #|           let sib = this.nextSibling;
  #|           while (sib && sib._nodeType !== 1) sib = sib.nextSibling;
  #|           return sib;
  #|         },
  #|         get previousElementSibling() {
  #|           let sib = this.previousSibling;
  #|           while (sib && sib._nodeType !== 1) sib = sib.previousSibling;
  #|           return sib;
  #|         },
  #|         contains(node) {
  #|           if (!node) return false;
  #|           if (node === this) return true;
  #|           for (const child of this._children) {
  #|             if (child === node || (child.contains && child.contains(node))) return true;
  #|           }
  #|           return false;
  #|         },
  #|         matches(selector) {
  #|           if (selector.startsWith('#')) return this.getAttribute('id') === selector.slice(1);
  #|           if (selector.startsWith('.')) return this.classList.contains(selector.slice(1));
  #|           return this._tagName === selector.toUpperCase();
  #|         },
  #|         closest(selector) {
  #|           let node = this;
  #|           while (node) {
  #|             if (node.matches && node.matches(selector)) return node;
  #|             node = node._parent;
  #|           }
  #|           return null;
  #|         },
  #|         getElementsByTagName(tag) {
  #|           const results = [];
  #|           const search = (el) => {
  #|             for (const child of el._children) {
  #|               if (child._nodeType === 1) {
  #|                 if (tag === '*' || child._tagName === tag.toUpperCase()) results.push(child);
  #|                 search(child);
  #|               }
  #|             }
  #|           };
  #|           search(this);
  #|           return results;
  #|         },
  #|         getElementsByClassName(cls) {
  #|           const results = [];
  #|           const search = (el) => {
  #|             for (const child of el._children) {
  #|               if (child._nodeType === 1) {
  #|                 if (child.classList.contains(cls)) results.push(child);
  #|                 search(child);
  #|               }
  #|             }
  #|           };
  #|           search(this);
  #|           return results;
  #|         },
  #|         getElementsByTagNameNS(ns, tag) {
  #|           return this.getElementsByTagName(tag);
  #|         },
  #|         webkitMatchesSelector(selector) {
  #|           return this.matches(selector);
  #|         },
  #|         insertAdjacentElement(position, element) {
  #|           if (!element) return null;
  #|           const pos = String(position).toLowerCase();
  #|           switch (pos) {
  #|             case 'beforebegin': if (this._parent) this._parent.insertBefore(element, this); break;
  #|             case 'afterbegin': this.insertBefore(element, this.firstChild); break;
  #|             case 'beforeend': this.appendChild(element); break;
  #|             case 'afterend': if (this._parent) this._parent.insertBefore(element, this.nextSibling); break;
  #|             default: throw new DOMException("Invalid position: " + position, "SyntaxError");
  #|           }
  #|           return element;
  #|         },
  #|         insertAdjacentText(position, text) {
  #|           const node = document.createTextNode(text);
  #|           this.insertAdjacentElement(position, node);
  #|         },
  #|         insertAdjacentHTML(position, html) {
  #|           const temp = document.createElement('template');
  #|           temp._textContent = html;
  #|           this.insertAdjacentElement(position, temp);
  #|         },
  #|         get shadowRoot() { return this._shadowRoot || null; },
  #|         attachShadow(init) {
  #|           if (this._shadowRoot) throw new Error('Already has shadow root');
  #|           const shadow = { mode: init.mode, host: this, _children: [], appendChild(c) { this._children.push(c); return c; } };
  #|           this._shadowRoot = shadow;
  #|           return shadow;
  #|         },
  #|         focus() {},
  #|         blur() {},
  #|         click() {},
  #|         dispatchEvent(event) { return true; },
  #|         addEventListener(type, listener, options) {},
  #|         removeEventListener(type, listener, options) {},
  #|         querySelector(selector) {
  #|           const search = (el) => {
  #|             for (const child of el._children) {
  #|               if (child._nodeType === 1) {
  #|                 if (child.matches(selector)) return child;
  #|                 const found = search(child);
  #|                 if (found) return found;
  #|               }
  #|             }
  #|             return null;
  #|           };
  #|           return search(this);
  #|         },
  #|         querySelectorAll(selector) {
  #|           const results = [];
  #|           const search = (el) => {
  #|             for (const child of el._children) {
  #|               if (child._nodeType === 1) {
  #|                 if (child.matches(selector)) results.push(child);
  #|                 search(child);
  #|               }
  #|             }
  #|           };
  #|           search(this);
  #|           return results;
  #|         },
  #|         append(...nodes) {
  #|           for (const node of nodes) {
  #|             if (typeof node === 'string') {
  #|               const text = document.createTextNode(node);
  #|               this.appendChild(text);
  #|             } else {
  #|               this.appendChild(node);
  #|             }
  #|           }
  #|         },
  #|         prepend(...nodes) {
  #|           const first = this.firstChild;
  #|           for (const node of nodes) {
  #|             if (typeof node === 'string') {
  #|               const text = document.createTextNode(node);
  #|               this.insertBefore(text, first);
  #|             } else {
  #|               this.insertBefore(node, first);
  #|             }
  #|           }
  #|         },
  #|         remove() {
  #|           if (this._parent) this._parent.removeChild(this);
  #|         },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceChildren(...nodes) {
  #|           while (this._children.length > 0) this.removeChild(this._children[0]);
  #|           this.append(...nodes);
  #|         },
  #|         getBoundingClientRect() { return { x: 0, y: 0, width: 0, height: 0, top: 0, right: 0, bottom: 0, left: 0 }; },
  #|         get style() {
  #|           const self = this;
  #|           return new Proxy({}, {
  #|             get(_, prop) {
  #|               if (prop === 'cssText') return self._attrs.style || '';
  #|               return '';
  #|             },
  #|             set(_, prop, value) {
  #|               if (prop === 'cssText') {
  #|                 self.setAttribute('style', value);
  #|                 return true;
  #|               }
  #|               const style = self._attrs.style || '';
  #|               const propName = prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               self.setAttribute('style', style + propName + ':' + value + ';');
  #|               return true;
  #|             }
  #|           });
  #|         },
  #|         set style(v) {
  #|           // el.style = "string" sets the style attribute
  #|           this.setAttribute('style', String(v));
  #|         },
  #|         // HTMLElement properties
  #|         get title() { return this._attrs.title || ''; },
  #|         set title(v) { this.setAttribute('title', v); },
  #|         get lang() { return this._attrs.lang || ''; },
  #|         set lang(v) { this.setAttribute('lang', v); },
  #|         get translate() { return this._attrs.translate !== 'no'; },
  #|         set translate(v) { this.setAttribute('translate', v ? 'yes' : 'no'); },
  #|         get dir() { return this._attrs.dir || ''; },
  #|         set dir(v) { this.setAttribute('dir', v); },
  #|         get hidden() { return this.hasAttribute('hidden'); },
  #|         set hidden(v) { if (v) this.setAttribute('hidden', ''); else this.removeAttribute('hidden'); },
  #|         get inert() { return this.hasAttribute('inert'); },
  #|         set inert(v) { if (v) this.setAttribute('inert', ''); else this.removeAttribute('inert'); },
  #|         get accessKey() { return this._attrs.accesskey || ''; },
  #|         set accessKey(v) { this.setAttribute('accesskey', v); },
  #|         get accessKeyLabel() { return this._attrs.accesskey || ''; },
  #|         get draggable() { return this._attrs.draggable === 'true'; },
  #|         set draggable(v) { this.setAttribute('draggable', v ? 'true' : 'false'); },
  #|         get spellcheck() { return this._attrs.spellcheck !== 'false'; },
  #|         set spellcheck(v) { this.setAttribute('spellcheck', String(v)); },
  #|         get writingSuggestions() { return this._attrs.writingsuggestions || ''; },
  #|         set writingSuggestions(v) { this.setAttribute('writingsuggestions', v); },
  #|         get autocapitalize() { return this._attrs.autocapitalize || ''; },
  #|         set autocapitalize(v) { this.setAttribute('autocapitalize', v); },
  #|         get innerText() { return this.textContent; },
  #|         set innerText(v) { this.textContent = v; },
  #|         get outerText() { return this.textContent; },
  #|         set outerText(v) { this.textContent = v; },
  #|         get tabIndex() { return parseInt(this._attrs.tabindex) || 0; },
  #|         set tabIndex(v) { this.setAttribute('tabindex', String(v)); },
  #|         get contentEditable() { return this._attrs.contenteditable || 'inherit'; },
  #|         set contentEditable(v) { this.setAttribute('contenteditable', v); },
  #|         get isContentEditable() { return this._attrs.contenteditable === 'true'; },
  #|         _popoverState: 'hidden',
  #|         get popover() { return this._attrs.popover || null; },
  #|         set popover(v) { if (v) this.setAttribute('popover', v); else this.removeAttribute('popover'); },
  #|         showPopover() { this._popoverState = 'showing'; },
  #|         hidePopover() { this._popoverState = 'hidden'; },
  #|         togglePopover(force) {
  #|           if (force === undefined) {
  #|             this._popoverState = this._popoverState === 'showing' ? 'hidden' : 'showing';
  #|           } else {
  #|             this._popoverState = force ? 'showing' : 'hidden';
  #|           }
  #|           return this._popoverState === 'showing';
  #|         },
  #|         attachInternals() { return { shadowRoot: null, form: null, willValidate: false, validity: {}, validationMessage: '', labels: [] }; },
  #|         get offsetParent() { return this._parent; },
  #|         get offsetTop() { return 0; },
  #|         get offsetLeft() { return 0; },
  #|         get offsetWidth() { return 0; },
  #|         get offsetHeight() { return 0; },
  #|         get dataset() {
  #|           const self = this;
  #|           return new Proxy({}, {
  #|             get(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               return self._attrs[attrName] || undefined;
  #|             },
  #|             set(_, prop, value) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               self.setAttribute(attrName, value);
  #|               return true;
  #|             },
  #|             has(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               return attrName in self._attrs;
  #|             },
  #|             deleteProperty(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               self.removeAttribute(attrName);
  #|               return true;
  #|             },
  #|             ownKeys() {
  #|               return Object.keys(self._attrs)
  #|                 .filter(function(k) { return k.startsWith('data-'); })
  #|                 .map(function(k) { return k.slice(5).replace(/-([a-z])/g, function(_, c) { return c.toUpperCase(); }); });
  #|             },
  #|             getOwnPropertyDescriptor(_, prop) {
  #|               const attrName = 'data-' + prop.replace(/([A-Z])/g, '-$1').toLowerCase();
  #|               if (attrName in self._attrs) {
  #|                 return { enumerable: true, configurable: true, value: self._attrs[attrName] };
  #|               }
  #|             }
  #|           });
  #|         }
  #|       };
  #|       mockElements.set(mockId, el);
  #|       return el;
  #|     }
  #|
  #|     function createMockTextNode(text, mockId) {
  #|       const node = {
  #|         _mockId: mockId,
  #|         _tagName: '#text',
  #|         _textContent: text,
  #|         _parent: null,
  #|         _nodeType: 3,
  #|         get nodeType() { return 3; },
  #|         get nodeName() { return '#text'; },
  #|         get ownerDocument() { return document; },
  #|         get isConnected() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n._tagName === 'HTML';
  #|         },
  #|         getRootNode(options) {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n;
  #|         },
  #|         get textContent() { return this._textContent; },
  #|         set textContent(v) {
  #|           this._textContent = String(v);
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: String(v) });
  #|         },
  #|         get nodeValue() { return this._textContent; },
  #|         set nodeValue(v) { this.data = v; },
  #|         get data() { return this._textContent; },
  #|         set data(v) {
  #|           const str = v === null ? '' : String(v);
  #|           this._textContent = str;
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: str });
  #|         },
  #|         get length() { return this._textContent.length; },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get firstChild() { return null; },
  #|         get lastChild() { return null; },
  #|         get childNodes() { return []; },
  #|         hasChildNodes() { return false; },
  #|         appendChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot appendChild to a Text node', 'HierarchyRequestError');
  #|         },
  #|         insertBefore(child, ref) {
  #|           if (child === null) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot insertBefore on a Text node', 'HierarchyRequestError');
  #|         },
  #|         removeChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot removeChild from a Text node', 'NotFoundError');
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (newChild === null) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot replaceChild on a Text node', 'HierarchyRequestError');
  #|         },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return this._parent._children[idx + 1] || null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return idx > 0 ? this._parent._children[idx - 1] : null;
  #|         },
  #|         cloneNode() {
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createTextNode', id, text: this._textContent });
  #|           return createMockTextNode(this._textContent, id);
  #|         },
  #|         remove() { if (this._parent) this._parent.removeChild(this); },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         splitText(offset) {
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           const newText = this._textContent.slice(offset);
  #|           this._textContent = this._textContent.slice(0, offset);
  #|           domOps.push({ op: 'setTextContent', id: this._mockId, value: this._textContent });
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createTextNode', id, text: newText });
  #|           const newNode = createMockTextNode(newText, id);
  #|           if (this._parent) {
  #|             const idx = this._parent._children.indexOf(this);
  #|             this._parent._children.splice(idx + 1, 0, newNode);
  #|             newNode._parent = this._parent;
  #|             domOps.push({ op: 'insertBefore', parentId: this._parent._mockId, childId: newNode._mockId, refId: this.nextSibling ? this.nextSibling._mockId : 0 });
  #|           }
  #|           return newNode;
  #|         },
  #|         get wholeText() {
  #|           let text = this._textContent;
  #|           let sib = this.previousSibling;
  #|           while (sib && sib._nodeType === 3) { text = sib._textContent + text; sib = sib.previousSibling; }
  #|           sib = this.nextSibling;
  #|           while (sib && sib._nodeType === 3) { text = text + sib._textContent; sib = sib.nextSibling; }
  #|           return text;
  #|         },
  #|         substringData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'substringData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           return this._textContent.substr(offset, count);
  #|         },
  #|         appendData(data) {
  #|           if (arguments.length < 1) throw new TypeError("Failed to execute 'appendData': 1 argument required");
  #|           this.textContent = this._textContent + String(data);
  #|         },
  #|         insertData(offset, data) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'insertData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           this.textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset);
  #|         },
  #|         deleteData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'deleteData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this.textContent = this._textContent.slice(0, offset) + this._textContent.slice(offset + count);
  #|         },
  #|         replaceData(offset, count, data) {
  #|           if (arguments.length < 3) throw new TypeError("Failed to execute 'replaceData': 3 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this.textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset + count);
  #|         },
  #|         normalize() {},
  #|         isEqualNode(other) { return other && other._nodeType === 3 && other._textContent === this._textContent; },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, node);
  #|       return node;
  #|     }
  #|
  #|     function createMockComment(text, mockId) {
  #|       const node = {
  #|         _mockId: mockId,
  #|         _tagName: '#comment',
  #|         _textContent: text,
  #|         _parent: null,
  #|         _nodeType: 8,
  #|         _children: [],
  #|         get nodeType() { return 8; },
  #|         get nodeName() { return '#comment'; },
  #|         get ownerDocument() { return document; },
  #|         get textContent() { return this._textContent; },
  #|         set textContent(v) { this.data = v; },
  #|         get nodeValue() { return this._textContent; },
  #|         set nodeValue(v) { this.data = v; },
  #|         get data() { return this._textContent; },
  #|         set data(v) { this._textContent = v === null ? '' : String(v); },
  #|         get length() { return this._textContent.length; },
  #|         get outerHTML() { return '<!--' + this._textContent + '-->'; },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get firstChild() { return null; },
  #|         get lastChild() { return null; },
  #|         get childNodes() { return []; },
  #|         hasChildNodes() { return false; },
  #|         appendChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot appendChild to a Comment node', 'HierarchyRequestError');
  #|         },
  #|         insertBefore(child, ref) {
  #|           if (child === null) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot insertBefore on a Comment node', 'HierarchyRequestError');
  #|         },
  #|         removeChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute removeChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot removeChild from a Comment node', 'NotFoundError');
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (newChild === null) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot replaceChild on a Comment node', 'HierarchyRequestError');
  #|         },
  #|         get isConnected() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n._tagName === 'HTML';
  #|         },
  #|         getRootNode() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n;
  #|         },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return this._parent._children[idx + 1] || null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return idx > 0 ? this._parent._children[idx - 1] : null;
  #|         },
  #|         substringData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'substringData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           return this._textContent.substr(offset, count);
  #|         },
  #|         appendData(data) {
  #|           if (arguments.length < 1) throw new TypeError("Failed to execute 'appendData': 1 argument required");
  #|           this._textContent = this._textContent + String(data);
  #|         },
  #|         insertData(offset, data) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'insertData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset);
  #|         },
  #|         deleteData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'deleteData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + this._textContent.slice(offset + count);
  #|         },
  #|         replaceData(offset, count, data) {
  #|           if (arguments.length < 3) throw new TypeError("Failed to execute 'replaceData': 3 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset + count);
  #|         },
  #|         cloneNode() {
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createComment', id, text: this._textContent });
  #|           return createMockComment(this._textContent, id);
  #|         },
  #|         remove() { if (this._parent) this._parent.removeChild(this); },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         isEqualNode(other) { return other && other._nodeType === 8 && other._textContent === this._textContent; },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, node);
  #|       return node;
  #|     }
  #|
  #|     function createMockProcessingInstruction(target, data, mockId) {
  #|       const node = {
  #|         _mockId: mockId,
  #|         _tagName: target,
  #|         _textContent: data,
  #|         _target: target,
  #|         _parent: null,
  #|         _nodeType: 7,
  #|         _children: [],
  #|         get nodeType() { return 7; },
  #|         get nodeName() { return this._target; },
  #|         get target() { return this._target; },
  #|         get ownerDocument() { return document; },
  #|         get textContent() { return this._textContent; },
  #|         set textContent(v) { this.data = v; },
  #|         get nodeValue() { return this._textContent; },
  #|         set nodeValue(v) { this.data = v; },
  #|         get data() { return this._textContent; },
  #|         set data(v) { this._textContent = v === null ? '' : String(v); },
  #|         get length() { return this._textContent.length; },
  #|         get parentNode() { return this._parent; },
  #|         get parentElement() { return this._parent && this._parent._nodeType === 1 ? this._parent : null; },
  #|         get isConnected() {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n._tagName === 'HTML';
  #|         },
  #|         getRootNode(options) {
  #|           let n = this;
  #|           while (n._parent) n = n._parent;
  #|           return n;
  #|         },
  #|         get firstChild() { return null; },
  #|         get lastChild() { return null; },
  #|         get childNodes() { return []; },
  #|         hasChildNodes() { return false; },
  #|         get nextSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return this._parent._children[idx + 1] || null;
  #|         },
  #|         get previousSibling() {
  #|           if (!this._parent) return null;
  #|           const idx = this._parent._children.indexOf(this);
  #|           return idx > 0 ? this._parent._children[idx - 1] : null;
  #|         },
  #|         appendChild(child) {
  #|           if (child === null) throw new TypeError('Failed to execute appendChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot appendChild to a ProcessingInstruction node', 'HierarchyRequestError');
  #|         },
  #|         insertBefore(child, ref) {
  #|           if (child === null) throw new TypeError('Failed to execute insertBefore: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot insertBefore on a ProcessingInstruction node', 'HierarchyRequestError');
  #|         },
  #|         removeChild(child) {
  #|           throw new DOMException('Cannot removeChild from a ProcessingInstruction node', 'NotFoundError');
  #|         },
  #|         replaceChild(newChild, oldChild) {
  #|           if (newChild === null) throw new TypeError('Failed to execute replaceChild: parameter 1 is not of type Node');
  #|           throw new DOMException('Cannot replaceChild on a ProcessingInstruction node', 'HierarchyRequestError');
  #|         },
  #|         substringData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'substringData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           return this._textContent.substr(offset, count);
  #|         },
  #|         appendData(data) {
  #|           if (arguments.length < 1) throw new TypeError("Failed to execute 'appendData': 1 argument required");
  #|           this._textContent = this._textContent + String(data);
  #|         },
  #|         insertData(offset, data) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'insertData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset);
  #|         },
  #|         deleteData(offset, count) {
  #|           if (arguments.length < 2) throw new TypeError("Failed to execute 'deleteData': 2 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + this._textContent.slice(offset + count);
  #|         },
  #|         replaceData(offset, count, data) {
  #|           if (arguments.length < 3) throw new TypeError("Failed to execute 'replaceData': 3 arguments required");
  #|           offset = offset >>> 0;
  #|           if (offset > this._textContent.length) throw new DOMException('Index out of bounds', 'IndexSizeError');
  #|           count = count >>> 0;
  #|           if (count > this._textContent.length - offset) count = this._textContent.length - offset;
  #|           this._textContent = this._textContent.slice(0, offset) + String(data) + this._textContent.slice(offset + count);
  #|         },
  #|         cloneNode() {
  #|           const id = nodeIdCounter++;
  #|           return createMockProcessingInstruction(this._target, this._textContent, id);
  #|         },
  #|         remove() { if (this._parent) this._parent.removeChild(this); },
  #|         before(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viablePreviousSibling = this.previousSibling;
  #|           while (viablePreviousSibling && actualNodes.includes(viablePreviousSibling)) {
  #|             viablePreviousSibling = viablePreviousSibling.previousSibling;
  #|           }
  #|           let ref = viablePreviousSibling ? viablePreviousSibling.nextSibling : parent.firstChild;
  #|           for (let i = actualNodes.length - 1; i >= 0; i--) {
  #|             parent.insertBefore(actualNodes[i], ref);
  #|             ref = actualNodes[i];
  #|           }
  #|         },
  #|         after(...nodes) {
  #|           if (!this._parent) return;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           for (const node of actualNodes) {
  #|             this._parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         replaceWith(...nodes) {
  #|           if (!this._parent) return;
  #|           const parent = this._parent;
  #|           const actualNodes = nodes.map(n => (n && n._mockId !== undefined) ? n : document.createTextNode(String(n)));
  #|           let viableNextSibling = this.nextSibling;
  #|           while (viableNextSibling && actualNodes.includes(viableNextSibling)) {
  #|             viableNextSibling = viableNextSibling.nextSibling;
  #|           }
  #|           parent.removeChild(this);
  #|           for (const node of actualNodes) {
  #|             parent.insertBefore(node, viableNextSibling);
  #|           }
  #|         },
  #|         isEqualNode(other) { return other && other._nodeType === 7 && other._target === this._target && other._textContent === this._textContent; },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, node);
  #|       return node;
  #|     }
  #|
  #|     function createMockDocumentFragment(mockId) {
  #|       const frag = {
  #|         _mockId: mockId,
  #|         _tagName: '#document-fragment',
  #|         _children: [],
  #|         _parent: null,
  #|         _nodeType: 11,
  #|         get nodeType() { return 11; },
  #|         get nodeName() { return '#document-fragment'; },
  #|         get ownerDocument() { return document; },
  #|         get textContent() {
  #|           // Collect text content from Text node descendants only
  #|           const collectText = (node) => {
  #|             if (node._nodeType === 3) return node._textContent;
  #|             if (!node._children) return '';
  #|             return node._children.map(collectText).join('');
  #|           };
  #|           return collectText(this);
  #|         },
  #|         set textContent(v) {
  #|           const str = (v === null || v === undefined) ? '' : String(v);
  #|           this._children.forEach(c => { c._parent = null; });
  #|           this._children = [];
  #|           if (str !== '') {
  #|             const textNode = document.createTextNode(str);
  #|             textNode._parent = this;
  #|             this._children.push(textNode);
  #|           }
  #|         },
  #|         get firstChild() { return this._children[0] || null; },
  #|         get lastChild() { return this._children[this._children.length - 1] || null; },
  #|         get childNodes() { return [...this._children]; },
  #|         get children() { return this._children.filter(c => c._nodeType === 1); },
  #|         get childElementCount() { return this._children.filter(c => c._nodeType === 1).length; },
  #|         hasChildNodes() { return this._children.length > 0; },
  #|         appendChild(child) {
  #|           if (child && child._mockId !== undefined) {
  #|             if (child._parent) child._parent.removeChild(child);
  #|             this._children.push(child);
  #|             child._parent = this;
  #|           }
  #|           return child;
  #|         },
  #|         insertBefore(newChild, refChild) {
  #|           if (!newChild || newChild._mockId === undefined) return newChild;
  #|           if (refChild === null || refChild === undefined) return this.appendChild(newChild);
  #|           let actualRef = refChild;
  #|           if (refChild === newChild) {
  #|             actualRef = newChild.nextSibling;
  #|           }
  #|           if (newChild._parent) newChild._parent.removeChild(newChild);
  #|           if (actualRef === null || actualRef === undefined) {
  #|             return this.appendChild(newChild);
  #|           }
  #|           const idx = this._children.indexOf(actualRef);
  #|           if (idx >= 0) { this._children.splice(idx, 0, newChild); newChild._parent = this; }
  #|           else { return this.appendChild(newChild); }
  #|           return newChild;
  #|         },
  #|         removeChild(child) {
  #|           const idx = this._children.indexOf(child);
  #|           if (idx >= 0) { this._children.splice(idx, 1); child._parent = null; }
  #|           return child;
  #|         },
  #|         append(...nodes) {
  #|           for (const n of nodes) {
  #|             const node = (n && n._mockId !== undefined) ? n : document.createTextNode(String(n));
  #|             this.appendChild(node);
  #|           }
  #|         },
  #|         prepend(...nodes) {
  #|           const first = this.firstChild;
  #|           for (const n of nodes) {
  #|             const node = (n && n._mockId !== undefined) ? n : document.createTextNode(String(n));
  #|             this.insertBefore(node, first);
  #|           }
  #|         },
  #|         replaceChildren(...nodes) {
  #|           while (this._children.length > 0) this.removeChild(this._children[0]);
  #|           this.append(...nodes);
  #|         },
  #|         querySelector(selector) {
  #|           for (const child of this._children) {
  #|             if (child._nodeType === 1) {
  #|               if (child.matches && child.matches(selector)) return child;
  #|               const found = child.querySelector && child.querySelector(selector);
  #|               if (found) return found;
  #|             }
  #|           }
  #|           return null;
  #|         },
  #|         querySelectorAll(selector) {
  #|           const results = [];
  #|           const search = (el) => {
  #|             for (const child of el._children || []) {
  #|               if (child._nodeType === 1) {
  #|                 if (child.matches && child.matches(selector)) results.push(child);
  #|                 search(child);
  #|               }
  #|             }
  #|           };
  #|           search(this);
  #|           return results;
  #|         },
  #|         getElementById(id) {
  #|           if (id === '') return null;
  #|           const search = (el) => {
  #|             for (const child of el._children || []) {
  #|               if (child._nodeType === 1) {
  #|                 if (child.id === id) return child;
  #|                 const found = search(child);
  #|                 if (found) return found;
  #|               }
  #|             }
  #|             return null;
  #|           };
  #|           return search(this);
  #|         },
  #|         cloneNode(deep) {
  #|           const id = nodeIdCounter++;
  #|           domOps.push({ op: 'createDocumentFragment', id });
  #|           const clone = createMockDocumentFragment(id);
  #|           if (deep) {
  #|             for (const child of this._children) {
  #|               const clonedChild = child.cloneNode(true);
  #|               clone._children.push(clonedChild);
  #|               clonedChild._parent = clone;
  #|             }
  #|           }
  #|           return clone;
  #|         },
  #|         isEqualNode(other) {
  #|           if (!other || other._nodeType !== 11) return false;
  #|           if (this._children.length !== (other._children || []).length) return false;
  #|           for (let i = 0; i < this._children.length; i++) {
  #|             if (!this._children[i].isEqualNode || !this._children[i].isEqualNode(other._children[i])) return false;
  #|           }
  #|           return true;
  #|         },
  #|         isSameNode(other) { return this === other; }
  #|       };
  #|       mockElements.set(mockId, frag);
  #|       return frag;
  #|     }
  #|
  #|     const htmlEl = createMockElement('html', 1);
  #|     const headEl = createMockElement('head', 3);
  #|     const bodyEl = createMockElement('body', 2);
  #|     htmlEl.appendChild(headEl);
  #|     htmlEl.appendChild(bodyEl);
  #|     let _title = '';
  #|     let _doctype = null;
  #|     let _implementation = null;
  #|
  #|     const document = {
  #|       _mockElements: mockElements,
  #|       _nodeType: 9,
  #|       get nodeType() { return 9; },
  #|       get nodeName() { return '#document'; },
  #|       get nodeValue() { return null; },
  #|       get textContent() { return null; },
  #|       set textContent(v) { /* Document textContent is null, ignore setter */ },
  #|       get ownerDocument() { return null; },
  #|       get URL() { return 'about:blank'; },
  #|       get documentURI() { return 'about:blank'; },
  #|       get baseURI() { return 'about:blank'; },
  #|       get compatMode() { return 'CSS1Compat'; },
  #|       get characterSet() { return 'UTF-8'; },
  #|       get charset() { return 'UTF-8'; },
  #|       get inputEncoding() { return 'UTF-8'; },
  #|       get contentType() { return 'text/html'; },
  #|       get doctype() { return _doctype; },
  #|       get implementation() {
  #|         if (_implementation) return _implementation;
  #|         // Helper to create implementation bound to a specific document
  #|         const createImplForDoc = function(ownerDoc) {
  #|           return {
  #|             _ownerDocument: ownerDoc,
  #|             createDocument(namespace, qualifiedName, doctype) {
  #|               // Determine content type based on namespace
  #|               let contentType = 'application/xml';
  #|               if (namespace === 'http://www.w3.org/1999/xhtml') {
  #|                 contentType = 'application/xhtml+xml';
  #|               } else if (namespace === 'http://www.w3.org/2000/svg') {
  #|                 contentType = 'image/svg+xml';
  #|               }
  #|               const doc = {
  #|                 _nodeType: 9,
  #|                 nodeType: 9,
  #|                 nodeName: '#document',
  #|                 get nodeValue() { return null; },
  #|                 set nodeValue(v) { /* ignore */ },
  #|                 get textContent() { return null; },
  #|                 set textContent(v) { /* ignore */ },
  #|                 documentElement: null,
  #|                 doctype: doctype !== undefined ? doctype : null,
  #|                 _children: [],
  #|                 _impl: null,
  #|                 URL: 'about:blank',
  #|                 documentURI: 'about:blank',
  #|                 compatMode: 'CSS1Compat',
  #|                 characterSet: 'UTF-8',
  #|                 charset: 'UTF-8',
  #|                 inputEncoding: 'UTF-8',
  #|                 contentType: contentType,
  #|                 location: null,
  #|                 get implementation() {
  #|                   if (!this._impl) this._impl = createImplForDoc(this);
  #|                   return this._impl;
  #|                 },
  #|                 createElement(name) { return document.createElement(name); },
  #|                 createTextNode(text) { return document.createTextNode(text); },
  #|                 createComment(text) { return document.createComment(text); },
  #|                 createDocumentFragment() { return document.createDocumentFragment(); },
  #|                 appendChild(child) { this._children.push(child); child._parent = this; child.parentNode = this; if (child._nodeType === 1) this.documentElement = child; return child; },
  #|                 removeChild(child) { const idx = this._children.indexOf(child); if (idx >= 0) { this._children.splice(idx, 1); child._parent = null; child.parentNode = null; } return child; },
  #|                 get childNodes() { return this._children; },
  #|                 get firstChild() { return this._children[0] || null; },
  #|                 getRootNode() { return this; },
  #|                 isSameNode(other) { return this === other; },
  #|                 isEqualNode(other) { return this === other; },
  #|                 adoptNode(node) {
  #|                   if (!node) return null;
  #|                   if (node._nodeType === 9) throw new DOMException('Cannot adopt a document node', 'NotSupportedError');
  #|                   if (node._parent) node._parent.removeChild(node);
  #|                   node.ownerDocument = this;
  #|                   return node;
  #|                 }
  #|               };
  #|               Object.setPrototypeOf(doc, Document.prototype);
  #|               if (qualifiedName) {
  #|                 const el = document.createElementNS(namespace, qualifiedName);
  #|                 doc.appendChild(el);
  #|               }
  #|               return doc;
  #|             },
  #|             createDocumentType(qualifiedName, publicId, systemId) {
  #|               const ownerDoc = this._ownerDocument || document;
  #|               const doctype = {
  #|                 _nodeType: 10,
  #|                 nodeType: 10,
  #|                 name: qualifiedName,
  #|                 publicId: publicId || '',
  #|                 systemId: systemId || '',
  #|                 nodeName: qualifiedName,
  #|                 get nodeValue() { return null; },
  #|                 set nodeValue(v) { /* ignore */ },
  #|                 get textContent() { return null; },
  #|                 set textContent(v) { /* ignore */ },
  #|                 ownerDocument: ownerDoc,
  #|                 parentNode: null,
  #|                 _parent: null,
  #|                 firstChild: null,
  #|                 lastChild: null,
  #|                 previousSibling: null,
  #|                 nextSibling: null,
  #|                 get childNodes() { return []; },
  #|                 hasChildNodes() { return false; },
  #|                 isSameNode(other) { return this === other; },
  #|                 isEqualNode(other) { return other && other._nodeType === 10 && other.name === this.name && other.publicId === this.publicId && other.systemId === this.systemId; },
  #|                 cloneNode() {
  #|                   return ownerDoc.implementation.createDocumentType(this.name, this.publicId, this.systemId);
  #|                 },
  #|                 getRootNode() {
  #|                   let node = this;
  #|                   while (node._parent) node = node._parent;
  #|                   return node;
  #|                 }
  #|               };
  #|               Object.setPrototypeOf(doctype, DocumentType.prototype);
  #|               return doctype;
  #|             },
  #|             createHTMLDocument(title) {
  #|               const doctype = this.createDocumentType('html', '', '');
  #|               const doc = this.createDocument(null, null, doctype);
  #|               doc._children = [doctype];
  #|               doctype._parent = doc;
  #|               doctype.parentNode = doc;
  #|               doctype.ownerDocument = doc;
  #|               doc.doctype = doctype;
  #|               const html = document.createElement('html');
  #|               const head = document.createElement('head');
  #|               const body = document.createElement('body');
  #|               if (title !== undefined) {
  #|                 const titleEl = document.createElement('title');
  #|                 const titleText = title === null ? 'null' : String(title);
  #|                 const textNode = document.createTextNode(titleText);
  #|                 titleEl.appendChild(textNode);
  #|                 head.appendChild(titleEl);
  #|               }
  #|               html.appendChild(head);
  #|               html.appendChild(body);
  #|               doc.appendChild(html);
  #|               doc.documentElement = html;
  #|               doc.head = head;
  #|               doc.body = body;
  #|               doc.title = title === null ? 'null' : (title === undefined ? '' : String(title));
  #|               return doc;
  #|             },
  #|             hasFeature() { return true; }
  #|           };
  #|         };
  #|         const impl = createImplForDoc(document);
  #|         Object.setPrototypeOf(impl, DOMImplementation.prototype);
  #|         _implementation = impl;
  #|         return impl;
  #|       },
  #|       get activeElement() { return bodyEl; },
  #|       get forms() { return []; },
  #|       get images() { return []; },
  #|       get links() { return []; },
  #|       get scripts() { return []; },
  #|       get embeds() { return []; },
  #|       get plugins() { return []; },
  #|       hasFocus() { return true; },
  #|       createElement(tagName) {
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createElement', id, tagName });
  #|         const el = createMockElement(tagName, id);
  #|         const Ctor = tagToConstructor[tagName.toLowerCase()] || HTMLUnknownElement;
  #|         Object.setPrototypeOf(el, Ctor.prototype);
  #|         return el;
  #|       },
  #|       createTextNode(text) {
  #|         const str = String(text);
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createTextNode', id, text: str });
  #|         const node = createMockTextNode(str, id);
  #|         Object.setPrototypeOf(node, Text.prototype);
  #|         return node;
  #|       },
  #|       createComment(text) {
  #|         const str = String(text);
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createComment', id, text: str });
  #|         const node = createMockComment(str, id);
  #|         Object.setPrototypeOf(node, Comment.prototype);
  #|         return node;
  #|       },
  #|       createAttribute(name) {
  #|         const attr = {
  #|           _nodeType: 2,
  #|           nodeType: 2,
  #|           name: name,
  #|           localName: name,
  #|           value: '',
  #|           namespaceURI: null,
  #|           prefix: null,
  #|           ownerElement: null,
  #|           specified: true,
  #|           isSameNode(other) { return this === other; },
  #|           isEqualNode(other) { return other && other._nodeType === 2 && other.name === this.name && other.value === this.value; }
  #|         };
  #|         return attr;
  #|       },
  #|       createAttributeNS(ns, name) {
  #|         const attr = this.createAttribute(name);
  #|         attr.namespaceURI = ns;
  #|         const colonIdx = name.indexOf(':');
  #|         if (colonIdx >= 0) {
  #|           attr.prefix = name.slice(0, colonIdx);
  #|           attr.localName = name.slice(colonIdx + 1);
  #|         }
  #|         return attr;
  #|       },
  #|       createDocumentFragment() {
  #|         const id = nodeIdCounter++;
  #|         domOps.push({ op: 'createDocumentFragment', id });
  #|         return createMockDocumentFragment(id);
  #|       },
  #|       get body() { return bodyEl; },
  #|       get head() { return headEl; },
  #|       get documentElement() { return htmlEl; },
  #|       get title() { return _title; },
  #|       set title(v) { _title = String(v); },
  #|       get childNodes() { return [htmlEl]; },
  #|       get children() { return [htmlEl]; },
  #|       get firstChild() { return htmlEl; },
  #|       get lastChild() { return htmlEl; },
  #|       getElementById(id) {
  #|         if (id === '') return null;
  #|         for (const el of mockElements.values()) {
  #|           if (el._attrs && el._attrs.id === id) return el;
  #|         }
  #|         return null;
  #|       },
  #|       getElementsByTagName(tag) {
  #|         const results = [];
  #|         for (const el of mockElements.values()) {
  #|           if (el._nodeType === 1 && (tag === '*' || el._tagName === tag.toUpperCase())) results.push(el);
  #|         }
  #|         return results;
  #|       },
  #|       getElementsByClassName(cls) {
  #|         const results = [];
  #|         for (const el of mockElements.values()) {
  #|           if (el._nodeType === 1 && el.classList && el.classList.contains(cls)) results.push(el);
  #|         }
  #|         return results;
  #|       },
  #|       getElementsByName(name) {
  #|         const results = [];
  #|         for (const el of mockElements.values()) {
  #|           if (el._attrs && el._attrs.name === name) results.push(el);
  #|         }
  #|         return results;
  #|       },
  #|       querySelector(selector) {
  #|         if (selector === 'body') return bodyEl;
  #|         if (selector === 'html') return htmlEl;
  #|         if (selector === 'head') return headEl;
  #|         if (selector.startsWith('#')) return this.getElementById(selector.slice(1));
  #|         if (selector.startsWith('.')) {
  #|           const cls = selector.slice(1);
  #|           for (const el of mockElements.values()) {
  #|             if (el._nodeType === 1 && el.classList && el.classList.contains(cls)) return el;
  #|           }
  #|           return null;
  #|         }
  #|         for (const el of mockElements.values()) {
  #|           if (el._tagName === selector.toUpperCase()) return el;
  #|         }
  #|         return null;
  #|       },
  #|       querySelectorAll(selector) {
  #|         const results = [];
  #|         if (selector === 'body') return [bodyEl];
  #|         if (selector === 'html') return [htmlEl];
  #|         if (selector === 'head') return [headEl];
  #|         if (selector.startsWith('.')) {
  #|           const cls = selector.slice(1);
  #|           for (const el of mockElements.values()) {
  #|             if (el._nodeType === 1 && el.classList && el.classList.contains(cls)) results.push(el);
  #|           }
  #|           return results;
  #|         }
  #|         for (const el of mockElements.values()) {
  #|           if (el._tagName === selector.toUpperCase()) results.push(el);
  #|         }
  #|         return results;
  #|       },
  #|       createEvent(type) { return { type, initEvent() {}, preventDefault() {}, stopPropagation() {} }; },
  #|       contains(node) { return htmlEl.contains(node); },
  #|       createElementNS(ns, tagName) { return this.createElement(tagName); },
  #|       getElementsByTagNameNS(ns, tag) { return this.getElementsByTagName(tag); },
  #|       importNode(node, deep) { return node.cloneNode ? node.cloneNode(deep) : node; },
  #|       adoptNode(node) {
  #|         if (!node) return null;
  #|         if (node._nodeType === 9 || node.nodeType === 9) {
  #|           throw new DOMException('Cannot adopt a document node', 'NotSupportedError');
  #|         }
  #|         if (node._parent) node._parent.removeChild(node);
  #|         node.ownerDocument = this;
  #|         return node;
  #|       },
  #|       createRange() {
  #|         return {
  #|           startContainer: null, startOffset: 0, endContainer: null, endOffset: 0, collapsed: true,
  #|           setStart(node, offset) { this.startContainer = node; this.startOffset = offset; },
  #|           setEnd(node, offset) { this.endContainer = node; this.endOffset = offset; },
  #|           selectNode(node) { this.startContainer = this.endContainer = node; },
  #|           selectNodeContents(node) { this.startContainer = this.endContainer = node; },
  #|           collapse(toStart) { if (toStart) { this.endContainer = this.startContainer; this.endOffset = this.startOffset; } else { this.startContainer = this.endContainer; this.startOffset = this.endOffset; } this.collapsed = true; },
  #|           cloneContents() { return document.createDocumentFragment(); },
  #|           deleteContents() {},
  #|           extractContents() { return document.createDocumentFragment(); },
  #|           insertNode(node) {},
  #|           surroundContents(node) {},
  #|           cloneRange() { return document.createRange(); },
  #|           detach() {},
  #|           toString() { return ''; }
  #|         };
  #|       },
  #|       createNodeIterator(root, whatToShow, filter) {
  #|         return { root, nextNode() { return null; }, previousNode() { return null; } };
  #|       },
  #|       createTreeWalker(root, whatToShow, filter) {
  #|         return {
  #|           root, currentNode: root,
  #|           firstChild() { return this.currentNode.firstChild; },
  #|           lastChild() { return this.currentNode.lastChild; },
  #|           nextSibling() { return this.currentNode.nextSibling; },
  #|           previousSibling() { return this.currentNode.previousSibling; },
  #|           parentNode() { return this.currentNode.parentNode; },
  #|           nextNode() { return null; },
  #|           previousNode() { return null; }
  #|         };
  #|       },
  #|       createCDATASection(data) {
  #|         const id = nodeIdCounter++;
  #|         return { _mockId: id, _nodeType: 4, nodeType: 4, nodeName: '#cdata-section', data, textContent: data };
  #|       },
  #|       createProcessingInstruction(target, data) {
  #|         const id = nodeIdCounter++;
  #|         return createMockProcessingInstruction(target, data, id);
  #|       },
  #|       get defaultView() { return typeof window !== 'undefined' ? window : null; },
  #|       getRootNode() { return this; },
  #|       get readyState() { return 'complete'; },
  #|       get hidden() { return false; },
  #|       get visibilityState() { return 'visible'; },
  #|       get dir() { return ''; },
  #|       set dir(v) {},
  #|       get firstElementChild() { return htmlEl; },
  #|       get lastElementChild() { return htmlEl; },
  #|       get childElementCount() { return 1; },
  #|       prepend(...nodes) {
  #|         for (const n of nodes.reverse()) {
  #|           const node = (n && n._mockId !== undefined) ? n : this.createTextNode(String(n));
  #|           htmlEl.insertBefore(node, htmlEl.firstChild);
  #|         }
  #|       },
  #|       append(...nodes) {
  #|         for (const n of nodes) {
  #|           const node = (n && n._mockId !== undefined) ? n : this.createTextNode(String(n));
  #|           htmlEl.appendChild(node);
  #|         }
  #|       },
  #|       replaceChildren(...nodes) {
  #|         while (htmlEl._children.length > 0) htmlEl.removeChild(htmlEl._children[0]);
  #|         this.append(...nodes);
  #|       }
  #|     };
  #|
  #|     const console = {
  #|       log(...args) { logs.push(args.map(String).join(' ')); },
  #|       warn(...args) { logs.push('[WARN] ' + args.map(String).join(' ')); },
  #|       error(...args) { logs.push('[ERROR] ' + args.map(String).join(' ')); },
  #|       info(...args) { logs.push('[INFO] ' + args.map(String).join(' ')); }
  #|     };
  #|
  #|     // Event class
  #|     class Event {
  #|       constructor(type, options) {
  #|         options = options || {};
  #|         this._type = type;
  #|         this._bubbles = !!options.bubbles;
  #|         this._cancelable = !!options.cancelable;
  #|         this._composed = !!options.composed;
  #|         this._defaultPrevented = false;
  #|         this._propagationStopped = false;
  #|         this._immediatePropagationStopped = false;
  #|         this._target = null;
  #|         this._currentTarget = null;
  #|         this._eventPhase = 0;
  #|         this._timeStamp = Date.now();
  #|         this._isTrusted = false;
  #|       }
  #|       get type() { return this._type; }
  #|       get target() { return this._target; }
  #|       get srcElement() { return this._target; }
  #|       get currentTarget() { return this._currentTarget; }
  #|       get bubbles() { return this._bubbles; }
  #|       get cancelable() { return this._cancelable; }
  #|       get defaultPrevented() { return this._defaultPrevented; }
  #|       get composed() { return this._composed; }
  #|       get isTrusted() { return this._isTrusted; }
  #|       get timeStamp() { return this._timeStamp; }
  #|       get eventPhase() { return this._eventPhase; }
  #|       stopPropagation() { this._propagationStopped = true; }
  #|       stopImmediatePropagation() { this._immediatePropagationStopped = true; this._propagationStopped = true; }
  #|       preventDefault() { if (this._cancelable) this._defaultPrevented = true; }
  #|       initEvent(type, bubbles, cancelable) {
  #|         this._type = type;
  #|         this._bubbles = !!bubbles;
  #|         this._cancelable = !!cancelable;
  #|       }
  #|     }
  #|
  #|     // Window object
  #|     const _timers = { nextId: 1, timeouts: {}, intervals: {} };
  #|     const _animationFrames = { nextId: 1, callbacks: {} };
  #|
  #|     const window = {
  #|       get window() { return this; },
  #|       get self() { return this; },
  #|       get document() { return document; },
  #|       get name() { return ''; },
  #|       get location() { return { href: 'about:blank', protocol: 'about:', host: '', hostname: '', port: '', pathname: 'blank', search: '', hash: '', origin: 'null' }; },
  #|       get history() { return { length: 1, state: null, back() {}, forward() {}, go() {}, pushState() {}, replaceState() {} }; },
  #|       get navigator() { return { userAgent: 'Crater/1.0', language: 'en', languages: ['en'], platform: 'Unknown', cookieEnabled: false, onLine: true }; },
  #|       devicePixelRatio: 1,
  #|       innerWidth: 1024,
  #|       innerHeight: 768,
  #|       outerWidth: 1024,
  #|       outerHeight: 768,
  #|       scrollX: 0,
  #|       scrollY: 0,
  #|       get pageXOffset() { return this.scrollX; },
  #|       get pageYOffset() { return this.scrollY; },
  #|       screenX: 0,
  #|       screenY: 0,
  #|       scroll(options) { if (options) { this.scrollX = options.left || 0; this.scrollY = options.top || 0; } },
  #|       scrollTo(options) { this.scroll(options); },
  #|       scrollBy(options) { if (options) { this.scrollX += options.left || 0; this.scrollY += options.top || 0; } },
  #|       alert(msg) { logs.push('[ALERT] ' + (msg || '')); },
  #|       close() {},
  #|       focus() {},
  #|       blur() {},
  #|       print() {},
  #|       stop() {},
  #|       setTimeout(handler, timeout) {
  #|         const id = _timers.nextId++;
  #|         _timers.timeouts[id] = { handler, timeout: timeout || 0 };
  #|         return id;
  #|       },
  #|       clearTimeout(id) { delete _timers.timeouts[id]; },
  #|       setInterval(handler, timeout) {
  #|         const id = _timers.nextId++;
  #|         _timers.intervals[id] = { handler, timeout: timeout || 0 };
  #|         return id;
  #|       },
  #|       clearInterval(id) { delete _timers.intervals[id]; },
  #|       requestAnimationFrame(callback) {
  #|         const id = _animationFrames.nextId++;
  #|         _animationFrames.callbacks[id] = callback;
  #|         return id;
  #|       },
  #|       cancelAnimationFrame(id) { delete _animationFrames.callbacks[id]; },
  #|       getComputedStyle(elt, pseudoElt) {
  #|         return new Proxy({}, {
  #|           get(_, prop) { return ''; },
  #|           getPropertyValue(prop) { return ''; }
  #|         });
  #|       },
  #|       matchMedia(query) {
  #|         return {
  #|           matches: false,
  #|           media: query,
  #|           onchange: null,
  #|           addListener(cb) {},
  #|           removeListener(cb) {},
  #|           addEventListener(type, cb) {},
  #|           removeEventListener(type, cb) {},
  #|           dispatchEvent(ev) { return true; }
  #|         };
  #|       },
  #|       addEventListener(type, listener, options) {},
  #|       removeEventListener(type, listener, options) {},
  #|       dispatchEvent(event) { return true; },
  #|       Event: Event,
  #|       Node: Node,
  #|       CharacterData: CharacterData,
  #|       Element: Element,
  #|       Document: Document,
  #|       DocumentType: DocumentType,
  #|       DocumentFragment: DocumentFragment,
  #|       Text: Text,
  #|       Comment: Comment,
  #|       DOMException: DOMException,
  #|       DOMImplementation: DOMImplementation,
  #|       HTMLElement: HTMLElement,
  #|       HTMLHtmlElement: HTMLHtmlElement,
  #|       HTMLHeadElement: HTMLHeadElement,
  #|       HTMLBodyElement: HTMLBodyElement,
  #|       HTMLDivElement: HTMLDivElement,
  #|       HTMLSpanElement: HTMLSpanElement,
  #|       HTMLTitleElement: HTMLTitleElement,
  #|       HTMLAnchorElement: HTMLAnchorElement,
  #|       HTMLAreaElement: HTMLAreaElement,
  #|       HTMLAudioElement: HTMLAudioElement,
  #|       HTMLBaseElement: HTMLBaseElement,
  #|       HTMLBRElement: HTMLBRElement,
  #|       HTMLButtonElement: HTMLButtonElement,
  #|       HTMLCanvasElement: HTMLCanvasElement,
  #|       HTMLDataElement: HTMLDataElement,
  #|       HTMLDataListElement: HTMLDataListElement,
  #|       HTMLDetailsElement: HTMLDetailsElement,
  #|       HTMLDialogElement: HTMLDialogElement,
  #|       HTMLDListElement: HTMLDListElement,
  #|       HTMLEmbedElement: HTMLEmbedElement,
  #|       HTMLFieldSetElement: HTMLFieldSetElement,
  #|       HTMLFormElement: HTMLFormElement,
  #|       HTMLHeadingElement: HTMLHeadingElement,
  #|       HTMLHRElement: HTMLHRElement,
  #|       HTMLIFrameElement: HTMLIFrameElement,
  #|       HTMLImageElement: HTMLImageElement,
  #|       HTMLInputElement: HTMLInputElement,
  #|       HTMLLabelElement: HTMLLabelElement,
  #|       HTMLLegendElement: HTMLLegendElement,
  #|       HTMLLIElement: HTMLLIElement,
  #|       HTMLLinkElement: HTMLLinkElement,
  #|       HTMLMapElement: HTMLMapElement,
  #|       HTMLMenuElement: HTMLMenuElement,
  #|       HTMLMetaElement: HTMLMetaElement,
  #|       HTMLMeterElement: HTMLMeterElement,
  #|       HTMLModElement: HTMLModElement,
  #|       HTMLObjectElement: HTMLObjectElement,
  #|       HTMLOListElement: HTMLOListElement,
  #|       HTMLOptGroupElement: HTMLOptGroupElement,
  #|       HTMLOptionElement: HTMLOptionElement,
  #|       HTMLOutputElement: HTMLOutputElement,
  #|       HTMLParagraphElement: HTMLParagraphElement,
  #|       HTMLPictureElement: HTMLPictureElement,
  #|       HTMLPreElement: HTMLPreElement,
  #|       HTMLProgressElement: HTMLProgressElement,
  #|       HTMLQuoteElement: HTMLQuoteElement,
  #|       HTMLScriptElement: HTMLScriptElement,
  #|       HTMLSelectElement: HTMLSelectElement,
  #|       HTMLSlotElement: HTMLSlotElement,
  #|       HTMLSourceElement: HTMLSourceElement,
  #|       HTMLStyleElement: HTMLStyleElement,
  #|       HTMLTableElement: HTMLTableElement,
  #|       HTMLTableCellElement: HTMLTableCellElement,
  #|       HTMLTableColElement: HTMLTableColElement,
  #|       HTMLTableRowElement: HTMLTableRowElement,
  #|       HTMLTableSectionElement: HTMLTableSectionElement,
  #|       HTMLTemplateElement: HTMLTemplateElement,
  #|       HTMLTextAreaElement: HTMLTextAreaElement,
  #|       HTMLTimeElement: HTMLTimeElement,
  #|       HTMLTrackElement: HTMLTrackElement,
  #|       HTMLUListElement: HTMLUListElement,
  #|       HTMLVideoElement: HTMLVideoElement,
  #|       HTMLUnknownElement: HTMLUnknownElement,
  #|       HTMLTableCaptionElement: HTMLTableCaptionElement,
  #|       HTMLDirectoryElement: HTMLDirectoryElement,
  #|       HTMLFontElement: HTMLFontElement,
  #|       HTMLMarqueeElement: HTMLMarqueeElement,
  #|       HTMLFrameElement: HTMLFrameElement,
  #|       HTMLFrameSetElement: HTMLFrameSetElement,
  #|       HTMLParamElement: HTMLParamElement
  #|     };
  #|
  #|     // Make window globals accessible
  #|     const setTimeout = window.setTimeout.bind(window);
  #|     const clearTimeout = window.clearTimeout.bind(window);
  #|     const setInterval = window.setInterval.bind(window);
  #|     const clearInterval = window.clearInterval.bind(window);
  #|     const requestAnimationFrame = window.requestAnimationFrame.bind(window);
  #|     const cancelAnimationFrame = window.cancelAnimationFrame.bind(window);
  #|     const alert = window.alert.bind(window);
  #|
  #|     // DOMTokenList class
  #|     function DOMTokenList(getter, setter) { this._getter = getter; this._setter = setter; }
  #|     DOMTokenList.prototype._getTokens = function() { return (this._getter() || '').split(/\s+/).filter(Boolean); };
  #|     Object.defineProperties(DOMTokenList.prototype, {
  #|       length: { get: function() { return this._getTokens().length; } },
  #|       value: { get: function() { return this._getter() || ''; }, set: function(v) { this._setter(v); } }
  #|     });
  #|     DOMTokenList.prototype.item = function(index) { return this._getTokens()[index] || null; };
  #|     DOMTokenList.prototype.contains = function(token) { return this._getTokens().indexOf(token) >= 0; };
  #|     DOMTokenList.prototype.add = function() { var tokens = Array.prototype.slice.call(arguments); var set = {}; var list = this._getTokens(); for (var i = 0; i < list.length; i++) set[list[i]] = true; for (var j = 0; j < tokens.length; j++) set[tokens[j]] = true; this._setter(Object.keys(set).join(' ')); };
  #|     DOMTokenList.prototype.remove = function() { var tokens = Array.prototype.slice.call(arguments); var set = {}; var list = this._getTokens(); for (var i = 0; i < list.length; i++) set[list[i]] = true; for (var j = 0; j < tokens.length; j++) delete set[tokens[j]]; this._setter(Object.keys(set).join(' ')); };
  #|     DOMTokenList.prototype.toggle = function(token, force) { if (force === undefined) force = !this.contains(token); if (force) this.add(token); else this.remove(token); return force; };
  #|     DOMTokenList.prototype.replace = function(token, newToken) { if (!this.contains(token)) return false; this.remove(token); this.add(newToken); return true; };
  #|     DOMTokenList.prototype.supports = function(token) { return true; };
  #|     DOMTokenList.prototype.toString = function() { return this._getter() || ''; };
  #|     DOMTokenList.prototype.forEach = function(cb, thisArg) { var tokens = this._getTokens(); for (var i = 0; i < tokens.length; i++) cb.call(thisArg, tokens[i], i, this); };
  #|
  #|     // DOMRect class
  #|     class DOMRect {
  #|       constructor(x, y, width, height) {
  #|         this.x = x || 0;
  #|         this.y = y || 0;
  #|         this.width = width || 0;
  #|         this.height = height || 0;
  #|       }
  #|       get top() { return this.y; }
  #|       get right() { return this.x + this.width; }
  #|       get bottom() { return this.y + this.height; }
  #|       get left() { return this.x; }
  #|       static fromRect(rect) { return new DOMRect(rect.x, rect.y, rect.width, rect.height); }
  #|       toJSON() { return { x: this.x, y: this.y, width: this.width, height: this.height, top: this.top, right: this.right, bottom: this.bottom, left: this.left }; }
  #|     }
  #|
  #|     // Storage class
  #|     class Storage {
  #|       constructor() { this._data = {}; }
  #|       get length() { return Object.keys(this._data).length; }
  #|       key(index) { return Object.keys(this._data)[index] || null; }
  #|       getItem(key) { return this._data.hasOwnProperty(key) ? this._data[key] : null; }
  #|       setItem(key, value) { this._data[key] = String(value); }
  #|       removeItem(key) { delete this._data[key]; }
  #|       clear() { this._data = {}; }
  #|     }
  #|     const localStorage = new Storage();
  #|     const sessionStorage = new Storage();
  #|
  #|     // MutationObserver class
  #|     class MutationObserver {
  #|       constructor(callback) { this._callback = callback; this._records = []; this._targets = []; }
  #|       observe(target, options) { this._targets.push({ target, options }); }
  #|       disconnect() { this._targets = []; }
  #|       takeRecords() { const records = this._records; this._records = []; return records; }
  #|     }
  #|
  #|     // IntersectionObserver class
  #|     class IntersectionObserver {
  #|       constructor(callback, options) {
  #|         this._callback = callback;
  #|         this._options = options || {};
  #|         this._targets = [];
  #|       }
  #|       get root() { return this._options.root || null; }
  #|       get rootMargin() { return this._options.rootMargin || '0px'; }
  #|       get thresholds() { return this._options.threshold ? [].concat(this._options.threshold) : [0]; }
  #|       observe(target) { this._targets.push(target); }
  #|       unobserve(target) { this._targets = this._targets.filter(function(t) { return t !== target; }); }
  #|       disconnect() { this._targets = []; }
  #|       takeRecords() { return []; }
  #|     }
  #|
  #|     // ResizeObserver class
  #|     class ResizeObserver {
  #|       constructor(callback) { this._callback = callback; this._targets = []; }
  #|       observe(target, options) { this._targets.push({ target: target, options: options }); }
  #|       unobserve(target) { this._targets = this._targets.filter(function(t) { return t.target !== target; }); }
  #|       disconnect() { this._targets = []; }
  #|     }
  #|
  #|     // Automation helpers for CDP/BiDi compatibility
  #|     // waitForSelector - polls until an element matching selector appears
  #|     window.__waitForSelector = function(selector, options) {
  #|       options = options || {};
  #|       var timeout = options.timeout || 30000;
  #|       var interval = options.interval || 100;
  #|       var visible = options.visible || false;
  #|       var hidden = options.hidden || false;
  #|       var startTime = Date.now();
  #|       return new Promise(function(resolve, reject) {
  #|         function check() {
  #|           var element = document.querySelector(selector);
  #|           if (element) {
  #|             if (visible) {
  #|               // Check if element is visible (has size and not hidden)
  #|               var rect = element.getBoundingClientRect ? element.getBoundingClientRect() : { width: 1, height: 1 };
  #|               var isVisible = rect.width > 0 && rect.height > 0 && !element.hidden;
  #|               if (isVisible) { resolve(element); return; }
  #|             } else if (hidden) {
  #|               // Wait for element to be hidden (not found or hidden)
  #|             } else {
  #|               resolve(element);
  #|               return;
  #|             }
  #|           } else if (hidden) {
  #|             resolve(null);
  #|             return;
  #|           }
  #|           if (Date.now() - startTime >= timeout) {
  #|             reject(new Error('Timeout waiting for selector: ' + selector));
  #|             return;
  #|           }
  #|           setTimeout(check, interval);
  #|         }
  #|         check();
  #|       });
  #|     };
  #|
  #|     // waitForFunction - polls until a function returns truthy value
  #|     window.__waitForFunction = function(fn, options) {
  #|       options = options || {};
  #|       var timeout = options.timeout || 30000;
  #|       var interval = options.interval || 100;
  #|       var args = options.args || [];
  #|       var startTime = Date.now();
  #|       return new Promise(function(resolve, reject) {
  #|         function check() {
  #|           try {
  #|             var result = typeof fn === 'function' ? fn.apply(null, args) : eval('(' + fn + ')').apply(null, args);
  #|             if (result) { resolve(result); return; }
  #|           } catch (e) {
  #|             // Function threw, continue polling
  #|           }
  #|           if (Date.now() - startTime >= timeout) {
  #|             reject(new Error('Timeout waiting for function'));
  #|             return;
  #|           }
  #|           setTimeout(check, interval);
  #|         }
  #|         check();
  #|       });
  #|     };
  #|
  #|     // waitFor - generic wait with condition
  #|     window.__waitFor = function(condition, options) {
  #|       if (typeof condition === 'string') {
  #|         return window.__waitForSelector(condition, options);
  #|       }
  #|       return window.__waitForFunction(condition, options);
  #|     };
  #|
  #|     // FormData class (using bracket notation for reserved words)
  #|     function FormData(form) { this._data = []; }
  #|     FormData.prototype.append = function(name, value) { this._data.push([name, String(value)]); };
  #|     FormData.prototype['delete'] = function(name) { this._data = this._data.filter(function(e) { return e[0] !== name; }); };
  #|     FormData.prototype['get'] = function(name) { var entry = this._data.find(function(e) { return e[0] === name; }); return entry ? entry[1] : null; };
  #|     FormData.prototype.getAll = function(name) { return this._data.filter(function(e) { return e[0] === name; }).map(function(e) { return e[1]; }); };
  #|     FormData.prototype.has = function(name) { return this._data.some(function(e) { return e[0] === name; }); };
  #|     FormData.prototype['set'] = function(name, value) { this['delete'](name); this.append(name, value); };
  #|     FormData.prototype.keys = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][0], done: false } : { done: true }; } }; };
  #|     FormData.prototype.values = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][1], done: false } : { done: true }; } }; };
  #|     FormData.prototype.entries = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++], done: false } : { done: true }; } }; };
  #|     FormData.prototype.forEach = function(cb, thisArg) { var self = this; this._data.forEach(function(e) { cb.call(thisArg, e[1], e[0], self); }); };
  #|
  #|     // URLSearchParams class (using bracket notation for reserved words)
  #|     function URLSearchParams(init) {
  #|       this._data = [];
  #|       if (typeof init === 'string') {
  #|         var str = init.charAt(0) === '?' ? init.slice(1) : init;
  #|         if (str) {
  #|           var pairs = str.split('&');
  #|           for (var i = 0; i < pairs.length; i++) {
  #|             var parts = pairs[i].split('=');
  #|             this._data.push([decodeURIComponent(parts[0]), decodeURIComponent(parts[1] || '')]);
  #|           }
  #|         }
  #|       } else if (Array.isArray(init)) {
  #|         for (var j = 0; j < init.length; j++) {
  #|           this._data.push([String(init[j][0]), String(init[j][1])]);
  #|         }
  #|       } else if (init && typeof init === 'object') {
  #|         var keys = Object.keys(init);
  #|         for (var k = 0; k < keys.length; k++) {
  #|           this._data.push([keys[k], String(init[keys[k]])]);
  #|         }
  #|       }
  #|     }
  #|     URLSearchParams.prototype.append = function(name, value) { this._data.push([String(name), String(value)]); };
  #|     URLSearchParams.prototype['delete'] = function(name) { this._data = this._data.filter(function(e) { return e[0] !== name; }); };
  #|     URLSearchParams.prototype['get'] = function(name) { var entry = this._data.find(function(e) { return e[0] === name; }); return entry ? entry[1] : null; };
  #|     URLSearchParams.prototype.getAll = function(name) { return this._data.filter(function(e) { return e[0] === name; }).map(function(e) { return e[1]; }); };
  #|     URLSearchParams.prototype.has = function(name) { return this._data.some(function(e) { return e[0] === name; }); };
  #|     URLSearchParams.prototype['set'] = function(name, value) { this['delete'](name); this.append(name, value); };
  #|     URLSearchParams.prototype.sort = function() { this._data.sort(function(a, b) { return a[0].localeCompare(b[0]); }); };
  #|     URLSearchParams.prototype.toString = function() { return this._data.map(function(e) { return encodeURIComponent(e[0]) + '=' + encodeURIComponent(e[1]); }).join('&'); };
  #|     URLSearchParams.prototype.keys = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][0], done: false } : { done: true }; } }; };
  #|     URLSearchParams.prototype.values = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++][1], done: false } : { done: true }; } }; };
  #|     URLSearchParams.prototype.entries = function() { var self = this; var i = 0; return { next: function() { return i < self._data.length ? { value: self._data[i++], done: false } : { done: true }; } }; };
  #|     URLSearchParams.prototype.forEach = function(cb, thisArg) { var self = this; this._data.forEach(function(e) { cb.call(thisArg, e[1], e[0], self); }); };
  #|
  #|     // URL class (simplified without complex regex)
  #|     function URL(url, base) {
  #|       this._protocol = 'https:';
  #|       this._hostname = '';
  #|       this._port = '';
  #|       this._pathname = '/';
  #|       this._search = '';
  #|       this._hash = '';
  #|       this._username = '';
  #|       this._password = '';
  #|       var fullUrl = url;
  #|       if (base && url.indexOf('://') === -1) {
  #|         var baseSlash = base.lastIndexOf('/');
  #|         if (baseSlash >= 0) fullUrl = base.substring(0, baseSlash + 1) + url;
  #|       }
  #|       var protoEnd = fullUrl.indexOf('://');
  #|       if (protoEnd >= 0) {
  #|         this._protocol = fullUrl.substring(0, protoEnd) + ':';
  #|         fullUrl = fullUrl.substring(protoEnd + 3);
  #|       }
  #|       var hashIdx = fullUrl.indexOf('#');
  #|       if (hashIdx >= 0) { this._hash = fullUrl.substring(hashIdx); fullUrl = fullUrl.substring(0, hashIdx); }
  #|       var searchIdx = fullUrl.indexOf('?');
  #|       if (searchIdx >= 0) { this._search = fullUrl.substring(searchIdx); fullUrl = fullUrl.substring(0, searchIdx); }
  #|       var pathIdx = fullUrl.indexOf('/');
  #|       if (pathIdx >= 0) { this._pathname = fullUrl.substring(pathIdx); fullUrl = fullUrl.substring(0, pathIdx); }
  #|       var portIdx = fullUrl.indexOf(':');
  #|       if (portIdx >= 0) { this._port = fullUrl.substring(portIdx + 1); this._hostname = fullUrl.substring(0, portIdx); }
  #|       else { this._hostname = fullUrl; }
  #|       this._searchParams = new URLSearchParams(this._search);
  #|     }
  #|     URL.prototype = {
  #|       get href() { return this._protocol + '//' + this.host + this._pathname + this._search + this._hash; },
  #|       set href(v) { var u = new URL(v); this._protocol = u._protocol; this._hostname = u._hostname; this._port = u._port; this._pathname = u._pathname; this._search = u._search; this._hash = u._hash; },
  #|       get origin() { return this._protocol + '//' + this.host; },
  #|       get protocol() { return this._protocol; },
  #|       set protocol(v) { this._protocol = v.charAt(v.length - 1) === ':' ? v : v + ':'; },
  #|       get username() { return this._username; },
  #|       set username(v) { this._username = v; },
  #|       get password() { return this._password; },
  #|       set password(v) { this._password = v; },
  #|       get host() { return this._port ? this._hostname + ':' + this._port : this._hostname; },
  #|       set host(v) { var parts = v.split(':'); this._hostname = parts[0]; this._port = parts[1] || ''; },
  #|       get hostname() { return this._hostname; },
  #|       set hostname(v) { this._hostname = v; },
  #|       get port() { return this._port; },
  #|       set port(v) { this._port = v; },
  #|       get pathname() { return this._pathname; },
  #|       set pathname(v) { this._pathname = v.charAt(0) === '/' ? v : '/' + v; },
  #|       get search() { return this._search; },
  #|       set search(v) { this._search = v.charAt(0) === '?' ? v : (v ? '?' + v : ''); this._searchParams = new URLSearchParams(this._search); },
  #|       get searchParams() { return this._searchParams; },
  #|       get hash() { return this._hash; },
  #|       set hash(v) { this._hash = v.charAt(0) === '#' ? v : (v ? '#' + v : ''); },
  #|       toString: function() { return this.href; },
  #|       toJSON: function() { return this.href; }
  #|     };
  #|
  #|     // Initialize document doctype (simulating parser-created doctype)
  #|     _doctype = document.implementation.createDocumentType('html', '', '');
  #|     _doctype._parent = document;
  #|     _doctype.parentNode = document;
  #|   `;
  #|
  #|   // Use QuickJS if initialized, otherwise use Node.js vm
  #|   if (globalThis.__quickjs_initialized && globalThis.__quickjs && !globalThis.__use_nodejs_vm) {
  #|     // QuickJS execution
  #|     const QuickJS = globalThis.__quickjs;
  #|     const vm = QuickJS.newContext();
  #|     try {
  #|       const fullCode = setupCode + '\n' + code + '\n; JSON.stringify({ logs, domOps })';
  #|       const result = vm.evalCode(fullCode);
  #|       if (result.error) {
  #|         const errorStr = vm.dump(result.error);
  #|         result.error.dispose();
  #|         vm.dispose();
  #|         return JSON.stringify({
  #|           success: false, value: '', logs: [], domOps: [],
  #|           error: String(errorStr)
  #|         });
  #|       }
  #|       const resultStr = vm.dump(result.value);
  #|       result.value.dispose();
  #|       vm.dispose();
  #|       const parsed = JSON.parse(resultStr);
  #|       return JSON.stringify({
  #|         success: true, value: 'undefined',
  #|         logs: parsed.logs || [], domOps: parsed.domOps || []
  #|       });
  #|     } catch (e) {
  #|       try { vm.dispose(); } catch {}
  #|       return JSON.stringify({
  #|         success: false, value: '', logs: [], domOps: [],
  #|         error: e.message || String(e)
  #|       });
  #|     }
  #|   } else {
  #|     // Node.js vm fallback - two-phase execution
  #|     const vm = require('vm');
  #|     const sandbox = {};
  #|     try {
  #|       vm.createContext(sandbox);
  #|       // Phase 1: Run setup + user code and capture the return value
  #|       const userResult = vm.runInContext(setupCode + '\n' + code, sandbox, { timeout: 5000 });
  #|       // Phase 2: Collect logs and domOps
  #|       const collected = vm.runInContext('({ logs, domOps })', sandbox, { timeout: 1000 });
  #|       return JSON.stringify({
  #|         success: true,
  #|         value: userResult === undefined ? 'undefined' : String(userResult),
  #|         logs: collected.logs || [],
  #|         domOps: collected.domOps || []
  #|       });
  #|     } catch (e) {
  #|       // Try to collect logs even on error
  #|       let logs = [], domOps = [];
  #|       try {
  #|         const collected = vm.runInContext('({ logs: logs || [], domOps: domOps || [] })', sandbox, { timeout: 100 });
  #|         logs = collected.logs || [];
  #|         domOps = collected.domOps || [];
  #|       } catch {}
  #|       return JSON.stringify({
  #|         success: false, value: '',
  #|         logs, domOps,
  #|         error: e.message || String(e)
  #|       });
  #|     }
  #|   }
  #| }

///|
/// Initialize JS runtime with QuickJS
pub fn init_js_runtime() -> Unit {
  if not(runtime_state.initialized) {
    let success = quickjs_init()
    if success {
      runtime_state.initialized = true
    }
  }
}

///|
/// Execute JavaScript code with DOM bindings
pub fn JsContext::execute(
  self : JsContext,
  code : String,
) -> JsResult raise JsError {
  init_js_runtime()
  let context_id = register_context(self.dom)
  let result_json = quickjs_execute_with_mock_dom(code)

  // Parse result
  let (result, dom_ops) = parse_js_result_with_ops(result_json)

  // Apply DOM operations to actual DomTree
  apply_dom_ops(self.dom, dom_ops)

  // Cleanup
  unregister_context(context_id)

  // Add logs to context
  for log in result.logs {
    self.logs.push(log)
  }
  if not(result.success) {
    raise ExecutionError(result.value)
  }
  result
}

///|
/// DOM operation type
priv struct DomOp {
  op : String
  id : Int
  parent_id : Int
  child_id : Int
  ref_id : Int // Reference node ID for insertBefore
  tag_name : String
  text : String
  name : String
  value : String
}

///|
/// Parse JS result JSON with DOM operations
fn parse_js_result_with_ops(json : String) -> (JsResult, Array[DomOp]) {
  let success = json.contains("\"success\":true")
  let value = if success {
    extract_json_field(json, "value")
  } else {
    extract_json_field(json, "error")
  }
  let logs = extract_json_array(json, "logs")
  let dom_ops = parse_dom_ops(json)
  ({ value, logs, success }, dom_ops)
}

///|
/// Parse DOM operations from JSON
fn parse_dom_ops(json : String) -> Array[DomOp] {
  let ops : Array[DomOp] = []
  // Find domOps array
  let pattern = "\"domOps\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      // Simple JSON array of objects parser
      let chars = json.to_array()
      let mut i = array_start
      let mut depth = 0
      let mut obj_start = -1
      while i < chars.length() {
        let c = chars[i]
        if c == '{' {
          if depth == 0 {
            obj_start = i
          }
          depth = depth + 1
        } else if c == '}' {
          depth = depth - 1
          if depth == 0 && obj_start >= 0 {
            let obj_json = json.unsafe_substring(start=obj_start, end=i + 1)
            let op = parse_single_dom_op(obj_json)
            ops.push(op)
            obj_start = -1
          }
        } else if c == ']' && depth == 0 {
          break
        }
        i = i + 1
      }
    }
    None => ()
  }
  ops
}

///|
/// Parse a single DOM operation object
fn parse_single_dom_op(json : String) -> DomOp {
  {
    op: extract_json_field(json, "op"),
    id: parse_int_field(json, "id"),
    parent_id: parse_int_field(json, "parentId"),
    child_id: parse_int_field(json, "childId"),
    ref_id: parse_int_field(json, "refId"),
    tag_name: extract_json_field(json, "tagName"),
    text: extract_json_field(json, "text"),
    name: extract_json_field(json, "name"),
    value: extract_json_field(json, "value"),
  }
}

///|
/// Parse integer field from JSON
fn parse_int_field(json : String, field : String) -> Int {
  let pattern = "\"" + field + "\":"
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut end = value_start
      while end < chars.length() &&
            ((chars[end] >= '0' && chars[end] <= '9') || chars[end] == '-') {
        end = end + 1
      }
      if end > value_start {
        let num_str = json.unsafe_substring(start=value_start, end~)
        @strconv.parse_int(num_str) catch {
          _ => 0
        }
      } else {
        0
      }
    }
    None => 0
  }
}

///|
/// Apply DOM operations to DomTree
fn apply_dom_ops(dom : @dom.DomTree, ops : Array[DomOp]) -> Unit {
  // Map mock IDs to real NodeIds
  let id_map : Map[Int, @dom.NodeId] = {}

  // Pre-populate with body (id=2 in mock)
  match dom.query_selector(dom.get_document(), "body") {
    Ok(Some(body_id)) => id_map.set(2, body_id)
    _ => ()
  }
  // Pre-populate with html (id=1 in mock)
  match dom.query_selector(dom.get_document(), "html") {
    Ok(Some(html_id)) => id_map.set(1, html_id)
    _ => ()
  }
  for op in ops {
    match op.op {
      "createElement" => {
        let node_id = dom.create_element(op.tag_name)
        id_map.set(op.id, node_id)
      }
      "createTextNode" => {
        let node_id = dom.create_text(op.text)
        id_map.set(op.id, node_id)
      }
      "createComment" => {
        let node_id = dom.create_comment(op.text)
        id_map.set(op.id, node_id)
      }
      "createDocumentFragment" => {
        // DocumentFragment is represented as a temporary container
        // For now, create a dummy element that won't be rendered
        let node_id = dom.create_element("template")
        id_map.set(op.id, node_id)
      }
      "appendChild" =>
        match (id_map.get(op.parent_id), id_map.get(op.child_id)) {
          (Some(parent), Some(child)) => {
            let _ = dom.append_child(parent, child)

          }
          _ => ()
        }
      "insertBefore" =>
        match (id_map.get(op.parent_id), id_map.get(op.child_id)) {
          (Some(parent), Some(child)) => {
            let ref_node = if op.ref_id > 0 {
              id_map.get(op.ref_id)
            } else {
              None
            }
            let _ = dom.insert_before(parent, child, ref_node)

          }
          _ => ()
        }
      "replaceChild" =>
        match
          (
            id_map.get(op.parent_id),
            id_map.get(op.child_id),
            id_map.get(op.ref_id),
          ) {
          (Some(parent), Some(new_child), Some(old_child)) => {
            // replaceChild: insert new before old, then remove old
            let _ = dom.insert_before(parent, new_child, Some(old_child))
            let _ = dom.remove_child(parent, old_child)

          }
          _ => ()
        }
      "removeChild" =>
        match (id_map.get(op.parent_id), id_map.get(op.child_id)) {
          (Some(parent), Some(child)) => {
            let _ = dom.remove_child(parent, child)

          }
          _ => ()
        }
      "setAttribute" =>
        match id_map.get(op.id) {
          Some(node_id) => {
            let _ = dom.set_attribute(node_id, op.name, op.value)

          }
          None => ()
        }
      "removeAttribute" =>
        match id_map.get(op.id) {
          Some(node_id) => {
            let _ = dom.remove_attribute(node_id, op.name)

          }
          None => ()
        }
      "setTextContent" =>
        match id_map.get(op.id) {
          Some(node_id) => {
            let _ = dom.set_text_content(node_id, op.value)

          }
          None => ()
        }
      _ => ()
    }
  }
}

///|
/// Extract string field from JSON
fn extract_json_field(json : String, field : String) -> String {
  let pattern = "\"" + field + "\":\""
  match json.find(pattern) {
    Some(start) => {
      let value_start = start + pattern.length()
      let chars = json.to_array()
      let mut end = value_start
      while end < chars.length() {
        if chars[end] == '"' && (end == value_start || chars[end - 1] != '\\') {
          break
        }
        end = end + 1
      }
      json.unsafe_substring(start=value_start, end~)
    }
    None => ""
  }
}

///|
/// Extract string array from JSON
fn extract_json_array(json : String, field : String) -> Array[String] {
  let pattern = "\"" + field + "\":["
  match json.find(pattern) {
    Some(start) => {
      let array_start = start + pattern.length()
      let chars = json.to_array()
      let result : Array[String] = []
      let mut i = array_start
      while i < chars.length() && chars[i] != ']' {
        if chars[i] == '"' {
          let str_start = i + 1
          let mut str_end = str_start
          while str_end < chars.length() {
            if chars[str_end] == '"' && chars[str_end - 1] != '\\' {
              break
            }
            str_end = str_end + 1
          }
          result.push(json.unsafe_substring(start=str_start, end=str_end))
          i = str_end + 1
        } else {
          i = i + 1
        }
      }
      result
    }
    None => []
  }
}
