/** Verifies incremental UTF-8 bounds on subscriber-authored display fields. */
@IsTest
private class RHCDisplayByteBudgetTest {
  @IsTest
  static void fieldBytesAreBoundedAtTheExactBoundary() {
    for (String label : new List<String>{ 'x', 'é😀' }) {
      for (Integer offset : new List<Integer>{ -1, 0, 1 }) {
        RecordHealthCheckDisplayText builder = exactByteBuilder(
          65536 + offset,
          label
        );
        Assert.areEqual(
          offset <= 0,
          builder.valid,
          'The UTF-8 field boundary must include URLs and JSON overhead for ' +
            label +
            ' at offset ' +
            offset
        );
        Integer bytes = Blob.valueOf(JSON.serialize(builder.copyNodes()))
          .size();
        Assert.isTrue(
          bytes <= 65536,
          'An oversized node must not remain in accumulated builder state.'
        );
        if (offset <= 0) {
          Assert.areEqual(
            65536 + offset,
            bytes,
            'A valid boundary field must remain intact.'
          );
        }
      }
    }
  }

  @IsTest
  static void coalescedTextIncludesSerializedEscapeGrowth() {
    RecordHealthCheckDisplayText builder = new RecordHealthCheckDisplayText();
    builder.text(''.leftPad(10000, '\t'));
    builder.text(''.leftPad(10000, '\t'));
    Assert.isTrue(
      builder.valid,
      'Twenty thousand tab characters fit the visible and serialized bounds.'
    );
    Assert.areEqual(
      1,
      builder.copyNodes().size(),
      'Adjacent text must still coalesce into one node.'
    );
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(builder.copyNodes())).size() <= 65536,
      'Escaped text must remain bounded after coalescing.'
    );
  }

  @IsTest
  static void composedGroupsShareTheFieldByteBudget() {
    RecordHealthCheckDisplayText first = exactByteBuilder(40000, 'x');
    RecordHealthCheckDisplayText second = exactByteBuilder(40000, 'x');
    RecordHealthCheckDisplayText composed = new RecordHealthCheckDisplayText()
      .groups(
        new List<RecordHealthCheckDisplayGroup>{
          new RecordHealthCheckDisplayGroup('first')
            .withLabel(new RecordHealthCheckDisplayText().text('First'))
            .withItems(first),
          new RecordHealthCheckDisplayGroup('second')
            .withLabel(new RecordHealthCheckDisplayText().text('Second'))
            .withItems(second)
        }
      );
    Assert.isFalse(
      composed.valid,
      'Individually valid fragments must share one composed field budget.'
    );
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(composed.copyNodes())).size() <= 65536,
      'Composition must stop before retaining an oversized node.'
    );
  }

  @IsTest
  static void coalescingTextDoesNotConsumeAnotherNode() {
    RecordHealthCheckDisplayText builder = new RecordHealthCheckDisplayText();
    for (Integer index = 0; index < 500; index++) {
      builder.lineBreak().text('x');
    }
    Assert.isTrue(
      builder.valid,
      'The existing one-thousand-node boundary must fit.'
    );
    builder.text('suffix');
    Assert.isTrue(
      builder.valid,
      'Coalescing into the last text node must not consume node 1001.'
    );
    Assert.areEqual(
      1000,
      builder.copyNodes().size(),
      'Appending adjacent text must preserve the node count.'
    );
    Assert.areEqual(
      'xsuffix',
      builder.copyNodes()[999].text,
      'Coalesced text must preserve both fragments.'
    );
  }

  @IsTest
  static void coalescedEscapedTextCannotExceedTheByteBudget() {
    String control = (String) JSON.deserialize('"\\u0001"', String.class);
    RecordHealthCheckDisplayText builder = new RecordHealthCheckDisplayText()
      .text(''.leftPad(10000, control));
    Assert.isTrue(builder.valid, 'The first escaped fragment must fit.');
    builder.text(''.leftPad(1000, control));
    Assert.isFalse(
      builder.valid,
      'JSON escaping must count toward the merged text byte budget.'
    );
    Assert.isTrue(
      Blob.valueOf(JSON.serialize(builder.copyNodes())).size() <= 65536,
      'The oversized merged value must not replace the retained node.'
    );
  }

  @IsTest
  static void authoredLinksStopAtOneHundred() {
    RecordHealthCheckDisplayText builder = new RecordHealthCheckDisplayText();
    for (Integer index = 0; index < 100; index++) {
      builder.link('x', '/record');
    }
    Assert.isTrue(builder.valid, 'One hundred short links must remain valid.');
    builder.link('x', '/record');
    Assert.isFalse(
      builder.valid,
      'The documented one-hundred-link field cap must apply to builders.'
    );
    Assert.areEqual(
      100,
      builder.copyNodes().size(),
      'The extra link must not be retained.'
    );
  }

  private static RecordHealthCheckDisplayText exactByteBuilder(
    Integer targetBytes,
    String label
  ) {
    RecordHealthCheckDisplayText builder = new RecordHealthCheckDisplayText();
    List<RecordHealthCheckDisplayNode> expected = new List<RecordHealthCheckDisplayNode>();
    String prefix = 'https://example.com/';
    String fullUrl = prefix + ''.leftPad(2000 - prefix.length(), 'a');
    Integer nodeBytes = Blob.valueOf(
        JSON.serialize(new RecordHealthCheckDisplayNode('link', label, fullUrl))
      )
      .size();
    Integer count = (targetBytes - 100) / (nodeBytes + 1);
    for (Integer index = 0; index < count; index++) {
      expected.add(new RecordHealthCheckDisplayNode('link', label, fullUrl));
      builder.link(label, fullUrl);
    }
    Integer remaining =
      targetBytes - Blob.valueOf(JSON.serialize(expected)).size();
    RecordHealthCheckDisplayNode last = new RecordHealthCheckDisplayNode(
      'link',
      label,
      prefix
    );
    Integer padding =
      remaining -
      Blob.valueOf(JSON.serialize(last)).size() -
      (expected.isEmpty() ? 0 : 1);
    Assert.isTrue(
      padding >= 0 && padding + prefix.length() <= 2000,
      'The exact byte fixture must use a valid URL length.'
    );
    last.href += ''.leftPad(padding, 'b');
    expected.add(last);
    Assert.areEqual(
      targetBytes,
      Blob.valueOf(JSON.serialize(expected)).size(),
      'The independent fixture must hit the requested UTF-8 byte count.'
    );
    builder.link(label, last.href);
    return builder;
  }
}
