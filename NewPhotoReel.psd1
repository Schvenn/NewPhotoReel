@{RootModule = 'NewPhotoReel.psm1'
ModuleVersion = '1.5'
GUID = '5418bf05-be70-4b39-a134-d5d6ca7d16da'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'Create a Facebook safe photo reel from the images and mp3 stored in a specific directory.'
PowerShellVersion = '5.1'
FunctionsToExport = @('NewPhotoReel')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('NewPhotoReel.psm1')

PrivateData = @{PSData = @{Tags = @('audio', 'ffmpeg', 'jpeg', 'jpg', 'mp3', 'mp4', 'photo', 'png', 'video', 'facebook')
LicenseUri = 'https://github.com/Schvenn/NewPhotoReel/blob/main/license.txt'
ProjectUri = 'https://github.com/Schvenn/NewPhotoReel'
ReleaseNotes = 'Added volume, intro, outro, order and transitions.'}

AudioSkip = '5'
AudioFadeIn = '5'
AudioFadeOut = '5'
Volume = '100'

Height = '1024'
Width = '1024'
FrameRate = '30'

FontFile = 'C:\Windows\Fonts\arial.ttf'
IntroText = ''
OutroText = ''
TextCardBackground = '#2B233D'
TextCardDuration = '3'
TextCardFontSize = '68'
TextCardMaxWidth = '850'

MaxPictureWidth = '1536'
MaxPictureHeight = '1536'

# All available transitions include:
#'fade','fadeblack','fadewhite','slideleft','slideright','slideup','slidedown','smoothleft','smoothright','wipeleft','wiperight','circleopen'
TransitionDuration = '0.5'
RandomTransitions = @('fade','fadeblack','fadewhite','smoothleft','smoothright','circleopen')

Path = 'C:\Program Files (x86)\FFMPeg\bin'

Watermark = @{Right = 0
Bottom = 0}}}
