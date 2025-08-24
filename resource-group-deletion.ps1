#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runbook to delete all eligible Resource Groups across selected subscriptions.
    Assumes resource groups are already empty and does not attempt to delete individual resources.
#>

# 1) Authenticate under the Automation Account’s Managed Identity
Write-Output "Logging into Azure via Managed Identity..."
Connect-AzAccount -Identity

# 2) Define your “friendly names” of the subscriptions you want to process
$desiredFriendlyNames = @(
    "CIS130 - Azure Cloud Fundamentals",
    "CAI105 - Azure AI Fundamentals",
    "CIS131 - Azure Cloud Administration",
    "CLD332 - Microsoft Azure Security Technologies"
    # Add more display names here as needed
)

# 3) Pull all subscriptions your identity has access to
$allSubs = Get-AzSubscription

# 4) Filter to only those whose DisplayName matches our list
$targetSubs = $allSubs | Where-Object { $desiredFriendlyNames -contains $_.Name }
if ($targetSubs.Count -ne $desiredFriendlyNames.Count) {
    $missing = $desiredFriendlyNames | Where-Object { $_ -notin $targetSubs.Name }
    Write-Warning "Could not find these subscription names in the account: $($missing -join ', ')"
}

foreach ($subObj in $targetSubs) {
    $subName = $subObj.Name
    $subId   = $subObj.Id

    Write-Output "==============================================="
    Write-Output "Switching context to Subscription:`n   Name: $subName`n   Id:   $subId"

    # 5) Set the context to the target subscription
    try {
        Set-AzContext -SubscriptionId $subId | Out-Null
    }
    catch {
        Write-Error "❌ Failed to set context to subscription $subId`: $($_)"
        continue
    }

    # 6) Retrieve all RGs, excluding automation-related groups (safety filter)
    $allRGs = Get-AzResourceGroup | Where-Object {
        ($_.ResourceGroupName -notmatch "(?i)automation") -and
        ($_.ResourceGroupName -ne "trashbin-rg")
    }

    if (-not $allRGs) {
        Write-Output "   • No eligible Resource Groups found in subscription [$subName]. Skipping."
        continue
    }

    # 7) Attempt to delete each RG
    foreach ($rg in $allRGs) {
        $rgName = $rg.ResourceGroupName
        Write-Output "   → Deleting Resource Group: $rgName"
        try {
            Remove-AzResourceGroup -Name $rgName -Force -ErrorAction Stop
            Write-Output "      ✓ Deleted Resource Group: $rgName"
        }
        catch {
            Write-Error "      ❌ Failed to delete Resource Group [$rgName`]: $($_)"
        }
    }
}

Write-Output "==============================================="
Write-Output "Resource Group Deletion Runbook completed at $(Get-Date -Format 'u')"
