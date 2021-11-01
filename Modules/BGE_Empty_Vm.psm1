function Empty_Vm {
    $work = Read-Host "Create Empty VM y/n" 
    Switch ($Work) {
        y {
            $Name = Read-Host "Enter Vm Name"
            $dPath = Get-VMHost |Select-Object VirtualMachinePath -ExpandProperty VirtualMachinePath
            $path = Read-host "Enter Path for VM's or Enter to use this path $Dpath\$name\"
            if ($path -eq "") {$path = "$DPath\"} ; if ($path -eq $NULL) {$path = "$DPath\"}
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
            $message2 = "Enter HD Size amount in GB (or specify unit)"
            do {
                [int64]$DISK = $null
                [string]$SRAM = Read-Host $message2
                switch -regex ($SRAM) {
                    '^\d+KB$' { $DISK = 1KB * $SRAM.Substring(0, $SRAM.Length - 2) }
                    '^\d+MB$' {$DISK = 1MB * $SRAM.Substring(0, $SRAM.Length - 2) }
                    '^\d+GB$' { $DISK = 1GB * $SRAM.Substring(0, $SRAM.Length - 2) }
                    '\D+' {Write-Verbose 'No valid integer entered'} #no number means $null 
                    '^\d+$' {$DISK = 1GB * $SRAM}
                    default {$DISK = 1 * 1GB} #no entry = 1GB
                }
                $message = "Invalid Entry, please enter RAM amount in GB (or specify unit)"
            }
            until ($DISK)
            #Hyper V Switch Name
            $network = Get-VMSwitch
            Write-Host $network.Name-ForegroundColor Red |Format-Table
            $net = Read-Host "Enter switch name (press [Enter] to use Default Switch)"
            if ($net -eq "") {$net = "Default Switch"} ; if ($net -eq $NULL) {$net = "Default Switch"}
            #Set the VM Domain access NIC name
            $NetworkAdapterName = "Network Adapter"
            if ($NetworkAdapterName -eq "") {$NetworkAdapterName = "Ethernet"} ; if ($NetworkAdapterName -eq $NULL) {$NetworkAdapterName = "Ethernet"}
            #Where should I store the VM VHD?, you actually have nothing to do here unless you want a custom name on the VHD
            $VHDPath = $Path + $Name + "\" + $Name + ".vhdx"
            Write-Host "
            CPU=$CpuCount
            Mem=$RAM
            Disk=$DISK
            Switch=$net
            VM Path=$VHDPath"
            Read-Host "Press Enter to Continue"
            #Create the VM
            & New-VHD -Path $path\$name\$name.vhdx -SizeBytes $DISK
            New-VM -Name $Name -Path $Path  -MemoryStartupBytes $RAM  -Generation 2 -NoVHD
            Set-VMMemory -VMName $name -DynamicMemoryEnabled $true -MaximumBytes $RAM -MinimumBytes $RAM
 
            #Remove any auto generated adapters and add new ones with correct names for Consistent Device Naming
            Get-VMNetworkAdapter -VMName $Name |Remove-VMNetworkAdapter
            Add-VMNetworkAdapter -VMName $Name -SwitchName $net -Name $NetworkAdapterName -DeviceNaming On

            Set-VM -Name $Name -ProcessorCount $CpuCount  -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 
            Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path $VHDPath
 
            #Set first boot device to the disk we attached
            $Drive = Get-VMHardDiskDrive -VMName $Name | where {$_.Path -eq "$VHDPath"}
            Get-VMFirmware -VMName $Name | Set-VMFirmware -FirstBootDevice $Drive
            $vm = get-vm -Name $Name
            write-host "$vm.name"
            Read-Host "Enter to Continue"
        }

        n {
            Write-host "Exit" -ForegroundColor green
            return
        }
    }
}