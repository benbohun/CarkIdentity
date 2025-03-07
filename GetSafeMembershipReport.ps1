# Import the psPAS Module
Import-Module psPAS

# Define Log Files
$LogFile = "SafeMemberAdditionLog.txt"
$FailedLogFile = "FailToAddSafeMember.txt"

Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

Function Write-FailLog {
    Param ([string]$SafeName, [string]$MemberName)
    $FailedEntry = "$SafeName,$MemberName"
    Add-Content -Path $FailedLogFile -Value $FailedEntry
    Write-Output "❌ Failed to add/update Safe member: $SafeName - $MemberName"
}

# Function to convert string values to boolean
Function Convert-ToBool ($Value) {
    if ($Value -match "^(True|1)$") { return $true }
    elseif ($Value -match "^(False|0)$") { return $false }
    else { return $false }  # Default to false if invalid
}

# Step 1: Authenticate Using psPAS
Write-Log "Requesting CyberArk PAS authentication..."
$header = Get-IdentityHeader -IdentityTenantURL "aat4012.id.cyberark.cloud" -psPASFormat -PCloudSubdomain "cna-prod" -UPCreds $UPCred

# Register the PAS session
use-PASSession $header

# Validate the session
$session = Get-PASSession
if ($session) {
    Write-Log "✅ Authentication successful, PAS session established."
} else {
    Write-Log "❌ Authentication failed. Exiting script."
    exit
}

# Step 2: Load the CSV File with Safe Members to Add/Update
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeMembersToAdd.csv"

if (!(Test-Path $CsvFilePath)) {
    Write-Log "❌ ERROR: CSV file not found at $CsvFilePath. Exiting script."
    exit
}

$SafeMembersToAdd = Import-Csv -Path $CsvFilePath

if ($SafeMembersToAdd.Count -eq 0) {
    Write-Log "❌ ERROR: No Safe members found in the CSV file. Exiting script."
    exit
}

Write-Log "✅ Loaded $($SafeMembersToAdd.Count) Safe members from CSV for processing."

