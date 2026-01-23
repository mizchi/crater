/**
 * WebIDL Coverage Analyzer for Crater DOM Implementation
 *
 * Usage:
 *   npx tsx scripts/webidl-coverage.ts              # Show coverage report
 *   npx tsx scripts/webidl-coverage.ts --json       # Output as JSON
 *   npx tsx scripts/webidl-coverage.ts --generate   # Generate stub code
 */

import * as WebIDL2 from 'webidl2';

// Current mock DOM implementation - manually extracted
const IMPLEMENTED = {
  Element: {
    attributes: [
      'tagName', 'id', 'className', 'textContent', 'parentNode', 'firstChild', 'children', 'nextSibling',
      'nodeType', 'nodeName', 'localName', 'ownerDocument', 'isConnected',
      'classList', 'innerHTML', 'outerHTML', 'attributes',
      'parentElement', 'lastChild', 'childNodes', 'firstElementChild', 'lastElementChild', 'childElementCount',
      'previousSibling', 'nextElementSibling', 'previousElementSibling', 'style',
      'namespaceURI', 'prefix', 'slot', 'nodeValue', 'baseURI', 'shadowRoot'
    ],
    operations: [
      'setAttribute', 'getAttribute', 'removeAttribute', 'appendChild', 'removeChild',
      'hasAttribute', 'hasAttributes', 'getAttributeNames', 'toggleAttribute',
      'hasChildNodes', 'contains', 'matches', 'closest',
      'getElementsByTagName', 'getElementsByClassName', 'querySelector', 'querySelectorAll',
      'append', 'prepend', 'remove', 'before', 'after', 'replaceWith', 'replaceChildren',
      'getBoundingClientRect', 'insertBefore', 'replaceChild', 'cloneNode',
      'getAttributeNS', 'setAttributeNS', 'removeAttributeNS', 'hasAttributeNS',
      'getAttributeNode', 'getAttributeNodeNS', 'setAttributeNode', 'setAttributeNodeNS', 'removeAttributeNode',
      'getRootNode', 'normalize', 'isEqualNode', 'isSameNode', 'compareDocumentPosition',
      'lookupPrefix', 'lookupNamespaceURI', 'isDefaultNamespace',
      'webkitMatchesSelector', 'getElementsByTagNameNS', 'insertAdjacentElement', 'insertAdjacentText',
      'attachShadow', 'focus', 'blur', 'click', 'dispatchEvent', 'addEventListener', 'removeEventListener'
    ],
  },
  Document: {
    attributes: [
      'body', 'documentElement', 'head', 'title', 'nodeType', 'nodeName', 'childNodes', 'children', 'firstChild', 'lastChild',
      'URL', 'documentURI', 'baseURI', 'compatMode', 'characterSet', 'charset', 'inputEncoding', 'contentType',
      'doctype', 'implementation', 'activeElement', 'forms', 'images', 'links', 'scripts', 'embeds', 'plugins',
      'defaultView', 'readyState', 'hidden', 'visibilityState',
      'dir', 'firstElementChild', 'lastElementChild', 'childElementCount'
    ],
    operations: [
      'createElement', 'createTextNode', 'getElementById', 'querySelector', 'querySelectorAll',
      'createComment', 'createDocumentFragment',
      'getElementsByTagName', 'getElementsByClassName', 'getElementsByName',
      'createEvent', 'contains', 'hasFocus',
      'createElementNS', 'getElementsByTagNameNS', 'createAttribute', 'createAttributeNS',
      'importNode', 'adoptNode', 'createRange', 'createNodeIterator', 'createTreeWalker',
      'createCDATASection', 'createProcessingInstruction',
      'prepend', 'append', 'replaceChildren'
    ],
  },
  Node: {
    attributes: [
      'textContent', 'parentNode', 'firstChild', 'nextSibling',
      'nodeType', 'nodeName', 'ownerDocument', 'isConnected',
      'parentElement', 'lastChild', 'childNodes', 'previousSibling',
      'nodeValue', 'baseURI'
    ],
    operations: [
      'appendChild', 'removeChild', 'insertBefore', 'replaceChild', 'cloneNode', 'hasChildNodes', 'contains',
      'getRootNode', 'normalize', 'isEqualNode', 'isSameNode', 'compareDocumentPosition',
      'lookupPrefix', 'lookupNamespaceURI', 'isDefaultNamespace'
    ],
  },
  Text: {
    attributes: [
      'textContent', 'nodeType', 'nodeName', 'ownerDocument', 'isConnected', 'nodeValue', 'data', 'length',
      'parentNode', 'parentElement', 'previousSibling', 'nextSibling', 'wholeText'
    ],
    operations: [
      'cloneNode', 'remove', 'before', 'after', 'replaceWith',
      'splitText', 'substringData', 'appendData', 'insertData', 'deleteData', 'replaceData',
      'normalize', 'isEqualNode', 'isSameNode'
    ],
  },
  Console: {
    attributes: [],
    operations: ['log', 'warn', 'error', 'info'],
  },
  CharacterData: {
    attributes: ['data', 'length'],
    operations: ['substringData', 'appendData', 'insertData', 'deleteData', 'replaceData'],
  },
  HTMLElement: {
    attributes: [
      'title', 'lang', 'translate', 'dir', 'hidden', 'inert',
      'accessKey', 'accessKeyLabel', 'draggable', 'spellcheck',
      'writingSuggestions', 'autocapitalize', 'innerText', 'outerText',
      'tabIndex', 'contentEditable', 'isContentEditable', 'popover',
      'dataset', 'offsetParent', 'offsetTop', 'offsetLeft', 'offsetWidth', 'offsetHeight'
    ],
    operations: ['click', 'attachInternals', 'showPopover', 'hidePopover', 'togglePopover'],
  },
  Event: {
    attributes: [
      'type', 'target', 'srcElement', 'currentTarget',
      'bubbles', 'cancelable', 'defaultPrevented', 'composed',
      'isTrusted', 'timeStamp', 'eventPhase'
    ],
    operations: ['stopPropagation', 'stopImmediatePropagation', 'preventDefault', 'initEvent'],
  },
  Window: {
    attributes: [
      'window', 'self', 'document', 'name', 'location', 'history', 'navigator',
      'devicePixelRatio', 'innerWidth', 'innerHeight', 'outerWidth', 'outerHeight',
      'scrollX', 'scrollY', 'pageXOffset', 'pageYOffset', 'screenX', 'screenY'
    ],
    operations: [
      'scroll', 'scrollTo', 'scrollBy', 'alert', 'close', 'focus', 'blur', 'print', 'stop',
      'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval',
      'requestAnimationFrame', 'cancelAnimationFrame', 'getComputedStyle', 'matchMedia'
    ],
  },
  EventTarget: {
    attributes: [],
    operations: ['addEventListener', 'removeEventListener', 'dispatchEvent'],
  },
  DOMTokenList: {
    attributes: ['length', 'value'],
    operations: ['item', 'contains', 'add', 'remove', 'toggle', 'replace', 'supports', 'toString'],
  },
  DOMRect: {
    attributes: ['x', 'y', 'width', 'height', 'top', 'right', 'bottom', 'left'],
    operations: ['fromRect', 'toJSON'],
  },
  Storage: {
    attributes: ['length'],
    operations: ['key', 'getItem', 'setItem', 'removeItem', 'clear'],
  },
  MutationObserver: {
    attributes: [],
    operations: ['observe', 'disconnect', 'takeRecords'],
  },
  IntersectionObserver: {
    attributes: ['root', 'rootMargin', 'thresholds'],
    operations: ['observe', 'unobserve', 'disconnect', 'takeRecords'],
  },
  ResizeObserver: {
    attributes: [],
    operations: ['observe', 'unobserve', 'disconnect'],
  },
  FormData: {
    attributes: [],
    operations: ['append', 'delete', 'get', 'getAll', 'has', 'set', 'keys', 'values', 'entries', 'forEach'],
  },
  URLSearchParams: {
    attributes: [],
    operations: ['append', 'delete', 'get', 'getAll', 'has', 'set', 'sort', 'toString', 'keys', 'values', 'entries', 'forEach'],
  },
  URL: {
    attributes: ['href', 'origin', 'protocol', 'username', 'password', 'host', 'hostname', 'port', 'pathname', 'search', 'searchParams', 'hash'],
    operations: ['toJSON', 'toString'],
  },
};

