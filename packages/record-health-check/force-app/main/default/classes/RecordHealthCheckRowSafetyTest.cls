/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * What a queried row cannot do to a message or a link.
 *
 * Row values come from records the framework does not control, so the rules
 * that keep them harmless are worth stating as tests rather than as comments:
 * a value is inserted as text and never becomes markup or a link, and a link
 * that outgrows its limit is dropped rather than shortened into a working link
 * to somewhere else.
 */
@IsTest
private class RecordHealthCheckRowSafetyTest {
  /**
   * A row value long enough to push the finished URL past its limit.
   *
   * Encoding expands the value, so a field well inside its own limit can still
   * produce a URL that is not. The link is dropped rather than shortened: a
   * truncated URL is a working link to the wrong place, which is worse than no
   * link at all.
   */
  @IsTest
  static void dropsALinkWhoseEncodedUrlOutgrowsItsLimit() {
    String oversized = 'a b&c'.repeat(500);
    String resolved = RecordHealthCheckTemplateService.resolveUrl(
      '/lightning/r/Account/{!rhcQuery.sourceRows[0].Name}/view',
      new RecordHealthCheckMergeContext()
        .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Page'))
        .withQueryRows(
          new List<SObject>{
            RecordHealthCheckTestDataFactory.accountFixture(oversized)
          },
          null
        )
    );
    Assert.isTrue(
      resolved.length() > 2000,
      'Precondition: encoding pushed this past the limit: ' + resolved.length()
    );
    Assert.isNull(
      new RecordHealthCheckScopeResultSupport().sanitizeActionUrl(resolved),
      'An oversized URL is dropped, never shortened into a working link to ' +
      'somewhere else.'
    );
  }

  /**
   * Hostile row values reach a message as text and stay text.
   *
   * Markup, a bidirectional override, and URL-looking text are all just
   * characters in a queried field. The framework substitutes them and stops:
   * it never builds an element, and it never turns text that looks like a link
   * into one. Only Action URL creates a link.
   */
  @IsTest
  static void treatsHostileRowValuesAsTextInAMessage() {
    for (
      String hostile : new List<String>{
        '<script>alert(1)</script>',
        'https://attacker.example/path',
        'javascript:alert(1)',
        'before\u202Eafter'
      }
    ) {
      String rendered = RecordHealthCheckTemplateService.resolveDisplay(
        'Review {!rhcQuery.sourceRows[0].Name}',
        new RecordHealthCheckMergeContext()
          .withRecord(RecordHealthCheckTestDataFactory.accountFixture('Page'))
          .withQueryRows(
            new List<SObject>{
              RecordHealthCheckTestDataFactory.accountFixture(hostile)
            },
            null
          )
      );
      Assert.areEqual(
        'Review ' + hostile,
        rendered,
        'The value is inserted verbatim as text, with nothing added around ' +
          'it: ' +
          rendered
      );
      Assert.isFalse(
        rendered.contains('<a '),
        'And nothing in a message ever becomes a link: ' + rendered
      );
    }
  }
}
