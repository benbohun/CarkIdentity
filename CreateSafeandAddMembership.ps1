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

# Step 2: Read CSV Data
$CsvFilePath = "E:\Installation Media\RemovePendingAccount\SafeSetup.csv"  # Update this path as needed
if (!(Test-Path $CsvFilePath)) {
    Write-Log "❌ ERROR: Safe setup CSV file not found at: $CsvFilePath"
    exit
}

$SafeData = Import-Csv -Path $CsvFilePath

# Step 3: Process Safes and Members
$ExistingSafes = @{}

foreach ($Entry in $SafeData) {
    $SafeName = $Entry.SafeName

    # Check if the safe already exists (only once per safe)
    if (-not $ExistingSafes.ContainsKey($SafeName)) {
        Write-Log "Checking if Safe: ${SafeName} exists..."
        try {
            $SafeCheck = Get-PASSafe -SafeName $SafeName -ErrorAction SilentlyContinue
            if ($SafeCheck) {
                Write-Log "✅ Safe: ${SafeName} already exists."
                $ExistingSafes[$SafeName] = $true
            } else {
                Write-Log "⚠️ Safe: ${SafeName} does not exist. Creating now..."
                try {
                    $ManagingCPM = $Entry.ManagingCPM
                    $Description = $Entry.Description
                    $NumberOfVersionsRetention = $Entry.NumberOfVersionsRetention
                    $NumberOfDaysRetention = $Entry.NumberOfDaysRetention
                    $EnableAudit = $Entry.EnableAudit -eq "true"
                    $EnableCache = $Entry.EnableCache -eq "true"

                    $NewSafe = Add-PASSafe -SafeName $SafeName -ManagingCPM $ManagingCPM -Description $Description `
                        -NumberOfVersionsRetention $NumberOfVersionsRetention -NumberOfDaysRetention $NumberOfDaysRetention `
                        -EnableAudit $EnableAudit -EnableCache $EnableCache

                    if ($NewSafe) {
                        Write-Log "✅ Successfully created Safe: ${SafeName}."
                        $ExistingSafes[$SafeName] = $true
                    } else {
                        Write-Log "❌ ERROR: Failed to create Safe: ${SafeName}."
                        continue  # Skip adding members if safe creation failed
                    }
                } catch {
                    Write-Log "❌ ERROR: Exception while creating Safe: ${SafeName} - $_"
                    continue  # Skip adding members if an error occurred
                }
            }
        } catch {
            Write-Log "❌ ERROR: Unable to check Safe: ${SafeName} - $_"
            continue  # Skip adding members if an error occurred
        }
    }

    # Step 3B: Add or Update Member Permissions
    $MemberName = $Entry.MemberName
    $MemberType = $Entry.MemberType
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

    Write-Log "Updating permissions for Member: ${MemberName} in Safe: ${SafeName}..."
    try {
        $UpdatedMember = Set-PASSafeMember -SafeName $SafeName -MemberName $MemberName -MemberType $MemberType @Permissions

        if ($UpdatedMember) {
            Write-Log "✅ Successfully updated ${MemberName}'s permissions in Safe: ${SafeName}."
        } else {
            Write-Log "❌ ERROR: Failed to update ${MemberName}'s permissions in Safe: ${SafeName}."
        }
    } catch {
        Write-Log "❌ ERROR: Exception while updating ${MemberName}'s permissions in Safe: ${SafeName} - $_"
    }
}

Write-Log "🔹 Safe creation and member permission updates completed."
