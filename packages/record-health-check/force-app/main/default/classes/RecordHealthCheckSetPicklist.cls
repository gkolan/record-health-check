/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Design-time picklist for the LWC's Check Set property in Lightning App Builder.
 * Replaces free-text entry of a Check Set QualifiedApiName, the most common cause
 * of a blank card — with a dropdown of the active Check Sets that apply to the
 * record page's object.
 *
 * Each option displays the Check Set Master Label while storing its
 * QualifiedApiName. This keeps packaged and subscriber-owned records
 * unambiguous without exposing namespace prefixes in App Builder. App Builder
 * supplies the page's object through DesignTimePageContext.entityName, so the
 * list is scoped to Check Sets whose ObjectApiName__c matches. Runs at design
 * time as the admin building the page; custom-metadata SOQL is not
 * governor-limited.
 */
public with sharing class RecordHealthCheckSetPicklist extends VisualEditor.DynamicPickList {
  private final VisualEditor.DesignTimePageContext context;

  public RecordHealthCheckSetPicklist(
    VisualEditor.DesignTimePageContext context
  ) {
    this.context = context;
  }

  /**
   * Auto-selects the object's sole active Check Set so dropping the component
   * onto a page with one obvious choice works with zero clicks. With zero or
   * several matches, returns null so the admin picks explicitly.
   */
  public override VisualEditor.DataRow getDefaultValue() {
    List<Record_Health_Check_Set__mdt> checkSets = scopedCheckSets();
    return checkSets.size() == 1 ? row(checkSets[0]) : null;
  }

  public override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows rows = new VisualEditor.DynamicPickListRows();
    for (Record_Health_Check_Set__mdt checkSet : scopedCheckSets()) {
      rows.addRow(row(checkSet));
    }
    return rows;
  }

  /** Active Check Sets scoped to the page's object and sorted by label. */
  private List<Record_Health_Check_Set__mdt> scopedCheckSets() {
    String entityName = context == null ? null : context.entityName;
    List<Record_Health_Check_Set__mdt> checkSets = new List<Record_Health_Check_Set__mdt>();
    // code-analyzer-suppress-next-line ApexCRUDViolation: Custom Metadata configuration is setup data for App Builder design-time choices; runtime access is enforced by RecordHealthCheckAccess before definitions are exposed.
    for (Record_Health_Check_Set__mdt checkSet : [
      SELECT QualifiedApiName, DeveloperName, MasterLabel, ObjectApiName__c
      FROM Record_Health_Check_Set__mdt
      WHERE IsActive__c = TRUE
      ORDER BY MasterLabel ASC, DeveloperName ASC
    ]) {
      // Scope to the record page's object when App Builder names one; a page
      // without an entity (e.g. a template being edited) shows every active set.
      if (
        String.isBlank(entityName) ||
        entityName.equalsIgnoreCase(checkSet.ObjectApiName__c)
      ) {
        checkSets.add(checkSet);
      }
    }
    return checkSets;
  }

  /** Displays Master Label while retaining QualifiedApiName as the stored value. */
  private VisualEditor.DataRow row(Record_Health_Check_Set__mdt checkSet) {
    return new VisualEditor.DataRow(
      checkSet.MasterLabel,
      checkSet.QualifiedApiName
    );
  }
}
