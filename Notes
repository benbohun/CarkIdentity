# Import the psPAS Module
Import-Module psPAS

# Define Log File
$LogFile = "SafeMemberReportLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
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

# Step 2: Retrieve All Safes
Write-Log "Retrieving list of Safes..."
try {
    $Safes = Get-PASSafe
    Write-Log "✅ Retrieved $($Safes.Count) Safes."
} catch {
    Write-Log "❌ ERROR: Failed to retrieve Safes - $_"
    exit
}

# Step 3: Retrieve Safe Members and Permissions
$SafeMembersReport = @()

foreach ($Safe in $Safes) {
    $SafeName = $Safe.safeName
    Write-Log "Retrieving members for Safe: ${SafeName}"

    try {
        $SafeMembers = Get-PASSafeMember -SafeName $SafeName

        foreach ($Member in $SafeMembers) {
            $SafeMembersReport += [PSCustomObject]@{
                SafeName                                    = $SafeName
                Member                                      = $Member.memberName
                MemberType                                  = $Member.memberType
                UseAccounts                                = $Member.useAccounts
                RetrieveAccounts                           = $Member.retrieveAccounts
                ListAccounts                               = $Member.listAccounts
                AddAccounts                                = $Member.addAccounts
                UpdateAccountContent                      = $Member.updateAccountContent
                UpdateAccountProperties                   = $Member.updateAccountProperties
                InitiateCPMAccountManagementOperations    = $Member.initiateCPMAccountManagementOperations
                SpecifyNextAccountContent                 = $Member.specifyNextAccountContent
                RenameAccounts                            = $Member.renameAccounts
                DeleteAccounts                            = $Member.deleteAccounts
                UnlockAccounts                            = $Member.unlockAccounts
                ManageSafe                                = $Member.manageSafe
                ManageSafeMembers                         = $Member.manageSafeMembers
                BackupSafe                                = $Member.backupSafe
                ViewAuditLog                              = $Member.viewAuditLog
                ViewSafeMembers                           = $Member.viewSafeMembers
                AccessWithoutConfirmation                 = $Member.accessWithoutConfirmation
                CreateFolders                             = $Member.createFolders
                DeleteFolders                             = $Member.deleteFolders
                MoveAccountsAndFolders                    = $Member.moveAccountsAndFolders
                RequestsAuthorizationLevel1              = $Member.requestsAuthorizationLevel1
                RequestsAuthorizationLevel2              = $Member.requestsAuthorizationLevel2
            }
        }
        Write-Log "✅ Retrieved $($SafeMembers.Count) members for Safe: ${SafeName}"
    } catch {
        Write-Log "❌ ERROR: Failed to retrieve members for Safe: ${SafeName} - $_"
    }
}

# Step 4: Export Safe Member Report to CSV
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeMemberReport.csv"  # Update this path as needed
$SafeMembersReport | Export-Csv -Path $CsvFilePath -NoTypeInformation

Write-Log "✅ Safe Member Report successfully exported to: $CsvFilePath"
Write-Log "🔹 Safe Member Report generation completed."
