$ErrorActionPreference = 'Stop'

# YASB owns a private F24 global hotkey. GlazeWM owns the user-facing launcher
# chords so VM binding mode can leave those chords untouched for the guest.
Add-Type -AssemblyName System.Windows.Forms

$deadline = [DateTime]::UtcNow.AddMilliseconds(750)
while (
    [System.Windows.Forms.Control]::ModifierKeys -ne [System.Windows.Forms.Keys]::None -and
    [DateTime]::UtcNow -lt $deadline
) {
    Start-Sleep -Milliseconds 10
}

[System.Windows.Forms.SendKeys]::SendWait('{F24}')