# Step 3: Process Safe Members
foreach ($Entry in $SafeMembersToAdd) {
    $SafeName = $Entry.SafeName
    $MemberName = $Entry.MemberName
    $SearchIn = $Entry.SearchIn  # e.g., "Vault", "LDAP"

    if (-not $SafeName -or -not $MemberName) {
        Write-Log "⚠️ WARNING: Missing SafeName or MemberName in CSV. Skipping..."
        continue
    }

    # Step 3a: Check if Safe Exists
    $SafeExists = Get-PASSafe -SafeName $SafeName -ErrorAction SilentlyContinue
    if (-not $SafeExists) {
        Write-Log "❌ ERROR: Safe $SafeName does not exist. Skipping..."
        Write-FailLog -SafeName $SafeName -MemberName $MemberName
        continue
    }

    Write-Log "🔹 Processing Safe: $SafeName for Member: $MemberName"

    # Step 3b: Check if Member Already Exists
    $ExistingMember = Get-PASSafeMember -SafeName $SafeName | Where-Object { $_.MemberName -eq $MemberName }

    # Handle Membership Expiration Date
    $MembershipExpirationDate = $null
    if ($Entry.MembershipExpirationDate -match '^\d{4}-\d{2}-\d{2}$') {
        try {
            $MembershipExpirationDate = [datetime]::ParseExact($Entry.MembershipExpirationDate, "yyyy-MM-dd", $null)
        } catch {
            Write-Log "⚠️ WARNING: Invalid MembershipExpirationDate for $MemberName in Safe $SafeName. Skipping date."
            $MembershipExpirationDate = $null
        }
    }

    try {
        if ($ExistingMember) {
            # Update existing member permissions
            Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName `
                -UseAccounts (Convert-ToBool $Entry.UseAccounts) `
                -RetrieveAccounts (Convert-ToBool $Entry.RetrieveAccounts) `
                -ListAccounts (Convert-ToBool $Entry.ListAccounts) `
                -AddAccounts (Convert-ToBool $Entry.AddAccounts) `
                -UpdateAccountContent (Convert-ToBool $Entry.UpdateAccountContent) `
                -UpdateAccountProperties (Convert-ToBool $Entry.UpdateAccountProperties) `
                -InitiateCPMAccountManagementOperations (Convert-ToBool $Entry.InitiateCPMAccountManagementOperations) `
                -SpecifyNextAccountContent (Convert-ToBool $Entry.SpecifyNextAccountContent) `
                -RenameAccounts (Convert-ToBool $Entry.RenameAccounts) `
                -DeleteAccounts (Convert-ToBool $Entry.DeleteAccounts) `
                -UnlockAccounts (Convert-ToBool $Entry.UnlockAccounts) `
                -ManageSafe (Convert-ToBool $Entry.ManageSafe) `
                -ManageSafeMembers (Convert-ToBool $Entry.ManageSafeMembers) `
                -BackupSafe (Convert-ToBool $Entry.BackupSafe) `
                -ViewAuditLog (Convert-ToBool $Entry.ViewAuditLog) `
                -ViewSafeMembers (Convert-ToBool $Entry.ViewSafeMembers) `
                -AccessWithoutConfirmation (Convert-ToBool $Entry.AccessWithoutConfirmation) `
                -CreateFolders (Convert-ToBool $Entry.CreateFolders) `
                -DeleteFolders (Convert-ToBool $Entry.DeleteFolders) `
                -MoveAccountsAndFolders (Convert-ToBool $Entry.MoveAccountsAndFolders) `
                -RequestsAuthorizationLevel1 (Convert-ToBool $Entry.RequestsAuthorizationLevel1) `
                -RequestsAuthorizationLevel2 (Convert-ToBool $Entry.RequestsAuthorizationLevel2)

            Write-Log "✅ Updated Member: $MemberName in Safe: $SafeName"
        } else {
            # Add new member
            Add-PASSafeMember -SafeName $SafeName -MemberName $MemberName -SearchIn $SearchIn `
                -UseAccounts (Convert-ToBool $Entry.UseAccounts) `
                -RetrieveAccounts (Convert-ToBool $Entry.RetrieveAccounts) `
                -ListAccounts (Convert-ToBool $Entry.ListAccounts) `
                -AddAccounts (Convert-ToBool $Entry.AddAccounts) `
                -UpdateAccountContent (Convert-ToBool $Entry.UpdateAccountContent) `
                -UpdateAccountProperties (Convert-ToBool $Entry.UpdateAccountProperties) `
                -InitiateCPMAccountManagementOperations (Convert-ToBool $Entry.InitiateCPMAccountManagementOperations) `
                -SpecifyNextAccountContent (Convert-ToBool $Entry.SpecifyNextAccountContent) `
                -RenameAccounts (Convert-ToBool $Entry.RenameAccounts) `
                -DeleteAccounts (Convert-ToBool $Entry.DeleteAccounts) `
                -UnlockAccounts (Convert-ToBool $Entry.UnlockAccounts) `
                -ManageSafe (Convert-ToBool $Entry.ManageSafe) `
                -ManageSafeMembers (Convert-ToBool $Entry.ManageSafeMembers) `
                -BackupSafe (Convert-ToBool $Entry.BackupSafe) `
                -ViewAuditLog (Convert-ToBool $Entry.ViewAuditLog) `
                -ViewSafeMembers (Convert-ToBool $Entry.ViewSafeMembers) `
                -AccessWithoutConfirmation (Convert-ToBool $Entry.AccessWithoutConfirmation)

            Write-Log "✅ Added Member: $MemberName to Safe: $SafeName"
        }

    } catch {
        Write-Log "❌ ERROR: Failed to add/update Member: $MemberName in Safe: $SafeName - $_"
        Write-FailLog -SafeName $SafeName -MemberName $MemberName
    }
}

Write-Log "🔹 Safe member addition/update process completed."
