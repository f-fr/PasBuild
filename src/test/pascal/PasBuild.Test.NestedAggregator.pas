{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.NestedAggregator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Types,
  PasBuild.ModuleDiscovery;

type
  { Tests for nested aggregator discovery }
  TTestNestedDiscovery = class(TTestCase)
  private
    function GetFixturePath(const AFixtureName: string): string;
  published
    procedure TestDiscoverNestedSimple;
    procedure TestDiscoverNestedSimpleModuleCount;
    procedure TestDiscoverNestedSimpleAggregatorInRegistry;
    procedure TestDiscoverNestedDeep;
    procedure TestDiscoverNestedDeepModuleCount;
    procedure TestNestedVersionInheritanceLeaf;
    procedure TestNestedVersionInheritanceMiddle;
    procedure TestNestedCycleDetection;
    procedure TestNestedWithCrosslevelDependencies;
    procedure TestNestedBuildOrderWithDependencies;
  end;

implementation

{ TTestNestedDiscovery }

function TTestNestedDiscovery.GetFixturePath(const AFixtureName: string): string;
begin
  Result := 'fixtures/multi-module/' + AFixtureName + '/project.xml';
end;

procedure TTestNestedDiscovery.TestDiscoverNestedSimple;
var
  Registry: TModuleRegistry;
begin
  { Two-level nesting: root -> lib-core + sub-agg -> app-a }
  Registry := TModuleDiscoverer.DiscoverModules(GetFixturePath('nested-simple'));
  try
    AssertNotNull('lib-core should be discovered',
      Registry.FindModuleByName('lib-core'));
    AssertNotNull('sub-agg should be discovered',
      Registry.FindModuleByName('sub-agg'));
    AssertNotNull('app-a should be discovered',
      Registry.FindModuleByName('app-a'));
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestDiscoverNestedSimpleModuleCount;
var
  Registry: TModuleRegistry;
begin
  Registry := TModuleDiscoverer.DiscoverModules(GetFixturePath('nested-simple'));
  try
    AssertEquals('Should discover 3 modules (lib-core, sub-agg, app-a)',
      3, Registry.Modules.Count);
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestDiscoverNestedSimpleAggregatorInRegistry;
var
  Registry: TModuleRegistry;
  SubAgg: TModuleInfo;
begin
  { Nested aggregator should be in registry with ptPom type }
  Registry := TModuleDiscoverer.DiscoverModules(GetFixturePath('nested-simple'));
  try
    SubAgg := Registry.FindModuleByName('sub-agg');
    AssertNotNull('sub-agg should be in registry', SubAgg);
    AssertNotNull('sub-agg should have config', SubAgg.Config);
    AssertTrue('sub-agg should be ptPom',
      SubAgg.Config.BuildConfig.ProjectType = ptPom);
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestDiscoverNestedDeep;
var
  Registry: TModuleRegistry;
begin
  { Three-level nesting: root -> mid-agg -> inner-agg -> leaf-lib }
  Registry := TModuleDiscoverer.DiscoverModules(GetFixturePath('nested-deep'));
  try
    AssertNotNull('mid-agg should be discovered',
      Registry.FindModuleByName('mid-agg'));
    AssertNotNull('inner-agg should be discovered',
      Registry.FindModuleByName('inner-agg'));
    AssertNotNull('leaf-lib should be discovered',
      Registry.FindModuleByName('leaf-lib'));
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestDiscoverNestedDeepModuleCount;
var
  Registry: TModuleRegistry;
begin
  Registry := TModuleDiscoverer.DiscoverModules(GetFixturePath('nested-deep'));
  try
    AssertEquals('Should discover 3 modules (mid-agg, inner-agg, leaf-lib)',
      3, Registry.Modules.Count);
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestNestedVersionInheritanceLeaf;
var
  Registry: TModuleRegistry;
  LeafLib: TModuleInfo;
begin
  { Version should cascade: root 4.0.0 -> sub-agg -> leaf-lib }
  Registry := TModuleDiscoverer.DiscoverModules(
    GetFixturePath('nested-version-inherit'));
  try
    LeafLib := Registry.FindModuleByName('leaf-lib');
    AssertNotNull('leaf-lib should be discovered', LeafLib);
    AssertEquals('leaf-lib should inherit version 4.0.0 through two levels',
      '4.0.0', LeafLib.Config.Version);
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestNestedVersionInheritanceMiddle;
var
  Registry: TModuleRegistry;
  SubAgg: TModuleInfo;
begin
  { Middle aggregator should also inherit version }
  Registry := TModuleDiscoverer.DiscoverModules(
    GetFixturePath('nested-version-inherit'));
  try
    SubAgg := Registry.FindModuleByName('sub-agg');
    AssertNotNull('sub-agg should be discovered', SubAgg);
    AssertEquals('sub-agg should inherit version 4.0.0',
      '4.0.0', SubAgg.Config.Version);
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestNestedCycleDetection;
var
  Registry: TModuleRegistry;
  ExceptionRaised: Boolean;
begin
  { child-agg points back to root via ".." - should detect cycle }
  ExceptionRaised := False;
  Registry := nil;
  try
    Registry := TModuleDiscoverer.DiscoverModules(
      GetFixturePath('nested-cycle'));
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      AssertTrue('Error should mention circular or cycle',
        (Pos('circular', LowerCase(E.Message)) > 0) or
        (Pos('cycle', LowerCase(E.Message)) > 0));
    end;
  end;

  AssertTrue('Circular aggregator reference should raise exception',
    ExceptionRaised);
  if Assigned(Registry) then
    Registry.Free;
end;

procedure TTestNestedDiscovery.TestNestedWithCrosslevelDependencies;
var
  Registry: TModuleRegistry;
  DemoApp: TModuleInfo;
begin
  { demo-app (nested under examples/) depends on lib-core (at root level) }
  Registry := TModuleDiscoverer.DiscoverModules(
    GetFixturePath('nested-with-deps'));
  try
    DemoApp := Registry.FindModuleByName('demo-app');
    AssertNotNull('demo-app should be discovered', DemoApp);
    AssertEquals('demo-app should have 1 dependency',
      1, DemoApp.Dependencies.Count);
    AssertEquals('demo-app should depend on lib-core',
      'lib-core', DemoApp.Dependencies[0]);
  finally
    Registry.Free;
  end;
end;

procedure TTestNestedDiscovery.TestNestedBuildOrderWithDependencies;
var
  Registry: TModuleRegistry;
  BuildOrder: TList;
  LibCoreIdx, DemoAppIdx: Integer;
  I: Integer;
begin
  { Build order should place lib-core before demo-app }
  Registry := TModuleDiscoverer.DiscoverModules(
    GetFixturePath('nested-with-deps'));
  try
    BuildOrder := Registry.GetBuildOrder;
    try
      LibCoreIdx := -1;
      DemoAppIdx := -1;
      for I := 0 to BuildOrder.Count - 1 do
      begin
        if TModuleInfo(BuildOrder[I]).Name = 'lib-core' then
          LibCoreIdx := I;
        if TModuleInfo(BuildOrder[I]).Name = 'demo-app' then
          DemoAppIdx := I;
      end;

      AssertTrue('lib-core should be in build order', LibCoreIdx >= 0);
      AssertTrue('demo-app should be in build order', DemoAppIdx >= 0);
      AssertTrue('lib-core should come before demo-app in build order',
        LibCoreIdx < DemoAppIdx);
    finally
      BuildOrder.Free;
    end;
  finally
    Registry.Free;
  end;
end;

initialization
  RegisterTest(TTestNestedDiscovery);

end.
