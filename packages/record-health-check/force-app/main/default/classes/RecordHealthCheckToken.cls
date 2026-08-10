/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** A parsed namespaced merge token and its source span. */
public class RecordHealthCheckToken {
  public String expression;
  public String namespaceName;
  public String propertyPath;
  public String formatName;
  public String fallbackValue;
  public String attributeError;
  public Integer startIndex;
  public Integer endIndex;

  public RecordHealthCheckToken(
    String expression,
    String namespaceName,
    String propertyPath,
    Integer startIndex,
    Integer endIndex
  ) {
    this(expression, namespaceName, propertyPath, null, startIndex, endIndex);
  }

  public RecordHealthCheckToken(
    String expression,
    String namespaceName,
    String propertyPath,
    String fallbackValue,
    Integer startIndex,
    Integer endIndex
  ) {
    this.expression = expression;
    this.namespaceName = namespaceName;
    this.propertyPath = propertyPath;
    this.fallbackValue = fallbackValue;
    this.startIndex = startIndex;
    this.endIndex = endIndex;
  }
}
