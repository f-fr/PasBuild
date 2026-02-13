program Main;

{$mode objfpc}{$H+}

uses
  SysUtils,
  StringUtils;  // From string-utils dependency

var
  Name, Greeting: string;
begin
  Name := 'PasBuild';
  Greeting := RepeatString('Hello, ' + Name + '! ', 3);
  WriteLn(Greeting);
  WriteLn('Reversed: ', ReverseString(Name));
  WriteLn('Is "racecar" a palindrome? ', IsPalindrome('racecar'));
  WriteLn('Is "hello" a palindrome? ', IsPalindrome('hello'));
end.
