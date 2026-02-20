(async () => {
  try {
    const mod = await import('../_build/js/release/build/wpt_runtime/wpt_runtime.js');
    console.log('import-ok', typeof mod.renderHtmlToJsonForWpt);
  } catch (e) {
    console.log('import-failed', e instanceof Error ? e.message : String(e));
  }
})();
