Import-Module psPAS

# Define parameters
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$CSVFilePath = "C:\Temp\SafeMembersUpdate.csv"  # Path to CSV file with safe members

# Prompt for user credentials
$UPCreds = Get-Credential

# Authenticate and establish a session
$header = Get-IdentityHeader -IdentityTenantURL $TenantURL -psPASFormat -PCloudSubdomain $PCloudSubdomain -UPCreds $UPCreds
Use-PASSession $header

# Verify session
$session = Get-PASSession
if ($session) {
    Write-Host "Authentication successful, session established."
} else {
    Throw "Authentication failed. Exiting script."
}

# Function to convert CSV string values to Boolean
function Convert-ToBoolean {
    param ([string]$value)
    return $value -match "^(True|1)$"
}

# Function to safely convert RequestsAuthorizationLevel to integer
function Convert-ToInt {
    param ([string]$value)
    if ($value -match "^\d+$") {
        return [int]$value
    } else {
        return 0  # Default to 0 if invalid
    }
}

# Function to update Safe Members in bulk
function Update-SafeMembers {
    param (
        [string]$CSVFilePath
    )
    if (Test-Path $CSVFilePath) {
        $SafeMembers = Import-Csv -Path $CSVFilePath

        foreach ($Member in $SafeMembers) {
            # Convert CSV values to Boolean and Integer where necessary
            Set-PASSafeMember -SafeName $Member.SafeName -MemberName $Member.Member -MemberLocation $Member.MemberLocation -MemberType $Member.MemberType `
                -UseAccounts (Convert-ToBoolean $Member.UseAccounts) -RetrieveAccounts (Convert-ToBoolean $Member.RetrieveAccounts) -ListAccounts (Convert-ToBoolean $Member.ListAccounts) `
                -AddAccounts (Convert-ToBoolean $Member.AddAccounts) -UpdateAccountContent (Convert-ToBoolean $Member.UpdateAccountContent) -UpdateAccountProperties (Convert-ToBoolean $Member.UpdateAccountProperties) `
                -InitiateCPMAccountManagementOperations (Convert-ToBoolean $Member.InitiateCPMAccountManagementOperations) -SpecifyNextAccountContent (Convert-ToBoolean $Member.SpecifyNextAccountContent) `
                -RenameAccounts (Convert-ToBoolean $Member.RenameAccounts) -DeleteAccounts (Convert-ToBoolean $Member.DeleteAccounts) -UnlockAccounts (Convert-ToBoolean $Member.UnlockAccounts) `
                -ManageSafe (Convert-ToBoolean $Member.ManageSafe) -ManageSafeMembers (Convert-ToBoolean $Member.ManageSafeMembers) -BackupSafe (Convert-ToBoolean $Member.BackupSafe) -ViewAuditLog (Convert-ToBoolean $Member.ViewAuditLog) `
                -ViewSafeMembers (Convert-ToBoolean $Member.ViewSafeMembers) -RequestsAuthorizationLevel (Convert-ToInt $Member.RequestsAuthorizationLevel) `
                -AccessWithoutConfirmation (Convert-ToBoolean $Member.AccessWithoutConfirmation) -CreateFolders (Convert-ToBoolean $Member.CreateFolders) -DeleteFolders (Convert-ToBoolean $Member.DeleteFolders) `
                -MoveAccountsAndFolders (Convert-ToBoolean $Member.MoveAccountsAndFolders)
            
            Write-Host "Updated Safe Member: $($Member.Member) in Safe: $($Member.SafeName)"
        }
        Write-Host "Bulk safe members update completed."
    } else {
        Write-Host "CSV file not found: $CSVFilePath"
    }
}

# Execute bulk update
Update-SafeMembers -CSVFilePath $CSVFilePath

# End Session
Close-PASSession
Write-Host "Session logged off successfully."
