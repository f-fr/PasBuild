{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Test.Bootstrap;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  PasBuild.Bootstrap;

type
  { Test TBootstrapGenerator.ParseUnitName }
  TTestParseUnitName = class(TTestCase)
  private
    FTempDir: string;
    function CreateTempFile(const AFileName, AContent: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestStandardSingleLine;
    procedure TestMultiLineUnitDeclaration;
    procedure TestMultiLineWithLeadingComments;
    procedure TestBraceCommentBeforeUnit;
    procedure TestParenCommentBeforeUnit;
    procedure TestLineCommentBeforeUnit;
    procedure TestDottedUnitName;
    procedure TestDottedUnitNameMultiLine;
    procedure TestNonExistentFile;
    procedure TestEmptyFile;
    procedure TestFileWithOnlyComments;
    procedure TestMultiLineBraceCommentThenUnit;
    procedure TestUnitKeywordInComment;
    procedure TestUnitWithTrailingSpaces;
    procedure TestUnitWithLeadingSpaces;
    procedure TestUnitWithLeadingAndTrailingSpaces;
    procedure TestUnitWithTrailingSpacesMultiLine;
  end;

implementation

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

{ TTestParseUnitName }

procedure TTestParseUnitName.SetUp;
begin
  FTempDir := IncludeTrailingPathDelimiter(GetTempDir) + 'pasbuild-test-bootstrap-' + IntToStr(GetProcessID);
  ForceDirectories(FTempDir);
end;

procedure TTestParseUnitName.TearDown;
begin
  RemoveDir(FTempDir);
end;

function TTestParseUnitName.CreateTempFile(const AFileName, AContent: string): string;
var
  F: TextFile;
begin
  Result := IncludeTrailingPathDelimiter(FTempDir) + AFileName;
  AssignFile(F, Result);
  Rewrite(F);
  Write(F, AContent);
  CloseFile(F);
end;

procedure TTestParseUnitName.TestStandardSingleLine;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('MyUnit.pas',
    'unit MyUnit;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('MyUnit', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestMultiLineUnitDeclaration;
var
  FilePath: string;
begin
  // This is the aggpas pattern: "unit" on one line, name on the next
  FilePath := CreateTempFile('agg_arrowhead.pas',
    'unit' + LineEnding +
    '  agg_arrowhead;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('agg_arrowhead', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestMultiLineWithLeadingComments;
var
  FilePath: string;
begin
  // Comment block followed by multi-line unit declaration
  FilePath := CreateTempFile('agg_basics.pas',
    '{ AggPas graphics library }' + LineEnding +
    '{ Copyright (c) 2006 }' + LineEnding +
    '' + LineEnding +
    'unit' + LineEnding +
    '  agg_basics;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('agg_basics', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestBraceCommentBeforeUnit;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('Commented.pas',
    '{' + LineEnding +
    '  Multi-line brace comment' + LineEnding +
    '  spanning several lines' + LineEnding +
    '}' + LineEnding +
    'unit Commented;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('Commented', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestParenCommentBeforeUnit;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('ParenComment.pas',
    '(*' + LineEnding +
    '  Old-style comment' + LineEnding +
    '*)' + LineEnding +
    'unit ParenComment;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('ParenComment', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestLineCommentBeforeUnit;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('LineComment.pas',
    '// This is a line comment' + LineEnding +
    '// Another line comment' + LineEnding +
    'unit LineComment;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('LineComment', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestDottedUnitName;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('PasBuild.Utils.pas',
    'unit PasBuild.Utils;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('PasBuild.Utils', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestDottedUnitNameMultiLine;
var
  FilePath: string;
begin
  // Dotted name with multi-line declaration
  FilePath := CreateTempFile('My.Dotted.Unit.pas',
    'unit' + LineEnding +
    '  My.Dotted.Unit;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('My.Dotted.Unit', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestNonExistentFile;
begin
  AssertEquals('', TBootstrapGenerator.ParseUnitName('/tmp/does-not-exist-12345.pas'));
end;

procedure TTestParseUnitName.TestEmptyFile;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('Empty.pas', '');
  AssertEquals('', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestFileWithOnlyComments;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('OnlyComments.pas',
    '{ Just a comment }' + LineEnding +
    '// Another comment' + LineEnding +
    '(* And another *)' + LineEnding);

  AssertEquals('', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestMultiLineBraceCommentThenUnit;
var
  FilePath: string;
begin
  // Multi-line brace comment followed by multi-line unit declaration
  FilePath := CreateTempFile('agg_color.pas',
    '{' + LineEnding +
    '  AggPas 2.4 RM3' + LineEnding +
    '  Copyright (c) 2006' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    'unit' + LineEnding +
    '  agg_color;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('agg_color', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestUnitKeywordInComment;
var
  FilePath: string;
begin
  // The word "unit" appears in a comment — should not be picked up
  FilePath := CreateTempFile('Tricky.pas',
    '{ This unit provides utility functions }' + LineEnding +
    'unit Tricky;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('Tricky', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestUnitWithTrailingSpaces;
var
  FilePath: string;
begin
  // "unit  " with trailing spaces — should be treated as standalone keyword
  FilePath := CreateTempFile('TrailingSpaces.pas',
    'unit  ' + LineEnding +
    '  TrailingSpaces;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('TrailingSpaces', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestUnitWithLeadingSpaces;
var
  FilePath: string;
begin
  // "  unit MyUnit;" with leading spaces
  FilePath := CreateTempFile('LeadingSpaces.pas',
    '  unit LeadingSpaces;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('LeadingSpaces', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestUnitWithLeadingAndTrailingSpaces;
var
  FilePath: string;
begin
  // "  unit  MyUnit;  " with spaces everywhere
  FilePath := CreateTempFile('Spaces.pas',
    '  unit  Spaces;  ' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('Spaces', TBootstrapGenerator.ParseUnitName(FilePath));
end;

procedure TTestParseUnitName.TestUnitWithTrailingSpacesMultiLine;
var
  FilePath: string;
begin
  // "  unit  " (with leading and trailing spaces) then name on next line
  FilePath := CreateTempFile('SpacesMultiLine.pas',
    '  unit  ' + LineEnding +
    '  SpacesMultiLine;' + LineEnding +
    '' + LineEnding +
    'interface' + LineEnding +
    '' + LineEnding +
    'implementation' + LineEnding +
    '' + LineEnding +
    'end.' + LineEnding);

  AssertEquals('SpacesMultiLine', TBootstrapGenerator.ParseUnitName(FilePath));
end;

initialization
  RegisterTest(TTestParseUnitName);

end.
