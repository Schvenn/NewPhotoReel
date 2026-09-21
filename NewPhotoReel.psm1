function newphotoreel ([string]$Folder, [int]$MP3SpeedAdjust = 13, [double]$PhotoDuration = 1.5, [string]$FirstPhoto, [string]$LastPhoto, [string]$Watermark, [double]$Volume = 100, [string]$IntroText, [string]$OutroText, [ValidateSet('Chronological','Filename','Random')][string]$Order = 'Chronological', [switch]$KenBurns, [switch]$RandomTransition, [switch]$help) {# Create a Facebook safe photo reel from the images and mp3 stored in a specific directory.

# Resolve watermark only when -Watermark is specified.
if ($PSBoundParameters.ContainsKey('Watermark')) {if ([string]::IsNullOrWhiteSpace($Watermark) -or $Watermark -eq 'default') {$Watermark = Join-Path $PSScriptRoot 'watermark.png'}
if (-not (Test-Path -LiteralPath $Watermark -PathType Leaf)) {throw "Watermark file was not found: $Watermark"}
$Watermark = (Resolve-Path -LiteralPath $Watermark).Path}
else {$Watermark = $null}

# Load settings.
function LoadConfiguration {$script:ConfigPath = Join-Path $PSScriptRoot 'NewPhotoReel.psd1'
if (!(Test-Path $script:ConfigPath)) {throw "Config file not found at $script:ConfigPath"}
$script:Config = Import-PowerShellDataFile -Path $script:ConfigPath

# Pull config values into variables.
$script:Path = $script:Config.PrivateData.Path

$script:Height = [int]$script:Config.PrivateData.Height
$script:Width = [int]$script:Config.PrivateData.Width
$script:MaxPictureHeight = [int]$script:Config.PrivateData.MaxPictureHeight
$script:MaxPictureWidth = [int]$script:Config.PrivateData.MaxPictureWidth

$script:TransitionDuration = [double]$script:Config.PrivateData.TransitionDuration
$script:RandomTransitions = @($script:Config.PrivateData.RandomTransitions)
$script:FrameRate = [int]$script:Config.PrivateData.FrameRate

$script:AudioSkip = [int]$script:Config.PrivateData.AudioSkip
$script:AudioFadeIn = [int]$script:Config.PrivateData.AudioFadeIn
$script:AudioFadeOut = [int]$script:Config.PrivateData.AudioFadeOut
$script:Volume = [double]$script:Config.PrivateData.Volume

$script:FontFile = [string]$script:Config.PrivateData.FontFile
$script:IntroText = [string]$script:Config.PrivateData.IntroText
$script:OutroText = [string]$script:Config.PrivateData.OutroText
$script:TextCardBackground = [string]$script:Config.PrivateData.TextCardBackground
$script:TextCardDuration = [double]$script:Config.PrivateData.TextCardDuration
$script:TextCardFontSize = [int]$script:Config.PrivateData.TextCardFontSize
$script:TextCardMaxWidth = [int]$script:Config.PrivateData.TextCardMaxWidth

$script:WatermarkRight = [int]$script:Config.PrivateData.Watermark.Right
$script:WatermarkBottom = [int]$script:Config.PrivateData.Watermark.Bottom}
LoadConfiguration

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

# Wrap text-card text to the configured maximum width.
function WrapTextCard ($text) {if ([string]::IsNullOrWhiteSpace($text)) {return $text}
$maximumCharacters = [Math]::Max(10,[Math]::Floor($script:TextCardMaxWidth / ($script:TextCardFontSize * 0.45)))
$lines = @()
foreach ($line in ($text -split "`r?\n")) {if ($line.Length -le $maximumCharacters) {$lines += $line; continue}
$remaining = $line
while ($remaining.Length -gt $maximumCharacters) {$breakAt = $remaining.LastIndexOf(' ', $maximumCharacters - 1)
if ($breakAt -lt 1) {$breakAt = $maximumCharacters}
$lines += $remaining.Substring(0,$breakAt).TrimEnd()
$remaining = $remaining.Substring($breakAt).TrimStart()}
$lines += $remaining}
return ($lines -join "`n")}

function help {# Inline help.
# Select content.
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)"); $selection = $null; $lines = @(); $wrappedLines = @(); $position = 0; $pageSize = 30; $inputBuffer = ""

function scripthelp ($section) {$pattern = "(?ims)^## ($([regex]::Escape($section)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}

# Display Table of Contents.
while ($true) {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n"

if ($sections.Count -gt 7) {$half = [Math]::Ceiling($sections.Count / 2)
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; $leftNumber  = "{0,2}." -f ($leftIndex + 1); $leftLabel   = " $($sections[$leftIndex].Groups[1].Value)"; $leftOutput  = [string]::Empty

if ($rightIndex -lt $sections.Count) {$rightNumber = "{0,2}." -f ($rightIndex + 1); $rightLabel  = " $($sections[$rightIndex].Groups[1].Value)"; Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel -n; $pad = 40 - ($leftNumber.Length + $leftLabel.Length)
if ($pad -gt 0) {Write-Host (" " * $pad) -n}; Write-Host -f cyan $rightNumber -n; Write-Host -f white $rightLabel}
else {Write-Host -f cyan $leftNumber -n; Write-Host -f white $leftLabel}}}

else {for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host -f cyan ("{0,2}. " -f ($i + 1)) -n; Write-Host -f white "$($sections[$i].Groups[1].Value)"}}

# Display Header.
line yellow 100
if ($lines.Count -gt 0) {Write-Host  -f yellow $lines[0]}
else {Write-Host "Choose a section to view." -f darkgray}
line yellow 100

# Display content.
$end = [Math]::Min($position + $pageSize, $wrappedLines.Count)
for ($i = $position; $i -lt $end; $i++) {Write-Host -f white $wrappedLines[$i]}

# Pad display section with blank lines.
for ($j = 0; $j -lt ($pageSize - ($end - $position)); $j++) {Write-Host ""}

# Display menu options.
line yellow 100; Write-Host -f white "[↑/↓]  [PgUp/PgDn]  [Home/End]  |  [#] Select section  |  [Q] Quit  " -n; if ($inputBuffer.length -gt 0) {Write-Host -f cyan "section: $inputBuffer" -n}; $key = [System.Console]::ReadKey($true)

# Define interaction.
switch ($key.Key) {'UpArrow' {if ($position -gt 0) { $position-- }; $inputBuffer = ""}
'DownArrow' {if ($position -lt ($wrappedLines.Count - $pageSize)) { $position++ }; $inputBuffer = ""}
'PageUp' {$position -= 30; if ($position -lt 0) {$position = 0}; $inputBuffer = ""}
'PageDown' {$position += 30; $maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); if ($position -gt $maxStart) {$position = $maxStart}; $inputBuffer = ""}
'Home' {$position = 0; $inputBuffer = ""}
'End' {$maxStart = [Math]::Max(0, $wrappedLines.Count - $pageSize); $position = $maxStart; $inputBuffer = ""}

'Enter' {if ($inputBuffer -eq "") {"`n"; return}
elseif ($inputBuffer -match '^\d+$') {$index = [int]$inputBuffer
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index; $pattern = "(?ims)^## ($([regex]::Escape($sections[$selection-1].Groups[1].Value)).*?)(?=^##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $block = $match.Groups[1].Value.TrimEnd(); $lines = $block -split "`r?`n", 2
if ($lines.Count -gt 1) {$wrappedLines = (wordwrap $lines[1] 100) -split "`n", [System.StringSplitOptions]::None}
else {$wrappedLines = @()}
$position = 0}}
$inputBuffer = ""}

