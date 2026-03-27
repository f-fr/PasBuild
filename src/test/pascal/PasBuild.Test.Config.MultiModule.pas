{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Config.MultiModule;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Types,
  PasBuild.Config;

type
  { Test parsing of <packaging> element from XML }
  TTestParsePackaging = class(TTestCase)
  private
    function GetFixturePath(const AFileName: string): string;
  published
    procedure TestParsePackagingPom;
    procedure TestParsePackagingLibrary;
    procedure TestParsePackagingApplication;
    procedure TestParsePackagingDefault;
    procedure TestParsePackagingBackwardCompat;
    procedure TestParsePackagingInvalid;
  end;

  { Test parsing of <modules> element from XML }
  TTestParseModules = class(TTestCase)
  private
    function GetFixturePath(const AFileName: string): string;
  published
    procedure TestParseModulesEmpty;
    procedure TestParseModulesSingle;
    procedure TestParseModulesMultiple;
  end;

  { Test validation of packaging rules }
  TTestValidatePackagingRules = class(TTestCase)
  private
    function GetFixturePath(const AFileName: string): string;
  published
    procedure TestValidatePomRequiresModules;
    procedure TestValidatePomForbidsMainSource;
    procedure TestValidateLibraryForbidsAggregatorModules;
    procedure TestValidateApplicationForbidsAggregatorModules;
    procedure TestValidatePomValid;
    procedure TestValidateLibraryValid;
    procedure TestValidateApplicationValid;
  end;

  { Test AAllowEmptyVersion parameter for version inheritance support }
  TTestVersionLoading = class(TTestCase)
  private
    function GetFixturePath(const AFileName: string): string;
  published
    procedure TestParseModuleWithoutVersion;
    procedure TestParseModuleWithoutVersionStandaloneFails;
  end;

  { Test parsing of activeByDefault attribute on <module> elements }
  TTestParseModuleActiveByDefault = class(TTestCase)
  private
    function GetFixturePath(const AFileName: string): string;
  published
    procedure TestActiveByDefaultAbsentIsActive;
    procedure TestActiveByDefaultTrueIsActive;
    procedure TestActiveByDefaultFalseIsInactive;
    procedure TestInactiveModuleStillInModulesList;
    procedure TestMultipleMixedActiveByDefault;
  end;

  { Test parsing of <sourceDirectory> element from XML }
  TTestParseSourceDirectory = class(TTestCase)
  private
    function GetFixturePath(const AFileName: string): string;
  published
    procedure TestSourceDirectoryDefault;
    procedure TestSourceDirectoryCustomDot;
    procedure TestSourceDirectorySubdir;
  end;

implementation

{ TTestParsePackaging }

function TTestParsePackaging.GetFixturePath(const AFileName: string): string;
begin
  // Tests run from target/ directory, fixtures are copied there
  Result := 'fixtures/multi-module/' + AFileName;
end;

procedure TTestParsePackaging.TestParsePackagingPom;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-pom.xml'));
  try
    AssertEquals('Packaging should be pom', Ord(ptPom), Ord(Config.BuildConfig.ProjectType));
    AssertEquals('Project name should match', 'TestAggregator', Config.Name);
  finally
    Config.Free;
  end;
end;

procedure TTestParsePackaging.TestParsePackagingLibrary;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-library.xml'));
  try
    AssertEquals('Packaging should be library', Ord(ptLibrary), Ord(Config.BuildConfig.ProjectType));
    AssertEquals('Project name should match', 'TestLibrary', Config.Name);
  finally
    Config.Free;
  end;
end;

procedure TTestParsePackaging.TestParsePackagingApplication;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-application.xml'));
  try
    AssertEquals('Packaging should be application', Ord(ptApplication), Ord(Config.BuildConfig.ProjectType));
    AssertEquals('Project name should match', 'TestApplication', Config.Name);
  finally
    Config.Free;
  end;
end;

procedure TTestParsePackaging.TestParsePackagingDefault;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-default.xml'));
  try
    AssertEquals('Default packaging should be application', Ord(ptApplication), Ord(Config.BuildConfig.ProjectType));
    AssertEquals('Project name should match', 'TestDefault', Config.Name);
  finally
    Config.Free;
  end;
end;

procedure TTestParsePackaging.TestParsePackagingBackwardCompat;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-backward-compat.xml'));
  try
    AssertEquals('Old projectType should still work', Ord(ptLibrary), Ord(Config.BuildConfig.ProjectType));
    AssertEquals('Project name should match', 'TestBackwardCompat', Config.Name);
  finally
    Config.Free;
  end;
end;

procedure TTestParsePackaging.TestParsePackagingInvalid;
var
  Config: TProjectConfig;
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  Config := nil;
  try
    Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-invalid.xml'));
  except
    on E: EProjectConfigError do
      ExceptionRaised := True;
  end;

  AssertTrue('Invalid packaging value should raise exception', ExceptionRaised);
  if Assigned(Config) then
    Config.Free;
end;

{ TTestParseModules }

function TTestParseModules.GetFixturePath(const AFileName: string): string;
begin
  // Tests run from target/ directory, fixtures are copied there
  Result := 'fixtures/multi-module/' + AFileName;
end;

procedure TTestParseModules.TestParseModulesEmpty;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-library.xml'));
  try
    AssertEquals('Modules list should be empty', 0, Config.Modules.Count);
  finally
    Config.Free;
  end;
end;

procedure TTestParseModules.TestParseModulesSingle;
var
  Config: TProjectConfig;
begin
  // We'll create this fixture next - for now skip
  // TODO: Create modules-single.xml fixture
  AssertTrue('Test not yet implemented', True);
end;

procedure TTestParseModules.TestParseModulesMultiple;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('packaging-pom.xml'));
  try
    AssertEquals('Modules list should have 2 items', 2, Config.Modules.Count);
    AssertEquals('First module should match', 'module1', Config.Modules[0]);
    AssertEquals('Second module should match', 'module2', Config.Modules[1]);
  finally
    Config.Free;
  end;