// Core DOM WebIDL definitions (simplified subset)
const DOM_WEBIDL = `
[Exposed=Window]
interface Node : EventTarget {
  const unsigned short ELEMENT_NODE = 1;
  const unsigned short ATTRIBUTE_NODE = 2;
  const unsigned short TEXT_NODE = 3;
  const unsigned short CDATA_SECTION_NODE = 4;
  const unsigned short ENTITY_REFERENCE_NODE = 5;
  const unsigned short ENTITY_NODE = 6;
  const unsigned short PROCESSING_INSTRUCTION_NODE = 7;
  const unsigned short COMMENT_NODE = 8;
  const unsigned short DOCUMENT_NODE = 9;
  const unsigned short DOCUMENT_TYPE_NODE = 10;
  const unsigned short DOCUMENT_FRAGMENT_NODE = 11;
  const unsigned short NOTATION_NODE = 12;

  readonly attribute unsigned short nodeType;
  readonly attribute DOMString nodeName;

  readonly attribute DOMString? baseURI;

  readonly attribute boolean isConnected;
  readonly attribute Document? ownerDocument;
  Node getRootNode(optional GetRootNodeOptions options = {});
  readonly attribute Node? parentNode;
  readonly attribute Element? parentElement;
  boolean hasChildNodes();
  [SameObject] readonly attribute NodeList childNodes;
  readonly attribute Node? firstChild;
  readonly attribute Node? lastChild;
  readonly attribute Node? previousSibling;
  readonly attribute Node? nextSibling;

  [CEReactions] attribute DOMString? nodeValue;
  [CEReactions] attribute DOMString? textContent;
  [CEReactions] undefined normalize();

  [CEReactions, NewObject] Node cloneNode(optional boolean deep = false);
  boolean isEqualNode(Node? otherNode);
  boolean isSameNode(Node? otherNode);

  const unsigned short DOCUMENT_POSITION_DISCONNECTED = 0x01;
  const unsigned short DOCUMENT_POSITION_PRECEDING = 0x02;
  const unsigned short DOCUMENT_POSITION_FOLLOWING = 0x04;
  const unsigned short DOCUMENT_POSITION_CONTAINS = 0x08;
  const unsigned short DOCUMENT_POSITION_CONTAINED_BY = 0x10;
  const unsigned short DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;
  unsigned short compareDocumentPosition(Node other);
  boolean contains(Node? other);

  DOMString? lookupPrefix(DOMString? namespace);
  DOMString? lookupNamespaceURI(DOMString? prefix);
  boolean isDefaultNamespace(DOMString? namespace);

  [CEReactions] Node insertBefore(Node node, Node? child);
  [CEReactions] Node appendChild(Node node);
  [CEReactions] Node replaceChild(Node node, Node child);
  [CEReactions] Node removeChild(Node child);
};

[Exposed=Window]
interface Element : Node {
  readonly attribute DOMString? namespaceURI;
  readonly attribute DOMString? prefix;
  readonly attribute DOMString localName;
  readonly attribute DOMString tagName;

  [CEReactions] attribute DOMString id;
  [CEReactions] attribute DOMString className;
  [SameObject, PutForwards=value] readonly attribute DOMTokenList classList;
  [CEReactions, Unscopable] attribute DOMString slot;

  boolean hasAttributes();
  [SameObject] readonly attribute NamedNodeMap attributes;
  sequence<DOMString> getAttributeNames();
  DOMString? getAttribute(DOMString qualifiedName);
  DOMString? getAttributeNS(DOMString? namespace, DOMString localName);
  [CEReactions] undefined setAttribute(DOMString qualifiedName, DOMString value);
  [CEReactions] undefined setAttributeNS(DOMString? namespace, DOMString qualifiedName, DOMString value);
  [CEReactions] undefined removeAttribute(DOMString qualifiedName);
  [CEReactions] undefined removeAttributeNS(DOMString? namespace, DOMString localName);
  [CEReactions] boolean toggleAttribute(DOMString qualifiedName, optional boolean force);
  boolean hasAttribute(DOMString qualifiedName);
  boolean hasAttributeNS(DOMString? namespace, DOMString localName);

  Attr? getAttributeNode(DOMString qualifiedName);
  Attr? getAttributeNodeNS(DOMString? namespace, DOMString localName);
  [CEReactions] Attr? setAttributeNode(Attr attr);
  [CEReactions] Attr? setAttributeNodeNS(Attr attr);
  [CEReactions] Attr removeAttributeNode(Attr attr);

  ShadowRoot attachShadow(ShadowRootInit init);
  readonly attribute ShadowRoot? shadowRoot;

  Element? closest(DOMString selectors);
  boolean matches(DOMString selectors);
  boolean webkitMatchesSelector(DOMString selectors);

  HTMLCollection getElementsByTagName(DOMString qualifiedName);
  HTMLCollection getElementsByTagNameNS(DOMString? namespace, DOMString localName);
  HTMLCollection getElementsByClassName(DOMString classNames);

  [CEReactions] Element? insertAdjacentElement(DOMString where, Element element);
  undefined insertAdjacentText(DOMString where, DOMString data);
};

[Exposed=Window]
interface Document : Node {
  constructor();

  [SameObject] readonly attribute DOMImplementation implementation;
  readonly attribute USVString URL;
  readonly attribute USVString documentURI;
  readonly attribute DOMString compatMode;
  readonly attribute DOMString characterSet;
  readonly attribute DOMString charset;
  readonly attribute DOMString inputEncoding;
  readonly attribute DOMString contentType;

  readonly attribute DocumentType? doctype;
  readonly attribute Element? documentElement;
  HTMLCollection getElementsByTagName(DOMString qualifiedName);
  HTMLCollection getElementsByTagNameNS(DOMString? namespace, DOMString localName);
  HTMLCollection getElementsByClassName(DOMString classNames);

  [CEReactions, NewObject] Element createElement(DOMString localName, optional (DOMString or ElementCreationOptions) options = {});
  [CEReactions, NewObject] Element createElementNS(DOMString? namespace, DOMString qualifiedName, optional (DOMString or ElementCreationOptions) options = {});
  [NewObject] DocumentFragment createDocumentFragment();
  [NewObject] Text createTextNode(DOMString data);
  [NewObject] CDATASection createCDATASection(DOMString data);
  [NewObject] Comment createComment(DOMString data);
  [NewObject] ProcessingInstruction createProcessingInstruction(DOMString target, DOMString data);

  [CEReactions, NewObject] Node importNode(Node node, optional boolean deep = false);
  [CEReactions] Node adoptNode(Node node);

  [NewObject] Attr createAttribute(DOMString localName);
  [NewObject] Attr createAttributeNS(DOMString? namespace, DOMString qualifiedName);

  [NewObject] Event createEvent(DOMString interface);

  [NewObject] Range createRange();

  [NewObject] NodeIterator createNodeIterator(Node root, optional unsigned long whatToShow = 0xFFFFFFFF, optional NodeFilter? filter = null);
  [NewObject] TreeWalker createTreeWalker(Node root, optional unsigned long whatToShow = 0xFFFFFFFF, optional NodeFilter? filter = null);
};

partial interface Document {
  [CEReactions] attribute DOMString title;
  [CEReactions] attribute DOMString dir;
  [CEReactions] attribute HTMLElement? body;
  readonly attribute HTMLHeadElement? head;
  [SameObject] readonly attribute HTMLCollection images;
  [SameObject] readonly attribute HTMLCollection embeds;
  [SameObject] readonly attribute HTMLCollection plugins;
  [SameObject] readonly attribute HTMLCollection links;
  [SameObject] readonly attribute HTMLCollection forms;
  [SameObject] readonly attribute HTMLCollection scripts;
  NodeList getElementsByName(DOMString elementName);

  readonly attribute Element? activeElement;

  Element? getElementById(DOMString elementId);
};

[Exposed=Window]
interface Text : CharacterData {
  constructor(optional DOMString data = "");

  [NewObject] Text splitText(unsigned long offset);
  readonly attribute DOMString wholeText;
};

[Exposed=Window]
interface CharacterData : Node {
  attribute DOMString data;
  readonly attribute unsigned long length;
  DOMString substringData(unsigned long offset, unsigned long count);
  undefined appendData(DOMString data);
  undefined insertData(unsigned long offset, DOMString data);
  undefined deleteData(unsigned long offset, unsigned long count);
  undefined replaceData(unsigned long offset, unsigned long count, DOMString data);
};

interface mixin ParentNode {
  [SameObject] readonly attribute HTMLCollection children;
  readonly attribute Element? firstElementChild;
  readonly attribute Element? lastElementChild;
  readonly attribute unsigned long childElementCount;

  [CEReactions, Unscopable] undefined prepend((Node or DOMString)... nodes);
  [CEReactions, Unscopable] undefined append((Node or DOMString)... nodes);
  [CEReactions, Unscopable] undefined replaceChildren((Node or DOMString)... nodes);

  Element? querySelector(DOMString selectors);
  [NewObject] NodeList querySelectorAll(DOMString selectors);
};

Document includes ParentNode;
Element includes ParentNode;

interface mixin NonElementParentNode {
  Element? getElementById(DOMString elementId);
};

Document includes NonElementParentNode;

interface mixin ChildNode {
  [CEReactions, Unscopable] undefined before((Node or DOMString)... nodes);
  [CEReactions, Unscopable] undefined after((Node or DOMString)... nodes);
  [CEReactions, Unscopable] undefined replaceWith((Node or DOMString)... nodes);
  [CEReactions, Unscopable] undefined remove();
};

Element includes ChildNode;
Text includes ChildNode;

[Exposed=Window]
interface HTMLElement : Element {
  [HTMLConstructor] constructor();

  [CEReactions] attribute DOMString title;
  [CEReactions] attribute DOMString lang;
  [CEReactions] attribute boolean translate;
  [CEReactions] attribute DOMString dir;

  [CEReactions] attribute boolean hidden;
  [CEReactions] attribute DOMString? inert;
  undefined click();
  [CEReactions] attribute DOMString accessKey;
  readonly attribute DOMString accessKeyLabel;
  [CEReactions] attribute boolean draggable;
  [CEReactions] attribute boolean spellcheck;
  [CEReactions] attribute DOMString writingSuggestions;
  [CEReactions] attribute DOMString autocapitalize;

  [CEReactions] attribute DOMString innerText;
  [CEReactions] attribute DOMString outerText;

  ElementInternals attachInternals();

  [CEReactions] attribute boolean showPopover;
  undefined showPopover();
  undefined hidePopover();
  boolean togglePopover(optional boolean force);
};

[Exposed=*]
interface Event {
  constructor(DOMString type, optional EventInit eventInitDict = {});

  readonly attribute DOMString type;
  readonly attribute EventTarget? target;
  readonly attribute EventTarget? srcElement;
  readonly attribute EventTarget? currentTarget;

  readonly attribute boolean bubbles;
  readonly attribute boolean cancelable;
  readonly attribute boolean defaultPrevented;
  readonly attribute boolean composed;

  readonly attribute boolean isTrusted;
  readonly attribute DOMHighResTimeStamp timeStamp;

  undefined stopPropagation();
  undefined stopImmediatePropagation();
  undefined preventDefault();

  readonly attribute unsigned short eventPhase;

  undefined initEvent(DOMString type, optional boolean bubbles = false, optional boolean cancelable = false);
};

[Exposed=Window]
interface Window : EventTarget {
  readonly attribute Window window;
  readonly attribute Window self;
  readonly attribute Document document;
  readonly attribute DOMString name;
  readonly attribute Location location;
  readonly attribute History history;
  readonly attribute Navigator navigator;

  readonly attribute double devicePixelRatio;

  readonly attribute long innerWidth;
  readonly attribute long innerHeight;
  readonly attribute long outerWidth;
  readonly attribute long outerHeight;
  readonly attribute long scrollX;
  readonly attribute long scrollY;
  readonly attribute long pageXOffset;
  readonly attribute long pageYOffset;
  readonly attribute long screenX;
  readonly attribute long screenY;

  undefined scroll(optional ScrollToOptions options = {});
  undefined scrollTo(optional ScrollToOptions options = {});
  undefined scrollBy(optional ScrollToOptions options = {});

  undefined alert(optional DOMString message = "");
  undefined close();
  undefined focus();
  undefined blur();
  undefined print();
  undefined stop();

  long setTimeout(TimerHandler handler, optional long timeout = 0);
  undefined clearTimeout(optional long id = 0);
  long setInterval(TimerHandler handler, optional long timeout = 0);
  undefined clearInterval(optional long id = 0);
  long requestAnimationFrame(FrameRequestCallback callback);
  undefined cancelAnimationFrame(long handle);

  any getComputedStyle(Element elt, optional DOMString? pseudoElt);
  MediaQueryList matchMedia(DOMString query);
};

[Exposed=Window]
interface EventTarget {
  constructor();
  undefined addEventListener(DOMString type, EventListener? callback, optional (AddEventListenerOptions or boolean) options = {});
  undefined removeEventListener(DOMString type, EventListener? callback, optional (EventListenerOptions or boolean) options = {});
  boolean dispatchEvent(Event event);
};

[Exposed=Window]
interface DOMTokenList {
  readonly attribute unsigned long length;
  attribute DOMString value;
  getter DOMString? item(unsigned long index);
  boolean contains(DOMString token);
  undefined add(DOMString... tokens);
  undefined remove(DOMString... tokens);
  boolean toggle(DOMString token, optional boolean force);
  boolean replace(DOMString token, DOMString newToken);
  boolean supports(DOMString token);
  stringifier;
};

[Exposed=Window]
interface DOMRect : DOMRectReadOnly {
  constructor(optional unrestricted double x = 0, optional unrestricted double y = 0,
              optional unrestricted double width = 0, optional unrestricted double height = 0);
  attribute unrestricted double x;
  attribute unrestricted double y;
  attribute unrestricted double width;
  attribute unrestricted double height;
  readonly attribute unrestricted double top;
  readonly attribute unrestricted double right;
  readonly attribute unrestricted double bottom;
  readonly attribute unrestricted double left;
  static DOMRect fromRect(optional DOMRectInit other = {});
  object toJSON();
};

[Exposed=Window]
interface Storage {
  readonly attribute unsigned long length;
  DOMString? key(unsigned long index);
  getter DOMString? getItem(DOMString key);
  setter undefined setItem(DOMString key, DOMString value);
  deleter undefined removeItem(DOMString key);
  undefined clear();
};

[Exposed=Window]
interface MutationObserver {
  constructor(MutationCallback callback);
  undefined observe(Node target, optional MutationObserverInit options = {});
  undefined disconnect();
  sequence<MutationRecord> takeRecords();
};

[Exposed=Window]
interface IntersectionObserver {
  constructor(IntersectionObserverCallback callback, optional IntersectionObserverInit options = {});
  readonly attribute Element? root;
  readonly attribute DOMString rootMargin;
  readonly attribute FrozenArray<double> thresholds;
  undefined observe(Element target);
  undefined unobserve(Element target);
  undefined disconnect();
  sequence<IntersectionObserverEntry> takeRecords();
};

[Exposed=Window]
interface ResizeObserver {
  constructor(ResizeObserverCallback callback);
  undefined observe(Element target, optional ResizeObserverOptions options = {});
  undefined unobserve(Element target);
  undefined disconnect();
};

[Exposed=(Window,Worker)]
interface FormData {
  constructor(optional HTMLFormElement form, optional HTMLElement? submitter = null);
  undefined append(USVString name, USVString value);
  undefined delete(USVString name);
  USVString? get(USVString name);
  sequence<USVString> getAll(USVString name);
  boolean has(USVString name);
  undefined set(USVString name, USVString value);
  iterable<USVString, FormDataEntryValue>;
};

[Exposed=*]
interface URLSearchParams {
  constructor(optional (sequence<sequence<USVString>> or record<USVString, USVString> or USVString) init = "");
  undefined append(USVString name, USVString value);
  undefined delete(USVString name);
  USVString? get(USVString name);
  sequence<USVString> getAll(USVString name);
  boolean has(USVString name);
  undefined set(USVString name, USVString value);
  undefined sort();
  stringifier;
  iterable<USVString, USVString>;
};

[Exposed=*]
interface URL {
  constructor(USVString url, optional USVString base);
  attribute USVString href;
  readonly attribute USVString origin;
  attribute USVString protocol;
  attribute USVString username;
  attribute USVString password;
  attribute USVString host;
  attribute USVString hostname;
  attribute USVString port;
  attribute USVString pathname;
  attribute USVString search;
  readonly attribute URLSearchParams searchParams;
  attribute USVString hash;
  USVString toJSON();
  stringifier;
};
`;

