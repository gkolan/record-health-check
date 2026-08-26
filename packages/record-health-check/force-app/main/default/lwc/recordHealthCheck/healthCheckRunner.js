/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import {
  synthesizeResult,
  normalizeResult,
  toCompletionResult,
  detectDependencyCycles,
  newRunId,
  parseAuraError,
  checkIdentity,
  prerequisiteIdentity
} from "./healthCheckModel";

const MAX_CONCURRENT_EVALUATIONS = 5;

// Lightning pages can host this component more than once. A runner-local limit
// lets every instance open five requests, so three components can create fifteen
// simultaneous Apex transactions. Keep one scheduler per loaded module/page so
// all instances share the same conservative browser-to-Apex budget.
let pageScheduler = { active: 0, queue: [] };

function acquirePageEvaluationSlot(isCurrent) {
  const scheduler = pageScheduler;
  return new Promise((resolve) => {
    if (!isCurrent()) {
      resolve(false);
      return;
    }
    if (scheduler.active < MAX_CONCURRENT_EVALUATIONS) {
      scheduler.active++;
      resolve(scheduler);
      return;
    }
    scheduler.queue.push({ isCurrent, resolve });
  });
}

function tryAcquirePageEvaluationSlot(isCurrent) {
  if (!isCurrent()) return false;
  if (pageScheduler.active >= MAX_CONCURRENT_EVALUATIONS) return null;
  pageScheduler.active++;
  return pageScheduler;
}

function releasePageEvaluationSlot(scheduler) {
  scheduler.active = Math.max(0, scheduler.active - 1);
  while (
    scheduler.queue.length > 0 &&
    scheduler.active < MAX_CONCURRENT_EVALUATIONS
  ) {
    const next = scheduler.queue.shift();
    if (!next.isCurrent()) {
      next.resolve(false);
      continue;
    }
    scheduler.active++;
    next.resolve(scheduler);
    break;
  }
}

// Jest intentionally leaves some mocked Apex promises unresolved to verify stale
// result handling. Give each test an isolated scheduler generation without
// changing production behavior or releasing a real browser request early.
export function resetPageEvaluationSchedulerForTest() {
  pageScheduler = { active: 0, queue: [] };
}

/**
 * Run lifecycle: dependency gating, concurrency-capped evaluation, progressive reveal.
 */
export class HealthCheckRunner {
  _resultBuffer = new Map();
  _stopped = false;
  _runInProgress = false;
  _runToken = 0;
  _runId = null;

  constructor(host, services) {
    this.host = host;
    this.evaluateCheck = services.evaluateCheck;
    this.completeRun = services.completeRun;
  }

  get isRunning() {
    return this._runInProgress;
  }

  get runId() {
    return this._runId;
  }

  /** Starts a fresh correlation id, stores it for the upcoming run, and returns it. */
  beginRunId() {
    this._runId = newRunId();
    return this._runId;
  }

  /**
   * Invalidate any run still in flight (token bump) and clear orchestration
   * state. Called on record/config reload and on disconnect. The component
   * resets its own reactive counters (completedCheckCount, runComplete).
   */
  invalidate() {
    this._runToken++;
    this._runInProgress = false;
    this._stopped = false;
    this._resultBuffer = new Map();
  }

