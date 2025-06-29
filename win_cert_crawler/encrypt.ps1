# Initialize an empty array to store user records
$users = @()

do {
    # Prompt for username
    $username = Read-Host "Enter your username"

    # Prompt for password as a SecureString (to mask input)
    $securePwd = Read-Host "Enter your pwd" -AsSecureString

    # Convert SecureString to plain text for display (use with caution)
    $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd)
    )

    # Create a custom object to store user info
    $user = [PSCustomObject]@{
        Username = $username
        Password = $plainPwd
    }

    # Add to the array
    $users += $user

    # Ask whether to add another
    $choice = Read-Host "Press 'y' to add next user and 'n' to terminate"
}
while ($choice -eq 'y')

# Display the list of users
Write-Host "`nUsers entered:`n"
$users | Format-Table -AutoSize
