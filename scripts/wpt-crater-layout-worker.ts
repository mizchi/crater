import { parentPort } from 'worker_threads';

process.env.CRATER_WPT_RENDER_WORKER = '1';

const { renderCraterLayoutForWorker } = await import('./wpt-runner.ts');

if (!parentPort) {
  throw new Error('wpt-crater-layout-worker must run in a worker thread');
}

interface RenderRequest {
  id: number;
  htmlPath: string;
}

parentPort.on('message', async (message: RenderRequest) => {
  try {
    const layout = await renderCraterLayoutForWorker(message.htmlPath);
    parentPort!.postMessage({ id: message.id, ok: true, layout });
  } catch (error) {
    parentPort!.postMessage({
      id: message.id,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
