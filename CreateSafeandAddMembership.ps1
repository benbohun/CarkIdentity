# Import the psPAS Module
Import-Module psPAS

# Define parameters
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeSetup.csv"  # Update this path as needed

# Step 1: Prompt User for CyberArk Credentials
Write-Output "Requesting CyberArk PAS authentication..."
$UPCreds = Get-Credential  # Securely prompts for credentials

# Authenticate and establish session
$header = Get-IdentityHeader -IdentityTenantURL $TenantURL -psPASFormat -PCloudSubdomain $PCloudSubdomain -UPCreds $UPCreds
Use-PASSession $header

# Verify session
if (Get-PASSession) {
    Write-Output "✅ Authentication successful, PAS session established."
} else {
    Write-Output "❌ Authentication failed. Exiting script."
    exit
}

# Step 2: Read CSV Data
if (!(Test-Path $CsvFilePath)) {
    Write-Output "❌ ERROR: Safe setup CSV file not found at: $CsvFilePath"
    exit
}

$SafeData = Import-Csv -Path $CsvFilePath

### **Step 3A: Process Safe Creation FIRST (Avoiding Duplicates)**
$ProcessedSafes = @{}  # To track already processed Safes

Write-Output "🔹 Starting Safe creation process..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName

    # Skip duplicate Safes
    if ($ProcessedSafes.ContainsKey($SafeName)) {
        continue
    }

    $ManagingCPM = $Entry.ManagingCPM
    $Description = $Entry.Description

    Write-Output "Creating Safe: ${SafeName}..."
    try {
        $NewSafe = Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM -Description $Description

        Write-Output "✅ Successfully created Safe: ${SafeName}."
        $ProcessedSafes[$SafeName] = $true  # Mark Safe as created
    } catch {
        Write-Output "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
        continue  # Skip adding members if safe creation failed
    }
}
Write-Output "🔹 Safe creation process completed."

### **Step 3B: Process Safe Members (After All Safes are Created)**
Write-Output "🔹 Starting Safe member permission updates..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName
    $MemberName = $Entry.MemberName
    $MemberType = $Entry.MemberType  # User, Group, or Role

    # Validate Member Type
    if ($MemberType -notin @("User", "Group", "Role")) {
        Write-Output "❌ ERROR: Invalid MemberType '${MemberType}' for ${MemberName} in Safe: ${SafeName}. Skipping..."
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
    Write-Output "Setting permissions for ${MemberType}: ${MemberName} in Safe: ${SafeName}..."
    try {
        $UpdatedMember = Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName @Permissions

        if ($UpdatedMember) {
            Write-Output "✅ Successfully updated ${MemberType}: ${MemberName} permissions in Safe: ${SafeName}."
        } else {
            Write-Output "❌ ERROR: Failed to update ${MemberType}: ${MemberName} permissions in Safe: ${SafeName}."
        }
    } catch {
        Write-Output "❌ ERROR: Exception while updating ${MemberType}: ${MemberName} permissions in Safe: ${SafeName} - $_"
    }
}

Write-Output "🔹 Safe creation and member permission updates completed."
