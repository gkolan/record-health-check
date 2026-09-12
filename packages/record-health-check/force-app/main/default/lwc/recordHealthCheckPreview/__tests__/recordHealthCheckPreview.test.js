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

  it("renders the human result message returned by the display contract", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        mode: "EXECUTE",
        results: [
          {
            evaluation: {
              recordId: "001000000000001AAA",
              status: "FAIL",
              reasonCode: "FORMULA_FALSE"
            },
            display: { renderedMessage: "The website needs attention." }
          }
        ]
      })
    );
    const element = createComponent();

    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("[data-result]").textContent
    ).toContain("The website needs attention.");
    expect(
      element.shadowRoot.querySelector("[data-result]").textContent
    ).not.toContain("FORMULA_FALSE");
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

  it("invalidates live verification when a parent replaces the draft", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        mode: "EXECUTE",
        readinessState: "LIVE_VERIFIED",
        hasCurrentLiveVerification: true
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();

    element.draftJson = JSON.stringify({
      DeveloperName: "Parent_Replaced_Draft",
      Record_Health_Check_Set__c: "m0A000000000001AAA",
      EvaluationType__c: "FORMULA"
    });
    await flushPromises();

    expect(element.shadowRoot.querySelector("[data-readiness]")).toBeNull();
    expect(element.shadowRoot.querySelector("[data-stale]")).not.toBeNull();
  });

  it("invalidates live verification when a parent replaces the Check Set", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        mode: "EXECUTE",
        readinessState: "LIVE_VERIFIED",
        hasCurrentLiveVerification: true
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();

    element.qualifiedSetName = "Different_Set";
    await flushPromises();

    expect(element.shadowRoot.querySelector("[data-readiness]")).toBeNull();
    expect(element.shadowRoot.querySelector("[data-stale]")).not.toBeNull();
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
  it.each(["42", "true", '"text"', "null", "[]"])(
    "rejects non-object draft %s before calling Apex",
    async (draft) => {
      const element = createComponent();
      element.draftJson = draft;
      element.shadowRoot.querySelector("[data-action='validate']").click();
      await flushPromises();
      expect(preview).not.toHaveBeenCalled();
      expect(
        element.shadowRoot.querySelector("[role='alert']").textContent
      ).toContain("one object");
    }
  );

  it("can run again after disconnecting while a request is pending", async () => {
    let resolveOld;
    preview.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveOld = resolve;
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();
    document.body.removeChild(element);
    document.body.appendChild(element);
    await flushPromises();
    expect(
      element.shadowRoot.querySelector("[data-action='preview']").disabled
    ).toBe(false);
    preview.mockResolvedValueOnce(
      JSON.stringify({ ...VALID_RESPONSE, runId: "new-run" })
    );
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();
    resolveOld(JSON.stringify({ ...VALID_RESPONSE, validationStatus: "OLD" }));
    await flushPromises();
    expect(
      element.shadowRoot.querySelector("[data-status]").textContent
    ).not.toContain("OLD");
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });

  it("shows an unsaved receipt warning and identifies each Check result", async () => {
    preview.mockResolvedValue(
      JSON.stringify({
        ...VALID_RESPONSE,
        readinessReceipt: {
          receiptStatus: "NOT_SAVED",
          warning: "Receipt storage unavailable."
        },
        results: ["ns__Prerequisite", "ns__Draft"].map(
          (checkQualifiedApiName) => ({
            evaluation: {
              recordId: "001000000000001AAA",
              checkQualifiedApiName,
              status: "PASS"
            }
          })
        )
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector("[data-receipt-warning]")?.textContent
    ).toContain("Receipt storage unavailable.");
    const rows = [...element.shadowRoot.querySelectorAll("[data-result]")];
    expect(rows[0].textContent).toContain("ns__Prerequisite");
    expect(rows[1].textContent).toContain("ns__Draft");
    element.draftJson = "{}";
    await flushPromises();
    expect(
      element.shadowRoot.querySelector("[data-receipt-warning]")
    ).toBeNull();
  });

  it("omits a cleared integer without changing sibling parameters", async () => {
    const element = await parameterComponent(
      '{"maxPreviewRecords":5,"other":true}'
    );
    const control = element.shadowRoot.querySelector(
      "[data-parameter-key='maxPreviewRecords']"
    );
    control.dispatchEvent(new CustomEvent("change", { detail: { value: "" } }));
    await flushPromises();
    expect(
      JSON.parse(JSON.parse(element.draftJson).ApexParametersJson__c)
    ).toEqual({ other: true });
    expect(
      element.shadowRoot.querySelector(
        "[data-parameter-key='maxPreviewRecords']"
      )
    ).not.toBeNull();
  });

  it.each(["null", "[]", "42", "true", '"text"', "{"])(
    "reports malformed parameter object %s without changing the draft",
    async (parameters) => {
      const element = await parameterComponent(parameters);
      const before = element.draftJson;
      element.shadowRoot
        .querySelector("[data-parameter-key='maxPreviewRecords']")
        .dispatchEvent(new CustomEvent("change", { detail: { value: "7" } }));
      await flushPromises();
      expect(element.draftJson).toBe(before);
      expect(
        element.shadowRoot.querySelector("[role='alert']").textContent
      ).toContain("Apex Parameters JSON");
    }
  );

  it("removes obsolete controls when raw draft JSON changes", async () => {
    const element = await parameterComponent("{}");
    const obsolete = element.shadowRoot.querySelector(
      "[data-parameter-key='maxPreviewRecords']"
    );
    element.draftJson = "{";
    await flushPromises();
    expect(
      element.shadowRoot.querySelector("[data-plugin-parameter]")
    ).toBeNull();
    obsolete.dispatchEvent(
      new CustomEvent("change", { detail: { value: "7" } })
    );
    await flushPromises();
    expect(element.draftJson).toBe("{");
  });

  it("ignores cleanup completion from before a disconnect during a new Preview", async () => {
    let finishCleanup;
    let finishPreview;
    LightningConfirm.open.mockResolvedValue(true);
    deleteExpiredReceipts.mockReturnValue(
      new Promise((resolve) => {
        finishCleanup = resolve;
      })
    );
    preview.mockReturnValue(
      new Promise((resolve) => {
        finishPreview = resolve;
      })
    );
    const element = createComponent();
    element.shadowRoot.querySelector("[data-action='delete-expired']").click();
    await flushPromises();
    document.body.removeChild(element);
    document.body.appendChild(element);
    element.shadowRoot.querySelector("[data-action='preview']").click();
    await flushPromises();
    finishCleanup(2);
    await flushPromises();
    expect(element.shadowRoot.querySelector("[data-cleanup]")).toBeNull();
    expect(
      element.shadowRoot.querySelector("lightning-spinner")
    ).not.toBeNull();
    finishPreview(JSON.stringify(VALID_RESPONSE));
    await flushPromises();
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });

  it.each(["1.5", "NaN", "Infinity", "9007199254740992"])(
    "does not write invalid integer %s into the draft",
    async (value) => {
      const element = await parameterComponent("{}");
      const before = element.draftJson;
      element.shadowRoot
        .querySelector("[data-parameter-key='maxPreviewRecords']")
        .dispatchEvent(new CustomEvent("change", { detail: { value } }));
      await flushPromises();
      expect(element.draftJson).toBe(before);
      expect(
        element.shadowRoot.querySelector("[role='alert']").textContent
      ).toContain("whole number");
    }
  );
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

async function parameterComponent(parameters) {
  preview.mockResolvedValue(
    JSON.stringify({
      ...VALID_RESPONSE,
      pluginParameters: [
        {
          key: "maxPreviewRecords",
          typeName: "INTEGER",
          label: "Maximum preview records",
          currentValue: 5
        }
      ]
    })
  );
  const element = createComponent();
  element.draftJson = JSON.stringify({
    ...JSON.parse(element.draftJson),
    ApexParametersJson__c: parameters
  });
  element.shadowRoot.querySelector("[data-action='preview']").click();
  await flushPromises();
  return element;
}
