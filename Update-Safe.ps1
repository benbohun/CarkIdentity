# Import the psPAS module
Import-Module psPAS

# Define Log File
$LogFile = "SafeMemberUpdateLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

# Authentication Variables (User should define these)
$TenantURL = "https://yourtenant.identity.cyberark.cloud"
$PCloudSubdomain = "your_subdomain"
$UPCreds = Get-Credential

# Authenticate and start session
Write-Log "Starting CyberArk Authentication..."
$header = Get-IdentityHeader -IdentityTenantURL $TenantURL -psPASFormat -PCloudSubdomain $PCloudSubdomain -UPCreds $UPCreds
Use-PASSession $header
Write-Log "Authentication successful."

# Define CSV File Path
$CsvFilePath = "C:\Path\To\SafeMembers.csv"

# Check if CSV file exists
if (-Not (Test-Path $CsvFilePath)) {
    Write-Log "ERROR: CSV file not found at $CsvFilePath"
    exit
}

# Load CSV
$SafeMembers = Import-Csv -Path $CsvFilePath

# Process each Safe member
foreach ($Member in $SafeMembers) {
    $SafeName = $Member.SafeName
    $MemberName = $Member.Member
    $MemberLocation = $Member.MemberLocation
    $MemberType = $Member.MemberType
    
    # Convert permission values to Boolean (CyberArk requires this)
    $Permissions = @{
        "UseAccounts" = [boolean]($Member.UseAccounts -eq "TRUE")
        "RetrieveAccounts" = [boolean]($Member.RetrieveAccounts -eq "TRUE")
        "ListAccounts" = [boolean]($Member.ListAccounts -eq "TRUE")
        "AddAccounts" = [boolean]($Member.AddAccounts -eq "TRUE")
        "UpdateAccountContent" = [boolean]($Member.UpdateAccountContent -eq "TRUE")
        "UpdateAccountProperties" = [boolean]($Member.UpdateAccountProperties -eq "TRUE")
        "InitiateCPMAccountManagementOperations" = [boolean]($Member.InitiateCPMAccountManagementOperations -eq "TRUE")
        "SpecifyNextAccountContent" = [boolean]($Member.SpecifyNextAccountContent -eq "TRUE")
        "RenameAccounts" = [boolean]($Member.RenameAccounts -eq "TRUE")
        "DeleteAccounts" = [boolean]($Member.DeleteAccounts -eq "TRUE")
        "UnlockAccounts" = [boolean]($Member.UnlockAccounts -eq "TRUE")
        "ManageSafe" = [boolean]($Member.ManageSafe -eq "TRUE")
        "ManageSafeMembers" = [boolean]($Member.ManageSafeMembers -eq "TRUE")
        "BackupSafe" = [boolean]($Member.BackupSafe -eq "TRUE")
        "ViewAuditLog" = [boolean]($Member.ViewAuditLog -eq "TRUE")
        "ViewSafeMembers" = [boolean]($Member.ViewSafeMembers -eq "TRUE")
        "RequestsAuthorizationLevel" = [int]$Member.RequestsAuthorizationLevel  # Handling as 1 or 0
        "AccessWithoutConfirmation" = [boolean]($Member.AccessWithoutConfirmation -eq "TRUE")
        "CreateFolders" = [boolean]($Member.CreateFolders -eq "TRUE")
        "DeleteFolders" = [boolean]($Member.DeleteFolders -eq "TRUE")
        "MoveAccountsAndFolders" = [boolean]($Member.MoveAccountsAndFolders -eq "TRUE")
    }

    Write-Log "Updating Safe Member: $MemberName in Safe: $SafeName"

    try {
        Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName -MemberType $MemberType -MemberLocation $MemberLocation -Permissions $Permissions -ErrorAction Stop
        Write-Log "Successfully updated permissions for $MemberName in $SafeName"
    }
    catch {
        Write-Log "ERROR: Failed to update permissions for $MemberName in $SafeName - $_"
    }
}

# End session
Write-Log "Safe member permission update process completed."