  run(reuseRunId = false, source = "USER_INITIATED") {
    if (this._runInProgress) return;
    if (!["USER_INITIATED", "RUN_ON_LOAD"].includes(source)) {
      throw Object.assign(
        new Error("The execution source is not recognized."),
        {
          reasonCode: "INVALID_EXECUTION_SOURCE"
        }
      );
    }
    this._runInProgress = true;
    if (!reuseRunId || !this._runId) {
      this._runId = newRunId();
    }
    const token = ++this._runToken; // capture token for this run; prior in-flight calls carry the old value
    this.host.completedCheckCount = 0;
    this.host.runComplete = false;
    this._resultBuffer = new Map();
    this._stopped = false;
    this._source = source;

    // Reset all rows to PENDING and clear previous results
    this.host.checks = this.host.checks.map((c) => ({
      ...c,
      uiState: "PENDING",
      result: null
    }));

    if (this.host.checks.length === 0) {
      this.host.runComplete = true;
      this.host.hasCompletedRunOnce = true;
      this._runInProgress = false;
      return;
    }

    // Pre-seed circular dependencies as errors so their Promises resolve immediately
    // rather than hanging indefinitely awaiting each other.
    // Message wording matches RecordHealthCheckScopePipeline (names the blocking prerequisite).
    const cycleNames = detectDependencyCycles(this.host.checks);
    const checkMap = new Map();
    for (const check of this.host.checks) {
      checkMap.set(checkIdentity(check), check);
    }
    for (const name of cycleNames) {
      const check = checkMap.get(name);
      if (check) {
        const prereqName =
          prerequisiteIdentity(check, this.host.checks) ||
          check.dependsOnCheckDeveloperName;
        this._resultBuffer.set(
          name,
          synthesizeResult(
            check,
            "UNABLE_TO_EVALUATE",
            "CIRCULAR_DEPENDENCY",
            `Circular dependency with "${prereqName}".`
          )
        );
      }
    }

    if (this.host.stopOnFirstError) {
      this._runChecksSequentially(checkMap, cycleNames, token).catch(() => {
        if (token === this._runToken) {
          this._runInProgress = false;
        }
      });
      return;
    }

    // Fire checks concurrently, but create tasks recursively so dependencies
    // can point to checks that appear later in the ordered run list.
    const taskMap = new Map(); // qualifiedApiName -> Promise
    const runCheck = this._makeRunCheck(taskMap, checkMap, cycleNames, token);

    for (const check of this.host.checks) {
      runCheck(check).catch(() => {
        if (
          token === this._runToken &&
          !this._resultBuffer.has(checkIdentity(check))
        ) {
          this._resultBuffer.set(
            checkIdentity(check),
            synthesizeResult(
              check,
              "ERROR",
              "CLIENT_CALL_FAILED",
              "The check could not be reached. Please try again."
            )
          );
          this._drain(token);
        }
      });
    }
  }

  /**
   * Builds the recursive task launcher shared by the concurrent and sequential
   * run paths. Each check's promise is memoized in taskMap so a check is only
   * evaluated once even when several dependents point at it; cycle members
   * return early with an already-resolved promise (their result is pre-seeded).
   */
  _makeRunCheck(taskMap, checkMap, cycleNames, token) {
    const runCheck = (check) => {
      const identity = checkIdentity(check);
      if (taskMap.has(identity)) {
        return taskMap.get(identity);
      }
      if (cycleNames.has(identity)) {
        taskMap.set(identity, Promise.resolve());
        this._drain(token);
        return taskMap.get(identity);
      }
      taskMap.set(
        identity,
        this._runOneCheck(check, taskMap, checkMap, runCheck, token)
      );
      return taskMap.get(identity);
    };
    return runCheck;
  }

  async _runChecksSequentially(checkMap, cycleNames, token) {
    try {
      const taskMap = new Map();
      const runCheck = this._makeRunCheck(taskMap, checkMap, cycleNames, token);

      for (const check of this.host.checks) {
        if (this._stopped) {
          break;
        }
        // stopOnFirstError must wait for each result before starting the next check.
        // eslint-disable-next-line no-await-in-loop
        await runCheck(check);
      }
    } finally {
      if (token === this._runToken) {
        const allResolved = this.host.checks.every((c) =>
          this._resultBuffer.has(checkIdentity(c))
        );
        if (!allResolved) {
          this._runInProgress = false;
        }
      }
    }
  }

