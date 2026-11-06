# Redirect Gradle and temp files off a full C: drive before building.
# Usage (PowerShell): . .\scripts\use_d_drive_gradle.ps1; flutter run -d DEVICE_ID

$gradleHome = 'D:\dev\gradle-home'
$tempDir = 'D:\dev\build-temp'

New-Item -ItemType Directory -Force -Path $gradleHome | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$env:GRADLE_USER_HOME = $gradleHome
$env:TEMP = $tempDir
$env:TMP = $tempDir

Write-Host "GRADLE_USER_HOME=$gradleHome"
Write-Host "TEMP/TMP=$tempDir"