default {$char = $key.KeyChar
if ($char -match '^[Qq]$') {"`n"; return}
elseif ($char -match '^\d$') {$inputBuffer += $char}
else {$inputBuffer = ""}}}}}

# External call to help.
if ($help) {help; return}

# -------------------------------------- Load FFMPEG path. ----------------------------------------
$env:Path += ";$script:Path"
$PhotoDuration = [Math]::Round($PhotoDuration, 1)
$AudioSpeed = ($MP3SpeedAdjust / 100) + 1

# -------------------------------------- Set volume. ----------------------------------------------
if ($null -ne $Volume) {$script:Volume = $Volume}
if ($script:Volume -lt 0 -or $script:Volume -gt 200) {throw "Volume must be between 0 and 200 percent."}

# -------------------------------------- Set intro and outro text. --------------------------------
if ($PSBoundParameters.ContainsKey('IntroText')) {$script:IntroText = $IntroText}
if ($PSBoundParameters.ContainsKey('OutroText')) {$script:OutroText = $OutroText}

# -------------------------------------- Usage. ---------------------------------------------------
function usage {Write-Host -f cyan "`nUsage: NewPhotoReel <Folder> -MP3SpeedAdjust ## -PhotoDuration #.# -FirstPhoto 'filename.ext' -LastPhoto 'filename.ext' -WaterMark 'default|watermark.png' -Volume ## -IntroText 'sample' -OutroText 'sample' -Order 'Chronological/Filename/Random' -KenBurns -RandomTransition -Help"
Write-Host -f cyan "`nFolder: `t`t" -n; Write-Host -f white "Path to the folder containing the MP3 file and all the relevant photos."
Write-Host -f cyan "MP3SpeedAdjust: `t" -n; Write-Host -f white "The percentage of speed adjustment to apply to the MP3 file. The default is 13."
Write-Host -f cyan "PhotoDuration: `t`t" -n; Write-Host -f white "The number of seconds each photo should be displayed. The default is 1.5."
Write-Host -f yellow "`nThe following switches are all optional.`n"
Write-Host -f cyan "FirstPhoto: `t`t" -n; Write-Host -f white "The first photo to display."
Write-Host -f cyan "LastPhoto: `t`t" -n; Write-Host -f white "The last photo to display."
Write-Host -f cyan "Watermark: `t`t" -n; Write-Host -f white "Define a watermark file to display. Use 'default' or specify a full path."
Write-Host -f cyan "Volume: `t`t" -n; Write-Host -f white "Set the volume percentage."
Write-Host -f cyan "IntroText: `t`t" -n; Write-Host -f white "Add a text based introduction frame."
Write-Host -f cyan "OutroText: `t`t" -n; Write-Host -f white "Add a text-based final frame."
Write-Host -f cyan "Order: `t`t`t" -n; Write-Host -f white "Set the order to Chronological, Filename (alphabetical), or Random."
Write-Host -f cyan "KenBurns: `t`t" -n; Write-Host -f white "Use the zoom transition made famous by documentary film maker Ken Burns."
Write-Host -f cyan "RandomTransition: `t" -n; Write-Host -f white "Use a random transition."
Write-Host -f cyan "Help: `t`t`t" -n; Write-Host -f white "Call the full Help menu.`n"}
if ([string]::IsNullOrWhiteSpace($Folder)) {usage; return}

