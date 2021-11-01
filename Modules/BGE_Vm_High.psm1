function Vm_High {
    $work = Read-Host "Make running VM highly available y/n" 
    Switch ($Work) {
        y {
            $cluster = Get-Cluster
            $hostname = HOSTNAME
            $vm = Get-VM
            Write-host -BackgroundColor Green $vm.name
            $vmname = read-host "Enter VM Name"
            Get-VM $vmname -ComputerName $hostname | Add-VMToCluster -Cluster (Get-Cluster $cluster)
        }

        n {
            Write-host "Exit" -ForegroundColor green
            return
        }
    }
}