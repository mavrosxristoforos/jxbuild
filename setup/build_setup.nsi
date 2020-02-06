!include "FileAssociation.nsh"

Name "JXBuild"
OutFile "JXBuild_setup.exe"
RequestExecutionLevel admin
Unicode True
InstallDir $PROGRAMFILES\JXBuild
InstallDirRegKey HKLM "Software\NSIS_JXBuild" "Install_Dir"

;--------------------------------

; Pages

Page components
Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

;--------------------------------

; The stuff to install
Section "JXBuild (required)"

  SectionIn RO
  
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  
  ; Put file there
  File "..\Win32\Debug\JXBuild.exe"
  File "..\Win32\Debug\jxbuild-minifier.php"
  
  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\NSIS_JXBuild "Install_Dir" "$INSTDIR"

  ; Associate jxb files
  ${registerExtension} "$INSTDIR\JXBuild.exe" ".jxb" "JXB_File"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\JXBuild" "DisplayName" "NSIS JXBuild"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\JXBuild" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\JXBuild" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\JXBuild" "NoRepair" 1
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
SectionEnd

; Optional section (can be disabled by the user)
Section "Start Menu Shortcuts"

  CreateDirectory "$SMPROGRAMS\JXBuild"
  CreateShortcut "$SMPROGRAMS\JXBuild\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  CreateShortcut "$SMPROGRAMS\JXBuild\JXBuild.lnk" "$INSTDIR\JXBuild.exe" "" "$INSTDIR\JXBuild.exe" 0
  
SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"
  
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\JXBuild"
  DeleteRegKey HKLM SOFTWARE\NSIS_JXBuild

  ; Remove file association
  ${unregisterExtension} ".jxb" "JXB File"

  ; Remove files and uninstaller
  Delete $INSTDIR\JXBuild.exe
  Delete $INSTDIR\uninstall.exe

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\JXBuild\*.*"

  ; Remove directories used
  RMDir "$SMPROGRAMS\JXBuild"
  RMDir "$INSTDIR"

SectionEnd