interface InterfaceMember {
  name: string;
  type: 'attribute' | 'operation' | 'const';
  readonly?: boolean;
  static?: boolean;
}

interface ParsedInterface {
  name: string;
  inherits?: string;
  members: InterfaceMember[];
  mixins: string[];
}

function parseWebIDL(idl: string): Map<string, ParsedInterface> {
  const interfaces = new Map<string, ParsedInterface>();
  const mixins = new Map<string, InterfaceMember[]>();
  const includes: Array<{ target: string; mixin: string }> = [];

  try {
    const parsed = WebIDL2.parse(idl);

    for (const def of parsed) {
      if (def.type === 'interface') {
        const members: InterfaceMember[] = [];
        for (const member of def.members) {
          if (member.type === 'attribute') {
            members.push({
              name: member.name,
              type: 'attribute',
              readonly: member.readonly,
            });
          } else if (member.type === 'operation' && member.name) {
            members.push({
              name: member.name,
              type: 'operation',
            });
          } else if (member.type === 'const') {
            members.push({
              name: member.name,
              type: 'const',
            });
          }
        }

        const existing = interfaces.get(def.name);
        if (existing) {
          // Partial interface - merge members
          existing.members.push(...members);
        } else {
          interfaces.set(def.name, {
            name: def.name,
            inherits: def.inheritance?.name,
            members,
            mixins: [],
          });
        }
      } else if (def.type === 'interface mixin') {
        const members: InterfaceMember[] = [];
        for (const member of def.members) {
          if (member.type === 'attribute') {
            members.push({
              name: member.name,
              type: 'attribute',
              readonly: member.readonly,
            });
          } else if (member.type === 'operation' && member.name) {
            members.push({
              name: member.name,
              type: 'operation',
            });
          }
        }
        mixins.set(def.name, members);
      } else if (def.type === 'includes') {
        includes.push({ target: def.target, mixin: def.includes });
      }
    }

    // Apply mixins
    for (const inc of includes) {
      const iface = interfaces.get(inc.target);
      const mixin = mixins.get(inc.mixin);
      if (iface && mixin) {
        iface.mixins.push(inc.mixin);
        iface.members.push(...mixin);
      }
    }

    // Apply inheritance
    for (const [name, iface] of interfaces) {
      if (iface.inherits) {
        const parent = interfaces.get(iface.inherits);
        if (parent) {
          // Add parent members (inherited)
          const inheritedNames = new Set(iface.members.map(m => m.name));
          for (const member of parent.members) {
            if (!inheritedNames.has(member.name)) {
              iface.members.push({ ...member });
            }
          }
        }
      }
    }
  } catch (e) {
    console.error('Failed to parse WebIDL:', e);
  }

  return interfaces;
}

