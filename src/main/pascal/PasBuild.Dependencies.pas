{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Dependencies;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  PasBuild.Types;

type
  { Exception raised when dependency resolution fails }
  EDependencyError = class(Exception);

  { Resolves external dependencies from the local repository }
  TDependencyResolver = class
  private
    FVerbose: Boolean;
    FVisited: TStringList;
    procedure ResolveOne(const AName, AVersion, ATriplet: string;
      AResolvedPaths: TStringList);
  public
    constructor Create;
    destructor Destroy; override;

    { Resolve all dependencies declared in project config.
      Adds resolved unit paths to Config.BuildConfig.ResolvedModulePaths. }
    procedure ResolveDependencies(AConfig: TProjectConfig);

    property Verbose: Boolean read FVerbose write FVerbose;
  end;

implementation

uses
  PasBuild.Utils,
  PasBuild.Repository;

{ TDependencyResolver }

constructor TDependencyResolver.Create;
begin
  inherited Create;
  FVisited := TStringList.Create;
  FVisited.Sorted := True;
  FVisited.Duplicates := dupIgnore;
  FVerbose := False;
end;

destructor TDependencyResolver.Destroy;
begin
  FVisited.Free;
  inherited Destroy;
end;

procedure TDependencyResolver.ResolveOne(const AName, AVersion, ATriplet: string;
  AResolvedPaths: TStringList);
var
  Key, UnitsPath: string;
  Metadata: TArtifactMetadata;
  I: Integer;
  Targets: TStringList;
begin
  // Build a unique key for cycle detection
  Key := AName + ':' + AVersion;

  // Skip if already resolved (prevents cycles and duplicates)
  if FVisited.IndexOf(Key) >= 0 then
    Exit;
  FVisited.Add(Key);

  // Check if artifact exists in local repository
  if not TLocalRepository.ArtifactExists(AName, AVersion, ATriplet) then
  begin
    // Provide helpful error: check if artifact exists for other targets
    Targets := TLocalRepository.GetAvailableTargets(AName, AVersion);
    try
      if Targets.Count > 0 then
        raise EDependencyError.CreateFmt(
          'Dependency "%s:%s" not found for target "%s". ' +
          'Available targets: %s. Recompile and install with matching FPC target.',
          [AName, AVersion, ATriplet, Targets.CommaText])
      else
        raise EDependencyError.CreateFmt(
          'Dependency "%s:%s" not found in local repository. ' +
          'Run "pasbuild install" in the dependency project first.',
          [AName, AVersion]);
    finally
      Targets.Free;
    end;
  end;

  // Add units path
  UnitsPath := TLocalRepository.GetUnitsPath(AName, AVersion, ATriplet);
  if AResolvedPaths.IndexOf(UnitsPath) < 0 then
    AResolvedPaths.Add(UnitsPath);

  if FVerbose then
    TUtils.LogInfo('  Resolved: ' + AName + ':' + AVersion + ' -> ' + UnitsPath);

  // Read metadata to find transitive dependencies
  Metadata := TLocalRepository.ReadMetadata(AName, AVersion, ATriplet);
  try
    for I := 0 to Length(Metadata.Dependencies) - 1 do
    begin
      ResolveOne(
        Metadata.Dependencies[I].Name,
        Metadata.Dependencies[I].Version,
        ATriplet,
        AResolvedPaths
      );
    end;
  finally
    Metadata.Free;
  end;
end;

procedure TDependencyResolver.ResolveDependencies(AConfig: TProjectConfig);
var
  Triplet: string;
  I: Integer;
begin
  if AConfig.Dependencies.Count = 0 then
    Exit;

  if AConfig.Dependencies.Count = 1 then
    TUtils.LogInfo('Resolving 1 external dependency...')
  else
    TUtils.LogInfo('Resolving ' + IntToStr(AConfig.Dependencies.Count) +
                   ' external dependencies...');

  // Detect target triplet once
  Triplet := TUtils.GetTargetTriplet;

  // Clear visited set for this resolution run
  FVisited.Clear;

  // Resolve each declared dependency
  for I := 0 to AConfig.Dependencies.Count - 1 do
  begin
    ResolveOne(
      AConfig.Dependencies[I].Name,
      AConfig.Dependencies[I].Version,
      Triplet,
      AConfig.BuildConfig.ResolvedModulePaths
    );
  end;

  TUtils.LogInfo('Dependencies resolved successfully');
end;

end.
