{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Repository;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Repository;

type
  { Test TLocalRepository path construction }
  TTestRepositoryPaths = class(TTestCase)
  published
    procedure TestGetRepositoryRoot;
    procedure TestGetArtifactPath;
    procedure TestGetUnitsPath;
    procedure TestGetMetadataPath;
  end;

  { Test TLocalRepository directory management }
  TTestRepositoryDirectories = class(TTestCase)
  private
    FTestRepoRoot: string;
    procedure CleanTestDir;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEnsureDirectoryStructure;
    procedure TestArtifactExistsFalseWhenMissing;
    procedure TestArtifactExistsTrueWhenPresent;
    procedure TestGetAvailableTargetsEmpty;
    procedure TestGetAvailableTargetsMultiple;
  end;

  { Test metadata read/write }
  TTestRepositoryMetadata = class(TTestCase)
  private
    FTestRepoRoot: string;
    procedure CleanTestDir;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWriteAndReadMetadataNoDeps;
    procedure TestWriteAndReadMetadataWithDeps;
    procedure TestReadMetadataMissingFile;
  end;

  { Test unit file copying }
  TTestRepositoryCopyFiles = class(TTestCase)
  private
    FTestRepoRoot: string;
    FTestSourceDir: string;
    procedure CleanTestDir;
    procedure CreateTestSourceFiles;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCopyUnitFiles;
    procedure TestCopySkipsNonUnitFiles;
    procedure TestCountFiles;
  end;

implementation

{ Helper: recursively remove a directory }
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

{ TTestRepositoryPaths }

procedure TTestRepositoryPaths.TestGetRepositoryRoot;
var
  Root: string;
begin
  Root := TLocalRepository.GetRepositoryRoot;
  AssertTrue('Repository root should not be empty', Root <> '');
  AssertTrue('Repository root should end with "repository"',
    Copy(Root, Length(Root) - Length('repository') + 1, MaxInt) = 'repository');
  AssertTrue('Repository root should contain .pasbuild',
    Pos('.pasbuild', Root) > 0);
end;

procedure TTestRepositoryPaths.TestGetArtifactPath;
var
  Path: string;
begin
  Path := TLocalRepository.GetArtifactPath('my-lib', '1.0.0', 'x86_64-linux-3.2.2');
  AssertTrue('Artifact path should contain name', Pos('my-lib', Path) > 0);
  AssertTrue('Artifact path should contain version', Pos('1.0.0', Path) > 0);
  AssertTrue('Artifact path should contain triplet', Pos('x86_64-linux-3.2.2', Path) > 0);
end;

procedure TTestRepositoryPaths.TestGetUnitsPath;
var
  Path: string;
begin
  Path := TLocalRepository.GetUnitsPath('my-lib', '1.0.0', 'x86_64-linux-3.2.2');
  AssertTrue('Units path should end with "units"',
    Copy(Path, Length(Path) - Length('units') + 1, MaxInt) = 'units');
end;

procedure TTestRepositoryPaths.TestGetMetadataPath;
var
  Path: string;
begin
  Path := TLocalRepository.GetMetadataPath('my-lib', '1.0.0', 'x86_64-linux-3.2.2');
  AssertTrue('Metadata path should end with "metadata.xml"',
    Copy(Path, Length(Path) - Length('metadata.xml') + 1, MaxInt) = 'metadata.xml');
end;

{ TTestRepositoryDirectories }

procedure TTestRepositoryDirectories.CleanTestDir;
begin
  RemoveDirRecursive(FTestRepoRoot);
end;

procedure TTestRepositoryDirectories.SetUp;
begin
  // Use a test-specific directory under target/ to avoid polluting the real repo
  FTestRepoRoot := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test-repo';
  CleanTestDir;
end;

procedure TTestRepositoryDirectories.TearDown;
begin
  CleanTestDir;
end;

procedure TTestRepositoryDirectories.TestEnsureDirectoryStructure;
var
  UnitsDir: string;
begin
  UnitsDir := FTestRepoRoot + DirectorySeparator + 'my-lib' + DirectorySeparator +
              '1.0.0' + DirectorySeparator + 'x86_64-linux-3.2.2' + DirectorySeparator + 'units';
  ForceDirectories(UnitsDir);
  AssertTrue('Units directory should be created', DirectoryExists(UnitsDir));
end;

procedure TTestRepositoryDirectories.TestArtifactExistsFalseWhenMissing;
begin
  AssertFalse('Artifact should not exist in empty directory',
    TLocalRepository.ArtifactExists('nonexistent', '1.0.0', 'x86_64-linux-3.2.2'));
end;

procedure TTestRepositoryDirectories.TestArtifactExistsTrueWhenPresent;
var
  ArtifactDir, MetadataFile: string;
  F: TextFile;
begin
  // Create the artifact directory structure with metadata.xml
  ArtifactDir := TLocalRepository.GetArtifactPath('test-lib', '1.0.0', 'x86_64-linux-3.2.2');
  ForceDirectories(ArtifactDir);
  MetadataFile := TLocalRepository.GetMetadataPath('test-lib', '1.0.0', 'x86_64-linux-3.2.2');

  AssignFile(F, MetadataFile);
  Rewrite(F);
  WriteLn(F, '<artifact></artifact>');
  CloseFile(F);

  AssertTrue('Artifact should exist when directory and metadata present',
    TLocalRepository.ArtifactExists('test-lib', '1.0.0', 'x86_64-linux-3.2.2'));
end;

procedure TTestRepositoryDirectories.TestGetAvailableTargetsEmpty;
var
  Targets: TStringList;
begin
  Targets := TLocalRepository.GetAvailableTargets('nonexistent', '1.0.0');
  try
    AssertEquals('Should have no targets for missing artifact', 0, Targets.Count);
  finally
    Targets.Free;
  end;
end;

procedure TTestRepositoryDirectories.TestGetAvailableTargetsMultiple;
var
  Targets: TStringList;
  VersionDir: string;
begin
  // Create two target directories
  VersionDir := TLocalRepository.GetRepositoryRoot + DirectorySeparator +
                'test-lib' + DirectorySeparator + '1.0.0';
  ForceDirectories(VersionDir + DirectorySeparator + 'x86_64-linux-3.2.2');
  ForceDirectories(VersionDir + DirectorySeparator + 'i386-win32-3.2.2');

  Targets := TLocalRepository.GetAvailableTargets('test-lib', '1.0.0');
  try
    AssertEquals('Should find two targets', 2, Targets.Count);
  finally
    Targets.Free;
  end;
end;

{ TTestRepositoryMetadata }

procedure TTestRepositoryMetadata.CleanTestDir;
begin
  RemoveDirRecursive(FTestRepoRoot);
end;

procedure TTestRepositoryMetadata.SetUp;
begin
  FTestRepoRoot := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test-repo';
  CleanTestDir;
end;

procedure TTestRepositoryMetadata.TearDown;
begin
  CleanTestDir;
end;

procedure TTestRepositoryMetadata.TestWriteAndReadMetadataNoDeps;
var
  Written, Read: TArtifactMetadata;
begin
  // Create directory structure first
  TLocalRepository.EnsureDirectoryStructure('test-lib', '1.0.0', 'x86_64-linux-3.2.2');

  Written := TArtifactMetadata.Create;
  try
    Written.Name := 'test-lib';
    Written.Version := '1.0.0';
    Written.Packaging := 'library';
    Written.FPCVersion := '3.2.2';
    Written.TargetCPU := 'x86_64';
    Written.TargetOS := 'linux';
    Written.Timestamp := '2026-02-12T14:30:00';

    TLocalRepository.WriteMetadata('test-lib', '1.0.0', 'x86_64-linux-3.2.2', Written);
  finally
    Written.Free;
  end;

  Read := TLocalRepository.ReadMetadata('test-lib', '1.0.0', 'x86_64-linux-3.2.2');
  try
    AssertEquals('Name should match', 'test-lib', Read.Name);
    AssertEquals('Version should match', '1.0.0', Read.Version);
    AssertEquals('Packaging should match', 'library', Read.Packaging);
    AssertEquals('FPC version should match', '3.2.2', Read.FPCVersion);
    AssertEquals('Target CPU should match', 'x86_64', Read.TargetCPU);
    AssertEquals('Target OS should match', 'linux', Read.TargetOS);
    AssertEquals('Timestamp should match', '2026-02-12T14:30:00', Read.Timestamp);
    AssertEquals('Should have no dependencies', 0, Length(Read.Dependencies));
  finally
    Read.Free;
  end;
end;

procedure TTestRepositoryMetadata.TestWriteAndReadMetadataWithDeps;
var
  Written, Read: TArtifactMetadata;
  Deps: TMetadataDependencyArray;
begin
  TLocalRepository.EnsureDirectoryStructure('ui-lib', '2.0.0', 'x86_64-linux-3.2.2');

  Written := TArtifactMetadata.Create;
  try
    Written.Name := 'ui-lib';
    Written.Version := '2.0.0';
    Written.Packaging := 'library';
    Written.FPCVersion := '3.2.2';
    Written.TargetCPU := 'x86_64';
    Written.TargetOS := 'linux';
    Written.Timestamp := '2026-02-12T15:00:00';

    SetLength(Deps, 2);
    Deps[0].Name := 'core-lib';
    Deps[0].Version := '1.0.0';
    Deps[1].Name := 'utils-lib';
    Deps[1].Version := '3.1.0';
    Written.Dependencies := Deps;

    TLocalRepository.WriteMetadata('ui-lib', '2.0.0', 'x86_64-linux-3.2.2', Written);
  finally
    Written.Free;
  end;

  Read := TLocalRepository.ReadMetadata('ui-lib', '2.0.0', 'x86_64-linux-3.2.2');
  try
    AssertEquals('Should have 2 dependencies', 2, Length(Read.Dependencies));
    AssertEquals('First dep name', 'core-lib', Read.Dependencies[0].Name);
    AssertEquals('First dep version', '1.0.0', Read.Dependencies[0].Version);
    AssertEquals('Second dep name', 'utils-lib', Read.Dependencies[1].Name);
    AssertEquals('Second dep version', '3.1.0', Read.Dependencies[1].Version);
  finally
    Read.Free;
  end;
end;

procedure TTestRepositoryMetadata.TestReadMetadataMissingFile;
var
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  try
    TLocalRepository.ReadMetadata('nonexistent', '1.0.0', 'x86_64-linux-3.2.2').Free;
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      AssertTrue('Error should mention metadata', Pos('Metadata', E.Message) > 0);
    end;
  end;
  AssertTrue('Should raise exception for missing metadata', ExceptionRaised);
end;

{ TTestRepositoryCopyFiles }

procedure TTestRepositoryCopyFiles.CleanTestDir;
begin
  RemoveDirRecursive(FTestRepoRoot);
  RemoveDirRecursive(FTestSourceDir);
end;

procedure TTestRepositoryCopyFiles.SetUp;
begin
  FTestRepoRoot := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test-repo';
  FTestSourceDir := IncludeTrailingPathDelimiter(GetCurrentDir) + 'test-source-units';
  CleanTestDir;
end;

procedure TTestRepositoryCopyFiles.TearDown;
begin
  CleanTestDir;
end;

procedure TTestRepositoryCopyFiles.CreateTestSourceFiles;
var
  F: TextFile;
begin
  ForceDirectories(FTestSourceDir);

  // Create mock .ppu files
  AssignFile(F, FTestSourceDir + DirectorySeparator + 'MyUnit.ppu');
  Rewrite(F);
  WriteLn(F, 'mock ppu content');
  CloseFile(F);

  // Create mock .o files
  AssignFile(F, FTestSourceDir + DirectorySeparator + 'MyUnit.o');
  Rewrite(F);
  WriteLn(F, 'mock object content');
  CloseFile(F);

  // Create a non-unit file that should be skipped
  AssignFile(F, FTestSourceDir + DirectorySeparator + 'README.txt');
  Rewrite(F);
  WriteLn(F, 'should not be copied');
  CloseFile(F);
end;

procedure TTestRepositoryCopyFiles.TestCopyUnitFiles;
var
  DestUnitsDir: string;
begin
  CreateTestSourceFiles;
  TLocalRepository.EnsureDirectoryStructure('copy-test', '1.0.0', 'x86_64-linux-3.2.2');

  TLocalRepository.CopyUnitFiles(FTestSourceDir, 'copy-test', '1.0.0', 'x86_64-linux-3.2.2');

  DestUnitsDir := TLocalRepository.GetUnitsPath('copy-test', '1.0.0', 'x86_64-linux-3.2.2');
  AssertTrue('.ppu file should be copied',
    FileExists(DestUnitsDir + DirectorySeparator + 'MyUnit.ppu'));
  AssertTrue('.o file should be copied',
    FileExists(DestUnitsDir + DirectorySeparator + 'MyUnit.o'));
end;

procedure TTestRepositoryCopyFiles.TestCopySkipsNonUnitFiles;
var
  DestUnitsDir: string;
begin
  CreateTestSourceFiles;
  TLocalRepository.EnsureDirectoryStructure('copy-test', '1.0.0', 'x86_64-linux-3.2.2');

  TLocalRepository.CopyUnitFiles(FTestSourceDir, 'copy-test', '1.0.0', 'x86_64-linux-3.2.2');

  DestUnitsDir := TLocalRepository.GetUnitsPath('copy-test', '1.0.0', 'x86_64-linux-3.2.2');
  AssertFalse('README.txt should NOT be copied',
    FileExists(DestUnitsDir + DirectorySeparator + 'README.txt'));
end;

procedure TTestRepositoryCopyFiles.TestCountFiles;
begin
  CreateTestSourceFiles;
  AssertEquals('Should count 2 unit files', 2,
    TLocalRepository.CountFiles(FTestSourceDir, '*.ppu') +
    TLocalRepository.CountFiles(FTestSourceDir, '*.o'));
  AssertEquals('Should count 1 ppu file', 1,
    TLocalRepository.CountFiles(FTestSourceDir, '*.ppu'));
end;

initialization
  RegisterTest(TTestRepositoryPaths);
  RegisterTest(TTestRepositoryDirectories);
  RegisterTest(TTestRepositoryMetadata);
  RegisterTest(TTestRepositoryCopyFiles);

end.
