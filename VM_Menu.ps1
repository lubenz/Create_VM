$host.ui.RawUI.WindowTitle = "Bensa Virtual Tool $PSScriptRoot "

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

#Template location
$global:template = "\\sensanet.is\fs\ISO\Software\Hyper-V\Template"

#working folder
$mypath = Get-Location
$global:StartupFolder = $mypath.Path

# oscdimg from Deployment Kit "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg"
$global:oscdimgPath = "$global:StartupFolder\tools\oscdimg.exe"

#working folder
$mypath = Get-Location
$global:StartupFolder = $mypath.Path

#template vhd name / windows is sysprep / Ubuntu cloud-init
$global:win10 = "W10PRO_OS.vhdx"
$global:2016desk = "W2016D_OS.vhdx"
$global:2019desk = "W2019D_OS.vhdx"
$global:Ubuntu18 = "Ubuntu18_OS.vhdx"
$global:Centos7 = "Centos7_OS.vhdx"
$global:Debian = "Debian_OS.vhdx"
        
Foreach ($i in get-childitem $global:StartupFolder\modules\B*.psm1)
{
	import-module $i
}

    
Function Show-Menu {
    	
	Param (
		[Parameter(Position = 0, Mandatory = $True, HelpMessage = "Enter your menu text")]
		[ValidateNotNullOrEmpty()]
		[string]$Menu,
		[Parameter(Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string]$Title = "Menu",
		[switch]$ClearScreen
	)
	
	if ($ClearScreen) { Clear-Host }
	#build the menu prompt
	$menuPrompt = $title
	#add a return
	$menuprompt += "`n"
	#add an underline
	$menuprompt += "-" * $title.Length
	$menuprompt += "`n"
	#add the menu
	$menuPrompt += $menu
	
	Read-Host -Prompt $menuprompt
}


Function MainMenu {
	$menu = @"

1: Work with VM's - not reddy

2: Create VM's

3: About

Q: Quit

-----

Select a task by number or Q to quit
"@
	
	Do {
		Switch (Show-Menu $menu "Bensa Virtual Tool" -clear) {
			"1" { WORK_VM_not_reddy }
			"2" { Create_VM }
			"3" { About }
			"Q" {
				Clear-Host
				Write-output "Have a nice day"
				Start-Sleep 2
				Remove-Module BGE*
				exit
			}
			Default {
				Write-Warning "Invalid Choice. Try again."
				Start-Sleep -milliseconds 750
			}
		}
	} While ($True)
}

Function Create_VM {
	$menu = @"

1: Create New Empty VM

2: Create Windows Vm From Template

3: Create Linux Vm From  Template

B: Back

-----

Select a task by number or B to go back
"@
	Do {
		clear-host
		Switch (Show-Menu $menu "Management Menu" -clear) {
			"1" { Empty_Vm }
			"2" { BGE_Vm_Windows }
			"3" { BGE_Vm_linux }
			"B" { MainMenu }
			Default { Write-Warning "Invalid Choice. Try again."; Start-Sleep -milliseconds 750 }
		}
	} While ($True)
}

Function WORK_VM {
	$menu = @"

1: Make running VM highly available

2: Convert VMDK to Vhdx

3: Export Vm to file

B: Back

-----

Select a task by number or B to go back
"@
	Do {
		Switch (Show-Menu $menu "Management Menu" -clear) {
			"1" { Vm_High }
			"2" { Vm_Convert }
			"3" { Vm_Export }
			"B" { MainMenu }
			Default { Write-Warning "Invalid Choice. Try again."; Start-Sleep -milliseconds 750 }
		}
	} While ($True)
}
Function About {
	
	Write-Output "
    Benedikt G. Egilsson put to gether with help from the internet
    Tested in lab environments, Use at your own risk."
	Read-Host "Press Enter to return to menu"
}


MainMenu