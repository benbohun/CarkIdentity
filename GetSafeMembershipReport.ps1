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

# Function to convert CSV values ("True", "False", "1", "0") to Boolean ($true, $false)
Function Convert-ToBool ($Value) {
    return ($Value -match "^(?i)True|1$") # Matches "True" or "1" (case-insensitive)
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

    # Handle Membership Expiration Date (Set to null if empty)
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
            # Update existing member permissions using Gen2 Syntax
            Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName -SearchIn $SearchIn -Permissions @{
                useAccounts = (Convert-ToBool $Entry.UseAccounts)
                retrieveAccounts = (Convert-ToBool $Entry.RetrieveAccounts)
                listAccounts = (Convert-ToBool $Entry.ListAccounts)
                addAccounts = (Convert-ToBool $Entry.AddAccounts)
                initiateCPMAccountManagementOperations = (Convert-ToBool $Entry.InitiateCPMAccountManagementOperations)
                specifyNextAccountContent = (Convert-ToBool $Entry.SpecifyNextAccountContent)
                renameAccounts = (Convert-ToBool $Entry.RenameAccounts)
                deleteAccounts = (Convert-ToBool $Entry.DeleteAccounts)
                unlockAccounts = (Convert-ToBool $Entry.UnlockAccounts)
                manageSafe = (Convert-ToBool $Entry.ManageSafe)
                backupSafe = (Convert-ToBool $Entry.BackupSafe)
                viewAuditLog = (Convert-ToBool $Entry.ViewAuditLog)
                viewSafeMembers = (Convert-ToBool $Entry.ViewSafeMembers)
                accessWithoutConfirmation = (Convert-ToBool $Entry.AccessWithoutConfirmation)
            }

            Write-Log "✅ Updated Member: $MemberName in Safe: $SafeName"
        } else {
            # Add new member with explicit permissions using Gen2 Syntax
            Add-PASSafeMember -SafeName $SafeName -MemberName $MemberName -SearchIn $SearchIn -Permissions @{
                useAccounts = (Convert-ToBool $Entry.UseAccounts)
                retrieveAccounts = (Convert-ToBool $Entry.RetrieveAccounts)
                listAccounts = (Convert-ToBool $Entry.ListAccounts)
                addAccounts = (Convert-ToBool $Entry.AddAccounts)
                initiateCPMAccountManagementOperations = (Convert-ToBool $Entry.InitiateCPMAccountManagementOperations)
                specifyNextAccountContent = (Convert-ToBool $Entry.SpecifyNextAccountContent)
                renameAccounts = (Convert-ToBool $Entry.RenameAccounts)
                deleteAccounts = (Convert-ToBool $Entry.DeleteAccounts)
                unlockAccounts = (Convert-ToBool $Entry.UnlockAccounts)
                manageSafe = (Convert-ToBool $Entry.ManageSafe)
                backupSafe = (Convert-ToBool $Entry.BackupSafe)
                viewAuditLog = (Convert-ToBool $Entry.ViewAuditLog)
                viewSafeMembers = (Convert-ToBool $Entry.ViewSafeMembers)
                accessWithoutConfirmation = (Convert-ToBool $Entry.AccessWithoutConfirmation)
            }

            Write-Log "✅ Added Member: $MemberName to Safe: $SafeName"
        }

    } catch {
        Write-Log "❌ ERROR: Failed to add/update Member: $MemberName in Safe: $SafeName - $_"
        Write-FailLog -SafeName $SafeName -MemberName $MemberName
    }
}

Write-Log "🔹 Safe member addition/update process completed."
Write-Log "📌 Check $FailedLogFile for any failed operations."
