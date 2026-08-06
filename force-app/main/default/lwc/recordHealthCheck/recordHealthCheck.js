/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import { LightningElement, api, track } from "lwc";
import themeStyles from "./recordHealthCheckTheme.css";
import USER_ID from "@salesforce/user/Id";
import getCheckDefinitions from "@salesforce/apex/RecordHealthCheckController.getCheckDefinitions";
import getCheckSetAvailabilityForRecord from "@salesforce/apex/RecordHealthCheckController.getCheckSetAvailabilityForRecord";
import evaluateCheck from "@salesforce/apex/RecordHealthCheckController.evaluateCheck";
import completeRun from "@salesforce/apex/RecordHealthCheckController.completeRun";
import { parseAuraError } from "./healthCheckModel";
import { annotateCheck, buildSummaryGroups } from "./healthCheckPresentation";
import { HealthCheckRunner } from "./healthCheckRunner";
import {
  buildInactiveRuleStat,
  formatRunSummary,
  parseDiagnosticJson,
  setupErrorHint
} from "./healthCheckDiagnostics";

// Columns shown in the run-diagnostics table. Value-source detail stays in the nested
// group below — those strings are long and read better one check at a time.
const RHC_DIAG_TABLE_COLUMNS = [
  "check",
  "status",
  "severity",
  "reasonCode",
  "actualValue",
  "expectedValue",
  "durationMs",
  "evaluatorType"
];

// Pointer hover waits before the tooltip fades in so quick row scans do not flash
// popovers. Keyboard focus keeps a shorter CSS dwell (see recordHealthCheck.css).
const TOOLTIP_HOVER_DWELL_MS = 1000;
const ESTIMATED_TOOLTIP_HEIGHT = 180;

const SETUP_ERROR_CODES = new Set([
  "SETUP_REQUIRED",
  "NO_ACTIVE_CHECK_SETS",
  "INACTIVE_CHECK_SETS_ONLY",
  "CONFIG_NOT_FOUND",
  "CONFIG_INACTIVE",
  "OBJECT_MISMATCH",
  "NO_RECORD_CONTEXT",
  "NO_ACTIVE_CHECKS",
  "INVALID_CONFIG"
]);

/** SLDS 2 / Cosmos pages expose one of these (absent on SLDS 1). */
const SLDS2_COLOR_SCHEME_CLASSES = [
  "slds-color-scheme--light",
  "slds-color-scheme--dark",
  "slds-color-scheme--system"
];

function elementHasSlds2ColorScheme(el) {
  if (!el?.classList) {
    return false;
  }
  return SLDS2_COLOR_SCHEME_CLASSES.some((name) => el.classList.contains(name));
}

function detectSlds2Theme() {
  if (typeof document === "undefined") {
    return false;
  }
  if (
    elementHasSlds2ColorScheme(document.body) ||
    elementHasSlds2ColorScheme(document.documentElement)
  ) {
    return true;
  }
  // Cosmos / SLDS 2 publishes the surface scale on :root. Presence of
  // --slds-g-color-surface-1 is enough — do not also require --lwc-* to be
  // absent; Lightning may leave legacy tokens defined after a theme switch.
  try {
    return (
      getComputedStyle(document.documentElement)
        .getPropertyValue("--slds-g-color-surface-1")
        .trim().length > 0
    );
  } catch {
    return false;
  }
}

export default class RecordHealthCheck extends LightningElement {
  static stylesheets = [themeStyles];

  _checkSetName;
  @track _isSlds2 = false;

  get themeClass() {
    return this._isSlds2 ? "rhc-theme rhc-theme_slds2" : "rhc-theme";
  }

  @api
  get checkSetName() {
    return this._checkSetName;
  }
  set checkSetName(value) {
    const changed = value !== this._checkSetName;
    this._checkSetName = value;
    if (this._connected && changed) {
      this._loadDefinitions();
    }
  }

