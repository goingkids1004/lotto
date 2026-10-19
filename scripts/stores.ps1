# 1등 배출 판매점(명당) 데이터 갱신
# - data/stores_raw.csv : 회차별 1등 판매점 원본 (262회부터, 새 회차만 추가)
# - data/stores.js      : 웹페이지용 요약 (전국 TOP, 시도별 TOP, 최근 회차 1등 판매점)
# 사용법: ./scripts/stores.ps1   (data/lotto.csv 의 마지막 회차까지 받아온다)
# Windows PowerShell 5.1 과 PowerShell 7(GitHub Actions) 모두에서 동작한다.
param([int]$From = 262, [int]$Top = 30, [int]$RegionTop = 10)

$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $PSScriptRoot
$rawPath = Join-Path $root 'data/stores_raw.csv'
$jsPath  = Join-Path $root 'data/stores.js'
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$utf8    = New-Object System.Text.UTF8Encoding $false
$cols    = '회차','판매점ID','상호','주소','지역','구분','위도','경도'

$lastRound = (Import-Csv (Join-Path $root 'data/lotto.csv') -Encoding UTF8 | Select-Object -Last 1).'회차' -as [int]
$raw = New-Object System.Collections.ArrayList
$done = $From - 1
if (Test-Path $rawPath) {
    foreach ($r in (Import-Csv $rawPath -Encoding UTF8)) { [void]$raw.Add($r) }
}
$metaPath = Join-Path $root 'data/stores_meta.txt'
if (Test-Path $metaPath) { $done = [int](Get-Content $metaPath -Encoding UTF8 -TotalCount 1) }
Write-Host "명당 데이터: ${done}회까지 받음, 당첨번호는 ${lastRound}회까지"

$api = 'https://www.dhlottery.co.kr/wnprchsplcsrch/selectLtWnShp.do'
$headers = @{ 'X-Requested-With' = 'XMLHttpRequest'; 'Referer' = 'https://www.dhlottery.co.kr/wnprchsplcsrch/home' }
$added = 0
try {
    for ($ep = $done + 1; $ep -le $lastRound; $ep++) {
        $res = Invoke-WebRequest -UseBasicParsing "${api}?srchWnShpRnk=1&srchLtEpsd=$ep&srchShpLctn=" -UserAgent 'Mozilla/5.0' -Headers $headers -TimeoutSec 30
        if ($res.Content.TrimStart() -notlike '{*') { throw "동행복권이 JSON 대신 다른 페이지를 돌려줬습니다 (${ep}회)" }
        foreach ($x in @(($res.Content | ConvertFrom-Json).data.list)) {
            if (-not $x) { continue }
            [void]$raw.Add([pscustomobject][ordered]@{
                '회차' = $ep; '판매점ID' = [string]$x.ltShpId; '상호' = [string]$x.shpNm; '주소' = ([string]$x.shpAddr).Trim()
                '지역' = [string]$x.region; '구분' = [string]$x.atmtPsvYnTxt; '위도' = [string]$x.shpLat; '경도' = [string]$x.shpLot })
            $added++
        }
        $done = $ep
        if ($ep % 50 -eq 0) { Write-Host "  ${ep}회까지 받음 (1등 판매점 누적 $($raw.Count)건)" }
        Start-Sleep -Milliseconds 200
    }
} catch {
    Write-Host "::warning::명당 데이터를 끝까지 받지 못했습니다 (${done}회까지 저장): $($_.Exception.Message)"
}

# 원본 저장
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine((($cols | ForEach-Object { '"' + $_ + '"' }) -join ','))
foreach ($r in $raw) { [void]$sb.AppendLine((($cols | ForEach-Object { '"' + ([string]$r.$_).Replace('"', '""') + '"' }) -join ',')) }
[System.IO.File]::WriteAllText($rawPath, $sb.ToString(), $utf8Bom)
[System.IO.File]::WriteAllText($metaPath, "$done`n", $utf8)