# -------------------------------------- Resolve folder and derive names. -------------------------
$PhotoFolder = (Resolve-Path -LiteralPath $Folder).Path
$folderInfo = [System.IO.DirectoryInfo]$PhotoFolder
$folderName = $folderInfo.Name
$OutputFile = "$folderName.mp4"

# -------------------------------------- Find FFmpeg and validate settings. -----------------------
$ffmpegCandidates = @('C:\Tools\ffmpeg\bin\ffmpeg.exe', 'C:\Program Files\ffmpeg\bin\ffmpeg.exe')
$ffmpeg = $ffmpegCandidates | Where-Object {Test-Path $_} | Select-Object -First 1
if (-not $ffmpeg) {$ffmpegCommand = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if ($ffmpegCommand) {$ffmpeg = $ffmpegCommand.Source}}
if (-not $ffmpeg) {throw 'FFmpeg.exe was not found.'}
cls
$ffmpegVersion = & $ffmpeg -version 2>&1 | Select-Object -First 1
Write-Host -f yellow "`nNew Facebook Friendly Photo Reel:"
Write-Host -f yellow ("-" * 100)
Write-Host -f white $ffmpegVersion
Write-Host -f yellow "`nSource"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "FFMPEG Location: " -n; Write-Host -f yellow "$ffmpeg"
if ($ffmpegVersion -match 'ffmpeg version (\d+)\.') {if ([int]$Matches[1] -lt 4) {throw 'FFmpeg 4.0 or newer is required.'}}
if ($PhotoDuration -le 0) {throw 'PhotoDuration must be greater than zero.'}
if ($TransitionDuration -lt 0) {throw 'TransitionDuration cannot be negative.'}
if ($TransitionDuration -ge $PhotoDuration) {throw 'TransitionDuration must be less than PhotoDuration.'}
if ($Width -le 0 -or $Height -le 0) {throw 'Width and Height must be greater than zero.'}
if ($MaxPictureWidth -le 0 -or $MaxPictureHeight -le 0) {throw 'MaxPictureWidth and MaxPictureHeight must be greater than zero.'}
if ($FrameRate -le 0) {throw 'FrameRate must be greater than zero.'}
if ($AudioSpeed -le 0) {throw 'AudioSpeed must be greater than zero.'}