interface CoverageResult {
  interface: string;
  total: number;
  implemented: number;
  percentage: number;
  missing: string[];
  extra: string[];
}

function analyzeCoverage(interfaces: Map<string, ParsedInterface>): CoverageResult[] {
  const results: CoverageResult[] = [];

  for (const [name, impl] of Object.entries(IMPLEMENTED)) {
    const spec = interfaces.get(name);
    if (!spec) {
      results.push({
        interface: name,
        total: 0,
        implemented: impl.attributes.length + impl.operations.length,
        percentage: 100,
        missing: [],
        extra: [...impl.attributes, ...impl.operations],
      });
      continue;
    }

    const specMembers = new Set(
      spec.members
        .filter(m => m.type === 'attribute' || m.type === 'operation')
        .map(m => m.name)
    );

    const implMembers = new Set([...impl.attributes, ...impl.operations]);

    const missing = [...specMembers].filter(m => !implMembers.has(m));
    const extra = [...implMembers].filter(m => !specMembers.has(m));

    const implemented = [...implMembers].filter(m => specMembers.has(m)).length;

    results.push({
      interface: name,
      total: specMembers.size,
      implemented,
      percentage: specMembers.size > 0 ? Math.round((implemented / specMembers.size) * 100) : 100,
      missing,
      extra,
    });
  }

  return results;
}

