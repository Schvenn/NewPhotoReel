function newphotoreel ([string]$Folder, [int]$MP3SpeedAdjust = 13, [double]$PhotoDuration = 1.5, [string]$FirstPhoto, [string]$LastPhoto, [switch]$help) {# Create a Facebook safe photo reel from the images and mp3 stored in a specific directory.

# Settings
function LoadConfiguration {$script:ConfigPath = Join-Path $PSScriptRoot 'NewPhotoReel.psd1'
if (!(Test-Path $script:ConfigPath)) {throw "Config file not found at $script:ConfigPath"}
$script:Config = Import-PowerShellDataFile -Path $script:ConfigPath

# Pull config values into variables
$script:Path = $script:Config.PrivateData.Path
$script:Height = [int]$script:Config.PrivateData.Height
$script:Width = [int]$script:Config.PrivateData.Width
$script:MaxPictureHeight = [int]$script:Config.PrivateData.MaxPictureHeight
$script:MaxPictureWidth = [int]$script:Config.PrivateData.MaxPictureWidth
$script:FrameRate = [int]$script:Config.PrivateData.FrameRate
$script:AudioSkip = [int]$script:Config.PrivateData.AudioSkip
$script:AudioFadeIn = [int]$script:Config.PrivateData.AudioFadeIn
$script:AudioFadeOut = [int]$script:Config.PrivateData.AudioFadeOut
$script:TransitionDuration = [double]$script:Config.PrivateData.TransitionDuration}
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

# Load FFMPEG path
$env:Path += ";$script:Path"
$PhotoDuration = [Math]::Round($PhotoDuration, 1)
$AudioSpeed = ($MP3SpeedAdjust / 100) + 1


if ([string]::IsNullOrWhiteSpace($Folder)) {Write-Host -f cyan "`nUsage: NewPhotoReel <Folder> -MP3SpeedAdjust ## -PhotoDuration #.# -FirstPhoto 'filename.ext' -LastPhoto 'filename.ext' -Help"
Write-Host -f cyan "`nFolder: `t`t" -n; Write-Host -f white "Path to the folder containing the MP3 file and all the relevant photos."
Write-Host -f cyan "MP3SpeedAdjust: `t" -n; Write-Host -f white "The percentage of speed adjustment to apply to the MP3 file. The default is 13."
Write-Host -f cyan "PhotoDuration: `t`t" -n; Write-Host -f white "The number of seconds each photo should be displayed. The default is 1.5."
Write-Host -f cyan "FirstPhoto: `t`t" -n; Write-Host -f white "The first photo to display. This is optional."
Write-Host -f cyan "LastPhoto: `t`t" -n; Write-Host -f white "The last photo to display. This is optional."
Write-Host -f cyan "Help: `t`t`t" -n; Write-Host -f white "Call the full Help menu.`n"; return}

# Resolve folder and derive names
$PhotoFolder = (Resolve-Path -LiteralPath $Folder).Path
$folderInfo = [System.IO.DirectoryInfo]$PhotoFolder
$folderName = $folderInfo.Name
$OutputFile = "$folderName.mp4"

# Find FFmpeg
$ffmpegCandidates = @('C:\Tools\ffmpeg\bin\ffmpeg.exe', 'C:\Program Files\ffmpeg\bin\ffmpeg.exe')
$ffmpeg = $ffmpegCandidates | Where-Object {Test-Path $_} | Select-Object -First 1
if (-not $ffmpeg) {$ffmpegCommand = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if ($ffmpegCommand) {$ffmpeg = $ffmpegCommand.Source}}
if (-not $ffmpeg) {throw 'FFmpeg.exe was not found.'}
$ffmpegVersion = & $ffmpeg -version 2>&1 | Select-Object -First 1
Write-Host -f yellow "`nNew Facebook Friendly Photo Reel:"
Write-Host -f yellow ("-" * 100)
Write-Host -f white $ffmpegVersion
Write-Host -f yellow "`nSource"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "FFMPEG Location: " -n; Write-Host -f yellow "$ffmpeg"
if ($ffmpegVersion -match 'ffmpeg version (\d+)\.') {if ([int]$Matches[1] -lt 4) {throw 'FFmpeg 4.0 or newer is required.'}}

# Validate settings
if ($PhotoDuration -le 0) {throw 'PhotoDuration must be greater than zero.'}
if ($TransitionDuration -lt 0) {throw 'TransitionDuration cannot be negative.'}
if ($TransitionDuration -ge $PhotoDuration) {throw 'TransitionDuration must be less than PhotoDuration.'}
if ($Width -le 0 -or $Height -le 0) {throw 'Width and Height must be greater than zero.'}
if ($MaxPictureWidth -le 0 -or $MaxPictureHeight -le 0) {throw 'MaxPictureWidth and MaxPictureHeight must be greater than zero.'}
if ($FrameRate -le 0) {throw 'FrameRate must be greater than zero.'}
if ($AudioSpeed -le 0) {throw 'AudioSpeed must be greater than zero.'}

# Find the first MP3 in the folder
$MusicFile = Get-ChildItem -LiteralPath $PhotoFolder -File -Filter '*.mp3' | Sort-Object Name | Select-Object -First 1
if (-not $MusicFile) {throw "No MP3 file was found in '$PhotoFolder'."}

# Find photos
$photos = Get-ChildItem -LiteralPath $PhotoFolder -File | Where-Object {$_.Extension -match '^\.(jpg|jpeg|png)$'} | Sort-Object @{Expression = {if ($_.BaseName -match '(\d{4})[-_.](\d{2})[-_.](\d{2})') {try {[datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])}
catch {$_.LastWriteTime}}
elseif ($_.BaseName -match '(\d{4})(\d{2})(\d{2})') {try {[datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])}
catch {$_.LastWriteTime}}
else {$_.LastWriteTime}}}, Name

