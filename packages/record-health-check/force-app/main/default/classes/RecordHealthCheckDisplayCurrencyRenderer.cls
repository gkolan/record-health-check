/**
 * Renders monetary values with currency-specific symbols and minor units.
 */
public with sharing class RecordHealthCheckDisplayCurrencyRenderer {
  private static final Map<String, String> SYMBOLS_BY_ISO_CODE = new Map<String, String>{
    'USD' => '$',
    'EUR' => '€',
    'GBP' => '£',
    'JPY' => '¥',
    'CNY' => '¥',
    'INR' => '₹',
    'AUD' => 'A$',
    'CAD' => 'C$',
    'NZD' => 'NZ$',
    'SGD' => 'S$',
    'HKD' => 'HK$',
    'BRL' => 'R$',
    'MXN' => 'MX$',
    'KRW' => '₩',
    'RUB' => '₽',
    'TRY' => '₺',
    'ILS' => '₪',
    'PHP' => '₱',
    'THB' => '฿',
    'VND' => '₫',
    'NGN' => '₦',
    'PLN' => 'zł',
    'ZAR' => 'R'
  };

  private static final Set<String> ZERO_DECIMAL_ISO_CODES = new Set<String>{
    'BIF',
    'CLP',
    'DJF',
    'GNF',
    'ISK',
    'JPY',
    'KMF',
    'KRW',
    'PYG',
    'RWF',
    'UGX',
    'VND',
    'VUV',
    'XAF',
    'XOF',
    'XPF'
  };
  private static final Set<String> AMBIGUOUS_SYMBOL_ISO_CODES = new Set<String>{
    'JPY',
    'CNY'
  };

  /**
   * Renders an amount in the named currency.
   *
   * @param amount amount to render
   * @param isoCode ISO 4217 currency code
   * @param showIsoCode whether the org requires unambiguous ISO-code labels
   * @return localized monetary display text
   */
  public static String render(
    Decimal amount,
    String isoCode,
    Boolean showIsoCode
  ) {
    if (amount == null) {
      return RecordHealthCheckDisplayFormat.BLANK_TEXT;
    }
    if (String.isBlank(isoCode)) {
      return RecordHealthCheckDisplayNumberRenderer.renderNumber(amount);
    }

    String normalizedIsoCode = isoCode.trim().toUpperCase();
    Integer decimalPlaces = ZERO_DECIMAL_ISO_CODES.contains(normalizedIsoCode)
      ? 0
      : 2;
    String renderedAmount = RecordHealthCheckDisplayNumberRenderer.renderFixedScale(
      amount,
      decimalPlaces
    );
    String symbol = SYMBOLS_BY_ISO_CODE.get(normalizedIsoCode);
    if (
      symbol == null ||
      showIsoCode == true ||
      AMBIGUOUS_SYMBOL_ISO_CODES.contains(normalizedIsoCode)
    ) {
      return normalizedIsoCode + ' ' + renderedAmount;
    }
    return renderedAmount.startsWith('-')
      ? '-' + symbol + renderedAmount.substring(1)
      : symbol + renderedAmount;
  }
}
