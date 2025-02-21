# Import the psPAS module
Import-Module psPAS

# Define Log File
$LogFile = "SafeCreationLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

# Step 1: Define Required Variables (Prompt only for Client ID & Secret)
$IdentityTenantID = "aat4012"  # Replace with actual CyberArk Identity tenant ID
$PCloudSubdomain = "cna-prod"  # Replace with actual CyberArk Privilege Cloud Subdomain
$ClientID = Read-Host "Enter your CyberArk API Client ID"
$ClientSecret = Read-Host "Enter your CyberArk API Client Secret" -AsSecureString
$ClientSecret = [System.Net.NetworkCredential]::new("", $ClientSecret).Password  # Convert SecureString to plain text

# Ensure variables are set correctly
if ([string]::IsNullOrEmpty($ClientID) -or [string]::IsNullOrEmpty($ClientSecret)) {
    Write-Log "ERROR: Client ID or Client Secret is missing. Exiting..."
    exit
}

# Step 2: Request Initial Token
Write-Log "Requesting initial CyberArk ISPSS token..."
$TokenURL = "https://$IdentityTenantID.id.cyberark.cloud/oauth2/platformtoken"

$TokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientID
    client_secret = $ClientSecret
}

$headers = @{
    "Content-Type" = "application/x-www-form-urlencoded"
}

try {
    $TokenResponse = Invoke-RestMethod -Uri $TokenURL -Method Post -Headers $headers -Body $TokenBody
    $BearerToken = [string]$TokenResponse.access_token  # Ensure token is a string

    # Ensure Token is Valid
    if ([string]::IsNullOrEmpty($BearerToken) -or $BearerToken.Length -lt 100) {
        Write-Log "ERROR: Received an invalid token. Length: $($BearerToken.Length)"
        exit
    }
    Write-Log "✅ Authentication successful, token obtained."
} catch {
    Write-Log "ERROR: Failed to authenticate with CyberArk ISPSS. $_"
    exit
}

# Step 3: Define Headers for API Requests
$headers = @{
    "Authorization" = "Bearer $BearerToken"
    "Content-Type"  = "application/json"
}

# Step 4: Load CSV File (Hardcoded Path)
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\addsafe.csv"  # Update this path to your actual CSV file

# Check if CSV file exists
if (-Not (Test-Path $CsvFilePath)) {
    Write-Log "ERROR: CSV file not found at $CsvFilePath"
    exit
}

# Load CSV
$SafeData = Import-Csv -Path $CsvFilePath

# Step 5: Create Safes Using API
foreach ($Safe in $SafeData) {
    $SafeName = $Safe.SafeName.Trim()
    $ManagingCPM = $Safe.ManagingCPM.Trim()
    $Description = $Safe.Description.Trim()
    
    # Ensure required parameters are present
    if ([string]::IsNullOrEmpty($SafeName) -or [string]::IsNullOrEmpty($ManagingCPM)) {
        Write-Log "❌ ERROR: SafeName or ManagingCPM missing for an entry. Skipping..."
        continue
    }

    # Convert Boolean & Integer Values
    $OLACEnabled = [System.Convert]::ToBoolean($Safe.OLACEnabled)
    $AutoPurgeEnabled = [System.Convert]::ToBoolean($Safe.AutoPurgeEnabled)
    $NumberOfVersionsRetention = [math]::Min([int]$Safe.NumberOfVersionsRetention, 999)
    $NumberOfDaysRetention = [math]::Min([int]$Safe.NumberOfDaysRetention, 3650)

    # Construct API Endpoint
    $APIEndpoint = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault/API/Safes/"

    # Construct JSON Payload
    $SafePayload = @{
        "safeName" = $SafeName
        "description" = $Description
        "olacEnabled" = $OLACEnabled
        "managingCPM" = $ManagingCPM
        "numberOfVersionsRetention" = $NumberOfVersionsRetention
        "numberOfDaysRetention" = $NumberOfDaysRetention
        "autoPurgeEnabled" = $AutoPurgeEnabled
    } | ConvertTo-Json -Depth 3

    Write-Log "Creating Safe: ${SafeName}..."

    try {
        $Response = Invoke-RestMethod -Uri $APIEndpoint -Method Post -Headers $headers -Body $SafePayload -ErrorAction Stop
        Write-Log "✅ Successfully created Safe: ${SafeName}."
    } catch {
        Write-Log "❌ ERROR: Failed to create Safe: ${SafeName} - $_"
    }
}

Write-Log "🔹 Safe creation process completed."
