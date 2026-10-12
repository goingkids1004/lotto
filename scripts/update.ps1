# 동행복권에서 새 회차를 받아 data/lotto.csv 에 추가하고, 웹페이지용 data/lotto.js 를 다시 만든다.
# 사용법: ./scripts/update.ps1            (새 회차만 추가)
#         ./scripts/update.ps1 -RebuildOnly (CSV -> JS 변환만)
# Windows PowerShell 5.1 과 PowerShell 7(GitHub Actions) 모두에서 동작한다.
param([switch]$RebuildOnly)

$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root 'data/lotto.csv'
$jsPath  = Join-Path $root 'data/lotto.js'
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$utf8    = New-Object System.Text.UTF8Encoding $false
$cols    = '회차','추첨일','번호1','번호2','번호3','번호4','번호5','번호6','보너스','1등당첨자수','1등당첨금'

$rows = @{}
foreach ($r in (Import-Csv $csvPath -Encoding UTF8)) {
    $rows[[int]$r.'회차'] = @([int]$r.'회차', $r.'추첨일') + @($cols[2..10] | ForEach-Object { [long]$r.$_ })
}
$before = ($rows.Keys | Measure-Object -Maximum).Maximum
Write-Host "현재 마지막 회차: $before"

if (-not $RebuildOnly) {
    $api = 'https://www.dhlottery.co.kr/lt645/selectPstLt645InfoNew.do'
    $headers = @{ 'X-Requested-With' = 'XMLHttpRequest'; 'Referer' = 'https://www.dhlottery.co.kr/lt645/result' }
    try {
        while ($true) {
            $cursor = ($rows.Keys | Measure-Object -Maximum).Maximum
            $res = Invoke-WebRequest -UseBasicParsing "${api}?srchDir=latest&srchCursorLtEpsd=$cursor" `
                -UserAgent 'Mozilla/5.0' -Headers $headers -TimeoutSec 30
            if ($res.Content.TrimStart() -notlike '{*') { throw '동행복권이 JSON 대신 다른 페이지를 돌려줬습니다 (사이트 점검 또는 주소 변경)' }
            $list = @(($res.Content | ConvertFrom-Json).data.list)
            $new = @($list | Where-Object { $_ -and [int]$_.ltEpsd -gt $cursor })
            if ($new.Count -eq 0) { break }
            foreach ($x in $new) {
                $d = [string]$x.ltRflYmd
                $rows[[int]$x.ltEpsd] = @([int]$x.ltEpsd, ('{0}-{1}-{2}' -f $d.Substring(0,4), $d.Substring(4,2), $d.Substring(6,2)),
                    [long]$x.tm1WnNo, [long]$x.tm2WnNo, [long]$x.tm3WnNo, [long]$x.tm4WnNo, [long]$x.tm5WnNo, [long]$x.tm6WnNo,
                    [long]$x.bnsWnNo, [long]$x.rnk1WnNope, [long]$x.rnk1WnAmt)
            }
            Start-Sleep -Milliseconds 300
        }
    } catch {
        # 받아오기에 실패해도 기존 데이터는 그대로 두고, 사이트 배포는 계속되게 한다
        Write-Host "::warning::새 회차를 받아오지 못했습니다: $($_.Exception.Message)"
    }
}

$keys = $rows.Keys | Sort-Object
$after = $keys[-1]
# 회차가 빠진 곳이 있으면 잘못된 데이터를 쓰지 않도록 중단
$missing = 1..$after | Where-Object { -not $rows.ContainsKey($_) }
if ($missing) { throw "빠진 회차가 있습니다: $($missing -join ', ')" }

$csv = New-Object System.Text.StringBuilder
[void]$csv.AppendLine((($cols | ForEach-Object { '"' + $_ + '"' }) -join ','))
$js = New-Object System.Text.StringBuilder
[void]$js.AppendLine('// 자동 생성 파일 (scripts/update.ps1). [회차, 추첨일, n1..n6, 보너스, 1등당첨자수, 1등당첨금]')
[void]$js.AppendLine('window.LOTTO_DATA = [')
foreach ($k in $keys) {
    $v = $rows[$k]
    [void]$csv.AppendLine((($v | ForEach-Object { '"' + $_ + '"' }) -join ','))
    $line = '[{0},"{1}",{2}]' -f $v[0], $v[1], (($v[2..10]) -join ',')
    [void]$js.AppendLine($line + $(if ($k -ne $after) { ',' } else { '' }))
}
[void]$js.AppendLine('];')

[System.IO.File]::WriteAllText($csvPath, $csv.ToString(), $utf8Bom)
[System.IO.File]::WriteAllText($jsPath, $js.ToString(), $utf8)
Write-Host "완료: $($keys.Count)회차 (1회 ~ ${after}회), 새로 추가 $($after - $before)회차"
