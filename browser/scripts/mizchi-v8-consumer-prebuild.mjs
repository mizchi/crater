// Compatibility entry point for repository tooling. The published native module
// owns the implementation so its prebuild hook never reaches outside the module.
export * from "../native/scripts/mizchi-v8-consumer-prebuild.mjs"
import { main } from "../native/scripts/mizchi-v8-consumer-prebuild.mjs"
import path from "node:path"
import { fileURLToPath } from "node:url"

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main()
}
