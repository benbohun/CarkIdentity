# Import the psPAS Module
Import-Module psPAS

# Define parameters
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeSetup.csv"  # Update this path as needed

# Step 1: Read CSV Data
if (!(Test-Path $CsvFilePath)) {
    Write-Output "❌ ERROR: Safe setup CSV file not found at: $CsvFilePath"
    exit
}

$SafeData = Import-Csv -Path $CsvFilePath

# Step 2: Prompt User for CyberArk Credentials
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

### **Step 3A: Create Safes FIRST (Avoiding Duplicates)**
$ProcessedSafes = @{}  # To track already created Safes

Write-Output "🔹 Starting Safe creation process..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName

    # Skip duplicate Safe creation
    if ($ProcessedSafes.ContainsKey($SafeName)) {
        continue
    }

    $ManagingCPM = $Entry.ManagingCPM
    $Description = $Entry.Description
    $NumberOfVersionsRetention = [int]$Entry.NumberOfVersionsRetention  # Convert to integer
    $NumberOfDaysRetention = [int]$Entry.NumberOfDaysRetention  # Convert to integer

    Write-Output "Creating Safe: ${SafeName}..."
    try {
        $NewSafe = Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM -Description $Description `
            -NumberOfVersionsRetention $NumberOfVersionsRetention -NumberOfDaysRetention $NumberOfDaysRetention

        Write-Output "✅ Successfully created Safe: ${SafeName}."
        $ProcessedSafes[$SafeName] = $true  # Mark Safe as created
    } catch {
        Write-Output "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
        continue  # Skip adding members if safe creation failed
    }
}
Write-Output "🔹 Safe creation process completed."

### **Step 3B: Assign Members AFTER Safes Are Created**
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
        UseAccounts = [bool]($Entry.UseAccounts -eq "true")
        RetrieveAccounts = [bool]($Entry.RetrieveAccounts -eq "true")
        ListAccounts = [bool]($Entry.ListAccounts -eq "true")
        AddAccounts = [bool]($Entry.AddAccounts -eq "true")
        UpdateAccountContent = [bool]($Entry.UpdateAccountContent -eq "true")
        UpdateAccountProperties = [bool]($Entry.UpdateAccountProperties -eq "true")
        InitiateCPMAccountManagementOperations = [bool]($Entry.InitiateCPMAccountManagementOperations -eq "true")
        SpecifyNextAccountContent = [bool]($Entry.SpecifyNextAccountContent -eq "true")
        RenameAccounts = [bool]($Entry.RenameAccounts -eq "true")
        DeleteAccounts = [bool]($Entry.DeleteAccounts -eq "true")
        UnlockAccounts = [bool]($Entry.UnlockAccounts -eq "true")
        ManageSafe = [bool]($Entry.ManageSafe -eq "true")
        ManageSafeMembers = [bool]($Entry.ManageSafeMembers -eq "true")
        BackupSafe = [bool]($Entry.BackupSafe -eq "true")
        ViewAuditLog = [bool]($Entry.ViewAuditLog -eq "true")
        ViewSafeMembers = [bool]($Entry.ViewSafeMembers -eq "true")
        AccessWithoutConfirmation = [bool]($Entry.AccessWithoutConfirmation -eq "true")
        CreateFolders = [bool]($Entry.CreateFolders -eq "true")
        DeleteFolders = [bool]($Entry.DeleteFolders -eq "true")
        MoveAccountsAndFolders = [bool]($Entry.MoveAccountsAndFolders -eq "true")
        RequestsAuthorizationLevel1 = [bool]($Entry.RequestsAuthorizationLevel1 -eq "true")
        RequestsAuthorizationLevel2 = [bool]($Entry.RequestsAuthorizationLevel2 -eq "true")
    }

    # Assign Permissions to Safe Members
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
