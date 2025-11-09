# azure-automation-runbooks

This repository contains Azure Automation runbooks used by CIAT to clean up cloud resources and resource groups at the end of each academic term.

## `resource-deletion.ps1`

- **Purpose:** Deletes individual resources across the target subscriptions while leaving the resource groups themselves intact.
- **Execution:** Runs under managed identity, walks each subscription and resource group sequentially, and skips automation-related groups plus the `trashbin-rg`.
- **How it works:** Attempts a direct delete for every resource (with a small protected-type allowlist); if Azure blocks the delete, the resource is moved into `trashbin-rg` for manual follow-up.
- **Timeout considerations:** This implementation favors reliability over raw speed and no longer relies on large fan‑out job batches. Typical runs stay within Azure Automation’s three-hour window, but runtime scales with the number of resources and dependency errors surfaced by Azure.
- **Operational notes:** Watch the job logs for `⚠ Failed to delete` / `✓ Moved` lines—they identify resources that ended up in the trash bin because of dependency constraints.

## Runbook Types

There are two categories of runbooks:

### 1. `[course]resourcecleanup`
- **Purpose:** Deletes all individual resources within a specific course's Azure subscription.
- **Naming Convention:** `CIS130resourcecleanup`, `CIS131resourcecleanup`, etc.
- **Schedule:** Automatically runs every Sunday at 12:01 AM.
- **Design Note:**  
  Runbooks are separated by course subscription to **avoid exceeding Azure Automation’s 3-hour job execution limit**. This split is the default for all runbooks so each one stays under the runtime ceiling while retaining isolated logging.

### 2. `[course]rgcleanup`
- **Purpose:** Deletes the resource groups themselves after the term ends.
- **Naming Convention:** `CIS130rgcleanup`, `CIS131rgcleanup`, etc.
- **Execution:** Must be triggered manually.
- **Recommended Timing:** The Thursday after the course term ends.

## Manual Execution Instructions

To manually execute a `rgcleanup` runbook:
1. Log into the Azure Portal.
2. Navigate to the Automation Account managing the relevant course.
3. Select the `[course]rgcleanup` runbook.
4. Click **Start** to execute it.

> ⚠️ **Warning:** These runbooks permanently delete all associated resource groups. Confirm all grading and data recovery needs are met before executing.

## Known Behaviors

- Some resource types (e.g., Recovery Services Vaults) cannot be deleted via automation and will be moved to a special `trashbin-rg` for manual follow-up.
- The runbook processes subscriptions sequentially; runtime depends on the volume of resources and Azure throttling, so review job duration after major subscription changes.
- Splitting work by subscription remains the default approach; consolidate only if you can still guarantee sub-three-hour execution.
- Logs for each runbook execution can be reviewed under **Automation Account → Runbooks → Jobs → View Logs**.

## Permissions Required

Ensure the `azure-automation` identity has **Contributor** access to each course subscription for runbooks to function properly.