# Reorder photos when FirstPhoto/LastPhoto are specified
$photos = @($photos | Where-Object {$_ -and $_.FullName})
$firstPhotoObject = $null
$lastPhotoObject = $null

if ($FirstPhoto) {$firstName = Split-Path $FirstPhoto -Leaf
$firstPhotoObject = $photos | Where-Object {$_.Name -eq $firstName} | Select-Object -First 1
if (-not $firstPhotoObject) {throw "FirstPhoto '$firstName' was not found in '$PhotoFolder'."}
$photos = @($photos | Where-Object {$_.FullName -ne $firstPhotoObject.FullName})}

if ($LastPhoto) {$lastName = Split-Path $LastPhoto -Leaf
$lastPhotoObject = $photos | Where-Object {$_.Name -eq $lastName} | Select-Object -First 1

# If FirstPhoto and LastPhoto are the same file, get it from the original list
if (-not $lastPhotoObject -and $firstPhotoObject -and $firstPhotoObject.Name -eq $lastName) {$lastPhotoObject = $firstPhotoObject}
if (-not $lastPhotoObject) {throw "LastPhoto '$lastName' was not found in '$PhotoFolder'."}
$photos = @($photos | Where-Object {$_.FullName -ne $lastPhotoObject.FullName})}

# Put FirstPhoto first, all remaining photos in their normal order,
# then LastPhoto last
$reorderedPhotos = @()

if ($firstPhotoObject) {$reorderedPhotos += $firstPhotoObject}
$reorderedPhotos += $photos

if ($lastPhotoObject -and $lastPhotoObject.FullName -ne $firstPhotoObject.FullName) {$reorderedPhotos += $lastPhotoObject}
$photos = @($reorderedPhotos)
$photoCount = $photos.Count

# Effective picture size. The source image can never be larger than the final canvas, otherwise pad() would be asked to make a smaller canvas.
$effectiveMaxWidth = [Math]::Min($MaxPictureWidth, $Width)
$effectiveMaxHeight = [Math]::Min($MaxPictureHeight, $Height)

# Video timing
$videoDuration = $photoCount * $PhotoDuration
$clipDuration = $PhotoDuration + $TransitionDuration

# Audio fade timing
$audioFadeOutStart = [Math]::Max(0, $videoDuration - $AudioFadeOut)

Write-Host -f cyan "Source Folder:   " -n; Write-Host -f yellow "$PhotoFolder`n"
Write-Host -f yellow "Pictures"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "First Photo:  " -n; Write-Host -f yellow "$FirstPhoto"
Write-Host -f cyan "Last Photo:   " -n; Write-Host -f yellow "$LastPhoto"
Write-Host -f cyan "Photos:       " -n; Write-Host -f white "$photoCount"
Write-Host -f cyan "Photo timing: " -n; Write-Host -f white "$PhotoDuration sec"
Write-Host -f cyan "Transition:   " -n; Write-Host -f white "$TransitionDuration sec`n"
Write-Host -f yellow "Audio"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Audio:        " -n; Write-Host -f yellow "$($MusicFile.Name)"
Write-Host -f cyan "Audio Speed:  " -n; Write-Host -f white "$($AudioSpeed * 100)%`n"
Write-Host -f yellow "Output"
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Output File:  " -n; Write-Host -f yellow "$OutputFile"
Write-Host -f cyan "Duration:     " -n; Write-Host -f white "$([Math]::Round($videoDuration, 0)) seconds"
Write-Host -f cyan "Resolution:   " -n; Write-Host -f white "${Height} x ${Width}`n"
Write-Host -f yellow ("-" * 50)

# Build FFmpeg input arguments
$ffmpegArgs = [System.Collections.Generic.List[string]]::new()
foreach ($photo in $photos) {$ffmpegArgs.Add('-loop')
$ffmpegArgs.Add('1')
$ffmpegArgs.Add('-t')
$ffmpegArgs.Add($clipDuration.ToString([System.Globalization.CultureInfo]::InvariantCulture))
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add($photo.FullName)}

