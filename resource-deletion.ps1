#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runbook to purge most resources across selected subscriptions, with safeties to preserve automation assets.
#>

# 1) Authenticate under the Automation Account’s Managed Identity
Write-Output "Logging into Azure via Managed Identity..."
Connect-AzAccount -Identity

# 2) Define your “friendly names” of the subscriptions to process
$desiredFriendlyNames = @(
    "CIS130 - Azure Cloud Fundamentals",
    "CAI105 - Azure AI Fundamentals",
    "CIS131 - Azure Cloud Administration",
    "CLD332 - Microsoft Azure Security Technologies"
)

# 3) List all subscriptions accessible to this identity
$allSubs = Get-AzSubscription

# 4) Filter to only those whose Name matches our list
$targetSubs = $allSubs | Where-Object { $desiredFriendlyNames -contains $_.Name }
if ($targetSubs.Count -ne $desiredFriendlyNames.Count) {
    $missing = $desiredFriendlyNames | Where-Object { $_ -notin $targetSubs.Name }
    Write-Warning "Could not find these subscriptions: $($missing -join ', ')"
}

# 5) Name of the “trash-bin” RG
$trashBinName = "trashbin-rg"

foreach ($subObj in $targetSubs) {
    $subName = $subObj.Name
    $subId   = $subObj.Id

    Write-Output "==============================================="
    Write-Output "Switching context to Subscription:`n   Name: ${subName}`n   Id:   ${subId}"

    # 6) Switch context
    try {
        Set-AzContext -SubscriptionId $subId | Out-Null
    }
    catch {
        Write-Error "Failed to set context to subscription ${subId}: $_"
        continue
    }

    # Ensure trash-bin RG exists
    $existingTrash = Get-AzResourceGroup -Name $trashBinName -ErrorAction SilentlyContinue
    if (-not $existingTrash) {
        $firstRG    = Get-AzResourceGroup | Select-Object -First 1
        $rgLocation = if ($firstRG) { $firstRG.Location } else { "eastus" }
        Write-Output "Creating RG [${trashBinName}] in [${rgLocation}]..."
        try {
            New-AzResourceGroup -Name $trashBinName `
                                -Location $rgLocation `
                                -Tag @{ instructor="azure-automation"; name="azure-automation" } | Out-Null
            Write-Output "Created RG: ${trashBinName}"
        }
        catch {
            Write-Error "Could not create RG ${trashBinName}: $_"
        }
    }
    else {
        Write-Output "RG [${trashBinName}] already exists."
    }

    # Gather RGs to process (skip trash-bin and any with “automation” in name)
    $allRGs    = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
    $targetRGs = $allRGs | Where-Object { $_ -ne $trashBinName -and ($_ -notmatch "(?i)automation") }

    if ($targetRGs.Count -eq 0) {
        Write-Output "No eligible RGs found. Skipping subscription."
        continue
    }

    # Loop through each RG’s resources
    foreach ($rgName in $targetRGs) {
        Write-Output "→ Processing RG: ${rgName}"

        $resources = Get-AzResource -ResourceGroupName $rgName
        if (-not $resources) {
            Write-Output "   • No resources in [${rgName}]."
            continue
        }

        foreach ($res in $resources) {
            $resName       = $res.Name
            $resType       = $res.ResourceType
            $resId         = $res.ResourceId
            $resApiVersion = $res.ApiVersion

            # Skip the Automation Account, azure-delete and resource-deletion runbooks
            if ($resType -eq 'Microsoft.Automation/automationAccounts' `
                -or ($resType -eq 'Microsoft.Automation/automationAccounts/runbooks' -and ($resName -eq 'azure-delete' -or $resName -eq 'resource-deletion'))) {
                Write-Output "   • Skipping protected resource: ${resName} (${resType})"
                continue
            }

            Write-Output "   • Deleting: ${resName} (Type: ${resType})"
            try {
                Remove-AzResource -ResourceId $resId -ApiVersion $resApiVersion -Force -ErrorAction Stop
                Write-Output "     ✓ Deleted ${resName}"
            }
            catch {
                Write-Warning "     ⚠ Failed to delete ${resName}. Moving to [${trashBinName}]..."
                try {
                    Move-AzResource -ResourceId $resId -DestinationResourceGroupName $trashBinName -Force -ErrorAction Stop
                    Write-Output "       ✓ Moved ${resName} to ${trashBinName}"
                }
                catch {
                    Write-Error "       ✗ Failed to move ${resName}: $_"
                }
            }
        }
    }
}

Write-Output "==============================================="
Write-Output "Runbook completed at $(Get-Date -Format 'u')"