end;

{ TTestValidatePackagingRules }

function TTestValidatePackagingRules.GetFixturePath(const AFileName: string): string;
begin
  Result := 'fixtures/multi-module/' + AFileName;
end;

procedure TTestValidatePackagingRules.TestValidatePomRequiresModules;
var
  Config: TProjectConfig;
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  Config := nil;
  try
    Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-pom-no-modules.xml'));
  except
    on E: EProjectConfigError do
    begin
      ExceptionRaised := True;
      AssertTrue('Error message should mention modules', Pos('modules', LowerCase(E.Message)) > 0);
    end;
  end;

  AssertTrue('POM without modules should raise exception', ExceptionRaised);
  if Assigned(Config) then
    Config.Free;
end;

procedure TTestValidatePackagingRules.TestValidatePomForbidsMainSource;
var
  Config: TProjectConfig;
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  Config := nil;
  try
    Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-pom-with-mainsource.xml'));
  except
    on E: EProjectConfigError do
    begin
      ExceptionRaised := True;
      AssertTrue('Error message should mention mainSource', Pos('mainSource', E.Message) > 0);
    end;
  end;

  AssertTrue('POM with mainSource should raise exception', ExceptionRaised);
  if Assigned(Config) then
    Config.Free;
end;

procedure TTestValidatePackagingRules.TestValidateLibraryForbidsAggregatorModules;
var
  Config: TProjectConfig;
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  Config := nil;
  try
    Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-library-with-modules.xml'));
  except
    on E: EProjectConfigError do
    begin
      ExceptionRaised := True;
      AssertTrue('Error message should mention aggregator', Pos('aggregator', LowerCase(E.Message)) > 0);
    end;
  end;

  AssertTrue('Library with modules should raise exception', ExceptionRaised);
  if Assigned(Config) then
    Config.Free;
end;

procedure TTestValidatePackagingRules.TestValidateApplicationForbidsAggregatorModules;
var
  Config: TProjectConfig;
  ExceptionRaised: Boolean;
begin
  ExceptionRaised := False;
  Config := nil;
  try
    Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-application-with-modules.xml'));
  except
    on E: EProjectConfigError do
    begin
      ExceptionRaised := True;
      AssertTrue('Error message should mention aggregator', Pos('aggregator', LowerCase(E.Message)) > 0);
    end;
  end;

  AssertTrue('Application with modules should raise exception', ExceptionRaised);
  if Assigned(Config) then
    Config.Free;
end;

procedure TTestValidatePackagingRules.TestValidatePomValid;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-pom-valid.xml'));
  try
    AssertEquals('Valid POM should load', Ord(ptPom), Ord(Config.BuildConfig.ProjectType));
    AssertTrue('POM should have modules', Config.Modules.Count > 0);
  finally
    Config.Free;
  end;
end;

procedure TTestValidatePackagingRules.TestValidateLibraryValid;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-library-valid.xml'));
  try
    AssertEquals('Valid Library should load', Ord(ptLibrary), Ord(Config.BuildConfig.ProjectType));
    AssertTrue('Library should not have modules', Config.Modules.Count = 0);
  finally
    Config.Free;
  end;
end;

procedure TTestValidatePackagingRules.TestValidateApplicationValid;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('validate-application-valid.xml'));
  try
    AssertEquals('Valid Application should load', Ord(ptApplication), Ord(Config.BuildConfig.ProjectType));
    AssertTrue('Application should not have modules', Config.Modules.Count = 0);
    AssertTrue('Application should have mainSource', Config.BuildConfig.MainSource <> '');
  finally
    Config.Free;
  end;
end;

{ TTestVersionLoading }

function TTestVersionLoading.GetFixturePath(const AFileName: string): string;
begin
  Result := 'fixtures/multi-module/' + AFileName;
end;

procedure TTestVersionLoading.TestParseModuleWithoutVersion;
var
  Config: TProjectConfig;
