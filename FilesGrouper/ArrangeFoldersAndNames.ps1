Param(
    [Parameter(Mandatory)]
    [String]$DestinationFolder,

    [String]$FilePrefix,

    [int]$GroupSize,

    [Parameter(ValueFromPipeline)]
    [System.IO.DirectoryInfo]$Directory
)

begin {
    try {
        $Directory = Get-Item -Path $DestinationFolder
    } catch {
        Write-Error "The destination path is not a valid path."
        exit
    }

    if([string]::IsNullOrEmpty($FilePrefix)) {
        $FilePrefix = $Directory.Name
    }
}
process {
    # Moves nested folders to the parent fodler
    function Arrange-Folders {
        Param(
            [Parameter(Mandatory)]
            [System.IO.DirectoryInfo]$ParentDir
        )

        $childFolders = $ParentDir.GetDirectories();
        foreach($folder in $childFolders) {
            Get-ChildItem -Path $folder.FullName | Move-Item -Destination $ParentDir.FullName
            Remove-Item $folder.FullName -Force
        }
    }
    
    function Change-FileNames {
        Param(
            [Parameter(Mandatory)]
            [System.IO.DirectoryInfo]$ParentDir,

            [Parameter(Mandatory)]
            [String]$FilePrefix
        )

        $files = $ParentDir.GetFiles()
        foreach($file in $files) {
            $filesLength = $files.Count.ToString().Length
            $filesNumber = $file.Name -replace "[^0-9]" , ''
            $fileName = "$($FilePrefix)_$("{0:d$filesLength}" -f [int]$filesNumber)$($file.Extension)"
            Write-Host "Renaming from " $file.BaseName " to " $fileName
            Rename-Item -Path $file.FullName -NewName $fileName
        }
    }

    function Add-FilesToGroups {
        Param(
            [Parameter(Mandatory)]
            [System.IO.DirectoryInfo]$Directory,
            [string]$GroupPrefix,
            [int]$GroupSize
        )

        if($GroupSize -eq 0 -or $GroupSize -eq $null) {
            Write-Host "Group size is not defined. Skipping size grouping."
            return
        }

        $sortedFiles = Get-ChildItem -Path $Directory.FullName | Sort-Object -Property 'Name'

        $i = 0
        foreach($file in $sortedFiles) {
            $groupIndex = [math]::floor($i++ / $GroupSize) + 1
            $itemFullName = "$($file.Directory.FullName)\$($GroupPrefix)_$($groupIndex)"
            if(!(Test-Path $itemFullName)){
                Write-Host "Creating a folder " $itemFullName
                New-Item -Path $itemFullName -ItemType Directory -Force
            }

            Move-Item -LiteralPath $file.FullName -Destination $itemFullName -Force
        }
    }

    Write-Host "Arrange folders"
    Arrange-Folders -ParentDir $Directory

    Write-Host "Change file names"
    Change-FileNames -ParentDir $Directory -FilePrefix $FilePrefix
    
    Write-Host "Arrange Arrange in groups"
    Add-FilesToGroups -Directory $Directory -GroupPrefix $FilePrefix -GroupSize $GroupSize
}