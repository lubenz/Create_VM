function BGE_Create_vm_W {
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$name,

        [Parameter(Mandatory = $True, Position = 2)]
        [string]$CpuCount,
    
        [Parameter(Mandatory = $True, Position = 3)]
        [string]$RAM,

        [Parameter(Mandatory = $True, Position = 4)]
        [string]$winuser,
    
        [Parameter(Mandatory = $True, Position = 5)]
        [string]$net,
    
        [Parameter(Mandatory = $True, Position = 6)]
        [string]$IpAddress,
        
        [Parameter(Mandatory = $True, Position = 7)]
        [string]$DefaultGW,
    
        [Parameter(Mandatory = $True, Position = 8)]
        [string]$DNSServer,
    
        [Parameter(Mandatory = $True, Position = 9)]
        [string]$DNSDomain,
    
        [Parameter(Mandatory = $True, Position = 10)]
        [string]$DHCP
  
    )
    
    #get the local path for virtual machines
    $dPath = Get-VMHost | Select-Object VirtualMachinePath -ExpandProperty VirtualMachinePath
    if ($path -eq "") { $path = "$DPath" } ; if ($null -eq $path ) { $path = "$DPath" }

    #password gen username
    Add-Type -AssemblyName System.web
    $AdminPassword = [System.Web.Security.Membership]::GeneratePassword(8, 1)

    #Set the VM Domain access NIC name
    $NetworkAdapterName = "Network Adapter"
    if ($NetworkAdapterName -eq "") { $NetworkAdapterName = "Ethernet" } ; if ($NULL -eq $NetworkAdapterName) { $NetworkAdapterName = "Ethernet" }

    #Where should I store the VM VHD?, you actually have nothing to do here unless you want a custom name on the VHD
    #$VHDPath = $Path + $Name + "\" + $Name + ".vhdx"
    $VHDPath = "$($path)$name\$name.vhdx"

    #Create the VM
    New-VM -Name $Name -Path $Path  -MemoryStartupBytes $RAM  -Generation 2 -NoVHD
    Set-VMMemory -VMName $name -DynamicMemoryEnabled $true -MaximumBytes $RAM -MinimumBytes $RAM
  
    #Remove any auto generated adapters and add new ones with correct names for Consistent Device Naming
    Get-VMNetworkAdapter -VMName $Name | Remove-VMNetworkAdapter
    Add-VMNetworkAdapter -VMName $Name -SwitchName $net -Name $NetworkAdapterName -DeviceNaming On
    Set-VMNetworkAdapterVlan -VMName $name -Access -VlanId $global:vlan
 
    #Copy the template and add the disk on the VM. Also configure CPU and start - stop settings
    $totalTimes = 1
    $i = 0
    for ($i = 0; $i -lt $totalTimes; $i++) {
        Write-Progress -Activity "Copy $global:TemplateLocation to $VHDPath"
        copy-Item -Path $global:TemplateLocation -Destination $VHDPath
        Write-Progress -Activity "Copy $global:TemplateLocation to $VHDPath" -Status "Ready" -Completed
        Start-Sleep 1
    }
    
    Set-VM -Name $Name -ProcessorCount $CpuCount  -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 
    Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path $VHDPath
 
    #Set first boot device to the disk we attached
    $Drive = Get-VMHardDiskDrive -VMName $Name | Where-Object { $_.Path -eq "$VHDPath" }
    Get-VMFirmware -VMName $Name | Set-VMFirmware -FirstBootDevice $Drive

    #set macaddress for unattend
    $firstbytes = "00-15-5D"
    $randommac = [BitConverter]::ToString([BitConverter]::GetBytes((Get-Random -Maximum 0xFFFFFFFFFFFF)), 0, 3)
    $Mac = $firstbytes + "-" + $randommac
    Set-VMNetworkAdapter -VMName $name -StaticMacAddress $Mac
    #replace - for : in mac.
    $Mac.Replace('-', ':')

    #disable automatic check point
    get-vm -Name $name | Set-VM -AutomaticCheckpointsEnabled $false

    #Prepare the unattend.xml file to send out, simply copy to a new file and replace values
    $DefaultXML = Get-Content "$($global:StartupFolder)\Setup\unattend.xml"
    $NewXML = "$($global:StartupFolder)\data\unattend.xml"

    If ($DHCP -eq 'true') {
        $DefaultXML | Foreach-Object {
            $_ -replace '1Organization', $Organization `
                -replace '1Name', $Name `
                -replace '1ProductID', $ProductID `
                -replace '1AdminPassword', $AdminPassword `
                -replace '1win10user', $winuser `
                -replace '1Mac', $Mac `
                -replace '1Dhcp', 'true' 
        } | Set-Content $NewXML
    }
    Else {
        If ($DHCP -eq 'false') {
            $DefaultXML | Foreach-Object {
                $_ -replace '1Organization', $Organization `
                    -replace '1Name', $Name `
                    -replace '1ProductID', $ProductID `
                    -replace '1AdminPassword', $AdminPassword `
                    -replace '1win10user', $winuser `
                    -replace '1Ip', $IpAddress `
                    -replace '1Mac', $Mac `
                    -replace '1Dnsdomain', $DNSdomain `
                    -replace '1DNSServer', $DNSServer `
                    -replace '1DefaultGW', $DefaultGW `
                    -replace '1Dhcp', 'false'
            } | Set-Content $NewXML 
        }
    }
        
    #create iso file for unattend
    $metaDataIso = "$($path)$name\$name.iso"
    & $global:oscdimgPath "$($global:StartupFolder)\data\" $metaDataIso -j2 -lcidata
    #mount iso file
    Add-VMDvdDrive -VMName $name -Path $metaDataIso
    #Remove xml files.
    Remove-Item -Path "$($global:StartupFolder)\data\unattend.xml" -Force
    
    #Fire up the VM
    Start-VM $name

    #Wait for vm going throug customize
    
    do {
        $VM1 = get-vm -Name $Name
        Write-Progress -Activity "Customize VM and Waiting for the VM to shutdown" 
    } until ($Null -eq $VM1.Heartbeat)

    #Dismount DVD ISO file
    Get-VMDvdDrive -VMName $name | Remove-VMDvdDrive
    remove-Item -Path $metaDataIso -Force

    #Fire up the VM
    start-vm -name $name

    #Wait for vm getting ip
    do {
        $ipadd = get-vm -name $name | get-VMNetworkAdapter
        Write-Progress -Activity "Starting VM and Waiting for IP"
    } until ($true -eq $ipadd.IpAddresses[0])
    
    $output = $ipadd.IpAddresses[0]
    
    #make vm High Availability on cluster
    $cmdName = "Get-cluster"
    if (Get-Command $cmdName -errorAction SilentlyContinue) {
        $cluster = Get-Cluster
        $hostname = $env:computername
        Get-VM $name -ComputerName $hostname | Add-VMToCluster -Cluster (Get-Cluster $cluster) -errorAction SilentlyContinue | out-null 
    }

    Read-Host "Done creating Vm [$name] With user [$winuser] password [$AdminPassword] Ipaddress [$output] Copy info and Press Enter to Continue"
}
