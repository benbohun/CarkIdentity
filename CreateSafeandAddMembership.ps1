# Import the psPAS Module
Import-Module psPAS

# Define Log File
$LogFile = "SafeSetupLog.txt"
Function Write-Log {
    Param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Output $LogEntry
}

# Step 1: Read CSV Data for Authentication & Safe Setup
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeSetup.csv"  # Update this path as needed
if (!(Test-Path $CsvFilePath)) {
    Write-Log "❌ ERROR: Safe setup CSV file not found at: $CsvFilePath"
    exit
}

$SafeData = Import-Csv -Path $CsvFilePath

# Extract CyberArk Authentication Details from CSV (First Row)
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$AdminUser = $SafeData[0].MemberName  # Assumes first row has the admin user
$AdminPassword = ConvertTo-SecureString -String "YourPasswordHere" -AsPlainText -Force  # Replace with a secure password source
$UPCred = New-Object System.Management.Automation.PSCredential ($AdminUser, $AdminPassword)

# Step 2: Authenticate Using psPAS
Write-Log "Requesting CyberArk PAS authentication..."
$header = Get-IdentityHeader -IdentityTenantURL $TenantURL -psPASFormat -PCloudSubdomain $PCloudSubdomain -UPCreds $UPCred

# Register the PAS session
Use-PASSession $header

# Validate the session
$session = Get-PASSession
if ($session) {
    Write-Log "✅ Authentication successful, PAS session established."
} else {
    Write-Log "❌ Authentication failed. Exiting script."
    exit
}

### **Step 3A: Process Safe Creation FIRST (Avoiding Duplicates)**
$ProcessedSafes = @{}  # To track already processed Safes

Write-Log "🔹 Starting Safe creation process..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName

    # Skip duplicate Safes
    if ($ProcessedSafes.ContainsKey($SafeName)) {
        continue
    }

    $ManagingCPM = $Entry.ManagingCPM
    $Description = $Entry.Description

    Write-Log "Creating Safe: ${SafeName}..."
    try {
        $NewSafe = Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM -Description $Description

        Write-Log "✅ Successfully created Safe: ${SafeName}."
        $ProcessedSafes[$SafeName] = $true  # Mark Safe as created
    } catch {
        Write-Log "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
        continue  # Skip adding members if safe creation failed
    }
}
Write-Log "🔹 Safe creation process completed."

### **Step 3B: Process Safe Members (After All Safes are Created)**
Write-Log "🔹 Starting Safe member permission updates..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName
    $MemberName = $Entry.MemberName
    $MemberType = $Entry.MemberType  # User, Group, or Role

    # Validate Member Type
    if ($MemberType -notin @("User", "Group", "Role")) {
        Write-Log "❌ ERROR: Invalid MemberType '${MemberType}' for ${MemberName} in Safe: ${SafeName}. Skipping..."
        continue
    }

    # Prepare Permissions
    $Permissions = @{
        UseAccounts = $Entry.UseAccounts -eq "true"
        RetrieveAccounts = $Entry.RetrieveAccounts -eq "true"
        ListAccounts = $Entry.ListAccounts -eq "true"
        AddAccounts = $Entry.AddAccounts -eq "true"
        UpdateAccountContent = $Entry.UpdateAccountContent -eq "true"
        UpdateAccountProperties = $Entry.UpdateAccountProperties -eq "true"
        InitiateCPMAccountManagementOperations = $Entry.InitiateCPMAccountManagementOperations -eq "true"
        SpecifyNextAccountContent = $Entry.SpecifyNextAccountContent -eq "true"
        RenameAccounts = $Entry.RenameAccounts -eq "true"
        DeleteAccounts = $Entry.DeleteAccounts -eq "true"
        UnlockAccounts = $Entry.UnlockAccounts -eq "true"
        ManageSafe = $Entry.ManageSafe -eq "true"
        ManageSafeMembers = $Entry.ManageSafeMembers -eq "true"
        BackupSafe = $Entry.BackupSafe -eq "true"
        ViewAuditLog = $Entry.ViewAuditLog -eq "true"
        ViewSafeMembers = $Entry.ViewSafeMembers -eq "true"
        AccessWithoutConfirmation = $Entry.AccessWithoutConfirmation -eq "true"
        CreateFolders = $Entry.CreateFolders -eq "true"
        DeleteFolders = $Entry.DeleteFolders -eq "true"
        MoveAccountsAndFolders = $Entry.MoveAccountsAndFolders -eq "true"
        RequestsAuthorizationLevel1 = $Entry.RequestsAuthorizationLevel1 -eq "true"
        RequestsAuthorizationLevel2 = $Entry.RequestsAuthorizationLevel2 -eq "true"
    }

    # Set Member Permissions in Safe
    Write-Log "Setting permissions for ${MemberType}: ${MemberName} in Safe: ${SafeName}..."
    try {
        $UpdatedMember = Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName @Permissions

        if ($UpdatedMember) {
            Write-Log "✅ Successfully updated ${MemberType}: ${MemberName} permissions in Safe: ${SafeName}."
        } else {
            Write-Log "❌ ERROR: Failed to update ${MemberType}: ${MemberName} permissions in Safe: ${SafeName}."
        }
    } catch {
        Write-Log "❌ ERROR: Exception while updating ${MemberType}: ${MemberName} permissions in Safe: ${SafeName} - $_"
    }
}

Write-Log "🔹 Safe creation and member permission updates completed."
