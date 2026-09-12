# Subscriber contract foundations

Use this reference for the internal classes that implement formula planning, diagnostic contract
2.0, plugin definitions, typed outcomes, and scope-stage coordination. These classes are package
implementation details unless their type is explicitly `global` and documented in the subscriber
developer guides.

## Diagnostic provenance and projection

### `RecordHealthCheckDiagContextSupport`

Maps concrete planning, configuration, and plugin failures to their observed phase, invocation
state, reason origin, and bounded source coordinates. It never exposes inaccessible field paths.

### `RecordHealthCheckDiagnosticEnvelope`

Global data holder for one authorized diagnostic contract 2.0 projection. Its fixed fields carry
categorical provenance and bounded trace data without changing legacy evaluation JSON.

### `RecordHealthCheckDiagnosticErrorDetail`

Global disclosure-safe exception projection nested in a diagnostic envelope. It contains bounded
type and top-frame identifiers while arbitrary plugin messages remain withheld.

### `RecordHealthCheckDiagnosticProjection`

Projects server-only incidents and traces in selected Check and normalized record order. It keeps
whole envelopes within the 128 KiB UTF-8 request budget and counts later omissions.

### `RecordHealthCheckDiagnosticResponse`

Global diagnostic response containing `contractVersion = "2.0"`, ordered envelopes, and
`omittedDiagnosticCount`. It is returned only through the explicit authorized diagnostic API.

### `RecordHealthCheckDiagnosticRuntime`

Rejects unknown diagnostic versions before evaluation and attaches the version 2.0 source only
when requested. Existing Show Diagnostics and direct permission-set checks still govern access.

### `RecordHealthCheckDiagnosticTraceEntry`

Global value object for one stage sequence, stage name, and optional measured duration. It carries
no record values, parameter values, formulas, queries, or stack text.

### `RecordHealthCheckExecutionTrace`

Maintains the active phase separately from completed stages for one Check and record. It retains
the first 32 entries and preserves terminal failure independently when the entry cap is exceeded.

### `RecordHealthCheckFatalFailure`

Package marker for failures that per-record isolation must rethrow. Authorization, side-effect,
and framework contract failures use it so an ordinary recovery helper cannot swallow them.

## Formula planning

### `RecordHealthCheckCompileDiagnostic`

Maps each rejected platform compiler probe to a fixed category keyed by the attempted return type.
It never retains exception messages or formula source and caps one category at 120 characters and
the complete AUTO-probe detail at 1,000 characters.

### `RecordHealthCheckFormulaTokenizer`

Tokenizes the supported Salesforce-formula subset while preserving UTF-16 source offsets. It
distinguishes field paths, functions, operators, and literals and redacts malformed literal text.

### `RecordHealthCheckFormulaPlanService`

Produces the detached permission-sensitive formula plan shared by runtime field loading and
metadata validation. It applies token, finding, dependency-depth, and platform-compile bounds.

### `RecordHealthCheckFormulaDepsPlanner`

Expands calculated-field dependencies through described metadata with cycle and depth protection.
It retains the authored source origin for every dependency failure.

### `RecordHealthCheckFormulaMetadataAdapter`

Adapts Salesforce field describe information into deterministic dependency inputs for the shared
planner. Production and controlled test metadata therefore use the same planning algorithm.

### `RecordHealthCheckMergeFindingService`

Carries merge-token findings into the same ordered provenance representation used by field
planning. It does not combine the merge language with the separate formula grammar.

### `RecordHealthCheckDetachedValidator`

Validates a copied draft Check without querying or changing its Custom Metadata record. Validate-only
mode checks Apex structure without constructing subscriber code; execute mode uses the guarded plugin
resolver and the same metadata rules as ordinary execution.

## Plugin definitions and outcomes

### `RecordHealthCheckPluginDefinition`

Global fluent schema for integer, choice, string, and Boolean plugin parameters plus an applicable
scope capacity. It rejects contradictory declarations and returns detached snapshots.

### `RecordHealthCheckPluginDefinitionSource`

Global optional interface that lets a plugin return its definition once under the dispatch fence.
Legacy plugins that implement only `RecordHealthCheckPlugin` remain supported.

### `RecordHealthCheckPluginDefinitionService`

Normalizes configured JSON against a provider definition. It distinguishes absence from null,
rejects duplicate or unknown keys, applies defaults, and enforces exact type and value bounds.

### `RecordHealthCheckOutcomeValidator`

Validates raw typed outcomes before display normalization. Empty lists, `false`, and zero remain
present values while missing Found and Expected values receive distinct structured violations.

