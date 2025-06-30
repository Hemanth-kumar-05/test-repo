# Initialize an empty array to store records
$certs = @()

do {
    # Prompt for certificate path
    $certPath = Read-Host "Enter your certificate path"

    # Prompt for password as SecureString
    $securePwd = Read-Host "Enter your password" -AsSecureString

    # Convert SecureString to plain text
    $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd)
    )

    # Create a custom object
    $cert = [PSCustomObject]@{
        Path     = $certPath
        Password = $plainPwd
    }

    # Add to array
    $certs += $cert

    # Prompt to continue
    $choice = Read-Host "Press 'y' to add next certificate and 'n' to terminate"
}
while ($choice -eq 'y')

# Output file path
$logPath = Join-Path -Path (Get-Location) -ChildPath "password_encrypt.txt"

Write-Host $logPath

# Remove file if it exists to avoid residual content
if (Test-Path $logPath) {
    Remove-Item -Path $logPath
}

# Write each line in the required format
foreach ($cert in $certs) {
    "$($cert.Path)=$($cert.Password)" | Out-File -FilePath $logPath -Append -Encoding UTF8
}
