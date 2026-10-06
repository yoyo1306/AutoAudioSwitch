' Stops AutoAudioSwitch watcher
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Stop-AutoAudioSwitch.ps1")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & script & """"
CreateObject("WScript.Shell").Run cmd, 1, True
