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
  FPdfFile.LoadFromFile('..\Common\Simple.pdf');
end;

procedure TestTPdfFile.TestLoadLibreOffice;
begin
  FPdfFile.LoadFromFile('..\Common\LibreOffice.pdf');
end;

procedure TestTPdfFile.TestLoadPDFA;
begin
  FPdfFile.LoadFromFile('..\Common\PDFA.pdf');
end;

procedure TestTPdfFile.TestLoadTextString;
begin
  FPdfFile.LoadFromFile('..\Common\TextString.pdf');
end;

procedure TestTPdfFile.TestCanLoad;
begin
  CheckTrue(FPdfFile.CanLoad('..\Common\Simple.pdf'));
  CheckTrue(FPdfFile.CanLoad('..\Common\LibreOffice.pdf'));
  CheckTrue(FPdfFile.CanLoad('..\Common\PDFA.pdf'));
  CheckTrue(FPdfFile.CanLoad('..\Common\TextString.pdf'));
end;

initialization
  RegisterTest(TestTPdfFile.Suite);

end.


