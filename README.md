# azure-automation-runbooks

This repository contains Azure Automation runbooks used by CIAT to clean up cloud resources and resource groups at the end of each academic term.

## Runbook Types

There are two categories of runbooks:

### 1. `[course]resourcecleanup`
- **Purpose:** Deletes all individual resources within a specific course's Azure subscription.
- **Naming Convention:** `CIS130resourcecleanup`, `CIS131resourcecleanup`, etc.
- **Schedule:** Automatically runs every Sunday at 12:01 AM.
- **Design Note:**  
  Runbooks are separated by course subscription to **avoid exceeding Azure Automation’s 3-hour job execution limit**. Each course has its own scoped runbook to ensure predictable completion time and isolated logging.

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
- Logs for each runbook execution can be reviewed under **Automation Account → Runbooks → Jobs → View Logs**.

## Permissions Required

Ensure the `azure-automation` identity has **Contributor** access to each course subscription for runbooks to function properly.