### `RecordHealthCheckOutcomeBuilderException`

Global stable exception raised when a fluent outcome builder receives an impossible or
contradictory contract. Subscriber code can correct construction without parsing display text.

### `RecordHealthCheckEvidence`

Global additive builder for an ordered evidence summary, typed columns, rows, and optional grouping
keys. It snapshots caller-owned collections before projection.

### `RecordHealthCheckEvidenceColumn`

Global declaration of one stable column key, visible label, and supported scalar data type.

### `RecordHealthCheckEvidenceCell`

Global typed cell that is either plugin-authored or bound to record-and-field provenance. Provenance
is authorized again before its value can cross the response boundary.

### `RecordHealthCheckEvidenceEnvelope`

Global versioned transport for projected evidence, including ordered rows and explicit completeness,
returned-count, total-count, and omitted-count semantics.

### `RecordHealthCheckEvidenceProjection`

Validates schemas, enforces field access, and applies row, column, cell, summary, and UTF-8 response
budgets. Restricted rows are omitted without disclosing how many inaccessible values existed.

### `RecordHealthCheckRecordEvaluator`

Global per-record callback used by `RecordHealthCheckOutcome.tryEvaluate`. It lets ordinary
record-specific exceptions become isolated outcomes while fatal failures still escape.

### `RecordHealthCheckPluginVerification`

Global subscriber-facing contract-test facade for raw plugin definitions, dispatch, and outcomes.
It deliberately fails broken providers and plugins before normalized framework output can hide a defect.

### `RecordHealthCheckDefTestPlugin`

Package test fixture that exercises valid, malformed, throwing, querying, and mutating definition
providers. Production evaluation never selects this class from shipped customer configuration.

### `RecordHealthCheckDiagModeTestPlugin`

Package test fixture for returned unable outcomes, origin spoof attempts, missing typed values, and
secret-bearing exceptions. It exists solely to guard diagnostic classification and redaction.

## Scope coordination

### `RecordHealthCheckScopeRuntime`

Owns request-local identity utilities and optional per-Check/per-record traces. It records
configuration, applicability, completion, and failure without rerunning an operation.

### `RecordHealthCheckScopeRecordLoader`

Plans the shared field projection and performs the single user-mode record load. It records actual
field-planning and record-loading stages and preserves per-Check planning findings.

### `RecordHealthCheckScopeResultCoordinator`

Attaches server incidents, renders display content, completes the display stage, and maps each
internal result to its public response item in deterministic order.

### `RecordHealthCheckResponseFinalizer`

Publishes the unchanged legacy lifecycle response and then attaches the optional authorized
diagnostic projection. Trace collection never expands stored event schemas.

## Detached preview and readiness

### `RecordHealthCheckPreviewController`

Imperative Lightning adapter for explicit Validate, Preview, and confirmed expired-receipt cleanup.
It converts JSON drafts into the typed global request and returns the versioned response.

### `RecordHealthCheckPreviewRequest`

Global immutable request for one detached Check, a server-owned qualified Set, stable deduplicated
record IDs, mode, and explicit receipt intent. It enforces the 200-ID and 1 MiB request bounds.

### `RecordHealthCheckPreviewResponse`

Global version-1 response carrying validation state, capabilities, source findings, planned fields,
ordinary results, readiness, and any provider-generated parameter controls.

### `RecordHealthCheckPreviewFinding`

Global disclosure-safe validation finding with stable code, severity, configuration field, and
optional zero-based source offsets. Compiler failures may also include the bounded, source-free
probe categories for an authorized administrator; raw compiler messages are never returned.

### `RecordHealthCheckDisplayRedaction`

Creates a detached structured-display copy when an operand is restricted. Formula conditions are
removed from the structured Expected nodes together with their plain display value and label, so
alternate response representations cannot bypass the same disclosure rule.

### `RecordHealthCheckPreviewParameter`

Global typed administrator-control description derived from a guarded Apex plugin definition during
execute preview. It includes normalized current value, constraints, choices, label, and help text.

### `RecordHealthCheckPreviewFingerprint`

Builds a lowercase SHA-256 fingerprint over typed canonical Check, Set, prerequisite, contract, and
available plugin-revision inputs while preserving significant string whitespace.

### `RecordHealthCheckPreviewService`

Global privileged detached-preview boundary. It resolves the Set from server metadata, rejects parent
or identity forgery, validates the effective prerequisite closure, and executes without lifecycle
events or metadata activation.

### `RecordHealthCheckReadinessReceipt`

Global bounded result describing whether an explicitly requested private receipt was saved, rejected,
or unavailable, without exposing representative record IDs or values.