  // recordId is a getter/setter so the component reloads when the record page
  // swaps the underlying record without remounting the component (e.g. console
  // navigation, dynamic record pages). Without this, results would be stale or
  // belong to the previously-viewed record.
  _recordId;
  _connected = false;

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    const changed = value !== this._recordId;
    this._recordId = value;
    // Only reload on a genuine change after the initial connectedCallback load;
    // the first load is owned by connectedCallback so it can defer one macrotask.
    if (this._connected && changed) {
      this._loadDefinitions();
    }
  }

  @track displayTitle;
  @track displayDescription;
  @track triggerMode;
  @track revealMode;
  @track successDisplayMode;
  @track skippedDisplayMode;
  @track comparisonDisplay = "OnDemand";
  @track stopOnFirstError;
  @track showDiagnostics = false;
  @track totalCheckCount = 0;
  @track totalAvailableCheckCount = 0;
  @track frameworkMaxChecks = 25;
  @track inactiveRuleCount = 0;
  @track inactiveRuleLabels = [];
  @track completedCheckCount = 0;
  @track runComplete = false;
  /** Stays true after the first completed run until definitions reload — drives
   *  the Run/Rerun label while a subsequent run is in flight (runComplete is
   *  false during that window). */
  @track hasCompletedRunOnce = false;
  @track componentError = null; // safe user-facing message
  @track componentErrorCode = null;
  @track componentErrorDiagnosticCode = null;
  @track checksOmittedByLimit = false;
  @track isLoading = true;

  @track checks = [];

  // Per-row disclosure overrides, keyed by developerName. Absent → the row
  // starts collapsed (the default). Reassigned on toggle so
  // the visibleChecks getter re-annotates. Lives outside `checks` because the
  // runner rebuilds that array on every result; expand state must survive that.
  @track _expandedNames = {};

  // Run orchestration (result buffer, reveal pointer, concurrency pool, run id,
  // and the run token that discards stale in-flight results) lives in the runner;
  // the component owns lifecycle, definition loading, display, and diagnostics.
  _runner = new HealthCheckRunner(this, { evaluateCheck, completeRun });
  _loadToken = 0;
  _initialLoadFrame;
  _tooltipListenersBound = false;
  _tooltipDwellTimers = new WeakMap();
  _pendingTooltipAnchors = new Set();
  _summaryStatsSource = null;
  _summaryStatsTooltipSignature = "";
  _inactiveStatSignature = "";
  _summaryStatsCache = [];
  _visibleChecksSource = null;
  _visibleChecksSignature = "";
  _visibleChecksCache = [];
  _resizeFrame;

  connectedCallback() {
    this._connected = true;
    this._syncDesignTheme();
    // LWS forbids MutationObserver on shared document/body/html nodes, so
    // re-check when the user returns to the tab after switching themes in Setup.
    window.addEventListener("focus", this._syncDesignTheme);
    window.addEventListener("visibilitychange", this._syncDesignTheme);
    window.addEventListener("resize", this._handleViewportResize);
    // Yield the first frame to the Lightning page before loading definitions.
    // Automatic evaluation therefore cannot compete with the page's initial
    // component mount and first meaningful paint.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._initialLoadFrame = requestAnimationFrame(() => {
      this._initialLoadFrame = null;
      // Theme tokens can land after first paint when Cosmos/SLDS 1 is applied.
      this._syncDesignTheme();
      this._loadDefinitions();
    });
  }

  disconnectedCallback() {
    this._connected = false;
    window.removeEventListener("focus", this._syncDesignTheme);
    window.removeEventListener("visibilitychange", this._syncDesignTheme);
    window.removeEventListener("resize", this._handleViewportResize);
    if (this._resizeFrame) {
      cancelAnimationFrame(this._resizeFrame);
      this._resizeFrame = null;
    }
    this._loadToken++;
    if (this._initialLoadFrame) {
      cancelAnimationFrame(this._initialLoadFrame);
      this._initialLoadFrame = null;
    }
    // Bump the run token and clear the concurrency pool so any in-flight
    // evaluation resolves to a discarded result instead of changing a dead component.
    this._runner.invalidate();
    if (this._tooltipListenersBound) {
      this.template.removeEventListener("mouseover", this._positionTooltip);
      this.template.removeEventListener(
        "mouseover",
        this._handleTooltipMouseOver
      );
      this.template.removeEventListener("focusin", this._positionTooltip);
      this.template.removeEventListener("mouseout", this._clearTooltipFlip);
      this.template.removeEventListener(
        "mouseout",
        this._handleTooltipMouseOut
      );
      this.template.removeEventListener("focusout", this._clearTooltipFlip);
      this.template.removeEventListener(
        "focusout",
        this._handleTooltipFocusOut
      );
      this._tooltipListenersBound = false;
    }
    this._clearAllTooltipDwells();
  }

  _syncDesignTheme = () => {
    if (!this._connected) {
      return;
    }
    const next = detectSlds2Theme();
    if (next !== this._isSlds2) {
      this._isSlds2 = next;
    }
  };

  renderedCallback() {
    // Re-check on each render so a soft theme change that remounts children
    // (without focus/visibility events) still picks up Cosmos chrome.
    this._syncDesignTheme();
    // Content grows as checks resolve, so re-measure every clampable region and
    // reveal its +/- toggle only when the rendered text actually overflows.
    this._measureClampedContent();
    if (this._tooltipListenersBound) {
      return;
    }
    this._tooltipListenersBound = true;
    // Tooltips open downward by default (pure CSS). On hover/focus we measure the
    // anchor against the viewport and add --flip-up when there is not enough room
    // below, so a tooltip near the bottom of the screen opens upward instead of
    // being clipped. Delegated on the template root — mouseover and focusin both
    // bubble, so one listener pair covers every rule row and summary pill.
    this.template.addEventListener("mouseover", this._positionTooltip);
    this.template.addEventListener("mouseover", this._handleTooltipMouseOver);
    this.template.addEventListener("focusin", this._positionTooltip);
    this.template.addEventListener("mouseout", this._clearTooltipFlip);
    this.template.addEventListener("mouseout", this._handleTooltipMouseOut);
    this.template.addEventListener("focusout", this._clearTooltipFlip);
    this.template.addEventListener("focusout", this._handleTooltipFocusOut);
  }

  // Removes the flip-up modifier once the pointer/focus leaves the anchor entirely
  // (ignoring moves between the anchor's own children), so the next open recomputes
  // direction from the default downward position instead of a stale flipped state.
  _clearTooltipFlip = (event) => {
    const anchor =
      event.target && event.target.closest
        ? event.target.closest(".rhc-tooltip-anchor")
        : null;
    if (!anchor) {
      return;
    }
    const movingTo = event.relatedTarget;
    if (movingTo && anchor.contains(movingTo)) {
      return;
    }
    anchor.classList.remove("rhc-tooltip-anchor--flip-up");
  };

  // Decide open direction for the hovered/focused tooltip anchor. Flips upward only
  // when the space below the anchor is tight AND there is more room above, so the
  // default (downward, matching the rule rows) is preserved everywhere it fits.
  _positionTooltip = (event) => {
    const target = event.target;
    const anchor =
      target && target.closest ? target.closest(".rhc-tooltip-anchor") : null;
    if (!anchor) {
      return;
    }
    const rect = anchor.getBoundingClientRect();
    const viewportHeight =
      window.innerHeight || document.documentElement.clientHeight || 0;
    const spaceBelow = viewportHeight - rect.bottom;
    const spaceAbove = rect.top;
    // Roomy enough for the multi-line summary/rule bubbles; below this we flip.
    const flipUp =
      spaceBelow < ESTIMATED_TOOLTIP_HEIGHT && spaceAbove > spaceBelow;
    anchor.classList.toggle("rhc-tooltip-anchor--flip-up", flipUp);
  };

  _findTooltipAnchor(event) {
    const target = event.target;
    return target && target.closest
      ? target.closest(".rhc-tooltip-anchor")
      : null;
  }

  _isTooltipAnchorExit(event, anchor) {
    const movingTo = event.relatedTarget;
    return !(movingTo && anchor.contains(movingTo));
  }

  _tooltipHoverDwellMs() {
    if (
      typeof window !== "undefined" &&
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      return 0;
    }
    return TOOLTIP_HOVER_DWELL_MS;
  }

  _clearTooltipDwell(anchor) {
    const timer = this._tooltipDwellTimers.get(anchor);
    if (timer != null) {
      clearTimeout(timer);
      this._tooltipDwellTimers.delete(anchor);
    }
    this._pendingTooltipAnchors.delete(anchor);
    anchor.classList.remove("rhc-tooltip-anchor--dwell");
  }

  _clearAllTooltipDwells() {
    for (const anchor of this._pendingTooltipAnchors) {
      this._clearTooltipDwell(anchor);
    }
    this._pendingTooltipAnchors.clear();
  }

  _scheduleTooltipDwell(anchor, delayMs) {
    this._clearTooltipDwell(anchor);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    const timer = setTimeout(() => {
      this._tooltipDwellTimers.delete(anchor);
      this._pendingTooltipAnchors.delete(anchor);
      anchor.classList.add("rhc-tooltip-anchor--dwell");
    }, delayMs);
    this._tooltipDwellTimers.set(anchor, timer);
    this._pendingTooltipAnchors.add(anchor);
  }

  _handleTooltipMouseOver = (event) => {
    const anchor = this._findTooltipAnchor(event);
    if (!anchor) {
      return;
    }
    const from = event.relatedTarget;
    if (from && anchor.contains(from)) {
      return;
    }
    if (this._tooltipDwellTimers.has(anchor)) {
      return;
    }
    this._scheduleTooltipDwell(anchor, this._tooltipHoverDwellMs());
  };

  _handleTooltipMouseOut = (event) => {
    const anchor = this._findTooltipAnchor(event);
    if (!anchor || !this._isTooltipAnchorExit(event, anchor)) {
      return;
    }
    this._clearTooltipDwell(anchor);
  };

  _handleTooltipFocusOut = (event) => {
    const anchor = this._findTooltipAnchor(event);
    if (!anchor || !this._isTooltipAnchorExit(event, anchor)) {
      return;
    }
    this._clearTooltipDwell(anchor);
  };

  async _loadDefinitions() {
    const loadToken = ++this._loadToken;
    const requestedCheckSetName = this.checkSetName;
    const requestedRecordId = this.recordId;
    if (this._initialLoadFrame) {
      cancelAnimationFrame(this._initialLoadFrame);
      this._initialLoadFrame = null;
    }
    // Invalidate any run still in flight from a previously-viewed record. This
    // method is the entry point for both the first load AND the in-place record
    // swap (console navigation / dynamic record pages), so without this reset a
    // stale evaluateCheck result from record A could drain into record B's rows
    // (the run token guards stale results, and B reuses A's developerName keys),
    // and a leftover in-progress run would suppress B's Automatic run entirely.
    this._runner.invalidate();
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
    this.completedCheckCount = 0;
    this.checks = [];
    // Per-row expand state belongs to the previous record's rows; clear it so a
    // new record starts from the placement default rather than inheriting stale
    // carets keyed by reused developerNames.
    this._expandedNames = {};

    this.isLoading = true;
    this.componentError = null;
    this.componentErrorCode = null;

    if (!this.checkSetName || !this.checkSetName.trim()) {
      await this._applyBlankCheckSetSetupError(loadToken, requestedRecordId);
      return;
    }

    const runId = this._runner.beginRunId();

    try {
      const response = await getCheckDefinitions({
        checkSetQualifiedApiName: requestedCheckSetName,
        recordId: requestedRecordId,
        runId
      });

      if (loadToken !== this._loadToken || !this._connected) return;
      if (!response || !Array.isArray(response.checks)) {
        throw new Error(
          "The server returned an invalid health-check definition response."
        );
      }

      const seenNames = new Set();
      for (const def of response.checks) {
        if (!def || !def.developerName) {
          throw new Error(
            "A health-check definition is missing its developer name."
          );
        }
        if (!def.qualifiedApiName) {
          throw new Error(
            "A health-check definition is missing its qualified API name."
          );
        }
        if (seenNames.has(def.developerName)) {
          throw new Error(
            `Duplicate health-check developer name: ${def.developerName}.`
          );
        }
        seenNames.add(def.developerName);
      }

      this.displayTitle = response.displayTitle;
      this.displayDescription = response.displayDescription;
      this._requireMode(
        response.triggerMode,
        ["Automatic", "Manual"],
        "When Checks Run"
      );
      this._requireMode(
        response.revealMode,
        ["OneAtATime", "AllAtOnce"],
        "Reveal Mode"
      );
      this._requireMode(
        response.successDisplayMode,
        ["Show", "Hide"],
        "Passed Checks Display"
      );
      this._requireMode(
        response.skippedDisplayMode,
        ["Show", "Hide"],
        "Skipped Checks Display"
      );
      this._requireMode(
        response.comparisonDisplay,
        ["OnDemand", "FailuresOnly", "AllRows"],
        "Found/Expected Display"
      );
      this.triggerMode = response.triggerMode;
      this.revealMode = response.revealMode;
      this.successDisplayMode = response.successDisplayMode;
      this.skippedDisplayMode = response.skippedDisplayMode;
      this.comparisonDisplay = response.comparisonDisplay;
      this.stopOnFirstError = response.stopOnFirstError;
      this.showDiagnostics = response.showDiagnostics === true;
      this.totalCheckCount = response.checks.length;
      this.totalAvailableCheckCount =
        typeof response.totalAvailableCheckCount === "number"
          ? response.totalAvailableCheckCount
          : response.checks.length;
      this.frameworkMaxChecks =
        typeof response.frameworkMaxChecks === "number"
          ? response.frameworkMaxChecks
          : 25;
      this.inactiveRuleCount =
        typeof response.inactiveRuleCount === "number"
          ? response.inactiveRuleCount
          : 0;
      // Names arrive only for the diagnostics audience; without them the pill
      // still renders, just without a hover list.
      this.inactiveRuleLabels = Array.isArray(response.inactiveRuleLabels)
        ? response.inactiveRuleLabels.filter((name) => !!name)
        : [];
      this.checksOmittedByLimit = response.checksOmittedByLimit || false;

      // Build per-check rows — all start PENDING
      this.checks = response.checks.map((def) => ({
        developerName: def.developerName,
        qualifiedApiName: def.qualifiedApiName,
        label: def.label,
        description: def.description,
        category: def.category || null,
        categoryLabel: def.categoryLabel || null,
        priority: def.priority,
        dependsOnRuleDeveloperName: def.dependsOnRuleDeveloperName || null,
        uiState: "PENDING",
        result: null
      }));

      this.isLoading = false;
      this.componentError = null;
      this.componentErrorCode = null;

      if (this.triggerMode === "Automatic") {
        this._runner.run(true, "RUN_ON_LOAD");
      }
    } catch (err) {
      if (loadToken !== this._loadToken || !this._connected) return;
      this.isLoading = false;
      const parsed = parseAuraError(err);
      this.componentError = parsed.message;
      this.componentErrorCode = parsed.reasonCode;
      this.componentErrorDiagnosticCode = parsed.diagnosticCode;
    }
  }

  get hasComponentError() {
    return !!this.componentError;
  }

  /**
   * Blank checkSetName is ambiguous until we ask Apex what Check Sets exist for
   * this object. Active sets → SETUP_REQUIRED (pick one). Inactive only →
   * INACTIVE_CHECK_SETS_ONLY. None at all → NO_ACTIVE_CHECK_SETS. Lookup failures
   * A lookup failure remains a distinct retriable system error so an Apex or
   * network problem is never mislabeled as missing configuration.
   */
  async _applyBlankCheckSetSetupError(loadToken, requestedRecordId) {
    let availability = { hasActive: true, hasInactive: false };
    if (requestedRecordId) {
      try {
        const response = await getCheckSetAvailabilityForRecord({
          recordId: requestedRecordId
        });
        availability = {
          hasActive: response?.hasActive === true,
          hasInactive: response?.hasInactive === true
        };
      } catch (error) {
        if (loadToken !== this._loadToken || !this._connected) return;
        const parsed = parseAuraError(error);
        this.isLoading = false;
        this.componentError =
          "Record Health Check could not verify its setup. Please try again.";
        this.componentErrorCode = "AVAILABILITY_LOOKUP_FAILED";
        this.componentErrorDiagnosticCode = parsed.diagnosticCode;
        return;
      }
    }
    if (loadToken !== this._loadToken || !this._connected) {
      return;
    }
    this.isLoading = false;
    if (availability.hasActive) {
      this.componentError =
        "Record Health Check is not ready on this page yet.";
      this.componentErrorCode = "SETUP_REQUIRED";
      return;
    }
    if (availability.hasInactive) {
      this.componentError =
        "Record Health Check is not ready on this page yet.";
      this.componentErrorCode = "INACTIVE_CHECK_SETS_ONLY";
      return;
    }
    this.componentError = "Record Health Check is not ready on this page yet.";
    this.componentErrorCode = "NO_ACTIVE_CHECK_SETS";
  }

  _requireMode(value, allowed, label) {
    if (!allowed.includes(value)) {
      throw Object.assign(
        new Error(`${label} has an invalid configured value.`),
        {
          reasonCode: "INVALID_CONFIG"
        }
      );
    }
  }

  _handleCompletionFailure(error) {
    const parsed = parseAuraError(error);
    this.componentError =
      "The checks finished, but the run could not be completed. Please try again.";
    this.componentErrorCode = "RUN_COMPLETION_FAILED";
    this.componentErrorDiagnosticCode = parsed.diagnosticCode;
  }

  get isSetupError() {
    return SETUP_ERROR_CODES.has(this.componentErrorCode);
  }

  get errorBannerIcon() {
    return this.isSetupError ? "utility:setup" : "utility:error";
  }

  get errorBannerIconAltText() {
    return this.isSetupError ? "Setup required" : "Error";
  }

  get errorBannerTitle() {
    return this.isSetupError
      ? "Health Check Needs Setup"
      : "Health Check Unavailable";
  }

  get setupErrorHint() {
    return setupErrorHint(this.componentErrorCode);
  }

  get showRunButton() {
    // Stays rendered while a run is in progress (disabled + spinner; label stays
    // Run or Rerun per hasCompletedRunOnce — see actionButtonLabel).
    return this.triggerMode === "Manual" && !this.runComplete;
  }

  get showRerunButton() {
    return this.runComplete;
  }

  get isAllAtOnce() {
    return this.revealMode === "AllAtOnce";
  }

  get visibleChecks() {
    const signature = JSON.stringify([
      this.revealMode,
      this.successDisplayMode,
      this.skippedDisplayMode,
      this.showDiagnostics,
      this.comparisonDisplay,
      this._expandedNames,
      this._runner.isRunning
    ]);
    if (
      this._visibleChecksSource === this.checks &&
      this._visibleChecksSignature === signature
    ) {
      return this._visibleChecksCache;
    }
    let filtered;
    if (this.isAllAtOnce) {
      filtered = this.checks.filter((c) => {
        if (this._isHiddenSkipped(c)) {
          return false;
        }
        if (this._isHiddenSuccess(c)) {
          return false;
        }
        return true;
      });
    } else {
      // OneAtATime: reveal every resolved (non-hidden) row as soon as it lands
      const nextPending = this.checks.find((c) => c.uiState !== "RESOLVED");
      const revealName = nextPending ? nextPending.developerName : null;
      filtered = this.checks.filter((c) => {
        if (c.uiState === "RESOLVED") {
          if (this._isHiddenSkipped(c)) {
            return false;
          }
          if (this._isHiddenSuccess(c)) {
            return false;
          }
          return true;
        }
        return (
          (c.uiState === "LOADING" ||
            (c.uiState === "PENDING" && this._runner.isRunning)) &&
          c.developerName === revealName
        );
      });
    }
    // Annotate each check with computed display properties for the template
    this._visibleChecksSource = this.checks;
    this._visibleChecksSignature = signature;
    this._visibleChecksCache = filtered.map((c) =>
      annotateCheck(
        c,
        this.showDiagnostics,
        this.comparisonDisplay,
        this._isRowExpanded(c.developerName)
      )
    );
    return this._visibleChecksCache;
  }

  // Whether a row's comparison detail is currently expanded. Carets default to
  // collapsed; a user toggle records an explicit state in _expandedNames.
  _isRowExpanded(developerName) {
    if (
      Object.prototype.hasOwnProperty.call(this._expandedNames, developerName)
    ) {
      return this._expandedNames[developerName];
    }
    return false;
  }

  handleToggleDetail(event) {
    const developerName = event.currentTarget.dataset.check;
    const next = !this._isRowExpanded(developerName);
    // Reassign (not mutate) so the tracked field change re-runs visibleChecks.
    this._expandedNames = {
      ...this._expandedNames,
      [developerName]: next
    };
  }

  // Found/Expected values, user messages, fix guidance, and diagnostic detail
  // share one four-line disclosure interaction. This layout pass decides only
  // whether the control is necessary.
  _measureClampedContent() {
    const regions = this.template.querySelectorAll("[data-clampcontent]");
    for (const content of regions) {
      const container = content.closest("[data-expandable]");
      /* istanbul ignore next -- guards DOM detachment between query and measurement */
      if (!container) {
        continue;
      }
      const toggle = container.querySelector("[data-clamptoggle]");
      /* istanbul ignore next -- template invariant during normal rendering */
      if (!toggle) {
        continue;
      }
      if (content.classList.contains("rhc-expandable__content--expanded")) {
        continue;
      }
      const overflowing = content.scrollHeight - content.clientHeight > 1;
      toggle.hidden = !overflowing;
    }
  }

  // Resizing a Lightning region can change wrapping without causing an LWC
  // render. Re-measure explicitly so a newly overflowing value gains its +/-
  // affordance (and a value that now fits loses it) immediately.
  _handleViewportResize = () => {
    if (this._resizeFrame) {
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._resizeFrame = requestAnimationFrame(() => {
      this._resizeFrame = null;
      this._measureClampedContent();
    });
  };

  // Expand or re-clamp one content region in place. Imperative state is kept
  // local to the rendered region, matching the established value-chip behavior.
  handleToggleContent(event) {
    const toggle = event.currentTarget;
    const container = toggle.closest("[data-expandable]");
    /* istanbul ignore next -- click target can detach during rerender */
    if (!container) {
      return;
    }
    const content = container.querySelector("[data-clampcontent]");
    /* istanbul ignore next -- template invariant during normal rendering */
    if (!content) {
      return;
    }
    const expanded = content.classList.toggle(
      "rhc-expandable__content--expanded"
    );
    const label = toggle.dataset.expandLabel || "content";
    toggle.dataset.symbol = expanded ? "−" : "+";
    toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
    toggle.setAttribute(
      "aria-label",
      `${expanded ? "Collapse" : "Expand"} ${label}`
    );
  }

  get checkCountLabel() {
    const n = this.totalCheckCount;
    return `${n} ${n === 1 ? "Check" : "Checks"}`;
  }

  // Count phrase for the pre-run hint: pluralized, and when the set exceeds the
  // 25-rule cap it makes clear only the first 25 will run (matching the
  // limit badge).
  get checkCountPhrase() {
    if (this.checksOmittedByLimit) {
      return `the first ${this.frameworkMaxChecks} of ${this.totalAvailableCheckCount} checks`;
    }
    const n = this.totalCheckCount;
    return `${n} ${n === 1 ? "check" : "checks"}`;
  }

  get limitNoticeLabel() {
    return `First ${this.frameworkMaxChecks} of ${this.totalAvailableCheckCount} shown`;
  }

  get limitNoticeTitle() {
    return `Showing the first ${this.frameworkMaxChecks} of ${this.totalAvailableCheckCount} active rules.`;
  }

  get showActionButton() {
    return this.showRunButton || this.showRerunButton;
  }

  get showPreRunHint() {
    // Shown before the first Manual run in BOTH reveal modes for a consistent
    // call to action: OneAtATime shows the hint alone (no rows yet),
    // AllAtOnce shows it above the already-listed rows.
    return (
      this.triggerMode === "Manual" &&
      !this.isLoading &&
      !this.runComplete &&
      !this._runner.isRunning &&
      this.checks.length > 0
    );
  }

  get preRunHintText() {
    return `Click Run to evaluate ${this.checkCountPhrase}.`;
  }

  get showSummaryStats() {
    return this.runComplete && this.summaryGroups.length > 0;
  }

  /**
   * When Passed/Skipped display is Hide and every resolved row is filtered out,
   * the list looks empty even though the run succeeded. Surface a short status
   * so the card does not appear broken beside the summary pills.
   */
  get showHiddenResultsNotice() {
    return (
      this.runComplete &&
      !this.isLoading &&
      this.checks.length > 0 &&
      this.visibleChecks.length === 0
    );
  }

  get hiddenResultsNotice() {
    const hiddenPasses = this.checks.some((c) => this._isHiddenSuccess(c));
    const hiddenSkips = this.checks.some((c) => this._isHiddenSkipped(c));
    if (hiddenPasses && hiddenSkips) {
      return "All checks passed or were skipped. Details are hidden.";
    }
    if (hiddenPasses) {
      return "All checks passed. Details are hidden.";
    }
    return "All checks were skipped. Details are hidden.";
  }

  get actionTitle() {
    // Check count lives in the hover tooltip; while a run is in flight the title
    // carries the busy state because the visible label stays "Run" / "Rerun".
    if (this._runner.isRunning) {
      return this.hasCompletedRunOnce
        ? `Re-running ${this.checkCountLabel}`
        : `Running ${this.checkCountLabel}`;
    }
    return this.hasCompletedRunOnce
      ? `Re-run ${this.checkCountLabel}`
      : `Run ${this.checkCountLabel}`;
  }

  get actionButtonLabel() {
    return this.hasCompletedRunOnce ? "Rerun" : "Run";
  }

  get actionButtonAriaLabel() {
    if (this._runner.isRunning) {
      return this.actionTitle;
    }
    return this.actionButtonLabel;
  }

  get actionButtonBusy() {
    return this._runner.isRunning;
  }

  // While a run is in flight the button stays put but is disabled, so it reads
  // as busy instead of vanishing.
  get actionButtonDisabled() {
    return this._runner.isRunning;
  }

  handleAction() {
    // A Rerun starts a fresh evaluation, so per-row carets the user opened on the
    // previous run should collapse back to the placement default rather than
    // linger open over rows whose values are being recomputed.
    this._expandedNames = {};
    this._runner.run(false, "USER_INITIATED");
  }

  get summaryGroups() {
    const tooltipKeys = this._summaryTooltipKeys();
    const tooltipSignature = tooltipKeys.join("|");
    const inactiveStat = this._inactiveRuleStat();
    const inactiveSignature = inactiveStat
      ? `${inactiveStat.label}|${inactiveStat.tooltip}`
      : "";
    if (
      this._summaryStatsSource !== this.checks ||
      this._summaryStatsTooltipSignature !== tooltipSignature ||
      this._inactiveStatSignature !== inactiveSignature
    ) {
      this._summaryStatsSource = this.checks;
      this._summaryStatsTooltipSignature = tooltipSignature;
      this._inactiveStatSignature = inactiveSignature;
      const groups = buildSummaryGroups(this.checks, new Set(tooltipKeys));
      if (inactiveStat) {
        const uncategorized = groups.find(
          (group) => group.key === "uncategorized" || group.key === "all"
        );
        if (uncategorized) {
          uncategorized.stats = [inactiveStat, ...uncategorized.stats];
        } else {
          groups.push({
            key: "uncategorized",
            label: "Other",
            assistiveLabel: null,
            cssClass: "rhc-stats-group rhc-stats-group--labeled",
            stats: [inactiveStat]
          });
        }
      }
      this._summaryStatsCache = groups;
    }
    return this._summaryStatsCache;
  }

  get summaryStats() {
    return this.summaryGroups.flatMap((group) => group.stats);
  }

  /**
   * Inactive rules are configuration housekeeping a regular user cannot act on,
   * so the count no longer sits in the card header. Under diagnostics it leads
   * the stats bar as a neutral pill whose hover lists the omitted rule names,
   * matching how the Passed/Skipped pills reveal their rows.
   */
  _inactiveRuleStat() {
    return buildInactiveRuleStat(
      this.showDiagnostics,
      this.inactiveRuleCount,
      this.inactiveRuleLabels
    );
  }

  get showLimitNotice() {
    return this.checksOmittedByLimit;
  }

  _isSkipped(check) {
    return (
      check &&
      check.uiState === "RESOLVED" &&
      check.result &&
      check.result.status === "SKIPPED"
    );
  }

  // Diagnostics is an authorized troubleshooting overlay: when active it auto-
  // expands every check, overriding count-only display, so an admin can see the
  // rows a count-only summary hides. showDiagnostics is already gated server-side
  // (Set flag AND the diagnostics permission), so normal users are unaffected.
  _isHiddenSkipped(check) {
    if (this.showDiagnostics) return false;
    return this._isSkipped(check) && this.skippedDisplayMode === "Hide";
  }

  _isSuccess(check) {
    return (
      check &&
      check.uiState === "RESOLVED" &&
      check.result &&
      check.result.status === "PASS"
    );
  }

  _isHiddenSuccess(check) {
    if (this.showDiagnostics) return false; // auto-expand under diagnostics
    return this._isSuccess(check) && this.successDisplayMode === "Hide";
  }

  _summaryTooltipKeys() {
    const keys = [];
    if (this.checks.some((c) => this._isHiddenSuccess(c))) {
      keys.push("pass");
    }
    if (this.checks.some((c) => this._isHiddenSkipped(c))) {
      keys.push("skip");
    }
    return keys;
  }

  get showDiagnosticsConsoleHint() {
    return this.showDiagnostics && this.runComplete;
  }

  _buildRunDiagnostics() {
    return {
      runId: this._runner.runId,
      userId: USER_ID,
      recordId: this.recordId,
      checkSetQualifiedApiName: this.checkSetName,
      generatedAt: new Date().toISOString(),
      checks: this.checks.map((c) => {
        const r = c.result || {};
        return {
          check: c.developerName,
          label: c.label || c.developerName,
          status: r.status || c.uiState,
          severity: r.severity || null,
          reasonCode: r.reasonCode || null,
          actualValue: r.actualValue ?? null,
          expectedValue: r.expectedValue ?? null,
          actualValueDetail: r.actualValueDetail ?? null,
          expectedValueDetail: r.expectedValueDetail ?? null,
          durationMs: r.durationMs != null ? r.durationMs : null,
          evaluatorType:
            r.evaluatorType ??
            parseDiagnosticJson(r.adminDetail?.configurationJson)
              .evaluationType ??
            null,
          message: r.message ?? null,
          fixInstructions: r.fixInstructions ?? null,
          actionLabel: r.actionLabel ?? null,
          actionUrl: r.actionUrl ?? null,
          adminMessage: r.adminDetail?.message ?? null,
          containsRestrictedDetail:
            r.adminDetail?.containsRestrictedDetail === true,
          configuration: parseDiagnosticJson(r.adminDetail?.configurationJson),
          resolution: parseDiagnosticJson(r.adminDetail?.resolutionJson),
          rawResult: r
        };
      })
    };
  }

  _formatRunSummary(checks) {
    return formatRunSummary(checks);
  }

  _logRunDiagnostics() {
    const diag = this._buildRunDiagnostics();
    const configLabel =
      diag.checkSetQualifiedApiName || "(unset checkSetQualifiedApiName)";
    console.group(
      `[RHC] Health Check run ${diag.runId} | ${configLabel} | record ${diag.recordId}`
    );
    console.log(this._formatRunSummary(diag.checks));
    console.log({
      runId: diag.runId,
      checkSet: diag.checkSetQualifiedApiName,
      recordId: diag.recordId,
      userId: diag.userId,
      generatedAt: diag.generatedAt
    });
    console.table(diag.checks, RHC_DIAG_TABLE_COLUMNS);
    this._logCheckDiagnostics(diag.checks);
    console.log("Complete copyable report", JSON.parse(JSON.stringify(diag)));
    console.log("Copy as JSON", JSON.stringify(diag, null, 2));
    console.groupEnd();
  }

  _logCheckDiagnostics(checks) {
    console.group(`[RHC] Full check details (${checks.length})`);
    for (const [index, c] of checks.entries()) {
      const heading = `${index + 1}. ${c.label} (${c.check}) · ${c.status}`;
      console.groupCollapsed(heading);
      console.log("Identity and outcome", {
        qualifiedApiName: c.rawResult?.ruleDeveloperName || c.check,
        evaluatorType: c.evaluatorType,
        status: c.status,
        severity: c.severity,
        reasonCode: c.reasonCode,
        durationMs: c.durationMs
      });
      console.log("Rule configuration", c.configuration);
      console.log("Resolved evaluation", c.resolution);
      console.log("Rendered output", {
        message: c.message,
        found: c.actualValue,
        expected: c.expectedValue,
        foundSource: c.actualValueDetail,
        expectedSource: c.expectedValueDetail,
        fixInstructions: c.fixInstructions,
        actionLabel: c.actionLabel,
        actionUrl: c.actionUrl
      });
      if (c.adminMessage != null) {
        console.warn("Server diagnostic", c.adminMessage);
      }
      if (c.containsRestrictedDetail) {
        console.warn("This check contains restricted diagnostic detail.");
      }
      console.log("Raw normalized result", c.rawResult);
      if (c.actualValueDetail != null) {
        console.log("Found", c.actualValueDetail);
      }
      if (c.expectedValueDetail != null) {
        console.log("Expected", c.expectedValueDetail);
      }
      console.groupEnd();
    }
    console.groupEnd();
  }
}
