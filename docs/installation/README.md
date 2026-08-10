# Choose your Record Health Check path

> [!NOTE]
> On this page, choose the installation, demo, upgrade, or removal path that matches the outcome you
> need in your Salesforce org.

Start with the outcome you need. Most administrators should install the package in a sandbox, assign
the installed permission sets, and test with records that represent their own business process. The
demo scratch-org path is for evaluators or contributors who have Salesforce CLI and Dev Hub access
and want a separate disposable org with prepared data.

## Choose your path

| Your starting point | Follow this path | What you will accomplish |
| --- | --- | --- |
| I want to understand the experience before installing | [How Record Health Check works](how-it-works.md) | Understand Check Sets, Checks, outcomes, and when advisory guidance fits |
| I want to add Record Health Check to a sandbox or another org I already use | [Install and verify in your org](install-and-verify.md) | Install the package, assign access, place the card, and verify it with that org's records |
| I need a specific released version or recovery path | [Package versions, installation, and rollback](package-versions.md) | Choose an immutable version and understand safe rollback options |
| I have Salesforce CLI and Dev Hub access and want a separate prepared demo | [Deploy to a demo scratch org](create-rhc-scratch-org.md) | Create a disposable org with prepared records and confirm the expected demo results |
| I want to create a check for my organization | [Create your first Check](create-your-first-check.md) | Build one Account Check and test both attention and passing states |
| Record Health Check is already installed | [Upgrade and revalidate](upgrading.md) | Protect the configuration and prove the user experience still works after an upgrade |
| I need to remove Record Health Check | [Uninstall and rollback](uninstall-and-rollback.md) | Remove dependencies in a safe order and confirm the org is clean |

## New installation sequence

| Step | Page | What you learn or verify |
| ---: | --- | --- |
| 1 | [How Record Health Check works](how-it-works.md) | What the card communicates and when it is the right tool |
| 2 | [Install and verify in your org](install-and-verify.md) | The package, access, page placement, and a working result against your records |
| 3 | [Create your first Check](create-your-first-check.md) | How to turn one familiar business question into useful guidance |

If you have Salesforce CLI and Dev Hub access and prefer a separate prepared experience, start with
[Deploy to a demo scratch org](create-rhc-scratch-org.md). Otherwise, use a sandbox you already
manage.

## Upgrade sequence

The [upgrade and revalidation guide](upgrading.md) starts by preserving the current experience.
It then upgrades a representative sandbox, compares known business outcomes, verifies access and
automation, and defines when it is safe to continue to production.

## Next steps

| Your next goal | Continue with |
| --- | --- |
| Find a practical Check pattern | [Examples library](../examples/README.md) |
| Configure a complete readiness review | [Configure Check Sets and Checks](../guides/configure-check-sets-and-checks.md) |
| Review security before production | [Security and data access](../reference/framework/security.md) |
| Plan day-to-day ownership | [Operate in production](../guides/operate-in-production.md) |
