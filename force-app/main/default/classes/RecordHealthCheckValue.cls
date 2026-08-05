/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * A typed Found or Expected value with exactly one stored format per data type.
 *
 * An unqualified `Object` is convenient inside Apex and unstable everywhere
 * else. The same value has to survive Apex, Flow, JSON, an agent, an MCP tool,
 * and a persisted Monitor row, and without one defined encoding per type every
 * consumer inspects runtime shapes and guesses how the value was written.
 *
 * | Data type  | Stored format                          |
 * | ---------- | -------------------------------------- |
 * | STRING     | original unlocalized string            |
 * | BOOLEAN    | `true` or `false`                      |
 * | NUMBER     | locale-neutral decimal using `.`       |
 * | DATE       | ISO `YYYY-MM-DD`                       |
 * | DATETIME   | UTC ISO-8601                           |
 * | ID         | 18-character Salesforce ID             |
 * | COUNT      | base-10 non-negative integer           |
 * | LIST       | `storedValues`; `storedValue` is null  |
 *
 * `dataType` also does real work downstream: it is what lets the engine derive
 * display formatting from an Evaluation Result, which is why a plugin can
 * return evaluation data alone and leave every rendering decision to the core.
 *
 * Instances are built through the factories so the stored format is produced in
 * one place rather than at each call site.
 */
global class RecordHealthCheckValue {
  /** String value discriminator. */
  global static final String TYPE_STRING = 'STRING';
  /** Boolean value discriminator. */
  global static final String TYPE_BOOLEAN = 'BOOLEAN';
  /** Decimal value discriminator. */
  global static final String TYPE_NUMBER = 'NUMBER';
  /** Date value discriminator. */
  global static final String TYPE_DATE = 'DATE';
  /** Datetime value discriminator. */
  global static final String TYPE_DATETIME = 'DATETIME';
  /** Salesforce ID value discriminator. */
  global static final String TYPE_ID = 'ID';
  /** Integer count value discriminator. */
  global static final String TYPE_COUNT = 'COUNT';
  /** Ordered list value discriminator. */
  global static final String TYPE_LIST = 'LIST';

  /** Stable type discriminator. */
  global String dataType { get; private set; }
  /** Official serialized scalar value. */
  global String storedValue { get; private set; }

  private List<String> storedValuesInternal;

  /** Returns a copy, so a caller cannot mutate a value it was handed. */
  global List<String> storedValues {
    get {
      return storedValuesInternal == null
        ? null
        : new List<String>(storedValuesInternal);
    }
  }

  private RecordHealthCheckValue(String dataType, String storedValue) {
    this.dataType = dataType;
    this.storedValue = storedValue;
  }

  /** Creates a typed String value. */
  global static RecordHealthCheckValue ofString(String value) {
    return new RecordHealthCheckValue(TYPE_STRING, value);
  }

  /** Creates a typed Boolean value. */
  global static RecordHealthCheckValue ofBoolean(Boolean value) {
    return new RecordHealthCheckValue(
      TYPE_BOOLEAN,
      value == null ? null : (value ? 'true' : 'false')
    );
  }

  /**
   * Decimal.toPlainString() is deliberate: format() is locale-aware and
   * toString() can emit scientific notation for very large or small values,
   * either of which would break a consumer parsing the stored form.
   */
  global static RecordHealthCheckValue ofNumber(Decimal value) {
    return new RecordHealthCheckValue(
      TYPE_NUMBER,
      value == null ? null : value.toPlainString()
    );
  }

  /** Creates a typed Date value. */
  global static RecordHealthCheckValue ofDate(Date value) {
    return new RecordHealthCheckValue(
      TYPE_DATE,
      value == null ? null : String.valueOf(value)
    );
  }

  /** Always UTC, so two orgs in different time zones store the same instant identically. */
  global static RecordHealthCheckValue ofDateTime(Datetime value) {
    return new RecordHealthCheckValue(
      TYPE_DATETIME,
      value == null ? null : value.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
    );
  }

  /** Normalized to 18 characters so a 15-character Id and its 18-character form compare equal. */
  global static RecordHealthCheckValue ofId(Id value) {
    return new RecordHealthCheckValue(
      TYPE_ID,
      value == null ? null : String.valueOf(value)
    );
  }

  /** Creates a typed Count value. */
  global static RecordHealthCheckValue ofCount(Integer value) {
    if (value != null && value < 0) {
      throw new RecordHealthCheckValueException(
        'A COUNT value cannot be negative.'
      );
    }
    return new RecordHealthCheckValue(
      TYPE_COUNT,
      value == null ? null : String.valueOf(value)
    );
  }

  /**
   * A LIST keeps its members in `storedValues` and leaves the scalar field
   * null, so a consumer never has to decide which of the two to read.
   */
  global static RecordHealthCheckValue ofList(List<String> values) {
    RecordHealthCheckValue result = new RecordHealthCheckValue(TYPE_LIST, null);
    result.storedValuesInternal = values == null
      ? new List<String>()
      : new List<String>(values);
    return result;
  }

  /** @return Whether this value contains an ordered list. */
  global Boolean isList() {
    return TYPE_LIST.equals(dataType);
  }

  /** Invalid typed-value construction or conversion. */
  global class RecordHealthCheckValueException extends Exception {
  }
}
