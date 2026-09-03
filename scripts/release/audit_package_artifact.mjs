#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { run } from "../lib/run.mjs";
import {
  assertPackageObjectBoundary,
  assertRunOnlyCustomPermission
} from "../lib/package-object-boundary.mjs";

const { values } = parseArgs({
  options: {
    "metadata-dir": { type: "string" }
  }
});

let metadataDirectory = values["metadata-dir"]
  ? path.resolve(values["metadata-dir"])
  : "";
let temporaryDirectory = "";

if (!metadataDirectory) {
  temporaryDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-package-artifact-")
  );
  metadataDirectory = temporaryDirectory;
  run(
    "sf",
    [
      "project",
      "convert",
      "source",
      "--root-dir",
      "force-app",
      "--output-dir",
      metadataDirectory
    ],
    {
      cwd: paths.packageRoot,
      env: { ...process.env, SF_DISABLE_LOG_FILE: "true" }
    }
  );
}

try {
  const manifestPath = path.join(metadataDirectory, "package.xml");
  const customMetadataDirectory = path.join(
    metadataDirectory,
    "customMetadata"
  );
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Package artifact has no package.xml: ${manifestPath}`);
  }
  if (!fs.existsSync(customMetadataDirectory)) {
    throw new Error(
      `Package artifact has no customMetadata directory: ${customMetadataDirectory}`
    );
  }

  const manifest = fs.readFileSync(manifestPath, "utf8");
  assertPackageObjectBoundary(manifest);
  assertRunOnlyCustomPermission(manifest);
  const customMetadataBlock = [
    ...manifest.matchAll(/<types>([\s\S]*?)<\/types>/g)
  ]
    .map((match) => match[1])
    .find((block) => /<name>CustomMetadata<\/name>/.test(block));
  if (!customMetadataBlock) {
    throw new Error("package.xml has no CustomMetadata type block.");
  }

  const manifestMembers = new Set(
    [...customMetadataBlock.matchAll(/<members\s*>([^<]+)<\/members>/g)].map(
      (match) => match[1].trim()
    )
  );
  const physicalMembers = new Set(
    fs
      .readdirSync(customMetadataDirectory)
      .filter((file) => file.endsWith(".md"))
      .map((file) => file.slice(0, -3))
  );
  const errors = [];

  for (const member of new Set([...manifestMembers, ...physicalMembers])) {
    if (member.includes("__mdt.")) {
      errors.push(
        `CustomMetadata record uses a noncanonical __mdt filename or member: ${member}`
      );
    }
  }

  for (const member of manifestMembers) {
    if (!physicalMembers.has(member)) {
      errors.push(
        `CustomMetadata is named in package.xml but missing from the artifact: ${member}`
      );
    }
  }
  for (const member of physicalMembers) {
    if (!manifestMembers.has(member)) {
      errors.push(
        `CustomMetadata exists in the artifact but is missing from package.xml: ${member}`
      );
    }
  }

  const checkSets = [...manifestMembers].filter((member) =>
    member.startsWith("Record_Health_Check_Set.")
  );
  const checks = [...manifestMembers].filter((member) =>
    member.startsWith("Record_Health_Check.")
  );
  if (checkSets.length !== 4 || checks.length !== 50) {
    errors.push(
      `Expected 4 Check Sets and 50 Checks; found ${checkSets.length} and ${checks.length}.`
    );
  }

  const retiredIdentity = /Record_Health_Check_Rule|RecordHealthCheckRule/i;
  const allManifestMembers = [
    ...manifest.matchAll(/<members\s*>([^<]+)<\/members>/g)
  ].map((match) => match[1].trim());
  for (const member of new Set([...allManifestMembers, ...physicalMembers])) {
    if (retiredIdentity.test(member)) {
      errors.push(`Artifact contains retired Rule identity: ${member}`);
    }
  }

  const typeFields = new Map();
  for (const typeName of [
    "Record_Health_Check_Set__mdt",
    "Record_Health_Check__mdt"
  ]) {
    const objectPath = path.join(
      metadataDirectory,
      "objects",
      `${typeName}.object`
    );
    if (!fs.existsSync(objectPath)) {
      errors.push(`Artifact is missing Custom Metadata type: ${typeName}`);
      continue;
    }
    const objectXml = fs.readFileSync(objectPath, "utf8");
    typeFields.set(
      typeName,
      new Set(
        [...objectXml.matchAll(/<fields>([\s\S]*?)<\/fields>/g)]
          .map((match) => match[1].match(/<fullName>([^<]+)<\/fullName>/)?.[1])
          .filter(Boolean)
      )
    );
  }

  const checkSetNames = new Set(
    checkSets.map((member) => member.split(".")[1])
  );
  const checkNames = new Set(checks.map((member) => member.split(".")[1]));
  for (const member of physicalMembers) {
    const [typeName] = member.split(".");
    const objectTypeName = `${typeName}__mdt`;
    const recordXml = fs.readFileSync(
      path.join(customMetadataDirectory, `${member}.md`),
      "utf8"
    );
    for (const valueBlock of recordXml.matchAll(
      /<values>([\s\S]*?)<\/values>/g
    )) {
      const field = valueBlock[1].match(/<field>([^<]+)<\/field>/)?.[1];
      const value = valueBlock[1]
        .match(/<value[^>]*>([\s\S]*?)<\/value>/)?.[1]
        ?.trim();
      if (field && !typeFields.get(objectTypeName)?.has(field)) {
        errors.push(`${member} references missing field ${field}.`);
      }
      if (
        field === "Record_Health_Check_Set__c" &&
        value &&
        !checkSetNames.has(value)
      ) {
        errors.push(`${member} references missing Check Set ${value}.`);
      }
      if (field === "PrerequisiteCheck__c" && value && !checkNames.has(value)) {
        errors.push(
          `${member} references missing prerequisite Check ${value}.`
        );
      }
    }
  }

  if (errors.length) {
    console.error(errors.join("\n"));
    process.exitCode = 1;
  } else {
    console.log(
      `Package artifact audit passed: ${manifestMembers.size} Custom Metadata records ` +
        `(4 Check Sets, 50 Checks) exist in both package.xml and the physical artifact.`
    );
  }
} finally {
  if (temporaryDirectory) {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}
