import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";

const SOURCE = path.join(paths.forceApp, "main", "default");
const manifest = fs.readFileSync(
  path.join(paths.manifest, "package.xml"),
  "utf8"
);
const manifestByType = new Map();

for (const block of manifest.matchAll(/<types>([\s\S]*?)<\/types>/g)) {
  const type = block[1].match(/<name>([^<]+)<\/name>/)?.[1];
  if (!type) continue;
  manifestByType.set(
    type,
    new Set(
      [...block[1].matchAll(/<members\s*>([^<]+)<\/members>/g)].map((m) =>
        m[1].trim()
      )
    )
  );
}

const files = (directory, suffix) => {
  const dir = path.join(SOURCE, directory);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, {
      recursive: true,
      withFileTypes: true
    })
    .filter((entry) => entry.isFile() && entry.name.endsWith(suffix))
    .map((entry) => path.join(entry.parentPath, entry.name));
};

const inventory = new Map([
  [
    "ApexClass",
    new Set(files("classes", ".cls").map((file) => path.basename(file, ".cls")))
  ],
  [
    "CustomMetadata",
    new Set(
      files("customMetadata", ".md-meta.xml").map((file) =>
        path.basename(file, ".md-meta.xml")
      )
    )
  ],
  [
    "CustomObject",
    new Set(
      files("objects", ".object-meta.xml").map((file) =>
        path.basename(file, ".object-meta.xml")
      )
    )
  ],
  [
    "CustomField",
    new Set(
      files("objects", ".field-meta.xml").map(
        (file) =>
          `${path.basename(path.dirname(path.dirname(file)))}.${path.basename(file, ".field-meta.xml")}`
      )
    )
  ],
  [
    "LightningComponentBundle",
    new Set(
      files("lwc", ".js-meta.xml").map((file) =>
        path.basename(path.dirname(file))
      )
    )
  ],
  [
    "CustomPermission",
    new Set(
      files("customPermissions", ".customPermission-meta.xml").map((file) =>
        path.basename(file, ".customPermission-meta.xml")
      )
    )
  ],
  [
    "PermissionSet",
    new Set(
      files("permissionsets", ".permissionset-meta.xml").map((file) =>
        path.basename(file, ".permissionset-meta.xml")
      )
    )
  ],
  [
    "Layout",
    new Set(
      files("layouts", ".layout-meta.xml").map((file) =>
        path.basename(file, ".layout-meta.xml")
      )
    )
  ],
  [
    "ListView",
    new Set(
      files("objects", ".listView-meta.xml").map(
        (file) =>
          `${path.basename(path.dirname(path.dirname(file)))}.${path.basename(file, ".listView-meta.xml")}`
      )
    )
  ],
  ["CustomLabel", new Set(["*"])]
]);

const errors = [];
for (const [type, sourceMembers] of inventory) {
  const declared = manifestByType.get(type) ?? new Set();
  if (declared.has("*")) continue;
  for (const member of sourceMembers) {
    if (!declared.has(member)) errors.push(`Missing ${type}: ${member}`);
  }
  for (const member of declared) {
    if (!sourceMembers.has(member)) errors.push(`Stale ${type}: ${member}`);
  }
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else {
  const count = [...inventory.values()].reduce(
    (sum, members) => sum + members.size,
    0
  );
  console.log(
    `Verified manifest coverage for ${count} packageable source members.`
  );
}
