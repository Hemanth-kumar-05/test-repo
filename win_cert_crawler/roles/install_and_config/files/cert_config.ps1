Param(
    [Parameter(Mandatory = $true)]
    [string]$installPath,

    [Parameter(Mandatory = $true)]
    [string]$jsonB64,

    [string]$extRootCert
)

try {
    # Decode Base64 JSON string
    $jsonText = [System.Text.Encoding]::UTF8.GetString(
        [System.Convert]::FromBase64String($jsonB64)
    )

    Write-Host "DEBUG: Raw decoded JSON text:"
    Write-Host $jsonText

    # Parse top-level JSON object
    $parsedJson = $jsonText | ConvertFrom-Json

    # If $parsedJson.certs is a string, convert it properly
    if ($parsedJson.certs -is [string]) {
        Write-Host "DEBUG: certs was a string, cleaning..."

        # Clean up: replace single quotes with double quotes
        $cleanCerts = $parsedJson.certs -replace "'", '"' 

        # Trim leading/trailing spaces
        $cleanCerts = $cleanCerts.Trim()

        Write-Host "DEBUG: Cleaned certs JSON string:"
        Write-Host $cleanCerts

        # Convert to array of cert objects
        $certList = $cleanCerts | ConvertFrom-Json
    }
    else {
        # Already a proper array
        $certList = $parsedJson.certs
    }

    Write-Host "DEBUG: Parsed cert list:"
    $certList | ConvertTo-Json -Depth 5
}
catch {
    Write-Error "Error decoding or parsing JSON input: $_"
    exit 1
}

# Always ensure certList is an array
if ($certList -isnot [System.Array]) {
    $certList = @($certList)
}

# Create a mapping for deterministic folder codes
$folderCodes = @{}

# Create XML structure
[xml]$xml = New-Object System.Xml.XmlDocument
$xml.AppendChild($xml.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null

$configuration = $xml.CreateElement("configuration")
$xml.AppendChild($configuration) | Out-Null

$certificatesNode = $xml.CreateElement("Certificates")
$configuration.AppendChild($certificatesNode) | Out-Null

foreach ($cert in $certList) {
    $path = $cert.path
    $type = $cert.type

    # Generate deterministic SHA1 code for this folder path
    if (-not $folderCodes.ContainsKey($path)) {
        $sha1 = [System.Security.Cryptography.SHA1]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($path)
        $hashBytes = $sha1.ComputeHash($bytes)
        $hashString = ([BitConverter]::ToString($hashBytes)).Replace("-", "")
        $code = $hashString.ToUpper()
        $folderCodes[$path] = $code
    }
    else {
        $code = $folderCodes[$path]
    }

    # Build the tag
    $tag = "${code}_$($type.ToUpper())"

    # Create <add> element
    $certNode = $xml.CreateElement("add")
    $certNode.SetAttribute("tag", $tag)
    $certNode.SetAttribute("type", $type.ToLower())
    $certNode.SetAttribute("path", $path)

    $certificatesNode.AppendChild($certNode) | Out-Null
}

Write-Host "DEBUG: extRootCert = '$extRootCert'"

# Add <appSettings> element with <add key="Storecert"/>
$appSettingsNode = $xml.CreateElement("appSettings")

$certFlag = if ($extRootCert -eq "True") { "Y" } else { "N" }

$storeNode = $xml.CreateElement("add")
$storeNode.SetAttribute("key", "Storecert")
$storeNode.SetAttribute("value", $certFlag)

$appSettingsNode.AppendChild($storeNode) | Out-Null
$configuration.AppendChild($appSettingsNode) | Out-Null

# If installPath is a directory, append default filename
if ((Test-Path -Path $installPath) -and (Get-Item -Path $installPath).PSIsContainer) {
    $installPath = Join-Path -Path $installPath -ChildPath "certs.ini"
}

# Ensure output directory exists
$outputDir = Split-Path -Path $installPath -Parent
New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction SilentlyContinue | Out-Null

# Save the XML file
$xml.Save($installPath)

Write-Host "certs.ini created successfully with $($certList.Count) certs at $installPath"

# Remove the original cert_config.ps1 file (this file)
$scriptPath = $MyInvocation.MyCommand.Path
if (Test-Path -Path $scriptPath) {
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    Write-Host "Removed script file: $scriptPath"
} else {
    Write-Host "Script file not found: $scriptPath"
}