# -------------------------------------- Find the first MP3 in the folder. ------------------------
$MusicFile = Get-ChildItem -LiteralPath $PhotoFolder -File -Filter '*.mp3' | Sort-Object Name | Select-Object -First 1
if (-not $MusicFile) {throw "No MP3 file was found in '$PhotoFolder'."}

# -------------------------------------- Find photos. ---------------------------------------------
$photos = Get-ChildItem -LiteralPath $PhotoFolder -File | Where-Object {$_.Extension -match '^\.(jpg|jpeg|png)$'} | Sort-Object @{Expression = {if ($_.BaseName -match '(\d{4})[-_.](\d{2})[-_.](\d{2})') {try {[datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])}
catch {$_.LastWriteTime}}
elseif ($_.BaseName -match '(\d{4})(\d{2})(\d{2})') {try {[datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])}
catch {$_.LastWriteTime}}
else {$_.LastWriteTime}}}, Name

# -------------------------------------- Apply ordering, then First, Last photo repositions. ------
if ($Order -eq 'Filename') {$photos = @($photos | Sort-Object Name)}
elseif ($Order -eq 'Random') {$photos = @($photos | Sort-Object {Get-Random})}

# Reorder photos when FirstPhoto/LastPhoto are specified.
$photos = @($photos | Where-Object {$_ -and $_.FullName})
$firstPhotoObject = $null
$lastPhotoObject = $null
if ($FirstPhoto) {$firstName = Split-Path $FirstPhoto -Leaf
$firstPhotoObject = $photos | Where-Object {$_.Name -eq $firstName} | Select-Object -First 1
if (-not $firstPhotoObject) {throw "FirstPhoto '$firstName' was not found in '$PhotoFolder'."}
$photos = @($photos | Where-Object {$_.FullName -ne $firstPhotoObject.FullName})}
if ($LastPhoto) {$lastName = Split-Path $LastPhoto -Leaf
$lastPhotoObject = $photos | Where-Object {$_.Name -eq $lastName} | Select-Object -First 1

# If FirstPhoto and LastPhoto are the same file, get it from the original list.
if (-not $lastPhotoObject -and $firstPhotoObject -and $firstPhotoObject.Name -eq $lastName) {$lastPhotoObject = $firstPhotoObject}
if (-not $lastPhotoObject) {throw "LastPhoto '$lastName' was not found in '$PhotoFolder'."}
$photos = @($photos | Where-Object {$_.FullName -ne $lastPhotoObject.FullName})}

# Put FirstPhoto first, then LastPhoto last.
$reorderedPhotos = @()
if ($firstPhotoObject) {$reorderedPhotos += $firstPhotoObject}
$reorderedPhotos += $photos
if ($lastPhotoObject -and $lastPhotoObject.FullName -ne $firstPhotoObject.FullName) {$reorderedPhotos += $lastPhotoObject}
$photos = @($reorderedPhotos)
$photoCount = $photos.Count

# -------------------------------------- Set effective picture size. -------------------------00000
$effectiveMaxWidth = [Math]::Min($MaxPictureWidth, $Width)
$effectiveMaxHeight = [Math]::Min($MaxPictureHeight, $Height)

