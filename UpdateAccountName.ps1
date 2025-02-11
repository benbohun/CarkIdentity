# Import the psPAS Module
Import-Module psPAS

# Define Log File
$LogFile = "PASAccountUpdateLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
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

# Step 2: Load CSV File (Hardcoded Path)
$CsvFilePath = "C:\Path\To\AccountUpdates.csv"  # Update this path to your actual CSV file

# Check if CSV file exists
if (-Not (Test-Path $CsvFilePath)) {
    Write-Log "❌ ERROR: CSV file not found at $CsvFilePath"
    exit
}

# Load CSV
$Accounts = Import-Csv -Path $CsvFilePath

# Process each Account update
foreach ($Account in $Accounts) {
    $AccountID = $Account.AccountID
    $NewName = $Account.Name  # Use Name from CSV as the new account name

    Write-Log "Updating PAS Account ID: ${AccountID} to '${NewName}'"

    try {
        # Step 3: Execute API Request to Update Account Name
        Set-PASAccount -AccountID $AccountID -op replace -path /name -value $NewName -ErrorAction Stop
        Write-Log "✅ Successfully updated PAS Account ID: ${AccountID} to '${NewName}'"
    } catch {
        Write-Log "❌ ERROR: Failed to update PAS Account ID: ${AccountID} - $_"
    }
}

Write-Log "🔹 Bulk PAS Account Name update process completed."
