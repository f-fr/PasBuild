{
  pasbuild-hello — Example PasBuild plugin (Pascal version)

  Demonstrates the external plugin contract using Object Pascal.
  Compile with: fpc pasbuild-hello.pas
  Install by copying the binary to ~/.pasbuild/plugins/ or adding to PATH.
}

program pasbuild_hello;

{$mode objfpc}{$H+}

uses
  SysUtils;

begin
  // Phase declaration: respond to --pasbuild-phase
  if (ParamCount >= 1) and (ParamStr(1) = '--pasbuild-phase') then
  begin
    WriteLn('after:compile');
    Halt(0);
  end;

  WriteLn('[hello] Hello from PasBuild plugin! (Pascal version)');
  WriteLn('[hello] Project directory: ', GetEnvironmentVariable('PASBUILD_PROJECT_DIR'));
  WriteLn('[hello] Project file: ', GetEnvironmentVariable('PASBUILD_PROJECT_FILE'));
  WriteLn('[hello] Active profiles: ', GetEnvironmentVariable('PASBUILD_PROFILES'));
  WriteLn('[hello] Verbose: ', GetEnvironmentVariable('PASBUILD_VERBOSE'));
  WriteLn;
  WriteLn('[hello] Tip: run ''pasbuild resolve'' from the project directory');
  WriteLn('[hello] to get the full resolved build configuration as JSON.');

  Halt(0);
end.
