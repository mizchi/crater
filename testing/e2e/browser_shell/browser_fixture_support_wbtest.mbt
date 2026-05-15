///|
fn load_fixture(browser : @shell.Browser, html : String) -> Unit {
  browser.set_html_content(html)
}

///|
extern "js" fn js_load_builtin_github_snapshot() -> String =
  #| () => {
  #|   const fs = require("node:fs");
  #|   const path = require("node:path");
  #|   const candidates = [
  #|     path.join(process.cwd(), "benchmarks", "fixtures"),
  #|     path.join(process.cwd(), "..", "benchmarks", "fixtures"),
  #|     path.join(process.cwd(), "src", "benchmarks", "fixtures"),
  #|     path.join(process.cwd(), "..", "src", "benchmarks", "fixtures"),
  #|   ];
  #|   const dir = candidates.find((candidate) =>
  #|     fs.existsSync(path.join(candidate, "github_mizchi.html"))
  #|   );
  #|   if (!dir) {
  #|     throw new Error(
  #|       `github snapshot fixture directory not found: ${candidates.join(", ")}`,
  #|     );
  #|   }
  #|   const html = fs.readFileSync(path.join(dir, "github_mizchi.html"), "utf8");
  #|   const cssFiles = [
  #|     "github_primer.css",
  #|     "github_global.css",
  #|     "github_main.css",
  #|     "github_profile.css",
  #|   ];
  #|   const styles = cssFiles.map((name, index) => {
  #|     const css = fs.readFileSync(path.join(dir, name), "utf8");
  #|     return `<style data-real-world-style="${index + 1}">\n${css}\n</style>`;
  #|   }).join("\n");
  #|   const withoutScripts = String(html)
  #|     .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
  #|     .replace(/<script\b[^>]*\/\s*>/gi, "");
  #|   const withoutLinks = withoutScripts
  #|     .replace(/<link\b[^>]*rel=(['"])[^'"]*stylesheet[^'"]*\1[^>]*>/gi, "")
  #|     .replace(/<link\b[^>]*rel=(['"])[^'"]*(dns-prefetch|preconnect|prefetch|preload)[^'"]*\1[^>]*>/gi, "");
  #|   return withoutLinks.replace(
  #|     /<\/head>/i,
  #|     `<base href="https://github.com/mizchi">\n${styles}\n</head>`,
  #|   );
  #| }

///|
fn builtin_github_snapshot_fixture() -> String {
  js_load_builtin_github_snapshot()
}

///|
fn docs_article_fixture() -> String {
  let buf = StringBuilder::new()
  buf.write_string(
    "<!DOCTYPE html><html><body style=\"margin:0;background:#202532;color:#f6f7fb\">",
  )
  buf.write_string(
    "<header style=\"padding:24px 40px;border-bottom:1px solid #39404f\">",
  )
  buf.write_string(
    "<nav style=\"display:flex;gap:24px\"><a href=\"#html\">HTML</a><a href=\"#css\">CSS</a><a href=\"#js\">JavaScript</a><a href=\"#api\">Web APIs</a></nav>",
  )
  buf.write_string("</header>")
  buf.write_string(
    "<main style=\"display:grid;grid-template-columns:240px 1fr;gap:32px;padding:32px 40px\">",
  )
  buf.write_string("<aside style=\"padding-top:16px\">")
  for i = 0; i < 18; i = i + 1 {
    buf.write_string("<div style=\"margin-bottom:12px\"><a href=\"#sec")
    buf.write_string(i.to_string())
    buf.write_string("\">節 ")
    buf.write_string(i.to_string())
    buf.write_string("</a></div>")
  }
  buf.write_string("</aside>")
  buf.write_string("<article style=\"max-width:860px\">")
  buf.write_string(
    "<h1 style=\"font-size:42px;margin:0 0 16px\">WebAssembly テキスト形式の理解</h1>",
  )
  buf.write_string(
    "<p style=\"margin:0 0 20px\">バイナリーとテキスト形式の両方で WebAssembly のモジュールを表現できます。</p>",
  )
  for i = 0; i < 14; i = i + 1 {
    buf.write_string("<section id=\"sec")
    buf.write_string(i.to_string())
    buf.write_string("\" style=\"margin-bottom:28px\">")
    buf.write_string(
      "<h2 style=\"font-size:28px;margin:0 0 12px\">セクション ",
    )
    buf.write_string(i.to_string())
    buf.write_string("</h2>")
    buf.write_string(
      "<p style=\"margin:0 0 12px\">S 式はツリー構造を表現するための構文で、括弧とラベルの並びから構成されます。</p>",
    )
    buf.write_string(
      "<pre style=\"padding:16px;background:#171b25;border-radius:8px;overflow:auto\">(module (func (export \\\"run\\\") nop))</pre>",
    )
    buf.write_string("</section>")
  }
  buf.write_string("</article></main></body></html>")
  buf.to_string()
}
