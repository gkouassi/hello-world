strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set colListOfServices = objWMIService.ExecQuery _
    ("Select * from Win32_Service Where Name  Like 'TIBHawk%' or Name = 'tibemsmcd' or Name = 'tibemsd'")

For Each objService in colListOfServices
    Wscript.Echo "Disable service: " & objService.Name & " State: " & objService.State
    objService.StopService()
	objService.ChangeStartMode("Disabled")
  '  objService.Delete()
Next
