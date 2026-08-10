List<Account> accounts = new List<Account>();
for (Integer index = 0; index < 10; index++) {
  accounts.add(
    new Account(Name = 'RHC Capacity ' + index, BillingCity = 'Chicago')
  );
}
insert accounts;
List<Id> recordIds = new List<Id>();
for (Account accountRecord : accounts) recordIds.add(accountRecord.Id);

Integer queriesBefore = Limits.getQueries();
Integer rowsBefore = Limits.getQueryRows();
Integer cpuBefore = Limits.getCpuTime();
Integer heapBefore = Limits.getHeapSize();
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forCheck('Account_DQ_BillingCity', recordIds)
);
Integer responseBytes = Blob.valueOf(JSON.serialize(response)).size();
System.debug(
  'RHC_CAPACITY=' +
    JSON.serialize(
      new Map<String, Object>{
        'records' => recordIds.size(),
        'evaluations' => response.results.size(),
        'queries' => Limits.getQueries() - queriesBefore,
        'queryRows' => Limits.getQueryRows() - rowsBefore,
        'cpuMs' => Limits.getCpuTime() - cpuBefore,
        'heapBytes' => Limits.getHeapSize() - heapBefore,
        'responseBytes' => responseBytes
      }
    )
);
