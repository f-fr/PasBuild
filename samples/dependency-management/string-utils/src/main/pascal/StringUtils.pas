unit StringUtils;

{$mode objfpc}{$H+}

interface

{ Reverse a string }
function ReverseString(const S: string): string;

{ Repeat a string N times }
function RepeatString(const S: string; Count: Integer): string;

{ Check if a string is a palindrome }
function IsPalindrome(const S: string): Boolean;

implementation

uses
  SysUtils;

function ReverseString(const S: string): string;
var
  I, Len: Integer;
begin
  Len := Length(S);
  SetLength(Result, Len);
  for I := 1 to Len do
    Result[I] := S[Len - I + 1];
end;

function RepeatString(const S: string; Count: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Count do
    Result := Result + S;
end;

function IsPalindrome(const S: string): Boolean;
begin
  Result := LowerCase(S) = LowerCase(ReverseString(S));
end;

end.
