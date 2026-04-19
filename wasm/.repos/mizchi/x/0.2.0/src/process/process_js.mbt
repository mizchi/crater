///|
priv struct SpawnResult {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
priv struct MergedResult {
  exit_code : Int
  output : String
}

///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
fn env_to_arrays(env : Map[String, String]) -> (Array[String], Array[String]) {
  let keys : Array[String] = []
  let values : Array[String] = []
  for k, v in env {
    keys.push(k)
    values.push(v)
  }
  (keys, values)
}

///|
extern "js" fn spawn_and_collect(
  cmd : String,
  args : Array[String],
  cwd : String?,
  env_keys : Array[String],
  env_values : Array[String],
  inherit_env : Bool,
) -> JsPromise[SpawnResult] =
  #| async (cmd, args, cwd, envKeys, envValues, inheritEnv) => {
  #|   const { spawn, execFileSync } = await import('node:child_process');
  #|   const path = await import('node:path');
  #|   let resolvedCmd = cmd;
  #|   if (!inheritEnv && !path.isAbsolute(cmd) && !cmd.includes('/')) {
  #|     try { resolvedCmd = execFileSync('/usr/bin/which', [cmd], { encoding: 'utf8' }).trim(); } catch {}
  #|   }
  #|   return new Promise((resolve, reject) => {
  #|     const options = { stdio: ['pipe', 'pipe', 'pipe'] };
  #|     if (cwd !== undefined) options.cwd = cwd;
  #|     const extraEnv = {};
  #|     for (let i = 0; i < envKeys.length; i++) extraEnv[envKeys[i]] = envValues[i];
  #|     options.env = inheritEnv ? { ...process.env, ...extraEnv } : extraEnv;
  #|     const child = spawn(resolvedCmd, args, options);
  #|     let stdout = '';
  #|     let stderr = '';
  #|     child.stdout.on('data', (data) => { stdout += data.toString(); });
  #|     child.stderr.on('data', (data) => { stderr += data.toString(); });
  #|     child.on('error', (err) => reject(err));
  #|     child.on('close', (code) => {
  #|       resolve({ exit_code: code ?? 0, stdout, stderr });
  #|     });
  #|   });
  #| }

///|
extern "js" fn spawn_and_collect_merged(
  cmd : String,
  args : Array[String],
  cwd : String?,
  env_keys : Array[String],
  env_values : Array[String],
  inherit_env : Bool,
) -> JsPromise[MergedResult] =
  #| async (cmd, args, cwd, envKeys, envValues, inheritEnv) => {
  #|   const { spawn, execFileSync } = await import('node:child_process');
  #|   const path = await import('node:path');
  #|   let resolvedCmd = cmd;
  #|   if (!inheritEnv && !path.isAbsolute(cmd) && !cmd.includes('/')) {
  #|     try { resolvedCmd = execFileSync('/usr/bin/which', [cmd], { encoding: 'utf8' }).trim(); } catch {}
  #|   }
  #|   return new Promise((resolve, reject) => {
  #|     const options = { stdio: ['pipe', 'pipe', 'pipe'] };
  #|     if (cwd !== undefined) options.cwd = cwd;
  #|     const extraEnv = {};
  #|     for (let i = 0; i < envKeys.length; i++) extraEnv[envKeys[i]] = envValues[i];
  #|     options.env = inheritEnv ? { ...process.env, ...extraEnv } : extraEnv;
  #|     const child = spawn(resolvedCmd, args, options);
  #|     let output = '';
  #|     child.stdout.on('data', (data) => { output += data.toString(); });
  #|     child.stderr.on('data', (data) => { output += data.toString(); });
  #|     child.on('error', (err) => reject(err));
  #|     child.on('close', (code) => {
  #|       resolve({ exit_code: code ?? 0, output });
  #|     });
  #|   });
  #| }

///|
extern "js" fn spawn_inherit(
  cmd : String,
  args : Array[String],
  cwd : String?,
  env_keys : Array[String],
  env_values : Array[String],
  inherit_env : Bool,
) -> JsPromise[Int] =
  #| async (cmd, args, cwd, envKeys, envValues, inheritEnv) => {
  #|   const { spawn, execFileSync } = await import('node:child_process');
  #|   const path = await import('node:path');
  #|   let resolvedCmd = cmd;
  #|   if (!inheritEnv && !path.isAbsolute(cmd) && !cmd.includes('/')) {
  #|     try { resolvedCmd = execFileSync('/usr/bin/which', [cmd], { encoding: 'utf8' }).trim(); } catch {}
  #|   }
  #|   return new Promise((resolve, reject) => {
  #|     const options = { stdio: 'inherit' };
  #|     if (cwd !== undefined) options.cwd = cwd;
  #|     const extraEnv = {};
  #|     for (let i = 0; i < envKeys.length; i++) extraEnv[envKeys[i]] = envValues[i];
  #|     options.env = inheritEnv ? { ...process.env, ...extraEnv } : extraEnv;
  #|     const child = spawn(resolvedCmd, args, options);
  #|     child.on('error', (err) => reject(err));
  #|     child.on('close', (code) => resolve(code ?? 0));
  #|   });
  #| }

///|
async fn run_inherit_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> Int {
  let (env_keys, env_values) = env_to_arrays(extra_env)
  let promise = spawn_inherit(
    cmd.to_string(),
    Array::from_iter(args.iter().map(fn(s) { s })),
    cwd.map(fn(c) { c.to_string() }),
    env_keys,
    env_values,
    inherit_env,
  )
  @js_async.run_promise(fn(_signal) { promise.cast() })
}

///|
async fn collect_output_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  let (env_keys, env_values) = env_to_arrays(extra_env)
  let promise = spawn_and_collect(
    cmd.to_string(),
    Array::from_iter(args.iter().map(fn(s) { s })),
    cwd.map(fn(c) { c.to_string() }),
    env_keys,
    env_values,
    inherit_env,
  )
  let result : SpawnResult = @js_async.run_promise(fn(_signal) {
    promise.cast()
  })
  (result.exit_code, result.stdout, result.stderr)
}

///|
async fn collect_output_merged_internal(
  cmd : StringView,
  args : Array[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> (Int, &@async_io.Data) {
  let (env_keys, env_values) = env_to_arrays(extra_env)
  let promise = spawn_and_collect_merged(
    cmd.to_string(),
    args,
    cwd.map(fn(c) { c.to_string() }),
    env_keys,
    env_values,
    inherit_env,
  )
  let result : MergedResult = @js_async.run_promise(fn(_signal) {
    promise.cast()
  })
  (result.exit_code, result.output)
}
