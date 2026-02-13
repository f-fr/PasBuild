{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Dependencies;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Types,
  PasBuild.Repository,
  PasBuild.Dependencies;

type
  { Test dependency resolution from local repository }
  TTestDependencyResolver = class(TTestCase)
  private
    FTriplet: string;
    procedure InstallMockArtifact(const AName, AVersion: string;
      const ADeps: array of string);
    procedure CleanupMockArtifact(const AName, AVersion: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestResolveSingleDependency;
    procedure TestResolveMultipleDependencies;
    procedure TestResolveTransitiveDependency;
    procedure TestResolveMissingDependency;
    procedure TestResolveTargetMismatch;
    procedure TestResolveNoDependencies;
    procedure TestResolveCyclicDependency;
  end;

implementation

uses
  PasBuild.Utils;

{ TTestDependencyResolver }

procedure TTestDependencyResolver.InstallMockArtifact(const AName, AVersion: string;
  const ADeps: array of string);
var
  Metadata: TArtifactMetadata;
  DepArray: TMetadataDependencyArray;
  I: Integer;
  UnitsDir, DummyFile: string;
  F: TextFile;
begin
  // Create directory structure
  TLocalRepository.EnsureDirectoryStructure(AName, AVersion, FTriplet);

  // Create a dummy .ppu file so the artifact looks real
  UnitsDir := TLocalRepository.GetUnitsPath(AName, AVersion, FTriplet);
  DummyFile := IncludeTrailingPathDelimiter(UnitsDir) + AName + '.ppu';
  AssignFile(F, DummyFile);
  Rewrite(F);
  WriteLn(F, '// dummy');
  CloseFile(F);

  // Build dependencies array (pairs of name:version)
  SetLength(DepArray, Length(ADeps) div 2);
  I := 0;
  while I < Length(ADeps) do
  begin
    DepArray[I div 2].Name := ADeps[I];
    DepArray[I div 2].Version := ADeps[I + 1];
    Inc(I, 2);
  end;

  // Write metadata
  Metadata := TArtifactMetadata.Create;
  try
    Metadata.Name := AName;
    Metadata.Version := AVersion;
    Metadata.Packaging := 'library';
    Metadata.FPCVersion := '3.2.2';
    Metadata.TargetCPU := 'x86_64';
    Metadata.TargetOS := 'linux';
    Metadata.Timestamp := '2026-01-01T00:00:00';
    Metadata.Dependencies := DepArray;
    TLocalRepository.WriteMetadata(AName, AVersion, FTriplet, Metadata);
  finally
    Metadata.Free;
  end;
end;

procedure TTestDependencyResolver.CleanupMockArtifact(const AName, AVersion: string);
var
  ArtifactPath: string;

  procedure RemoveDirRecursive(const ADir: string);
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
          if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
          begin
            FullPath := IncludeTrailingPathDelimiter(ADir) + SearchRec.Name;
            if (SearchRec.Attr and faDirectory) = faDirectory then
              RemoveDirRecursive(FullPath)
            else
              DeleteFile(FullPath);
          end;
        until FindNext(SearchRec) <> 0;
      finally
        FindClose(SearchRec);
      end;
    end;
    RemoveDir(ADir);
  end;

begin
  ArtifactPath := TLocalRepository.GetArtifactPath(AName, AVersion, FTriplet);
  RemoveDirRecursive(ArtifactPath);
end;

procedure TTestDependencyResolver.SetUp;
begin
  FTriplet := TUtils.GetTargetTriplet;
end;

procedure TTestDependencyResolver.TearDown;
begin
  // Cleanup is done per-test in each test method
end;

procedure TTestDependencyResolver.TestResolveSingleDependency;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
begin
  InstallMockArtifact('test-dep-lib', '1.0.0', []);
  try
    Config := TProjectConfig.Create;
    try
      Config.Dependencies.Add(TDependencyInfo.Create('test-dep-lib', '1.0.0'));

      Resolver := TDependencyResolver.Create;
      try
        Resolver.ResolveDependencies(Config);

        AssertEquals('Should have 1 resolved path', 1,
          Config.BuildConfig.ResolvedModulePaths.Count);
        AssertTrue('Path should point to units dir',
          Pos('test-dep-lib', Config.BuildConfig.ResolvedModulePaths[0]) > 0);
      finally
        Resolver.Free;
      end;
    finally
      Config.Free;
    end;
  finally
    CleanupMockArtifact('test-dep-lib', '1.0.0');
  end;
end;

procedure TTestDependencyResolver.TestResolveMultipleDependencies;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
begin
  InstallMockArtifact('test-dep-a', '1.0.0', []);
  InstallMockArtifact('test-dep-b', '2.0.0', []);
  try
    Config := TProjectConfig.Create;
    try
      Config.Dependencies.Add(TDependencyInfo.Create('test-dep-a', '1.0.0'));
      Config.Dependencies.Add(TDependencyInfo.Create('test-dep-b', '2.0.0'));

      Resolver := TDependencyResolver.Create;
      try
        Resolver.ResolveDependencies(Config);

        AssertEquals('Should have 2 resolved paths', 2,
          Config.BuildConfig.ResolvedModulePaths.Count);
      finally
        Resolver.Free;
      end;
    finally
      Config.Free;
    end;
  finally
    CleanupMockArtifact('test-dep-a', '1.0.0');
    CleanupMockArtifact('test-dep-b', '2.0.0');
  end;
end;

procedure TTestDependencyResolver.TestResolveTransitiveDependency;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
begin
  // dep-base has no deps, dep-mid depends on dep-base
  InstallMockArtifact('test-dep-base', '1.0.0', []);
  InstallMockArtifact('test-dep-mid', '1.0.0', ['test-dep-base', '1.0.0']);
  try
    Config := TProjectConfig.Create;
    try
      // Only declare dep-mid; dep-base should be resolved transitively
      Config.Dependencies.Add(TDependencyInfo.Create('test-dep-mid', '1.0.0'));

      Resolver := TDependencyResolver.Create;
      try
        Resolver.ResolveDependencies(Config);

        AssertEquals('Should have 2 resolved paths (direct + transitive)', 2,
          Config.BuildConfig.ResolvedModulePaths.Count);
      finally
        Resolver.Free;
      end;
    finally
      Config.Free;
    end;
  finally
    CleanupMockArtifact('test-dep-base', '1.0.0');
    CleanupMockArtifact('test-dep-mid', '1.0.0');
  end;
end;

procedure TTestDependencyResolver.TestResolveMissingDependency;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  Config := TProjectConfig.Create;
  try
    Config.Dependencies.Add(TDependencyInfo.Create('nonexistent-lib', '1.0.0'));

    Resolver := TDependencyResolver.Create;
    try
      try
        Resolver.ResolveDependencies(Config);
      except
        on E: EDependencyError do
        begin
          ExceptionRaised := True;
          AssertTrue('Error should mention dependency name',
            Pos('nonexistent-lib', E.Message) > 0);
          AssertTrue('Error should mention install',
            Pos('install', LowerCase(E.Message)) > 0);
        end;
      end;
    finally
      Resolver.Free;
    end;

    AssertTrue('Missing dependency should raise exception', ExceptionRaised);
  finally
    Config.Free;
  end;
end;

procedure TTestDependencyResolver.TestResolveTargetMismatch;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
  Metadata: TArtifactMetadata;
  WrongTriplet: string;
  UnitsDir, DummyFile: string;
  F: TextFile;
  ExceptionRaised: Boolean;
begin
  // Install under a different triplet
  WrongTriplet := 'arm-darwin-3.2.2';
  TLocalRepository.EnsureDirectoryStructure('test-dep-wrong-target', '1.0.0', WrongTriplet);

  UnitsDir := TLocalRepository.GetUnitsPath('test-dep-wrong-target', '1.0.0', WrongTriplet);
  DummyFile := IncludeTrailingPathDelimiter(UnitsDir) + 'dummy.ppu';
  AssignFile(F, DummyFile);
  Rewrite(F);
  WriteLn(F, '// dummy');
  CloseFile(F);

  Metadata := TArtifactMetadata.Create;
  try
    Metadata.Name := 'test-dep-wrong-target';
    Metadata.Version := '1.0.0';
    Metadata.Packaging := 'library';
    Metadata.FPCVersion := '3.2.2';
    Metadata.TargetCPU := 'arm';
    Metadata.TargetOS := 'darwin';
    Metadata.Timestamp := '2026-01-01T00:00:00';
    TLocalRepository.WriteMetadata('test-dep-wrong-target', '1.0.0', WrongTriplet, Metadata);
  finally
    Metadata.Free;
  end;

  ExceptionRaised := False;
  Config := TProjectConfig.Create;
  try
    Config.Dependencies.Add(TDependencyInfo.Create('test-dep-wrong-target', '1.0.0'));

    Resolver := TDependencyResolver.Create;
    try
      try
        Resolver.ResolveDependencies(Config);
      except
        on E: EDependencyError do
        begin
          ExceptionRaised := True;
          AssertTrue('Error should mention target',
            Pos('target', LowerCase(E.Message)) > 0);
          AssertTrue('Error should list available targets',
            Pos('arm-darwin-3.2.2', E.Message) > 0);
        end;
      end;
    finally
      Resolver.Free;
    end;

    AssertTrue('Target mismatch should raise exception', ExceptionRaised);
  finally
    Config.Free;
    // Clean up the wrong triplet directory
    DeleteFile(IncludeTrailingPathDelimiter(
      TLocalRepository.GetUnitsPath('test-dep-wrong-target', '1.0.0', WrongTriplet)) + 'dummy.ppu');
    DeleteFile(TLocalRepository.GetMetadataPath('test-dep-wrong-target', '1.0.0', WrongTriplet));
    RemoveDir(TLocalRepository.GetUnitsPath('test-dep-wrong-target', '1.0.0', WrongTriplet));
    RemoveDir(TLocalRepository.GetArtifactPath('test-dep-wrong-target', '1.0.0', WrongTriplet));
    // Remove version and name directories if empty
    RemoveDir(TLocalRepository.GetRepositoryRoot + DirectorySeparator +
              'test-dep-wrong-target' + DirectorySeparator + '1.0.0');
    RemoveDir(TLocalRepository.GetRepositoryRoot + DirectorySeparator +
              'test-dep-wrong-target');
  end;
end;

procedure TTestDependencyResolver.TestResolveNoDependencies;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
begin
  Config := TProjectConfig.Create;
  try
    // No dependencies declared
    Resolver := TDependencyResolver.Create;
    try
      Resolver.ResolveDependencies(Config);
      AssertEquals('No paths should be resolved', 0,
        Config.BuildConfig.ResolvedModulePaths.Count);
    finally
      Resolver.Free;
    end;
  finally
    Config.Free;
  end;
end;

procedure TTestDependencyResolver.TestResolveCyclicDependency;
var
  Config: TProjectConfig;
  Resolver: TDependencyResolver;
begin
  // Create two artifacts that depend on each other
  InstallMockArtifact('test-cycle-a', '1.0.0', ['test-cycle-b', '1.0.0']);
  InstallMockArtifact('test-cycle-b', '1.0.0', ['test-cycle-a', '1.0.0']);
  try
    Config := TProjectConfig.Create;
    try
      Config.Dependencies.Add(TDependencyInfo.Create('test-cycle-a', '1.0.0'));

      Resolver := TDependencyResolver.Create;
      try
        // Should NOT infinite loop - cycle detection via visited set
        Resolver.ResolveDependencies(Config);

        AssertEquals('Should resolve both (no infinite loop)', 2,
          Config.BuildConfig.ResolvedModulePaths.Count);
      finally
        Resolver.Free;
      end;
    finally
      Config.Free;
    end;
  finally
    CleanupMockArtifact('test-cycle-a', '1.0.0');
    CleanupMockArtifact('test-cycle-b', '1.0.0');
  end;
end;

initialization
  RegisterTest(TTestDependencyResolver);

end.
