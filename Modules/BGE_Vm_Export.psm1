    function Vm_Export {
        $work = Read-Host "Export VM y/n" 
        Switch ($Work) {
            y {
                $vm = Get-VM
                write-host -BackgroundColor Green $vm.name
                $vmname = Read-Host "Enter VM Name"
                $path = Read-Host "Enter Destination"
                Export-VM -VMName $vmname -Path $path
                Read-Host "Enter to Continue" 
            }

            n {
                Write-host "Exit" -ForegroundColor green
                return
            }
        }
}
