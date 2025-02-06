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
        Set-PASSafeMember -SafeName $Member.SafeName -MemberName $Member.Member -SearchIn $Member.MemberLocation -MemberType $Member.MemberType `
            -UseAccounts ([bool]$Member.UseAccounts) -RetrieveAccounts ([bool]$Member.RetrieveAccounts) -ListAccounts ([bool]$Member.ListAccounts) `
            -AddAccounts ([bool]$Member.AddAccounts) -UpdateAccountContent ([bool]$Member.UpdateAccountContent) -UpdateAccountProperties ([bool]$Member.UpdateAccountProperties) `
            -InitiateCPMAccountManagementOperations ([bool]$Member.InitiateCPMAccountManagementOperations) -SpecifyNextAccountContent ([bool]$Member.SpecifyNextAccountContent) `
            -RenameAccounts ([bool]$Member.RenameAccounts) -DeleteAccounts ([bool]$Member.DeleteAccounts) -UnlockAccounts ([bool]$Member.UnlockAccounts) `
            -ManageSafe ([bool]$Member.ManageSafe) -ManageSafeMembers ([bool]$Member.ManageSafeMembers) -BackupSafe ([bool]$Member.BackupSafe) -ViewAuditLog ([bool]$Member.ViewAuditLog) `
            -ViewSafeMembers ([bool]$Member.ViewSafeMembers) -RequestsAuthorizationLevel ([int]$Member.RequestsAuthorizationLevel) `
            -AccessWithoutConfirmation ([bool]$Member.AccessWithoutConfirmation) -CreateFolders ([bool]$Member.CreateFolders) -DeleteFolders ([bool]$Member.DeleteFolders) `
            -MoveAccountsAndFolders ([bool]$Member.MoveAccountsAndFolders)
        
        Write-Host "Updated Safe Member: $($Member.Member) in Safe: $($Member.SafeName)"
    }
    Write-Host "Bulk safe members update completed."
} else {
    Write-Host "CSV file not found: $CSVFilePath"
}

# End Session
Remove-PASSession -Session $header
Write-Host "Session logged off successfully."
