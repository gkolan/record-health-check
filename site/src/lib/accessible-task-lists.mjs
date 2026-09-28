import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

function visibleText(html) {
  return html
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function attributeValue(text) {
  return text.replaceAll('"', "&quot;");
}

export function labelTaskListCheckboxes(html) {
  return html.replace(
    /<li class="task-list-item"><input([^>]*)>([\s\S]*?)<\/li>/g,
    (item, inputAttributes, content) => {
      if (/\saria-label=/.test(inputAttributes)) return item;
      const label = visibleText(content);
      if (!label) return item;
      return `<li class="task-list-item"><input${inputAttributes} aria-label="${attributeValue(label)}">${content}</li>`;
    }
  );
}

async function htmlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) return htmlFiles(entryPath);
      return entry.isFile() && entry.name.endsWith(".html") ? [entryPath] : [];
    })
  );
  return nested.flat();
}

export default function accessibleTaskLists() {
  return {
    name: "record-health-check-accessible-task-lists",
    hooks: {
      "astro:build:done": async ({ dir }) => {
        for (const file of await htmlFiles(fileURLToPath(dir))) {
          const original = await readFile(file, "utf8");
          const labeled = labelTaskListCheckboxes(original);
          if (labeled !== original) await writeFile(file, labeled);
        }
      }
    }
  };
}
