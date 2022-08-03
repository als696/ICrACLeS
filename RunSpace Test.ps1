$MaxThreads = 5
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$PowerShell = [powershell]::Create()
$PowerShell.RunspacePool = $RunspacePool
$RunspacePool.Open()
$Jobs = @()

1..10 | Foreach-Object {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $PowerShell.AddScript({Start-Sleep 5})
    $Jobs += $PowerShell.BeginInvoke()
}
while ($Jobs.IsCompleted -contains $false) {Start-Sleep -Milliseconds 100}