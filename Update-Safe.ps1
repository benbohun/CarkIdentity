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

# Function to update Safe Members in bulk
function Update-SafeMembers {
    param (
        [string]$CSVFilePath
    )
    if (Test-Path $CSVFilePath) {
        $SafeMembers = Import-Csv -Path $CSVFilePath

        foreach ($Member in $SafeMembers) {
            # Update Safe Member Permissions
            Set-PASSafeMember -SafeName $Member.SafeName -MemberName $Member.Member -MemberLocation $Member.MemberLocation -MemberType $Member.MemberType `
                -UseAccounts $Member.UseAccounts -RetrieveAccounts $Member.RetrieveAccounts -ListAccounts $Member.ListAccounts `
                -AddAccounts $Member.AddAccounts -UpdateAccountContent $Member.UpdateAccountContent -UpdateAccountProperties $Member.UpdateAccountProperties `
                -InitiateCPMAccountManagementOperations $Member.InitiateCPMAccountManagementOperations -SpecifyNextAccountContent $Member.SpecifyNextAccountContent `
                -RenameAccounts $Member.RenameAccounts -DeleteAccounts $Member.DeleteAccounts -UnlockAccounts $Member.UnlockAccounts `
                -ManageSafe $Member.ManageSafe -ManageSafeMembers $Member.ManageSafeMembers -BackupSafe $Member.BackupSafe -ViewAuditLog $Member.ViewAuditLog `
                -ViewSafeMembers $Member.ViewSafeMembers -RequestsAuthorizationLevel $Member.RequestsAuthorizationLevel `
                -AccessWithoutConfirmation $Member.AccessWithoutConfirmation -CreateFolders $Member.CreateFolders -DeleteFolders $Member.DeleteFolders `
                -MoveAccountsAndFolders $Member.MoveAccountsAndFolders
            
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
