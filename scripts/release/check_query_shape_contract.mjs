import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(".");
const corpusPath = path.join(root, "tests/fixtures/query-shapes/corpus.json");
const resourcePath = path.join(
  root,
  "packages/record-health-check/integration-tests/main/default/staticresources/RHCQueryShapeCorpus.resource"
);
const metadataPath = `${resourcePath}-meta.xml`;
const metadata = `<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Private</cacheControl>
    <contentType>application/json</contentType>
</StaticResource>
`;

const write = process.argv.includes("--write");
const corpus = await readFile(corpusPath, "utf8");
if (write) {
  await mkdir(path.dirname(resourcePath), { recursive: true });
  await writeFile(resourcePath, corpus);
  await writeFile(metadataPath, metadata);
  process.stdout.write("Generated query-shape static resource.\n");
} else {
  const [resource, resourceMetadata] = await Promise.all([
    readFile(resourcePath, "utf8"),
    readFile(metadataPath, "utf8")
  ]);
  if (resource !== corpus) {
    throw new Error(
      "Query-shape static resource is stale; run this command with --write."
    );
  }
  if (resourceMetadata !== metadata) {
    throw new Error("Query-shape static resource metadata is stale.");
  }
  process.stdout.write(
    "Query-shape corpus and static resource match exactly.\n"
  );
}