# -------------------------------------- Video timing. --------------------------------------------
$photoVideoDuration = $photoCount * $PhotoDuration
$clipDuration = $PhotoDuration + $TransitionDuration
$introDuration = if ([string]::IsNullOrWhiteSpace($script:IntroText)) {0} else {$script:TextCardDuration}
$outroDuration = if ([string]::IsNullOrWhiteSpace($script:OutroText)) {0} else {$script:TextCardDuration}
$videoDuration = $introDuration + $photoVideoDuration + $outroDuration

# -------------------------------------- Audio fade timing. ---------------------------------------
$audioFadeOutStart = [Math]::Max(0, $videoDuration - $AudioFadeOut)

# -------------------------------------- Display output settings. ---------------------------------
function displayoutputsettings {Write-Host -f cyan "Source Folder:   " -n; Write-Host -f yellow "$PhotoFolder"
Write-Host -f cyan "Watermark:       " -n; Write-Host -f yellow "$Watermark`n"
Write-Host -f yellow "Pictures"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "First Photo:  " -n; Write-Host -f yellow "$FirstPhoto"
Write-Host -f cyan "Last Photo:   " -n; Write-Host -f yellow "$LastPhoto"
Write-Host -f cyan "Photos:       " -n; Write-Host -f white "$photoCount"
Write-Host -f cyan "Photo timing: " -n; Write-Host -f white "$PhotoDuration sec"
Write-Host -f cyan "Transition:   " -n; Write-Host -f white "$TransitionDuration sec"
Write-Host -f cyan "Order:        " -n; Write-Host -f white "$Order`n"
Write-Host -f yellow "Audio"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Audio:        " -n; Write-Host -f yellow "$($MusicFile.Name)"
Write-Host -f cyan "Audio Speed:  " -n; Write-Host -f white "$($AudioSpeed * 100)%"
Write-Host -f cyan "Audio Volume: " -n; Write-Host -f white "$script:Volume%`n"
Write-Host -f yellow "Text"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Intro text:   " -n; Write-Host -f yellow "$script:IntroText"
Write-Host -f cyan "Outro text:   " -n; Write-Host -f yellow "$script:OutroText`n"
Write-Host -f yellow "Output"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Output File:  " -n; Write-Host -f yellow "$OutputFile"
Write-Host -f cyan "Duration:     " -n; Write-Host -f white "$([Math]::Round($videoDuration, 0)) seconds"
Write-Host -f cyan "Resolution:   " -n; Write-Host -f white "${Height} x ${Width}`n"
Write-Host -f yellow ("-" * 50)}
displayoutputsettings

# -------------------------------------- Build FFmpeg input arguments. ----------------------------
$ffmpegArgs = [System.Collections.Generic.List[string]]::new()
foreach ($photo in $photos) {$ffmpegArgs.Add('-loop')
$ffmpegArgs.Add('1')
$ffmpegArgs.Add('-t')
$ffmpegArgs.Add($clipDuration.ToString([System.Globalization.CultureInfo]::InvariantCulture))
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add($photo.FullName)}

# -------------------------------------- Add intro and outro text card inputs. --------------------
$introIndex = $photoCount
$outroIndex = $photoCount + [int]($introDuration -gt 0)
if ($introDuration -gt 0) {$ffmpegArgs.Add('-f')
$ffmpegArgs.Add('lavfi')
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add("color=c=$($script:TextCardBackground):s=${Width}x${Height}:r=${FrameRate}:d=$introDuration")}
if ($outroDuration -gt 0) {$ffmpegArgs.Add('-f')
$ffmpegArgs.Add('lavfi')
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add("color=c=$($script:TextCardBackground):s=${Width}x${Height}:r=${FrameRate}:d=$outroDuration")}

# -------------------------------------- Add watermark image. -------------------------------------
$watermarkIndex = $photoCount + [int]($introDuration -gt 0) + [int]($outroDuration -gt 0)
if ($Watermark) {if (-not (Test-Path -LiteralPath $Watermark -PathType Leaf)) {throw "Watermark file was not found: $Watermark"}
$ffmpegArgs.Add('-loop')
$ffmpegArgs.Add('1')
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add((Resolve-Path -LiteralPath $Watermark).Path)}

