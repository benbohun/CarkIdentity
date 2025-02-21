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

    $Description = if ($Entry.Description -ne "") { $Entry.Description.Trim() } else { $null }
    $ManagingCPM = $Entry.ManagingCPM.Trim()

    # Validate and limit integer parameters
    $NumberOfVersionsRetention = [math]::Min([int]$Entry.NumberOfVersionsRetention, 999)  # Max 999
    $NumberOfDaysRetention = [math]::Min([int]$Entry.NumberOfDaysRetention, 3650)  # Max 3650

    # Convert Boolean parameters
    $OLACEnabled = [System.Convert]::ToBoolean($Entry.OLACEnabled)
    $AutoPurgeEnabled = [System.Convert]::ToBoolean($Entry.AutoPurgeEnabled)

    # Handle Location and UseGen1API correctly
    $Location = if ($Entry.Location -ne "") { $Entry.Location.Trim() } else { $null }
    $UseGen1API = [System.Convert]::ToBoolean($Entry.UseGen1API)

    Write-Output "Creating Safe: ${SafeName}..."

    try {
        # Construct required parameters
        $Parameters = @{
            SafeName                  = $SafeName
            ManagingCPM               = $ManagingCPM
            NumberOfVersionsRetention = $NumberOfVersionsRetention
            NumberOfDaysRetention     = $NumberOfDaysRetention
            OLACEnabled               = $OLACEnabled
            AutoPurgeEnabled          = $AutoPurgeEnabled
        }

        # Add optional parameters only if they have values
        if ($Description) { $Parameters["Description"] = $Description }
        if ($Location) { $Parameters["Location"] = $Location }
        if ($UseGen1API) { $Parameters["UseGen1API"] = $true }  # Only add if true

        # Execute Safe Creation
        $NewSafe = Add-PASSafe @Parameters

        Write-Output "✅ Successfully created Safe: ${SafeName}."
        $ProcessedSafes[$SafeName] = $true  # Mark Safe as created
    } catch {
        Write-Output "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
        continue  # Skip adding members if safe creation failed
    }
}
Write-Output "🔹 Safe creation process completed."
