function ConvertFrom-Ini {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$ini
    )
    $PSObject = New-Object PSObject
    foreach ($string in $ini) {
        if ($string -match "^\[(.+)\]$") {
            # Если находим имя диска, создаем и помещаем в родительский объект пустой дочерний объект с именем диска
            $Parent = $Matches[1]
            $CustomObjectChildren = New-Object PSObject
            $PSObject | Add-Member -MemberType NoteProperty `
            -Name $Parent `
            -Value $CustomObjectChildren
        }
        else {
            # Удаляем ковычки из строки и забираем ключ-значение
            $Child = $string -replace '"' | ConvertFrom-StringData
            # Помещяем в последний дочерний объект ключ-значения
            $PSObject.$Parent | Add-Member -MemberType NoteProperty `
            -Name $Child.Keys `
            -Value ($Child.Values | ForEach-Object { $_.ToString() }) -Force # Конвертируем каждое значение хэш-таблицы в формат String
        }
    }
    $PSObject
}

function Get-DiskInfo {
    <#
    .SYNOPSIS
    Command line interface using PowerShell module for software CrystalDiskInfo
    .DESCRIPTION
    Examples:
    Get-DiskInfo
    $(Get-DiskInfo)[0].Temperature
    Get-DiskInfo -Path "C:\Program Files\CrystalDiskInfo"
    Get-DiskInfo -List
    Get-DiskInfo -Report
    .LINK
    https://github.com/Lifailon/CrystalDisk-Cli
    https://github.com/hiyohiyo/CrystalDiskInfo
    #>
    param (
        [switch]$Report,
        [switch]$List,
        $Path = "C:\Program Files\CrystalDiskInfo"
    )
    $Smart_Path = "$Path\Smart"
    # Проверьте, существует ли заданный путь, если нет, то выбросьте ошибку
    if ((Test-Path $Path, $Smart_Path) -contains $false) {
        Write-Error -Category ObjectNotFound -TargetObject $Path -Message "CrystalDiskInfo was not found at path: `"$Path`"."
        Write-Host -ForegroundColor Cyan "Try running `"winget install -e --id=CrystalDewWorld.CrystalDiskInfo`""
        break
    }
    # Формируем массив из имен дисков вложенных директорий
    $Disk_Array = @($(Get-ChildItem $Smart_Path | Where-Object Attributes -eq "Directory").Name)
    if ($List){
        $Disk_Array
    }
    else {
        if ($Report) {
            # Запускаем отчет и проверяем его создание по дате изменения
            $DateTemp = Get-Date
            # Посмотрите, какая версия установлена
            $ExecutableEditions = @("$Path\DiskInfo64.exe", "$Path\DiskInfo64S.exe", "$Path\DiskInfo64A.exe", "$Path\DiskInfo64K.exe")
            $TestedPaths = Test-Path $ExecutableEditions
            # Если не найдено ни одного из них, выбросьте ошибку
            if ($TestedPaths -notcontains $true) {
                Write-Error -Category ObjectNotFound -TargetObject $ExecutableEditions[0] -Message "CrystalDiskInfo executable was not found! Validate your install."
                break
            }
            # Сопоставьте версию с путем к исполняемому файлу
            $Executable = $ExecutableEditions[$TestedPaths.IndexOf($true)]
            Start-Process -FilePath $Executable -ArgumentList "/CopyExit" -WindowStyle Hidden
            while ($true) {
                if ($(Get-ChildItem "$Path\DiskInfo.txt" -ErrorAction Ignore).LastWriteTime -gt $DateTemp) {
                    break
                }
            }
        }
        $MainObject = New-Object PSObject
        foreach ($Disk in $Disk_Array) {
            # Читаем содержимое ini-файла
            $ini = Get-Content "$Smart_Path\$Disk\Smart.ini"
            # Конвертируем содержимое ini-файла в объект
            $ChildrenObject = ConvertFrom-Ini $ini
            # Заполняем родительский объект из имени диска и дочерним объектом
            $MainObject | Add-Member -MemberType NoteProperty `
            -Name $Disk `
            -Value $ChildrenObject
        }
        # Пересобираем объект с фильтрацией по дате и одним вложенным родительским объектом
        $Date = $(Get-Date).ToString("yyyy/MM/dd")
        $NewObject = New-Object PSObject
        foreach ($Disk in $Disk_Array) {
            $ChildrenArray = $($MainObject.$Disk | Get-Member -MemberType NoteProperty).Name
            foreach ($Children in $ChildrenArray) {
                $CheckDate = $MainObject.$Disk.$Children | Where-Object Date -match $Date
                if ($CheckDate) {
                    $NewObject | Add-Member -MemberType NoteProperty `
                    -Name $Disk `
                    -Value $MainObject.$Disk.$Children
                    break
                }
            }
        }
        # Вывод в формате объекта с вложениями:
        # $NewObject
        # Пересобираем коллекцию
        $Collection = @()
        foreach ($DiskName in $NewObject.PSObject.Properties) {
            $DiskProperties = $DiskName.Value
            $DiskPropertiesChild = [PSCustomObject]@{
                Name = $DiskName.Name
            }
            foreach ($Property in $DiskProperties.PSObject.Properties) {
                $DiskPropertiesChild | Add-Member -MemberType NoteProperty -Name $Property.Name -Value $Property.Value
            }
            $Collection += $DiskPropertiesChild
        }
        $Collection
    }
}

