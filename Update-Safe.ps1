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
    try {
        $header = Get-IdentityHeader -IdentityTenantURL $TenantURL -psPASFormat -PCloudSubdomain $PCloudSubdomain -UPCreds $UPCreds
        Use-PASSession $header
        $session = Get-PASSession
        if (-not $session) {
            Throw "Authentication failed. Exiting script."
        }
        Write-Host "Authentication successful, session established."
    } catch {
        Write-Host "Error during authentication: $_"
        exit 1
    }
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

        # Update Safe Member Permissions using Set-PASSafeMember
        try {
            Set-PASSafeMember -SafeName $Member.SafeName -MemberName $Member.Member -MemberType $Member.MemberType `
                -UseAccounts ([System.Convert]::ToBoolean($Member.UseAccounts)) `
                -RetrieveAccounts ([System.Convert]::ToBoolean($Member.RetrieveAccounts)) `
                -ListAccounts ([System.Convert]::ToBoolean($Member.ListAccounts)) `
                -AddAccounts ([System.Convert]::ToBoolean($Member.AddAccounts)) `
                -UpdateAccountContent ([System.Convert]::ToBoolean($Member.UpdateAccountContent)) `
                -UpdateAccountProperties ([System.Convert]::ToBoolean($Member.UpdateAccountProperties)) `
                -InitiateCPMAccountManagementOperations ([System.Convert]::ToBoolean($Member.InitiateCPMAccountManagementOperations)) `
                -SpecifyNextAccountContent ([System.Convert]::ToBoolean($Member.SpecifyNextAccountContent)) `
                -RenameAccounts ([System.Convert]::ToBoolean($Member.RenameAccounts)) `
                -DeleteAccounts ([System.Convert]::ToBoolean($Member.DeleteAccounts)) `
                -UnlockAccounts ([System.Convert]::ToBoolean($Member.UnlockAccounts)) `
                -ManageSafe ([System.Convert]::ToBoolean($Member.ManageSafe)) `
                -ManageSafeMembers ([System.Convert]::ToBoolean($Member.ManageSafeMembers)) `
                -BackupSafe ([System.Convert]::ToBoolean($Member.BackupSafe)) `
                -ViewAuditLog ([System.Convert]::ToBoolean($Member.ViewAuditLog)) `
                -ViewSafeMembers ([System.Convert]::ToBoolean($Member.ViewSafeMembers)) `
                -RequestsAuthorizationLevel ([int]$Member.RequestsAuthorizationLevel) `
                -AccessWithoutConfirmation ([System.Convert]::ToBoolean($Member.AccessWithoutConfirmation)) `
                -CreateFolders ([System.Convert]::ToBoolean($Member.CreateFolders)) `
                -DeleteFolders ([System.Convert]::ToBoolean($Member.DeleteFolders)) `
                -MoveAccountsAndFolders ([System.Convert]::ToBoolean($Member.MoveAccountsAndFolders))

            Write-Host "Successfully updated Safe Member: $($Member.Member) in Safe: $($Member.SafeName)"
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
    if ($session) {
        Write-Host "Logging off session..."
        Disconnect-PASSession
        Write-Host "Session logged off successfully."
    }
} catch {
    Write-Host "Error logging off session: $_"
}
