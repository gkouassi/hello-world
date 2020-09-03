Dim installFile,location,envLocation,key,value

If WScript.Arguments.Count = 3 Then
    installFile= WScript.Arguments(0)
    location=WScript.Arguments(1)
    key=WScript.Arguments(2)
Else
    Wscript.Echo "Usage: readInstallInfos.vbs <installFile> <envLocation> <key>"
    Wscript.Quit 1
End If

Set FileSystem = CreateObject("Scripting.FileSystemObject")
If NOT FileSystem.FileExists(installFile) Then    
    Wscript.Quit 0
End If

Set xmlDoc = CreateObject("Microsoft.XMLDOM")
xmlDoc.Async = "false"
xmlDoc.Load(installFile)

For Each envElement In xmlDoc.selectNodes("/TIBCOEnvironment/environment")
	envLocation=envElement.getAttribute("location")
	If Trim(LCase(envLocation))=Trim(LCase(location)) Then
		value=envElement.getAttribute(key)
		If NOT IsNull(value) Then
			Wscript.Echo value
		End If		
	End If
Next

Wscript.Quit 0
