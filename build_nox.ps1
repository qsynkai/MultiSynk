# Script para buildar e instalar MultiSynk no NoxPlayer
# Resolve o bug do JDK 25 WEPoll/UDS com tmpdir curto

$adb = "C:\Users\Igor Norberto\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$flutter = "C:\flutter\bin\flutter.bat"

New-Item -ItemType Directory -Force "C:\tmp" | Out-Null

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:GRADLE_USER_HOME = "E:\.gradle"
$env:JAVA_TOOL_OPTIONS = "-Djdk.nio.enableWepoll=false -Djava.io.tmpdir=C:\tmp -Djdk.net.unixdomain.tmpdir=C:\tmp"

Write-Host "Conectando ADB ao NoxPlayer..." -ForegroundColor Cyan
& $adb connect 127.0.0.1:62025

Write-Host "Buildando APK..." -ForegroundColor Cyan
Set-Location "C:\Users\Igor Norberto\Documents\FocusBudget\android"
cmd /c ".\gradlew.bat --no-daemon assembleDebug 2>&1"

if ($LASTEXITCODE -eq 0) {
    $apk = "C:\Users\Igor Norberto\Documents\FocusBudget\build\app\outputs\flutter-apk\app-debug.apk"
    Write-Host "Build OK! Instalando APK..." -ForegroundColor Green
    & $adb -s 127.0.0.1:62025 install -r $apk
    Write-Host "Abrindo app..." -ForegroundColor Green
    & $adb -s 127.0.0.1:62025 shell am start -n "com.focusbudget.app/com.focusbudget.app.MainActivity"
} else {
    Write-Host "Build falhou!" -ForegroundColor Red
}
