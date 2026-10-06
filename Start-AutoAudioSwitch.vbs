' Starts AutoAudioSwitch hidden (no console window)
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "AutoAudioSwitch.ps1")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & """"
CreateObject("WScript.Shell").Run cmd, 0, False
