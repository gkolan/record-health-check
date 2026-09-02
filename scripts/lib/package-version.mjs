export function packageVersionString(details = {}) {
  const direct = details.Version ?? details.version ?? details.VersionNumber;
  if (direct !== undefined && direct !== null && String(direct) !== "") {
    return String(direct);
  }

  const parts = [
    ["MajorVersion", "majorVersion"],
    ["MinorVersion", "minorVersion"],
    ["PatchVersion", "patchVersion"],
    ["BuildNumber", "buildNumber"]
  ].map(([upper, lower]) => details[upper] ?? details[lower]);

  return parts.every(
    (part) => part !== undefined && part !== null && /^\d+$/.test(String(part))
  )
    ? parts.map(String).join(".")
    : "";
}
