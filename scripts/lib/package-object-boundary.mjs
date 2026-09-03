export function assertPackageObjectBoundary(manifest) {
  for (const [, block] of manifest.matchAll(/<types>([\s\S]*?)<\/types>/g)) {
    const type = block.match(/<name>([^<]+)<\/name>/)?.[1];
    if (!["CustomObject", "ListView", "CustomField"].includes(type)) continue;
    for (const [, member] of block.matchAll(
      /<members\s*>([^<]+)<\/members>/g
    )) {
      if (member.trim().split(".")[0] === "CustomPermission") {
        throw new Error(
          "CustomPermission is not a customizable object. Remove its object/list-view metadata; retain the real CustomPermission type members."
        );
      }
    }
  }
}

export function assertRunOnlyCustomPermission(manifest) {
  const members = [...manifest.matchAll(/<types>([\s\S]*?)<\/types>/g)]
    .map((match) => match[1])
    .filter((block) => /<name>CustomPermission<\/name>/.test(block))
    .flatMap((block) =>
      [...block.matchAll(/<members\s*>([^<]+)<\/members>/g)].map((match) =>
        match[1].trim()
      )
    );
  if (members.length !== 1 || members[0] !== "Record_Health_Check_Run") {
    throw new Error(
      "Run must be the only custom permission in the converted package artifact."
    );
  }
}
