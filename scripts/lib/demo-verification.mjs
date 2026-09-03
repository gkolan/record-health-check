import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { paths } from "./paths.mjs";
import { tryRun } from "./run.mjs";

function apexString(value) {
  return `'${value.replaceAll("\\", "\\\\").replaceAll("'", "\\'")}'`;
}

/** Verify named scenarios, every active result, rendered values, and record counts. */
export function verifyReadinessData(alias, namespace = "rhc") {
  const matrix = JSON.parse(
    fs.readFileSync(
      path.join(paths.subscriberData, "readiness-scenarios.json"),
      "utf8"
    )
  );
  const prefix = namespace ? `${namespace}.` : "";
  const metadataPrefix = namespace ? `${namespace}__` : "";
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "rhc-readiness-verification-")
  );
  const integrity = tryRun("sf", [
    "apex",
    "run",
    "--target-org",
    alias,
    "--file",
    path.join(paths.subscriberData, "verifyReadinessData.apex"),
    "--json"
  ]);
  fs.writeFileSync(
    path.join(directory, "data.json"),
    integrity.stdout || integrity.stderr
  );
  const integrityPayload = JSON.parse(integrity.stdout);
  if (
    integrity.status !== 0 ||
    integrityPayload.status !== 0 ||
    !integrityPayload.result?.success
  )
    throw new Error(
      `Demo data integrity failed: ${integrityPayload.message}. Evidence: ${directory}`
    );
  let total = 0;
  for (const [object, scenario] of Object.entries(matrix)) {
    const records = Object.entries(scenario.records);
    const expected = records
      .map(
        ([name, checks]) =>
          `${apexString(name)} => new Map<String,String>{${Object.entries(
            checks
          )
            .map(
              ([check, status]) =>
                `${apexString(metadataPrefix + check)} => ${apexString(status)}`
            )
            .join(",")}}`
      )
      .join(",");
    const count = records.reduce(
      (sum, [, checks]) => sum + Object.keys(checks).length,
      0
    );
    let source = `
List<${object}> records = [${scenario.query}];
Map<Id,${object}> byId = new Map<Id,${object}>(records);
Map<String,Map<String,String>> expected = new Map<String,Map<String,String>>{${expected}};
System.assertEquals(expected.size(),records.size(),'Missing or duplicate ${object} demo records');
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(RecordHealthCheckRequest.forCheckSet(${apexString(metadataPrefix + scenario.checkSet)},new List<Id>(byId.keySet())).withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY));
System.assertEquals(${count},response.results.size(),'Unexpected ${object} Check count');
for(RecordHealthCheckResultItem item:response.results) {
 String name=byId.get(item.evaluation.recordId).Name;
 String checkName=item.evaluation.checkQualifiedApiName;
 System.assert(expected.containsKey(name),'Unknown demo record: '+name);
 System.assert(expected.get(name).containsKey(checkName),'Unknown or duplicate Check: '+checkName);
 System.assertEquals(expected.get(name).get(checkName),item.evaluation.status,name+' / '+checkName);
 System.assert(!JSON.serialize(item.display).contains('{!'),'Unresolved display token: '+checkName);
 Boolean emptyRoleQuery=name=='RHC Demo Review Account' && checkName.endsWith('Example_Open_Deals_Have_Contacts');
 if(emptyRoleQuery) {
  System.assertEquals(null,item.display.foundDisplayValue,'No-row failure has no numeric evidence');
  System.assertEquals(null,item.display.expectedDisplayValue);
 }
 if(item.evaluation.status!='SKIPPED' && !emptyRoleQuery) {
  System.assert(!String.isBlank(item.display.foundDisplayValue),'Missing Found: '+name+' / '+checkName);
  System.assert(!String.isBlank(item.display.expectedDisplayValue),'Missing Expected: '+name+' / '+checkName);
 }
 if(name=='Acme Corporation' && checkName.endsWith('Example_Account_Owner_Active')) {
  System.assertEquals('Jordan Blake is inactive',item.display.foundDisplayValue);
  System.assertEquals('Active',item.display.expectedDisplayValue);
 }
 if(checkName.endsWith('Example_Opportunity_DR_Probability')) {
  String percentage=(name=='RHC Demo Ready Deal' || name=='RHC Demo Low Pipeline')?'50%':(name=='RHC Demo Closed Lost'?'0%':'100%');
  System.assertEquals(percentage,item.display.foundDisplayValue,'Probability must use percentage units');
 }
 expected.get(name).remove(checkName);
 System.debug('RHC_SCENARIO='+name+' / '+checkName+' / '+item.evaluation.status);
}
for(Map<String,String> remaining:expected.values()) System.assert(remaining.isEmpty(),'Omitted Checks');
System.debug('RHC_READINESS_VERIFIED ${object} records=${records.length} results=${count}');
`;
    source = source.replace(
      /\b(RecordHealthCheckResponse|RecordHealthCheckRequest|RecordHealthCheckResultMode|RecordHealthCheckResultItem|RecordHealthCheck)\b/g,
      `${prefix}$1`
    );
    const file = path.join(directory, `verify${object}.apex`);
    fs.writeFileSync(file, source);
    const result = tryRun("sf", [
      "apex",
      "run",
      "--target-org",
      alias,
      "--file",
      file,
      "--json"
    ]);
    fs.writeFileSync(
      path.join(directory, `${object}.json`),
      result.stdout || result.stderr
    );
    const payload = JSON.parse(result.stdout);
    if (
      result.status !== 0 ||
      payload.status !== 0 ||
      !payload.result?.success
    ) {
      throw new Error(
        `${object} demo verification failed: ${payload.message ?? payload.result?.exceptionMessage}. Evidence: ${directory}`
      );
    }
    console.log(
      `Verified ${object}: ${records.length} scenarios, ${count} Check results.`
    );
    total += count;
  }
  const productFile = path.join(directory, "verifyProducts.apex");
  fs.writeFileSync(
    productFile,
    `
Account ready=[SELECT Id FROM Account WHERE AccountNumber='RHC-DEMO-READY' LIMIT 1];
${prefix}RecordHealthCheckResponse response=${prefix}RecordHealthCheck.evaluate(${prefix}RecordHealthCheckRequest.forCheck('${metadataPrefix}Example_Average_Deal_Vs_Largest',ready.Id).withResultMode(${prefix}RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY));
System.assertEquals(1,response.results.size());
System.assertEquals('PASS',response.results[0].evaluation.status,'Positive Product-total scenario');
System.assert(!String.isBlank(response.results[0].display.foundDisplayValue));
System.assert(!String.isBlank(response.results[0].display.expectedDisplayValue));
`
  );
  const product = tryRun("sf", [
    "apex",
    "run",
    "--target-org",
    alias,
    "--file",
    productFile,
    "--json"
  ]);
  fs.writeFileSync(
    path.join(directory, "products.json"),
    product.stdout || product.stderr
  );
  const productPayload = JSON.parse(product.stdout);
  if (
    product.status !== 0 ||
    productPayload.status !== 0 ||
    !productPayload.result?.success
  )
    throw new Error(
      `Product comparison failed: ${productPayload.message}. Evidence: ${directory}`
    );
  console.log(
    `Verified ${total} readiness results plus the positive Product comparison. Evidence: ${directory}`
  );
  return directory;
}
