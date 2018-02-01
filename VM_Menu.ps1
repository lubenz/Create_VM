$host.ui.RawUI.WindowTitle = "Bensa Virtual Tool"

        $PSmoduleFolder = '.\modules'
        
        Foreach ($i in get-childitem $PSmoduleFolder *.psm1)

            {
                 import-module $PSmoduleFolder\$i
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

1: Work with VM's

2: Create VM's

3: Management Tasks

4: About

Q: Quit

-----

Select a task by number or Q to quit
"@
	
	Do {
		Switch (Show-Menu $menu "Bensa Virtual Tool" -clear) {
			"1" { WORK_VM }
            "2" { Create_VM }
            "3" { Manage_VM }
			"4" { About }
			"Q" {
				Write-output "Thanks for using the Bensa Virtual Tool"
                sleep 2
                Remove-Module BGE*
 				exit
			}
			Default {
				Write-Warning "Invalid Choice. Try again."
				sleep -milliseconds 750
			}
		}
	} While ($True)
}

Function Create_VM {
	$menu =@"

1: Create New Empty VM

2: Create Vm From Sysprep Template

B: Back

-----

Select a task by number or B to go back
"@
	Do {
		Switch (Show-Menu $menu "Management Menu" -clear) {
			"1" { Empty_Vm_Menu }
			"2" { Template_Vm_Menu }
			"B" { MainMenu }
			Default { Write-Warning "Invalid Choice. Try again."; sleep -milliseconds 750 }
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
            "3" { Vm_export }
            "B" { MainMenu }
            Default { Write-Warning "Invalid Choice. Try again."; sleep -milliseconds 750 }
        }
    } While ($True)
}
Function About {
	
	Write-Output "
    Author:		Benedikt G. Egilsson with help from the internet
    Tested in lab environments, Use on your own risk."
	Read-Host "Press Enter to return to menu"
}


MainMenu