# azure-automation-runbooks

This repository contains Azure Automation runbooks used by CIAT to clean up cloud resources and resource groups at the end of each academic term.

## `resource-deletion.ps1`

- **Purpose:** Deletes all resource groups (excluding automation and `trashbin-rg`) across the subscriptions listed in the script.
- **Execution:** Designed for the shared automation account with managed identity; uses parallel deletion so the job completes consistently in under three hours.
- **How it works:** Removes existing resource locks, then kicks off `Remove-AzResourceGroup` jobs in parallel runspaces with a conservative throttle limit to avoid Azure Automation timeouts.
- **Default template:** This script is the baseline design for all cleanup runbooks; course-scoped variants reuse the same throttled, parallel pattern to stay within Azure Automation’s job window.
- **Timeout avoidance:** The concurrency level is tuned so jobs finish within three hours; adjust `$throttle` only if Azure raises or reduces the job concurrency limits.

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
- The consolidated `resource-deletion` runbook now completes within the three-hour automation job window under normal load; check Azure Automation job duration if you change the throttle or subscription set.
- Splitting work by subscription remains the default approach; consolidate only if you can still guarantee sub-three-hour execution.
- Logs for each runbook execution can be reviewed under **Automation Account → Runbooks → Jobs → View Logs**.

## Permissions Required

Ensure the `azure-automation` identity has **Contributor** access to each course subscription for runbooks to function properly.