# Loop audio indefinitely so it can never run out before the photos finish
$ffmpegArgs.Add('-stream_loop')
$ffmpegArgs.Add('-1')
$ffmpegArgs.Add('-i')
$ffmpegArgs.Add($MusicFile.FullName)

# Build video filters
$filterParts = [System.Collections.Generic.List[string]]::new()

for ($i = 0; $i -lt $photoCount; $i++) {$filter = "[${i}:v]"
$filter += "scale=${effectiveMaxWidth}:${effectiveMaxHeight}:force_original_aspect_ratio=decrease,"
$filter += "scale=trunc(iw/2)*2:trunc(ih/2)*2,"
$filter += "pad=${Width}:${Height}:(ow-iw)/2:(oh-ih)/2,"
$filter += "fps=${FrameRate},"
$filter += "format=yuv420p,"
$filter += "setsar=1,"
$filter += "settb=1/${FrameRate},"
$filter += "trim=duration=${clipDuration},"
$filter += "setpts=PTS-STARTPTS"
$filter += "[v${i}]"
$filterParts.Add($filter)}

# Build crossfade chain
if ($photoCount -eq 1) {$filterParts.Add("[v0]trim=duration=${videoDuration},setpts=PTS-STARTPTS[vout]")}
else {$previous = '[v0]'
for ($i = 1; $i -lt $photoCount; $i++) {$offset = $i * $PhotoDuration
$outputLabel = "[x${i}]"
$xfade = $previous
$xfade += "[v${i}]"
$xfade += "xfade=transition=fade"
$xfade += ":duration=${TransitionDuration}"
$xfade += ":offset=${offset}"
$xfade += $outputLabel
$filterParts.Add($xfade)
$previous = $outputLabel}
$filterParts.Add("${previous}trim=duration=${videoDuration},setpts=PTS-STARTPTS[vout]")}

# Audio filter
$audioIndex = $photoCount
$audioFilter = "[${audioIndex}:a]"
$audioFilter += "atrim=start=${AudioSkip},"
$audioFilter += "asetpts=PTS-STARTPTS,"
$audioFilter += "atempo=${AudioSpeed},"
$audioFilter += "atrim=duration=${videoDuration},"
$audioFilter += "afade=t=in:st=0:d=${AudioFadeIn},"
$audioFilter += "afade=t=out:st=${audioFadeOutStart}:d=${AudioFadeOut},"
$audioFilter += "asetpts=N/SR/TB"
$audioFilter += "[aout]"
$filterParts.Add($audioFilter)
$filterComplex = $filterParts -join ';'

# FFmpeg output arguments
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

# Run FFmpeg
Write-Host -f cyan "Creating Reel...`n"
& $ffmpeg -hide_banner -loglevel error -stats @($ffmpegArgs.ToArray())
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {throw "FFmpeg failed with exit code $exitCode."}
if (-not (Test-Path -LiteralPath $OutputFile)) {throw "FFmpeg reported success, but the output file was not created."}
Write-Host ""
Write-Host -f yellow ("-" * 50)
Write-Host -f cyan "Reel created: " -n; Write-Host -f yellow "$OutputFile`n"}

Export-ModuleMember -Function newphotoreel

# Helptext.

<#
## Overview

This function will use FFMPEG to create a Facebook safe photo reel from the images and mp3 stored in a specific directory.

Usage: NewPhotoReel <Folder> -MP3SpeedAdjust ## -PhotoDuration #.# -FirstPhoto 'filename.ext' -LastPhoto 'filename.ext' -Help

Folder:		The path to the folder containing the MP3 file and all the relevant photos.
MP3SpeedAdjust:	The percentage of speed adjustment to apply to the MP3 file. The default is 13.
PhotoDuration:	The number of seconds each photo should be displayed. The default is 1.5.
FirstPhoto:	The first photo to display. This is optional.
LastPhoto:	The last photo to display. This is optional.
Help:		Call the full Help menu.

Notes:
Adjust the speed of an MP3 so that Facebook doesn't flag a video for copyright violation.
The script will use the first MP3 file located in the directory.
Photos are sorted in chronological order via best effort.

## Configuration File

The following settings can be set for the main configuration settings to be used with FFMPEG:

AudioSkip = '5'					This is the number of seconds of audio to skip at the start of the MP3 file.
Path = 'C:\Program Files (x86)\FFMPeg\bin'	This is the path to the FFMPEG.EXE file and it's files.
Height = '1920'					This is the height of the video.
Width = '1080'					This is the width of the video.
MaxPictureHeight = '1536'			This is the maximum height, before resize or crop.
MaxPictureWidth = '1536'			This is the maximum width, before resize or crop.
FrameRate = '30'				This is the frames per second to use during encoding.
AudioFadeIn = '5'				This is the number of seconds to use to fade the audio in.
AudioFadeOut = '5'				This is the number of seconds to use to fade the audio out.
TransitionDuration = '0.5'			This is the length of time in seconds to use to fade between photos.


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