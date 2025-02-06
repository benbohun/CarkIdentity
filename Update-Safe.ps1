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

# Import Safe-Management.ps1 script
. "C:\Path\To\Safe-Management.ps1"

# Read Safe Members Update CSV
if (Test-Path $CSVFilePath) {
    $SafeMembers = Import-Csv -Path $CSVFilePath

    foreach ($Member in $SafeMembers) {
        # Update Safe Member Permissions
        Set-PASSafeMember -SafeName $Member.SafeName -MemberName $Member.Member -MemberType $Member.MemberType `
            -UseAccounts ([bool]::Parse($Member.UseAccounts)) -RetrieveAccounts ([bool]::Parse($Member.RetrieveAccounts)) -ListAccounts ([bool]::Parse($Member.ListAccounts)) `
            -AddAccounts ([bool]::Parse($Member.AddAccounts)) -UpdateAccountContent ([bool]::Parse($Member.UpdateAccountContent)) -UpdateAccountProperties ([bool]::Parse($Member.UpdateAccountProperties)) `
            -InitiateCPMAccountManagementOperations ([bool]::Parse($Member.InitiateCPMAccountManagementOperations)) -SpecifyNextAccountContent ([bool]::Parse($Member.SpecifyNextAccountContent)) `
            -RenameAccounts ([bool]::Parse($Member.RenameAccounts)) -DeleteAccounts ([bool]::Parse($Member.DeleteAccounts)) -UnlockAccounts ([bool]::Parse($Member.UnlockAccounts)) `
            -ManageSafe ([bool]::Parse($Member.ManageSafe)) -ManageSafeMembers ([bool]::Parse($Member.ManageSafeMembers)) -BackupSafe ([bool]::Parse($Member.BackupSafe)) -ViewAuditLog ([bool]::Parse($Member.ViewAuditLog)) `
            -ViewSafeMembers ([bool]::Parse($Member.ViewSafeMembers)) -RequestsAuthorizationLevel ([int]::Parse($Member.RequestsAuthorizationLevel)) `
            -AccessWithoutConfirmation ([bool]::Parse($Member.AccessWithoutConfirmation)) -CreateFolders ([bool]::Parse($Member.CreateFolders)) -DeleteFolders ([bool]::Parse($Member.DeleteFolders)) `
            -MoveAccountsAndFolders ([bool]::Parse($Member.MoveAccountsAndFolders))
        
        Write-Host "Updated Safe Member: $($Member.Member) in Safe: $($Member.SafeName)"
    }
    Write-Host "Bulk safe members update completed."
} else {
    Write-Host "CSV file not found: $CSVFilePath"
}

# End Session
Remove-PASSession -Session $header
Write-Host "Session logged off successfully."
