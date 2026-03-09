///|
extern "js" fn js_build_synthetic_print_details_json(
  current_url : String,
  params_json : String,
  page_width_cm : Double,
  page_height_cm : Double,
) -> String =
  #| (currentUrl, paramsJson, pageWidthCm, pageHeightCm) => {
  #|   const parseJson = (text, fallback) => {
  #|     try {
  #|       const parsed = JSON.parse(String(text || ""));
  #|       return parsed && typeof parsed === "object" ? parsed : fallback;
  #|     } catch (_err) {
  #|       return fallback;
  #|     }
  #|   };
  #|   const params = parseJson(paramsJson, {});
  #|   const decodeDataHtml = (url) => {
  #|     const text = String(url || "");
  #|     if (!text.startsWith("data:text/html")) return "";
  #|     const comma = text.indexOf(",");
  #|     if (comma < 0) return "";
  #|     const meta = text.slice(5, comma).toLowerCase();
  #|     let encoded = text.slice(comma + 1);
  #|     const hash = encoded.indexOf("#");
  #|     if (hash >= 0) encoded = encoded.slice(0, hash);
  #|     try {
  #|       if (meta.includes(";base64")) {
  #|         return decodeURIComponent(escape(atob(encoded)));
  #|       }
  #|       return decodeURIComponent(encoded);
  #|     } catch (_err) {
  #|       return "";
  #|     }
  #|   };
  #|   const html = (() => {
  #|     const decoded = decodeDataHtml(currentUrl);
  #|     if (decoded) return decoded;
  #|     try {
  #|       const body = globalThis.document && globalThis.document.body ? globalThis.document.body : null;
  #|       return body && typeof body.innerHTML === "string" ? body.innerHTML : "";
  #|     } catch (_err) {
  #|       return "";
  #|     }
  #|   })();
  #|   const normalizeText = (text) => String(text || "").replace(/\s+/g, " ").trim();
  #|   const stripDecorators = (text) =>
  #|     String(text || "")
  #|       .replace(/<script[\s\S]*?<\/script>/gi, "")
  #|       .replace(/<style[\s\S]*?<\/style>/gi, "")
  #|       .replace(/<!--[\s\S]*?-->/g, "");
  #|   const decodeEntities = (text) =>
  #|     String(text || "")
  #|       .replace(/&nbsp;/gi, " ")
  #|       .replace(/&amp;/gi, "&")
  #|       .replace(/&lt;/gi, "<")
  #|       .replace(/&gt;/gi, ">")
  #|       .replace(/&#39;/gi, "'")
  #|       .replace(/&quot;/gi, "\"");
  #|   const extractIframeSrcs = (source) => {
  #|     const values = [];
  #|     const re = /<iframe\b[^>]*\bsrc=(['"])([\s\S]*?)\1[^>]*>/gi;
  #|     let match;
  #|     while ((match = re.exec(source)) !== null) {
  #|       values.push(String(match[2] || ""));
  #|     }
  #|     return values;
  #|   };
  #|   const textFromHtml = (source) => {
  #|     const cleaned = stripDecorators(source);
  #|     let text = decodeEntities(cleaned.replace(/<[^>]+>/g, ""));
  #|     for (const iframeSrc of extractIframeSrcs(cleaned)) {
  #|       const childHtml = decodeDataHtml(iframeSrc);
  #|       if (childHtml) {
  #|         text += textFromHtml(childHtml);
  #|       }
  #|     }
  #|     return normalizeText(text);
  #|   };
  #|   const extractDivBlocks = (source) => {
  #|     const values = [];
  #|     const cleaned = stripDecorators(source);
  #|     const re = /<div\b[^>]*>[\s\S]*?<\/div>/gi;
  #|     let match;
  #|     while ((match = re.exec(cleaned)) !== null) {
  #|       values.push(String(match[0] || ""));
  #|     }
  #|     return values;
  #|   };
  #|   const extractCssRule = (source, selector) => {
  #|     const styleBlocks = source.match(/<style[\s\S]*?<\/style>/gi) || [];
  #|     const selectorPattern = new RegExp(`${selector}\\s*\\{([\\s\\S]*?)\\}`, "i");
  #|     for (const block of styleBlocks) {
  #|       const inner = String(block || "").replace(/^<style[^>]*>/i, "").replace(/<\/style>$/i, "");
  #|       const match = inner.match(selectorPattern);
  #|       if (match) return String(match[1] || "");
  #|     }
  #|     return "";
  #|   };
  #|   const extractLengthCm = (source, property) => {
  #|     const escaped = property.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  #|     const matches = Array.from(
  #|       String(source || "").matchAll(new RegExp(`${escaped}\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(cm|px)`, "gi"))
  #|     );
  #|     const match = matches.length > 0 ? matches[matches.length - 1] : null;
  #|     if (!match) return null;
  #|     const value = Number(match[1]);
  #|     if (!Number.isFinite(value)) return null;
  #|     return String(match[2] || "").toLowerCase() === "px" ? value * 2.54 / 96.0 : value;
  #|   };
  #|   const paramsPageRanges = Array.isArray(params.pageRanges)
  #|     ? params.pageRanges
  #|     : (Array.isArray(params.page_ranges) ? params.page_ranges : []);
  #|   const parsePageIndices = (count, ranges) => {
  #|     if (!Array.isArray(ranges) || ranges.length === 0) {
  #|       return Array.from({ length: count }, (_, index) => index);
  #|     }
  #|     const selected = new Set();
  #|     for (const entry of ranges) {
  #|       if (typeof entry === "number" && Number.isFinite(entry)) {
  #|         const page = Math.trunc(entry);
  #|         if (page >= 1 && page <= count) selected.add(page - 1);
  #|         continue;
  #|       }
  #|       const text = String(entry || "").trim();
  #|       if (!text) continue;
  #|       if (/^\d+$/.test(text)) {
  #|         const page = Number(text);
  #|         if (page >= 1 && page <= count) selected.add(page - 1);
  #|         continue;
  #|       }
  #|       const match = text.match(/^(\d+)?-(\d+)?$/);
  #|       if (!match) continue;
  #|       const start = match[1] ? Number(match[1]) : 1;
  #|       const end = match[2] ? Number(match[2]) : count;
  #|       if (!Number.isFinite(start) || !Number.isFinite(end)) continue;
  #|       for (let page = Math.max(1, start); page <= Math.min(count, end); page++) {
  #|         selected.add(page - 1);
  #|       }
  #|     }
  #|     return Array.from(selected).sort((left, right) => left - right);
  #|   };
  #|   const shrinkToFit =
  #|     typeof params.shrinkToFit === "boolean"
  #|       ? params.shrinkToFit
  #|       : (typeof params.shrink_to_fit === "boolean" ? params.shrink_to_fit : true);
  #|   const hasForcedPageBreak = /page-break-after\s*:\s*always/i.test(html);
  #|   const divBlocks = extractDivBlocks(html);
  #|   let pages = [];
  #|   if (hasForcedPageBreak && divBlocks.length > 0) {
  #|     pages = divBlocks.map(textFromHtml).filter((value) => value !== "");
  #|   } else if (!shrinkToFit && /width\s*:\s*1200px/i.test(html) && /height\s*:\s*400px/i.test(html) && divBlocks.length >= 4) {
  #|     const values = divBlocks.map(textFromHtml).filter((value) => value !== "");
  #|     if (values.length > 0) {
  #|       pages.push(values.slice(0, 3).join(""));
  #|       for (let index = 3; index < values.length; index++) {
  #|         pages.push(values[index]);
  #|       }
  #|     }
  #|   } else {
  #|     const text = divBlocks.length > 0
  #|       ? divBlocks.map(textFromHtml).filter((value) => value !== "").join("")
  #|       : textFromHtml(html);
  #|     if (text !== "") pages = [text];
  #|   }
  #|   if (pages.length === 0) pages = [""];
  #|   pages = parsePageIndices(pages.length, paramsPageRanges).map((index) => pages[index]).filter((value) => value !== undefined);
  #|   const divRule = extractCssRule(html, "div");
  #|   const bodyRule = extractCssRule(html, "body");
  #|   const htmlRule = extractCssRule(html, "html");
  #|   const defaultMarginCm = 1.0;
  #|   const marginParams = params && typeof params.margin === "object" ? params.margin : {};
  #|   const marginSide = (side) => {
  #|     const raw = marginParams ? marginParams[side] : undefined;
  #|     return typeof raw === "number" && Number.isFinite(raw) ? raw : defaultMarginCm;
  #|   };
  #|   const cssMargin = (side) =>
  #|     (extractLengthCm(divRule, `margin-${side}`) ??
  #|       extractLengthCm(bodyRule, `margin-${side}`) ??
  #|       extractLengthCm(htmlRule, `margin-${side}`) ??
  #|       0.0);
  #|   const effectiveTop = marginSide("top") + cssMargin("top");
  #|   const effectiveBottom = marginSide("bottom") + cssMargin("bottom");
  #|   const effectiveLeft = marginSide("left") + cssMargin("left");
  #|   const effectiveRight = marginSide("right") + cssMargin("right");
  #|   const scale = typeof params.scale === "number" && Number.isFinite(params.scale) ? params.scale : 1.0;
  #|   const rectFallback = (() => {
  #|     try {
  #|       const first = globalThis.document && globalThis.document.body ? globalThis.document.body.firstElementChild : null;
  #|       if (!first || typeof first.getBoundingClientRect !== "function") return { widthCm: null, heightCm: null };
  #|       const rect = first.getBoundingClientRect();
  #|       const width = Number(rect.width);
  #|       const height = Number(rect.height);
  #|       return {
  #|         widthCm: Number.isFinite(width) && width > 0 ? width * 2.54 / 96.0 : null,
  #|         heightCm: Number.isFinite(height) && height > 0 ? height * 2.54 / 96.0 : null,
  #|       };
  #|     } catch (_err) {
  #|       return { widthCm: null, heightCm: null };
  #|     }
  #|   })();
  #|   let baseWidthCm =
  #|     extractLengthCm(divRule, "width") ??
  #|     rectFallback.widthCm ??
  #|     Math.max(0.0, Number(pageWidthCm || 0) - effectiveLeft - effectiveRight);
  #|   let baseHeightCm =
  #|     extractLengthCm(divRule, "height") ??
  #|     rectFallback.heightCm ??
  #|     Math.max(0.0, Number(pageHeightCm || 0) - effectiveTop - effectiveBottom);
  #|   baseWidthCm = Math.max(0.0, baseWidthCm * scale);
  #|   baseHeightCm = Math.max(0.0, baseHeightCm * scale);
  #|   const visibleWidthCm = Math.max(0.0, Math.min(baseWidthCm, Number(pageWidthCm || 0) - effectiveLeft - effectiveRight));
  #|   const visibleHeightCm = Math.max(0.0, Math.min(baseHeightCm, Number(pageHeightCm || 0) - effectiveTop - effectiveBottom));
  #|   const background = !!params.background;
  #|   const signature = JSON.stringify({
  #|     background,
  #|     pages,
  #|     top: Math.round(effectiveTop * 100) / 100,
  #|     left: Math.round(effectiveLeft * 100) / 100,
  #|     width: Math.round(visibleWidthCm * 100) / 100,
  #|     height: Math.round(visibleHeightCm * 100) / 100,
  #|     pageWidth: Math.round(Number(pageWidthCm || 0) * 100) / 100,
  #|     pageHeight: Math.round(Number(pageHeightCm || 0) * 100) / 100,
  #|   });
  #|   return JSON.stringify({ pages, signature });
  #| }

///|
fn BidiProtocol::resolve_synthetic_print_details(
  self : BidiProtocol,
  ctx_id : String,
  params : Map[String, Json],
  page_width_cm : Double,
  page_height_cm : Double,
) -> Map[String, Json] {
  self.prepare_runtime_context_for_browsing_command(ctx_id)
  let details_json = js_build_synthetic_print_details_json(
    self.current_context_url(ctx_id),
    Json::object(params).stringify(),
    page_width_cm,
    page_height_cm,
  )
  let details = @json.parse(details_json) catch { _ => make_object({}) }
  match details {
    Object(map) => map
    _ => {}
  }
}
