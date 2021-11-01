function BGE_create_vm_L {
    param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$name,

        [Parameter(Mandatory = $True, Position = 2)]
        [string]$CpuCount,
    
        [Parameter(Mandatory = $True, Position = 3)]
        [string]$RAM,
   
        [Parameter(Mandatory = $True, Position = 4)]
        [string]$net,
    
        [Parameter(Mandatory = $True, Position = 5)]
        [string]$IpAddress,
        
        [Parameter(Mandatory = $True, Position = 6)]
        [string]$DefaultGW,
    
        [Parameter(Mandatory = $True, Position = 7)]
        [string]$DNSServer,
    
        [Parameter(Mandatory = $True, Position = 8)]
        [string]$DNSDomain,
    
        [Parameter(Mandatory = $True, Position = 9)]
        [string]$DHCP
  
    )

    #get the local path for virtual machines
    $dPath = Get-VMHost | Select-Object VirtualMachinePath -ExpandProperty VirtualMachinePath

    #Where's the VM Default location? You can also specify it manually
    $path = "$Dpath$name\"
    #$VHDPath = $Path + $Name + "\" + $Name + ".vhdx"
    $VHDPath = $Path + $Name + ".vhdx"

    #random generator
    $random = (1000..9999) | Get-Random -Count 1

    #set static macaddress for vm
    $firstbytes = "00-15-5D"
    $randommac = [BitConverter]::ToString([BitConverter]::GetBytes((Get-Random -Maximum 0xFFFFFFFFFFFF)), 0, 3)
    $Mac = $firstbytes + "-" + $randommac
    #replace - for : in mac.
    $Mac = $Mac.Replace('-', ':')

    #Cloud-init Config
    $metadata = @"