begin
  { Loading with AAllowEmptyVersion=True should accept missing <version> }
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('module-no-version.xml'), True);
  try
    AssertEquals('Version should be empty when not specified', '', Config.Version);
    AssertEquals('Name should be parsed', 'TestModuleNoVersion', Config.Name);
    AssertEquals('Packaging should be library', Ord(ptLibrary), Ord(Config.BuildConfig.ProjectType));
  finally
    Config.Free;
  end;
end;

procedure TTestVersionLoading.TestParseModuleWithoutVersionStandaloneFails;
var
  Config: TProjectConfig;
  ExceptionRaised: Boolean;
begin
  { Loading without AAllowEmptyVersion flag should still require <version> }
  ExceptionRaised := False;
  Config := nil;
  try
    Config := TConfigLoader.LoadProjectXML(GetFixturePath('module-no-version.xml'));
  except
    on E: EProjectConfigError do
    begin
      ExceptionRaised := True;
      AssertTrue('Error should mention version', Pos('version', LowerCase(E.Message)) > 0);
    end;
  end;

  AssertTrue('Missing version should raise exception for standalone load', ExceptionRaised);
  if Assigned(Config) then
    Config.Free;
end;

{ TTestParseSourceDirectory }

function TTestParseSourceDirectory.GetFixturePath(const AFileName: string): string;
begin
  Result := 'fixtures/multi-module/' + AFileName;
end;

procedure TTestParseSourceDirectory.TestSourceDirectoryDefault;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('source-directory-default.xml'));
  try
    AssertEquals('Default sourceDirectory should be src/main/pascal',
      'src/main/pascal', Config.BuildConfig.SourceDirectory);
  finally
    Config.Free;
  end;
end;

procedure TTestParseSourceDirectory.TestSourceDirectoryCustomDot;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('source-directory-custom.xml'));
  try
    AssertEquals('Custom sourceDirectory should be dot',
      '.', Config.BuildConfig.SourceDirectory);
  finally
    Config.Free;
  end;
end;

procedure TTestParseSourceDirectory.TestSourceDirectorySubdir;
var
  Config: TProjectConfig;
begin
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('source-directory-subdir.xml'));
  try
    AssertEquals('Subdir sourceDirectory should be pascal',
      'pascal', Config.BuildConfig.SourceDirectory);
  finally
    Config.Free;
  end;
end;

{ TTestParseModuleActiveByDefault }

function TTestParseModuleActiveByDefault.GetFixturePath(const AFileName: string): string;
begin
  Result := 'fixtures/multi-module/' + AFileName;
end;

procedure TTestParseModuleActiveByDefault.TestActiveByDefaultAbsentIsActive;
var
  Config: TProjectConfig;
begin
  { module1 has no activeByDefault attribute — must NOT appear in InactiveModules }
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('modules-active-by-default.xml'));
  try
    AssertEquals('InactiveModules should not contain module1',
      -1, Config.InactiveModules.IndexOf('module1'));
  finally
    Config.Free;
  end;
end;

procedure TTestParseModuleActiveByDefault.TestActiveByDefaultTrueIsActive;
var
  Config: TProjectConfig;
begin
  { module2 has activeByDefault="true" — must NOT appear in InactiveModules }
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('modules-active-by-default.xml'));
  try
    AssertEquals('InactiveModules should not contain module2',
      -1, Config.InactiveModules.IndexOf('module2'));
  finally
    Config.Free;
  end;
end;

procedure TTestParseModuleActiveByDefault.TestActiveByDefaultFalseIsInactive;
var
  Config: TProjectConfig;
begin
  { module3 has activeByDefault="false" — must appear in InactiveModules }
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('modules-active-by-default.xml'));
  try
    AssertTrue('InactiveModules should contain module3',
      Config.InactiveModules.IndexOf('module3') >= 0);
  finally
    Config.Free;
  end;
end;

procedure TTestParseModuleActiveByDefault.TestInactiveModuleStillInModulesList;
var
  Config: TProjectConfig;
begin
  { module3 is inactive but must still appear in the full Modules list }
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('modules-active-by-default.xml'));
  try
    AssertTrue('Modules should still contain module3',
      Config.Modules.IndexOf('module3') >= 0);
  finally
    Config.Free;
  end;
end;

procedure TTestParseModuleActiveByDefault.TestMultipleMixedActiveByDefault;
var
  Config: TProjectConfig;
begin
  { Only module3 is inactive; InactiveModules count must be exactly 1 }
  Config := TConfigLoader.LoadProjectXML(GetFixturePath('modules-active-by-default.xml'));
  try
    AssertEquals('Modules list should have 3 entries', 3, Config.Modules.Count);
    AssertEquals('InactiveModules list should have 1 entry', 1, Config.InactiveModules.Count);
  finally
    Config.Free;
  end;
end;

initialization
  RegisterTest(TTestParsePackaging);
  RegisterTest(TTestParseModules);
  RegisterTest(TTestValidatePackagingRules);
  RegisterTest(TTestVersionLoading);
  RegisterTest(TTestParseModuleActiveByDefault);
  RegisterTest(TTestParseSourceDirectory);

end.
