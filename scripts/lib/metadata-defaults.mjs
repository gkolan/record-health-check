/** Plan a Custom Metadata backfill without overwriting explicit administrator choices. */
export function missingDefaults(record, fields) {
  return Object.fromEntries(
    fields
      .filter(
        (field) =>
          field.name.endsWith("__c") &&
          field.defaultValue != null &&
          record[field.name] == null
      )
      .map((field) => [field.name, field.defaultValue])
  );
}
