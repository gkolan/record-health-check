export type ServiceErrorType =
  | "DESTINATION_REJECTED"
  | "SALESFORCE_AUTH"
  | "UPSTREAM_CONTRACT"
  | "UPSTREAM_LIMIT"
  | "UPSTREAM_UNAVAILABLE";

export class ServiceError extends Error {
  readonly code: ServiceErrorType;
  readonly safeMessage: string;
  readonly httpStatus: number;

  constructor(code: ServiceErrorType, safeMessage: string, httpStatus: number) {
    super(safeMessage);
    this.name = "ServiceError";
    this.code = code;
    this.safeMessage = safeMessage;
    this.httpStatus = httpStatus;
  }
}
