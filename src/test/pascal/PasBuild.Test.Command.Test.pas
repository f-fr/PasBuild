{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Command.Test;

{$mode objfpc}{$H+}

{ Tests for TTestCompileCommand and TTestCommand behaviour when a module
  has no test directory or test executable. Maven-compatible behaviour:
  a missing src/test/pascal/ directory is a skip (exit 0), not a failure. }

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Types,
  PasBuild.Command.Test;

type
  { Verify that test-compile and test skip gracefully when no test directory
    exists, matching Maven behaviour (no tests = SUCCESS, not FAILURE). }
  TTestCommandNoTestDir = class(TTestCase)
  private
    FSavedDir: string;
    FTempDir: string;
    FConfig: TProjectConfig;
    FProfileIds: TStringList;
    procedure DeleteDirTree(const ADir: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    { test-compile must return 0 (skip) when src/test/pascal/ is absent }
    procedure TestTestCompileSkipsWhenNoTestDir;
    { test must return 0 (skip) when no TestRunner executable exists and
      no test directory exists (i.e. test-compile was previously skipped) }
    procedure TestTestSkipsWhenNoTestExecutable;
  end;

implementation

{ TTestCommandNoTestDir }

procedure TTestCommandNoTestDir.DeleteDirTree(const ADir: string);
var
  SR: TSearchRec;
  Entry: string;
begin
  if FindFirst(ADir + DirectorySeparator + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Entry := ADir + DirectorySeparator + SR.Name;
        if SR.Attr and faDirectory <> 0 then
          DeleteDirTree(Entry)
        else
          DeleteFile(Entry);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RmDir(ADir);
end;

procedure TTestCommandNoTestDir.SetUp;
begin
  FSavedDir := GetCurrentDir;

  { Create a temporary directory that has no src/test/pascal sub-tree }
  FTempDir := GetTempDir(False) + 'pasbuild_test_' + IntToStr(Random(MaxInt));
  ForceDirectories(FTempDir);
  { Also create the target/ dir so commands don't fail on directory creation,
    but deliberately omit src/test/pascal. }
  ForceDirectories(FTempDir + DirectorySeparator + 'target');

  ChDir(FTempDir);

  FConfig := TProjectConfig.Create;
  FConfig.Name := 'test-module';
  FConfig.Version := '1.0.0';

  FProfileIds := TStringList.Create;
end;

procedure TTestCommandNoTestDir.TearDown;
begin
  ChDir(FSavedDir);

  FProfileIds.Free;
  FConfig.Free;

  if (FTempDir <> '') and DirectoryExists(FTempDir) then
    DeleteDirTree(FTempDir);
end;

procedure TTestCommandNoTestDir.TestTestCompileSkipsWhenNoTestDir;
var
  Cmd: TTestCompileCommand;
  ExitCode: Integer;
begin
  AssertFalse('Precondition: src/test/pascal must not exist',
    DirectoryExists('src/test/pascal'));

  Cmd := TTestCompileCommand.Create(FConfig, FProfileIds);
  try
    ExitCode := Cmd.Execute;
  finally
    Cmd.Free;
  end;

  AssertEquals('test-compile should return 0 (skip) when no test dir exists', 0, ExitCode);
end;

procedure TTestCommandNoTestDir.TestTestSkipsWhenNoTestExecutable;
var
  Cmd: TTestCommand;
  ExitCode: Integer;
begin
  AssertFalse('Precondition: src/test/pascal must not exist',
    DirectoryExists('src/test/pascal'));
  AssertFalse('Precondition: TestRunner must not exist',
    FileExists('target' + DirectorySeparator + 'TestRunner'));

  Cmd := TTestCommand.Create(FConfig, FProfileIds);
  try
    ExitCode := Cmd.Execute;
  finally
    Cmd.Free;
  end;

  AssertEquals('test should return 0 (skip) when no test executable exists', 0, ExitCode);
end;

initialization
  RegisterTest(TTestCommandNoTestDir);

end.
