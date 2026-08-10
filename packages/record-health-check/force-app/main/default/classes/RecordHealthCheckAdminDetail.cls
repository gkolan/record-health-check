/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/** Diagnostics-only information. This object is never set for a normal response. */
global class RecordHealthCheckAdminDetail {
  @AuraEnabled
  /** Whether the detail contains data restricted to diagnostic viewers. */
  global Boolean containsRestrictedDetail;
  @AuraEnabled
  /** Stable diagnostic reason code. */
  global String reasonCode;
  @AuraEnabled
  /** Sanitized diagnostic explanation. */
  global String message;
  @AuraEnabled
  /** Sanitized configuration snapshot when relevant. */
  global String configurationJson;
  @AuraEnabled
  /** Sanitized resolution guidance when relevant. */
  global String resolutionJson;
}
