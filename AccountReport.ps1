# Import the psPAS module
Import-Module psPAS

# Define Log File
$LogFile = "CyberArkAccountsReportLog.txt"
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

# Step 4: Set API Parameters for Searching & Filtering
$SearchQuery = "*"  # Use * for all accounts, or specify a keyword
$SearchType = "contains"  # Other options: "startswith", "endswith", "equals"
$SortBy = "name"  # Other options: "address", "userName", etc.
$Offset = 0  # Start from first result
$Limit = 1000  # Adjust limit based on expected results
$Filter = ""  # Optional: Apply filters based on properties (e.g., "platformId eq 'Windows'")

# Construct API URL
$APIEndpoint = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault/API/Accounts?search=$SearchQuery&searchType=$SearchType&sort=$SortBy&offset=$Offset&limit=$Limit&filter=$Filter"

Write-Log "Retrieving CyberArk accounts from: $APIEndpoint"

# Step 5: Retrieve Account Data
try {
    $AccountsResponse = Invoke-RestMethod -Uri $APIEndpoint -Method Get -Headers $headers -ErrorAction Stop
    $Accounts = $AccountsResponse.value

    if ($Accounts.Count -eq 0) {
        Write-Log "No accounts found in CyberArk."
        exit
    }

    Write-Log "Retrieved $($Accounts.Count) accounts from CyberArk."

    # Step 6: Export to CSV
    $CsvFilePath = "C:\Path\To\CyberArkAccountsReport.csv"  # Update this path as needed
    $Accounts | Export-Csv -Path $CsvFilePath -NoTypeInformation

    Write-Log "✅ Successfully exported accounts to: $CsvFilePath"

} catch {
    Write-Log "❌ ERROR: Failed to retrieve accounts from CyberArk - $_"
    exit
}

Write-Log "🔹 CyberArk accounts retrieval process completed."
