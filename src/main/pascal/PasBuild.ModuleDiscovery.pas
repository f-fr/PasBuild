{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.ModuleDiscovery;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  PasBuild.Types,
  PasBuild.Config;

type
  { Module discovery and resolution }
  TModuleDiscoverer = class
  private
    class function ResolvePath(const ABaseDir, ARelativePath: string): string;
    class function IsPathWithinTree(const APath, ATreeRoot: string): Boolean;
    class procedure DiscoverModulesRecursive(
      const AAggregatorConfig: TProjectConfig;
      const AAggregatorDir: string;
      const ARootDir: string;
      const AInheritedVersion: string;
      ARegistry: TModuleRegistry;
      AVisitedAggregators: TStringList
    );
  public
    class function DiscoverModules(const AAggregatorPath: string): TModuleRegistry;
  end;

implementation

{ TModuleDiscoverer }

class function TModuleDiscoverer.ResolvePath(const ABaseDir, ARelativePath: string): string;
var
  NormalizedPath: string;
begin
  { Normalize path separators to platform-specific }
  NormalizedPath := StringReplace(ARelativePath, '/', PathDelim, [rfReplaceAll]);

  { Expand relative path from base directory }
  Result := ExpandFileName(IncludeTrailingPathDelimiter(ABaseDir) + NormalizedPath);

  { Ensure we have a normalized path }
  Result := ExpandFileName(Result);
end;

class function TModuleDiscoverer.IsPathWithinTree(const APath, ATreeRoot: string): Boolean;
var
  NormalizedPath, NormalizedRoot: string;
begin
  { Normalize both paths for comparison }
  NormalizedPath := ExpandFileName(APath);
  NormalizedRoot := IncludeTrailingPathDelimiter(ExpandFileName(ATreeRoot));

  { Check if path starts with root }
  Result := Pos(NormalizedRoot, NormalizedPath) = 1;
end;

class procedure TModuleDiscoverer.DiscoverModulesRecursive(
  const AAggregatorConfig: TProjectConfig;
  const AAggregatorDir: string;
  const ARootDir: string;
  const AInheritedVersion: string;
  ARegistry: TModuleRegistry;
  AVisitedAggregators: TStringList
);
var
  I: Integer;
  ModulePath: string;
  AbsoluteModulePath: string;
  ModuleProjectXml: string;
  ModuleConfig: TProjectConfig;
  ModuleInfo: TModuleInfo;
begin
  for I := 0 to AAggregatorConfig.Modules.Count - 1 do
  begin
    ModulePath := AAggregatorConfig.Modules[I];
    AbsoluteModulePath := ResolvePath(AAggregatorDir, ModulePath);

    { Cycle detection: check early before loading the module }
    if AVisitedAggregators.IndexOf(ExcludeTrailingPathDelimiter(AbsoluteModulePath)) >= 0 then
      raise Exception.CreateFmt(
        'Circular aggregator reference detected: %s (from %s)',
        [ModulePath, AAggregatorDir]);

    { Validate path is within project tree (always check against root) }
    if not IsPathWithinTree(AbsoluteModulePath, ARootDir) then
      raise Exception.CreateFmt('Module path outside project tree: %s', [ModulePath]);

    { Check if project.xml exists }
    ModuleProjectXml := IncludeTrailingPathDelimiter(AbsoluteModulePath) + 'project.xml';
    if not FileExists(ModuleProjectXml) then
      raise Exception.CreateFmt('Module project.xml not found: %s', [ModuleProjectXml]);

    { Load module configuration (allow empty version for inheritance) }
    ModuleConfig := TConfigLoader.LoadProjectXML(ModuleProjectXml, True);

    { Version inheritance: if module has no version, inherit from parent aggregator }
    if ModuleConfig.Version = '' then
      ModuleConfig.Version := AInheritedVersion
    else if ModuleConfig.Version <> AInheritedVersion then
      raise Exception.CreateFmt(
        'Module "%s" version "%s" does not match aggregator version "%s". ' +
        'Remove <version> from module to inherit from aggregator, or set it to "%s".',
        [ModuleConfig.Name, ModuleConfig.Version, AInheritedVersion, AInheritedVersion]);

    { Create module info }
    ModuleInfo := TModuleInfo.Create;
    ModuleInfo.Name := ModuleConfig.Name;
    ModuleInfo.Path := AbsoluteModulePath;
    ModuleInfo.Config := ModuleConfig;  { Assign config (owned by ModuleInfo) }
    ModuleInfo.UnitsDirectory := IncludeTrailingPathDelimiter(AbsoluteModulePath) + 'target' + PathDelim + 'units';

    { Register in registry }
    ARegistry.RegisterModule(ModuleInfo);

    { If this module is itself an aggregator, recurse into its children }
    if (ModuleConfig.BuildConfig.ProjectType = ptPom) and
       (ModuleConfig.Modules.Count > 0) then
    begin
      { Mark as visited and recurse }
      AVisitedAggregators.Add(ExcludeTrailingPathDelimiter(AbsoluteModulePath));
      DiscoverModulesRecursive(
        ModuleConfig,
        AbsoluteModulePath,
        ARootDir,
        ModuleConfig.Version,  { Pass resolved version down the chain }
        ARegistry,
        AVisitedAggregators
      );
    end;
  end;
end;

class function TModuleDiscoverer.DiscoverModules(const AAggregatorPath: string): TModuleRegistry;
var
  AggregatorConfig: TProjectConfig;
  AggregatorDir: string;
  VisitedAggregators: TStringList;
  I, J: Integer;
  ModuleInfo: TModuleInfo;
  DependencyPath: string;
  AbsoluteDependencyPath: string;
  DependencyModuleInfo: TModuleInfo;
begin
  Result := TModuleRegistry.Create;

  try
    { Load aggregator project.xml }
    AggregatorConfig := TConfigLoader.LoadProjectXML(AAggregatorPath);
    try
      { Validate it's an aggregator }
      if AggregatorConfig.BuildConfig.ProjectType <> ptPom then
        raise Exception.Create('Aggregator project must have packaging=pom');

      { Get aggregator directory }
      AggregatorDir := ExtractFilePath(AAggregatorPath);
      if AggregatorDir = '' then
        AggregatorDir := GetCurrentDir;
      AggregatorDir := ExpandFileName(AggregatorDir);

      { Recursively discover all modules }
      VisitedAggregators := TStringList.Create;
      try
        VisitedAggregators.Add(ExcludeTrailingPathDelimiter(AggregatorDir));  { Seed with root aggregator path }
        DiscoverModulesRecursive(
          AggregatorConfig,
          AggregatorDir,
          AggregatorDir,
          AggregatorConfig.Version,
          Result,
          VisitedAggregators
        );
      finally
        VisitedAggregators.Free;
      end;

      { Second pass: Resolve dependencies across all discovered modules }
      for I := 0 to Result.Modules.Count - 1 do
      begin
        ModuleInfo := TModuleInfo(Result.Modules[I]);

        { Process module dependencies }
        for J := 0 to ModuleInfo.Config.ModuleDependencies.Count - 1 do
        begin
          DependencyPath := ModuleInfo.Config.ModuleDependencies[J];

          { Resolve relative to module's directory }
          AbsoluteDependencyPath := ResolvePath(ModuleInfo.Path, DependencyPath);

          { Validate path is within project tree }
          if not IsPathWithinTree(AbsoluteDependencyPath, AggregatorDir) then
            raise Exception.CreateFmt('Dependency path outside project tree: %s', [DependencyPath]);

          { Find module by path }
          DependencyModuleInfo := Result.FindModuleByPath(AbsoluteDependencyPath);
          if DependencyModuleInfo = nil then
            raise Exception.CreateFmt('Dependency module not found: %s (resolved to %s)', [DependencyPath, AbsoluteDependencyPath]);

          { Add dependency name to module's dependencies }
          if ModuleInfo.Dependencies.IndexOf(DependencyModuleInfo.Name) < 0 then
            ModuleInfo.Dependencies.Add(DependencyModuleInfo.Name);
        end;
      end;

    finally
      AggregatorConfig.Free;
    end;

  except
    Result.Free;
    raise;
  end;
end;

end.
