{
  This file is part of PasBuild.

  Copyright (c) 2025 Graeme Geldenhuys <graemeg@gmail.com>

  SPDX-License-Identifier: BSD-3-Clause

  See LICENSE file in the project root for full license terms.
}

unit PasBuild.Repository;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, DOM, XMLRead, XMLWrite;

type
  { Dependency information stored in metadata }
  TMetadataDependency = record
    Name: string;
    Version: string;
  end;
  TMetadataDependencyArray = array of TMetadataDependency;

  { Artifact metadata read from/written to metadata.xml }
  TArtifactMetadata = class
  private
    FName: string;
    FVersion: string;
    FPackaging: string;
    FFPCVersion: string;
    FTargetCPU: string;
    FTargetOS: string;
    FTimestamp: string;
    FDependencies: TMetadataDependencyArray;
  public
    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property Packaging: string read FPackaging write FPackaging;
    property FPCVersion: string read FFPCVersion write FFPCVersion;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property TargetOS: string read FTargetOS write FTargetOS;
    property Timestamp: string read FTimestamp write FTimestamp;
    property Dependencies: TMetadataDependencyArray read FDependencies write FDependencies;
  end;

  { Local repository management }
  TLocalRepository = class
  public
    { Repository root directory }
    class function GetRepositoryRoot: string;

    { Path construction }
    class function GetArtifactPath(const AName, AVersion, ATriplet: string): string;
    class function GetUnitsPath(const AName, AVersion, ATriplet: string): string;
    class function GetMetadataPath(const AName, AVersion, ATriplet: string): string;

    { Repository queries }
    class function ArtifactExists(const AName, AVersion, ATriplet: string): Boolean;
    class function GetAvailableTargets(const AName, AVersion: string): TStringList;

    { Directory management }
    class procedure EnsureDirectoryStructure(const AName, AVersion, ATriplet: string);

    { Artifact installation }
    class procedure CopyUnitFiles(const ASourceUnitsDir, AName, AVersion, ATriplet: string);
    class function CountFiles(const ADirectory, APattern: string): Integer;

    { Metadata operations }
    class procedure WriteMetadata(const AName, AVersion, ATriplet: string; AMetadata: TArtifactMetadata);
    class function ReadMetadata(const AName, AVersion, ATriplet: string): TArtifactMetadata;
  end;

implementation

{ TLocalRepository }

class function TLocalRepository.GetRepositoryRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(GetUserDir) +
            '.pasbuild' + DirectorySeparator + 'repository';
end;

class function TLocalRepository.GetArtifactPath(const AName, AVersion, ATriplet: string): string;
begin
  Result := GetRepositoryRoot + DirectorySeparator +
            AName + DirectorySeparator +
            AVersion + DirectorySeparator +
            ATriplet;
end;

class function TLocalRepository.GetUnitsPath(const AName, AVersion, ATriplet: string): string;
begin
  Result := GetArtifactPath(AName, AVersion, ATriplet) + DirectorySeparator + 'units';
end;

class function TLocalRepository.GetMetadataPath(const AName, AVersion, ATriplet: string): string;
begin
  Result := GetArtifactPath(AName, AVersion, ATriplet) + DirectorySeparator + 'metadata.xml';
end;

class function TLocalRepository.ArtifactExists(const AName, AVersion, ATriplet: string): Boolean;
var
  ArtifactDir, MetadataFile: string;
begin
  ArtifactDir := GetArtifactPath(AName, AVersion, ATriplet);
  MetadataFile := GetMetadataPath(AName, AVersion, ATriplet);
  Result := DirectoryExists(ArtifactDir) and FileExists(MetadataFile);
end;

class function TLocalRepository.GetAvailableTargets(const AName, AVersion: string): TStringList;
var
  SearchRec: TSearchRec;
  VersionDir: string;
begin
  Result := TStringList.Create;
  Result.Sorted := True;

  VersionDir := GetRepositoryRoot + DirectorySeparator +
                AName + DirectorySeparator + AVersion;

  if not DirectoryExists(VersionDir) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(VersionDir) + '*', faDirectory, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and
           ((SearchRec.Attr and faDirectory) = faDirectory) then
          Result.Add(SearchRec.Name);
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

class procedure TLocalRepository.EnsureDirectoryStructure(const AName, AVersion, ATriplet: string);
var
  UnitsDir: string;
begin
  UnitsDir := GetUnitsPath(AName, AVersion, ATriplet);
  if not ForceDirectories(UnitsDir) then
    raise Exception.CreateFmt('Failed to create repository directory: %s', [UnitsDir]);
end;

class procedure TLocalRepository.CopyUnitFiles(const ASourceUnitsDir, AName, AVersion, ATriplet: string);
var
  SearchRec: TSearchRec;
  SourcePath, DestPath, DestDir: string;
  SourceStream, DestStream: TFileStream;
begin
  if not DirectoryExists(ASourceUnitsDir) then
    raise Exception.CreateFmt('Source units directory not found: %s', [ASourceUnitsDir]);

  DestDir := GetUnitsPath(AName, AVersion, ATriplet);

  if FindFirst(IncludeTrailingPathDelimiter(ASourceUnitsDir) + '*', faAnyFile, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Attr and faDirectory) = 0 then
        begin
          // Copy .ppu and .o files
          if AnsiEndsText('.ppu', SearchRec.Name) or
             AnsiEndsText('.o', SearchRec.Name) then
          begin
            SourcePath := IncludeTrailingPathDelimiter(ASourceUnitsDir) + SearchRec.Name;
            DestPath := IncludeTrailingPathDelimiter(DestDir) + SearchRec.Name;

            SourceStream := TFileStream.Create(SourcePath, fmOpenRead or fmShareDenyNone);
            try
              DestStream := TFileStream.Create(DestPath, fmCreate);
              try
                DestStream.CopyFrom(SourceStream, SourceStream.Size);
              finally
                DestStream.Free;
              end;
            finally
              SourceStream.Free;
            end;
          end;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

