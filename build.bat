@echo off
if not exist build\ (
    mkdir build
)
setlocal enabledelayedexpansion
set "Compiler=gcc"
set "Wflags=-Wall -Wextra"
set "Buildflags=" :: g means debug
set "Outputfile=./build/ASMVulkan.exe"
set "Includepaths=-I./include"
set "Inputfiles=./build/main.o"
set "Linkerpaths=-L./lib"
set "Linkerflags=-lSDL3 -lwinmm -lole32 -loleaut32 -lsetupapi -lgdi32 -limm32 -lversion -luuid"

:build
@echo on
fasm ./src/main.asm ./build/main.o
@echo off
if errorlevel 1 (
    goto end
)

:link
@echo on
%Compiler% %Buildflags% -o %Outputfile% %Inputfiles% %Linkerpaths% %Linkerflags%
@echo off

:end
echo.
echo -------------------------------------
if errorlevel 1 (
    echo Build Failed %date% %time:~0,8%
) else (
    echo Build Complete %date% %time:~0,8%
)
echo -------------------------------------
echo.