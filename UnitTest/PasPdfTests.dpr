program PasPdfTests;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  TestsPasPdf in 'TestsPasPdf.pas',
  PasPdf in '..\Source\PasPdf.pas';

{$R *.RES}

begin
  DUnitTestRunner.RunRegisteredTests;
end.


