program PasPdfTests;

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  Forms,
  DUnitTestRunner,
  TestsPasPdf in 'TestsPasPdf.pas',
  PasPdf in '..\Source\PasPdf.pas',
  PasPdfFileElements in '..\Source\PasPdfFileElements.pas',
  PasPdfStrings in '..\Source\PasPdfStrings.pas';

{$R *.RES}

begin
  Application.Title := 'PasPDF Tests';
  DUnitTestRunner.RunRegisteredTests;
end.


