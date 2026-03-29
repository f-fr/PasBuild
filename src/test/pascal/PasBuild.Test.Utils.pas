{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Utils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.CLI,
  PasBuild.Utils;

type
  { Test TUtils.QuotePath }
  TTestQuotePath = class(TTestCase)
  published
    procedure TestPathWithoutSpaces;
    procedure TestPathWithSpaces;
    procedure TestEmptyPath;
    procedure TestPathWithTrailingSeparator;
    procedure TestPathWithMultipleSpaces;
  end;

  { Test TUtils.GetFPCExecutable / SetFPCExecutable }
  TTestFPCExecutable = class(TTestCase)
  protected
    procedure TearDown; override;
  published
    procedure TestDefaultReturnsFpc;
    procedure TestSetCustomPath;
    procedure TestSetAbsolutePath;
    procedure TestResetToDefault;
    procedure TestCustomFPCUsedByIsFPCAvailable;
  end;

  { Test TCommandLineArgs.FPCExecutable field }
  TTestCLIFPCExecutable = class(TTestCase)
  published
    procedure TestFPCExecutableFieldExists;
    procedure TestFPCExecutableDefaultEmpty;
    procedure TestFPCExecutableStoresPath;
  end;

  { Test TUtils.XmlEscapeText }
  TTestXmlEscapeText = class(TTestCase)
  published
    procedure TestPlainText;
    procedure TestAmpersand;
    procedure TestLessThan;
    procedure TestGreaterThan;
    procedure TestAllSpecialChars;
    procedure TestEmptyString;
    procedure TestAuthorWithEmail;
    procedure TestDoubleAmpersand;
  end;

  { Test FPC target detection utilities }
  TTestFPCTargetDetection = class(TTestCase)
  published
    procedure TestDetectTargetCPU;
    procedure TestDetectTargetOS;
    procedure TestGetTargetTriplet;
    procedure TestTargetTripletFormat;
    procedure TestGetPackagePlatformSuffixNotEmpty;
    procedure TestGetPackagePlatformSuffixTwoComponents;
    procedure TestGetPackagePlatformSuffixNoFPCVersion;
    procedure TestGetPackagePlatformSuffixMatchesTriplet;
  end;

implementation

{ TTestQuotePath }

procedure TTestQuotePath.TestPathWithoutSpaces;
begin
  AssertEquals('Path without spaces should be unchanged',
    '/home/user/.pasbuild/repository',
    TUtils.QuotePath('/home/user/.pasbuild/repository'));
end;

procedure TTestQuotePath.TestPathWithSpaces;
var
  Quoted: string;
begin
  Quoted := TUtils.QuotePath('/home/John Smith/.pasbuild/repository');
  AssertEquals('Path with spaces should be wrapped in double quotes',
    '"/home/John Smith/.pasbuild/repository"',
    Quoted);
end;

procedure TTestQuotePath.TestEmptyPath;
begin
  AssertEquals('Empty path should remain empty', '', TUtils.QuotePath(''));
end;

procedure TTestQuotePath.TestPathWithTrailingSeparator;
begin
  AssertEquals('Path with spaces and trailing separator should be quoted',
    '"/home/John Smith/projects/"',
    TUtils.QuotePath('/home/John Smith/projects/'));
end;

procedure TTestQuotePath.TestPathWithMultipleSpaces;
begin
  AssertEquals('Path with multiple spaces should be quoted',
    '"/home/My User/My Projects/build output"',
    TUtils.QuotePath('/home/My User/My Projects/build output'));
end;

{ TTestFPCExecutable }

procedure TTestFPCExecutable.TearDown;
begin
  { Reset to default after each test to avoid leaking state }
  TUtils.SetFPCExecutable('');
end;

procedure TTestFPCExecutable.TestDefaultReturnsFpc;
begin
  AssertEquals('Default FPC executable should be fpc',
    'fpc', TUtils.GetFPCExecutable);
end;

procedure TTestFPCExecutable.TestSetCustomPath;
begin
  TUtils.SetFPCExecutable('fpc-ootb');
  AssertEquals('Custom FPC executable should be returned',
    'fpc-ootb', TUtils.GetFPCExecutable);
end;

procedure TTestFPCExecutable.TestSetAbsolutePath;
begin
  TUtils.SetFPCExecutable('/opt/fpc-3.3.1/bin/fpc');
  AssertEquals('Absolute path should be returned',
    '/opt/fpc-3.3.1/bin/fpc', TUtils.GetFPCExecutable);
end;

procedure TTestFPCExecutable.TestResetToDefault;
begin
  TUtils.SetFPCExecutable('/custom/fpc');
  AssertEquals('Custom path should be active',
    '/custom/fpc', TUtils.GetFPCExecutable);

  TUtils.SetFPCExecutable('');
  AssertEquals('After reset, should return default fpc',
    'fpc', TUtils.GetFPCExecutable);
end;

procedure TTestFPCExecutable.TestCustomFPCUsedByIsFPCAvailable;
begin
  { Setting a nonexistent FPC should cause IsFPCAvailable to return False }
  TUtils.SetFPCExecutable('nonexistent-fpc-binary-that-does-not-exist');
  AssertFalse('IsFPCAvailable should return False for nonexistent binary',
    TUtils.IsFPCAvailable);
end;

{ TTestCLIFPCExecutable }

procedure TTestCLIFPCExecutable.TestFPCExecutableFieldExists;
var
  Args: TCommandLineArgs;
begin
  Args.ProfileIds := TStringList.Create;
  try
    Args.FPCExecutable := '/usr/bin/fpc';
    AssertEquals('FPCExecutable field should be settable',
      '/usr/bin/fpc', Args.FPCExecutable);
  finally
    Args.ProfileIds.Free;
  end;
end;

procedure TTestCLIFPCExecutable.TestFPCExecutableDefaultEmpty;
var
  Args: TCommandLineArgs;
begin
  Args.ProfileIds := TStringList.Create;
  try
    Args.FPCExecutable := '';
    AssertEquals('FPCExecutable should default to empty string',
      '', Args.FPCExecutable);
  finally
    Args.ProfileIds.Free;
  end;
end;

procedure TTestCLIFPCExecutable.TestFPCExecutableStoresPath;
var
  Args: TCommandLineArgs;
begin
  Args.ProfileIds := TStringList.Create;
  try
    Args.FPCExecutable := '/opt/fpc-3.3.1/bin/fpc';
    AssertEquals('Absolute path should be stored',
      '/opt/fpc-3.3.1/bin/fpc', Args.FPCExecutable);

    Args.FPCExecutable := 'fpc-ootb';
    AssertEquals('Simple name should be stored',
      'fpc-ootb', Args.FPCExecutable);
  finally
    Args.ProfileIds.Free;
  end;
end;

{ TTestFPCTargetDetection }

procedure TTestFPCTargetDetection.TestDetectTargetCPU;
var
  CPU: string;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  CPU := TUtils.DetectTargetCPU;
  AssertTrue('Target CPU should not be empty', CPU <> '');
  AssertTrue('Target CPU should not be error value', CPU <> 'Unknown');
end;

procedure TTestFPCTargetDetection.TestDetectTargetOS;
var
  OS: string;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  OS := TUtils.DetectTargetOS;
  AssertTrue('Target OS should not be empty', OS <> '');
  AssertTrue('Target OS should not be error value', OS <> 'Unknown');
end;

procedure TTestFPCTargetDetection.TestGetTargetTriplet;
var
  Triplet: string;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  Triplet := TUtils.GetTargetTriplet;
  AssertTrue('Target triplet should not be empty', Triplet <> '');
  // Should contain exactly two hyphens (cpu-os-version)
  AssertTrue('Target triplet should contain at least two hyphens',
    (Pos('-', Triplet) > 0) and (Pos('-', Copy(Triplet, Pos('-', Triplet) + 1, MaxInt)) > 0));
end;

procedure TTestFPCTargetDetection.TestTargetTripletFormat;
var
  Triplet, CPU, OS, Version: string;
  FirstDash, SecondDash: Integer;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  Triplet := TUtils.GetTargetTriplet;

  // Parse the triplet
  FirstDash := Pos('-', Triplet);
  AssertTrue('First dash should exist', FirstDash > 0);
  CPU := Copy(Triplet, 1, FirstDash - 1);

  SecondDash := Pos('-', Copy(Triplet, FirstDash + 1, MaxInt));
  AssertTrue('Second dash should exist', SecondDash > 0);
  OS := Copy(Triplet, FirstDash + 1, SecondDash - 1);
  Version := Copy(Triplet, FirstDash + SecondDash + 1, MaxInt);

  AssertTrue('CPU component should not be empty', CPU <> '');
  AssertTrue('OS component should not be empty', OS <> '');
  AssertTrue('Version component should not be empty', Version <> '');

  // Version should match DetectFPCVersion
  AssertEquals('Version component should match DetectFPCVersion',
    TUtils.DetectFPCVersion, Version);
end;

{ TTestFPCTargetDetection — GetPackagePlatformSuffix }

procedure TTestFPCTargetDetection.TestGetPackagePlatformSuffixNotEmpty;
var
  Suffix: string;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  Suffix := TUtils.GetPackagePlatformSuffix;
  AssertTrue('Package platform suffix should not be empty', Suffix <> '');
end;

procedure TTestFPCTargetDetection.TestGetPackagePlatformSuffixTwoComponents;
var
  Suffix: string;
  DashPos: Integer;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  Suffix := TUtils.GetPackagePlatformSuffix;
  DashPos := Pos('-', Suffix);
  AssertTrue('Suffix should contain a hyphen separating cpu and os', DashPos > 0);
  AssertTrue('cpu component should not be empty', DashPos > 1);
  AssertTrue('os component should not be empty', Length(Suffix) > DashPos);
  // Exactly one hyphen: no second hyphen after the first
  AssertEquals('Suffix should have exactly one hyphen (cpu-os, no fpc version)',
    0, Pos('-', Copy(Suffix, DashPos + 1, MaxInt)));
end;

procedure TTestFPCTargetDetection.TestGetPackagePlatformSuffixNoFPCVersion;
var
  Suffix, FPCVersion: string;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  Suffix := TUtils.GetPackagePlatformSuffix;
  FPCVersion := TUtils.DetectFPCVersion;
  AssertEquals('Package suffix must not contain the FPC version',
    0, Pos(FPCVersion, Suffix));
end;

procedure TTestFPCTargetDetection.TestGetPackagePlatformSuffixMatchesTriplet;
var
  Suffix, Triplet, CPU, OS: string;
  FirstDash: Integer;
begin
  if not TUtils.IsFPCAvailable then
  begin
    Ignore('FPC not available');
    Exit;
  end;
  Suffix := TUtils.GetPackagePlatformSuffix;
  Triplet := TUtils.GetTargetTriplet;

  // Extract cpu and os from triplet (format: cpu-os-fpcversion)
  FirstDash := Pos('-', Triplet);
  CPU := Copy(Triplet, 1, FirstDash - 1);
  OS  := Copy(Triplet, FirstDash + 1, Pos('-', Copy(Triplet, FirstDash + 1, MaxInt)) - 1);

  AssertEquals('Package suffix should equal cpu-os from the full triplet',
    CPU + '-' + OS, Suffix);
end;

{ TTestXmlEscapeText }

procedure TTestXmlEscapeText.TestPlainText;
begin
  AssertEquals('Plain text should be unchanged',
    'Hello World', TUtils.XmlEscapeText('Hello World'));
end;

procedure TTestXmlEscapeText.TestAmpersand;
begin
  AssertEquals('Ampersand should be escaped',
    'Smith &amp; Co', TUtils.XmlEscapeText('Smith & Co'));
end;

procedure TTestXmlEscapeText.TestLessThan;
begin
  AssertEquals('Less-than should be escaped',
    'a &lt; b', TUtils.XmlEscapeText('a < b'));
end;

procedure TTestXmlEscapeText.TestGreaterThan;
begin
  AssertEquals('Greater-than should be escaped',
    'a &gt; b', TUtils.XmlEscapeText('a > b'));
end;

procedure TTestXmlEscapeText.TestAllSpecialChars;
begin
  AssertEquals('All special chars should be escaped',
    '&amp; &lt; &gt;', TUtils.XmlEscapeText('& < >'));
end;

procedure TTestXmlEscapeText.TestEmptyString;
begin
  AssertEquals('Empty string should remain empty',
    '', TUtils.XmlEscapeText(''));
end;

procedure TTestXmlEscapeText.TestAuthorWithEmail;
begin
  AssertEquals('Author with email angle brackets should be escaped',
    'John Doe &lt;john@example.org&gt;',
    TUtils.XmlEscapeText('John Doe <john@example.org>'));
end;

procedure TTestXmlEscapeText.TestDoubleAmpersand;
begin
  AssertEquals('Multiple ampersands should each be escaped',
    'A &amp;&amp; B', TUtils.XmlEscapeText('A && B'));
end;

initialization
  RegisterTest(TTestQuotePath);
  RegisterTest(TTestFPCExecutable);
  RegisterTest(TTestCLIFPCExecutable);
  RegisterTest(TTestXmlEscapeText);
  RegisterTest(TTestFPCTargetDetection);

end.