# 요약 만들기 (인터넷 판매는 매장 순위에서 제외하고 따로 집계)
$isOnline = { param($r) ($r.'상호' -like '*인터넷*') -or ($r.'주소' -like '*dhlottery*') }
$SidoList = '서울','부산','대구','인천','광주','대전','울산','세종','경기','강원','충북','충남','전북','전남','경북','경남','제주'
$GWANGJU_GU = '동구','서구','남구','북구','광산구'
# 원본의 지역 값이 비어 있거나 '전남광주'처럼 합쳐진 경우가 있어 주소로 시도를 정한다
function Get-Sido($r) {
    $tok = @(([string]$r.'주소').Trim() -split '\s+')
    $reg = ([string]$r.'지역').Trim()
    foreach ($cand in @($tok[0], $reg)) {
        if ($cand -eq '전남광주') { if ($tok.Count -gt 1 -and $GWANGJU_GU -contains $tok[1]) { return '광주' } else { return '전남' } }
        if ($SidoList -contains $cand) { return $cand }
    }
    return ''
}
function Fix-Addr([string]$a, [string]$sd) { $a = $a.Trim(); if ($sd -and $a.StartsWith('전남광주 ')) { return $sd + $a.Substring(4) } return $a }
$stores = @{}; $online = 0; $regionWins = @{}
foreach ($r in $raw) {
    if (& $isOnline $r) { $online++; continue }
    $id = if ($r.'판매점ID') { $r.'판매점ID' } else { $r.'상호' + '|' + $r.'주소' }
    if (-not $stores.ContainsKey($id)) { $stores[$id] = [ordered]@{ n = 0; auto = 0; manual = 0; semi = 0; last = 0; best = -1; name = ''; addr = ''; region = ''; lat = ''; lng = '' } }
    $s = $stores[$id]; $s.n++
    switch ($r.'구분') { '자동' { $s.auto++ } '수동' { $s.manual++ } '반자동' { $s.semi++ } }
    $ep = [int]$r.'회차'; $rs = Get-Sido $r
    if ($ep -ge $s.last) { $s.last = $ep; $s.name = $r.'상호' }
    # 주소·지역은 시도를 알 수 있는 가장 최근 기록을 쓴다 (없으면 가장 최근 기록)
    $score = $(if ($rs) { 100000 } else { 0 }) + $ep
    if ($score -gt $s.best) { $s.best = $score; $s.addr = Fix-Addr $r.'주소' $rs; $s.region = $(if ($rs) { $rs } else { '기타' }); $s.lat = $r.'위도'; $s.lng = $r.'경도' }
}
foreach ($s in $stores.Values) { $regionWins[$s.region] = [int]$regionWins[$s.region] + $s.n }
function Esc([string]$v) { '"' + $v.Replace('\', '\\').Replace('"', '\"') + '"' }
function StoreJs($s) { '[{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}]' -f (Esc $s.name), (Esc $s.addr), (Esc $s.region), $s.n, $s.auto, $s.manual, $s.semi, $s.last, $(if ($s.lat) { $s.lat } else { 'null' }), $(if ($s.lng) { $s.lng } else { 'null' }) }
$sorted = @($stores.Values | Sort-Object @{ e = { $_.n }; Descending = $true }, @{ e = { $_.last }; Descending = $true })
$js = New-Object System.Text.StringBuilder
[void]$js.AppendLine('// 자동 생성 파일 (scripts/stores.ps1). 판매점 = [상호, 주소, 시도, 1등횟수, 자동, 수동, 반자동, 마지막1등회차, 위도, 경도]')
[void]$js.AppendLine('window.LOTTO_STORES = {')
[void]$js.AppendLine("  from: $From, to: $done, online: $online, storeCount: $($stores.Count),")
[void]$js.AppendLine('  national: [' + (($sorted | Select-Object -First $Top | ForEach-Object { StoreJs $_ }) -join ',') + '],')
$regs = $regionWins.Keys | Where-Object { $_ -ne '기타' } | Sort-Object @{ e = { $regionWins[$_] }; Descending = $true }
[void]$js.AppendLine('  regionWins: {' + (($regs | ForEach-Object { (Esc $_) + ':' + $regionWins[$_] }) -join ',') + '},')
[void]$js.AppendLine('  regions: {')
$lines = foreach ($g in $regs) { '    ' + (Esc $g) + ': [' + ((@($sorted | Where-Object { $_.region -eq $g }) | Select-Object -First $RegionTop | ForEach-Object { StoreJs $_ }) -join ',') + ']' }
[void]$js.AppendLine(($lines -join ",`n"))
[void]$js.AppendLine('  },')
$latest = @($raw | Where-Object { [int]$_.'회차' -eq $done })
[void]$js.AppendLine('  latest: [' + (($latest | ForEach-Object { $sd = $(if (& $isOnline $_) { '인터넷' } else { Get-Sido $_ }); '[{0},{1},{2},{3}]' -f (Esc $_.'상호'), (Esc (Fix-Addr $_.'주소' $sd)), (Esc $sd), (Esc $_.'구분') }) -join ',') + ']')
[void]$js.AppendLine('};')
[System.IO.File]::WriteAllText($jsPath, $js.ToString(), $utf8)
Write-Host "완료: ${From}~${done}회 1등 $($raw.Count)건 (새로 ${added}건), 판매점 $($stores.Count)곳, 인터넷 ${online}건"
