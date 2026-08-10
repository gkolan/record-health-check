/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Reports whether an object has active and/or inactive Check Sets.
 * Used when the LWC has no Check Set selected, so the setup banner can say
 * choose one, activate one, or create one.
 */
public class RecordHealthCheckSetAvailability {
  @AuraEnabled
  public Boolean hasActive;
  @AuraEnabled
  public Boolean hasInactive;

  public RecordHealthCheckSetAvailability() {
    this.hasActive = false;
    this.hasInactive = false;
  }
}
