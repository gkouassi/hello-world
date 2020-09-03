Set WshShell = WScript.CreateObject("WScript.Shell")
Set objWshSpecialFolders = WshShell.SpecialFolders
Set FileSystem = CreateObject("Scripting.FileSystemObject")
WSCript.Echo FileSystem.GetParentFolderName (objWshSpecialFolders("Desktop"))

