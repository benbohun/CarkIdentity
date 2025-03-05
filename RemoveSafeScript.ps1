# Import the psPAS Module
Import-Module psPAS

# Define Log Files
$LogFile = "SafeRemovalLog.txt"
$FailedLogFile = "FailToRemoveSafe.txt"

Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

Function Write-FailLog {
    Param ([string]$SafeName)
    Add-Content -Path $FailedLogFile -Value $SafeName
    Write-Output "❌ Failed Safe logged: $SafeName"
}

# Step 1: Authenticate Using psPAS
Write-Log "Requesting CyberArk PAS authentication..."
$header = Get-IdentityHeader -IdentityTenantURL "aat4012.id.cyberark.cloud" -psPASFormat -PCloudSubdomain "cna-prod" -UPCreds $UPCred

# Register the PAS session
use-PASSession $header

# Validate the session
$session = Get-PASSession
if ($session) {
    Write-Log "✅ Authentication successful, PAS session established."
} else {
    Write-Log "❌ Authentication failed. Exiting script."
    exit
}

# Step 2: Load the CSV File with Safes to Remove
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafesToRemove.csv"  # Update this path as needed

if (!(Test-Path $CsvFilePath)) {
    Write-Log "❌ ERROR: CSV file not found at $CsvFilePath. Exiting script."
    exit
}

$SafesToRemove = Import-Csv -Path $CsvFilePath

if ($SafesToRemove.Count -eq 0) {
    Write-Log "❌ ERROR: No Safes found in the CSV file. Exiting script."
    exit
}

Write-Log "✅ Loaded $($SafesToRemove.Count) Safes from CSV for removal."

# Step 3: Remove Safes from CyberArk
foreach ($Safe in $SafesToRemove) {
    $SafeName = $Safe.SafeName

    if (-not $SafeName) {
        Write-Log "⚠️ WARNING: Empty SafeName found in CSV. Skipping..."
        continue
    }

    Write-Log "🔹 Attempting to remove Safe: $SafeName"

    try {
        # Remove Safe using Remove-PASSafe
        Remove-PASSafe -SafeName $SafeName -Confirm:$false

        Write-Log "✅ Successfully removed Safe: $SafeName"
    } catch {
        Write-Log "❌ ERROR: Failed to remove Safe: $SafeName - $_"
        Write-FailLog -SafeName $SafeName
    }
}

Write-Log "🔹 Safe removal process completed."
Write-Log "📌 Check $FailedLogFile for any failed Safe removals."
