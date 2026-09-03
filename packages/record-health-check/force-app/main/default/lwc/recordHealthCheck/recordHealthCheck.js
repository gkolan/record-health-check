/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

import { LightningElement, api, track } from "lwc";
import {
  registerRefreshHandler,
  unregisterRefreshHandler
} from "lightning/refresh";
import themeStyles from "./recordHealthCheckTheme.css";
import USER_ID from "@salesforce/user/Id";
import getCheckSetShellConfig from "@salesforce/apex/RecordHealthCheckController.getCheckSetShellConfig";
import getCheckDefinitions from "@salesforce/apex/RecordHealthCheckController.getCheckDefinitions";
import getCheckSetAvailabilityForRecord from "@salesforce/apex/RecordHealthCheckController.getCheckSetAvailabilityForRecord";
import evaluateCheck from "@salesforce/apex/RecordHealthCheckController.evaluateCheck";
import completeRun from "@salesforce/apex/RecordHealthCheckController.completeRun";
import {
  checkIdentity,
  checkNamespace,
  parseAuraError
} from "./healthCheckModel";
import { annotateCheck, buildSummaryGroups } from "./healthCheckPresentation";
import { HealthCheckRunner } from "./healthCheckRunner";
import {
  buildInactiveCheckStat,
  componentErrorPresentation,
  diagnosticNextSteps,
  formatRunSummary,
  parseDiagnosticJson,
  safeIncidentReport,
  setupErrorHint,
  supportCheckDiagnosticsReport
} from "./healthCheckDiagnostics";

// Pointer hover waits before the tooltip fades in so quick row scans do not flash
// popovers. Keyboard focus keeps a shorter CSS dwell (see recordHealthCheck.css).
const TOOLTIP_HOVER_DWELL_MS = 1000;
const RECORD_REFRESH_DEBOUNCE_MS = 250;
const ESTIMATED_TOOLTIP_HEIGHT = 180;
const DEFAULT_RUN_BUTTON_DISPLAY = "LABEL_AND_ICON";
const RUN_BUTTON_DISPLAYS = [
  "LABEL_AND_ICON",
  "LABEL_ONLY",
  "ICON_ONLY",
  "HIDE"
];
const SLDS_ICON_NAME = /^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$/;

function isLightningAppBuilderContext() {
  try {
    return window.location.pathname.includes("/flexipageEditor/");
  } catch {
    // If a container blocks location access, retain normal record-page behavior.
    return false;
  }
}

function emptyExpandedState() {
  return Object.create(null);
}

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

export default class RecordHealthCheck extends LightningElement {
  static stylesheets = [themeStyles];

  _checkSetName;

  get themeClass() {
    return "rhc-theme";
  }

