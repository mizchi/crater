#!/usr/bin/env npx tsx
import { chromium, type CraterModelContextToolDescriptor } from "../webdriver/playwright/adapter.ts";

type ChatMessage =
  | { role: "system" | "user"; content: string }
  | { role: "assistant"; content: string | null; tool_calls?: ToolCall[] }
  | { role: "tool"; tool_call_id: string; content: string };

type ToolCall = {
  id: string;
  type: "function";
  function: {
    name: string;
    arguments: string;
  };
};

type ChatTool = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: unknown;
  };
};

type AssistantMessage = {
  role?: "assistant";
  content?: string | null;
  tool_calls?: ToolCall[];
};

type ChatCompletionResponse = {
  choices?: Array<{
    message?: AssistantMessage;
  }>;
  error?: {
    message?: string;
  };
};

type Provider = "openai" | "openrouter";

type CliOptions = {
  dryRun: boolean;
  provider: Provider;
  model: string;
  prompt: string;
  maxTurns: number;
};

function parseArgs(argv: string[]): CliOptions {
  const provider = parseProvider(
    process.env.WEBMCP_PROVIDER ?? (process.env.OPENAI_API_KEY ? "openai" : "openrouter"),
  );
  const options: CliOptions = {
    dryRun: false,
    provider,
    model:
      provider === "openai"
        ? process.env.OPENAI_MODEL || "gpt-4.1-mini"
        : process.env.OPENROUTER_MODEL || "openai/gpt-4o-mini",
    prompt:
      "ページの内容を読んで、status を日本語の短い要約に更新してから、何をしたか答えてください。",
    maxTurns: 4,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--") {
      continue;
    } else if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--provider") {
      options.provider = parseProvider(requiredValue(argv, ++i, arg));
      if (options.provider === "openai" && options.model === "openai/gpt-4o-mini") {
        options.model = process.env.OPENAI_MODEL || "gpt-4.1-mini";
      } else if (options.provider === "openrouter" && options.model === "gpt-4.1-mini") {
        options.model = process.env.OPENROUTER_MODEL || "openai/gpt-4o-mini";
      }
    } else if (arg === "--model") {
      options.model = requiredValue(argv, ++i, arg);
    } else if (arg === "--prompt") {
      options.prompt = requiredValue(argv, ++i, arg);
    } else if (arg === "--max-turns") {
      options.maxTurns = Number(requiredValue(argv, ++i, arg));
    } else if (arg === "--help" || arg === "-h") {
      printUsage();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if (!Number.isInteger(options.maxTurns) || options.maxTurns < 1) {
    throw new Error("--max-turns must be a positive integer");
  }
  return options;
}

function parseProvider(value: string): Provider {
  if (value === "openai" || value === "openrouter") return value;
  throw new Error(`Unknown provider: ${value}`);
}

function requiredValue(argv: string[], index: number, flag: string): string {
  const value = argv[index];
  if (!value) {
    throw new Error(`${flag} requires a value`);
  }
  return value;
}

function printUsage(): void {
  console.log(`Usage:
  pnpm webmcp:model -- --dry-run
  OPENAI_API_KEY=... pnpm webmcp:model -- --provider openai --model gpt-4.1-mini
  OPENROUTER_API_KEY=... pnpm webmcp:model -- --provider openrouter --model openai/gpt-4o-mini

Options:
  --dry-run         Run the Crater WebMCP bridge without calling a model provider.
  --provider NAME   Model provider: openai or openrouter. Defaults to OPENAI when OPENAI_API_KEY is set, otherwise OpenRouter.
  --model NAME      Model id. Defaults to OPENAI_MODEL/gpt-4.1-mini or OPENROUTER_MODEL/openai/gpt-4o-mini.
  --prompt TEXT    User prompt sent to the model.
  --max-turns N    Maximum tool-calling turns. Defaults to 4.
`);
}

function descriptorToChatTool(tool: CraterModelContextToolDescriptor): ChatTool {
  return {
    type: "function",
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.inputSchema ?? {
        type: "object",
        properties: {},
      },
    },
  };
}