function Get-DiskInfoSettings {
    <#
    .SYNOPSIS
    Command line interface using PowerShell module for software CrystalDiskInfo
    .DESCRIPTION
    Examples:
    Get-DiskInfoSettings
    Get-DiskInfoSettings -AutoRefresh 0
    Get-DiskInfoSettings -AutoRefresh 1
    Get-DiskInfoSettings -AutoRefresh 5
    Get-DiskInfoSettings -Startup True
    Get-DiskInfoSettings -Startup False
    Get-DiskInfoSettings -Resident True
    Get-DiskInfoSettings -Resident False
    .LINK
    https://github.com/Lifailon/CrystalDisk-Cli
    https://github.com/hiyohiyo/CrystalDiskInfo
    #>
    param (
        [ValidateSet(0,1,3,5,10,30,60,120,180,360,720,1440)]$AutoRefresh,
        [ValidateSet("True","False")]$Startup,
        [ValidateSet("True","False")]$Resident,
        $Path = "C:\Program Files\CrystalDiskInfo"
    )
    # Проверьте, существует ли заданный путь, если нет, то выбросьте ошибку
    if ((Test-Path $Path, "$Path\DiskInfo.ini") -contains $false) {
        Write-Error -Category ObjectNotFound -TargetObject $Path -Message "CrystalDiskInfo was not found at path: `"$Path`"."
        Write-Host -ForegroundColor Cyan "Try running `"winget install -e --id=CrystalDewWorld.CrystalDiskInfo`""
        break
    }
    $Config_ini = Get-Content "$Path\DiskInfo.ini"
    if ($AutoRefresh -or $Startup -or $Resident) {
        Get-Process *DiskInfo* | Stop-Process
        if ($AutoRefresh) {
            $Config_ini = $Config_ini -replace 'AutoRefresh=".+',"AutoRefresh=`"$AutoRefresh`""
            $Config_ini | Out-File "$Path\DiskInfo.ini" -Force
        }
        elseif ($Startup) {
            switch($Startup) {
                "True" {$Mode = "1"}
                "False" {$Mode = "0"}
            }
            $Config_ini = $Config_ini -replace 'Startup=".+',"Startup=`"$Mode`""
            $Config_ini | Out-File "$Path\DiskInfo.ini" -Force
        }
        elseif ($Resident ) {
            switch($Resident ) {
                "True" {$Mode = "1"}
                "False" {$Mode = "0"}
            }
            $Config_ini = $Config_ini -replace 'Resident=".+',"Resident=`"$Mode`""
            $Config_ini | Out-File "$Path\DiskInfo.ini" -Force
        }
        # Посмотрите, какая версия установлена
        $ExecutableEditions = @("$Path\DiskInfo64.exe", "$Path\DiskInfo64S.exe", "$Path\DiskInfo64A.exe", "$Path\DiskInfo64K.exe")
        $TestedPaths = Test-Path $ExecutableEditions
        # Если не найдено ни одного из них, выбросьте ошибку
        if ($TestedPaths -notcontains $true) {
            Write-Error -Category ObjectNotFound -TargetObject $ExecutableEditions[0] -Message "CrystalDiskInfo executable was not found! Validate your install."
            break
        }
        # Сопоставьте версию с путем к исполняемому файлу
        $Executable = $ExecutableEditions[$TestedPaths.IndexOf($true)]
        Start-Process -FilePath $Executable -WindowStyle Hidden
    }
    $(ConvertFrom-Ini $Config_ini).Setting
}