function generateReport(results: CoverageResult[]): void {
  console.log('\n=== WebIDL Coverage Report ===\n');

  let totalSpec = 0;
  let totalImpl = 0;

  for (const result of results) {
    const bar = '█'.repeat(Math.floor(result.percentage / 5)) + '░'.repeat(20 - Math.floor(result.percentage / 5));
    console.log(`${result.interface.padEnd(12)} [${bar}] ${result.percentage}% (${result.implemented}/${result.total})`);

    if (result.missing.length > 0 && result.missing.length <= 10) {
      console.log(`  Missing: ${result.missing.join(', ')}`);
    } else if (result.missing.length > 10) {
      console.log(`  Missing: ${result.missing.slice(0, 10).join(', ')} ... +${result.missing.length - 10} more`);
    }

    totalSpec += result.total;
    totalImpl += result.implemented;
  }

  console.log('\n--- Summary ---');
  const overallPct = totalSpec > 0 ? Math.round((totalImpl / totalSpec) * 100) : 0;
  console.log(`Overall: ${totalImpl}/${totalSpec} members implemented (${overallPct}%)`);
}

function generateMoonBitStub(interfaces: Map<string, ParsedInterface>): string {
  const lines: string[] = [];
  lines.push('// Auto-generated DOM interface stubs from WebIDL');
  lines.push('// Run: npx tsx scripts/webidl-coverage.ts --generate');
  lines.push('');

  for (const [name, iface] of interfaces) {
    if (!['Node', 'Element', 'Document', 'Text', 'HTMLElement'].includes(name)) continue;

    lines.push(`///|`);
    lines.push(`/// ${name} interface`);
    if (iface.inherits) {
      lines.push(`/// Inherits from: ${iface.inherits}`);
    }
    if (iface.mixins.length > 0) {
      lines.push(`/// Includes: ${iface.mixins.join(', ')}`);
    }
    lines.push(`pub struct ${name} {`);
    lines.push(`  // TODO: Add fields`);
    lines.push(`}`);
    lines.push('');

    // Generate method stubs
    for (const member of iface.members) {
      if (member.type === 'attribute') {
        const impl = IMPLEMENTED[name as keyof typeof IMPLEMENTED];
        const isImpl = impl && (impl.attributes.includes(member.name) || impl.operations.includes(member.name));
        const marker = isImpl ? '✓' : '✗';

        lines.push(`///|`);
        lines.push(`/// [${marker}] ${member.readonly ? 'readonly ' : ''}attribute ${member.name}`);
        lines.push(`pub fn ${name}::${member.name}(self : ${name}) -> String {`);
        lines.push(`  abort("${name}.${member.name} not implemented")`);
        lines.push(`}`);
        lines.push('');
      } else if (member.type === 'operation') {
        const impl = IMPLEMENTED[name as keyof typeof IMPLEMENTED];
        const isImpl = impl && impl.operations.includes(member.name);
        const marker = isImpl ? '✓' : '✗';

        lines.push(`///|`);
        lines.push(`/// [${marker}] operation ${member.name}()`);
        lines.push(`pub fn ${name}::${member.name}(self : ${name}) -> Unit {`);
        lines.push(`  abort("${name}.${member.name}() not implemented")`);
        lines.push(`}`);
        lines.push('');
      }
    }
    lines.push('');
  }

  return lines.join('\n');
}

