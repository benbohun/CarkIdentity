if (-not (Get-Module -Name psPAS -ListAvailable)) {
    Write-Host "psPAS module not found. Installing..."
    Install-Module -Name psPAS -Force -Scope CurrentUser
}
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
    Start-Sleep -Seconds 5
    $session = Get-PASSession
    if (-not $session) {
        Throw "Authentication failed after retry. Exiting script."
    }
    Write-Host "Authentication successful, session established."
}

# Import Safe-Management.ps1 script
if (Test-Path "C:\Path\To\Safe-Management.ps1") {
    . "C:\Path\To\Safe-Management.ps1"
} else {
    Throw "Safe-Management.ps1 script not found. Exiting script."
}

# Read Safe Members Update CSV
if (Test-Path $CSVFilePath) {
    $SafeMembers = Import-Csv -Path $CSVFilePath
    if (-not ($SafeMembers | Get-Member -Name "SafeName")) {
        Throw "CSV file format is incorrect. Expected column: SafeName"
    }

    foreach ($Member in $SafeMembers) {
        # Log action
        Write-Host "Processing member $($Member.Member) for safe $($Member.SafeName)."

        # Update Safe Member Permissions using Set-SafeMember
        try {
            Set-SafeMember -SafeName $Member.SafeName -safeMember $Member.Member -updateMember:$true -deleteMember:$false -memberSearchInLocation $Member.MemberLocation -MemberType $Member.MemberType `
                -permUseAccounts ([bool]$Member.UseAccounts) -permRetrieveAccounts ([bool]$Member.RetrieveAccounts) -permListAccounts ([bool]$Member.ListAccounts) `
                -permAddAccounts ([bool]$Member.AddAccounts) -permUpdateAccountContent ([bool]$Member.UpdateAccountContent) -permUpdateAccountProperties ([bool]$Member.UpdateAccountProperties) `
                -permInitiateCPMManagement ([bool]$Member.InitiateCPMAccountManagementOperations) -permSpecifyNextAccountContent ([bool]$Member.SpecifyNextAccountContent) `
                -permRenameAccounts ([bool]$Member.RenameAccounts) -permDeleteAccounts ([bool]$Member.DeleteAccounts) -permUnlockAccounts ([bool]$Member.UnlockAccounts) `
                -permManageSafe ([bool]$Member.ManageSafe) -permManageSafeMembers ([bool]$Member.ManageSafeMembers) -permBackupSafe ([bool]$Member.BackupSafe) -permViewAuditLog ([bool]$Member.ViewAuditLog) `
                -permViewSafeMembers ([bool]$Member.ViewSafeMembers) -permRequestsAuthorizationLevel ([int]$Member.RequestsAuthorizationLevel) `
                -permAccessWithoutConfirmation ([bool]$Member.AccessWithoutConfirmation) -permCreateFolders ([bool]$Member.CreateFolders) -permDeleteFolders ([bool]$Member.DeleteFolders) `
                -permMoveAccountsAndFolders ([bool]$Member.MoveAccountsAndFolders)
        } catch {
            Write-Host "Error updating Safe Member: $($Member.Member) in Safe: $($Member.SafeName) - $_"
        }

        # Update Safe Member Permissions using Set-PASSafeMember (CyberArk Privilege Cloud)
        try {
            Set-PASSafeMember -SafeName $Member.SafeName -MemberName $Member.Member -MemberLocation $Member.MemberLocation -MemberType $Member.MemberType `
                -UseAccounts ([bool]$Member.UseAccounts) -RetrieveAccounts ([bool]$Member.RetrieveAccounts) -ListAccounts ([bool]$Member.ListAccounts) `
                -AddAccounts ([bool]$Member.AddAccounts) -UpdateAccountContent ([bool]$Member.UpdateAccountContent) -UpdateAccountProperties ([bool]$Member.UpdateAccountProperties) `
                -InitiateCPMAccountManagementOperations ([bool]$Member.InitiateCPMAccountManagementOperations) -SpecifyNextAccountContent ([bool]$Member.SpecifyNextAccountContent) `
                -RenameAccounts ([bool]$Member.RenameAccounts) -DeleteAccounts ([bool]$Member.DeleteAccounts) -UnlockAccounts ([bool]$Member.UnlockAccounts) `
                -ManageSafe ([bool]$Member.ManageSafe) -ManageSafeMembers ([bool]$Member.ManageSafeMembers) -BackupSafe ([bool]$Member.BackupSafe) -ViewAuditLog ([bool]$Member.ViewAuditLog) `
                -ViewSafeMembers ([bool]$Member.ViewSafeMembers) -RequestsAuthorizationLevel ([int]$Member.RequestsAuthorizationLevel) `
                -AccessWithoutConfirmation ([bool]$Member.AccessWithoutConfirmation) -CreateFolders ([bool]$Member.CreateFolders) -DeleteFolders ([bool]$Member.DeleteFolders) `
                -MoveAccountsAndFolders ([bool]$Member.MoveAccountsAndFolders)
            Write-Host "Updated Safe Member: $($Member.Member) in Safe: $($Member.SafeName)"
        } catch {
            Write-Host "Error updating Safe Member: $($Member.Member) in Safe: $($Member.SafeName) - $_"
        }
    }
    Write-Host "Bulk safe members update completed."
} else {
    Write-Host "CSV file not found: $CSVFilePath"
}

# End Session
try {
    Remove-PASSession -Session $header
    Write-Host "Session logged off successfully."
} catch {
    Write-Host "Error logging off session: $_"
}
