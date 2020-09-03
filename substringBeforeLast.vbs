Dim inputStr, token,indexOfToken

If WScript.Arguments.Count = 2 Then
    inputStr       = WScript.Arguments(0)
    token  	   = WScript.Arguments(1)                    
Else
    Wscript.Echo "Usage: substringBefore.vbs <inputStr> <token>"
    Wscript.Quit 1
End If

'Get index (last)
indexOfToken=InStrRev(inputStr,token)

'Substring at token
If indexOfToken > 0 Then
	sbStr = Mid(inputStr, 1, indexOfToken-1)
	Wscript.Echo sbStr
Else  			
	Wscript.Echo inputStr
End If


