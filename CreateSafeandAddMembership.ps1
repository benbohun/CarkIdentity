# Import the psPAS Module
Import-Module psPAS

# Define parameters
$TenantURL = "your_tenant_url"
$PCloudSubdomain = "your_subdomain"
$SafeCsvFilePath = "C:\Path\To\SafeSetup.csv"  # Update path as needed

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

# Step 3: Create Safes
Write-Output "🔹 Starting Safe creation process..."
foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName.Trim()
    if ([string]::IsNullOrEmpty($SafeName)) {
        Write-Output "⚠️ WARNING: SafeName is missing or empty. Skipping entry."
        continue
    }

    # Initialize parameters
    $params = @{
        SafeName = $SafeName
    }

    # Add optional parameters if they have valid values
    if (-not [string]::IsNullOrEmpty($Entry.Description)) {
        $params.Description = $Entry.Description.Trim()
    }
    if (-not [string]::IsNullOrEmpty($Entry.ManagingCPM)) {
        $params.ManagingCPM = $Entry.ManagingCPM.Trim()
    }
    if ($Entry.NumberOfVersionsRetention -match '^\d+$') {
        $params.NumberOfVersionsRetention = [math]::Min([int]$Entry.NumberOfVersionsRetention, 999)
    }
    if ($Entry.NumberOfDaysRetention -match '^\d+$') {
        $params.NumberOfDaysRetention = [math]::Min([int]$Entry.NumberOfDaysRetention, 3650)
    }
    if ($Entry.OLACEnabled -match '^(?i)true|false$') {
        $params.OLACEnabled = [System.Convert]::ToBoolean($Entry.OLACEnabled)
    }
    if ($Entry.AutoPurgeEnabled -match '^(?i)true|false$') {
        $params.AutoPurgeEnabled = [System.Convert]::ToBoolean($Entry.AutoPurgeEnabled)
    }
    if (-not [string]::IsNullOrEmpty($Entry.Location)) {
        $params.Location = $Entry.Location.Trim()
    }
    if ($Entry.UseGen1API -match '^(?i)true$') {
        $params.UseGen1API = $true
    }

    Write-Output "Creating Safe: ${SafeName} with parameters: $params"
    try {
        Add-PASSafe @params
        Write-Output "✅ Successfully created Safe: ${SafeName}."
    } catch {
        Write-Output "⚠️ WARNING: Failed to create Safe: ${SafeName} - $_"
    }
}
Write-Output "🔹 Safe creation process completed."