### `RecordHealthCheckReadinessService`

Performs user-mode receipt creation and current-user/org/fingerprint lookup, then deletes only a
confirmed batch of at most 200 visible expired receipts.

### `RecordHealthCheckReadinessState`

Derives DRAFT, VALIDATED, LIVE_VERIFIED, or ACTIVE. Live verification requires an unexpired execute
receipt with complete capabilities, at least one PASS or FAIL, and no ERROR or unable result.

## Merge syntax and structured card display

### `RecordHealthCheckInlineLinkParser`

Parses the explicit `{!link label="..." href="..."}` construct left to right, retaining source
offsets and rejecting unknown or duplicate attributes, incomplete constructs, and nested links.
Nested values retain the ordinary fallback form, for example
`{!record.Name fallback="this record"}`.

### `RecordHealthCheckInlineUrlPolicy`

Applies the strict same-org-path or HTTPS destination policy. It validates complete URLs, encodes
token substitutions by URL component, and degrades missing or unsafe destinations to plain labels.

### `RecordHealthCheckActionUrlPolicy`

Retains the older Action URL sanitizer separately so the new inline-link restrictions do not
silently change the established blue remediation-link contract.

### `RecordHealthCheckDisplayNode`

Global version-1 display node with the closed `text`, `link`, and `break` vocabulary. Only link
nodes carry a previously validated destination.

### `RecordHealthCheckDisplayContent`

Global versioned envelope for optional message, fix, Found, and Expected node lists. It is projected
only when a caller requests `EVALUATION_WITH_DISPLAY`; evaluation-only, event, and saved-result
contracts continue to use their existing machine values.

### `RecordHealthCheckDisplayText`

Global bounded fluent builder for literal text, safe links, line breaks, paragraph breaks, and
ordered record collections. `recordLinks(records, labelField)` emits one independently clickable
Lightning record link per saved record with a comma-space separator; its overload accepts a custom
separator. Null rows and blank labels are skipped, while an unsaved record remains readable as
plain text. `groups(values)` composes generic keyed label/item rows in caller-supplied order and
flattens them to the same validated nodes. It coalesces adjacent text and makes an unsafe destination
readable as a plain label.

### `RecordHealthCheckDisplayGroup`

Global generic group composer used by Apex display plugins. Each group has a unique stable nonblank
key, a required structured label, optional structured items, an optional empty state, and a
colon-space separator that the author may replace. Groups preserve caller order and repeated items.
An empty group is hidden unless it supplies visible empty-state content. The composition fails closed
if a key, nested fragment, or aggregate display bound is invalid.

### `RecordHealthCheckDisplayOverride`

Global optional plugin result that supplies independently optional message, fix, Found and Expected
builders; an atomic action; an Expected label; and per-side display format/currency choices without
giving the plugin control over its evaluation verdict or administrator policy.

### `RecordHealthCheckDisplayAction`

Global immutable-from-the-subscriber-view label-and-destination pair. The central resolver applies
the pair only to FAIL results and only when its trimmed label and established Action URL policy are
both valid; otherwise the configured action remains intact.

### `RecordHealthCheckDisplayPlugin`

Global additive interface for a `getDisplay(scope)` callback used by every
`EVALUATION_WITH_DISPLAY` request. The engine invokes it once on the same plugin instance after
evaluation so implementations can reuse preloaded data.

### `RecordHealthCheckDisplayComposer`

Resolves trusted metadata templates into validated nodes and their backward-compatible plain-text
projection. Returned record or plugin strings are never reparsed as authored markup.

### `RecordHealthCheckPluginDisplayDispatch`

Guards the optional display callback with exact record keys, detached scope input, query and
side-effect fences, per-field validation, and copied builders.

### `RecordHealthCheckApexDisplaySupport`

Attaches the detached plugin presentation to the internal Apex result while keeping the original
typed values available when an override is absent or rejected.

### `RecordHealthCheckPresentationResolver`

Applies valid plugin fields over configured presentation immediately before structured display is
projected. It owns status-specific policy, atomic action fallback, Expected-label validation,
per-side typed formatting and diagnostic recording. It never changes the typed evaluation values.

### `RecordHealthCheckStructuredDisplay`

Attaches structured content for display-capable results and enforces deterministic field order and
aggregate response budgets before the result crosses a serialized boundary.

## Related

- [Apex implementation reference](./README.md)
- [Scope orchestration](./scope-orchestration.md)
- [Results and plugins](./results-and-plugins.md)
- [Apex Check contract](../../developer-guides/write-an-apex-check.md)
