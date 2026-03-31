@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo [94m=== PLANETAPELI - ENVIAR ACTUALIZACION ===[0m
echo.

set /p "DESCRIPCION=Descripcion del cambio: "

if "!DESCRIPCION!"=="" (
    echo.
    echo [91mError: Debes escribir una descripcion del cambio.[0m
    echo.
    pause
    exit /b 1
)

echo.
echo [94mSubiendo cambios a GitHub...[0m
echo.

git add .
git commit -m "!DESCRIPCION!"

if %errorlevel% neq 0 (
    echo.
    echo [91mError: No se pudo crear el commit. Verifica que haya cambios pendientes.[0m
    echo.
    pause
    exit /b 1
)

git push origin main

if %errorlevel% neq 0 (
    echo.
    echo [91mError: git push fallo. Verifica tu conexion y permisos del repositorio.[0m
    echo.
    pause
    exit /b 1
)

echo.
echo [93mGitHub Actions compilara el APK automaticamente (5-10 minutos)[0m
echo.
echo [92mListo! Los usuarios veran la actualizacion disponible en la app[0m
echo.

pause
