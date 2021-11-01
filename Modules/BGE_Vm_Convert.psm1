Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Vm_Convert {
    write-host "Convert VMDK to VHDX " -ForegroundColor green
    $work = Read-Host "Convert file y/n" 
    Switch ($Work) {
        y {
            function Unzip {
                 
                param ([string]$zipfile, [string]$outpath)
                [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
            }

            if (-NOT (Test-Path $StartupFolder\qemu-img-win-x64-2_3_0.zip)) {
                write-host "You want to start Download https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip"
                $down = Read-Host "Download file file y/n" 
                    Switch ($down) {
                y {Start-BitsTransfer -Source https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip -Destination $StartupFolder\
                        unzip $StartupFolder\qemu-img-win-x64-2_3_0.zip $StartupFolder}
                n {Return}        
            } }
            $fileinput = Read-host "Enter Filname (c:\temp\bla.vmdk"
            $fileoutput = Read-host "Enter File destination (c:\temp\bla.vhdx)"
            	
            & $StartupFolder\qemu-img.exe convert -p $fileinput -O vpc -o subformat=dynamic $fileoutput
            Read-Host "Enter to Continue" 
        }

        n {
            Write-host "Exit" -ForegroundColor green
            return
        }
    }
}
    
