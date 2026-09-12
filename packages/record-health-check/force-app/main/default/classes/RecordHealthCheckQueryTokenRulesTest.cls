/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Direct branch coverage for the query row token rules.
 *
 * These rules are the whole safety boundary of the feature, and they were
 * previously only exercised incidentally from usage tests. Several branches are
 * reachable only in an org with a particular feature enabled, so those assert
 * both sides of the org condition rather than skipping silently.
 */
@IsTest
private class RecordHealthCheckQueryTokenRulesTest {
  private static final String CONTACTS = 'SELECT Id, LastName, Email FROM Contact ORDER BY Id';

  private static Record_Health_Check__mdt check(String query, String template) {
    return new Record_Health_Check__mdt(
      DeveloperName = 'RuleUnderTest',
      EvaluationType__c = 'QUERY',
      SourceQuery__c = query,
      FailureMessage__c = template
    );
  }

  private static String codeFor(Record_Health_Check__mdt candidate) {
    RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
      candidate
    );
    return issue == null ? null : issue.reasonCode;
  }

  @IsTest
  static void ignoresChecksAndTemplatesWithNothingToJudge() {
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.firstIssue(null),
      'A missing Check has no tokens.'
    );
    Assert.isNull(
      codeFor(check(CONTACTS, null)),
      'A blank template has no tokens.'
    );
    Assert.isNull(
      codeFor(check(CONTACTS, 'Plain text with no tokens at all')),
      'Text without tokens is not this validator\'s business.'
    );
    Assert.isNull(
      codeFor(check(CONTACTS, 'Owner is {!record.Name}')),
      'Other namespaces are judged elsewhere.'
    );
  }

  @IsTest
  static void refusesRowTokensOnChecksThatRunNoQuery() {
    for (String evaluationType : new List<String>{ 'FORMULA', 'APEX' }) {
      Record_Health_Check__mdt candidate = check(
        null,
        '{!rhcQuery.sourceRows[0].LastName}'
      );
      candidate.EvaluationType__c = evaluationType;
      Assert.areEqual(
        'TOKEN_NOT_ALLOWED_ON_SURFACE',
        codeFor(candidate),
        evaluationType + ' Checks produce no rows.'
      );
    }
  }

  @IsTest
  static void refusesACollectionTheCheckDoesNotProduce() {
    Assert.areEqual(
      'QUERY_ROLE_NOT_AVAILABLE',
      codeFor(check(CONTACTS, '{!rhcQuery.comparisonRows[0].LastName}')),
      'There is no Comparison Query on this Check.'
    );
    Record_Health_Check__mdt dual = check(
      CONTACTS,
      '{!rhcQuery.comparisonRows[0].LastName}'
    );
    dual.EvaluationType__c = 'COMPARE_TWO_QUERIES';
    dual.ComparisonQuery__c = 'SELECT Id, LastName FROM Contact ORDER BY Id';
    Assert.isNull(
      codeFor(dual),
      'With a Comparison Query the same token is fine.'
    );
  }

  @IsTest
  static void refusesEveryShapeThatCannotProduceTheAddressedRow() {
    Assert.areEqual(
      'QUERY_PROJECTION_NOT_ANALYZABLE',
      codeFor(
        check(
          'SELECT Id, (SELECT Id FROM Contacts) FROM Account ORDER BY Id',
          '{!rhcQuery.sourceRows[0].Name}'
        )
      ),
      'A nested projection must be rejected before resolving an indexed row field.'
    );
    Assert.areEqual(
      'QUERY_FIELD_NOT_SELECTED',
      codeFor(
        check(
          'SELECT Id FROM Contact ORDER BY Id',
          '{!rhcQuery.sourceRows[0].LastName}'
        )
      ),
      'A field absent from the projection must retain the not-selected reason.'
    );
    Assert.areEqual(
      null,
      codeFor(
        check(
          'SELECT Id, LastName FROM Contact ORDER BY LastName',
          '{!rhcQuery.sourceRows[0].LastName}'
        )
      ),
      'A selected and ordered LastName field must be accepted.'
    );
    Assert.areEqual(
      null,
      codeFor(
        check(
          'SELECT LastName, COUNT(Id) total FROM Contact ' +
          'GROUP BY LastName ORDER BY LastName',
          '{!rhcQuery.sourceRows[0].total}'
        )
      ),
      'An ordered grouped aggregate has an authored positional order.'
    );
  }

  @IsTest
  static void appliesTheTightestRowCeilingItCanFind() {
    Record_Health_Check__mdt oneResult = check(
      CONTACTS,
      '{!rhcQuery.sourceRows[1].LastName}'
    );
    oneResult.QueryResultHandling__c = 'ONE_RESULT';
    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      codeFor(oneResult),
      'One Result never holds a second row.'
    );

    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      codeFor(
        check(
          'SELECT Id, LastName FROM Contact ORDER BY Id LIMIT 2',
          '{!rhcQuery.sourceRows[2].LastName}'
        )
      ),
      'The query LIMIT is tighter than Max Query Rows.'
    );

    Record_Health_Check__mdt capped = check(
      CONTACTS,
      '{!rhcQuery.sourceRows[8].LastName}'
    );
    capped.MaxQueryRows__c = 5;
    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      codeFor(capped),
      'Max Query Rows applies when the query has no LIMIT.'
    );

    Assert.areEqual(
      'TOKEN_ROW_INDEX_INVALID',
      codeFor(
        check(
          'SELECT COUNT(Id) total FROM Contact',
          '{!rhcQuery.sourceRows[1].total}'
        )
      ),
      'An ungrouped aggregate returns exactly one row.'
    );
    Assert.isNull(
      codeFor(
        check(
          'SELECT COUNT(Id) total FROM Contact',
          '{!rhcQuery.sourceRows[0].total}'
        )
      ),
      'Its single row needs no ORDER BY, which SOQL would reject anyway.'
    );
  }

  @IsTest
  static void judgesRowCountsByWhatTheQueryReturns() {
    Assert.isNull(
      codeFor(
        check(
          'SELECT Id, (SELECT Id FROM Contacts) FROM Account',
          '{!rhcQuery.sourceRowCount}'
        )
      ),
      'A count reads no column and no order, so an unreadable SELECT is fine.'
    );
    Assert.areEqual(
      'QUERY_ROLE_NOT_AVAILABLE',
      codeFor(
        check('SELECT COUNT() FROM Contact', '{!rhcQuery.sourceRowCount}')
      ),
      'Counting the rows of a counting query always gives 1.'
    );
    Record_Health_Check__mdt noComparison = check(
      CONTACTS,
      '{!rhcQuery.comparisonRowCount}'
    );
    Assert.areEqual(
      'QUERY_ROLE_NOT_AVAILABLE',
      codeFor(noComparison),
      'A count of a collection the Check cannot produce is refused too.'
    );
  }

  @IsTest
  static void checksEverySurfaceThatCanCarryARowToken() {
    Record_Health_Check__mdt candidate = check(
      'SELECT Id FROM Contact ORDER BY Id',
      null
    );
    candidate.UnableToEvaluateMessage__c = '{!rhcQuery.sourceRows[0].LastName}';
    Assert.areEqual(
      'QUERY_FIELD_NOT_SELECTED',
      codeFor(candidate),
      'The unable message is inspected.'
    );

    candidate.UnableToEvaluateMessage__c = null;
    candidate.ActionUrl__c = '/x/{!rhcQuery.sourceRows[0].LastName}';
    Assert.areEqual(
      'QUERY_FIELD_NOT_SELECTED',
      codeFor(candidate),
      'So is the Action URL.'
    );

    candidate.ActionUrl__c = null;
    candidate.DisplayExpectedText__c = '{!rhcQuery.sourceRows[0].LastName}';
    Assert.areEqual(
      'QUERY_FIELD_NOT_SELECTED',
      codeFor(candidate),
      'So is Display: Expected Text.'
    );
  }

  @IsTest
  static void appliesTheCurrencyBasisRuleOnlyWhereItCanBeSatisfied() {
    Record_Health_Check__mdt amount = check(
      'SELECT Id, AnnualRevenue FROM Account ORDER BY Id',
      '{!rhcQuery.sourceRows[0].AnnualRevenue format="CURRENCY"}'
    );
    Record_Health_Check__mdt withBasis = check(
      'SELECT Id, AnnualRevenue, CurrencyIsoCode FROM Account ORDER BY Id',
      '{!rhcQuery.sourceRows[0].AnnualRevenue format="CURRENCY"}'
    );
    Record_Health_Check__mdt autoAmount = check(
      'SELECT Id, AnnualRevenue FROM Account ORDER BY Id',
      '{!rhcQuery.sourceRows[0].AnnualRevenue format="AUTO"}'
    );
    Record_Health_Check__mdt autoText = check(
      'SELECT Id, Name FROM Account ORDER BY Id',
      '{!rhcQuery.sourceRows[0].Name format="AUTO"}'
    );
    Record_Health_Check__mdt aggregate = check(
      'SELECT SUM(AnnualRevenue) total FROM Account',
      '{!rhcQuery.sourceRows[0].total format="CURRENCY"}'
    );

    Assert.isNull(codeFor(withBasis), 'Selecting the currency resolves it.');
    Assert.isNull(codeFor(autoText), 'Auto on text states no currency.');
    Assert.isNull(
      codeFor(aggregate),
      'SOQL refuses a bare CurrencyIsoCode beside an ungrouped aggregate, so ' +
      'one is never demanded.'
    );

    if (RecordHealthCheckDisplayCurrencyResolver.isMultiCurrencyOrg()) {
      Assert.areEqual(
        'FIXED_CURRENCY_BASIS_MISSING',
        codeFor(amount),
        'Multicurrency amounts require an explicit fixed currency basis.'
      );
      Assert.areEqual(
        'FIXED_CURRENCY_BASIS_MISSING',
        codeFor(autoAmount),
        'Auto on a currency field is the quiet version of the same slip.'
      );
    } else {
      Assert.isNull(
        codeFor(amount),
        'One currency in the org means there is nothing to state.'
      );
      Assert.isNull(
        codeFor(autoAmount),
        'AUTO currency needs no additional basis in a single-currency org.'
      );
    }
  }

  /**
   * The same rule proved on both sides of the org condition.
   *
   * An org has one currency mode and cannot pretend otherwise, so the rule is
   * asked the question directly. Without this, half of it would only ever run
   * in half the orgs it ships to.
   */
  @IsTest
  static void statesTheCurrencyRuleIndependentlyOfTheOrgItRunsIn() {
    Map<String, String> byTemplate = new Map<String, String>{
      '{!rhcQuery.sourceRows[0].AnnualRevenue format="CURRENCY"}' => 'SELECT Id, AnnualRevenue FROM Account ORDER BY Id',
      '{!rhcQuery.sourceRows[0].AnnualRevenue format="AUTO"}' => 'SELECT Id, AnnualRevenue FROM Account ORDER BY Id',
      '{!rhcQuery.sourceRows[0].Owner.Name format="CURRENCY"}' => 'SELECT Id, Owner.Name FROM Account ORDER BY Id'
    };
    for (String template : byTemplate.keySet()) {
      RecordHealthCheckToken parsed = RecordHealthCheckTemplateService.parse(
        template
      )[0];
      RecordHealthCheckQueryProjection projection = RecordHealthCheckQueryProjection.of(
        byTemplate.get(template)
      );
      Assert.isNull(
        RecordHealthCheckQueryTokenRules.currencyBasisIssue(
          parsed,
          parsed.shape,
          projection,
          'Source Query',
          false
        ),
        'A single-currency org has one unit, so nothing is demanded: ' +
        template
      );
      RecordHealthCheckTokenIssue multi = RecordHealthCheckQueryTokenRules.currencyBasisIssue(
        parsed,
        parsed.shape,
        projection,
        'Source Query',
        true
      );
      Assert.areEqual(
        'FIXED_CURRENCY_BASIS_MISSING',
        multi?.reasonCode,
        'A currency-rendered amount needs its unit: ' + template
      );
      Assert.isTrue(
        multi.message.contains('CurrencyIsoCode'),
        'And the message names the field to add: ' + multi.message
      );
    }

    // A relationship path needs that relationship's own currency, and a text
    // field needs none at all.
    RecordHealthCheckToken related = RecordHealthCheckTemplateService.parse(
      '{!rhcQuery.sourceRows[0].Owner.Name format="CURRENCY"}'
    )[0];
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.currencyBasisIssue(
        related,
        related.shape,
        RecordHealthCheckQueryProjection.of(
          'SELECT Id, Owner.Name, Owner.CurrencyIsoCode FROM Account ORDER BY Id'
        ),
        'Source Query',
        true
      ),
      'Selecting the related record\'s own currency resolves it.'
    );

    RecordHealthCheckToken plain = RecordHealthCheckTemplateService.parse(
      '{!rhcQuery.sourceRows[0].Name}'
    )[0];
    Assert.isNull(
      RecordHealthCheckQueryTokenRules.currencyBasisIssue(
        plain,
        plain.shape,
        RecordHealthCheckQueryProjection.of(
          'SELECT Id, Name FROM Account ORDER BY Id'
        ),
        'Source Query',
        true
      ),
      'A token with no format never reaches the currency renderer.'
    );
  }

  @IsTest
  static void refusesAnEncryptedFieldWhereverOneExists() {
    String encryptedField;
    for (
      Schema.SObjectField field : Schema.SObjectType.Account.fields.getMap()
        .values()
    ) {
      if (field.getDescribe().getType() == Schema.DisplayType.ENCRYPTEDSTRING) {
        encryptedField = field.getDescribe().getName();
        break;
      }
    }
    if (encryptedField == null) {
      Assert.isNull(
        codeFor(
          check(
            'SELECT Id, Name FROM Account ORDER BY Id',
            '{!rhcQuery.sourceRows[0].Name}'
          )
        ),
        'No encrypted field exists here, so the rule has nothing to refuse.'
      );
      return;
    }
    Assert.areEqual(
      RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
      codeFor(
        check(
          'SELECT Id, ' + encryptedField + ' FROM Account ORDER BY Id',
          '{!rhcQuery.sourceRows[0].' + encryptedField + '}'
        )
      ),
      'An encrypted selected field must retain the unsupported-type reason.'
    );
  }

  @IsTest
  static void refusesEncryptedFieldsWithoutCustomerCreatedSchema() {
    RecordHealthCheckQueryTokenRules.fieldTypeOverrideForTest = Schema.DisplayType.ENCRYPTEDSTRING;
    try {
      RecordHealthCheckTokenIssue issue = RecordHealthCheckQueryTokenRules.firstIssue(
        check(
          'SELECT Id, Name FROM Account ORDER BY Id',
          '{!rhcQuery.sourceRows[0].Name}'
        )
      );
      Assert.areEqual(
        RecordHealthCheckReasonCodes.FIELD_TYPE_NOT_SUPPORTED,
        issue?.reasonCode,
        'The injected unsupported field type must retain its specific validation reason.'
      );
      Assert.isTrue(
        issue.message.contains('encrypted field'),
        'The author receives a specific, actionable safety explanation.'
      );
    } finally {
      RecordHealthCheckQueryTokenRules.fieldTypeOverrideForTest = null;
    }
  }

  @IsTest
  static void toleratesAQueryWhoseObjectCannotBeResolved() {
    // A root object the describe cache cannot resolve leaves the type-based
    // rules with nothing to inspect. They decline rather than throw, and do not
    // duplicate the object check: RecordHealthCheckQuerySchemaValidator already
    // reports an unresolvable root as OBJECT_NOT_RESOLVED, and two findings for
    // one fault would only obscure the real one.
    Assert.isNull(
      codeFor(
        check(
          'SELECT Id, Name FROM ZzzNoSuchObject__c ORDER BY Id',
          '{!rhcQuery.sourceRows[0].Name}'
        )
      ),
      'The token rules judge the token, not whether the object exists.'
    );
  }
}
