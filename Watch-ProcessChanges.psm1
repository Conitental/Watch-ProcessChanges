<#
.SYNOPSIS
Monitors and reports changes in running processes, including creation and termination.

.DESCRIPTION
The Watch-ProcessChanges function continuously monitors the system for changes in running processes. It can be configured to include or exclude specific processes based on their names or IDs using whitelist and blacklist parameters. The function reports the creation and termination of processes at specified intervals.

.PARAMETER WatchInterval
The interval, in milliseconds, at which to check for process changes (default is 200 ms).

.PARAMETER ExcludeProcessName
An array of process names to exclude from monitoring. Processes matching these names will not trigger notifications.

.PARAMETER ExcludeProcessId
An array of process IDs to exclude from monitoring. Processes with these IDs will not trigger notifications.

.PARAMETER ProcessName
An array of process names to include in monitoring. Only processes matching these names will trigger notifications.

.PARAMETER ProcessId
An array of process IDs to include in monitoring. Only processes with these IDs will trigger notifications.

.EXAMPLE
Watch-ProcessChanges -WatchInterval 500 -ExcludeProcessName "notepad"

.EXAMPLE
Watch-ProcessChanges -WatchInterval 1000 -ProcessName "powershell", "explorer"

#>

Function Watch-ProcessChanges {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Blacklist')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Whitelist')]
        [int]$WatchInterval = 200,

        [Parameter(Mandatory = $false, ParameterSetName = 'Blacklist')]
        [string[]]$ExcludeProcessName = @(),

        [Parameter(Mandatory = $false, ParameterSetName = 'Blacklist')]
        [int[]]$ExcludeProcessId = @(),

        [Parameter(Mandatory = $false, ParameterSetName = 'Whitelist')]
        [string[]]$ProcessName = @(),

        [Parameter(Mandatory = $false, ParameterSetName = 'Whitelist')]
        [int[]]$ProcessId = @()
    )

    Begin {
        Write-Verbose "Getting initial process list"
        $PreviousProcesses = Get-Process

        $BeginTime = Get-Date
    }

    Process {
        While($true) {
            $CurrentProcesses = Get-Process

            # Find closed and new process by comparing the pid
            $Comparison = Compare-Object -ReferenceObject $PreviousProcesses -DifferenceObject $CurrentProcesses -Property 'Id'

            Foreach ($Process in $Comparison) {
                # Define the action depending on the comparison and decide where to get the process data
                If($Process.SideIndicator -eq '=>') {
                    Write-Verbose "PID $($Process.Id) has been created"
                    $Action = 'created'

                    # Created process data comes from the current processes
                    $ProcessData = $CurrentProcesses | Where-Object -Property 'Id' -eq $Process.Id
                } Else {
                    Write-Verbose "PID $($Process.Id) has been created"
                    $Action = 'closed'

                    # Closed process data comes from the previous processes
                    $ProcessData = $PreviousProcesses | Where-Object -Property 'Id' -eq $Process.Id
                }

                # Whitelist parameter set
                If(($ProcessName.Count -gt 0) -and ($ProcessName -notcontains $ProcessData.ProcessName)) {
                    Write-Verbose "Process: $($ProcessData.ProcessName) could not be found in the process whitelist. Ignore"
                    Continue
                }
                If(($ProcessId.Count -gt 0) -and ($ProcessId -notcontains $ProcessData.Id)) {
                    Write-Verbose "PID: $($ProcessData.Id) could not be found in the process whitelist. Ignore"
                    Continue
                }

                # Blacklist parameter set
                If(($ExcludeProcessName.Count -gt 0) -and ($ExcludeProcessName -contains $ProcessData.ProcessName)) {
                    Write-Verbose "Process: $($ProcessData.ProcessName) has been found in the process blacklist. Ignore"
                    Continue
                }
                If(($ExcludeProcessId.Count -gt 0) -and ($ExcludeProcessId -contains $ProcessData.Id)) {
                    Write-Verbose "PID: $($ProcessData.Id) has been found in the process blacklist. Ignore"
                    Continue
                }

                $DateTime = Get-Date -Format 'yyyy-MM-dd hh:mm:ss.ff'

                Write-Output "[$DateTime] $($ProcessData.ProcessName) ($($ProcessData.Id)) has been $Action"
            }

            # Reset the previous processes to compare in the next cycle
            $PreviousProcesses = $CurrentProcesses

            Start-Sleep -Milliseconds $WatchInterval
        }
    }
}

Export-ModuleMember -Function Watch-ProcessChanges
