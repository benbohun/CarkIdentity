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
        "UseAccounts" = [boolean]($Member.UseAccounts -eq "Yes")
        "RetrieveAccounts" = [boolean]($Member.RetrieveAccounts -eq "Yes")
        "ListAccounts" = [boolean]($Member.ListAccounts -eq "Yes")
        "AddAccounts" = [boolean]($Member.AddAccounts -eq "Yes")
        "UpdateAccountContent" = [boolean]($Member.UpdateAccountContent -eq "Yes")
        "UpdateAccountProperties" = [boolean]($Member.UpdateAccountProperties -eq "Yes")
        "InitiateCPMAccountManagementOperations" = [boolean]($Member.InitiateCPMAccountManagementOperations -eq "Yes")
        "SpecifyNextAccountContent" = [boolean]($Member.SpecifyNextAccountContent -eq "Yes")
        "RenameAccounts" = [boolean]($Member.RenameAccounts -eq "Yes")
        "DeleteAccounts" = [boolean]($Member.DeleteAccounts -eq "Yes")
        "UnlockAccounts" = [boolean]($Member.UnlockAccounts -eq "Yes")
        "ManageSafe" = [boolean]($Member.ManageSafe -eq "Yes")
        "ManageSafeMembers" = [boolean]($Member.ManageSafeMembers -eq "Yes")
        "BackupSafe" = [boolean]($Member.BackupSafe -eq "Yes")
        "ViewAuditLog" = [boolean]($Member.ViewAuditLog -eq "Yes")
        "ViewSafeMembers" = [boolean]($Member.ViewSafeMembers -eq "Yes")
        "AccessWithoutConfirmation" = [boolean]($Member.AccessWithoutConfirmation -eq "Yes")
        "CreateFolders" = [boolean]($Member.CreateFolders -eq "Yes")
        "DeleteFolders" = [boolean]($Member.DeleteFolders -eq "Yes")
        "MoveAccountsAndFolders" = [boolean]($Member.MoveAccountsAndFolders -eq "Yes")
        "RequestsAuthorizationLevel" = [int]$Member.RequestsAuthorizationLevel  # Handling 1 or 0 for RequestsAuthorizationLevel
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
