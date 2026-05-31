function Show-RestoreBackupWindow {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner = $null
    )

    try {
        Write-Host 'Opening restore backup dialog.'

        $dialogResult = Show-RestoreBackupDialog -Owner $Owner
        if (-not $dialogResult -or $dialogResult.Result -eq 'Cancel') {
            Write-Host 'Restore canceled by user.'
            return
        }

        $successMessage = $null
        $warningMessage = $null

        if ($dialogResult.Result -eq 'RestoreRegistry') {
            $backup = $dialogResult.Backup
            if (-not $backup) {
                throw 'Registry backup restore requested without a selected backup.'
            }

            Write-Host "User confirmed registry restore for $($backup.Target)."
            Restore-RegistryBackupState -Backup $backup
            $successMessage = '注册表备份还原成功。请重启计算机以使所有更改生效。'
        }
        elseif ($dialogResult.Result -eq 'RestoreStartMenu') {
            $scope = $dialogResult.StartMenuScope
            $useManualBackupFile = ($dialogResult.UseManualBackupFile -eq $true)
            $backupFilePath = $null
            if ($dialogResult -is [hashtable] -and $dialogResult.ContainsKey('BackupFilePath')) {
                $backupFilePath = $dialogResult['BackupFilePath']
            }
            elseif ($dialogResult.PSObject.Properties.Match('BackupFilePath').Count -gt 0) {
                $backupFilePath = $dialogResult.BackupFilePath
            }

            if ($useManualBackupFile -and [string]::IsNullOrWhiteSpace($backupFilePath)) {
                throw 'Start Menu restore canceled: no backup file selected.'
            }

            $result = if ($scope -eq 'AllUsers') {
                RestoreStartMenuForAllUsers -BackupFilePath $backupFilePath
            }
            else {
                RestoreStartMenu -BackupFilePath $backupFilePath
            }

            $resultEntries = @($result)
            $successCount = @($resultEntries | Where-Object { $_.Result -eq $true }).Count
            $failedEntries = @($resultEntries | Where-Object { $_.Result -ne $true })

            if ($successCount -eq 0) {
                $errorSummary = ($resultEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                throw "还原开始菜单备份失败。`n$errorSummary"
            }

            if ($failedEntries.Count -gt 0) {
                $failureSummary = ($failedEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                $warningMessage = "The Start Menu backup was successfully restored for $successCount user(s).`nSome users could not be restored:`n$failureSummary"
            }
            else {
                if ($scope -eq 'AllUsers') {
                    $successMessage = "开始菜单备份已成功为所有用户还原。更改将在用户下次登录时生效。"
                }
                else {
                    $successMessage = "开始菜单备份已成功为当前用户还原。更改将在你下次登录时生效。"
                }
            }
        }

        if ($warningMessage) {
            Write-Host "$warningMessage"
            Show-MessageBox -Title '备份已还原' -Message $warningMessage -Icon Warning
        }
        elseif ($successMessage) {
            Write-Host "$successMessage"
            Show-MessageBox -Title '备份已还原' -Message $successMessage -Icon Success
        }
    }
    catch {
        $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { '发生意外错误。' }
        Write-Error "Restore operation failed: $errorMessage"
        Show-MessageBox -Title '错误' -Message "Restore failed: $errorMessage" -Icon Error
    }
}
