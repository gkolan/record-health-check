List<Account> existing = [
  SELECT Id
  FROM Account
  WHERE Name LIKE 'RHC Link %'
];
if (!existing.isEmpty()) {
  delete existing;
}
insert new List<Account>{
  new Account(
    Name = 'RHC Link Healthy',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 0,
    Website = 'https://example.com/approvals'
  ),
  new Account(
    Name = 'RHC Link Needs Review',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 1,
    Website = 'https://example.com/approvals'
  ),
  new Account(
    Name = 'RHC Link Not Applicable',
    Site = 'RHC_LINK_OFF',
    NumberOfEmployees = 1,
    Website = 'https://example.com/approvals'
  ),
  new Account(
    Name = 'RHC Link Missing Data',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = null,
    Website = 'https://example.com/approvals'
  ),
  new Account(
    Name = 'RHC Link Missing Destination',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 1,
    Website = null
  ),
  new Account(
    Name = 'RHC Link Unsafe Destination',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 1,
    Website = 'http://example.com/approvals'
  ),
  new Account(
    Name = 'RHC Link Healthy Unsafe Destination',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 0,
    Website = 'http://example.com/approvals'
  ),
  new Account(
    Name = 'RHC Link Numeric Host',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 1,
    Website = 'https://2147483648.1.1.1/path'
  ),
  new Account(
    Name = 'RHC Link Healthy Numeric Host',
    Site = 'RHC_LINK_FIXTURE',
    NumberOfEmployees = 0,
    Website = 'https://2147483648.1.1.1/path'
  )
};
