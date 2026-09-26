function prefix(namespace) {
  return namespace ? `${namespace}__` : "";
}

function required(record, field, namespace) {
  const key = `${prefix(namespace)}${field}`;
  if (!(key in record)) {
    throw new Error(
      `${record.DeveloperName ?? "Unknown Check Set"} is missing ${field}.`
    );
  }
  return record[key];
}

export function upgradeCompatibilityQuery(namespace = "rhc") {
  const ns = prefix(namespace);
  return [
    `SELECT DeveloperName, MasterLabel, ${ns}CardHeadingDisplay__c,`,
    `${ns}CardRunMode__c, ${ns}RunButtonDisplay__c, ${ns}IsActive__c`,
    `FROM ${ns}Record_Health_Check_Set__mdt`,
    `WHERE ${ns}CardHeadingDisplay__c = 'HIDE'`,
    `AND ${ns}CardRunMode__c = 'RUN_ON_REQUEST'`,
    "ORDER BY DeveloperName"
  ].join(" ");
}

export function incompatibleHiddenManualCheckSets(records, namespace = "rhc") {
  return records
    .filter(
      (record) =>
        required(record, "CardHeadingDisplay__c", namespace) === "HIDE" &&
        required(record, "CardRunMode__c", namespace) === "RUN_ON_REQUEST"
    )
    .map((record) => ({
      developerName: record.DeveloperName,
      label: record.MasterLabel ?? record.DeveloperName,
      headingDisplay: required(record, "CardHeadingDisplay__c", namespace),
      runMode: required(record, "CardRunMode__c", namespace),
      runButtonDisplay:
        record[`${prefix(namespace)}RunButtonDisplay__c`] ?? null
    }));
}
