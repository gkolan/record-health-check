/** Bounded, stage-only lifecycle observation for one Check evaluation. */
public class RecordHealthCheckExecutionTrace {
  public static final Integer ENTRY_LIMIT = 32;

  private List<Entry> observed = new List<Entry>();
  private Boolean truncated = false;
  private String failure;
  private String activePhase;
  private Integer nextSequence = 1;

  /** Records the operation that is about to begin without claiming completion. */
  public void begin(String phase) {
    if (failure == null && String.isNotBlank(phase)) {
      activePhase = phase;
    }
  }

  /** Records a stage only after its operation completes. */
  public void complete(String stage) {
    if (!containsStage(stage)) {
      add(stage, null);
    }
  }

  /** Records a completed stage with an actually measured duration. */
  public void complete(String stage, Long durationMs) {
    if (!containsStage(stage)) {
      add(stage, durationMs);
    }
  }

  /** Records the terminal failure for the active operation and closes the trace. */
  public void fail(String activePhase) {
    if (failure != null) {
      return;
    }
    this.activePhase = activePhase;
    failure = activePhase + '_FAILED';
    add(failure, null);
  }

  /** Returns a detached ordered snapshot. */
  public List<Entry> entries() {
    List<Entry> snapshot = new List<Entry>();
    for (Entry item : observed) {
      snapshot.add(new Entry(item.sequence, item.stage, item.durationMs));
    }
    return snapshot;
  }

  public Boolean isTruncated() {
    return truncated;
  }

  public String terminalFailure() {
    return failure;
  }

  public String activePhase() {
    return activePhase;
  }

  private void add(String stage, Long durationMs) {
    if (String.isBlank(stage) || (failure != null && stage != failure)) {
      return;
    }
    Integer sequence = nextSequence++;
    if (observed.size() >= ENTRY_LIMIT) {
      truncated = true;
      return;
    }
    observed.add(new Entry(sequence, stage, durationMs));
  }

  private Boolean containsStage(String stage) {
    for (Entry entry : observed) {
      if (entry.stage == stage) {
        return true;
      }
    }
    return false;
  }

  public class Entry {
    public Integer sequence { get; private set; }
    public String stage { get; private set; }
    public Long durationMs { get; private set; }

    private Entry(Integer sequence, String stage, Long durationMs) {
      this.sequence = sequence;
      this.stage = stage;
      this.durationMs = durationMs;
    }
  }
}
