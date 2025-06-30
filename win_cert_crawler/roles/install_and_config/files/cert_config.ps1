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
        $cleanCerts = $parsedJson.certs -replace "'", '"' 
        $cleanCerts = $cleanCerts.Trim()
        Write-Host "DEBUG: Cleaned certs JSON string:"
        Write-Host $cleanCerts
        $certList = $cleanCerts | ConvertFrom-Json
    } else {
        $certList = $parsedJson.certs
    }

    Write-Host "DEBUG: Parsed cert list:"
    $certList | ConvertTo-Json -Depth 5
}
catch {
    Write-Error "Error decoding or parsing JSON input: $_"
    exit 1
}

if ($certList -isnot [System.Array]) {
    $certList = @($certList)
}

# Create a mapping for deterministic folder codes
$folderCodes = @{}

# If installPath is a directory, append default filename
if ((Test-Path -Path $installPath) -and (Get-Item -Path $installPath).PSIsContainer) {
    $installPath = Join-Path -Path $installPath -ChildPath "WinCert.config"
}

$outputDir = Split-Path -Path $installPath -Parent
New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction SilentlyContinue | Out-Null

# Check whether file exists and has content
$createNewXml = $true
if (Test-Path -Path $installPath) {
    $fileInfo = Get-Item -Path $installPath
    if ($fileInfo.Length -gt 0) {
        $createNewXml = $false
    }
}

if ($createNewXml) {
    Write-Host "INFO: Creating new XML structure..."

    [xml]$xml = New-Object System.Xml.XmlDocument
    $xml.AppendChild($xml.CreateXmlDeclaration("1.0", "UTF-8", $null)) | Out-Null

    $configuration = $xml.CreateElement("configuration")
    $xml.AppendChild($configuration) | Out-Null

    $certificatesNode = $xml.CreateElement("Certificates")
    $configuration.AppendChild($certificatesNode) | Out-Null

    # Add certs
    foreach ($cert in $certList) {
        $path = $cert.path
        $type = $cert.type

        if (-not $folderCodes.ContainsKey($path)) {
            $sha1 = [System.Security.Cryptography.SHA1]::Create()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($path)
            $hashBytes = $sha1.ComputeHash($bytes)
            $hashString = ([BitConverter]::ToString($hashBytes)).Replace("-", "")
            $code = $hashString.ToUpper()
            $folderCodes[$path] = $code
        } else {
            $code = $folderCodes[$path]
        }

        $tag = "${code}_$($type.ToUpper())"
        $certNode = $xml.CreateElement("add")
        $certNode.SetAttribute("tag", $tag)
        $certNode.SetAttribute("type", $type.ToLower())
        $certNode.SetAttribute("path", $path)

        $certificatesNode.AppendChild($certNode) | Out-Null
    }

    # Create appSettings
    $appSettingsNode = $xml.CreateElement("appSettings")
    $certFlag = if ($extRootCert -eq "True") { "Y" } else { "N" }

    $storeNode = $xml.CreateElement("add")
    $storeNode.SetAttribute("key", "Storecert")
    $storeNode.SetAttribute("value", $certFlag)

    $appSettingsNode.AppendChild($storeNode) | Out-Null
    $configuration.AppendChild($appSettingsNode) | Out-Null
}
else {
    Write-Host "INFO: Loading existing XML and adding certs..."

    [xml]$xml = Get-Content -Path $installPath

    $configuration = $xml.configuration

    if (-not $configuration) {
        throw "Invalid XML: <configuration> element not found."
    }

    # Get or create <Certificates>
    $certificatesNode = $configuration.Certificates
    if (-not $certificatesNode) {
        $certificatesNode = $xml.CreateElement("Certificates")
        $configuration.AppendChild($certificatesNode) | Out-Null
    }

    # Add certs
    foreach ($cert in $certList) {
        $path = $cert.path
        $type = $cert.type

        if (-not $folderCodes.ContainsKey($path)) {
            $sha1 = [System.Security.Cryptography.SHA1]::Create()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($path)
            $hashBytes = $sha1.ComputeHash($bytes)
            $hashString = ([BitConverter]::ToString($hashBytes)).Replace("-", "")
            $code = $hashString.ToUpper()
            $folderCodes[$path] = $code
        } else {
            $code = $folderCodes[$path]
        }

        $tag = "${code}_$($type.ToUpper())"
        $certNode = $xml.CreateElement("add")
        $certNode.SetAttribute("tag", $tag)
        $certNode.SetAttribute("type", $type.ToLower())
        $certNode.SetAttribute("path", $path)

        $certificatesNode.AppendChild($certNode) | Out-Null
    }

    # Get or create appSettings
    $appSettingsNode = $configuration.appSettings
    if (-not $appSettingsNode) {
        $appSettingsNode = $xml.CreateElement("appSettings")
        $configuration.AppendChild($appSettingsNode) | Out-Null
    }

    # Update or create Storecert node
    $storeNode = $appSettingsNode.SelectSingleNode("add[@key='Storecert']")
    if ($storeNode -eq $null) {
        $storeNode = $xml.CreateElement("add")
        $storeNode.SetAttribute("key", "Storecert")
        $appSettingsNode.AppendChild($storeNode) | Out-Null
    }

    $certFlag = if ($extRootCert -eq "True") { "Y" } else { "N" }
    $storeNode.SetAttribute("value", $certFlag)
}

# Save
$xml.Save($installPath)

Write-Host "WinCert.config updated successfully with $($certList.Count) cert(s) at $installPath"

# Remove the script itself
$scriptPath = $MyInvocation.MyCommand.Path
if (Test-Path -Path $scriptPath) {
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    Write-Host "Removed script file: $scriptPath"
} else {
    Write-Host "Script file not found: $scriptPath"
}
