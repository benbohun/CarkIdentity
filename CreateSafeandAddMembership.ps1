# Import the psPAS Module
Import-Module psPAS

# Define parameters
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$SafeCsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeSetup.csv"  # Update path as needed
$MemberCsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeMembers.csv"  # Update path as needed

# Step 1: Read Safe CSV Data
if (!(Test-Path $SafeCsvFilePath)) {
    Write-Output "❌ ERROR: Safe setup CSV file not found at: $SafeCsvFilePath"
    exit
}

$SafeData = Import-Csv -Path $SafeCsvFilePath

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
$ProcessedSafes = @{}  # Track created safes

Write-Output "🔹 Starting Safe creation process..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName.Trim()
    if ($ProcessedSafes.ContainsKey($SafeName)) { continue }

    $Description = $Entry.Description.Trim()
    $ManagingCPM = $Entry.ManagingCPM.Trim()

    # Validate and limit integer parameters
    $NumberOfVersionsRetention = [math]::Min([int]$Entry.NumberOfVersionsRetention, 999)  # Max 999
    $NumberOfDaysRetention = [math]::Min([int]$Entry.NumberOfDaysRetention, 3650)  # Max 3650

    # Convert Boolean parameters
    $OLACEnabled = [System.Convert]::ToBoolean($Entry.OLACEnabled)
    $AutoPurgeEnabled = [System.Convert]::ToBoolean($Entry.AutoPurgeEnabled)

    # Convert Location & UseGen1API
    $Location = if ($Entry.Location -ne "") { $Entry.Location.Trim() } else { $null }
    $UseGen1API = [System.Convert]::ToBoolean($Entry.UseGen1API)

    Write-Output "Creating Safe: ${SafeName}..."
    try {
        # Construct parameters with required values
        if ($UseGen1API) {
            $NewSafe = Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM `
                -NumberOfVersionsRetention $NumberOfVersionsRetention `
                -NumberOfDaysRetention $NumberOfDaysRetention `
                -OLACEnabled $OLACEnabled `
                -AutoPurgeEnabled $AutoPurgeEnabled `
                -UseGen1API
        } else {
            $NewSafe = Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM `
                -NumberOfVersionsRetention $NumberOfVersionsRetention `
                -NumberOfDaysRetention $NumberOfDaysRetention `
                -OLACEnabled $OLACEnabled `
                -AutoPurgeEnabled $AutoPurgeEnabled
        }

        Write-Output "✅ Successfully created Safe: ${SafeName}."
        $ProcessedSafes[$SafeName] = $true  # Mark Safe as created
    } catch {
        Write-Output "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
        continue  # Skip adding members if safe creation failed
    }
}
Write-Output "🔹 Safe creation process completed."

### **Step 3B: Assign Members AFTER Safes Are Created**
# Step 4: Read Safe Members CSV Data
if (!(Test-Path $MemberCsvFilePath)) {
    Write-Output "❌ ERROR: Safe members CSV file not found at: $MemberCsvFilePath"
    exit
}

$MemberData = Import-Csv -Path $MemberCsvFilePath

Write-Output "🔹 Starting Safe member permission updates..."
foreach ($Entry in $MemberData) {
    $SafeName = $Entry.SafeName.Trim()
    $MemberName = $Entry.MemberName.Trim()
    $MemberType = $Entry.MemberType.Trim()  # User, Group, or Role

    # Validate Member Type
    if ($MemberType -notin @("User", "Group", "Role")) {
        Write-Output "❌ ERROR: Invalid MemberType '${MemberType}' for ${MemberName} in Safe: ${SafeName}. Skipping..."
        continue
    }

    # Prepare Permissions
    $Permissions = @{}
    $PermissionFields = @("UseAccounts", "RetrieveAccounts", "ListAccounts", "AddAccounts",
        "UpdateAccountContent", "UpdateAccountProperties", "InitiateCPMAccountManagementOperations",
        "SpecifyNextAccountContent", "RenameAccounts", "DeleteAccounts", "UnlockAccounts",
        "ManageSafe", "ManageSafeMembers", "BackupSafe", "ViewAuditLog", "ViewSafeMembers",
        "AccessWithoutConfirmation", "CreateFolders", "DeleteFolders", "MoveAccountsAndFolders",
        "RequestsAuthorizationLevel1", "RequestsAuthorizationLevel2")

    foreach ($Field in $PermissionFields) {
        if ($Entry.$Field -match "^(?i)true|false$") {
            $Permissions[$Field] = [System.Convert]::ToBoolean($Entry.$Field)
        }
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
