# Get the folder where the script is running
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Check for .rdg files in the folder
$rdgFiles = Get-ChildItem -Path $scriptFolder -Filter "*.rdg"
if ($rdgFiles.Count -eq 0) {
    Write-Host -BackgroundColor Black -ForegroundColor Red "No .rdg files found in the script folder. The script requires .rdg files to process."
    Start-Sleep -Seconds 5 # Pause for 5 seconds
    exit
}

# Check if Custom.xml exists and remove it before processing
$customXmlFile = Join-Path -Path $scriptFolder -ChildPath "Custom.xml"
if (Test-Path -Path $customXmlFile) {
    Remove-Item -Path $customXmlFile -Force
    Write-Output "Custom.xml file found and removed."
}

# Define the output CSV file path
$outputCsvPath = Join-Path -Path $scriptFolder -ChildPath "PSMClientBuildTool.csv"

# Initialize the CSV file if it doesn't exist
if (-Not (Test-Path -Path $outputCsvPath)) {
    # Create an empty CSV with the headers
    @"
Group,ServerName
"@ | Out-File -FilePath $outputCsvPath -Encoding UTF8
}

# Process each .rdg file in the folder
$rdgFiles | ForEach-Object {
    $rdgFilePath = $_.FullName

    # Load the XML content from the RDG file
    [xml]$xmlContent = Get-Content -Path $rdgFilePath

    # Initialize an array to store the extracted data
    $serverData = @()

    # Check if the RDG file contains <group> tags
    $groups = $xmlContent.RDCMan.file.group

    # If there are no groups, treat the first <name> as the group name
    if ($groups.Count -eq 0) {
        $NoGroupsGroupName = $xmlContent.RDCMan.file.properties.name
        $groupName = $NoGroupsGroupName
        # Extract all server nodes
        $servers = $xmlContent.RDCMan.file.server
        foreach ($server in $servers) {
            $serverName = $server.properties.name
            # Add the data to the array
            $serverData += [PSCustomObject]@{
                Group      = $groupName
                ServerName = $serverName
            }
        }
    }
    else {
        # Process each group
        foreach ($group in $groups) {
            # Retrieve the <name> of each group and treat it as the Group name
            $groupName = $group.properties.name
            $servers = $group.server.properties.name
            foreach ($server in $servers) {
                $serverName = $server
                # Add the data to the array
                $serverData += [PSCustomObject]@{
                    Group      = $groupName # Use the group name as the Group
                    ServerName = $serverName
                }
            }
        }
    }

    # Append the extracted data to the CSV file
    $serverData | Export-Csv -Path $outputCsvPath -NoTypeInformation -Append -Encoding UTF8
    Write-Output "Processed file: $rdgFilePath"
}

Write-Output "All RDG files processed. Output saved to $outputCsvPath"

# Remove all processed .rdg files
$rdgFiles | Remove-Item -Force
Write-Output "All .rdg files have been removed from the folder."

# Build the Custom XML

# Check if the CSV file exists
if (-Not (Test-Path -Path $outputCsvPath)) {
    Write-Error "CSV file not found at $outputCsvPath"
    return
}

# Import the CSV
$data = Import-Csv -Path $outputCsvPath

# Create an XML document
$xml = New-Object System.Xml.XmlDocument

# Add the XML declaration
$xmlDeclaration = $xml.CreateXmlDeclaration("1.0", "utf-8", $null)
$xml.InsertBefore($xmlDeclaration, $xml.DocumentElement)

# Create root element
$root = $xml.CreateElement("CustomView")
$xml.AppendChild($root)

# Create "Root" element
$rootItem = $xml.CreateElement("item")
$rootItem.SetAttribute("name", "Root")
$rootItem.SetAttribute("text", "Root")
$rootItem.SetAttribute("imageindex", "1")
$root.AppendChild($rootItem)

# Group servers by Group
$groupedData = $data | Group-Object -Property Group

foreach ($group in $groupedData) {
    # Create a group node
    $groupItem = $xml.CreateElement("item")
    $groupItem.SetAttribute("name", $group.Name)
    $groupItem.SetAttribute("text", " $($group.Name)")
    $groupItem.SetAttribute("imageindex", "0")
    $rootItem.AppendChild($groupItem)

    foreach ($server in $group.Group) {
        # Create a server node
        $serverItem = $xml.CreateElement("item")
        $serverItem.SetAttribute("name", $server.ServerName)
        $serverItem.SetAttribute("text", $server.ServerName)
        $serverItem.SetAttribute("imageindex", "2")
        $groupItem.AppendChild($serverItem)
    }
}

# Output file path (same folder as the script)
$outputPath = Join-Path -Path $scriptFolder -ChildPath "Custom.xml"

# Save the XML to a file
$xml.Save($outputPath)

Write-Output "XML file created successfully at $outputPath"

# Remove PSMClientBuildTool file
Get-ChildItem -Path $scriptFolder -Filter "PSMClientBuildTool.csv" | Remove-Item -Force
Write-Output "PSMClientBuildTool CSV file has been removed from the folder."