instance-id: $($name+$random)
local-hostname: $($name)
"@

    If ($DHCP -eq 'true') {
        $userdata = @"
#cloud-config
password: passw0rd
chpasswd: { expire: True }
ssh_pwauth: True

package_upgrade: true
package_update: true
package_reboot_if_required: true

packages:
  - linux-virtual
  - linux-cloud-tools-virtual
  - linux-tools-virtual

runcmd:
  - sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

power_state:
 delay: "+1"
 mode: poweroff
 message: Bye Bye
 timeout: 30
 condition: True
"@
    }
    Else {
        If ($DHCP -eq 'false') {
            $userdata = @"
#cloud-config
password: passw0rd
chpasswd: { expire: True }
ssh_pwauth: True

package_upgrade: true
package_update: true
package_reboot_if_required: true

packages:
  - linux-virtual
  - linux-cloud-tools-virtual
  - linux-tools-virtual

runcmd:
  - sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  - mv /etc/netplan/netconfig /etc/netplan/01-systemd-networkd-eth.yaml
  - sed -i -e 's/IpAddress/$IpAddress/g' /etc/netplan/01-systemd-networkd-eth.yaml
  - sed -i -e 's/DefaultGW/$DefaultGW/g' /etc/netplan/01-systemd-networkd-eth.yaml
  - sed -i -e 's/DNSServer1/$DNSServer1/g' /etc/netplan/01-systemd-networkd-eth.yaml
  - sed -i -e 's/DNSServer2/$DNSServer2/g' /etc/netplan/01-systemd-networkd-eth.yaml
  - sed -i -e 's/DNSDomain/$DNSDomain/g' /etc/netplan/01-systemd-networkd-eth.yaml

power_state:
 delay: "+1"
 mode: poweroff
 message: Bye Bye
 timeout: 30
 condition: True
"@
        }
    }


    #make meta data files for cloud-init
    Set-Content "$($global:StartupFolder)data\meta-data" ([byte[]][char[]] "$metadata") -Encoding Byte
    Set-Content "$($global:StartupFolder)data\user-data" ([byte[]][char[]] "$userdata") -Encoding Byte

    #validate the memory
    [int64]$RAM = $null
    switch -regex ($SRAM) {
        '^\d+KB$' { $RAM = 1KB * $SRAM.Substring(0, $SRAM.Length - 2) }
        '^\d+MB$' { $RAM = 1MB * $SRAM.Substring(0, $SRAM.Length - 2) }
        '^\d+GB$' { $RAM = 1GB * $SRAM.Substring(0, $SRAM.Length - 2) }
        '\D+' { Write-Verbose 'No valid integer entered' } #no number means $null 
        '^\d+$' { $RAM = 1GB * $SRAM }
        default { $RAM = 1 * 1GB } #no entry = 1GB
    }
  
  
    #Set the VM Domain access NIC name , i dont need this,,... will I
    $NetworkAdapterName = "Network Adapter"
    if ($NetworkAdapterName -eq "") { $NetworkAdapterName = "Ethernet" } ; if ($NULL -eq $NetworkAdapterName) { $NetworkAdapterName = "Ethernet" }
   
    #Create the VM
    New-VM -Name $Name -Path $Path  -MemoryStartupBytes $RAM  -Generation 2 -NoVHD
    Set-VMMemory -VMName $name -DynamicMemoryEnabled $true -MaximumBytes $RAM -MinimumBytes $RAM
    
    #Remove any auto generated adapters and add new ones with correct names for Consistent Device Naming and vlan
    Get-VMNetworkAdapter -VMName $Name | Remove-VMNetworkAdapter
    Add-VMNetworkAdapter -VMName $Name -SwitchName $net -Name $NetworkAdapterName -DeviceNaming On
    Set-VMNetworkAdapter -VMName $name -StaticMacAddress $Mac
    Set-VMNetworkAdapterVlan -VMName $name -Access -VlanId $global:vlan

    # Set FW type to enable secureboot version 2 
    Set-VMFirmware -VMName $name -EnableSecureBoot on -SecureBootTemplate MicrosoftUEFICertificateAuthority
 
    #Copy the template and add the disk on the VM.
    $totalTimes = 1
    $i = 0
    for ($i = 0; $i -lt $totalTimes; $i++) {
        Write-Progress -Activity "Copy $global:TemplateLocation to $VHDPath"
        copy-Item -Path $global:TemplateLocation -Destination $VHDPath
        Write-Progress -Activity "Copy $global:TemplateLocation to $VHDPath" -Status "Ready" -Completed
        Start-Sleep 1
    }
   
    #Set cpu account    
    Set-VM -Name $Name -ProcessorCount $CpuCount  -AutomaticStartAction Start -AutomaticStopAction ShutDown -AutomaticStartDelay 5 

    #Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path $VHDPath
    Add-VMHardDiskDrive -VMName $Name -ControllerType SCSI -Path $VHDPath
 
    #Set first boot device to the disk we attached
    $Drive = Get-VMHardDiskDrive -VMName $Name | Where-Object { $_.Path -eq "$VHDPath" }
    Get-VMFirmware -VMName $Name | Set-VMFirmware -FirstBootDevice $Drive

    #disable automatic check point
    get-vm -Name $name | Set-VM -AutomaticCheckpointsEnabled $false

    #Create ISO Cloud-init
    $metaDataIso = "$($Path)metadata.iso"
    & $global:oscdimgPath "$($global:StartupFolder)\data\" $metaDataIso -j2 -lcidata

    #mount iso file for first boot
    Add-VMDvdDrive -VMName $name -Path $metaDataIso

    #Remove files metadata
    Remove-Item -Path "$($global:StartupFolder)data\*data" -Force

    #Fire up the VM
    Start-VM $Name
  
    do {
        $VM1 = get-vm -Name $Name
        Write-Progress -Activity "Customize VM and Waiting for the VM to shutdown" 
    } until ($Null -eq $VM1.Heartbeat)
    

    #Dismount DVD ISO file
    Get-VMDvdDrive -VMName $name | Remove-VMDvdDrive

    #Remove ISO file
    remove-Item -Path $metaDataIso -Force

    #Fire up the VM
    start-vm $Name

    #Wait for vm getting ip
    do {
        $ipadd = get-vm -name $name | get-VMNetworkAdapter
    } until ($true -eq $ipadd.IpAddresses[0])
    
    $output = $ipadd.IpAddresses[0]

    #Add the vm to HA cluster
    $cmdName = "Get-cluster"
    if (Get-Command $cmdName -errorAction SilentlyContinue) {
        $cluster = Get-Cluster
        $hostname = $env:computername
        Get-VM $name -ComputerName $hostname | Add-VMToCluster -Cluster (Get-Cluster $cluster) -errorAction SilentlyContinue | out-null 
    }

    Read-Host "Done creating Vm $name With user Ubuntu and password passw0rd Ipaddress $output Copy info and Press Enter to Continue"
}