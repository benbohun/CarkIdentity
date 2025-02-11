# Import the psPAS module
Import-Module psPAS

# Define Log File
$LogFile = "AccountUpdateLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

# Step 1: Define Required Variables (Prompt only for Client ID & Secret)
$IdentityTenantID = "your-identity-tenant-id"  # Replace with actual CyberArk Identity tenant ID
$PCloudSubdomain = "your-pcloud-subdomain"  # Replace with actual CyberArk Privilege Cloud Subdomain
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
    Write-Log "Authentication successful, token obtained."
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
$CsvFilePath = "C:\Path\To\AccountUpdates.csv"  # Update this path to your actual CSV file

# Check if CSV file exists
if (-Not (Test-Path $CsvFilePath)) {
    Write-Log "ERROR: CSV file not found at $CsvFilePath"
    exit
}

# Load CSV
$Accounts = Import-Csv -Path $CsvFilePath

# Process each Account update
foreach ($Account in $Accounts) {
    $AccountID = $Account.AccountID
    $NewName = $Account.Name  # Use Name from CSV as the new account name

    # Step 5: Construct API URL for Updating Account Name
    $APIEndpoint = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault/API/Accounts/$AccountID/"

    # Step 6: Construct JSON Payload for PATCH request (Updating only Name)
    $jsonBody = @(
        @{
            "op" = "replace"
            "path" = "/name"
            "value" = $NewName
        }
    ) | ConvertTo-Json -Depth 3 -Compress  # Use compressed JSON format

    Write-Log "Updating Name for Account ID: ${AccountID} to '${NewName}'"
    Write-Log "Payload Sent: $jsonBody"

    try {
        # Step 7: Execute API Request using PATCH method
        $response = Invoke-RestMethod -Uri $APIEndpoint -Method Patch -Headers $headers -Body $jsonBody -ErrorAction Stop
        Write-Log "✅ Successfully updated Name for Account ID: ${AccountID} to '${NewName}'"
    } catch {
        Write-Log "❌ ERROR: Failed to update Name for Account ID: ${AccountID} - $_"
    }
}

Write-Log "🔹 Bulk Account Name update process completed."
