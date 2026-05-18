// utels error tracker init for the crater playground.
//
// Loaded BEFORE any other module imports run (see the side-effect import at
// the top of main.js) so that early errors during MoonBit bundle eval are
// captured. The tracker subscribes to `window.error` / `unhandledrejection`
// internally — once initialized, every uncaught error and rejected promise
// on the page is reported.
//
// Configuration is read from Vite's `import.meta.env`. The endpoint /
// projectId / publicKey trio is required; if any is missing (local dev
// with no .env, preview builds, contributor checkouts) the tracker is
// installed as a no-op so the playground stays runnable without secrets.

import { createBrowserErrorTracker } from "@mizchi/utels/browser";

const env = import.meta.env;
const endpoint = env.VITE_UTELS_ENDPOINT;
const projectId = env.VITE_UTELS_PROJECT_ID;
const publicKey = env.VITE_UTELS_PUBLIC_KEY;

let tracker = null;

if (endpoint && projectId && publicKey) {
  tracker = createBrowserErrorTracker({
    endpoint,
    projectId,
    publicKey,
    release: env.VITE_UTELS_RELEASE ?? "local",
    buildId: env.VITE_UTELS_BUILD_ID ?? "local",
    sample: {
      // Conservative defaults — the playground is low-traffic, error
      // signal is high-value, everything else stays off until a user
      // opts in by overriding the env at deploy time.
      session: 1,
      error: 1,
      vital: 0,
      ui: 0,
      feature: 0,
    },
  });
} else if (env.DEV) {
  // Loud in dev only — production builds with missing env should fail
  // silently rather than spam the console for unsuspecting visitors.
  console.info(
    "[utels] tracker disabled — set VITE_UTELS_ENDPOINT / VITE_UTELS_PROJECT_ID / VITE_UTELS_PUBLIC_KEY to enable.",
  );
}

export { tracker };