function listAllMembers(interfaces: Map<string, ParsedInterface>): void {
  console.log('\n=== All WebIDL Interface Members ===\n');

  for (const [name, iface] of interfaces) {
    if (!['Node', 'Element', 'Document', 'Text', 'HTMLElement', 'CharacterData', 'Event', 'Window', 'EventTarget', 'DOMTokenList', 'DOMRect', 'Storage', 'MutationObserver', 'IntersectionObserver', 'ResizeObserver', 'FormData', 'URLSearchParams', 'URL'].includes(name)) continue;

    console.log(`\n## ${name}${iface.inherits ? ` : ${iface.inherits}` : ''}`);
    if (iface.mixins.length > 0) {
      console.log(`   includes: ${iface.mixins.join(', ')}`);
    }

    const impl = IMPLEMENTED[name as keyof typeof IMPLEMENTED];
    const implMembers = impl ? new Set([...impl.attributes, ...impl.operations]) : new Set();

    const attrs = iface.members.filter(m => m.type === 'attribute');
    const ops = iface.members.filter(m => m.type === 'operation');

    if (attrs.length > 0) {
      console.log('\n   Attributes:');
      for (const attr of attrs) {
        const marker = implMembers.has(attr.name) ? '✓' : '✗';
        console.log(`     [${marker}] ${attr.readonly ? 'readonly ' : ''}${attr.name}`);
      }
    }

    if (ops.length > 0) {
      console.log('\n   Operations:');
      for (const op of ops) {
        const marker = implMembers.has(op.name) ? '✓' : '✗';
        console.log(`     [${marker}] ${op.name}()`);
      }
    }
  }
}

// Main
const args = process.argv.slice(2);
const interfaces = parseWebIDL(DOM_WEBIDL);

if (args.includes('--json')) {
  const results = analyzeCoverage(interfaces);
  console.log(JSON.stringify(results, null, 2));
} else if (args.includes('--generate')) {
  console.log(generateMoonBitStub(interfaces));
} else if (args.includes('--list')) {
  listAllMembers(interfaces);
} else {
  generateReport(analyzeCoverage(interfaces));
  console.log('\nUse --list for detailed member list, --json for JSON output, --generate for MoonBit stubs');
}
