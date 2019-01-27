program CommandLine;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  PasPdf in '..\Source\PasPdf.pas',
  PasPdfFileElements in '..\Source\PasPdfFileElements.pas',
  PasPdfStrings in '..\Source\PasPdfStrings.pas';

begin
  try
    with TPdfFile.Create do
    try
      LoadFromFile('..\Common\Simple.pdf');
    finally
      Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

