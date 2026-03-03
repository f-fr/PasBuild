{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Command.DependencyTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  PasBuild.Types,
  PasBuild.Command,
  PasBuild.Utils;

type
  { TDependencyTreeCommand - Displays the dependency tree without compiling }
  TDependencyTreeCommand = class(TBuildCommand)
  private
    FRegistry: TModuleRegistry;   { nil for single-module projects }
    FSelectedModule: string;      { '' = all modules }
    function PackagingLabel(AType: TProjectType): string;
    procedure PrintModuleDeps(AModule: TModuleInfo);
    procedure PrintSingleProjectDeps;
  protected
    function GetName: string; override;
  public
    constructor Create(AConfig: TProjectConfig;
      AProfileIds: TStringList); override;
    constructor CreateMultiModule(AConfig: TProjectConfig;
      AProfileIds: TStringList; ARegistry: TModuleRegistry;
      const ASelectedModule: string = ''); reintroduce;

    function Execute: Integer; override;
    function GetDependencies: TBuildCommandList; override;

    property SelectedModule: string read FSelectedModule write FSelectedModule;
  end;

implementation

{ TDependencyTreeCommand }

constructor TDependencyTreeCommand.Create(AConfig: TProjectConfig;
  AProfileIds: TStringList);
begin
  inherited Create(AConfig, AProfileIds);
  FRegistry := nil;
  FSelectedModule := '';
end;

constructor TDependencyTreeCommand.CreateMultiModule(AConfig: TProjectConfig;
  AProfileIds: TStringList; ARegistry: TModuleRegistry;
  const ASelectedModule: string = '');
begin
  inherited Create(AConfig, AProfileIds);
  FRegistry := ARegistry;
  FSelectedModule := ASelectedModule;
end;

function TDependencyTreeCommand.GetName: string;
begin
  Result := 'dependency-tree';
end;

function TDependencyTreeCommand.GetDependencies: TBuildCommandList;
begin
  { No prerequisite goals — dependency-tree never compiles anything }
  Result := TBuildCommandList.Create;
  Result.FreeObjects := False;
end;

function TDependencyTreeCommand.PackagingLabel(AType: TProjectType): string;
begin
  case AType of
    ptApplication: Result := 'application';
    ptLibrary:     Result := 'library';
    ptPom:         Result := 'aggregator';
    else           Result := 'unknown';
  end;
end;

procedure TDependencyTreeCommand.PrintModuleDeps(AModule: TModuleInfo);
var
  I: Integer;
  TotalDeps: Integer;
  ItemIndex: Integer;
  Prefix: string;
  Header: string;
begin
  if AModule.Config = nil then
  begin
    TUtils.LogInfo(AModule.Name + ' [config not loaded]');
    Exit;
  end;

  { Build header: name + version + packaging label }
  if AModule.Config.Version <> '' then
    Header := AModule.Name + ' ' + AModule.Config.Version +
              ' [' + PackagingLabel(AModule.Config.BuildConfig.ProjectType) + ']'
  else
    Header := AModule.Name +
              ' [' + PackagingLabel(AModule.Config.BuildConfig.ProjectType) + ']';
  TUtils.LogInfo(Header);

  { Count total number of dependency items to print }
  TotalDeps := AModule.Dependencies.Count + AModule.Config.Dependencies.Count;

  if TotalDeps = 0 then
  begin
    TUtils.LogInfo('  (no dependencies)');
    Exit;
  end;

  ItemIndex := 0;

  { Print local module dependencies first }
  for I := 0 to AModule.Dependencies.Count - 1 do
  begin
    Inc(ItemIndex);
    if ItemIndex = TotalDeps then
      Prefix := '  └─ '
    else
      Prefix := '  ├─ ';
    TUtils.LogInfo(Prefix + AModule.Dependencies[I] + ' [module]');
  end;

  { Print external dependencies }
  for I := 0 to AModule.Config.Dependencies.Count - 1 do
  begin
    Inc(ItemIndex);
    if ItemIndex = TotalDeps then
      Prefix := '  └─ '
    else
      Prefix := '  ├─ ';
    TUtils.LogInfo(Prefix + AModule.Config.Dependencies[I].Name + ':' +
      AModule.Config.Dependencies[I].Version + ' [external]');
  end;
end;

procedure TDependencyTreeCommand.PrintSingleProjectDeps;
var
  I: Integer;
  TotalDeps: Integer;
  ItemIndex: Integer;
  Prefix: string;
  Header: string;
begin
  if FConfig.Version <> '' then
    Header := FConfig.Name + ' ' + FConfig.Version
  else
    Header := FConfig.Name;
  TUtils.LogInfo(Header);

  TotalDeps := FConfig.Dependencies.Count;

  if TotalDeps = 0 then
  begin
    TUtils.LogInfo('  (no dependencies)');
    Exit;
  end;

  ItemIndex := 0;
  for I := 0 to FConfig.Dependencies.Count - 1 do
  begin
    Inc(ItemIndex);
    if ItemIndex = TotalDeps then
      Prefix := '  └─ '
    else
      Prefix := '  ├─ ';
    TUtils.LogInfo(Prefix + FConfig.Dependencies[I].Name + ':' +
      FConfig.Dependencies[I].Version + ' [external]');
  end;
end;

function TDependencyTreeCommand.Execute: Integer;
var
  I: Integer;
  Module: TModuleInfo;
  FoundModule: TModuleInfo;
  BuildOrder: TList;
begin
  Result := 0;
  TUtils.LogSeparator;

  if FRegistry <> nil then
  begin
    { Multi-module path }
    if FSelectedModule <> '' then
      TUtils.LogInfo('Dependency Tree for module: ' + FSelectedModule)
    else
      TUtils.LogInfo('Dependency Tree');
    TUtils.LogSeparator;

    if FSelectedModule <> '' then
    begin
      { Find the requested module by name }
      FoundModule := nil;
      for I := 0 to FRegistry.Modules.Count - 1 do
      begin
        Module := TModuleInfo(FRegistry.Modules[I]);
        if CompareText(Module.Name, FSelectedModule) = 0 then
        begin
          FoundModule := Module;
          Break;
        end;
      end;

      if FoundModule = nil then
      begin
        TUtils.LogError('Module not found: ' + FSelectedModule);
        Result := 1;
        Exit;
      end;

      TUtils.LogInfo('');
      PrintModuleDeps(FoundModule);
    end
    else
    begin
      { Show all modules in topological order (dependencies before dependents) }
      BuildOrder := FRegistry.GetBuildOrder;
      try
        for I := 0 to BuildOrder.Count - 1 do
        begin
          Module := TModuleInfo(BuildOrder[I]);
          TUtils.LogInfo('');
          PrintModuleDeps(Module);
        end;
      finally
        BuildOrder.Free;
      end;
    end;
  end
  else
  begin
    { Single-module path }
    TUtils.LogInfo('Dependency Tree');
    TUtils.LogSeparator;
    TUtils.LogInfo('');
    PrintSingleProjectDeps;
  end;

  TUtils.LogInfo('');
end;

end.
