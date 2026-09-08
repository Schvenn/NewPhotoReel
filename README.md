# NewPhotoReel

A PowerShell module that creates a vertical, Facebook-friendly photo reel from a collection of photos and an MP3 file.

`NewPhotoReel` uses **FFmpeg** to:

* Create a 1920 x 1080 vertical video.
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
NewPhotoReel <Folder> -MP3SpeedAdjust ## -PhotoDuration #.# -FirstPhoto 'filename.ext' -LastPhoto 'filename.ext' -Help
```

| Setting| Value|
| --- | --- |
|Folder|The path to the folder containing the MP3 file and all the relevant photos.|
|MP3SpeedAdjust|The percentage of speed adjustment to apply to the MP3 file. The default is 13.|
|PhotoDuration|The number of seconds each photo should be displayed. The default is 1.5.|
|FirstPhoto|The first photo to display. This is optional.|
|LastPhoto|The last photo to display. This is optional.|
|Help|Call the full Help menu.|

# Video Output

The generated video uses:

| Setting| Value|
| --- | --- |
| Container|MP4|
| Video Codec|H.264|
| Audio Codec|AAC|
| Resolution|1920 × 1080|
| Pixel Format|yuv420p|
| Frame Rate|Configurable|
| Video Encoding|libx264|
| Audio Bitrate|192 kb/s|

The output file is created using the name of the source folder.

# Configuration

The module reads its configuration from `NewPhotoReel.psd1`

| Setting| Value|
| --- | --- |
|AudioSkip = '5'|This is the number of seconds of audio to skip at the start of the MP3 file.|
|Path = 'C:\Program Files (x86)\FFMPeg\bin'|This is the path to the FFMPEG.EXE file and it's files.|
|Height = '1920'|This is the height of the video.|
|Width = '1080'|This is the width of the video.|
|MaxPictureHeight = '1536'|This is the maximum height, before resize or crop.|
|MaxPictureWidth = '1536'|This is the maximum width, before resize or crop.|
|FrameRate = '30'|This is the frames per second to use during encoding.|
|AudioFadeIn = '5'|This is the number of seconds to use to fade the audio in.|
|AudioFadeOut = '5'|This is the number of seconds to use to fade the audio out.|
|TransitionDuration = '0.5'|This is the length of time in seconds to use to fade between photos.|

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
* Supported image formats are: `.jpg, .jpeg, .png`
* FFmpeg 4.0 or newer is required.
* The final output uses H.264 video and AAC audio.
* The source folder name is used as the output filename.
