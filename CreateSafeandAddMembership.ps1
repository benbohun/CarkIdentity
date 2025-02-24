# Import the psPAS Module
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

# Step 1: Define Required Variables (Prompt for Safe Name & Description)
$SafeName = Read-Host "Enter the Safe Name"
$Description = Read-Host "Enter the Safe Description"

# Ensure values are provided
if ([string]::IsNullOrEmpty($SafeName)) {
    Write-Log "❌ ERROR: Safe Name cannot be empty. Exiting..."
    exit
}

if ([string]::IsNullOrEmpty($Description)) {
    Write-Log "❌ ERROR: Safe Description cannot be empty. Exiting..."
    exit
}

# Step 2: Define CyberArk Authentication Variables
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

# Step 3: Request Initial Token
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

# Step 4: Define Headers for API Requests
$headers = @{
    "Authorization" = "Bearer $BearerToken"
    "Content-Type"  = "application/json"
}

# Step 5: Create Safe Using API
Write-Log "🔹 Creating Safe: ${SafeName}..."

# Construct API Endpoint
$APIEndpoint = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault/API/Safes/"

# Construct JSON Payload (Defaults Applied)
$SafePayload = @{
    "safeName"                  = $SafeName
    "description"               = $Description
    "olacEnabled"               = $false  # Default value
    "autoPurgeEnabled"          = $false  # Default value
    "managingCPM"               = "CNA_PASS_MANG"  # Default CPM
    "numberOfVersionsRetention" = 7  # Default retention policy
} | ConvertTo-Json -Depth 3

Write-Log "Creating Safe: ${SafeName} with payload: $SafePayload"

try {
    $Response = Invoke-RestMethod -Uri $APIEndpoint -Method Post -Headers $headers -Body $SafePayload -ErrorAction Stop
    Write-Log "✅ Successfully created Safe: ${SafeName}."
} catch {
    Write-Log "❌ ERROR: Failed to create Safe: ${SafeName} - $_"
}

Write-Log "🔹 Safe creation process completed."

