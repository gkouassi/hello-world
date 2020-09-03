Option Explicit

Const ExpectedArgs = 11
Const TristateFalse = 0 ' the value for ASCII
Const Overwrite = True

Dim FileSystem
Dim Filename, NewFilename, TibcoRoot, TibcoConfigDir, EmsConfigFile, EmsRoot, newEnv, envName, JavaHome, LGPLAssemblyPath, ThirdPartiesPath
Dim OriginalFile, NewFile, Line, useExistingTibcoHome
Dim objArgs,strArg

If WScript.Arguments.Count = ExpectedArgs Then
    Filename = WScript.Arguments.Item(0)   
    TibcoRoot = WScript.Arguments.Item(1)
    TibcoConfigDir = WScript.Arguments.Item(2)   
    EmsConfigFile= WScript.Arguments.Item(3)
	EmsRoot= WScript.Arguments.Item(4)
	JavaHome= WScript.Arguments.Item(5)
	LGPLAssemblyPath= WScript.Arguments.Item(6)
	ThirdPartiesPath = Wscript.Arguments.Item(7)
    newEnv=WScript.Arguments.Item(8)
    envName=WScript.Arguments.Item(9)
    NewFilename = WScript.Arguments.Item(10)  
Else		
	Wscript.Echo "Args length not match : expected " & ExpectedArgs & ", found " & WScript.Arguments.Count
	Set objArgs = WScript.Arguments	
	For Each strArg in objArgs
		WScript.Echo strArg
	Next
    Wscript.Echo "Error detected, expected argument count not match"
    Wscript.Quit 1
End If

Wscript.Echo "Replacing: " & Filename & ", LGPLAssemblyPath: " & LGPLAssemblyPath

Set FileSystem = CreateObject("Scripting.FileSystemObject")

If FileSystem.FileExists(NewFilename) Then
    FileSystem.DeleteFile NewFilename
End If

'commented
'If NOT FileSystem.FolderExists(TibcoRoot) Then
'    newEnv="true" 
'End If
	

Set NewFile = FileSystem.CreateTextFile(NewFilename, Overwrite, TristateFalse)
Set OriginalFile = FileSystem.OpenTextFile(Filename)

Do Until OriginalFile.AtEndOfStream
    Line = OriginalFile.ReadLine
    If InStr(Line,"<entry key=""installationRoot""")> 0 Then
    	Line = "<entry key=""installationRoot"">"&TibcoRoot&"</entry>"
    End If
    If InStr(Line,"<entry key=""configDirectoryRoot""")> 0 Then
    	Line = "<entry key=""configDirectoryRoot"">"&TibcoConfigDir&"</entry>"
    End If
    If InStr(Line,"<entry key=""configFile""")> 0 Then
    	Line = "<entry key=""configFile"">"&EmsConfigFile&"</entry>"
    End If
    If InStr(Line,"<entry key=""createNewEnvironment""")> 0 Then
    	Line = "<entry key=""createNewEnvironment"">"&newEnv&"</entry>"
    End If
	 If InStr(Line,"<!--entry key=""environmentName""")> 0 Then
    	Line = "<entry key=""environmentName"">"&envName&"</entry>"
    End If
    If InStr(Line,"<entry key=""environmentName""")> 0 Then
    	Line = "<entry key=""environmentName"">"&envName&"</entry>"
    End If
	If InStr(Line,"-P root.installLocation")> 0 Then
    	Line = "-P root.installLocation="&TibcoRoot
    End If	
	If InStr(Line,"-W TIBCOProductHomePanel.productHome")> 0 Then
    	Line = "-W TIBCOProductHomePanel.productHome="&TibcoRoot
    End If		
	If InStr(Line,"<entry key=""emsConfigDir""")> 0 Then
    	Line = "<entry key=""emsConfigDir"">"&EmsRoot&"</entry>"
    End If
	If InStr(Line,"<entry key=""java.home.directory""")> 0 Then
    	Line = "<entry key=""java.home.directory"">"&JavaHome&"</entry>"
    End If
	If InStr(Line,"<entry key=""LGPLAssemblyDownload""")> 0 Then
    	Line = "<entry key=""LGPLAssemblyDownload"">false</entry>"
    End If
	If InStr(Line,"<entry key=""LGPLAssemblyPath""")> 0 Then
    	Line = "<entry key=""LGPLAssemblyPath"">"&LGPLAssemblyPath&"</entry>"
    End If
	If InStr(Line,"<entry key=""oracle.jdbc.driver""")> 0 Then
    	Line = "<entry key=""oracle.jdbc.driver"">"&ThirdPartiesPath&"</entry>"
    End If
	If InStr(Line,"<entry key=""oracle.aq.api""")> 0 Then
    	Line = "<entry key=""oracle.aq.api"">"&ThirdPartiesPath&"</entry>"
    End If
	
	'If InStr(Line,"<entry key=""selectedProfiles""")> 0 Then
    ' 	Line = "<entry key=""selectedProfiles"">Typical</entry>"
    ' End If
    NewFile.WriteLine(Line)
Loop

OriginalFile.Close
NewFile.Close

Wscript.Quit
