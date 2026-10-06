$ErrorActionPreference = 'SilentlyContinue'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | ForEach-Object {
    if ($_.CommandLine -and $_.CommandLine -like '*AutoAudioSwitch.ps1*') {
        Stop-Process -Id $_.ProcessId -Force
        Write-Host "Stopped PID $($_.ProcessId)"
    }
}
Write-Host 'Done.'
