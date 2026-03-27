{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Plugin;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.CLI,
  PasBuild.Types,
  PasBuild.Plugin;

type
  { Test plugin discovery }
  TTestPluginDiscovery = class(TTestCase)
  private
    FTempDir: string;
    procedure CreateMockPlugin(const ADir, AName: string);
    procedure CreateMockPluginWithPhase(const ADir, AName, APhase: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDiscoverPluginNotFound;
    procedure TestDiscoverPluginFindsInProjectDir;
    procedure TestDiscoverAllPluginsEmpty;
    procedure TestDiscoverAllPluginsFindsPlugins;
    procedure TestDiscoverAllPluginsDeduplicates;
  end;

  { Test plugin phase query }
  TTestPluginPhaseQuery = class(TTestCase)
  private
    FTempDir: string;
    procedure CreateMockPluginWithPhase(const ADir, AName, APhase: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestQueryPhaseAfterCompile;
    procedure TestQueryPhaseAfterTest;
    procedure TestQueryPhaseNone;
    procedure TestQueryPhaseInvalid;
    procedure TestQueryPhaseWithAfterPrefix;
  end;

  { Test TPluginCommand }
  TTestPluginCommand = class(TTestCase)
  private
    FConfig: TProjectConfig;
    FProfileIds: TStringList;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPluginCommandGetName;
    procedure TestPluginCommandGetDependenciesAfterCompile;
    procedure TestPluginCommandGetDependenciesNone;
  end;

implementation

uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  PasBuild.Command,
  PasBuild.Command.Compile;

{ Helper to recursively delete a directory }
procedure RemoveDir(const ADir: string);
var
  SearchRec: TSearchRec;
  FullPath: string;
begin
  if not DirectoryExists(ADir) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
          Continue;
        FullPath := IncludeTrailingPathDelimiter(ADir) + SearchRec.Name;
        if (SearchRec.Attr and faDirectory) <> 0 then
          RemoveDir(FullPath)
        else
          DeleteFile(FullPath);
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
  RmDir(ADir);
end;

{ TTestPluginDiscovery }

procedure TTestPluginDiscovery.SetUp;
begin
  FTempDir := IncludeTrailingPathDelimiter(GetTempDir) + 'pasbuild-test-plugin-' + IntToStr(GetProcessID);
  ForceDirectories(FTempDir);
end;

procedure TTestPluginDiscovery.TearDown;
begin
  RemoveDir(FTempDir);
end;

procedure TTestPluginDiscovery.CreateMockPlugin(const ADir, AName: string);
var
  PluginPath: string;
  F: TextFile;
begin
  ForceDirectories(ADir);
  PluginPath := IncludeTrailingPathDelimiter(ADir) + AName;
  AssignFile(F, PluginPath);
  Rewrite(F);
  WriteLn(F, '#!/bin/sh');
  WriteLn(F, 'echo "mock plugin"');
  CloseFile(F);
  {$IFDEF UNIX}
  FpChmod(PluginPath, &755);
  {$ENDIF}
end;

procedure TTestPluginDiscovery.CreateMockPluginWithPhase(const ADir, AName, APhase: string);
var
  PluginPath: string;
  F: TextFile;
begin
  ForceDirectories(ADir);
  PluginPath := IncludeTrailingPathDelimiter(ADir) + AName;
  AssignFile(F, PluginPath);
  Rewrite(F);
  WriteLn(F, '#!/bin/sh');
  WriteLn(F, 'case "$1" in');
  WriteLn(F, '  --pasbuild-phase) echo "' + APhase + '"; exit 0 ;;');
  WriteLn(F, 'esac');
  WriteLn(F, 'echo "mock plugin executed"');
  CloseFile(F);
  {$IFDEF UNIX}
  FpChmod(PluginPath, &755);
  {$ENDIF}
end;

procedure TTestPluginDiscovery.TestDiscoverPluginNotFound;
var
  Result: string;
  SavedDir: string;
begin
  SavedDir := GetCurrentDir;
  try
    SetCurrentDir(FTempDir);
    Result := TPluginDiscovery.DiscoverPlugin('nonexistent-plugin-xyz');
    AssertEquals('Should return empty for nonexistent plugin', '', Result);
  finally
    SetCurrentDir(SavedDir);
  end;
end;

procedure TTestPluginDiscovery.TestDiscoverPluginFindsInProjectDir;
var
  PluginsDir: string;
  Result: string;
  SavedDir: string;
begin
  PluginsDir := IncludeTrailingPathDelimiter(FTempDir) + 'plugins';
  CreateMockPlugin(PluginsDir, 'pasbuild-testgoal');

  SavedDir := GetCurrentDir;
  try
    SetCurrentDir(FTempDir);
    Result := TPluginDiscovery.DiscoverPlugin('testgoal');
    AssertTrue('Should find plugin in project plugins dir', Result <> '');
    AssertTrue('Path should contain plugins directory',
      Pos('plugins', Result) > 0);
  finally
    SetCurrentDir(SavedDir);
  end;
end;

procedure TTestPluginDiscovery.TestDiscoverAllPluginsEmpty;
var
  Plugins: TStringList;
  SavedDir: string;
begin
  SavedDir := GetCurrentDir;
  try
    SetCurrentDir(FTempDir);
    Plugins := TPluginDiscovery.DiscoverAllPlugins;
    try
      // May find plugins from user dir, but project dir should be empty
      // This test just verifies the method doesn't crash
      AssertTrue('Should return a valid list', Plugins <> nil);
    finally
      Plugins.Free;
    end;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

procedure TTestPluginDiscovery.TestDiscoverAllPluginsFindsPlugins;
var
  PluginsDir: string;
  Plugins: TStringList;
  SavedDir: string;
begin
  PluginsDir := IncludeTrailingPathDelimiter(FTempDir) + 'plugins';
  CreateMockPlugin(PluginsDir, 'pasbuild-alpha');
  CreateMockPlugin(PluginsDir, 'pasbuild-beta');

  SavedDir := GetCurrentDir;
  try
    SetCurrentDir(FTempDir);
    Plugins := TPluginDiscovery.DiscoverAllPlugins;
    try
      AssertTrue('Should find at least 2 plugins', Plugins.Count >= 2);
      AssertTrue('Should find alpha', Plugins.IndexOf('alpha') >= 0);
      AssertTrue('Should find beta', Plugins.IndexOf('beta') >= 0);
    finally
      Plugins.Free;
    end;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

procedure TTestPluginDiscovery.TestDiscoverAllPluginsDeduplicates;
var
  PluginsDir: string;
  Plugins: TStringList;
  SavedDir: string;
  Count, I: Integer;
begin
  PluginsDir := IncludeTrailingPathDelimiter(FTempDir) + 'plugins';
  CreateMockPlugin(PluginsDir, 'pasbuild-duptest');

  SavedDir := GetCurrentDir;
  try
    SetCurrentDir(FTempDir);
    Plugins := TPluginDiscovery.DiscoverAllPlugins;
    try
      Count := 0;
      for I := 0 to Plugins.Count - 1 do
        if Plugins[I] = 'duptest' then
          Inc(Count);
      AssertEquals('Should have exactly one entry for duptest', 1, Count);
    finally
      Plugins.Free;
    end;
  finally
    SetCurrentDir(SavedDir);
  end;
end;

{ TTestPluginPhaseQuery }

procedure TTestPluginPhaseQuery.SetUp;
begin
  FTempDir := IncludeTrailingPathDelimiter(GetTempDir) + 'pasbuild-test-phase-' + IntToStr(GetProcessID);
  ForceDirectories(FTempDir);
end;

procedure TTestPluginPhaseQuery.TearDown;
begin
  RemoveDir(FTempDir);
end;

procedure TTestPluginPhaseQuery.CreateMockPluginWithPhase(const ADir, AName, APhase: string);
var
  PluginPath: string;
  F: TextFile;
begin
  ForceDirectories(ADir);
  PluginPath := IncludeTrailingPathDelimiter(ADir) + AName;
  AssignFile(F, PluginPath);
  Rewrite(F);
  WriteLn(F, '#!/bin/sh');
  WriteLn(F, 'case "$1" in');
  WriteLn(F, '  --pasbuild-phase) echo "' + APhase + '"; exit 0 ;;');
  WriteLn(F, 'esac');
  WriteLn(F, 'echo "executed"');
  CloseFile(F);
  {$IFDEF UNIX}
  FpChmod(PluginPath, &755);
  {$ENDIF}
end;

procedure TTestPluginPhaseQuery.TestQueryPhaseAfterCompile;
var
  Info: TPluginPhaseInfo;
  PluginPath: string;
begin
  PluginPath := IncludeTrailingPathDelimiter(FTempDir) + 'pasbuild-test';
  CreateMockPluginWithPhase(FTempDir, 'pasbuild-test', 'after:compile');

  Info := TPluginDiscovery.QueryPluginPhase(PluginPath);
  AssertTrue('Phase should be valid', Info.Valid);
  AssertEquals('AfterGoal should be bgCompile', Ord(bgCompile), Ord(Info.AfterGoal));
end;

procedure TTestPluginPhaseQuery.TestQueryPhaseAfterTest;
var
  Info: TPluginPhaseInfo;
  PluginPath: string;
begin
  PluginPath := IncludeTrailingPathDelimiter(FTempDir) + 'pasbuild-test';
  CreateMockPluginWithPhase(FTempDir, 'pasbuild-test', 'after:test');

  Info := TPluginDiscovery.QueryPluginPhase(PluginPath);
  AssertTrue('Phase should be valid', Info.Valid);
  AssertEquals('AfterGoal should be bgTest', Ord(bgTest), Ord(Info.AfterGoal));
end;

procedure TTestPluginPhaseQuery.TestQueryPhaseNone;
var
  Info: TPluginPhaseInfo;
  PluginPath: string;
begin
  PluginPath := IncludeTrailingPathDelimiter(FTempDir) + 'pasbuild-test';
  CreateMockPluginWithPhase(FTempDir, 'pasbuild-test', 'none');

  Info := TPluginDiscovery.QueryPluginPhase(PluginPath);
  AssertTrue('Phase should be valid', Info.Valid);
  AssertEquals('AfterGoal should be bgUnknown for none', Ord(bgUnknown), Ord(Info.AfterGoal));
end;

procedure TTestPluginPhaseQuery.TestQueryPhaseInvalid;
var
  Info: TPluginPhaseInfo;
  PluginPath: string;
begin
  PluginPath := IncludeTrailingPathDelimiter(FTempDir) + 'pasbuild-test';
  CreateMockPluginWithPhase(FTempDir, 'pasbuild-test', 'garbage-phase');

  Info := TPluginDiscovery.QueryPluginPhase(PluginPath);
  AssertFalse('Phase should be invalid for garbage input', Info.Valid);
end;

procedure TTestPluginPhaseQuery.TestQueryPhaseWithAfterPrefix;
var
  Info: TPluginPhaseInfo;
  PluginPath: string;
begin
  // Test that bare goal name (without after: prefix) also works
  PluginPath := IncludeTrailingPathDelimiter(FTempDir) + 'pasbuild-test';
  CreateMockPluginWithPhase(FTempDir, 'pasbuild-test', 'compile');

  Info := TPluginDiscovery.QueryPluginPhase(PluginPath);
  AssertTrue('Phase should be valid for bare goal name', Info.Valid);
  AssertEquals('AfterGoal should be bgCompile', Ord(bgCompile), Ord(Info.AfterGoal));
end;

{ TTestPluginCommand }

procedure TTestPluginCommand.SetUp;
begin
  FConfig := TProjectConfig.Create;
  FConfig.Name := 'test-project';
  FConfig.Version := '1.0.0';
  FProfileIds := TStringList.Create;
end;

procedure TTestPluginCommand.TearDown;
begin
  FProfileIds.Free;
  FConfig.Free;
end;

procedure TTestPluginCommand.TestPluginCommandGetName;
var
  Cmd: TPluginCommand;
begin
  Cmd := TPluginCommand.Create(FConfig, FProfileIds, '/usr/bin/pasbuild-hello', 'hello', bgUnknown);
  try
    AssertEquals('Name should be the goal name', 'hello', Cmd.Name);
  finally
    Cmd.Free;
  end;
end;

procedure TTestPluginCommand.TestPluginCommandGetDependenciesAfterCompile;
var
  Cmd: TPluginCommand;
  Deps: TBuildCommandList;
begin
  Cmd := TPluginCommand.Create(FConfig, FProfileIds, '/usr/bin/pasbuild-hello', 'hello', bgCompile);
  try
    Deps := Cmd.GetDependencies;
    try
      AssertEquals('Should have one dependency', 1, Deps.Count);
      AssertEquals('Dependency should be compile', 'compile', Deps[0].Name);
    finally
      Deps[0].Free;
      Deps.Free;
    end;
  finally
    Cmd.Free;
  end;
end;

procedure TTestPluginCommand.TestPluginCommandGetDependenciesNone;
var
  Cmd: TPluginCommand;
  Deps: TBuildCommandList;
begin
  Cmd := TPluginCommand.Create(FConfig, FProfileIds, '/usr/bin/pasbuild-hello', 'hello', bgUnknown);
  try
    Deps := Cmd.GetDependencies;
    try
      AssertEquals('Should have no dependencies for bgUnknown', 0, Deps.Count);
    finally
      Deps.Free;
    end;
  finally
    Cmd.Free;
  end;
end;

initialization
  RegisterTest(TTestPluginDiscovery);
  RegisterTest(TTestPluginPhaseQuery);
  RegisterTest(TTestPluginCommand);

end.
