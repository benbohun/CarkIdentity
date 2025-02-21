# Import the psPAS Module
Import-Module psPAS

# Define parameters
$TenantURL = "aat4012.id.cyberark.cloud"
$PCloudSubdomain = "cna-prod"
$SafeCsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeSetup.csv"
$MemberCsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeMembers.csv"

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

    $ManagingCPM = $Entry.ManagingCPM.Trim()
    $Description = if ($Entry.Description -ne "") { $Entry.Description.Trim() } else { $null }

    # Ensure integers are within valid range
    $NumberOfVersionsRetention = [math]::Min([int]$Entry.NumberOfVersionsRetention, 999)
    $NumberOfDaysRetention = [math]::Min([int]$Entry.NumberOfDaysRetention, 3650)

    # Convert Boolean values properly
    $OLACEnabled = [System.Convert]::ToBoolean($Entry.OLACEnabled)
    $AutoPurgeEnabled = [System.Convert]::ToBoolean($Entry.AutoPurgeEnabled)

    # Handle optional parameters correctly
    $Location = if ($Entry.Location -ne "") { $Entry.Location.Trim() } else { $null }
    $UseGen1API = if ($Entry.UseGen1API -eq "true") { $true } else { $false }

    Write-Output "Creating Safe: ${SafeName}..."

    try {
        # Explicitly passing only required parameters
        if ($UseGen1API) {
            Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM `
                -NumberOfVersionsRetention $NumberOfVersionsRetention `
                -NumberOfDaysRetention $NumberOfDaysRetention `
                -OLACEnabled $OLACEnabled `
                -AutoPurgeEnabled $AutoPurgeEnabled `
                -UseGen1API
        } else {
            Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM `
                -NumberOfVersionsRetention $NumberOfVersionsRetention `
                -NumberOfDaysRetention $NumberOfDaysRetention `
                -OLACEnabled $OLACEnabled `
                -AutoPurgeEnabled $AutoPurgeEnabled
        }

        Write-Output "✅ Successfully created Safe: ${SafeName}."
        $ProcessedSafes[$SafeName] = $true
    } catch {
        Write-Output "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
        continue
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
    $PermissionFields = @(
        "UseAccounts", "RetrieveAccounts", "ListAccounts", "AddAccounts",
        "UpdateAccountContent", "UpdateAccountProperties", "InitiateCPMAccountManagementOperations",
        "SpecifyNextAccountContent", "RenameAccounts", "DeleteAccounts", "UnlockAccounts",
        "ManageSafe", "ManageSafeMembers", "BackupSafe", "ViewAuditLog", "ViewSafeMembers",
        "AccessWithoutConfirmation", "CreateFolders", "DeleteFolders", "MoveAccountsAndFolders",
        "RequestsAuthorizationLevel1", "RequestsAuthorizationLevel2"
    )

    foreach ($Field in $PermissionFields) {
        if ($Entry.$Field -match "^(?i)true|false$") {
            $Permissions[$Field] = [System.Convert]::ToBoolean($Entry.$Field)
        }
    }

    # Assign Permissions to Safe Members
    Write-Output "Setting permissions for ${MemberType}: ${MemberName} in Safe: ${SafeName}..."
    try {
        Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName @Permissions

        Write-Output "✅ Successfully updated ${MemberType}: ${MemberName} permissions in Safe: ${SafeName}."
    } catch {
        Write-Output "❌ ERROR: Exception while updating ${MemberType}: ${MemberName} permissions in Safe: ${SafeName} - $_"
    }
}

Write-Output "🔹 Safe creation and member permission updates completed."
