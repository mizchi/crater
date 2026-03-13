import { expect, test } from "@playwright/test";
import { CraterBidiPage } from "./helpers/crater-bidi-page";

test.describe("Browser user scenarios", () => {
  let page: CraterBidiPage;

  test.beforeEach(async () => {
    page = new CraterBidiPage();
    await page.connect();
  });

  test.afterEach(async () => {
    await page.close();
  });

  test("todo flow: add, complete, and remove an item", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <div id="todo-form">
            <input id="todo-input" type="text" />
            <button id="add-btn" type="button">Add</button>
          </div>
          <ul id="todos"></ul>
          <div id="summary">0 active / 0 done</div>
          <script>
            const input = document.getElementById('todo-input');
            const add = document.getElementById('add-btn');
            const todos = document.getElementById('todos');
            const summary = document.getElementById('summary');
            const updateSummary = () => {
              const items = Array.from(todos.querySelectorAll('li'));
              const done = items.filter((item) => item.dataset.done === 'true').length;
              const active = items.length - done;
              summary.textContent = active + ' active / ' + done + ' done';
            };
            add.addEventListener('click', () => {
              const value = input.value.trim();
              if (!value) return;
              const li = document.createElement('li');
              li.dataset.done = 'false';
              const label = document.createElement('span');
              label.className = 'todo-label';
              label.textContent = value;
              const toggle = document.createElement('button');
              toggle.className = 'todo-toggle';
              toggle.type = 'button';
              toggle.textContent = 'Done';
              toggle.addEventListener('click', () => {
                const nextDone = li.dataset.done !== 'true';
                li.dataset.done = nextDone ? 'true' : 'false';
                label.textContent = nextDone ? value + ' (done)' : value;
                updateSummary();
              });
              const remove = document.createElement('button');
              remove.className = 'todo-remove';
              remove.type = 'button';
              remove.textContent = 'Remove';
              remove.addEventListener('click', () => {
                todos.removeChild(li);
                updateSummary();
              });
              li.append(label, toggle, remove);
              todos.appendChild(li);
              input.value = '';
              updateSummary();
            });
          </script>
        </body>
      </html>
    `);

    await page.type("#todo-input", "buy milk");
    await page.click("#add-btn");
    await page.waitForText("#summary", "1 active / 0 done");
    await expect(page.textContent(".todo-label")).resolves.toBe("buy milk");

    await page.click(".todo-toggle");
    await page.waitForText("#summary", "0 active / 1 done");
    await expect(page.textContent(".todo-label")).resolves.toBe("buy milk (done)");

    await page.click(".todo-remove");
    await page.waitForText("#summary", "0 active / 0 done");
    await expect(page.count("#todos li")).resolves.toBe(0);
  });

  test("search flow: type query and clear results", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <input id="search" type="search" />
          <button id="clear" type="button">Clear</button>
          <div id="count"></div>
          <ul id="results">
            <li class="result-item">apple</li>
            <li class="result-item">banana</li>
            <li class="result-item">apricot</li>
            <li class="result-item">grape</li>
          </ul>
          <script>
            const input = document.getElementById('search');
            const clear = document.getElementById('clear');
            const items = Array.from(document.querySelectorAll('.result-item'));
            const count = document.getElementById('count');
            const render = () => {
              const query = input.value.trim().toLowerCase();
              let visible = 0;
              for (const item of items) {
                const match = !query || item.textContent.toLowerCase().includes(query);
                item.style.display = match ? 'list-item' : 'none';
                if (match) visible += 1;
              }
              count.textContent = visible + ' results';
            };
            input.addEventListener('input', render);
            clear.addEventListener('click', () => {
              input.value = '';
              render();
            });
            render();
          </script>
        </body>
      </html>
    `);

    await page.waitForText("#count", "4 results");
    await page.type("#search", "ap");
    await page.waitForText("#count", "3 results");

    await page.click("#clear");
    await page.waitForText("#count", "4 results");
  });

  test("async save flow: timer and requestAnimationFrame update UI", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <button id="save" type="button">Save</button>
          <div id="status">Idle</div>
          <div id="badge" hidden></div>
          <script>
            const save = document.getElementById('save');
            const status = document.getElementById('status');
            const badge = document.getElementById('badge');
            save.addEventListener('click', () => {
              save.disabled = true;
              status.textContent = 'Saving...';
              setTimeout(() => {
                requestAnimationFrame(() => {
                  status.textContent = 'Saved';
                  badge.hidden = false;
                  badge.textContent = 'Synced';
                  save.disabled = false;
                });
              }, 20);
            });
          </script>
        </body>
      </html>
    `);

    await page.click("#save");
    await page.waitForText("#status", "Saving...");
    await page.waitForText("#status", "Saved", { timeout: 2000 });
    await expect(page.textContent("#badge")).resolves.toBe("Synced");
  });

  test("settings flow: toggle checkbox and select theme", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <label><input id="newsletter" type="checkbox" /> Newsletter</label>
          <select id="theme">
            <option value="light">Light</option>
            <option value="dark">Dark</option>
            <option value="system">System</option>
          </select>
          <button id="save" type="button">Save</button>
          <div id="preview">newsletter:off theme:light</div>
          <div id="status">Idle</div>
          <script>
            const newsletter = document.getElementById('newsletter');
            const theme = document.getElementById('theme');
            const preview = document.getElementById('preview');
            const status = document.getElementById('status');
            const renderPreview = () => {
              preview.textContent = 'newsletter:' + (newsletter.checked ? 'on' : 'off') + ' theme:' + theme.value;
            };
            newsletter.addEventListener('change', renderPreview);
            theme.addEventListener('change', renderPreview);
            document.getElementById('save').addEventListener('click', () => {
              status.textContent = 'Saved ' + preview.textContent;
            });
            renderPreview();
          </script>
        </body>
      </html>
    `);

    await page.check("#newsletter");
    await page.select("#theme", "dark");
    await page.waitForText("#preview", "newsletter:on theme:dark");

    await page.click("#save");
    await page.waitForText("#status", "Saved newsletter:on theme:dark");
  });

  test("editor flow: selection replacement and deletion update preview", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <input id="editor" type="text" />
          <div id="preview"></div>
          <script>
            const editor = document.getElementById('editor');
            const preview = document.getElementById('preview');
            const render = () => {
              preview.textContent = editor.value + ' @ ' + editor.selectionStart + ':' + editor.selectionEnd;
            };
            editor.addEventListener('input', render);
            editor.addEventListener('click', render);
            editor.addEventListener('keyup', render);
            render();
          </script>
        </body>
      </html>
    `);

    await page.type("#editor", "hello");
    await page.waitForText("#preview", "hello @ 5:5");

    await page.evaluate(`(() => {
      const editor = document.getElementById('editor');
      editor.setSelectionRange(1, 4);
      editor.dispatchEvent(new Event('click', { bubbles: true }));
    })()`);
    await page.press("x");
    await page.waitForText("#preview", "hxo @ 2:2");

    await page.press("Backspace");
    await page.waitForText("#preview", "ho @ 1:1");

    await page.press("Delete");
    await page.waitForText("#preview", "h @ 1:1");
  });

  test("kanban flow: drag card into done column", async () => {
    await page.setContentWithScripts(`
      <html>
        <body>
          <div id="board">
            <div id="todo" data-state="todo">
              <div id="card" draggable="true">Ship jsbidi</div>
            </div>
            <div id="done" data-state="done"></div>
          </div>
          <div id="status">todo</div>
          <script>
            const todo = document.getElementById('todo');
            const done = document.getElementById('done');
            const card = document.getElementById('card');
            const status = document.getElementById('status');
            let dragId = null;
            card.addEventListener('dragstart', (event) => {
              dragId = card.id;
              event.dataTransfer.effectAllowed = 'move';
            });
            done.addEventListener('dragover', (event) => {
              event.preventDefault();
              event.dataTransfer.dropEffect = 'move';
            });
            done.addEventListener('drop', () => {
              if (dragId === 'card') {
                done.appendChild(card);
                status.textContent = 'done';
              }
            });
            todo.addEventListener('drop', () => {
              status.textContent = 'todo';
            });
          </script>
        </body>
      </html>
    `);

    await page.drag("#card", "#done");
    await page.waitForText("#status", "done");
    await expect(page.evaluate(`document.querySelector("#done")?.textContent ?? ""`)).resolves.toContain("Ship jsbidi");
  });
});
