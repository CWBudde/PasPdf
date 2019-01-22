unit TestsPasPdf;

interface

uses
  TestFramework, Classes, SysUtils, PasPdf, Contnrs;

type
  // Testmethoden für Klasse TPdfFile

  TestTPdfFile = class(TTestCase)
  strict private
    FPdfFile: TPdfFile;
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLoadSimpleFile;
    procedure TestLoadLibreOffice;
    procedure TestLoadPDFA;
    procedure TestLoadTextString;
    procedure TestCanLoad;
  end;

implementation

procedure TestTPdfFile.SetUp;
begin
  FPdfFile := TPdfFile.Create;
end;

procedure TestTPdfFile.TearDown;
begin
  FPdfFile.Free;
  FPdfFile := nil;
end;

procedure TestTPdfFile.TestLoadSimpleFile;
begin
  FPdfFile.LoadFromFile('Simple.pdf');
end;

procedure TestTPdfFile.TestLoadLibreOffice;
begin
  FPdfFile.LoadFromFile('LibreOffice.pdf');
end;

procedure TestTPdfFile.TestLoadPDFA;
begin
  FPdfFile.LoadFromFile('PDFA.pdf');
end;

procedure TestTPdfFile.TestLoadTextString;
begin
  FPdfFile.LoadFromFile('TextString.pdf');
end;

procedure TestTPdfFile.TestCanLoad;
begin
  CheckTrue(FPdfFile.CanLoad('Simple.pdf'));
  CheckTrue(FPdfFile.CanLoad('LibreOffice.pdf'));
  CheckTrue(FPdfFile.CanLoad('PDFA.pdf'));
  CheckTrue(FPdfFile.CanLoad('TextString.pdf'));
end;

initialization
  RegisterTest(TestTPdfFile.Suite);

end.


