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
$PCloudSubdomain = "your-subdomain"  # Change this to your actual subdomain
$TenantURL = "https://$PCloudSubdomain.privilegecloud.cyberark.cloud/PasswordVault"
$UPCreds = Get-Credential

# Authenticate and start session
Write-Log "Starting CyberArk Authentication..."
$session = New-PASSession -Credential $UPCreds -BaseURI $TenantURL
if ($session) {
    Write-Log "Authentication successful, session established."
} else {
    Write-Log "ERROR: Authentication failed. Exiting script."
    exit
}

# Extract Token for API Calls
$AuthToken = $session.Token
$headers = @{
    "Authorization" = "Bearer $AuthToken"
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

    # URL-encode SafeName
    $SafeUrlId = [System.Web.HttpUtility]::UrlEncode($SafeName)

    # Construct API URL
    $APIEndpoint = "$TenantURL/API/Safes/$SafeUrlId/Members/$MemberName"

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
            "initiateCPMAccountManagementOperations" = [boolean]($Member.InitiateCPMAccountManagementOperations -eq "TRUE")
            "specifyNextAccountContent" = [boolean]($Member.SpecifyNextAccountContent -eq "TRUE")
            "renameAccounts" = [boolean]($Member.RenameAccounts -eq "TRUE")
            "deleteAccounts" = [boolean]($Member.DeleteAccounts -eq "TRUE")
            "unlockAccounts" = [boolean]($Member.UnlockAccounts -eq "TRUE")
            "manageSafe" = [boolean]($Member.ManageSafe -eq "TRUE")
            "manageSafeMembers" = [boolean]($Member.ManageSafeMembers -eq "TRUE")
            "backupSafe" = [boolean]($Member.BackupSafe -eq "TRUE")
            "viewAuditLog" = [boolean]($Member.ViewAuditLog -eq "TRUE")
            "viewSafeMembers" = [boolean]($Member.ViewSafeMembers -eq "TRUE")
            "accessWithoutConfirmation" = [boolean]($Member.AccessWithoutConfirmation -eq "TRUE")
            "createFolders" = [boolean]($Member.CreateFolders -eq "TRUE")
            "deleteFolders" = [boolean]($Member.DeleteFolders -eq "TRUE")
            "moveAccountsAndFolders" = [boolean]($Member.MoveAccountsAndFolders -eq "TRUE")
            "requestsAuthorizationLevel1" = [boolean]($Member.RequestsAuthorizationLevel1 -eq "TRUE")
            "requestsAuthorizationLevel2" = [boolean]($Member.RequestsAuthorizationLevel2 -eq "TRUE")
        }
    } | ConvertTo-Json -Depth 3  # Convert to JSON format

    Write-Log "Updating Safe Member: $MemberName in Safe: $SafeName"

    try {
        # Execute API Request using PUT method
        $response = Invoke-RestMethod -Uri $APIEndpoint -Method Put -Headers $headers -Body $jsonBody -ErrorAction Stop
        Write-Log "Successfully updated permissions for $MemberName in $SafeName"
    }
    catch {
        Write-Log "ERROR: Failed to update permissions for $MemberName in $SafeName - $_"
    }
}

# End session
Write-Log "Safe member permission update process completed."
