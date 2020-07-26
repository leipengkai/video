#!/usr/bin/env pwsh

# https://stackoverflow.com/questions/8761888/capturing-standard-out-and-error-with-start-process
function Start-Command ([String]$Path, [String]$Arguments) {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $Path
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $Arguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    return @{
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode
    }
}

# https://stackoverflow.com/questions/1783554/fast-and-simple-binary-concatenate-files-in-powershell
function Join-File ([String[]]$Path, [String]$Destination) {
    $OutFile = [IO.File]::Create($Destination)
    foreach ($File in $Path) {
        $InFile = [IO.File]::OpenRead($File)
        $InFile.CopyTo($OutFile)
        $InFile.Dispose()
    }
    $OutFile.Dispose()
}

# https://stackoverflow.com/questions/2570633/smallest-filesize-for-transparent-single-pixel-image#answer-15960901
[Byte[]]$SmallGIF = @(
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02
)

# $FFmpegExec = 'D:\ffmpeg\bin\ffmpeg.exe'
# $CurlExec = 'D:\curl-7.68.0-win64-mingw\bin\curl.exe'
$FFmpegExec = 'ffmpeg'
$CurlExec = 'curl'
if (Test-Path alias:\curl) {
    Remove-Item alias:\curl
}

$Video = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath((Read-Host 'Input H264+AAC video path').Replace('"', ''))

$TempDirectory = [IO.Path]::GetDirectoryName($Video) + '/' + [GUID]::NewGuid().ToString('N')
New-Item $TempDirectory -ItemType Directory

&$FFmpegExec -i $Video -c copy -vbsf h264_mp4toannexb -absf aac_adtstoasc ($TempDirectory + '/video.ts')
&$FFmpegExec -i ($TempDirectory + '/video.ts') -c copy -f segment -segment_list ($TempDirectory + '/video.m3u8') ($TempDirectory + '/%d.ts')
Remove-Item ($TempDirectory + '/video.ts')

$tsCount = (Get-ChildItem $TempDirectory -Filter *.ts).Length
do {
    $LimitExceed = $false
    foreach ($ts in (Get-ChildItem $TempDirectory -Filter *.ts)) {
        if ($ts.Length -gt (5MB - $SmallGIF.Length)) {
            $LimitExceed = $true
            Write-Host '[ERROR]' -NoNewline -BackgroundColor DarkRed -ForegroundColor White
            Write-Host (' File size limit exceeded: {0} ({1} MB)' -f $ts.Name, [Math]::Round($ts.Length / 1MB, 2))
        }
    }
    if ($LimitExceed) {
        Read-Host 'Compress the files and press enter to continue'
    }
} while ($LimitExceed)

Write-Host 'Parsing M3U8...'
$m3u8Source = [IO.File]::ReadAllLines($TempDirectory + '/video.m3u8')
$m3u8 = @{
    'meta' = @();
    'info' = @();
}
for ($i = 0; $i -lt $m3u8Source.Count; $i++) {
    if (($m3u8Source[$i] -eq '#EXTM3U') -or ($m3u8Source[$i] -eq '#EXT-X-ENDLIST')) {
        continue
    }

    if ($m3u8Source[$i].StartsWith('#EXTINF:')) {
        $m3u8.info += @{
            'duration' = [Double]($m3u8Source[$i].Replace('#EXTINF:', '').Replace(',', ''));
            'file' = $m3u8Source[++$i];
        }
    } else {
        $m3u8.meta += $m3u8Source[$i]
    }
}

