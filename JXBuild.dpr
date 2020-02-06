program JXBuild;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, System.ZIP, System.Types,
  StrUtils, Windows, ShellApi, DateUtils;

var
  F, XMLF: TextFile;
  S, CMD, CMDFile, XMLFile, Sep,
  buffer, CurrentVersion, NewVersion: String;
  i, LastPart: integer;
  Z: TZipFile;
  myVersionArray, myFileArray: TStringDynArray;
  Action: TSHFileOpStruct;
  ResultCode: NativeUInt;
  max: integer;
  MinifierPath: String;
  ExecutedCommands, FailedCommands: integer;
  TimeStart: TDateTime;
  AHnd : THandle;
  AChar : char;

begin
  try
    WriteLn('Welcome to JXBuild.');
    WriteLn('--');
    WriteLn('');
    TimeStart := Now();
    ExecutedCommands := 0;
    FailedCommands := 0;
    if ParamCount > 0 then begin
      if FileExists(ParamStr(1)) then begin
        // Open File
        WriteLn('Opening File '+ParamStr(1));
        WriteLn('--');
        WriteLn('');
        AssignFile(F, paramstr(1));
        Reset(F);
        if (GetCurrentDir <> ExtractFileDir(ExpandFileName(ParamStr(1)))) then
        begin
          // Set Current Directory to the file's parent directory.
          WriteLn('Setting current directory to "'+ExtractFileDir(ExpandFileName(ParamStr(1)))+'", so that paths are relative to the build file.');
          WriteLn('--');
          WriteLn('');
          SetCurrentDir(ExtractFileDir(ExpandFileName(ParamStr(1))));
        end;
        while not EOF(F) do begin
          ReadLn(F, S);
          if S = '' then continue;
          //WriteLn('Analyzing '+S);
          CMD := Copy(S, 0, Pos(':', S)-1);
          CMDFile := StringReplace(S, CMD+':', '', [rfReplaceAll, rfIgnoreCase]);
          WriteLn('Executing '+CMD);
          Inc(ExecutedCommands);
          if CMD = 'INCVERSION' then
          begin
            // COMMAND INCVERSION
            WriteLn('Detecting Version Number in '+CMDFile);
            if FileExists(CMDFile) then begin
              // Analyze XML, increment last part of <version>.
              //WriteLn('Opening XML File');
              AssignFile(XMLF, CMDFile);
              Reset(XMLF);
              XMLFile := '';
              while not EOF(XMLF) do begin
                ReadLn(XMLF, buffer);
                if (buffer = '') then continue;
                if ContainsText(buffer, '<version>') then
                begin
                  CurrentVersion := Trim(StringReplace(buffer, '<version>', '', [rfReplaceAll, rfIgnoreCase]));
                  CurrentVersion := StringReplace(CurrentVersion, '</version>', '', [rfReplaceAll, rfIgnoreCase]);
                  WriteLn('Old Version: '+CurrentVersion);
                  myVersionArray := SplitString(CurrentVersion, '.');
                  LastPart := StrToInt(myVersionArray[High(myVersionArray)]) + 1;
                  NewVersion := '';
                  Sep := '';
                  for i := 0 to Length(myVersionArray) - 2 do begin
                    NewVersion := NewVersion+Sep+myVersionArray[i];
                    Sep := '.';
                  end;
                  NewVersion := NewVersion+'.'+IntToStr(LastPart);
                  buffer := '<version>'+NewVersion+'</version>';
                  WriteLn('New Version: '+NewVersion);
                end;
                XMLFile := XMLFile+buffer+#13+#10;
              end;
              CloseFile(XMLF);
              ReWrite(XMLF);
              WriteLn(XMLF, Trim(XMLFile));
              CloseFile(XMLF);
            end;
          end
          else if CMD = 'ZIPDIR' then begin
            // COMMAND ZIPDIR
            if FileExists(CMDFILE+'.zip') then
              DeleteFile(PChar(CMDFile+'.zip'));
            WriteLn('Zipping Directory '+CMDFile);
            Z := TZipFile.Create;
            Z.Open(CMDFile+'.zip', TZipMode.zmWrite);
            Z.Close;
            Z.Free;
            TZipFile.ZipDirectoryContents(CMDFile+'.zip', CMDFile);
            WriteLn('Zip Completed');
          end
          else if CMD = 'ZIPFILES' then begin
            // COMMAND ZIPFILES
            // ZIPFILES:file.zip file1.aaa file2.bbb
            myFileArray := SplitString(CMDFile, ' ');
            if FileExists(myFileArray[0]) then
              DeleteFile(PChar(myFileArray[0]));
            WriteLn('Zipping Files');
            Z := TZipFile.Create;
            Z.Open(myFileArray[0], TZipMode.zmWrite);
            for i := 1 to Length(myFileArray) -1 do begin
              WriteLn('Adding '+myFileArray[i]);
              Z.Add(myFileArray[i]);
            end;
            Z.Close;
            Z.Free;
            WriteLn('Zip Completed');
          end
          else if CMD = 'MKDIR' then begin
            // COMMAND MKDIR
            if not DirectoryExists(CMDFile) then begin
              WriteLn('Making directory '+CMDFile);
              CreateDir(CMDFile);
            end
            else
              WriteLn('Directory Exists.');
          end
          else if CMD = 'DELETE' then begin
            // COMMAND DELETE
            if FileExists(CMDFile) then begin
              WriteLn('Deleting file '+CMDFile);
              DeleteFile(PChar(CMDFile))
            end
            else if DirectoryExists(CMDFile) then begin
              WriteLn('Deleting directory '+CMDFile);
              RmDir(CMDFile);
            end
            else
              WriteLn('File not found.');
          end
          else if CMD = 'COPY' then begin
            // COMMAND COPY
            myFileArray := SplitString(CMDFile, ' ');
            if FileExists(myFileArray[0]) then
            begin
              WriteLn('Copying file '+myFileArray[0]+' to '+myFileArray[1]);
              CopyFile(PChar(myFileArray[0]), PChar(myFileArray[1]), false)
            end
            else if DirectoryExists(myFileArray[0]) then begin
              Action.Wnd := GetDesktopWindow;
              Action.wFunc := FO_COPY;
              Action.pFrom := PChar(myFileArray[0]+#0#0);
              Action.pTo := PChar(myFileArray[1]);
              Action.fFlags := FOF_NOCONFIRMMKDIR;
              WriteLn('Copying directory '+myFileArray[0]+' to '+myFileArray[1]);
              SHFileOperation(Action);
            end
            else begin
              WriteLn('Source File Not Found.');
              Inc(FailedCommands);
            end;
          end
          else if CMD = 'RENAME' then begin
            // COMMAND RENAME
            myFileArray := SplitString(CMDFile, ' ');
            if FileExists(myFileArray[0]) then begin
              RenameFile(myFileArray[0], myFileArray[1]);
            end
            else begin
              WriteLn('File not found: '+myFileArray[0]);
              Inc(FailedCommands);
            end;
          end
          else if CMD = 'MINIFY' then begin
            myFileArray := SplitString(CMDFile, ' ');
            if FileExists(myFileArray[0]) then
            begin
              if FileExists(myFileArray[1]) then
              begin
                DeleteFile(PChar(myFileArray[1]))
              end;
              WriteLn('Minifying '+myFileArray[0]);
              WriteLn('Please note that this command requires that php is in the System Path.');
              MinifierPath := ExtractFileDir(ParamStr(0))+'\jxbuild-minifier.php';
              if FileExists(MinifierPath) then
              begin
                WriteLn('Executing '+MinifierPath);
                ResultCode := ShellExecute(0, 'open', PWideChar('php'),
                  PWideChar('"'+ExtractFileDir(ParamStr(0))+'\jxbuild-minifier.php" "'+myFileArray[0]+'" "'+myFileArray[1]+'"'),
                  '', SW_SHOW);
                WriteLn('Result: '+IntToStr(ResultCode));
                max := 10;
                WriteLn('Waiting for file '+myFileArray[1]+' to appear.');
                repeat
                  WriteLn('...');
                  Sleep(2000);
                  Dec(max);
                until (FileExists(myFileArray[1]) or (max <= 0));
                if Not FileExists(myFileArray[1]) then
                begin
                  WriteLn('Failed to minify file '+myFileArray[1]+'. Please try again.');
                  Inc(FailedCommands);
                  //Exit;
                end;
              end
              else
              begin
                WriteLn(MinifierPath+' not found.');
                WriteLn('Failed to minify file '+myFileArray[1]+'. Please try again.');
                Inc(FailedCommands);
              end;
            end;
          end;
          WriteLn('--');
          WriteLn('');
        end;
        CloseFile(F);
        WriteLn('Results');
        WriteLn('--');
        if (FailedCommands = 0) then begin
          WriteLn('Execution finished successfully');
          ExitCode := 0;
        end
        else begin
          WriteLn('There were errors. Please check above.');
          ExitCode := 1;
        end;
        WriteLn('Executed Commands: '+IntToStr(ExecutedCommands));
        WriteLn('Failed Commands: '+IntToStr(FailedCommands));
        WriteLn('Total execution time: '+IntToStr(MilliSecondsBetween(Now(), TimeStart))+'ms');
        if (FailedCommands > 0) then begin
          AHnd := GetStdHandle(STD_INPUT_HANDLE);
          SetConsoleMode(AHnd,0);
          Writeln('Press any key to exit');
          Read(AChar);
        end;
      end
      else
        WriteLn('Commands Text File not found');
    end
    else
    begin
      WriteLn('Correct usage: jxbuild [build_file]');
      WriteLn('Alternative usage: Double click on any .jxb file.');
      WriteLn('--');
      WriteLn('');
      AHnd := GetStdHandle(STD_INPUT_HANDLE);
      SetConsoleMode(AHnd,0);
      Writeln('Press any key to exit');
      Read(AChar);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
