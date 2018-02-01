function Template_Vm_Menu {
    Import-Csv -Path .\variable.csv | foreach {
        New-Variable -Name $_.Name -Value $_.Value -Force
    }
    function Show-OSMenu {
        param (
            [string]$Title = 'Select OS'
        )
        Clear-Host
        Write-Host "================ $Title ================"
    
        Write-Host "1: Press '1' Windows 10 PRO."
        Write-Host "2: Press '2' Windows 2012R2 Core."
        Write-Host "3: Press '3' Windows 2016 Core."
        Write-Host "Q: Press 'Q' to quit."
    }
    
    do {
        Show-OSMenu
        $input = Read-Host "Please make a selection"
        switch ($input) {
            '1' {
                cls
                'You chose Windows 10 PRO'
                $TemplateLocation = "$template\W10PRO.vhdx"
            } '2' {
                cls
                'You chose Windows 2012R2 Core'
                $TemplateLocation = "$template\W2012r2Core_OS.vhdx"
            } '3' {
                cls
                'You chose Windows 2016 Core'
                $TemplateLocation = "$template\W2016Core_OS.vhdx"
            } '4' {
                cls
                'You chose Windows 2016 Desktop'
                $TemplateLocation = "$template\W2016Desktop_OS.vhdx"    
            } 'q' {
                Return 
            }
        }
        pause
    }
    until ($input)
        
    $DHCP = "false"
    #Cpu Cores in the VM
    $CpuCount = Read-Host "Enter Cpu Count"
    #Ram Size
    $message = "Enter RAM amount in GB (or specify unit)"
    do {
        [int64]$RAM = $null
        [string]$SRAM = Read-Host $message
        switch -regex ($SRAM) {
            '^\d+KB$' { $RAM = 1KB * $SRAM.Substring(0, $SRAM.Length - 2) }
            '^\d+MB$' {$RAM = 1MB * $SRAM.Substring(0, $SRAM.Length - 2) }
            '^\d+GB$' { $RAM = 1GB * $SRAM.Substring(0, $SRAM.Length - 2) }
            '\D+' {Write-Verbose 'No valid integer entered'} #no number means $null 
            '^\d+$' {$RAM = 1GB * $SRAM}
            default {$RAM = 1 * 1GB} #no entry = 1GB
        }
        $message = "Invalid Entry, please enter RAM amount in GB (or specify unit)"
    }
    until ($RAM) 
    #VMName , will also become the Computer Name
    $Name = Read-Host "Enter Vm Name"
    write-host "DHCP or Static IP (D/S)" -ForegroundColor green
    $IP = Read-Host " ( D / S ) " 
    Switch ($IP) {
        S {
            #IP Address
            $IPDomain = Read-Host "Enter IP"
            #Default Gateway to be used
            $DefaultGW = Read-Host "Enter GW"
            #DNS Server
            $DNSServer = Read-Host "Enter DNS"
            #DNS Domain Name
            $DNSDomain = Read-Host "Enter DNS domain name (test.com)"
            
        }

        D {
            Write-host "Enable DHCP" -ForegroundColor green
            $DHCP = "true"
        }
    }

    #Hyper V Switch Name
    $network = Get-VMSwitch
    Write-Host $network.Name-ForegroundColor Red |Format-Table
    $net = Read-Host "Enter switch name (press [Enter] do use Default Switch)"
    if ($net -eq "") {$net = "Default Switch"} ; if ($net -eq $NULL) {$net = "Default Switch"}
    #Set the VM Domain access NIC name
    $NetworkAdapterName = "Network Adapter"
    if ($NetworkAdapterName -eq "") {$NetworkAdapterName = "Ethernet"} ; if ($NetworkAdapterName -eq $NULL) {$NetworkAdapterName = "Ethernet"}
    #User name and Password
    #$AdminAccount = Read-Host "Enter (Administrator) Account"
    $AdminPassword = Read-Host "Enter password for Administrator account"
    #Org info
    $Organization = Read-Host "Enter Organization (Test)"
    #This ProductID is actually the AVMA key provided by MS
    $ProductID = "C3RCX-M6NRP-6CXC9-TW2F2-4RHYD"
    #Where's the VM Default location? You can also specify it manually
    $path = Read-host "Enter Path for VM's or Enter to use this path $Dpath\$name"
    if ($path -eq "") {$path = "$DPath\"} ; if ($path -eq $NULL) {$path = "$DPath\"}
    #Where should I store the VM VHD?, you actually have nothing to do here unless you want a custom name on the VHD
    $VHDPath = $Path + $Name + "\" + $Name + ".vhdx"
    Write-Host "
            CPU=$CpuCount
            Mem=$RAM
            Hostname=$Name
            IPAdress=$IPDomain
            GW=$DefaultGW
            DNS=$DNSServer
            DNSDoamin=$DNSDomain
            Switch=$net
            Password=$AdminPassword
            ORG=$Organization
            ProductKey=$ProductID
            VM Path=$VHDPath"
    Read-Host "Press Enter to Continue"
    #Create the VM
    New-VM -Name $Name -Path $Path  -MemoryStartupBytes $RAM  -Generation 2 -NoVHD
    Set-VMMemory -VMName $name -DynamicMemoryEnabled $true -MaximumBytes $RAM -MinimumBytes $RAM
 
    #Remove any auto generated adapters and add new ones with correct names for Consistent Device Naming
    Get-VMNetworkAdapter -VMName $Name |Remove-VMNetworkAdapter
    Add-VMNetworkAdapter -VMName $Name -SwitchName $net -Name $NetworkAdapterName -DeviceNaming On
 
    #Copy the template and add the disk on the VM. Also configure CPU and start - stop settings
    Start-BitsTransfer -Source $TemplateLocation -Destination  $VHDPath

    Set-VM -Name $Name -ProcessorCount $CpuCount  -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 
    Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path $VHDPath
 
    #Set first boot device to the disk we attached
    $Drive = Get-VMHardDiskDrive -VMName $Name | where {$_.Path -eq "$VHDPath"}
    Get-VMFirmware -VMName $Name | Set-VMFirmware -FirstBootDevice $Drive
 
    #Prepare the unattend.xml file to send out, simply copy to a new file and replace values
    Copy-Item ..\Setup\Unattend.xml $StartupFolder\"unattend"$Name".xml"
    $DefaultXML = $StartupFolder + "\unattend" + $Name + ".xml"
    $NewXML = $StartupFolder + "\unattend$Name.xml"
    $DefaultXML = Get-Content $DefaultXML
    $DefaultXML  | Foreach-Object {
        $_ -replace '1Organization', $Organization `
            -replace '1Name', $Name `
            -replace '1ProductID', $ProductID `
            -replace '1AdminPassword', $AdminPassword `
    } | Set-Content $NewXML
 
    #Mount the new virtual machine VHD
    mount-vhd -Path $VHDPath
    #Find the drive letter of the mounted VHD
    $VolumeDriveLetter = GET-DISKIMAGE $VHDPath | GET-DISK | GET-PARTITION |get-volume |? {$_.FileSystemLabel -ne "Recovery"}|select DriveLetter -ExpandProperty DriveLetter
    #Construct the drive letter of the mounted VHD Drive
    $DriveLetter = "$VolumeDriveLetter" + ":"
    #Copy the unattend.xml to the drive
    Copy-Item $NewXML $DriveLetter\unattend.xml
    #Create script folder
    New-Item -ItemType Directory -Force -Path $DriveLetter\scripts
    New-Item -ItemType Directory -Force -Path $DriveLetter\windows\setup\scripts
    #Copy Scripts to vm
    Copy-Item ..\Setup\SetupComplete.cmd $DriveLetter\windows\setup\scripts\SetupComplete.cmd
    Copy-Item ..\Setup\setup.ps1 $DriveLetter\scripts\setup.ps1
    #Dismount the VHD
    Dismount-Vhd -Path $VHDPath
    #Fire up the VM
    Start-VM $Name
    Read-Host "Done Press Enter to Continue"
        
        
    
}