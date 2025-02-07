if (-not (Get-Module -Name psPAS -ListAvailable)) {
    Write-Host "psPAS module not found. Installing..."
    Install-Module -Name psPAS -Force -Scope CurrentUser
}
Import-Module psPAS

# Define parameters
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$CSVFilePath = "C:\Temp\SafeMembersUpdate.csv"  # Path to CSV file with safe members

# Check if session is already active
$session = Get-PASSession -ErrorAction SilentlyContinue
if (-not $session) {
    # Prompt for user credentials
    $UPCreds = Get-Credential

    # Authenticate and establish a session
    $header = Get-IdentityHeader -IdentityTenantURL $TenantURL -psPASFormat -PCloudSubdomain $PCloudSubdomain -UPCreds $UPCreds
    Use-PASSession $header

    # Verify session
    $session = Get-PASSession
    if (-not $session) {
        Throw "Authentication failed. Exiting script."
    }
    Write-Host "Authentication successful, session established."
} else {
    Write-Host "Existing session detected, reusing session."
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
