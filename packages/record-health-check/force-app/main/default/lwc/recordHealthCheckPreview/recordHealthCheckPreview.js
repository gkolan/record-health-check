import { LightningElement, api } from "lwc";
import LightningConfirm from "lightning/confirm";
import preview from "@salesforce/apex/RecordHealthCheckPreviewController.preview";
import deleteExpiredReceipts from "@salesforce/apex/RecordHealthCheckPreviewController.deleteExpiredReceipts";

const ACTIVATION_WARNING =
  "This Check has no current live verification. Activate anyway?";

export default class RecordHealthCheckPreview extends LightningElement {
  _qualifiedSetName = "";
  _draftJson = "{}";
  recordIdsText = "";
  readinessRequested = false;
  activationRequested = false;
  isLoading = false;
  errorMessage;
  cleanupMessage;
  response;
  isStale = false;
  requestSequence = 0;
  connected = true;

  @api
  get qualifiedSetName() {
    return this._qualifiedSetName;
  }

  set qualifiedSetName(value) {
    const normalized = value ?? "";
    if (normalized !== this._qualifiedSetName) {
      this._qualifiedSetName = normalized;
      this.markResponseStale();
    }
  }

  @api
  get draftJson() {
    return this._draftJson;
  }

  set draftJson(value) {
    const normalized = value ?? "{}";
    if (normalized !== this._draftJson) {
      this._draftJson = normalized;
      this.markResponseStale();
    }
  }

  connectedCallback() {
    this.connected = true;
  }

  disconnectedCallback() {
    this.connected = false;
    this.requestSequence += 1;
  }

  handleInput(event) {
    const { input } = event.target.dataset;
    const value = event.detail?.value ?? event.target.value;
    if (input === "qualifiedSetName") {
      this._qualifiedSetName = value;
    } else if (input === "draftJson") {
      this._draftJson = value;
    } else if (input === "recordIds") {
      this.recordIdsText = value;
    }
    this.markResponseStale();
  }

  handleReadiness(event) {
    this.readinessRequested = event.detail?.checked ?? event.target.checked;
  }

  handlePluginParameter(event) {
    const key = event.target.dataset.parameterKey;
    const typeName = event.target.dataset.parameterType;
    const value =
      typeName === "BOOLEAN"
        ? (event.detail?.checked ?? event.target.checked)
        : (event.detail?.value ?? event.target.value);
    const parsedDraft = JSON.parse(this.draftJson);
    let parameters = {};
    try {
      parameters = JSON.parse(parsedDraft.ApexParametersJson__c || "{}");
    } catch {
      this.errorMessage =
        "Apex Parameters JSON must be corrected before using generated controls.";
      return;
    }
    parameters[key] = typeName === "INTEGER" ? Number(value) : value;
    parsedDraft.ApexParametersJson__c = JSON.stringify(parameters);
    this._draftJson = JSON.stringify(parsedDraft, null, 2);
    this.markResponseStale();
  }

  handleActivation(event) {
    this.activationRequested = event.detail?.checked ?? event.target.checked;
    this.dispatchEvent(
      new CustomEvent("activationchange", {
        detail: {
          requested: this.activationRequested,
          warning: this.showActivationWarning ? ACTIVATION_WARNING : null
        }
      })
    );
  }

  handleValidate() {
    return this.run("VALIDATE_ONLY", false);
  }

  handlePreview() {
    return this.run("EXECUTE", this.readinessRequested);
  }

  async handleDeleteExpired() {
    // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open -- LightningConfirm.open is the supported platform confirmation API, not Window.open.
    const confirmed = await LightningConfirm.open({
      label: "Delete expired readiness receipts",
      message: "Delete up to 200 expired readiness receipts visible to you?",
      theme: "warning"
    });
    if (!confirmed || !this.connected) {
      return;
    }
    this.errorMessage = undefined;
    this.cleanupMessage = undefined;
    this.isLoading = true;
    try {
      const count = await deleteExpiredReceipts({ confirmed: true });
      if (this.connected) {
        this.cleanupMessage = `${count} expired readiness receipt${
          count === 1 ? "" : "s"
        } deleted.`;
      }
    } catch (error) {
      if (this.connected) {
        this.errorMessage = this.messageFrom(error);
      }
    } finally {
      if (this.connected) {
        this.isLoading = false;
      }
    }
  }

