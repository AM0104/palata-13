# Проверка всех скриптов проекта на ошибки парсинга/компиляции.
# В режиме --check-only автолоады (Game, Audio) не создаются, поэтому блоки
# "Identifier not found: Game/Audio" и каскад "Failed to compile depended scripts"
# считаются ожидаемым шумом и отбрасываются вместе со строками "at:".
param([string]$Project = "E:\2222")
$godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$noise = "Identifier not found: (Game|Audio|Settings)|Failed to compile depended scripts"
$files = Get-ChildItem "$Project\scripts" -Recurse -Filter *.gd | Sort-Object FullName
$bad = 0
foreach ($f in $files) {
    $rel = "res://" + $f.FullName.Substring($Project.Length + 1).Replace('\', '/')
    $out = & $godot --path $Project --headless --check-only --script $rel 2>&1 | Out-String
    $lines = $out -split "`n"
    $report = @()
    $skipBlock = $false
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match "^SCRIPT ERROR|^ERROR:.*Parse error") {
            $skipBlock = ($t -match $noise)
            if (-not $skipBlock) { $report += $t }
        } elseif ($t -match "^at: GDScript" -and -not $skipBlock -and $report.Count -gt 0) {
            $report += $t
        }
    }
    if ($report.Count -gt 0) {
        $bad++
        Write-Output "### $rel"
        $report | ForEach-Object { Write-Output ("    " + $_) }
    }
}
if ($bad -eq 0) { Write-Output "ALL SCRIPTS OK ($($files.Count) files)" } else { Write-Output "$bad file(s) with errors" }
