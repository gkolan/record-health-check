/** Resolves the currency associated with queried display values. */
public with sharing class RecordHealthCheckDisplayCurrencyResolver {
  @TestVisible
  private static Boolean corporateCurrencyLoaded = false;
  @TestVisible
  private static String corporateCurrencyCode;
  @TestVisible
  private static Boolean multiCurrency;
  @TestVisible
  private static List<SObject> corporateCurrencyRowsOverride;

  /** Returns a row's currency, or corporate currency for an aggregate. */
  public static String currencyIsoCodeFrom(SObject row) {
    if (row == null || !isMultiCurrencyOrg()) {
      return null;
    }
    if (row instanceof AggregateResult) {
      return corporateCurrency();
    }
    Map<String, Object> populated = row.getPopulatedFieldsAsMap();
    // prettier-ignore
    return populated.containsKey('CurrencyIsoCode') ? String.valueOf(populated.get('CurrencyIsoCode')) : null;
  }

  /** Returns currencies for the visible preview rows. */
  public static List<String> currencyIsoCodesFor(
    List<SObject> rows,
    SObject record,
    String fieldPath
  ) {
    if (rows == null) {
      return null;
    }
    List<String> result = new List<String>();
    Integer previewSize = Math.min(
      rows.size(),
      RecordHealthCheckConstants.DISPLAY_LIST_PREVIEW_CAP
    );
    for (Integer i = 0; i < previewSize; i++) {
      result.add(currencyIsoCodeFor(rows[i], record, fieldPath));
    }
    return result;
  }

  /** Returns the currency belonging to a queried field value. */
  public static String currencyIsoCodeFor(
    SObject row,
    SObject record,
    String fieldPath
  ) {
    SObject valueRow = rowForFieldPath(row, fieldPath);
    String isoCode = currencyIsoCodeFrom(valueRow);
    if (
      String.isBlank(isoCode) &&
      valueRow != null &&
      record != null &&
      valueRow.getSObjectType() == record.getSObjectType()
    ) {
      isoCode = currencyIsoCodeFrom(record);
    }
    return isoCode;
  }

  /** Returns the row owning the terminal field in a relationship path. */
  public static SObject rowForFieldPath(SObject row, String fieldPath) {
    if (
      row == null ||
      String.isBlank(fieldPath) ||
      row instanceof AggregateResult
    ) {
      return row;
    }
    SObject current = row;
    List<String> parts = fieldPath.trim().split('\\.');
    for (Integer i = 0; i < parts.size() - 1; i++) {
      try {
        current = current.getSObject(parts[i]);
      } catch (System.SObjectException ignored) {
        return null;
      }
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  /** Returns the org corporate currency once per transaction. */
  public static String corporateCurrency() {
    if (corporateCurrencyLoaded) {
      return corporateCurrencyCode;
    }
    corporateCurrencyLoaded = true;
    if (!isMultiCurrencyOrg()) {
      return null;
    }
    try {
      List<SObject> corporate = corporateCurrencyRowsOverride != null
        ? corporateCurrencyRowsOverride
        : Database.query(
            'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = TRUE LIMIT 1',
            AccessLevel.USER_MODE
          );
      if (!corporate.isEmpty()) {
        corporateCurrencyCode = String.valueOf(corporate[0].get('IsoCode'));
      }
    } catch (Exception ignored) {
      // The cached code is null until a successful lookup.
    }
    return corporateCurrencyCode;
  }

  /** Returns whether the org supports record-level currencies. */
  public static Boolean isMultiCurrencyOrg() {
    if (multiCurrency == null) {
      multiCurrency = UserInfo.isMultiCurrencyOrganization();
    }
    return multiCurrency;
  }
}
