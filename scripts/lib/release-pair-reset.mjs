import fs from "node:fs";
import path from "node:path";

// Removes the subscriber harness from a reused release-pair org before the
// candidate is uninstalled. Salesforce rejects a naive destroy manifest:
// standard objects cannot be deleted, a record page cannot be deleted while it
// is a View override, a Check Set cannot be deleted while Checks reference it,
// and an active Flow cannot be deleted. This plan orders the work around those.

const CHECK_PREFIX = "rhc__Record_Health_Check.";
const API_VERSION = "66.0";

function names(directory, suffix) {
  if (!fs.existsSync(directory)) return [];
  return fs
    .readdirSync(directory)
    .filter((file) => file.endsWith(suffix))
    .map((file) => file.slice(0, -suffix.length))
    .sort();
}

function overridesFrom(objectFile) {
  const xml = fs.readFileSync(objectFile, "utf8");
  return [...xml.matchAll(/<actionOverrides>([\s\S]*?)<\/actionOverrides>/g)]
    .map(([, body]) => ({
      actionName: body.match(/<actionName>([^<]+)<\/actionName>/)?.[1],
      formFactor: body.match(/<formFactor>([^<]+)<\/formFactor>/)?.[1] ?? null
    }))
    .filter((override) => override.actionName);
}

/** Builds the ordered reset plan from the subscriber harness source tree. */
export function planReleasePairReset(subscriberAppRoot, upgradeFixtureRoot) {
  const root = path.join(subscriberAppRoot, "main", "default");
  const known = new Set([
    "classes",
    "triggers",
    "customMetadata",
    "flexipages",
    "flows",
    "objects"
  ]);
  for (const entry of fs.readdirSync(root)) {
    if (!known.has(entry)) {
      throw new Error(
        `Release-pair reset does not know how to remove subscriber metadata folder '${entry}'.`
      );
    }
  }

  const metadata = [
    ...names(path.join(root, "customMetadata"), ".md-meta.xml"),
    ...(upgradeFixtureRoot
      ? names(
          path.join(upgradeFixtureRoot, "main", "default", "customMetadata"),
          ".md-meta.xml"
        )
      : [])
  ];
  const post = {
    ApexClass: names(path.join(root, "classes"), ".cls-meta.xml"),
    ApexTrigger: names(path.join(root, "triggers"), ".trigger-meta.xml"),
    CustomMetadata: metadata.filter((name) => !name.startsWith(CHECK_PREFIX)),
    FlexiPage: names(path.join(root, "flexipages"), ".flexipage-meta.xml"),
    ListView: []
  };
  const overrideResets = [];
  const objectsRoot = path.join(root, "objects");
  for (const object of fs.existsSync(objectsRoot)
    ? fs.readdirSync(objectsRoot).sort()
    : []) {
    if (object.endsWith("__c") || object.endsWith("__mdt")) {
      throw new Error(
        `Release-pair reset does not delete subscriber custom object '${object}'.`
      );
    }
    const objectRoot = path.join(objectsRoot, object);
    for (const entry of fs.readdirSync(objectRoot)) {
      if (entry === "listViews") {
        post.ListView.push(
          ...names(path.join(objectRoot, entry), ".listView-meta.xml").map(
            (view) => `${object}.${view}`
          )
        );
      } else if (entry === `${object}.object-meta.xml`) {
        const actions = overridesFrom(path.join(objectRoot, entry));
        if (actions.length) overrideResets.push({ object, actions });
      } else {
        throw new Error(
          `Release-pair reset does not know how to remove '${object}/${entry}'.`
        );
      }
    }
  }

  return {
    // Checks reference their Check Set, so they must go first.
    pre: {
      CustomMetadata: metadata.filter((name) => name.startsWith(CHECK_PREFIX))
    },
    overrideResets,
    // Flows are deactivated in the main deploy and their versions deleted afterwards.
    flows: names(path.join(root, "flows"), ".flow-meta.xml"),
    post
  };
}

export function manifestXml(types) {
  const body = Object.entries(types)
    .filter(([, members]) => members.length)
    .map(
      ([name, members]) =>
        `<types>${members.map((member) => `<members>${member}</members>`).join("")}<name>${name}</name></types>`
    )
    .join("");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">${body}<version>${API_VERSION}</version></Package>\n`;
}

export function overrideResetXml(actions) {
  const body = actions
    .map(
      ({ actionName, formFactor }) =>
        `<actionOverrides><actionName>${actionName}</actionName>${formFactor ? `<formFactor>${formFactor}</formFactor>` : ""}<type>Default</type></actionOverrides>`
    )
    .join("");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">${body}</CustomObject>\n`;
}

/** Writes a metadata-API deploy directory that applies the plan in one transaction. */
export function writeReleasePairResetDeploy(plan, directory) {
  fs.mkdirSync(path.join(directory, "objects"), { recursive: true });
  fs.mkdirSync(path.join(directory, "flowDefinitions"), { recursive: true });
  for (const { object, actions } of plan.overrideResets) {
    fs.writeFileSync(
      path.join(directory, "objects", `${object}.object`),
      overrideResetXml(actions)
    );
  }
  for (const flow of plan.flows) {
    fs.writeFileSync(
      path.join(directory, "flowDefinitions", `${flow}.flowDefinition`),
      `<?xml version="1.0" encoding="UTF-8"?>\n<FlowDefinition xmlns="http://soap.sforce.com/2006/04/metadata"><activeVersionNumber>0</activeVersionNumber></FlowDefinition>\n`
    );
  }
  fs.writeFileSync(
    path.join(directory, "package.xml"),
    manifestXml({
      CustomObject: plan.overrideResets.map(({ object }) => object),
      FlowDefinition: plan.flows
    })
  );
  fs.writeFileSync(
    path.join(directory, "destructiveChangesPre.xml"),
    manifestXml(plan.pre)
  );
  fs.writeFileSync(
    path.join(directory, "destructiveChangesPost.xml"),
    manifestXml(plan.post)
  );
}