  async run(mode, readinessReceiptRequested) {
    this.errorMessage = undefined;
    let parsedDraft;
    try {
      parsedDraft = JSON.parse(this.draftJson);
    } catch {
      this.errorMessage = "Draft Check JSON must be valid JSON.";
      return;
    }
    if (!parsedDraft || Array.isArray(parsedDraft)) {
      this.errorMessage = "Draft Check JSON must contain one object.";
      return;
    }
    if (!this.qualifiedSetName?.trim()) {
      this.errorMessage = "Qualified Check Set Name is required.";
      return;
    }

    const snapshot = this.currentSnapshot;
    const sequence = ++this.requestSequence;
    this.isLoading = true;
    try {
      const payload = await preview({
        draftJson: JSON.stringify(parsedDraft),
        qualifiedSetName: this.qualifiedSetName.trim(),
        recordIds: this.recordIds,
        mode,
        readinessReceiptRequested
      });
      if (!this.connected || sequence !== this.requestSequence) {
        return;
      }
      this.response = this.prepareResponse(JSON.parse(payload));
      this.isStale = snapshot !== this.currentSnapshot;
    } catch (error) {
      if (this.connected && sequence === this.requestSequence) {
        this.errorMessage = this.messageFrom(error);
        this.response = undefined;
      }
    } finally {
      if (this.connected && sequence === this.requestSequence) {
        this.isLoading = false;
      }
    }
  }

  prepareResponse(value) {
    return {
      ...value,
      pluginParameterRows: (value.pluginParameters ?? []).map((parameter) => ({
        ...parameter,
        isInteger: parameter.typeName === "INTEGER",
        isChoice: parameter.typeName === "CHOICE",
        isString: parameter.typeName === "STRING",
        isBoolean: parameter.typeName === "BOOLEAN",
        value: parameter.currentValue,
        checked: parameter.currentValue === true,
        options: (parameter.choices ?? []).map((choice) => ({
          label: choice,
          value: choice
        }))
      })),
      capabilityRows: Object.entries(value.capabilities ?? {}).map(
        ([name, status]) => ({ key: name, name, status })
      ),
      findingRows: (value.findings ?? []).map((finding, index) => ({
        ...finding,
        key: `${finding.code ?? "finding"}-${index}`
      })),
      resultRows: (value.results ?? []).map((item, index) => ({
        key: `${item.evaluation?.recordId ?? "result"}-${index}`,
        recordId: item.evaluation?.recordId,
        status: item.evaluation?.status,
        message:
          item.display?.renderedMessage ?? item.evaluation?.reasonCode ?? ""
      }))
    };
  }

  markResponseStale() {
    if (this.response) {
      this.isStale = true;
    }
  }

  messageFrom(error) {
    return error?.body?.message ?? error?.message ?? "Preview failed.";
  }

  get recordIds() {
    return [
      ...new Set(
        this.recordIdsText
          .split(/[\s,]+/)
          .map((value) => value.trim())
          .filter(Boolean)
      )
    ];
  }

  get currentSnapshot() {
    return JSON.stringify({
      draft: this.draftJson,
      set: this.qualifiedSetName,
      ids: this.recordIds
    });
  }

  get hasResponse() {
    return Boolean(this.response);
  }

  get hasFindings() {
    return Boolean(this.response?.findingRows.length);
  }

  get hasResults() {
    return Boolean(this.response?.resultRows.length);
  }

  get hasPluginParameters() {
    return Boolean(this.response?.pluginParameterRows.length);
  }

  get showCurrentReadiness() {
    return (
      !this.isStale &&
      this.response?.readinessReceipt?.receiptStatus === "SAVED"
    );
  }

  get currentLiveVerified() {
    if (this.isStale) {
      return false;
    }
    return this.response?.hasCurrentLiveVerification === true;
  }

  get showActivationWarning() {
    return this.activationRequested && !this.currentLiveVerified;
  }

  get activationWarning() {
    return ACTIVATION_WARNING;
  }

  get liveStatus() {
    if (this.isLoading) {
      return "Validation in progress.";
    }
    if (this.errorMessage) {
      return this.errorMessage;
    }
    if (this.response) {
      return `Validation ${this.response.validationStatus}${
        this.isStale ? ", stale" : ""
      }.`;
    }
    return "";
  }
}
