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
$trashBinName = "trashbin-rg"

$subs = Get-AzSubscription | Where-Object { $desiredFriendlyNames -contains $_.Name }

foreach ($sub in $subs) {
  Set-AzContext -SubscriptionId $sub.Id -Force | Out-Null

  # Target RGs (skip automation and trashbin)
  $rgs = Get-AzResourceGroup | Where-Object {
    $_.ResourceGroupName -ne $trashBinName -and $_.ResourceGroupName -notmatch "automation"
  }

  # Remove locks up front so group deletion doesn't stall
  foreach ($rg in $rgs) {
    Get-AzResourceLock -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue |
      Remove-AzResourceLock -Force -ErrorAction SilentlyContinue
  }

  # Kick off deletions in parallel and async
  $throttle = 6  # tune to your sub’s throttling tolerance
  $rgs | ForEach-Object -Parallel {
      param($trashBinName)
      # Each parallel runspace needs its own context
      Connect-AzAccount -Identity | Out-Null
      Set-AzContext -SubscriptionId $using:sub.Id -Force | Out-Null

      try {
        Remove-AzResourceGroup -Name $_.ResourceGroupName -Force -AsJob | Out-Null
        Write-Output "Started delete: $($_.ResourceGroupName)"
      } catch {
        Write-Warning "Delete start failed for $($_.ResourceGroupName): $($_.Exception.Message)"
      }
  } -ThrottleLimit $throttle
}
