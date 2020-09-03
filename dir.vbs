Set FileSystem = CreateObject("Scripting.FileSystemObject")
Set outputLines = CreateObject("System.Collections.ArrayList")
Set outputLinesNotVersioned = CreateObject("System.Collections.ArrayList")
Set realFolders = CreateObject("System.Collections.Hashtable")


If WScript.Arguments.Count = 1 Then
    location=WScript.Arguments(0)    
Else
    Wscript.Echo "Usage: dir.vbs location"
    Wscript.Quit 1
End If

If FileSystem.FolderExists(location) Then
	
	Set dossier = FileSystem.GetFolder(location)
	Set repertoires = dossier.SubFolders
	fileVersionedCount=0
	
	'Traverse
	For Each repertoire In repertoires		
		versionNumber=""
		For count = 1 to Len(repertoire.name)
			currentChar = Mid(repertoire.name, count, 1)
			If IsNumeric(currentChar) Then
				versionNumber=versionNumber&currentChar
			End If			
		Next
		
		If Len(versionNumber) > 0 Then
			fileVersionedCount=fileVersionedCount+1				
			outputLines.Add cint(versionNumber)
			realFolders.Add cint(versionNumber),repertoire.name
		Else
			outputLinesNotVersioned.Add repertoire.name
		End If						
				
	Next

	'sort
	outputLines.sort()	
	
	'echo result
	For Each name In outputLinesNotVersioned
		Wscript.Echo name
	Next
	For Each name In outputLines
		Wscript.Echo realFolders(name)	
	Next
	
End If