Write-Host 'Merging TS files...'
$FastStart = 3
for ($i = 0; $i -lt $tsCount; $i++) {
    $LastPath = ('{0}/{1}.ts' -f $TempDirectory, ($i - 1))
    $CurrentPath = ('{0}/{1}.ts' -f $TempDirectory, $i)

    if (-not [IO.File]::Exists($LastPath)) {
        continue
    }

    if ((Get-Item $LastPath).Length + (Get-Item $CurrentPath).Length -le @(5MB, 2MB)[[Bool]$FastStart]) {
        Write-Host '[MERGE]' -NoNewline -BackgroundColor DarkGreen -ForegroundColor White
        Write-Host (' {0}.ts <- {1}.ts' -f $i, ($i - 1))
        Join-File -Path $LastPath, $CurrentPath -Destination ('{0}/~.ts' -f $TempDirectory)

        Remove-Item $LastPath
        Remove-Item $CurrentPath
        Rename-Item ('{0}/~.ts' -f $TempDirectory) ('{0}.ts' -f $i)
    } else {
        Write-Host '[SKIP]' -NoNewline -BackgroundColor DarkCyan -ForegroundColor White
        if ($FastStart -gt 0) {
            $FastStart--
            Write-Host (' {0}.ts ({1} MB FastStart)' -f $i, [Math]::Round((Get-Item $LastPath).Length / 1MB, 2))
        } else {
            Write-Host (' {0}.ts ({1} MB)' -f $i, [Math]::Round((Get-Item $LastPath).Length / 1MB, 2))
        }
    }
}

Write-Host 'Writing M3U8...'
$MergedInfo = @()
$tsLast = 0
for ($i = 0; $i -lt $tsCount; $i++) {
    if (-not [IO.File]::Exists(('{0}/{1}.ts' -f $TempDirectory, $i))) {
        continue
    }
    $MergedDuration = 0
    for ($j = $tsLast; $j -le $i; $j++) {
        $MergedDuration += $m3u8.info[$j].duration
    }
    $MergedInfo += @{
        'duration' = $MergedDuration;
        'file' = $m3u8.info[$i].file
    }
    $tsLast = $i + 1
}
$m3u8.info = $MergedInfo

$m3u8Content = @('#EXTM3U')
foreach ($meta in $m3u8.meta) {
    $m3u8Content += $meta
}
foreach ($info in $m3u8.info) {
    $m3u8Content += '#EXTINF:' + $info.duration + ','
    $m3u8Content += $info.file
}
$m3u8Content += '#EXT-X-ENDLIST'
[IO.File]::WriteAllLines($TempDirectory + '/video.m3u8', $m3u8Content)
Read-Host 'Press enter to start uploading'

$URLMapping = @{}
foreach ($ts in (Get-ChildItem $TempDirectory -Filter *.ts)) {
    $FileName = [IO.Path]::GetFileName($ts.FullName)
    $FileWithImage = $ts.FullName + '.gif'
    [IO.File]::WriteAllBytes($FileWithImage, [Byte[]]($SmallGIF + [IO.File]::ReadAllBytes($ts.FullName)))

    $Response = (Start-Command $CurlExec (@(
        'https://kfupload.alibaba.com/mupload',
        '-X POST',
        '-F scene=productImageRule',
        '-F name=image.gif',
        '-F file=@{0}' -f $FileWithImage
    ) -join ' ')).stdout | ConvertFrom-Json

    Remove-Item $FileWithImage

    if ([Bool][Int32]$Response.code) {
        Write-Host '[WARNING]' -NoNewline -BackgroundColor DarkYellow -ForegroundColor White
        Write-Host (' {0} Failed to upload' -f $FileName)
        $URL = $FileName
    } else {
        Write-Host '[UPLOAD]' -NoNewline -BackgroundColor DarkGreen -ForegroundColor White
        Write-Host (' {0} {1}' -f $FileName, $Response.url)
        $URL = $Response.url
    }

    $URLMapping.$FileName = $URL
}

Write-Host 'Writing M3U8 with URL...'
$m3u8Content = @('#EXTM3U')
foreach ($meta in $m3u8.meta) {
    $m3u8Content += $meta
}
foreach ($info in $m3u8.info) {
    $m3u8Content += '#EXTINF:' + $info.duration + ','
    $m3u8Content += $URLMapping.($info.file)
}
$m3u8Content += '#EXT-X-ENDLIST'
[IO.File]::WriteAllBytes($TempDirectory + '/video_online.m3u8.gif', [Byte[]]($SmallGIF + [Text.Encoding]::UTF8.GetBytes($m3u8Content -join "`n")))

Write-Host 'Complete!'
