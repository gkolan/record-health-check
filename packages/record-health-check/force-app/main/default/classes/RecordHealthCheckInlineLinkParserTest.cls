/** Regression-first tests for authored inline-link grammar. */
@IsTest
private class RecordHealthCheckInlineLinkParserTest {
  @IsTest
  static void validLinkWithNestedValueTokenIsAccepted() {
    String template = 'Review {!link label="View account" href="/lightning/r/Account/{!record.Id}/view"}';

    Test.startTest();
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
    );
    Set<String> paths = RecordHealthCheckTemplateService.recordPaths(
      template,
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
    );
    Test.stopTest();

    Assert.isTrue(issues.isEmpty(), 'The locked link grammar must validate.');
    Assert.areEqual(
      new Set<String>{ 'Id' },
      paths,
      'Nested value tokens must contribute their record dependency once.'
    );
  }

  @IsTest
  static void attributeOrderIsIndependent() {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      '{!link href="/lightning/r/Account/{!record.Id}/view" label="Account"}',
      RecordHealthCheckTokenSurfaces.DISPLAY_FOUND
    );

    Assert.isTrue(
      issues.isEmpty(),
      'Required link attributes must be accepted in either order.'
    );
  }

  @IsTest
  static void duplicateUnknownAndMissingAttributesAreRejected() {
    assertInvalid(
      '{!link label="Account" label="Duplicate" href="/lightning"}',
      'INLINE_LINK_DUPLICATE_ATTRIBUTE'
    );
    assertInvalid(
      '{!link label="Account" href="/lightning" target="_self"}',
      'INLINE_LINK_UNKNOWN_ATTRIBUTE'
    );
    assertInvalid(
      '{!link label="Account"}',
      'INLINE_LINK_REQUIRED_ATTRIBUTE_MISSING'
    );
  }

  @IsTest
  static void linksAreRejectedOnForbiddenSurfaces() {
    assertInvalidOnSurface(
      '{!link label="Account" href="/lightning"}',
      RecordHealthCheckTokenSurfaces.ACTION_LABEL,
      'INLINE_LINK_NOT_ALLOWED_ON_SURFACE'
    );
    assertInvalidOnSurface(
      '{!link label="Account" href="/lightning"}',
      RecordHealthCheckTokenSurfaces.ACTION_URL,
      'INLINE_LINK_NOT_ALLOWED_ON_SURFACE'
    );
  }

  @IsTest
  static void malformedQuotesEscapesAndNestingAreRejectedWithLocations() {
    assertLocatedInvalid(
      '{!link label="Account" href="/bad\\q"}',
      'INLINE_LINK_MALFORMED_ESCAPE',
      'href'
    );
    assertLocatedInvalid(
      '{!link label="Account" href="/lightning/{!link label=\\"x\\"}"}',
      'INLINE_LINK_NESTING_INVALID',
      'href'
    );
    assertLocatedInvalid(
      '{!link label="Account" href="/lightning',
      'INLINE_LINK_MALFORMED',
      'href'
    );
    assertLocatedInvalid(
      '{!link ="Account" href="/lightning"}',
      'INLINE_LINK_MALFORMED',
      null
    );
  }

  @IsTest
  static void scannerPreservesEscapedValuesAndPlainCompatibility() {
    String template = 'Before {!link label="Say \\"hello\\" and \\\\" href="/ab"} after';
    RecordHealthCheckInlineLinkParser.Result result = RecordHealthCheckInlineLinkParser.scan(
      template
    );

    Assert.areEqual(1, result.links.size(), 'One authored link is found.');
    Assert.areEqual(
      'Say "hello" and \\',
      result.links[0].labelTemplate,
      'The scanner must decode escaped quotes and backslashes in link labels.'
    );
    Assert.areEqual(
      '/ab',
      result.links[0].hrefTemplate,
      'The scanner must retain the authored destination.'
    );
    Assert.areEqual(
      'Before Say "hello" and \\ after',
      RecordHealthCheckInlineLinkParser.flattenToLabels(template, result.links),
      'Legacy display consumers receive only the authored label.'
    );
    Assert.areEqual(
      'Before Say "hello" and \\ after',
      RecordHealthCheckTemplateService.resolveDisplay(
        template,
        new RecordHealthCheckMergeContext()
      ),
      'Plain display resolution must preserve the decoded link label and surrounding text.'
    );
  }

  @IsTest
  static void linkLimitIsEnforcedIncrementally() {
    List<String> links = new List<String>();
    for (Integer index = 0; index < 101; index++) {
      links.add('{!link label="x" href="/x"}');
    }

    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      String.join(links, ''),
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
    );

    Assert.areEqual(
      1,
      issues.size(),
      'Exceeding the inline-link cap must produce one primary issue.'
    );
    Assert.areEqual(
      'INLINE_LINK_LIMIT_EXCEEDED',
      issues[0].reasonCode,
      'The link cap must retain INLINE_LINK_LIMIT_EXCEEDED.'
    );
  }

  @IsTest
  static void rejectsUnsafeStaticAndDynamicAuthorityDestinations() {
    for (
      String href : new List<String>{
        'http://example.com',
        '//example.com',
        'https://user@example.com/path',
        'https://example.com:444/path',
        '/safe/%252e%252e/secret',
        '/safe/%2e%2e/secret'
      }
    ) {
      assertInvalid(
        '{!link label="Account" href="' + href + '"}',
        'INLINE_LINK_UNSAFE_URL'
      );
    }
    assertInvalid(
      '{!link label="Account" href="https://{!record.Name}/path"}',
      'INLINE_LINK_DYNAMIC_AUTHORITY'
    );
  }

  @IsTest
  static void acceptsLockedStaticDestinationForms() {
    for (
      String href : new List<String>{
        '/lightning/r/Account/001000000000001AAA/view',
        'https://example.com/path?q=one%20two#details',
        'https://sub.example.com:443/path',
        'https://xn--bcher-kva.example/path'
      }
    ) {
      List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
        '{!link label="Account" href="' + href + '"}',
        RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
      );
      Assert.isTrue(issues.isEmpty(), 'Expected safe destination: ' + href);
    }
  }

  @IsTest
  static void completeDestinationPolicyCoversHostEncodingAndLimits() {
    for (
      String unsafe : new List<String>{
        null,
        '',
        '0'.repeat(2) + '1000000000001AAA',
        'https://example.com/path'.toUpperCase(),
        'https:///missing-host',
        'https://localhost/path',
        'https://-bad.example/path',
        'https://bad-.example/path',
        'https://bad..example/path',
        'https://example.com./path',
        'https://256.1.1.1/path',
        'https://1.2.3/path',
        'https://[2001:db8::1]/path',
        '/bad path',
        '/bad\\path',
        '/bad%escape',
        '/bad%0aheader',
        '/bad%5cpath'
      }
    ) {
      Assert.isNull(
        RecordHealthCheckInlineUrlPolicy.sanitizeComplete(unsafe),
        'Expected unsafe destination to be rejected.'
      );
    }
    Assert.areEqual(
      '/safe/path?q=a%20b',
      RecordHealthCheckInlineUrlPolicy.sanitizeComplete(
        ' \t/safe/path?q=a%20b\r\n'
      ),
      'Only outer ASCII whitespace is trimmed.'
    );
    Assert.areEqual(
      'https://127.0.0.1:443/path',
      RecordHealthCheckInlineUrlPolicy.sanitizeComplete(
        'https://127.0.0.1:443/path'
      ),
      'An HTTPS IPv4 destination on port 443 must remain valid.'
    );
    Assert.isNull(
      RecordHealthCheckInlineUrlPolicy.sanitizeComplete('/' + 'x'.repeat(2000)),
      'The URL limit is enforced before accumulating more content.'
    );
    assertInvalid(
      '{!link label="Account" href="{!record.Website fallback=\\"/safe\\"}"}',
      'INLINE_LINK_WHOLE_URL_TOKEN_ATTRIBUTES'
    );
  }

  @IsTest
  static void resolvedValuesAreNeverReparsedAsLinks() {
    Account record = RecordHealthCheckTestDataFactory.accountFixture(
      RecordHealthCheckTestDataFactory.account(
        new Map<String, Object>{
          'Name' => '{!link label="Injected" href="https://example.test"}'
        }
      )
    );

    String resolved = RecordHealthCheckTemplateService.resolveDisplay(
      'Name: {!record.Name}',
      new RecordHealthCheckMergeContext().withRecord(record)
    );

    Assert.areEqual(
      'Name: {!link label="Injected" href="https://example.test"}',
      resolved,
      'Resolved field data must remain literal text.'
    );
  }

  @IsTest
  static void missingFinalBraceNeverProducesALink() {
    for (
      String source : new List<String>{
        '{!link label="Account" href="/lightning"',
        '{!link href="/lightning" label="Account"',
        '{!link label="{!record.Name}" href="/lightning"',
        '{!link label="Account" href="/lightning" ',
        'Before {!link label="Account" href="/lightning"'
      }
    ) {
      RecordHealthCheckInlineLinkParser.Result result = RecordHealthCheckInlineLinkParser.scan(
        source
      );
      Assert.isTrue(
        result.links.isEmpty(),
        'An unclosed construct must not produce a valid link: ' + source
      );
      Assert.areEqual(
        1,
        result.issues.size(),
        'An unclosed link must have one primary grammar issue.'
      );
      Assert.areEqual(
        'INLINE_LINK_MALFORMED',
        result.issues[0].reasonCode,
        'The missing final brace must be a structural error.'
      );
      Assert.areEqual(
        source.indexOf('{!link'),
        result.issues[0].startIndex,
        'The error must locate the unclosed link.'
      );
      Assert.areEqual(
        source.length(),
        result.issues[0].endIndex,
        'The error must extend to the end of the source.'
      );
    }
  }

  private static void assertInvalid(String template, String expectedCode) {
    assertInvalidOnSurface(
      template,
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE,
      expectedCode
    );
  }

  private static void assertInvalidOnSurface(
    String template,
    String surface,
    String expectedCode
  ) {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      surface
    );
    Assert.areEqual(1, issues.size(), 'Exactly one primary grammar issue.');
    Assert.areEqual(expectedCode, issues[0].reasonCode, 'Stable issue code.');
  }

  private static void assertLocatedInvalid(
    String template,
    String expectedCode,
    String expectedAttribute
  ) {
    List<RecordHealthCheckTokenIssue> issues = RecordHealthCheckTemplateService.validate(
      template,
      RecordHealthCheckTokenSurfaces.FAILURE_MESSAGE
    );
    Assert.areEqual(1, issues.size(), 'Exactly one primary grammar issue.');
    Assert.areEqual(expectedCode, issues[0].reasonCode, 'Stable issue code.');
    Assert.isNotNull(issues[0].startIndex, 'Issue has a source start offset.');
    Assert.isNotNull(issues[0].endIndex, 'Issue has a source end offset.');
    Assert.areEqual(
      expectedAttribute,
      issues[0].attribute,
      'The grammar issue must identify the offending attribute.'
    );
  }

  @IsTest
  static void numericHostOverflowIsRejectedWithoutThrowing() {
    for (
      String host : new List<String>{
        '2147483648.1.1.1',
        '1.1.1.2147483648',
        '9'.repeat(63) + '.1.1.1'
      }
    ) {
      Assert.isNull(
        RecordHealthCheckInlineUrlPolicy.sanitizeComplete(
          'https://' + host + '/path'
        ),
        'An oversized numeric host segment must be rejected without an exception: ' +
        host
      );
    }
  }

  @IsTest
  static void authoredNumericHostOverflowIsAValidationIssue() {
    RecordHealthCheckTokenIssue issue = RecordHealthCheckInlineUrlPolicy.validateAuthored(
      'https://2147483648.1.1.1/path'
    );
    Assert.isNotNull(
      issue,
      'An overflowing numeric host must produce an authored-URL issue.'
    );
    Assert.areEqual(
      'INLINE_LINK_UNSAFE_URL',
      issue.reasonCode,
      'Numeric host overflow must retain the unsafe-URL reason.'
    );
  }
}
