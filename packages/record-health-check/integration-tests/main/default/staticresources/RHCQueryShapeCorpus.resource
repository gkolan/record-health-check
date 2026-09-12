{
  "schemaVersion": 1,
  "cases": [
    {
      "id": "Q01",
      "query": "SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id} OR LastName = 'Smith'",
      "classification": "UNCLASSIFIED",
      "supported": false,
      "reason": "UNSUPPORTED_BULK_QUERY_SHAPE",
      "requiredConjunct": null
    },
    {
      "id": "Q02",
      "query": "SELECT COUNT() FROM Contact WHERE AccountId = {!record.Id} AND (LastName = 'Smith' OR LastName = 'Jones')",
      "classification": "CHILD_DIRECT",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q03A",
      "query": "SELECT Id FROM Contact WHERE ((AccountId = {!record.Id}))",
      "classification": "CHILD_DIRECT",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q03B",
      "query": "SELECT Id FROM Contact WHERE NOT (AccountId = {!record.Id})",
      "classification": "UNCLASSIFIED",
      "supported": false,
      "reason": "UNSUPPORTED_BULK_QUERY_SHAPE",
      "requiredConjunct": null
    },
    {
      "id": "Q03C",
      "query": "SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Contact WHERE Id = {!record.Id})",
      "classification": "UNCLASSIFIED",
      "supported": false,
      "reason": "UNSUPPORTED_BULK_QUERY_SHAPE",
      "requiredConjunct": null
    },
    {
      "id": "Q04",
      "query": "SELECT Id FROM Contact WHERE AccountId = {!record.ParentId}",
      "classification": "TOKEN_INDIRECT",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.ParentId}"
    },
    {
      "id": "Q05A",
      "query": "SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND LastName = 'OR AND'",
      "classification": "CHILD_DIRECT",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q05B",
      "query": "SELECT Id FROM Contact WHERE AccountId = '{!record.Id}'",
      "classification": "UNCLASSIFIED",
      "supported": false,
      "reason": "UNSUPPORTED_BULK_QUERY_SHAPE",
      "requiredConjunct": null
    },
    {
      "id": "Q09_ASC_NULLS_FIRST",
      "query": "SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate ASC NULLS FIRST LIMIT 1",
      "classification": "ORDERED_PICK_IN_MEMORY",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q09_ASC_NULLS_LAST",
      "query": "SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate ASC NULLS LAST LIMIT 1",
      "classification": "ORDERED_PICK_IN_MEMORY",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q09_DESC_NULLS_FIRST",
      "query": "SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate DESC NULLS FIRST LIMIT 1",
      "classification": "ORDERED_PICK_IN_MEMORY",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q09_DESC_NULLS_LAST",
      "query": "SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate DESC NULLS LAST LIMIT 1",
      "classification": "ORDERED_PICK_IN_MEMORY",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q09_ASC",
      "query": "SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate ASC LIMIT 1",
      "classification": "ORDERED_PICK_IN_MEMORY",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "Q09_DESC",
      "query": "SELECT Birthdate FROM Contact WHERE AccountId = {!record.Id} ORDER BY Birthdate DESC LIMIT 1",
      "classification": "ORDERED_PICK_IN_MEMORY",
      "supported": true,
      "reason": null,
      "requiredConjunct": "AccountId = {!record.Id}"
    },
    {
      "id": "C01",
      "query": "SELECT Id FROM Contact WHERE AccountId = {!record.Id} AND CreatedById = {!record.Id}",
      "classification": "UNCLASSIFIED",
      "supported": false,
      "reason": "UNSUPPORTED_BULK_QUERY_SHAPE",
      "requiredConjunct": null
    },
    {
      "id": "CONTROL_SELF",
      "query": "SELECT NumberOfEmployees FROM Account WHERE Id = {!record.Id}",
      "classification": "SELF",
      "supported": true,
      "reason": null,
      "requiredConjunct": "Id = {!record.Id}"
    },
    {
      "id": "CONTROL_INVARIANT",
      "query": "SELECT COUNT() FROM Contact WHERE LastName = 'Smith'",
      "classification": "SCOPE_INVARIANT",
      "supported": true,
      "reason": null,
      "requiredConjunct": null
    }
  ]
}
