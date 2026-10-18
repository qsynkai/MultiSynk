@echo off
echo ============================================
echo   FocusBudget - Configuracao inicial
echo ============================================
echo.

echo [1/3] Verificando Flutter...
flutter --version
if %errorlevel% neq 0 (
    echo ERRO: Flutter nao encontrado. Siga o guia de instalacao primeiro.
    pause
    exit /b 1
)

echo.
echo [2/3] Instalando dependencias...
flutter pub get
if %errorlevel% neq 0 (
    echo ERRO ao instalar dependencias.
    pause
    exit /b 1
)

echo.
echo [3/3] Verificando ambiente Android...
flutter doctor

echo.
echo ============================================
echo   Tudo pronto! Para rodar o app:
echo   - Conecte seu celular via USB (ative USB debugging nas opcoes de desenvolvedor)
echo   - Ou inicie um emulador no Android Studio
echo   - Depois execute: flutter run
echo ============================================
pause
