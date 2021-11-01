function BGE_Vm_windows {

    
    #create OS mennu    
    function Show-OSMenu {
        param (
            [string]$Title = 'Select OS'
        )
        Write-Host "================ $Title ================"
    
        Write-Host "1: Press '1' Windows 10 PRO."
        Write-Host "2: Press '2' Windows 2016 Desktop."
        Write-Host "3: Press '3' Windows 2019 Desktop."
        Write-Host "Q: Press 'Q' to quit."
    }
    #loop until answer
    do {
        Clear-Host
        Show-OSMenu
        $input = Read-Host "Please make a selection"
        switch ($input) {
            '1' {
                $global:TemplateLocation = "$global:template\$global:win10"
            } '2' {
                $global:TemplateLocation = "$global:template\$global:2016desk"
            } '3' {
                $global:TemplateLocation = "$global:template\$global:2019desk"
            } 'q' {
                Return 
            }
        }
        
    }while ($input -ne "1" -and $input -ne "2" -and $input -ne "3")

    #ask for vm name, VMName will also become the Computer Name
    do {
        try {
            #[ValidatePattern('[A-Z]{4}-[A-Z]{2,7}-\d{1,4}$')]$name = Read-Host "Enter a servername 15 max (jira-hlutv-01)" 
            [ValidatePattern('[A-Z]{2,8}-\d{1,4}$')]$name = Read-Host "Enter a servername 15 max (nafn-nr)" 
        }
        catch { }
    } until ($?)

    #check for vm name on the server if exist enter new name
    $VMS = Get-VM
    Foreach ($VM in $VMS) {
        if ($Name -match $VM.Name) {
            write-host -ForegroundColor Red "Found VM With the same name!!!!!"
            $name = Read-host "Enter Diffrent Vm Name"
        }
    }

    #ask for admin user
    $winuser = Read-host "Enter user name for Windows"
        
    #Cpu Cores in the VM
    do {
        try {
            $numOk = $true
            [int]$CpuCount = Read-host "Enter vCpu 1-12"
        } # end try
        catch { $numOK = $false }
    } # end do 
    until (($CpuCount -ge 1 -and $CpuCount -lt 13) -and $numOK)
    
    #Ram Size
    $message = "Enter RAM amount in GB (or specify unit)"
    do {
        [int64]$RAM = $null
        [string]$SRAM = Read-Host $message
        switch -regex ($SRAM) {
            '^\d+KB$' { $RAM = 1KB * $SRAM.Substring(0, $SRAM.Length - 2) }
            '^\d+MB$' { $RAM = 1MB * $SRAM.Substring(0, $SRAM.Length - 2) }
            '^\d+GB$' { $RAM = 1GB * $SRAM.Substring(0, $SRAM.Length - 2) }
            '\D+' { Write-Verbose 'No valid integer entered' } #no number means $null 
            '^\d+$' { $RAM = 1GB * $SRAM }
            default { $RAM = 1 * 1GB } #no entry = 1GB
        }
        $message = "Invalid Entry, please enter RAM amount in GB (or specify unit)"
    }
    until ($RAM) 

    #ask for network config
    do {
        write-host "DHCP or Static IP (D/S)" -ForegroundColor green
        $IP = Read-Host " ( D / S ) " 
        Switch ($IP) {
            S {
                #IP Address
                do {
                    $IpAddress = Read-Host 'Enter the Static IP Address. Format 192.168.x.x'; if ($($addr = $null; [ipaddress]::TryParse($IpAddress, [ref]$addr) -and $addr.AddressFamily -eq 'InterNetwork')) { 'Valid IPv4 address' } else { 'Not valid IPv4 address' }
                }until ($addr.AddressFamily -eq 'InterNetwork')
                #Default Gateway to be used
                do {
                    $DefaultGW = Read-Host 'Enter the default gateway. Format 192.168.x.x'; if ($($addr = $null; [ipaddress]::TryParse($DefaultGW, [ref]$addr) -and $addr.AddressFamily -eq 'InterNetwork')) { 'Valid IPv4 address' } else { 'Not valid IPv4 address' }
                }until ($addr.AddressFamily -eq 'InterNetwork')
                #DNS Server
                do {
                    $DNSServer = Read-Host 'Enter DNS server. Format 192.168.x.x'; if ($($addr = $null; [ipaddress]::TryParse($DNSServer, [ref]$addr) -and $addr.AddressFamily -eq 'InterNetwork')) { 'Valid IPv4 address' } else { 'Not valid IPv4 address' }
                }until ($addr.AddressFamily -eq 'InterNetwork')
                do {
                    try {
                        [ValidatePattern('\d{2}$')]$subnetmask = Read-Host "Enter subnetmask 24 for 255.255.255.0" 
                    }
                    catch { }
                } until ($?)
                do {
                    try {
                        [ValidatePattern('\d{1,4000}$')]$global:vlan = Read-Host "Enter vlanID or 0 for no vlanID" 
                    }
                    catch { }
                } until ($?)
                #DNS Domain Name
                $DNSDomain = Read-Host "Enter DNS domain name (test.com)"
                $DHCP = "false"
                $IpAddress = $IpAddress + "/" + $subnetmask
            }

            D {
                Write-host "Enable DHCP" -ForegroundColor green
                do {
                    try {
                        [ValidatePattern('\d{1,4000}$')]$global:vlan = Read-Host "Enter vlanID or 0 for no vlanID" 
                    }
                    catch { }
                } until ($?)
                $DHCP = "true"
            }
            Default { Write-Warning "Invalid Choice. Try again."; Start-Sleep -milliseconds 750 }
        }
    }while ($IP -ne "D" -and $IP -ne "S")

    #Hyper ask for Switch Name to use
    $network = Get-VMSwitch
    do {
        $menu = @{ }
        for ($i = 1; $i -le $network.count; $i++) {
            Write-Host "$i. $($network[$i-1].name),$($network[$i-1].status)" 
            $menu.Add($i, ($network[$i - 1].name))
        }

        [int]$ans = Read-Host 'VMSwitch Enter selection'
    
        #$net = $menu.Item($ans) ; Get-VMSwitch $selection
        $net = $menu.Item($ans)
    }while ($net -eq $menu.name)

    #get the local path for virtual machines
    $dPath = Get-VMHost | Select-Object VirtualMachinePath -ExpandProperty VirtualMachinePath

    #Where's the VM Default location? You can also specify it manually
    $path = "$Dpath$name\"
    #$VHDPath = $Path + $Name + "\" + $Name + ".vhdx"
    $VHDPath = $Path + $Name + ".vhdx"
       
    #write out config for vm
    Clear-Host
    do {
        $meminfo = $RAM / 1GB
        Write-Host "===== Create VM $name on $env:computername ====="
        Write-Host -ForegroundColor Yellow "
                    CPU=$CpuCount
                    Mem=$meminfo GB
                    IPAdress=$IpAddress
                    GW=$DefaultGW
                    DNS=$DNSServer
                    DNSDoamin=$DNSDomain
                    Switch=$net
                    VM Path=$VHDPath

                    "

        $input = Read-Host "===== C to create vm Q to quit ====="
        switch ($input) {
            'C' {
                If ($DHCP -eq 'true') {
                    $IpAddress = "1"
                    $DefaultGW = "1"
                    $DNSServer = "1" 
                    $DNSDomain = "1"
                    $DHCP = "true"
                    BGE_create_vm_W $Name $CpuCount $RAM $winuser $net $IpAddress $DefaultGW $DNSServer $DNSDomain $DHCP
                }
                Else {
                    BGE_create_vm_W $name $CpuCount $RAM $winuser $net $IpAddress $DefaultGW $DNSServer $DNSDomain $DHCP
                }
            } 'Q' {
                Return 
            }
        }
    } while ($input -ne "C" -and $input -ne "Q")
}