  @api
  get checkSetName() {
    return this._checkSetName;
  }
  set checkSetName(value) {
    const changed = value !== this._checkSetName;
    this._checkSetName = value;
    if (this._connected && changed) {
      this._restartConfiguredLifecycle(true);
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
    // the first load is owned by connectedCallback so it can wait for page idle.
    if (this._connected && changed) {
      this._restartConfiguredLifecycle();
    }
  }

  @track displayTitle = "Record Health Check";
  @track displayDescription;
  @track triggerMode;
  @track checkSetRunButtonDisplay = DEFAULT_RUN_BUTTON_DISPLAY;
  @track runButtonLabel;
  @track rerunButtonLabel;
  @track runButtonIcon;
  @track revealMode;
  @track successDisplayMode;
  @track skippedDisplayMode;
  @track summaryDisplay = "BOTTOM";
  @track comparisonDisplay = "OnDemand";
  @track stopOnFirstError;
  @track showDiagnostics = false;
  @track totalCheckCount = 0;
  @track totalAvailableCheckCount = 0;
  @track frameworkMaxChecks = 25;
  @track inactiveCheckCount = 0;
  @track inactiveCheckLabels = [];
  @track isBuilderPreview = false;
  @track builderCountsAvailable = false;
  @track completedCheckCount = 0;
  @track runComplete = false;
  /** Stays true after the first completed run until definitions reload — drives
   *  the Run/Rerun label while a subsequent run is in flight (runComplete is
   *  false during that window). */
  @track hasCompletedRunOnce = false;
  @track componentError = null; // safe user-facing message
  @track componentErrorCode = null;
  @track componentErrorDiagnosticCode = null;
  @track componentErrorTitle = null;
  @track componentErrorGuidance = null;
  @track componentErrorTechnicalDetail = null;
  @track componentErrorRetryable = false;
  @track completionWarning = null;
  @track completionWarningDiagnosticCode = null;
  @track checksOmittedByLimit = false;
  // The record-page shell must paint without a component loading indicator.
  // Automatic work starts only after browser idle; row-level progress appears
  // once checks are actually evaluating.
  @track isLoading = false;

  @track checks = [];

  // Per-row disclosure overrides, keyed by qualifiedApiName. Absent → the row
  // starts collapsed (the default). Reassigned on toggle so
  // the visibleChecks getter re-annotates. Lives outside `checks` because the
  // runner rebuilds that array on every result; expand state must survive that.
  @track _expandedNames = emptyExpandedState();

  // Run orchestration (result buffer, reveal pointer, concurrency pool, run id,
  // and the run token that discards stale in-flight results) lives in the runner;
  // the component owns lifecycle, definition loading, display, and diagnostics.
  _runner = new HealthCheckRunner(this, { evaluateCheck, completeRun });
  _loadToken = 0;
  _cancelInitialLoad = null;
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
  _cancelAutomaticRun = null;
  _definitionLoadInProgress = false;
  _canViewDetails = false;
  _refreshHandlerRegistration = null;
  _recordRefreshTimer = null;

  _clearComponentError() {
    this.componentError = null;
    this.componentErrorCode = null;
    this.componentErrorDiagnosticCode = null;
    this.componentErrorTitle = null;
    this.componentErrorGuidance = null;
    this.componentErrorTechnicalDetail = null;
    this.componentErrorRetryable = false;
  }

  _setComponentError(reasonCode, technicalMessage, diagnosticCode = null) {
    const presentation = componentErrorPresentation(
      reasonCode,
      technicalMessage,
      this._canViewDetails === true,
      diagnosticCode
    );
    this.componentError = presentation.message;
    this.componentErrorCode = presentation.reasonCode;
    this.componentErrorDiagnosticCode = presentation.diagnosticCode;
    this.componentErrorTitle = presentation.title;
    this.componentErrorGuidance = presentation.guidance;
    this.componentErrorTechnicalDetail = presentation.technicalDetail;
    this.componentErrorRetryable = presentation.retryable;
  }

  connectedCallback() {
    this._connected = true;
    window.addEventListener("resize", this._handleViewportResize);
    this._registerRefreshViewHandler();
    this._restartConfiguredLifecycle(true, true);
  }

  _registerRefreshViewHandler() {
    try {
      // Lightning Web Security registration protocol.
      this._refreshHandlerRegistration = registerRefreshHandler(
        this,
        this._handleRefreshView
      );
    } catch {
      try {
        // Lightning Locker requires the rendered host HTMLElement and an
        // explicitly-bound callback instead of the LightningElement instance.
        this._refreshHandlerRegistration = registerRefreshHandler(
          this.template.host,
          this._handleRefreshView.bind(this)
        );
      } catch {
        // RefreshView is progressive enhancement. A registration failure must
        // never prevent the health-check card itself from connecting.
        this._refreshHandlerRegistration = null;
      }
    }
  }

  _restartConfiguredLifecycle(
    resolveRunMode = false,
    deferInitialLoad = false
  ) {
    const loadToken = ++this._loadToken;
    this._cancelScheduledInitialLoad();
    this._cancelScheduledRecordRefresh();
    this._cancelScheduledAutomaticRun();
    this._runner.invalidate();
    this._definitionLoadInProgress = false;

    // Current Lightning App Builder versions can supply a sample recordId to
    // record-page previews. Detect the supported Builder container itself so
    // the preview loads only shell metadata, never definitions or evaluations.
    if (isLightningAppBuilderContext()) {
      this._loadBuilderPreview(loadToken);
      return;
    }

    if (!resolveRunMode && this.triggerMode === "Manual") {
      this._prepareQuietManualShell({
        cardTitle: this.displayTitle,
        cardDescription: this.displayDescription,
        activeCheckCount: this.totalAvailableCheckCount,
        runButtonDisplay: this.checkSetRunButtonDisplay,
        runButtonLabel: this.runButtonLabel,
        rerunButtonLabel: this.rerunButtonLabel,
        runButtonIcon: this.runButtonIcon
      });
      return;
    }
    if (!resolveRunMode && this.triggerMode === "Automatic") {
      this._prepareDeferredAutomaticShell({
        cardTitle: this.displayTitle,
        cardDescription: this.displayDescription,
        activeCheckCount: this.totalAvailableCheckCount,
        runButtonDisplay: this.checkSetRunButtonDisplay,
        runButtonLabel: this.runButtonLabel,
        rerunButtonLabel: this.rerunButtonLabel,
        runButtonIcon: this.runButtonIcon
      });
      this._scheduleAutomaticLoad();
      return;
    }

    if (deferInitialLoad) {
      // Do not enqueue Apex while the Lightning record page is still painting.
      // This keeps both the Salesforce page-level busy treatment and RHC's own
      // evaluation progress out of the initial page-load experience.
      this._cancelInitialLoad = this._scheduleIdleWork(() => {
        this._cancelInitialLoad = null;
        this._resolveConfiguredLifecycle(loadToken, this.checkSetName);
      });
      return;
    }
    this._resolveConfiguredLifecycle(loadToken, this.checkSetName);
  }

  async _resolveConfiguredLifecycle(loadToken, checkSetName) {
    // App Builder can supply a sample recordId. Its preview uses only the
    // lightweight Check Set shell; definitions and evaluation remain runtime-only.
    if (isLightningAppBuilderContext()) {
      this._loadBuilderPreview(loadToken);
      return;
    }
    if (!this.recordId) {
      this._prepareNoRecordShell();
      return;
    }
    let shellConfig = null;
    try {
      shellConfig = await getCheckSetShellConfig({
        checkSetQualifiedApiName: checkSetName
      });
    } catch {
      // The definition load owns user-facing configuration and access errors.
    }
    if (
      !this._connected ||
      loadToken !== this._loadToken ||
      checkSetName !== this.checkSetName
    ) {
      return;
    }
    if (
      shellConfig?.runMode === "Manual" &&
      shellConfig?.runButtonDisplay === "HIDE"
    ) {
      this._loadDefinitions();
      return;
    }
    if (shellConfig?.runMode === "Manual") {
      this._prepareQuietManualShell(shellConfig);
      return;
    }
    if (shellConfig?.runMode === "Automatic") {
      this._prepareDeferredAutomaticShell(shellConfig);
      this._scheduleAutomaticLoad();
      return;
    }
    this._loadDefinitions();
  }

  _prepareNoRecordShell() {
    this.isBuilderPreview = false;
    this.builderCountsAvailable = false;
    this.triggerMode = null;
    this.displayTitle = "Record Health Check";
    this.displayDescription = this.checkSetName
      ? "Runs when a record is available."
      : "Select a Check Set in the component properties.";
    this.isLoading = false;
    this._clearComponentError();
    this.checks = [];
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
  }

  async _loadBuilderPreview(loadToken) {
    const requestedCheckSetName = this.checkSetName;
    this.isBuilderPreview = true;
    this.builderCountsAvailable = false;
    this.triggerMode = null;
    this.displayTitle = requestedCheckSetName || "Record Health Check";
    this.displayDescription = requestedCheckSetName
      ? "Record Health Check"
      : null;
    this.isLoading = false;
    this._clearComponentError();
    this.checks = [];
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
    this.totalAvailableCheckCount = 0;
    this.totalCheckCount = 0;
    this.inactiveCheckCount = 0;

    if (!requestedCheckSetName) {
      return;
    }

    try {
      const shellConfig = await getCheckSetShellConfig({
        checkSetQualifiedApiName: requestedCheckSetName
      });
      if (
        !this._connected ||
        loadToken !== this._loadToken ||
        requestedCheckSetName !== this.checkSetName ||
        !isLightningAppBuilderContext()
      ) {
        return;
      }
      if (!shellConfig || Object.keys(shellConfig).length === 0) {
        return;
      }
      const activeCheckCount = Number(shellConfig.activeCheckCount) || 0;
      this.displayTitle =
        shellConfig.checkSetLabel ||
        shellConfig.cardTitle ||
        requestedCheckSetName;
      this.totalAvailableCheckCount = activeCheckCount;
      this.totalCheckCount = Math.min(
        activeCheckCount,
        this.frameworkMaxChecks
      );
      this.inactiveCheckCount = Number(shellConfig.inactiveCheckCount) || 0;
      this.builderCountsAvailable = true;
    } catch {
      // Keep the selected identity and local guidance visible if Builder cannot
      // load its optional metadata summary. Runtime error handling is unchanged.
    }
  }

  _prepareQuietManualShell(shellConfig = {}) {
    this.isBuilderPreview = false;
    this.builderCountsAvailable = false;
    this.triggerMode = "Manual";
    this._prepareMetadataShell(shellConfig);
    this.isLoading = false;
    this._clearComponentError();
    this.completionWarning = null;
    this.completionWarningDiagnosticCode = null;
    this.checks = [];
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
  }

  _prepareDeferredAutomaticShell(shellConfig = {}) {
    this.isBuilderPreview = false;
    this.builderCountsAvailable = false;
    this.triggerMode = "Automatic";
    this._prepareMetadataShell(shellConfig);
    this.isLoading = false;
    this._clearComponentError();
    this.completionWarning = null;
    this.completionWarningDiagnosticCode = null;
    this.checks = [];
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
  }

  _prepareMetadataShell(shellConfig) {
    const activeCheckCount = Number(shellConfig.activeCheckCount) || 0;
    this.displayTitle =
      shellConfig.cardTitle || this.checkSetName || "Record Health Check";
    this.displayDescription = shellConfig.cardDescription || null;
    this.totalAvailableCheckCount = activeCheckCount;
    this.totalCheckCount = Math.min(activeCheckCount, this.frameworkMaxChecks);
    this.checksOmittedByLimit = activeCheckCount > this.frameworkMaxChecks;
    this.checkSetRunButtonDisplay = RUN_BUTTON_DISPLAYS.includes(
      shellConfig.runButtonDisplay
    )
      ? shellConfig.runButtonDisplay
      : DEFAULT_RUN_BUTTON_DISPLAY;
    this.runButtonLabel = shellConfig.runButtonLabel || null;
    this.rerunButtonLabel = shellConfig.rerunButtonLabel || null;
    this.runButtonIcon = shellConfig.runButtonIcon || null;
  }

  disconnectedCallback() {
    this._connected = false;
    window.removeEventListener("resize", this._handleViewportResize);
    if (this._refreshHandlerRegistration !== null) {
      unregisterRefreshHandler(this._refreshHandlerRegistration);
      this._refreshHandlerRegistration = null;
    }
    this._cancelScheduledRecordRefresh();
    if (this._resizeFrame) {
      cancelAnimationFrame(this._resizeFrame);
      this._resizeFrame = null;
    }
    this._loadToken++;
    this._cancelScheduledInitialLoad();
    this._cancelScheduledAutomaticRun();
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

  _handleRefreshView = () => {
    this._scheduleRecordRefresh();
    return Promise.resolve(true);
  };

  _shouldRefreshCurrentResults() {
    if (!this.checkSetName || !this.recordId) {
      return false;
    }
    if (this.triggerMode === "Automatic") {
      return true;
    }
    return (
      this.triggerMode === "Manual" &&
      (this.hasCompletedRunOnce ||
        this._runner.isRunning ||
        this._definitionLoadInProgress)
    );
  }

  _scheduleRecordRefresh() {
    this._cancelScheduledRecordRefresh();
    if (!this._shouldRefreshCurrentResults()) {
      return;
    }
    const checkSetName = this.checkSetName;
    const recordId = this.recordId;
    // RefreshView can notify several page participants for one save. Coalesce
    // the burst so this component performs at most one replacement run.
    // LWS safely virtualizes this component-owned coalescing timer.
    // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
    this._recordRefreshTimer = setTimeout(() => {
      this._recordRefreshTimer = null;
      if (
        !this._connected ||
        checkSetName !== this.checkSetName ||
        recordId !== this.recordId ||
        !this._shouldRefreshCurrentResults()
      ) {
        return;
      }
      // RUN_ON_LOAD is the existing non-publishing browser lifecycle source.
      // _loadDefinitions invalidates any older run before starting this one.
      this._loadDefinitions("RUN_ON_LOAD");
    }, RECORD_REFRESH_DEBOUNCE_MS);
  }

  _cancelScheduledRecordRefresh() {
    if (this._recordRefreshTimer !== null) {
      clearTimeout(this._recordRefreshTimer);
      this._recordRefreshTimer = null;
    }
  }

  renderedCallback() {
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
    // bubble, so one listener pair covers every check row and summary pill.
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
  // default (downward, matching the check rows) is preserved everywhere it fits.
  _positionTooltip = (event) => {
    const target = event.target;
    const anchor =
      target && target.closest ? target.closest(".rhc-tooltip-anchor") : null;
    if (!anchor) {
      return;
    }
    // anchor is an HTMLElement owned by this template, not a cross-boundary Range.
    // eslint-disable-next-line @locker/locker/distorted-range-get-bounding-client-rect
    const rect = anchor.getBoundingClientRect();
    const viewportHeight = window.innerHeight || 0;
    const spaceBelow = viewportHeight - rect.bottom;
    const spaceAbove = rect.top;
    // Roomy enough for the multi-line summary/check bubbles; below this we flip.
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
    // LWS safely virtualizes this component-owned dwell timer.
    // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
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

  async _loadDefinitions(runSource = null) {
    this._canViewDetails = false;
    const loadToken = ++this._loadToken;
    const requestedCheckSetName = this.checkSetName;
    const requestedRecordId = this.recordId;
    this._cancelScheduledInitialLoad();
    this._cancelScheduledRecordRefresh();
    this._cancelScheduledAutomaticRun();
    // Invalidate any run still in flight from a previously-viewed record. This
    // method is the entry point for both the first load AND the in-place record
    // swap (console navigation / dynamic record pages), so without this reset a
    // stale evaluateCheck result from record A could drain into record B's rows
    // (the run token guards stale results, and B reuses A's Check identities),
    // and a leftover in-progress run would suppress B's Automatic run entirely.
    this._runner.invalidate();
    this.runComplete = false;
    this.hasCompletedRunOnce = false;
    this.completedCheckCount = 0;
    this.checks = [];
    // Per-row expand state belongs to the previous record's rows; clear it so a
    // new record starts from the placement default rather than inheriting stale
    // carets keyed by reused qualified API names.
    this._expandedNames = emptyExpandedState();

    this.isLoading = true;
    this._clearComponentError();
    this.completionWarning = null;
    this.completionWarningDiagnosticCode = null;

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
        throw this._clientDefinitionError(
          "The server returned an invalid health-check definition response."
        );
      }

      const seenQualifiedNames = new Set();
      for (const def of response.checks) {
        if (!def || !def.developerName) {
          throw this._clientDefinitionError(
            "A health-check definition is missing its developer name."
          );
        }
        if (!def.qualifiedApiName) {
          throw this._clientDefinitionError(
            "A health-check definition is missing its qualified API name."
          );
        }
        if (seenQualifiedNames.has(def.qualifiedApiName)) {
          throw this._clientDefinitionError(
            `Duplicate health-check qualified API name: ${def.qualifiedApiName}.`
          );
        }
        seenQualifiedNames.add(def.qualifiedApiName);
      }
      const canonicalChecks = this._canonicalizeCheckIdentities(
        response.checks
      );

      this.displayTitle = response.displayTitle;
      this.displayDescription = response.displayDescription;
      this._requireMode(
        response.triggerMode,
        ["Automatic", "Manual"],
        "When Checks Run"
      );
      this._requireMode(
        response.runButtonDisplay || DEFAULT_RUN_BUTTON_DISPLAY,
        RUN_BUTTON_DISPLAYS,
        "Run Button Display"
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
      this._requireMode(
        response.summaryDisplay || "BOTTOM",
        ["TOP", "BOTTOM"],
        "Summary Display"
      );
      this.triggerMode = response.triggerMode;
      this.checkSetRunButtonDisplay =
        response.runButtonDisplay || DEFAULT_RUN_BUTTON_DISPLAY;
      this.runButtonLabel = response.runButtonLabel;
      this.rerunButtonLabel = response.rerunButtonLabel;
      this.runButtonIcon = response.runButtonIcon;
      if (
        this.triggerMode === "Manual" &&
        this.checkSetRunButtonDisplay === "HIDE"
      ) {
        const configurationError = new Error(
          "Run Button Display cannot be Hide when checks run only after a user clicks Run. Choose a visible display or configure the Check Set to run when the page opens."
        );
        configurationError.reasonCode = "INVALID_CONFIG";
        throw configurationError;
      }
      this.revealMode = response.revealMode;
      this.successDisplayMode = response.successDisplayMode;
      this.skippedDisplayMode = response.skippedDisplayMode;
      this.summaryDisplay = response.summaryDisplay || "BOTTOM";
      this.comparisonDisplay = response.comparisonDisplay;
      this.stopOnFirstError = response.stopOnFirstError;
      this.showDiagnostics = response.showDiagnostics === true;
      this._canViewDetails = response.canViewDetails === true;
      this.totalCheckCount = canonicalChecks.length;
      this.totalAvailableCheckCount =
        typeof response.totalAvailableCheckCount === "number"
          ? response.totalAvailableCheckCount
          : canonicalChecks.length;
      this.frameworkMaxChecks =
        typeof response.frameworkMaxChecks === "number"
          ? response.frameworkMaxChecks
          : 25;
      this.inactiveCheckCount =
        typeof response.inactiveCheckCount === "number"
          ? response.inactiveCheckCount
          : 0;
      // Names arrive only for the diagnostics audience; without them the pill
      // still renders, just without a hover list.
      this.inactiveCheckLabels = Array.isArray(response.inactiveCheckLabels)
        ? response.inactiveCheckLabels.filter((name) => !!name)
        : [];
      this.checksOmittedByLimit = response.checksOmittedByLimit || false;

      // Build per-check rows — all start PENDING
      this.checks = canonicalChecks.map((def) => ({
        developerName: def.developerName,
        qualifiedApiName: def.qualifiedApiName,
        label: def.label,
        description: def.description,
        category: def.category || null,
        categoryLabel: def.categoryLabel || null,
        priority: def.priority,
        dependsOnCheckDeveloperName: def.dependsOnCheckDeveloperName || null,
        dependsOnCheckQualifiedApiName:
          def.dependsOnCheckQualifiedApiName || null,
        uiState: "PENDING",
        result: null
      }));

      this.isLoading = false;
      this._clearComponentError();

      if (runSource) {
        this._runner.run(runSource === "RUN_ON_LOAD", runSource);
      } else if (this.triggerMode === "Automatic") {
        this._scheduleAutomaticRun(
          loadToken,
          requestedCheckSetName,
          requestedRecordId
        );
      }
    } catch (err) {
      if (loadToken !== this._loadToken || !this._connected) return;
      this.isLoading = false;
      const parsed = parseAuraError(err);
      const reasonCode =
        err?.reasonCode === "CLIENT_DEFINITION_INVALID"
          ? "CLIENT_DEFINITION_INVALID"
          : parsed.reasonCode;
      this._setComponentError(
        reasonCode,
        parsed.message,
        parsed.diagnosticCode
      );
    }
  }

  _scheduleAutomaticLoad() {
    this._cancelScheduledAutomaticRun();
    const checkSetName = this.checkSetName;
    const recordId = this.recordId;
    const runWhenIdle = () => {
      this._cancelAutomaticRun = null;
      if (
        !this._connected ||
        this.triggerMode !== "Automatic" ||
        checkSetName !== this.checkSetName ||
        recordId !== this.recordId
      ) {
        return;
      }
      this._loadDefinitions("RUN_ON_LOAD");
    };
    this._cancelAutomaticRun = this._scheduleIdleWork(runWhenIdle);
  }

  _cancelScheduledInitialLoad() {
    if (this._cancelInitialLoad) {
      this._cancelInitialLoad();
      this._cancelInitialLoad = null;
    }
  }

  _cancelScheduledAutomaticRun() {
    if (this._cancelAutomaticRun) {
      this._cancelAutomaticRun();
      this._cancelAutomaticRun = null;
    }
  }

  _scheduleAutomaticRun(loadToken, checkSetName, recordId) {
    this._cancelScheduledAutomaticRun();
    const runWhenIdle = () => {
      this._cancelAutomaticRun = null;
      if (
        !this._connected ||
        loadToken !== this._loadToken ||
        checkSetName !== this.checkSetName ||
        recordId !== this.recordId ||
        this.triggerMode !== "Automatic"
      ) {
        return;
      }
      this._runner.run(true, "RUN_ON_LOAD");
    };

    this._cancelAutomaticRun = this._scheduleIdleWork(runWhenIdle);
  }

  _scheduleIdleWork(runWhenIdle) {
    if (typeof window.requestIdleCallback === "function") {
      const idleId = window.requestIdleCallback(runWhenIdle);
      return () => window.cancelIdleCallback(idleId);
    }

    // Older browsers and Lightning security runtimes that don't expose
    // requestIdleCallback use a paint-and-macrotask fallback.
    let timerId = null;
    let cancelled = false;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    const frameId = requestAnimationFrame(() => {
      if (cancelled) return;
      // LWS safely virtualizes this component-owned fallback timer.
      // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
      timerId = setTimeout(runWhenIdle, 0);
    });
    return () => {
      cancelled = true;
      cancelAnimationFrame(frameId);
      if (timerId !== null) clearTimeout(timerId);
    };
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
        if (parsed.reasonCode === "NOT_AUTHORIZED") {
          this._setComponentError(
            parsed.reasonCode,
            parsed.message,
            parsed.diagnosticCode
          );
          return;
        }
        this._setComponentError(
          "AVAILABILITY_LOOKUP_FAILED",
          parsed.message,
          parsed.diagnosticCode
        );
        return;
      }
    }
    if (loadToken !== this._loadToken || !this._connected) {
      return;
    }
    this.isLoading = false;
    if (availability.hasActive) {
      this._setComponentError(
        "SETUP_REQUIRED",
        "No Check Set is selected for this Record Health Check component."
      );
      return;
    }
    if (availability.hasInactive) {
      this._setComponentError(
        "INACTIVE_CHECK_SETS_ONLY",
        "Check Sets exist for this object, but none of them are active."
      );
      return;
    }
    this._setComponentError(
      "NO_ACTIVE_CHECK_SETS",
      "No Check Set has been configured for this object's records."
    );
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

  _clientDefinitionError(message) {
    return Object.assign(new Error(message), {
      reasonCode: "CLIENT_DEFINITION_INVALID"
    });
  }

  _canonicalizeCheckIdentities(definitions) {
    const byDeveloperName = new Map();
    for (const definition of definitions) {
      const candidates = byDeveloperName.get(definition.developerName) || [];
      candidates.push(definition);
      byDeveloperName.set(definition.developerName, candidates);
    }

    return definitions.map((definition) => {
      const explicitQualifiedDependency =
        definition.dependsOnCheckQualifiedApiName;
      const developerNameDependency = definition.dependsOnCheckDeveloperName;
      if (!explicitQualifiedDependency && !developerNameDependency) {
        return { ...definition, dependsOnCheckQualifiedApiName: null };
      }
      if (explicitQualifiedDependency) {
        return {
          ...definition,
          dependsOnCheckQualifiedApiName: explicitQualifiedDependency
        };
      }

      const candidates = byDeveloperName.get(developerNameDependency) || [];
      if (candidates.length === 0) {
        return {
          ...definition,
          dependsOnCheckQualifiedApiName: developerNameDependency
        };
      }
      if (candidates.length === 1) {
        return {
          ...definition,
          dependsOnCheckQualifiedApiName: candidates[0].qualifiedApiName
        };
      }

      const sourceNamespace = this._checkNamespace(definition);
      const sameNamespace = candidates.filter(
        (candidate) => this._checkNamespace(candidate) === sourceNamespace
      );
      if (sameNamespace.length !== 1) {
        throw this._clientDefinitionError(
          `Prerequisite Check "${developerNameDependency}" is ambiguous across namespaces.`
        );
      }
      return {
        ...definition,
        dependsOnCheckQualifiedApiName: sameNamespace[0].qualifiedApiName
      };
    });
  }

  _checkNamespace(definition) {
    return checkNamespace(definition);
  }

  _handleCompletionFailure(error) {
    const parsed = parseAuraError(error);
    this.completionWarning =
      "Your results are shown, but the run couldn't be finalized.";
    this.completionWarningDiagnosticCode =
      this._canViewDetails === true ? parsed.diagnosticCode : null;
  }

  get isSetupError() {
    return SETUP_ERROR_CODES.has(this.componentErrorCode);
  }

  get errorBannerClass() {
    return "rhc-row rhc-row--system-error rhc-error-banner";
  }

  get errorBannerTitle() {
    return this.componentErrorTitle || "Record Health Check Unavailable";
  }

  get componentErrorAccessibleLabel() {
    return [
      this.errorBannerTitle,
      this.componentError,
      this.componentErrorGuidance
    ]
      .filter(Boolean)
      .join(". ");
  }

  get setupErrorHint() {
    return (
      this.componentErrorGuidance || setupErrorHint(this.componentErrorCode)
    );
  }

  async handleComponentErrorRetry() {
    if (!this.componentErrorRetryable || this.isLoading) return;
    await this._loadDefinitions();
  }

  get showRunButton() {
    // Stays rendered while a run is in progress (disabled + spinner; label stays
    // Run or Rerun per hasCompletedRunOnce — see actionButtonLabel).
    return (
      !this.hideRunButton && this.triggerMode === "Manual" && !this.runComplete
    );
  }

  get showRerunButton() {
    return !this.hideRunButton && this.runComplete && this.checks.length > 0;
  }

  get isAllAtOnce() {
    return this.revealMode === "AllAtOnce";
  }

  get visibleChecks() {
    const signature = JSON.stringify([
      this.triggerMode,
      this.runComplete,
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
    // Manual Check Sets do not disclose rule names before the user starts the
    // first evaluation. Reveal mode controls how results appear during a run;
    // it must not expose the configured rules in the idle pre-run state.
    if (
      this.triggerMode === "Manual" &&
      !this.runComplete &&
      !this._runner.isRunning
    ) {
      this._visibleChecksSource = this.checks;
      this._visibleChecksSignature = signature;
      this._visibleChecksCache = [];
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
      const revealIdentity = nextPending ? checkIdentity(nextPending) : null;
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
          checkIdentity(c) === revealIdentity
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
        this._isRowExpanded(checkIdentity(c))
      )
    );
    return this._visibleChecksCache;
  }

  // Whether a row's comparison detail is currently expanded. Carets default to
  // collapsed; a user toggle records an explicit state in _expandedNames.
  _isRowExpanded(identity) {
    if (Object.prototype.hasOwnProperty.call(this._expandedNames, identity)) {
      return this._expandedNames[identity];
    }
    return false;
  }

  handleToggleDetail(event) {
    const identity = event.currentTarget.dataset.check;
    const next = !this._isRowExpanded(identity);
    // Reassign (not mutate) so the tracked field change re-runs visibleChecks.
    const expandedNames = emptyExpandedState();
    Object.assign(expandedNames, this._expandedNames);
    expandedNames[identity] = next;
    this._expandedNames = expandedNames;
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
    toggle.ariaExpanded = expanded ? "true" : "false";
    toggle.ariaLabel = `${expanded ? "Collapse" : "Expand"} ${label}`;
  }

  get checkCountLabel() {
    const n = this.totalCheckCount;
    return `${n} ${n === 1 ? "Check" : "Checks"}`;
  }

  // Count phrase for the pre-run hint: pluralized, and when the set exceeds the
  // 25-check cap it makes clear only the first 25 will run.
  get checkCountPhrase() {
    if (this.checksOmittedByLimit) {
      return `the first ${this.frameworkMaxChecks} of ${this.totalAvailableCheckCount} checks`;
    }
    const n = this.totalCheckCount;
    return `${n} ${n === 1 ? "check" : "checks"}`;
  }

  get showActionButton() {
    return this.showRunButton || this.showRerunButton;
  }

  get hideRunButton() {
    return this.checkSetRunButtonDisplay === "HIDE";
  }

  get showRunButtonLabel() {
    return ["LABEL_AND_ICON", "LABEL_ONLY"].includes(
      this.checkSetRunButtonDisplay
    );
  }

  get showRunButtonIcon() {
    return ["LABEL_AND_ICON", "ICON_ONLY"].includes(
      this.checkSetRunButtonDisplay
    );
  }

  get showActionButtonGlyph() {
    return this.showRunButtonIcon || this.actionButtonBusy;
  }

  get normalizedRunButtonIcon() {
    return typeof this.runButtonIcon === "string"
      ? this.runButtonIcon.trim()
      : "";
  }

  get useLightningRunButtonIcon() {
    return (
      this.showRunButtonIcon &&
      SLDS_ICON_NAME.test(this.normalizedRunButtonIcon)
    );
  }

  get useCssRunButtonIcon() {
    return this.showRunButtonIcon && !this.useLightningRunButtonIcon;
  }

  get actionButtonClass() {
    return this.checkSetRunButtonDisplay === "ICON_ONLY"
      ? "slds-button slds-button_neutral rhc-action-button rhc-action-button_icon-only"
      : "slds-button slds-button_neutral rhc-action-button";
  }

  get showHeaderActions() {
    return this.showActionButton;
  }

  get showPreRunHint() {
    // Shown before the first Manual run in both reveal modes. Rule names stay
    // hidden until the user starts evaluation.
    return (
      this.triggerMode === "Manual" &&
      this.showActionButton &&
      !this.isLoading &&
      !this.runComplete &&
      !this._runner.isRunning &&
      this.totalCheckCount > 0
    );
  }

  get preRunHintText() {
    const action = this.showRunButtonLabel
      ? this.actionButtonLabel
      : "the icon";
    return `Click ${action} to evaluate ${this.checkCountPhrase}.`;
  }

  get showBuilderPreviewMessage() {
    return this.isBuilderPreview;
  }

  get builderPreviewMessage() {
    if (!this.checkSetName) {
      return "Select a Check Set in the component properties.";
    }
    const availability = "Runs when a record is available.";
    if (!this.builderCountsAvailable) {
      return availability;
    }
    const activeLabel =
      this.totalAvailableCheckCount === 1 ? "check" : "checks";
    if (this.inactiveCheckCount === 0) {
      return `${availability} Includes ${this.totalAvailableCheckCount} active ${activeLabel}.`;
    }
    const inactiveLabel = this.inactiveCheckCount === 1 ? "check" : "checks";
    return `${availability} Includes ${this.totalAvailableCheckCount} active ${activeLabel} and ${this.inactiveCheckCount} inactive ${inactiveLabel}.`;
  }

  get showHiddenEvaluationHint() {
    return (
      this.triggerMode === "Automatic" &&
      this.hideRunButton &&
      this.checksOmittedByLimit &&
      this._runner.isRunning
    );
  }

  get hiddenEvaluationHintText() {
    return `Evaluating ${this.checkCountPhrase}.`;
  }

  get showSummaryStats() {
    return this.runComplete && this.summaryGroups.length > 0;
  }

  get showSummaryStatsAbove() {
    return this.showSummaryStats && this.summaryDisplay === "TOP";
  }

  get showSummaryStatsBelow() {
    return this.showSummaryStats && !this.showSummaryStatsAbove;
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
    return `${this.actionButtonLabel} · ${this.checkCountLabel}`;
  }

  get actionButtonLabel() {
    const configured = this.hasCompletedRunOnce
      ? this.rerunButtonLabel
      : this.runButtonLabel;
    const fallback = this.hasCompletedRunOnce ? "Rerun" : "Run";
    return typeof configured === "string" && configured.trim()
      ? configured.trim()
      : fallback;
  }

  get actionButtonAriaLabel() {
    if (this._runner.isRunning) {
      return this.actionTitle;
    }
    return this.actionButtonLabel;
  }

  get actionButtonBusy() {
    return this._definitionLoadInProgress || this._runner.isRunning;
  }

  // While a run is in flight the button stays put but is disabled, so it reads
  // as busy instead of vanishing.
  get actionButtonDisabled() {
    return (
      !this.recordId || this._definitionLoadInProgress || this._runner.isRunning
    );
  }

  async handleAction() {
    if (
      !this.recordId ||
      this._definitionLoadInProgress ||
      this._runner.isRunning
    ) {
      return;
    }
    this.completionWarning = null;
    this.completionWarningDiagnosticCode = null;
    // A Rerun starts a fresh evaluation, so per-row carets the user opened on the
    // previous run should collapse back to the placement default rather than
    // linger open over rows whose values are being recomputed.
    this._expandedNames = emptyExpandedState();
    if (this.checks.length === 0 && this.triggerMode === "Manual") {
      this._definitionLoadInProgress = true;
      try {
        await this._loadDefinitions("USER_INITIATED");
      } finally {
        this._definitionLoadInProgress = false;
      }
      return;
    }
    this._runner.run(false, "USER_INITIATED");
  }

  get summaryGroups() {
    const tooltipKeys = this._summaryTooltipKeys();
    const tooltipSignature = tooltipKeys.join("|");
    const inactiveStat = this._inactiveCheckStat();
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

  /**
   * Inactive checks are configuration housekeeping a regular user cannot act on,
   * so the count no longer sits in the card header. Under diagnostics it leads
   * the stats bar as a neutral pill whose hover lists the omitted check names,
   * matching how the Passed/Skipped pills reveal their rows.
   */
  _inactiveCheckStat() {
    return buildInactiveCheckStat(
      this.showDiagnostics,
      this.inactiveCheckCount,
      this.inactiveCheckLabels
    );
  }

  _isSkipped(check) {
    return (
      check &&
      check.uiState === "RESOLVED" &&
      check.result &&
      check.result.status === "SKIPPED"
    );
  }

  // Diagnostics is an authorized troubleshooting overlay, but it must not turn
  // healthy results into apparent problems. Respect the configured row visibility
  // and let an administrator inspect successful evidence deliberately.
  _isHiddenSkipped(check) {
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
          incident: r.adminDetail?.incident ?? null,
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
    // Snapshot reactive LWC values before logging so DevTools shows stable,
    // readable objects instead of Proxy wrappers that change after expansion.
    const diag = JSON.parse(JSON.stringify(this._buildRunDiagnostics()));
    const summary = this._formatRunSummary(diag.checks);
    const nextSteps = diagnosticNextSteps(diag.checks);
    const configLabel =
      diag.checkSetQualifiedApiName || "(unset checkSetQualifiedApiName)";
    console.group(`[RHC] ${configLabel} · ${summary}`);
    console.info(`Run ID: ${diag.runId}`);
    for (const step of nextSteps) {
      console.info(`Next: ${step}`);
    }
    const actionableChecks = diag.checks.filter(
      (check) => check.status !== "PASS"
    );
    if (actionableChecks.length === 0) {
      console.info(
        "No diagnostic issues were found. Successful Check details remain available in the component when configured to display."
      );
    } else {
      this._logCheckDiagnostics({ ...diag, checks: actionableChecks });
    }
    console.groupEnd();
  }

  _logCheckDiagnostics(diag) {
    const orderedChecks = [...diag.checks].sort((left, right) => {
      const rank = { ERROR: 0, UNABLE_TO_EVALUATE: 1, FAIL: 2, SKIPPED: 3 };
      return (rank[left.status] ?? 4) - (rank[right.status] ?? 4);
    });
    console.group(`[RHC] Results needing review (${orderedChecks.length})`);
    for (const [index, c] of orderedChecks.entries()) {
      const reason = c.reasonCode ? ` · ${c.reasonCode}` : "";
      const heading = `${index + 1}. ${c.label} · ${c.status}${reason}`;
      console.groupCollapsed(heading);
      console.log(`Status: ${c.status}`);
      if (c.severity) console.log(`Severity: ${c.severity}`);
      if (c.reasonCode) console.log(`Reason code: ${c.reasonCode}`);
      if (c.evaluatorType) console.log(`Evaluator: ${c.evaluatorType}`);
      if (c.durationMs != null) console.log(`Duration: ${c.durationMs}ms`);
      if (c.incident != null) {
        const incident = safeIncidentReport(c.incident);
        if (incident.summary) console.log(`Issue: ${incident.summary}`);
        const location = [
          incident.phase,
          incident.topFrameClass
            ? `${incident.topFrameClass}${incident.topFrameMethod ? `.${incident.topFrameMethod}` : ""}${incident.topFrameLine != null ? `, line ${incident.topFrameLine}` : ""}`
            : incident.component
        ]
          .filter(Boolean)
          .join(" · ");
        if (location) console.log(`Where: ${location}`);
        if (incident.likelyCause) console.log(`Why: ${incident.likelyCause}`);
        for (const action of incident.remediationActions || []) {
          console.log(
            `Fix: ${[action.label, action.instruction].filter(Boolean).join(" — ")}`
          );
        }
        for (const verification of incident.verificationSteps || []) {
          console.log(`Verify: ${verification}`);
        }
      } else {
        if (c.message) console.log(`Issue: ${c.message}`);
        if (c.adminMessage) console.log(`Why: ${c.adminMessage}`);
        if (c.fixInstructions) console.log(`Fix: ${c.fixInstructions}`);
      }

      const needsTechnicalEvidence =
        c.status === "ERROR" || c.status === "UNABLE_TO_EVALUATE";
      if (needsTechnicalEvidence) {
        const advanced = {
          identity: {
            qualifiedApiName:
              c.rawResult?.checkQualifiedApiName ||
              c.checkQualifiedApiName ||
              c.check,
            evaluatorType: c.evaluatorType,
            status: c.status,
            severity: c.severity,
            reasonCode: c.reasonCode,
            durationMs: c.durationMs
          },
          configuration: c.configuration,
          resolution: c.resolution,
          renderedOutput: {
            message: c.message,
            found: c.actualValue,
            expected: c.expectedValue,
            foundSource: c.actualValueDetail,
            expectedSource: c.expectedValueDetail,
            fixInstructions: c.fixInstructions,
            actionLabel: c.actionLabel,
            actionUrl: c.actionUrl
          },
          serverDiagnostic: c.adminMessage,
          incident: c.incident,
          containsRestrictedDetail: c.containsRestrictedDetail,
          rawNormalizedResult: c.rawResult
        };
        console.groupCollapsed("Advanced diagnostics");
        console.log(advanced);
        console.groupEnd();

        console.groupCollapsed("Support report for this check");
        console.warn(
          "Review and redact customer data, record and user IDs, queries, and authentication information before sharing."
        );
        console.log(supportCheckDiagnosticsReport(diag, c));
        console.groupEnd();
      }
      console.groupEnd();
    }
    console.groupEnd();
  }
}
