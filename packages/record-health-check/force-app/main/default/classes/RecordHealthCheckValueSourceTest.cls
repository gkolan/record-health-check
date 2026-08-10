/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

@IsTest
private class RecordHealthCheckValueSourceTest {
  @IsTest
  static void defaultDetailStartsWithoutSourceLabel() {
    Test.startTest();
    RecordHealthCheckValueSource.Detail detail = new RecordHealthCheckValueSource.Detail();
    Test.stopTest();

    Assert.isNull(
      detail.sourceLabel,
      'The default Detail must start without a source label.'
    );
  }

  @IsTest
  static void rendersSourceRawAndCoercion() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      'NumberOfEmployees',
      'null',
      'blank treated as 0'
    );
    Assert.areEqual(
      'NumberOfEmployees → null (blank treated as 0)',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void rendersSourceAndRawWithoutCoercion() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      'Contacts',
      '0 rows',
      null
    );
    Assert.areEqual(
      'Contacts → 0 rows',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void rendersSourceOnly() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      'Pass/Fail condition',
      null,
      null
    );
    Assert.areEqual(
      'Pass/Fail condition',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void rendersRawOnlyWhenSourceBlank() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      '  ',
      '42',
      null
    );
    Assert.areEqual('42', RecordHealthCheckValueSource.render(d));
  }

  @IsTest
  static void rendersCoercionOnlyWithoutNullPointer() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      null,
      null,
      'blank treated as 0'
    );
    Assert.areEqual(
      '(blank treated as 0)',
      RecordHealthCheckValueSource.render(d)
    );
  }

  @IsTest
  static void returnsNullForNullDetail() {
    Assert.areEqual(null, RecordHealthCheckValueSource.render(null));
  }

  @IsTest
  static void returnsNullWhenEveryPartBlank() {
    RecordHealthCheckValueSource.Detail d = new RecordHealthCheckValueSource.Detail(
      '',
      '   ',
      null
    );
    Assert.areEqual(
      null,
      RecordHealthCheckValueSource.render(d),
      'An all-blank detail renders nothing rather than an empty note.'
    );
  }

  @IsTest
  static void rowCountPluralizesCorrectly() {
    Assert.areEqual('0 rows', RecordHealthCheckValueSource.rowCount(0));
    Assert.areEqual(
      '1 row',
      RecordHealthCheckValueSource.rowCount(1),
      'A single row uses the singular unit, not "1 row(s)".'
    );
    Assert.areEqual('3 rows', RecordHealthCheckValueSource.rowCount(3));
    Assert.areEqual(
      '0 rows',
      RecordHealthCheckValueSource.rowCount(null),
      'Null is treated as 0.'
    );
  }
}