class function TLocalRepository.CountFiles(const ADirectory, APattern: string): Integer;
var
  SearchRec: TSearchRec;
begin
  Result := 0;
  if not DirectoryExists(ADirectory) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + APattern, faAnyFile, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Attr and faDirectory) = 0 then
          Inc(Result);
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

class procedure TLocalRepository.WriteMetadata(const AName, AVersion, ATriplet: string;
  AMetadata: TArtifactMetadata);
var
  Doc: TXMLDocument;
  RootNode, BuildNode, DepsNode, DepNode, ElemNode: TDOMNode;
  I: Integer;
  MetadataPath: string;
begin
  MetadataPath := GetMetadataPath(AName, AVersion, ATriplet);

  Doc := TXMLDocument.Create;
  try
    // Create root <artifact> element
    RootNode := Doc.CreateElement('artifact');
    Doc.AppendChild(RootNode);

    // Add identity elements
    ElemNode := Doc.CreateElement('name');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.Name));
    RootNode.AppendChild(ElemNode);

    ElemNode := Doc.CreateElement('version');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.Version));
    RootNode.AppendChild(ElemNode);

    ElemNode := Doc.CreateElement('packaging');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.Packaging));
    RootNode.AppendChild(ElemNode);

    // Add <build> section
    BuildNode := Doc.CreateElement('build');
    RootNode.AppendChild(BuildNode);

    ElemNode := Doc.CreateElement('fpcVersion');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.FPCVersion));
    BuildNode.AppendChild(ElemNode);

    ElemNode := Doc.CreateElement('targetCPU');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.TargetCPU));
    BuildNode.AppendChild(ElemNode);

    ElemNode := Doc.CreateElement('targetOS');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.TargetOS));
    BuildNode.AppendChild(ElemNode);

    ElemNode := Doc.CreateElement('timestamp');
    ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.Timestamp));
    BuildNode.AppendChild(ElemNode);

    // Add <dependencies> section
    DepsNode := Doc.CreateElement('dependencies');
    RootNode.AppendChild(DepsNode);

    for I := 0 to Length(AMetadata.Dependencies) - 1 do
    begin
      DepNode := Doc.CreateElement('dependency');
      DepsNode.AppendChild(DepNode);

      ElemNode := Doc.CreateElement('name');
      ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.Dependencies[I].Name));
      DepNode.AppendChild(ElemNode);

      ElemNode := Doc.CreateElement('version');
      ElemNode.AppendChild(Doc.CreateTextNode(AMetadata.Dependencies[I].Version));
      DepNode.AppendChild(ElemNode);
    end;

    // Write to file
    WriteXMLFile(Doc, MetadataPath);
  finally
    Doc.Free;
  end;
end;

class function TLocalRepository.ReadMetadata(const AName, AVersion, ATriplet: string): TArtifactMetadata;
var
  Doc: TXMLDocument;
  RootNode, BuildNode, DepsNode, DepNode, ChildNode: TDOMNode;
  MetadataPath: string;
  DepCount, I: Integer;

  function GetChildText(AParent: TDOMNode; const ATagName: string): string;
  var
    Node: TDOMNode;
  begin
    Result := '';
    if AParent = nil then
      Exit;
    Node := AParent.FindNode(ATagName);
    if (Node <> nil) and (Node.FirstChild <> nil) then
      Result := string(Node.FirstChild.NodeValue);
  end;

begin
  MetadataPath := GetMetadataPath(AName, AVersion, ATriplet);

  if not FileExists(MetadataPath) then
    raise Exception.CreateFmt('Metadata file not found: %s', [MetadataPath]);

  Result := TArtifactMetadata.Create;
  Doc := TXMLDocument.Create;
  try
    ReadXMLFile(Doc, MetadataPath);
    RootNode := Doc.DocumentElement;

    Result.Name := GetChildText(RootNode, 'name');
    Result.Version := GetChildText(RootNode, 'version');
    Result.Packaging := GetChildText(RootNode, 'packaging');

    // Parse <build> section
    BuildNode := RootNode.FindNode('build');
    if BuildNode <> nil then
    begin
      Result.FPCVersion := GetChildText(BuildNode, 'fpcVersion');
      Result.TargetCPU := GetChildText(BuildNode, 'targetCPU');
      Result.TargetOS := GetChildText(BuildNode, 'targetOS');
      Result.Timestamp := GetChildText(BuildNode, 'timestamp');
    end;

    // Parse <dependencies> section
    DepsNode := RootNode.FindNode('dependencies');
    if DepsNode <> nil then
    begin
      // Count dependency elements
      DepCount := 0;
      ChildNode := DepsNode.FirstChild;
      while ChildNode <> nil do
      begin
        if ChildNode.NodeName = 'dependency' then
          Inc(DepCount);
        ChildNode := ChildNode.NextSibling;
      end;

      SetLength(Result.FDependencies, DepCount);

      // Parse each dependency
      I := 0;
      ChildNode := DepsNode.FirstChild;
      while ChildNode <> nil do
      begin
        if ChildNode.NodeName = 'dependency' then
        begin
          Result.FDependencies[I].Name := GetChildText(ChildNode, 'name');
          Result.FDependencies[I].Version := GetChildText(ChildNode, 'version');
          Inc(I);
        end;
        ChildNode := ChildNode.NextSibling;
      end;
    end;
  finally
    Doc.Free;
  end;
end;

end.
