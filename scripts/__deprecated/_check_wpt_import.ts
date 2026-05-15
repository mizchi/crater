(async () => {
  try {
    const candidates = [
      '../_build/js/release/build/mizchi/crater-testing/wpt_runtime/wpt_runtime.js',
      '../_build/js/release/build/wpt_runtime/wpt_runtime.js',
    ];
    let lastError = '';
    for (const candidate of candidates) {
      try {
        const mod = await import(candidate);
        console.log('import-ok', typeof mod.renderHtmlToJsonForWpt);
        return;
      } catch (e) {
        lastError = e instanceof Error ? e.message : String(e);
      }
    }
    console.log('import-failed', lastError);
  } catch (e) {
    console.log('import-failed', e instanceof Error ? e.message : String(e));
  }
})();
