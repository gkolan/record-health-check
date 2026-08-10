/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * @description Validates and binds record tokens in dynamic SOQL templates.
 * SPDX-License-Identifier: Apache-2.0
 */
public with sharing class RecordHealthCheckSoqlTokenBinder {
  // ─── Token binding ──────────────────────────────────────────

  /**
   * Replaces {!record.FieldName} tokens with the record's field values.
   * Values are returned as a Map so Database.query can use them as bind vars.
   * Since Apex dynamic SOQL only supports real bind variables in code scope
   * we inject field values directly — but we use String.escapeSingleQuotes
   * for string values and typed formatting for non-strings to prevent injection.
   */
  public static String bindTokens(String soqlTemplate, SObject record) {
    if (String.isBlank(soqlTemplate)) {
      throw new RecordHealthCheckEvaluatorException(
        'INVALID_SOQL_TEMPLATE',
        'SOQL template is blank.'
      );
    }

    // Validate no disallowed DML keywords using word-boundary matching
    // so field names like IsDeleted or Last_Update__c are not false-positives.
    validateNoDisallowedKeywords(soqlTemplate);

    RecordHealthCheckTemplateService.assertValid(
      soqlTemplate,
      RecordHealthCheckTemplateService.SURFACE_SOQL
    );
    List<RecordHealthCheckToken> tokens = RecordHealthCheckTemplateService.parse(
      soqlTemplate
    );
    String bound = '';
    Integer lastEnd = 0;

    for (RecordHealthCheckToken token : tokens) {
      String fieldPath = token.propertyPath;

      Object fieldValue;
      try {
        fieldValue = RecordHealthCheckSoqlBindValueResolver.resolveFieldPath(
          record,
          fieldPath
        );
      } catch (System.SObjectException ex) {
        throw new RecordHealthCheckEvaluatorException(
          'MISSING_BIND_VALUE',
          'Field "' + fieldPath + '" could not be resolved on the record.'
        );
      }
      if (
        (fieldValue == null ||
        (fieldValue instanceof String &&
        String.isBlank((String) fieldValue))) && token.fallbackValue != null
      ) {
        fieldValue = RecordHealthCheckSoqlBindValueResolver.coerceFallbackValue(
          record,
          fieldPath,
          token.fallbackValue
        );
      }

      // A token can appear quoted ('{!record.Field}') AND unquoted ({!record.Field}) in the same
      // template, so resolve both quoting contexts independently. For most types the
      // two replacements are identical; only a multi-select picklist differs — its
      // unquoted form expands to an INCLUDES list while its quoted form keeps the
      // raw 'A;B;C' value.
      Boolean quotedToken =
        token.startIndex > 0 &&
        token.endIndex < soqlTemplate.length() &&
        soqlTemplate.substring(token.startIndex - 1, token.startIndex) ==
        '\'' &&
        soqlTemplate.substring(token.endIndex, token.endIndex + 1) == '\'';
      Boolean insideStringLiteral = isInsideStringLiteral(
        soqlTemplate,
        token.startIndex
      );

      // Safe substitution — each Apex type maps to the correct SOQL literal format.
      String unquotedReplacement;
      String quotedReplacement;
      String embeddedLiteralReplacement;
      if (fieldValue == null) {
        // Quoted context strips the outer quotes so the literal is a bare SOQL null.
        unquotedReplacement = 'null';
        quotedReplacement = 'null';
        embeddedLiteralReplacement = '';
      } else if (fieldValue instanceof Date) {
        // SOQL Date literals: yyyy-MM-dd — no quotes required or allowed
        unquotedReplacement = String.valueOf((Date) fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (fieldValue instanceof DateTime) {
        // SOQL DateTime literals: yyyy-MM-ddTHH:mm:ssZ — no quotes required or allowed
        unquotedReplacement = ((DateTime) fieldValue)
          .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (fieldValue instanceof Time) {
        // SOQL Time literals: HH:mm:ss.SSSz — no quotes required or allowed
        unquotedReplacement = String.valueOf((Time) fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (fieldValue instanceof Boolean) {
        // SOQL Boolean literals: true / false — no quotes
        unquotedReplacement = String.valueOf((Boolean) fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = String.escapeSingleQuotes(
          unquotedReplacement
        );
      } else if (
        fieldValue instanceof Integer ||
        fieldValue instanceof Long ||
        fieldValue instanceof Double ||
        fieldValue instanceof Decimal
      ) {
        // SOQL numeric literals — no quotes; Decimal handles Currency and Percent fields
        unquotedReplacement = String.valueOf(fieldValue);
        quotedReplacement = unquotedReplacement;
        embeddedLiteralReplacement = escapeSoqlLiteral(unquotedReplacement);
      } else {
        // String, Id, Picklist, Text Area, Auto Number, Encrypted Text, etc.
        String rawStr = String.valueOf(fieldValue);
        // Default: quoted string with single-quote escaping prevents injection.
        // Multi-select picklist in QUOTED context keeps the raw 'A;B;C' value
        // suitable for exact-match (=) or INCLUDES ('A;B') AND-semantics queries.
        String escapedRaw = escapeSoqlLiteral(rawStr);
        String quotedStr = '\'' + escapedRaw + '\'';
        quotedReplacement = quotedStr;
        embeddedLiteralReplacement = escapedRaw;
        if (
          RecordHealthCheckSoqlBindValueResolver.isMultiSelectPicklist(
            record,
            fieldPath
          ) && rawStr.contains(';')
        ) {
          // Multi-select picklist in UNQUOTED context
          // Template: WHERE Regions__c INCLUDES {!record.Regions__c}
          // Value: 'North;South'
          // Result: WHERE Regions__c INCLUDES ('North', 'South')
          // Each semicolon-delimited value is individually quoted and comma-joined.
          // An all-semicolon value (';' or ';;') has no segments after filtering, which
          // would produce '()' — invalid SOQL (INCLUDES ()). Empty quotedVals instead
          // raise MISSING_BIND_VALUE, same as an unresolved token.
          unquotedReplacement = buildMultiSelectIncludesClause(rawStr);
        } else {
          unquotedReplacement = quotedStr;
        }
      }

      // Build from original matcher spans so inserted field values are never scanned
      // for later {!record.token} text. Quoted tokens consume their outer quotes because
      // Date/Time/numeric/null replacements must stay unquoted.
      if (quotedToken) {
        bound +=
          soqlTemplate.substring(lastEnd, token.startIndex - 1) +
          quotedReplacement;
        lastEnd = token.endIndex + 1;
      } else if (insideStringLiteral) {
        bound +=
          soqlTemplate.substring(lastEnd, token.startIndex) +
          embeddedLiteralReplacement;
        lastEnd = token.endIndex;
      } else {
        bound +=
          soqlTemplate.substring(lastEnd, token.startIndex) +
          unquotedReplacement;
        lastEnd = token.endIndex;
      }
    }

    return bound + soqlTemplate.substring(lastEnd);
  }

  public static String escapeSoqlLiteral(String value) {
    if (value == null) {
      return null;
    }
    return String.escapeSingleQuotes(value);
  }

  private static Boolean isInsideStringLiteral(String source, Integer indexAt) {
    Boolean inQuote = false;
    for (Integer i = 0; i < indexAt; i++) {
      String ch = source.substring(i, i + 1);
      if (ch == '\\' && inQuote && i + 1 < indexAt) {
        i++;
      } else if (ch == '\'') {
        inQuote = !inQuote;
      }
    }
    return inQuote;
  }

  /**
   * Rejects SOQL containing DML/dangerous keywords matched as whole words only.
   * Uses \b word-boundary so field names like IsDeleted or Last_Update__c
   * do not trigger a false positive on DELETE or UPDATE.
   * Multi-word phrases (FOR UPDATE, ALL ROWS) are still matched literally.
   */
  public static void validateNoDisallowedKeywords(String soql) {
    try {
      RecordHealthCheckSoqlTemplate.validateNoDisallowedKeywords(soql);
    } catch (RecordHealthCheckSoqlTemplate.TemplateException ex) {
      throw new RecordHealthCheckEvaluatorException(
        ex.reasonCode,
        ex.getMessage()
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /**
   * Builds the parenthesized INCLUDES operand for an unquoted multi-select token.
   * Test-visible so semicolon-only values can be verified without a live field.
   */
  public static String buildMultiSelectIncludesClause(String rawStr) {
    List<String> quotedVals = new List<String>();
    for (String v : rawStr.split(';')) {
      // drop empty segments so 'A;' / 'A;;B' do not inject '' entries.
      if (String.isBlank(v)) {
        continue;
      }
      quotedVals.add('\'' + escapeSoqlLiteral(v.trim()) + '\'');
    }
    if (quotedVals.isEmpty()) {
      throw new RecordHealthCheckEvaluatorException(
        'MISSING_BIND_VALUE',
        'Multi-select value has no non-empty segments after splitting on ";".'
      );
    }
    return '(' + String.join(quotedVals, ', ') + ')';
  }
}
