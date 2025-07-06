#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runbook to delete all resources (not resource groups) across selected subscriptions,
    skipping protected types and moving undeletable ones to trashbin-rg.
#>

$ErrorActionPreference = "Stop"

Write-Output "Logging into Azure via Managed Identity..."
Connect-AzAccount -Identity

# Friendly subscription names
$desiredFriendlyNames = @(
    "CIS130 - Azure Cloud Fundamentals",
    "CAI105 - Azure AI Fundamentals",
    "CIS131 - Azure Cloud Administration",
    "CLD332 - Microsoft Azure Security Technologies"
)

# Load all accessible subscriptions
$allSubs = Get-AzSubscription
$targetSubs = $allSubs | Where-Object { $desiredFriendlyNames -contains $_.Name }

if ($targetSubs.Count -ne $desiredFriendlyNames.Count) {
    $missing = $desiredFriendlyNames | Where-Object { $_ -notin $targetSubs.Name }
    Write-Warning "Could not find these subscriptions: $($missing -join ', ')"
}

# Skip these resource types from deletion
$protectedTypes = @(
    "Microsoft.Automation/automationAccounts",
    "Microsoft.Automation/automationAccounts/runbooks"
)

$trashBinName = "trashbin-rg"
$processedSubIds = @{}

foreach ($sub in $targetSubs) {
    $subId = $sub.Id
    $subName = $sub.Name

    if ($processedSubIds.ContainsKey($subId)) {
        Write-Warning "Already processed ${subName} — skipping."
        continue
    }
    $processedSubIds[$subId] = $true

    Write-Output "`n==============================================="
    Write-Output "Switching to subscription: ${subName} (${subId})"

    try {
        Set-AzContext -SubscriptionId $subId -Force | Out-Null
    }
    catch {
        $err = $_.Exception.Message
        Write-Warning "Failed to set context to ${subName}: ${err}"
        continue
    }

    # Create trashbin-rg if missing
    if (-not (Get-AzResourceGroup -Name $trashBinName -ErrorAction SilentlyContinue)) {
        $location = (Get-AzResourceGroup | Select-Object -First 1).Location
        if (-not $location) { $location = "eastus" }
        Write-Output "Creating resource group '${trashBinName}' in ${location}"
        New-AzResourceGroup -Name $trashBinName -Location $location -Force | Out-Null
    }

    # Get all RGs except automation and trashbin
    $rgs = Get-AzResourceGroup | Where-Object {
        $_.ResourceGroupName -ne $trashBinName -and $_.ResourceGroupName -notmatch "automation"
    }

    foreach ($rg in $rgs) {
        Write-Output "→ Processing RG: $($rg.ResourceGroupName)"

        $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
        if (-not $resources) {
            Write-Output "   • No resources to delete."
            continue
        }

        foreach ($res in $resources) {
            $type = $res.ResourceType
            $name = $res.Name
            $id   = $res.ResourceId
            $api  = $res.ApiVersion

            if ($protectedTypes -contains $type) {
                Write-Output "   • Skipping protected: ${name} (${type})"
                continue
            }

            Write-Output "   • Deleting: ${name} (${type})"
            try {
                Remove-AzResource -ResourceId $id -ApiVersion $api -Force -ErrorAction Stop
                Write-Output "     ✓ Deleted ${name}"
            }
            catch {
                Write-Warning "     ⚠ Failed to delete ${name}. Attempting move..."
                try {
                    Move-AzResource -ResourceId $id -DestinationResourceGroupName $trashBinName -Force -ErrorAction Stop
                    Write-Output "       ✓ Moved ${name} to ${trashBinName}"
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    Write-Warning "       ✗ Failed to move ${name}. Exception: ${errorMsg}"
                }
            }
        }
    }
}

Write-Output "`n✅ Cleanup complete at $(Get-Date -Format u)"
