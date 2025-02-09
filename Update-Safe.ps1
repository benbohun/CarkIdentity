# Import the psPAS module
Import-Module psPAS

# Define Log File
$LogFile = "SafeMemberUpdateLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

# Authentication Variables
$PCloudSubdomain = "your-subdomain"  # Change this to your actual CyberArk ISPSS subdomain
$TenantID = "your-tenant-id"  # Replace with CyberArk Identity tenant ID
$ClientID = "api@cyberark.cloud"  # Replace with CyberArk API Client ID
$ClientSecret = "your-API-password"  # Replace with CyberArk API Client Secret
$TokenURL = "https://$TenantID.id.cyberark.cloud/oauth2/platformtoken"

# Request Initial Token (Step 1)
Write-Log "Requesting initial CyberArk ISPSS token..."
$Body = "grant_type=client_credentials&client_id=$ClientID&client_secret=$ClientSecret"
$headers = @{
    "Content-Type" = "application/x-www-form-urlencoded"
}

try {
    $TokenResponse = Invoke-RestMethod -Uri $TokenURL -Method Post -Headers $headers -Body $Body
    $BearerToken = [string]$TokenResponse.access_token  # Ensure token is a string
    Write-Log "Authentication successful, token obtained."
} catch {
    Write-Log "ERROR: Failed to authenticate with CyberArk ISPSS. $_"
    exit
}

# Define Headers for API Requests (Step 2)
$headers = @{
    "Authorization" = "Bearer $BearerToken"
    "Content-Type"  = "application/json"
}

# Define CSV File Path
$CsvFilePath = "C:\Path\To\SafeMembers.csv"

# Check if CSV file exists
if (-Not (Test-Path $CsvFilePath)) {
    Write-Log "ERROR: CSV file not found at $CsvFilePath"
    exit
}

# Load CSV
$SafeMembers = Import-Csv -Path $CsvFilePath

# Process each Safe member
foreach ($Member in $SafeMembers) {
    $SafeName = $Member.SafeName
    $MemberName = $Member.Member
    $MembershipExpirationDate = [int]$Member.MembershipExpirationDate  # Convert to integer

    # Verify if Safe Exists (Step 2)
    Write-Log "Checking if Safe '$SafeName' exists..."
    $SafeCheckURL = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault/WebServices/PIMServices.svc/Safes?query=$SafeName"

    try {
        $SafeResponse = Invoke-RestMethod -Uri $SafeCheckURL -Method Get -Headers $headers
        if ($SafeResponse.Safes -and $SafeResponse.Safes.Count -gt 0) {
            Write-Log "Safe '$SafeName' found, proceeding with update..."
        } else {
            Write-Log "ERROR: Safe '$SafeName' not found. Skipping update."
            continue
        }
    } catch {
        Write-Log "ERROR: Failed to verify Safe '$SafeName'. Skipping update. $_"
        continue
    }

    # Construct API URL for Safe Member Update
    $APIEndpoint = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault/API/Safes/$SafeName/Members/$MemberName"

    # Construct JSON Payload (matching API requirements)
    $jsonBody = @{
        "membershipExpirationDate" = $MembershipExpirationDate
        "permissions" = @{
            "useAccounts" = [boolean]($Member.UseAccounts -eq "TRUE")
            "retrieveAccounts" = [boolean]($Member.RetrieveAccounts -eq "TRUE")
            "listAccounts" = [boolean]($Member.ListAccounts -eq "TRUE")
            "addAccounts" = [boolean]($Member.AddAccounts -eq "TRUE")
            "updateAccountContent" = [boolean]($Member.UpdateAccountContent -eq "TRUE")
            "updateAccountProperties" = [boolean]($Member.UpdateAccountProperties -eq "TRUE")
            "requestsAuthorizationLevel1" = [boolean]($Member.RequestsAuthorizationLevel1 -eq "TRUE")
            "requestsAuthorizationLevel2" = [boolean]($Member.RequestsAuthorizationLevel2 -eq "TRUE")
        }
    } | ConvertTo-Json -Depth 3  # Convert to JSON format

    Write-Log "Updating Safe Member: $MemberName in Safe: $SafeName"

    try {
        # Execute API Request using PUT method (Step 3)
        $response = Invoke-RestMethod -Uri $APIEndpoint -Method Put -Headers $headers -Body $jsonBody -ErrorAction Stop
        Write-Log "Successfully updated permissions for $MemberName in $SafeName"
    } catch {
        Write-Log "ERROR: Failed to update permissions for $MemberName in $SafeName - $_"
    }
}

Write-Log "Safe member permission update process completed."