# -------------------------------------- Loop audio as often as required. -------------------------
$audioIndex = $photoCount + [int]($introDuration -gt 0) + [int]($outroDuration -gt 0) + [int]([bool]$Watermark)
$ffmpegArgs.Add('-stream_loop')
$ffmpegArgs.Add('-1')
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add($MusicFile.FullName)

# -------------------------------------- Build video filters. -------------------------------------
$filterParts = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $photoCount; $i++) {$filter = "[${i}:v]"

# Ken Burns style zooming in.
if ($KenBurns) {$filter += "scale=${effectiveMaxWidth}:${effectiveMaxHeight}:force_original_aspect_ratio=increase,"
$filter += "scale=trunc(iw/2)*2:trunc(ih/2)*2,"
$filter += "scale=w='iw*(1+0.03*t/${clipDuration})':h='ih*(1+0.03*t/${clipDuration})':eval=frame,"
$filter += "crop=${Width}:${Height}:(iw-${Width}):(ih-${Height}),"
$filter += "fps=${FrameRate},"}

else {$filter += "scale=${effectiveMaxWidth}:${effectiveMaxHeight}:force_original_aspect_ratio=decrease,"
$filter += "scale=trunc(iw/2)*2:trunc(ih/2)*2,"
$filter += "pad=${Width}:${Height}:(ow-iw)/2:(oh-ih)/2,"
$filter += "fps=${FrameRate},"}
$filter += "format=yuv420p,"
$filter += "setsar=1,"
$filter += "settb=1/${FrameRate},"
$filter += "trim=duration=${clipDuration},"
$filter += "setpts=PTS-STARTPTS"
$filter += "[v${i}]"
$filterParts.Add($filter)}