function safeJson(value: unknown): string {
  if (value === undefined) return "null";
  try {
    return JSON.stringify(value);
  } catch (error) {
    return JSON.stringify({
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

function parseToolArguments(raw: string): unknown {
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return { raw };
  }
}

async function callOpenRouter(input: {
  apiKey: string;
  model: string;
  messages: ChatMessage[];
  tools: ChatTool[];
}): Promise<AssistantMessage> {
  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${input.apiKey}`,
      "content-type": "application/json",
      "http-referer": "https://github.com/mizchi/crater",
      "x-title": "Crater WebMCP OpenRouter Demo",
    },
    body: JSON.stringify({
      model: input.model,
      messages: input.messages,
      tools: input.tools,
      tool_choice: "auto",
      parallel_tool_calls: true,
    }),
  });
  const json = await response.json() as ChatCompletionResponse;
  if (!response.ok || json.error) {
    throw new Error(json.error?.message || `OpenRouter request failed: ${response.status}`);
  }
  const message = json.choices?.[0]?.message;
  if (!message) {
    throw new Error("OpenRouter response did not include a message");
  }
  return message;
}

async function callOpenAI(input: {
  apiKey: string;
  model: string;
  messages: ChatMessage[];
  tools: ChatTool[];
}): Promise<AssistantMessage> {
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${input.apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: input.model,
      messages: input.messages,
      tools: input.tools,
      tool_choice: "auto",
      parallel_tool_calls: true,
    }),
  });
  const json = await response.json() as ChatCompletionResponse;
  if (!response.ok || json.error) {
    throw new Error(json.error?.message || `OpenAI request failed: ${response.status}`);
  }
  const message = json.choices?.[0]?.message;
  if (!message) {
    throw new Error("OpenAI response did not include a message");
  }
  return message;
}

function apiKeyForProvider(provider: Provider): string | undefined {
  return provider === "openai" ? process.env.OPENAI_API_KEY : process.env.OPENROUTER_API_KEY;
}

async function callProvider(input: {
  provider: Provider;
  apiKey: string;
  model: string;
  messages: ChatMessage[];
  tools: ChatTool[];
}): Promise<AssistantMessage> {
  if (input.provider === "openai") {
    return callOpenAI(input);
  }
  return callOpenRouter(input);
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const apiKey = apiKeyForProvider(options.provider);
  if (!options.dryRun && !apiKey) {
    const name = options.provider === "openai" ? "OPENAI_API_KEY" : "OPENROUTER_API_KEY";
    throw new Error(`${name} is required unless --dry-run is set`);
  }

  const browser = await chromium.launch({
    autoStartBidi: true,
    craterRoot: process.cwd(),
    stdio: "pipe",
  });
  try {
    const page = await browser.newPage();
    await page.setContentWithScripts(`
      <main>
        <h1>Crater WebMCP Demo</h1>
        <p id="source">
          Crater exposes page-owned tools through navigator.modelContext so a browser-side
          agent can inspect and act on the current document.
        </p>
        <output id="status">pending</output>
        <script>
          navigator.modelContext.registerTool({
            name: "read_page",
            description: "Read the current demo page text and status.",
            inputSchema: {
              type: "object",
              properties: {}
            },
            annotations: {
              readOnlyHint: true,
              untrustedContentHint: true
            },
            execute: () => ({
              title: document.querySelector("h1")?.textContent || "",
              text: document.querySelector("#source")?.textContent?.trim() || "",
              status: document.querySelector("#status")?.textContent || "",
              url: location.href
            })
          });
          navigator.modelContext.registerTool({
            name: "set_status",
            description: "Set the visible demo status text.",
            inputSchema: {
              type: "object",
              properties: {
                text: { type: "string", description: "New status text." }
              },
              required: ["text"]
            },
            execute: ({ text }) => {
              const value = String(text || "");
              document.querySelector("#status").textContent = value;
              return { ok: true, status: value };
            }
          });
        </script>
      </main>
    `);

    const descriptors = await page.modelContextTools();
    const tools = descriptors.map(descriptorToChatTool);
    console.log(`registered tools: ${descriptors.map((tool) => tool.name).join(", ")}`);

    if (options.dryRun) {
      const pageInfo = await page.callModelContextTool("read_page", {});
      const status = await page.callModelContextTool("set_status", {
        text: "dry-run: WebMCP bridge is working",
      });
      console.log(`read_page => ${safeJson(pageInfo)}`);
      console.log(`set_status => ${safeJson(status)}`);
      console.log(`visible status => ${await page.locator("#status").textContent()}`);
      return;
    }
    if (!apiKey) throw new Error("API key is required");

    const messages: ChatMessage[] = [
      {
        role: "system",
        content:
          "You are a browser-side agent. Use the provided WebMCP tools when they are relevant, then answer briefly in Japanese.",
      },
      { role: "user", content: options.prompt },
    ];
    let finalContent = "";
    for (let turn = 0; turn < options.maxTurns; turn += 1) {
      const message = await callProvider({
        provider: options.provider,
        apiKey,
        model: options.model,
        messages,
        tools,
      });
      const toolCalls = message.tool_calls ?? [];
      messages.push({
        role: "assistant",
        content: toolCalls.length === 0 ? message.content ?? "" : message.content ?? null,
        ...(toolCalls.length === 0 ? {} : { tool_calls: toolCalls }),
      });
      if (toolCalls.length === 0) {
        finalContent = message.content ?? "";
        break;
      }
      for (const toolCall of toolCalls) {
        const result = await page.callModelContextTool(
          toolCall.function.name,
          parseToolArguments(toolCall.function.arguments),
        );
        const content = safeJson(result);
        console.log(`${toolCall.function.name}(${toolCall.function.arguments || "{}"}) => ${content}`);
        messages.push({
          role: "tool",
          tool_call_id: toolCall.id,
          content,
        });
      }
    }

    console.log(`final => ${finalContent || "(no final message)"}`);
    console.log(`visible status => ${await page.locator("#status").textContent()}`);
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
