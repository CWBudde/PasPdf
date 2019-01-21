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
    procedure TestLoadFromFile;
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

procedure TestTPdfFile.TestLoadFromFile;
begin
  FPdfFile.LoadFromFile('Simple.pdf');
end;

procedure TestTPdfFile.TestCanLoad;
begin
  CheckTrue(FPdfFile.CanLoad('Simple.pdf'));
end;

initialization
  RegisterTest(TestTPdfFile.Suite);

end.