# -------------------------------------- Build intro and outro text cards. ------------------------
$introIndex = $photoCount
$outroIndex = $photoCount + [int]($introDuration -gt 0)
$fontFile = $script:FontFile.Replace('\','/').Replace(':','\:')
if ($introDuration -gt 0 -or $outroDuration -gt 0) {if (-not (Test-Path -LiteralPath $script:FontFile -PathType Leaf)) {throw "Font file was not found: $script:FontFile"}}
if ($introDuration -gt 0) {$introTextFile = Join-Path $env:TEMP "NewPhotoReel_intro_$PID.txt"
$introFilterText = WrapTextCard $script:IntroText
[System.IO.File]::WriteAllText($introTextFile,$introFilterText,(New-Object System.Text.UTF8Encoding($false)))
$introTextPath = (Resolve-Path -LiteralPath $introTextFile).Path.Replace('\','/').Replace(':','\:')
$filterParts.Add("[${introIndex}:v]drawtext=fontfile='$fontFile':textfile='$introTextPath':fontcolor=white:fontsize=$($script:TextCardFontSize):line_spacing=10:x=(w-text_w)/2:y=(h-text_h)/2,format=yuv420p,setsar=1,setpts=PTS-STARTPTS[intro]")}
if ($outroDuration -gt 0) {$outroTextFile = Join-Path $env:TEMP "NewPhotoReel_outro_$PID.txt"
$outroFilterText = WrapTextCard $script:OutroText
[System.IO.File]::WriteAllText($outroTextFile,$outroFilterText,(New-Object System.Text.UTF8Encoding($false)))
$outroTextPath = (Resolve-Path -LiteralPath $outroTextFile).Path.Replace('\','/').Replace(':','\:')
$filterParts.Add("[${outroIndex}:v]drawtext=fontfile='$fontFile':textfile='$outroTextPath':fontcolor=white:fontsize=$($script:TextCardFontSize):line_spacing=10:x=(w-text_w)/2:y=(h-text_h)/2,format=yuv420p,setsar=1,setpts=PTS-STARTPTS[outro]")}

# -------------------------------------- Build crossfade chain. -----------------------------------
if ($photoCount -eq 1) {$filterParts.Add("[v0]trim=duration=${photoVideoDuration},setpts=PTS-STARTPTS[photobase]")}
else {$previous = '[v0]'
$videoParts = [System.Collections.Generic.List[string]]::new()
if ($introDuration -gt 0) {$videoParts.Add('[intro]')}
$videoParts.Add('[photobase]')
if ($outroDuration -gt 0) {$videoParts.Add('[outro]')}
if ($videoParts.Count -eq 1) {$filterParts.Add("[photobase]null[vbase]")}
else {$filterParts.Add(($videoParts -join '') + "concat=n=$($videoParts.Count):v=1:a=0[vbase]")}
for ($i = 1; $i -lt $photoCount; $i++) {$offset = $i * $PhotoDuration
$outputLabel = "[x${i}]"
$xfade = $previous
$xfade += "[v${i}]"
$transition = 'fade'
if ($RandomTransition -and -not $KenBurns -and $script:RandomTransitions.Count -gt 0) {$transition = $script:RandomTransitions | Get-Random}
$xfade += "xfade=transition=$transition"
$xfade += ":duration=${TransitionDuration}"
$xfade += ":offset=${offset}"
$xfade += $outputLabel
$filterParts.Add($xfade)
$previous = $outputLabel}
$filterParts.Add("${previous}trim=duration=${photoVideoDuration},setpts=PTS-STARTPTS[photobase]")}

# -------------------------------------- Apply watermark. -----------------------------------------
if ($Watermark) {$filterParts.Add("[${watermarkIndex}:v]format=rgba,colorchannelmixer=aa=0.85[wm]")
$filterParts.Add("[vbase][wm]overlay=W-w-${script:WatermarkRight}:H-h-${script:WatermarkBottom}:shortest=1[vout]")}
else {$filterParts.Add("[vbase]null[vout]")}

# -------------------------------------- Audio filter. --------------------------------------------
$audioFilter = "[${audioIndex}:a]"
$audioFilter += "atrim=start=${AudioSkip},"
$audioFilter += "asetpts=PTS-STARTPTS,"
$audioFilter += "atempo=${AudioSpeed},"
$audioFilter += "volume=$($script:Volume / 100),"
$audioFilter += "atrim=duration=${videoDuration},"
$audioFilter += "afade=t=in:st=0:d=${AudioFadeIn},"
$audioFilter += "afade=t=out:st=${audioFadeOutStart}:d=${AudioFadeOut},"
$audioFilter += "asetpts=N/SR/TB"
$audioFilter += "[aout]"
$filterParts.Add($audioFilter)
$filterComplex = $filterParts -join ';'

# -------------------------------------- FFmpeg output arguments. ---------------------------------
$ffmpegArgs.Add('-filter_complex')
$ffmpegArgs.Add($filterComplex)
$ffmpegArgs.Add('-map')
$ffmpegArgs.Add('[vout]')
$ffmpegArgs.Add('-map')
$ffmpegArgs.Add('[aout]')
$ffmpegArgs.Add('-t')
$ffmpegArgs.Add($videoDuration.ToString([System.Globalization.CultureInfo]::InvariantCulture))
$ffmpegArgs.Add('-c:v')
$ffmpegArgs.Add('libx264')
$ffmpegArgs.Add('-preset')
$ffmpegArgs.Add('medium')
$ffmpegArgs.Add('-crf')
$ffmpegArgs.Add('20')
$ffmpegArgs.Add('-c:a')
$ffmpegArgs.Add('aac')
$ffmpegArgs.Add('-b:a')
$ffmpegArgs.Add('192k')
$ffmpegArgs.Add('-pix_fmt')
$ffmpegArgs.Add('yuv420p')
$ffmpegArgs.Add('-movflags')
$ffmpegArgs.Add('+faststart')
$ffmpegArgs.Add('-y')
$ffmpegArgs.Add($OutputFile)

# -------------------------------------- Run FFmpeg. ----------------------------------------------
Write-Host -f cyan "Creating Reel...`n"
& $ffmpeg -hide_banner -loglevel error -stats @($ffmpegArgs.ToArray())
$exitCode = $LASTEXITCODE
if ($introTextFile -and (Test-Path -LiteralPath $introTextFile)) {Remove-Item -LiteralPath $introTextFile -Force}
if ($outroTextFile -and (Test-Path -LiteralPath $outroTextFile)) {Remove-Item -LiteralPath $outroTextFile -Force}
if ($exitCode -ne 0) {throw "FFmpeg failed with exit code $exitCode."}
if (-not (Test-Path -LiteralPath $OutputFile)) {throw "FFmpeg reported success, but the output file was not created."}
Write-Host ""
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Reel created: " -n; Write-Host -f yellow "$OutputFile`n"}

Export-ModuleMember -Function newphotoreel

# Helptext.

<#
## Overview
This function will use FFMPEG to create a Facebook safe photo reel from the images and mp3 stored in a specified directory.

Usage: NewPhotoReel <Folder> -MP3SpeedAdjust ## -PhotoDuration #.# -FirstPhoto 'filename.ext' -LastPhoto 'filename.ext' -WaterMark 'default|watermark.png' -Volume ## -IntroText 'text' -OutroText 'text' -Order (Chronological|Filename|Random) -KenBurns -RandomTransition -Help

Folder:			The path to the folder containing the MP3 file and all the relevant photos.
MP3SpeedAdjust:		The percentage of speed adjustment to apply to the MP3 file. The default is 13.
PhotoDuration:		The number of seconds each photo should be displayed. The default is 1.5.

The following switches are all optional.

FirstPhoto:		The first photo to display.
LastPhoto:		The last photo to display.
Watermark:		Define a watermark file to display. Use 'default' or specify a full path.
Volume:			Set the volume percentage.
IntroText:		Add a text based introduction frame.
OutroText:		Add a text-based final frame.
Order:			Set the order to Chronological, Filename (alphabetical), or Random.
KenBurns:		Use the zoom transition made famous by documentary film maker Ken Burns.
RandomTransition:	Use a random transition.
Help:			Call the full Help menu.

Notes:
------------------------------------------------
Adjust the speed of an MP3 so that Facebook doesn't flag a video for copyright violation.
The script will use the first MP3 file located in the directory.

## Configuration File
The following settings can be set for the main configuration settings to be used with FFMPEG:

AudioSkip = '5'			This is the number of seconds of audio to skip at the start of the MP3 file.
AudioFadeIn = '5'		This is the number of seconds to use to fade the audio in.
AudioFadeOut = '5'		This is the number of seconds to use to fade the audio out.
Volume = '100'			This is the default volume percentage to use.

Height = '1024'			This is the height of the video.
Width = '1024'			This is the width of the video.
FrameRate = '30'		This is the frames per second to use during encoding.
MaxPictureHeight = '1536'	This is the maximum picture height, before resize or crop.
MaxPictureWidth = '1536'	This is the maximum picture width, before resize or crop.

TransitionDuration = '0.5'	This is the length of time in seconds to use to fade between photos.

# This is the permitted subset of transitions to use for the Random switch.
RandomTransitions = @('fade','fadeblack','fadewhite','smoothleft','smoothright','circleopen')

# This is the font file to use:
FontFile = 'C:\Windows\Fonts\arial.ttf'

IntroText = ''			This is the default text to use for the intro screen.
OutroText = ''			This is the default text to use for the outro screen.
TextCardBackground = '#2B233D'	This is the background colour to use for the intro and outro screens.
TextCardDuration = '3'		This is the length of time the intro and outro frames remain on screen.
TextCardFontSize = '68'		This is the font size to use for the intro and outro text.
TextCardMaxWidth = '850'	This is the maximum with the intro and outro text is allowed to take on the screen.

# This is the path to the FFMPEG.EXE file and it's files.
Path = 'C:\Program Files (x86)\FFMPeg\bin'

Watermark = @{Right = 0		This sets the horizontal offset to use for the watermark image.
Bottom = 0}			This sets the vertical offset to use for the watermark image.

Notes:
------------------------------------------------
• All available transitions include: 'fade', 'fadeblack', 'fadewhite', 'slideleft', 'slideright', 'slideup', 'slidedown', 'smoothleft', 'smoothright', 'wipeleft', 'wiperight', 'circleopen'

• If no watermark file is provided, the default watermark.png file located in the module directory will be used.

• MP3SpeedAdjust and PhotoDuration have hardcoded defaults that can be overridden via the command line, but because these are expected to be used in every instance of the script being run, no configuration items have been stored in the PSD1 file.

## License
MIT License

Copyright (c) 2026 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
##>
