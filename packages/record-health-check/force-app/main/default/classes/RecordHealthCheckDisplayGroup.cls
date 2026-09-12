/** Generic keyed composition for one labeled line of structured display content. */
global class RecordHealthCheckDisplayGroup {
  private static final Integer MAX_KEY_LENGTH = 255;
  private String groupKey;
  private RecordHealthCheckDisplayText label;
  private RecordHealthCheckDisplayText items;
  private RecordHealthCheckDisplayText emptyState;
  private String separator;
  private Boolean valid;

  /** Creates a group with a required stable, nonblank identity key. */
  global RecordHealthCheckDisplayGroup(String key) {
    groupKey = String.isBlank(key) ? null : key.trim();
    separator = ': ';
    valid = groupKey != null && groupKey.length() <= MAX_KEY_LENGTH;
  }

  /** Sets the required structured label rendered before the group items. */
  global RecordHealthCheckDisplayGroup withLabel(
    RecordHealthCheckDisplayText value
  ) {
    label = value;
    return this;
  }

  /** Sets the ordered structured items for this group. */
  global RecordHealthCheckDisplayGroup withItems(
    RecordHealthCheckDisplayText value
  ) {
    items = value;
    return this;
  }

  /** Sets content shown when the item builder is absent or visibly empty. */
  global RecordHealthCheckDisplayGroup withEmptyState(
    RecordHealthCheckDisplayText value
  ) {
    emptyState = value;
    return this;
  }

  /** Replaces the default colon-space separator between label and content. */
  global RecordHealthCheckDisplayGroup withSeparator(String value) {
    if (value == null) {
      valid = false;
    } else {
      separator = value;
    }
    return this;
  }

  public String getKey() {
    return groupKey;
  }

  public RecordHealthCheckDisplayText getLabel() {
    return label;
  }

  public RecordHealthCheckDisplayText getItems() {
    return items;
  }

  public RecordHealthCheckDisplayText getEmptyState() {
    return emptyState;
  }

  public String getSeparator() {
    return separator;
  }

  public Boolean isValid() {
    return valid &&
      isValidFragment(label, true) &&
      !label.isEmpty() &&
      isValidFragment(items, false) &&
      isValidFragment(emptyState, false);
  }

  private static Boolean isValidFragment(
    RecordHealthCheckDisplayText fragment,
    Boolean required
  ) {
    return fragment == null ? !required : fragment.valid;
  }
}
