import { createElement } from "lwc";
import RecordHealthCheckPreview from "c/recordHealthCheckPreview";
import preview from "@salesforce/apex/RecordHealthCheckPreviewController.preview";
import deleteExpiredReceipts from "@salesforce/apex/RecordHealthCheckPreviewController.deleteExpiredReceipts";
import LightningConfirm from "lightning/confirm";

jest.mock(
  "@salesforce/apex/RecordHealthCheckPreviewController.preview",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/RecordHealthCheckPreviewController.deleteExpiredReceipts",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock("lightning/confirm", () => ({ open: jest.fn() }), {
  virtual: true
});

const VALID_RESPONSE = {
  version: "1.0",
  runId: "run-1",
  definitionFingerprint: "abc123",
  mode: "VALIDATE_ONLY",
  validationStatus: "VALID",
  capabilities: { configuration: "COMPLETE" },
  findings: [],
  resolvedFields: ["Id", "Website"],
  results: [],
  readinessReceipt: { receiptStatus: "NOT_REQUESTED" },
  readinessState: "DRAFT",
  hasCurrentLiveVerification: false,
  pluginParameters: []
};

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-record-health-check-preview", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("validates only after the administrator clicks Validate", async () => {
    preview.mockResolvedValue(JSON.stringify(VALID_RESPONSE));
    const element = createComponent();

    element.shadowRoot.querySelector("[data-action='validate']").click();
    await flushPromises();

    expect(preview).toHaveBeenCalledWith(
      expect.objectContaining({
        mode: "VALIDATE_ONLY",
        readinessReceiptRequested: false,
        recordIds: []
      })
    );
    expect(
      element.shadowRoot.querySelector("[data-status]").textContent
    ).toContain("VALID");
  });

  it("sends stable deduplicated record IDs for explicit Preview", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        mode: "EXECUTE",
        results: [
          { evaluation: { recordId: "001000000000001AAA", status: "FAIL" } }
        ]
      })
    );
    const element = createComponent();
    change(element, "recordIds", "001000000000001AAA\n001000000000001AAA");
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();

    expect(preview).toHaveBeenCalledWith(
      expect.objectContaining({
        mode: "EXECUTE",
        recordIds: ["001000000000001AAA"]
      })
    );
    expect(element.shadowRoot.querySelectorAll("[data-result]")).toHaveLength(
      1
    );
  });

  it("labels a late response stale after the draft changes", async () => {
    let resolvePreview;
    preview.mockReturnValue(
      new Promise((resolve) => {
        resolvePreview = resolve;
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='validate']").click();
    change(element, "draftJson", '{"DeveloperName":"Changed"}');
    resolvePreview(JSON.stringify(VALID_RESPONSE));
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("[data-stale]").textContent
    ).toContain("stale");
    expect(element.shadowRoot.querySelector("[data-readiness]")).toBeNull();
  });

  it("shows the exact activation warning without blocking the choice", async () => {
    const element = createComponent();
    const activation = element.shadowRoot.querySelector(
      "[data-input='activate']"
    );
    activation.checked = true;
    activation.dispatchEvent(
      new CustomEvent("change", { detail: { checked: true } })
    );
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("[data-activation-warning]").textContent
    ).toContain(
      "This Check has no current live verification. Activate anyway?"
    );
  });

  it("deletes an expired batch only after explicit confirmation", async () => {
    LightningConfirm.open.mockResolvedValue(true);
    deleteExpiredReceipts.mockResolvedValue(2);
    const element = createComponent();

    element.shadowRoot.querySelector("[data-action='delete-expired']").click();
    await flushPromises();

    expect(LightningConfirm.open).toHaveBeenCalled();
    expect(deleteExpiredReceipts).toHaveBeenCalledWith({ confirmed: true });
    expect(
      element.shadowRoot.querySelector("[data-cleanup]").textContent
    ).toContain("2 expired readiness receipts deleted.");
  });

  it("does not delete expired receipts when confirmation is declined", async () => {
    LightningConfirm.open.mockResolvedValue(false);
    const element = createComponent();

    element.shadowRoot.querySelector("[data-action='delete-expired']").click();
    await flushPromises();

    expect(deleteExpiredReceipts).not.toHaveBeenCalled();
  });

  it("renders typed controls returned by an Apex provider", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        mode: "EXECUTE",
        pluginParameters: [
          {
            key: "maxPreviewRecords",
            typeName: "INTEGER",
            label: "Maximum preview records",
            helpText: "Choose a bounded preview size.",
            defaultValue: 5,
            minValue: 1,
            maxValue: 50,
            required: true
          }
        ]
      })
    );
    const element = createComponent();

    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();

    const controls = element.shadowRoot.querySelectorAll(
      "[data-plugin-parameter]"
    );
    expect(controls).toHaveLength(1);
    expect(controls[0].querySelector("lightning-input").type).toBe("number");
  });

  it("writes typed generated-control values into the draft parameter JSON", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        mode: "EXECUTE",
        pluginParameters: [
          {
            key: "maxPreviewRecords",
            typeName: "INTEGER",
            label: "Maximum preview records",
            currentValue: 5,
            minValue: 1,
            maxValue: 50
          }
        ]
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();
    const control = element.shadowRoot.querySelector(
      "[data-plugin-parameter] lightning-input"
    );

    control.value = "7";
    control.dispatchEvent(
      new CustomEvent("change", { detail: { value: "7" } })
    );
    await flushPromises();

    const draft = JSON.parse(element.draftJson);
    expect(JSON.parse(draft.ApexParametersJson__c)).toEqual({
      maxPreviewRecords: 7
    });
    expect(element.shadowRoot.querySelector("[data-stale]")).not.toBeNull();
  });
});

function createComponent() {
  const element = createElement("c-record-health-check-preview", {
    is: RecordHealthCheckPreview
  });
  element.qualifiedSetName = "RHC_SP_Preview";
  element.draftJson = JSON.stringify({
    DeveloperName: "RHC_SP_Preview_Website",
    Record_Health_Check_Set__c: "m0A000000000001AAA",
    EvaluationType__c: "FORMULA"
  });
  document.body.appendChild(element);
  return element;
}

function change(element, name, value) {
  const input = element.shadowRoot.querySelector(`[data-input='${name}']`);
  input.value = value;
  input.dispatchEvent(new CustomEvent("change", { detail: { value } }));
}