  async _runOneCheck(check, taskMap, checkMap, runCheck, token) {
    if (this._stopped || token !== this._runToken) return;

    // Enforce the Prerequisite Check before calling Apex.
    const prerequisiteKey = prerequisiteIdentity(check, this.host.checks);
    if (prerequisiteKey) {
      const prerequisiteCheck = checkMap.get(prerequisiteKey);
      if (!prerequisiteCheck) {
        const skipped = synthesizeResult(
          check,
          "SKIPPED",
          "DEPENDENCY_NOT_IN_RUN",
          `Skipped because Prerequisite Check "${prerequisiteKey}" was not included in the Framework run.`
        );
        this._resultBuffer.set(checkIdentity(check), skipped);
        this._drain(token);
        return;
      }
      if (!taskMap.has(prerequisiteKey)) {
        runCheck(prerequisiteCheck);
      }
      await taskMap.get(prerequisiteKey);
      if (this._stopped || token !== this._runToken) return;
      const prereqResult = this._resultBuffer.get(prerequisiteKey);
      if (!prereqResult || prereqResult.status !== "PASS") {
        const prereqLabel =
          prerequisiteCheck.label ||
          check.dependsOnCheckDeveloperName ||
          prerequisiteKey;
        const skipped = synthesizeResult(
          check,
          "SKIPPED",
          "PREREQUISITE_NOT_MET",
          `Skipped because Prerequisite Check "${prereqLabel}" did not pass.`
        );
        this._resultBuffer.set(checkIdentity(check), skipped);
        this._drain(token);
        return;
      }
    }

    // Set row to LOADING
    this._setCheckUiState(checkIdentity(check), "LOADING");

    let acquiredScheduler = tryAcquirePageEvaluationSlot(
      () => token === this._runToken
    );
    if (acquiredScheduler === null) {
      acquiredScheduler = await this._acquireEvaluationSlot(token);
    }
    if (!acquiredScheduler) return;
    if (token !== this._runToken) {
      this._releaseEvaluationSlot(acquiredScheduler);
      return;
    }

    let result;
    try {
      result = await this.evaluateCheck({
        checkSetQualifiedApiName: this.host.checkSetName,
        checkQualifiedApiName: check.qualifiedApiName,
        recordId: this.host.recordId,
        runId: this._runId,
        source: this._source
      });
    } catch (error) {
      const parsed = parseAuraError(error);
      const isGenericFailure = parsed.reasonCode === "LOAD_FAILED";
      result = synthesizeResult(
        check,
        "ERROR",
        isGenericFailure ? "CLIENT_CALL_FAILED" : parsed.reasonCode,
        isGenericFailure
          ? "The check could not be reached. Please try again."
          : parsed.message
      );
    } finally {
      this._releaseEvaluationSlot(acquiredScheduler);
    }

    // Discard result if a newer run has started since this call was fired
    if (token !== this._runToken) return;

    this._resultBuffer.set(
      checkIdentity(check),
      normalizeResult(result, check)
    );
    this._drain(token);
  }

  _drain(token) {
    if (token !== this._runToken) return;

    this.host.checks = this.host.checks.map((c) => {
      const identity = checkIdentity(c);
      const buffered = this._resultBuffer.get(identity);
      if (this._resultBuffer.has(identity) && c.uiState !== "RESOLVED") {
        return {
          ...c,
          uiState: "RESOLVED",
          result: normalizeResult(buffered, c)
        };
      }
      return c;
    });
    this.host.completedCheckCount = this.host.checks.filter(
      (c) => c.uiState === "RESOLVED"
    ).length;

    // Stop on first ERROR: synthesize SKIPPED for checks not yet evaluated.
    if (this.host.stopOnFirstError && !this._stopped) {
      const errored = this.host.checks.some(
        (c) =>
          c.uiState === "RESOLVED" && c.result && c.result.status === "ERROR"
      );
      if (errored) {
        this._stopped = true;
        let synthesizedAny = false;
        for (const c of this.host.checks) {
          const identity = checkIdentity(c);
          if (!this._resultBuffer.has(identity)) {
            this._resultBuffer.set(
              identity,
              synthesizeResult(
                c,
                "SKIPPED",
                "STOPPED_AFTER_ERROR",
                "This check was skipped because an earlier check encountered an error."
              )
            );
            synthesizedAny = true;
          }
        }
        if (synthesizedAny) {
          this._drain(token);
          return;
        }
      }
    }

    // The run is complete once every check has produced a result.
    const allResolved = this.host.checks.every((c) =>
      this._resultBuffer.has(checkIdentity(c))
    );
    if (allResolved && !this.host.runComplete) {
      this.host.runComplete = true;
      this.host.hasCompletedRunOnce = true;
      this._runInProgress = false;
      if (this._source === "USER_INITIATED") {
        this.completeRun({
          checkSetQualifiedApiName: this.host.checkSetName,
          runId: this._runId,
          source: this._source,
          recordId: this.host.recordId,
          resultsJson: JSON.stringify(
            Array.from(this._resultBuffer.values()).map((result) =>
              toCompletionResult(result, this.host.recordId)
            )
          )
        }).catch((error) => {
          if (token === this._runToken) {
            this.host._handleCompletionFailure?.(error);
          }
        });
      }
      if (this.host.showDiagnostics) {
        this.host._logRunDiagnostics();
      }
    }
  }

  _acquireEvaluationSlot(token) {
    return acquirePageEvaluationSlot(() => token === this._runToken);
  }

  _releaseEvaluationSlot(scheduler) {
    releasePageEvaluationSlot(scheduler);
  }

  _setCheckUiState(identity, uiState) {
    this.host.checks = this.host.checks.map((c) => {
      return checkIdentity(c) === identity ? { ...c, uiState } : c;
    });
  }
}
