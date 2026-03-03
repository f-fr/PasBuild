{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Command.DependencyTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Types,
  PasBuild.Command.DependencyTree;

type
  { Tests for TDependencyTreeCommand }
  TTestDependencyTreeCommand = class(TTestCase)
  private
    function BuildThreeModuleRegistry: TModuleRegistry;
  published
    procedure TestSingleModuleNoDeps;
    procedure TestSingleModuleWithExternalDeps;
    procedure TestMultiModuleAllModules;
    procedure TestMultiModuleSelectedModuleValid;
    procedure TestMultiModuleSelectedModuleInvalid;
  end;

implementation

{ Helper: build a 3-module registry:
    lib-core  (library, no deps)
    lib-ui    (library, depends on lib-core)
    my-app    (application, depends on lib-ui [module] + some-ext:2.0.0 [external])
}
function TTestDependencyTreeCommand.BuildThreeModuleRegistry: TModuleRegistry;
var
  Registry: TModuleRegistry;
  Module: TModuleInfo;
  Config: TProjectConfig;
begin
  Registry := TModuleRegistry.Create;

  { lib-core: no dependencies }
  Config := TProjectConfig.Create;
  Config.Name := 'lib-core';
  Config.Version := '1.0.0';
  Config.BuildConfig.ProjectType := ptLibrary;
  Module := TModuleInfo.Create;
  Module.Name := 'lib-core';
  Module.Path := '/tmp/test-lib-core';
  Module.Config := Config;
  Registry.RegisterModule(Module);

  { lib-ui: depends on lib-core (module) }
  Config := TProjectConfig.Create;
  Config.Name := 'lib-ui';
  Config.Version := '1.0.0';
  Config.BuildConfig.ProjectType := ptLibrary;
  Module := TModuleInfo.Create;
  Module.Name := 'lib-ui';
  Module.Path := '/tmp/test-lib-ui';
  Module.Config := Config;
  Module.Dependencies.Add('lib-core');
  Registry.RegisterModule(Module);

  { my-app: depends on lib-ui (module) and some-ext:2.0.0 (external) }
  Config := TProjectConfig.Create;
  Config.Name := 'my-app';
  Config.Version := '1.0.0';
  Config.BuildConfig.ProjectType := ptApplication;
  Config.Dependencies.Add(TDependencyInfo.Create('some-ext', '2.0.0'));
  Module := TModuleInfo.Create;
  Module.Name := 'my-app';
  Module.Path := '/tmp/test-my-app';
  Module.Config := Config;
  Module.Dependencies.Add('lib-ui');
  Registry.RegisterModule(Module);

  Result := Registry;
end;

{ Single-module project with no external dependencies }
procedure TTestDependencyTreeCommand.TestSingleModuleNoDeps;
var
  Config: TProjectConfig;
  Command: TDependencyTreeCommand;
  ExitCode: Integer;
begin
  Config := TProjectConfig.Create;
  try
    Config.Name := 'simple-app';
    Config.Version := '1.0.0';
    Command := TDependencyTreeCommand.Create(Config, nil);
    try
      ExitCode := Command.Execute;
      AssertEquals('Single-module with no deps should return 0', 0, ExitCode);
    finally
      Command.Free;
    end;
  finally
    Config.Free;
  end;
end;

{ Single-module project with external dependencies }
procedure TTestDependencyTreeCommand.TestSingleModuleWithExternalDeps;
var
  Config: TProjectConfig;
  Command: TDependencyTreeCommand;
  ExitCode: Integer;
begin
  Config := TProjectConfig.Create;
  try
    Config.Name := 'my-consumer';
    Config.Version := '2.1.0';
    Config.Dependencies.Add(TDependencyInfo.Create('lib-alpha', '1.0.0'));
    Config.Dependencies.Add(TDependencyInfo.Create('lib-beta', '3.2.1'));
    Command := TDependencyTreeCommand.Create(Config, nil);
    try
      ExitCode := Command.Execute;
      AssertEquals('Single-module with external deps should return 0', 0, ExitCode);
    finally
      Command.Free;
    end;
  finally
    Config.Free;
  end;
end;

{ Multi-module: display all modules (no -m filter) }
procedure TTestDependencyTreeCommand.TestMultiModuleAllModules;
var
  AggregatorConfig: TProjectConfig;
  Registry: TModuleRegistry;
  Command: TDependencyTreeCommand;
  ExitCode: Integer;
begin
  AggregatorConfig := TProjectConfig.Create;
  Registry := BuildThreeModuleRegistry;
  try
    AggregatorConfig.Name := 'my-project';
    AggregatorConfig.Version := '1.0.0';
    AggregatorConfig.BuildConfig.ProjectType := ptPom;
    Command := TDependencyTreeCommand.CreateMultiModule(
      AggregatorConfig, nil, Registry, '');
    try
      ExitCode := Command.Execute;
      AssertEquals('Multi-module all-modules should return 0', 0, ExitCode);
    finally
      Command.Free;
    end;
  finally
    Registry.Free;
    AggregatorConfig.Free;
  end;
end;

{ Multi-module: filter to a valid module with -m }
procedure TTestDependencyTreeCommand.TestMultiModuleSelectedModuleValid;
var
  AggregatorConfig: TProjectConfig;
  Registry: TModuleRegistry;
  Command: TDependencyTreeCommand;
  ExitCode: Integer;
begin
  AggregatorConfig := TProjectConfig.Create;
  Registry := BuildThreeModuleRegistry;
  try
    AggregatorConfig.Name := 'my-project';
    AggregatorConfig.Version := '1.0.0';
    AggregatorConfig.BuildConfig.ProjectType := ptPom;
    Command := TDependencyTreeCommand.CreateMultiModule(
      AggregatorConfig, nil, Registry, 'my-app');
    try
      ExitCode := Command.Execute;
      AssertEquals('Multi-module with valid -m should return 0', 0, ExitCode);
    finally
      Command.Free;
    end;
  finally
    Registry.Free;
    AggregatorConfig.Free;
  end;
end;

{ Multi-module: -m references a module that does not exist }
procedure TTestDependencyTreeCommand.TestMultiModuleSelectedModuleInvalid;
var
  AggregatorConfig: TProjectConfig;
  Registry: TModuleRegistry;
  Command: TDependencyTreeCommand;
  ExitCode: Integer;
begin
  AggregatorConfig := TProjectConfig.Create;
  Registry := BuildThreeModuleRegistry;
  try
    AggregatorConfig.Name := 'my-project';
    AggregatorConfig.Version := '1.0.0';
    AggregatorConfig.BuildConfig.ProjectType := ptPom;
    Command := TDependencyTreeCommand.CreateMultiModule(
      AggregatorConfig, nil, Registry, 'nonexistent-module');
    try
      ExitCode := Command.Execute;
      AssertEquals('Multi-module with invalid -m should return 1', 1, ExitCode);
    finally
      Command.Free;
    end;
  finally
    Registry.Free;
    AggregatorConfig.Free;
  end;
end;

initialization
  RegisterTest(TTestDependencyTreeCommand);

end.
