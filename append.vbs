Dim file1, file2, count

Const TristateFalse = 0 ' the value for ASCII
Const ForAppend = 8
Const ForRead = 1

If WScript.Arguments.Count = 2 Then
    file1   = WScript.Arguments(0)
    file2  	= WScript.Arguments(1)      	
Else
    Wscript.Echo "Usage: append.vbs <file1> <file2>"
    Wscript.Quit 1
End If

Set FileSystem = CreateObject("Scripting.FileSystemObject")
If FileSystem.FileExists(result) Then
    FileSystem.DeleteFile result
End If

'Open append
Set appendFile = FileSystem.OpenTextFile(file2)

'read fully
Set inputFile = FileSystem.OpenTextFile(file1,ForRead)
inputFileText = inputFile.ReadAll
inputFile.Close

'Open append
Set resultFile = FileSystem.OpenTextFile(file1,ForAppend,TristateFalse)

'Loop
count=0
Do Until appendFile.AtEndOfStream
    Line = appendFile.ReadLine 	
	If InStr(inputFileText,Line) = 0 Then
		If count=0 Then
			resultFile.WriteLine(VBCrLf)
		End If
		resultFile.WriteLine(Line)		
	End If 
	count=count+1
Loop

resultFile.Close
appendFile.Close
Wscript.Echo file1+" appended with "+file2
Wscript.Quit

