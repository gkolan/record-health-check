/** Builds deterministic definition fingerprints for preview and readiness. */
public with sharing class RecordHealthCheckPreviewFingerprint {
  /**
   * Hashes the detached Check, owning Set, prerequisite closure, and versioned contracts.
   * @param draft Detached Check definition.
   * @param checkSet Server-owned Check Set definition.
   * @param prerequisites Recursive prerequisite definitions.
   * @param pluginRevision Reliable plugin identity/revision, or null.
   * @return Lowercase SHA-256 hexadecimal fingerprint.
   */
  public static String compute(
    Record_Health_Check__mdt draft,
    Record_Health_Check_Set__mdt checkSet,
    List<Record_Health_Check__mdt> prerequisites,
    String pluginRevision
  ) {
    List<Record_Health_Check__mdt> ordered = prerequisites == null
      ? new List<Record_Health_Check__mdt>()
      : new List<Record_Health_Check__mdt>(prerequisites);
    ordered.sort(new CheckComparator());
    List<String> prerequisiteJson = new List<String>();
    for (Record_Health_Check__mdt prerequisite : ordered) {
      prerequisiteJson.add(canonicalSObject(prerequisite));
    }
    String canonical =
      '{"check":' +
      canonicalSObject(draft) +
      ',"set":' +
      canonicalSObject(checkSet) +
      ',"prerequisites":[' +
      String.join(prerequisiteJson, ',') +
      ']' +
      ',"pluginRevision":' +
      typed(pluginRevision) +
      ',"previewContract":"1.0","packageApi":66}';
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('SHA-256', Blob.valueOf(canonical))
      )
      .toLowerCase();
  }

  private static String canonicalSObject(SObject record) {
    if (record == null) {
      return 'null';
    }
    Map<String, Object> populated = record.getPopulatedFieldsAsMap();
    List<String> keys = new List<String>(populated.keySet());
    keys.sort();
    List<String> members = new List<String>();
    for (String key : keys) {
      members.add(JSON.serialize(key) + ':' + typed(populated.get(key)));
    }
    return '{' + String.join(members, ',') + '}';
  }

  private static String typed(Object value) {
    if (value == null) {
      return '{"type":"NULL"}';
    }
    if (value instanceof SObject) {
      return '{"type":"SOBJECT","value":' +
        canonicalSObject((SObject) value) +
        '}';
    }
    String typeName = 'NUMBER';
    String serialized = JSON.serialize(value);
    if (value instanceof Datetime) {
      typeName = 'DATETIME';
      serialized = JSON.serialize(
        ((Datetime) value).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
      );
    } else if (value instanceof Date) {
      typeName = 'DATE';
      serialized = JSON.serialize(String.valueOf(value));
    } else if (value instanceof Id) {
      typeName = 'ID';
    } else if (value instanceof String) {
      typeName = 'STRING';
    } else if (value instanceof Boolean) {
      typeName = 'BOOLEAN';
    }
    return '{"type":' +
      JSON.serialize(typeName) +
      ',"value":' +
      serialized +
      '}';
  }

  private class CheckComparator implements Comparator<Record_Health_Check__mdt> {
    public Integer compare(
      Record_Health_Check__mdt left,
      Record_Health_Check__mdt right
    ) {
      String leftIdentity = String.valueOf(left.get('QualifiedApiName'));
      String rightIdentity = String.valueOf(right.get('QualifiedApiName'));
      return leftIdentity.compareTo(rightIdentity);
    }
  }
}
