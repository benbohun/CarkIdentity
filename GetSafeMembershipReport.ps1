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
                -UseAccounts $Entry.UseAccounts `
                -RetrieveAccounts $Entry.RetrieveAccounts `
                -ListAccounts $Entry.ListAccounts `
                -AddAccounts $Entry.AddAccounts `
                -UpdateAccountContent $Entry.UpdateAccountContent `
                -UpdateAccountProperties $Entry.UpdateAccountProperties `
                -InitiateCPMAccountManagementOperations $Entry.InitiateCPMAccountManagementOperations `
                -SpecifyNextAccountContent $Entry.SpecifyNextAccountContent `
                -RenameAccounts $Entry.RenameAccounts `
                -DeleteAccounts $Entry.DeleteAccounts `
                -UnlockAccounts $Entry.UnlockAccounts `
                -ManageSafe $Entry.ManageSafe `
                -ManageSafeMembers $Entry.ManageSafeMembers `
                -BackupSafe $Entry.BackupSafe `
                -ViewAuditLog $Entry.ViewAuditLog `
                -ViewSafeMembers $Entry.ViewSafeMembers `
                -AccessWithoutConfirmation $Entry.AccessWithoutConfirmation `
                -CreateFolders $Entry.CreateFolders `
                -DeleteFolders $Entry.DeleteFolders `
                -MoveAccountsAndFolders $Entry.MoveAccountsAndFolders `
                -RequestsAuthorizationLevel1 $Entry.RequestsAuthorizationLevel1 `
                -RequestsAuthorizationLevel2 $Entry.RequestsAuthorizationLevel2

            Write-Log "✅ Updated Member: $MemberName in Safe: $SafeName"
        } else {
            # Add new member
            Add-PASSafeMember -SafeName $SafeName -MemberName $MemberName -SearchIn $SearchIn `
                -UseAccounts $Entry.UseAccounts `
                -RetrieveAccounts $Entry.RetrieveAccounts `
                -ListAccounts $Entry.ListAccounts `
                -AddAccounts $Entry.AddAccounts `
                -UpdateAccountContent $Entry.UpdateAccountContent `
                -UpdateAccountProperties $Entry.UpdateAccountProperties `
                -InitiateCPMAccountManagementOperations $Entry.InitiateCPMAccountManagementOperations `
                -SpecifyNextAccountContent $Entry.SpecifyNextAccountContent `
                -RenameAccounts $Entry.RenameAccounts `
                -DeleteAccounts $Entry.DeleteAccounts `
                -UnlockAccounts $Entry.UnlockAccounts `
                -ManageSafe $Entry.ManageSafe `
                -ManageSafeMembers $Entry.ManageSafeMembers `
                -BackupSafe $Entry.BackupSafe `
                -ViewAuditLog $Entry.ViewAuditLog `
                -ViewSafeMembers $Entry.ViewSafeMembers `
                -AccessWithoutConfirmation $Entry.AccessWithoutConfirmation `
                -CreateFolders $Entry.CreateFolders `
                -DeleteFolders $Entry.DeleteFolders `
                -MoveAccountsAndFolders $Entry.MoveAccountsAndFolders `
                -RequestsAuthorizationLevel1 $Entry.RequestsAuthorizationLevel1 `
                -RequestsAuthorizationLevel2 $Entry.RequestsAuthorizationLevel2

            Write-Log "✅ Added Member: $MemberName to Safe: $SafeName"
        }

    } catch {
        Write-Log "❌ ERROR: Failed to add/update Member: $MemberName in Safe: $SafeName - $_"
        Write-FailLog -SafeName $SafeName -MemberName $MemberName
    }
}

Write-Log "🔹 Safe member addition/update process completed."
Write-Log "📌 Check $FailedLogFile for any failed operations."
