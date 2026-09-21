# NewPhotoReel

A PowerShell module that creates a vertical, Facebook-friendly photo reel from a collection of photos and an MP3 file.

`NewPhotoReel` uses **FFmpeg** to:

* Create a 1024 x 1024 video, or adjust the size according to your preference.
* Sort photos into chronological order.
* Display each photo for a configurable duration.
* Fade between photos.
* Resize and pad images while preserving their aspect ratio.
* Add an MP3 soundtrack.
* Adjust the playback speed of the audio.
* Fade audio in and out.
* Produce an H.264/AAC MP4 compatible with Facebook and other social platforms.

# Usage

```
NewPhotoReel <Folder> -MP3SpeedAdjust ## -PhotoDuration #.# -FirstPhoto 'filename.ext' -LastPhoto 'filename.ext' -WaterMark 'filename.ext'  -Volume ##% -IntroText 'sample' -OutroText 'sample' -Order 'Chronological/Filename/Random' -KenBurns -RandomTransition -Help
```

| Setting| Value|
| --- | --- |
|Folder|The path to the folder containing the MP3 file and all the relevant photos.|
|MP3SpeedAdjust|The percentage of speed adjustment to apply to the MP3 file. The default is 13.|
|PhotoDuration|The number of seconds each photo should be displayed. The default is 1.5.|
|FirstPhoto|The first photo to display. This is optional.|
|LastPhoto|The last photo to display. This is optional.|
|Watermark|Add a transparent overlay, aligned by the bottom right corner. This is optional.|
|Volume|Set the volume percentage.|
|IntroText|Add a text based introduction frame.|
|OutroText|Add a text-based final frame.|
|Order|Set the order to Chronological, Filename (alphabetical), or Random.|
|KenBurns|Use the zoom transition made famous by documentary film maker Ken Burns.|
|RandomTransition|Use a random transition.|
|Help|Call the full Help menu.|


# Video Output

The generated video uses:

| Setting| Value|
| --- | --- |
| Container|MP4|
| Video Codec|H.264|
| Audio Codec|AAC|
| Resolution|1024 x 1024|
| Pixel Format|yuv420p|
| Frame Rate|Configurable|
| Video Encoding|libx264|
| Audio Bitrate|192 kb/s|

* The output file is created using the name of the source folder.
* The default watermark file is "watermark.png" located in the module directory.

# Configuration

The module reads its configuration from `NewPhotoReel.psd1`

| Setting| Value|
| --- | --- |
|AudioSkip = '5'|This is the number of seconds of audio to skip at the start of the MP3 file.|
|AudioFadeIn = '5'|This is the number of seconds to use to fade the audio in.|
|AudioFadeOut = '5'|This is the number of seconds to use to fade the audio out.|
|Volume = '100'|This is the default volume percentage to use.|
|Height = '1024'|This is the height of the video.|
|Width = '1024'|This is the width of the video.|
|FrameRate = '30'|This is the frames per second to use during encoding.|
|MaxPictureHeight = '1536'|This is the maximum picture height, before resize or crop.|
|MaxPictureWidth = '1536'|This is the maximum picture width, before resize or crop.|
|TransitionDuration = '0.5'|This is the length of time in seconds to use to fade between photos.|
|RandomTransitions = @('fade'...|This is the permitted subset of transitions to use for the Random switch, selected from: 'fade', 'fadeblack', 'fadewhite', 'slideleft', 'slideright', 'slideup', 'slidedown', 'smoothleft', 'smoothright', 'wipeleft', 'wiperight', 'circleopen'|
|FontFile = 'C:\Windows\Fonts\arial.ttf'|This is the font file to use:|
|IntroText = ''|This is the default text to use for the intro screen.|
|OutroText = ''|This is the default text to use for the outro screen.|
|TextCardBackground = '#2B233D'|This is the background colour to use for the intro and outro screens.|
|TextCardDuration = '3'|This is the length of time the intro and outro frames remain on screen.|
|TextCardFontSize = '68'|This is the font size to use for the intro and outro text.|
|TextCardMaxWidth = '850'|This is the maximum with the intro and outro text is allowed to take on the screen.|
|Path = 'C:\Program Files (x86)\FFMPeg\bin'|This is the path to the FFMPEG.EXE file and it's files.|
|Watermark = @{Right = 0|This sets the horizontal offset to use for the watermark image.|
|Bottom = 0}|This sets the vertical offset to use for the watermark image.|

# Image Processing

Images are processed using FFmpeg filters that:

1. Preserve the original aspect ratio.
2. Scale images to fit within the configured maximum dimensions.
3. Ensure dimensions are divisible by two for H.264 compatibility.
4. Center the image on the vertical video canvas.
5. Pad unused space as necessary.
6. Convert the final output to `yuv420p`.

This prevents distortion while ensuring the output is compatible with Facebook and likely other social media platforms.

---

# Audio Processing

The MP3 soundtrack is:

1. Looped so it cannot run out before the video ends.
2. Trimmed to skip the configured number of seconds.
3. Reset to start at zero.
4. Speed-adjusted to prevent copyright violation flagging.
5. Trimmed to the final video duration.
6. Faded in.
7. Faded out.
8. Volume adjusted.

The first MP3 file found alphabetically is used as the soundtrack and the final audio duration always matches the generated video.

---

# FFMPEG Progress

During encoding, FFmpeg displays live progress information similar to:

```text
frame=  205 fps= 33 q=26.0 size=    9984KiB time=00:00:09.03 bitrate=9054.9kbits/s speed=1.45x elapsed=0:00:06.21
```

This information updates continuously while the reel is being created.

---

# Notes

* At least one MP3 file is required.
* At least one supported image file is required.
* An optional watermark should be a transparent `.png` file.
* Supported image formats are: `.jpg, .jpeg, .png`
* FFmpeg 4.0 or newer is required.
* The final output uses H.264 video and AAC audio.
* The source folder name is used as the output filename.
