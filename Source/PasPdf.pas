unit PasPdf;

interface

uses
  Classes, SysUtils, Contnrs;

type
  TPdfFile = class;

  TPdfCrossReferenceEntry = class
  private
    FByteOffset: Integer;
    FGenerationNumber: Integer;
    FInUse: Boolean;
  public
    constructor Create(ByteOffset, GenerationNumber: Integer; InUse: Boolean);

    property ByteOffset: Integer read FByteOffset;
    property InUse: Boolean read FInUse;
    property GenerationNumber: Integer read FGenerationNumber;
  end;

  TPdfCrossReferenceTable = class
  private
    FStart: Integer;
    FCrossReferences: array of TPdfCrossReferenceEntry;
  public
    constructor Create(Start: Integer);
  end;

  TPdfCustomObject = class
  public
    constructor Create; virtual;
  end;

  TPdfObjectNumber = class(TPdfCustomObject)
  private
    FValue: Integer;
  public
    property Value: Integer read FValue;
  end;

  TPdfObjectString = class(TPdfCustomObject)
  private
    FValue: string;
  public
    property Value: string read FValue;
  end;

  TPdfObjectList = class
  private
    FList: TObjectList;
  public
    constructor Create;
  end;

  TPdfFileReader = class
  private
    FStream: TMemoryStream;
    FOwnsStream: Boolean;
    FPdfFile: TPdfFile;
    FCurrentChar: AnsiChar;
    FCrossReferenceTable: TPdfCrossReferenceTable;
    FObjects: TPdfObjectList;
    function ReadChar(const Character: AnsiChar): Boolean;
    function ReadNumber: Integer;
    function ReadHexNumber: Integer;
    function ReadString: AnsiString;

    procedure SkipSingleSpace;
    procedure SkipWhiteSpaces;
    function SkipUntil(const Text: AnsiString): Boolean;

    function CheckString(const Text: AnsiString): Boolean;
    procedure ReadCurrentChar; inline;

    procedure ReadObject;
    procedure ReadHeader;
    procedure ReadBody;
    procedure ReadCrossReferenceTable;
    procedure ReadTrailer;
    procedure ReadComment;
    procedure HandleLineBreak;
    function ReadLiteralString: AnsiString;
    function ReadHexadecimalString: AnsiString;
    procedure ReadDictionaryObject;
    function ReadNamedObject: AnsiString;
    procedure ReadArrayObject;
  public
    constructor Create(Stream: TStream; PdfFile: TPdfFile);
    destructor Destroy; override;

    procedure Read;
  end;

  TPdfFile = class
  private
    FMajorVersion: Integer;
    FMinorVersion: Integer;
  public
    constructor Create;

    procedure LoadFromFile(const FileName: TFileName);
    procedure LoadFromStream(const Stream: TStream);

    class function CanLoad(const FileName: TFileName): Boolean; overload;
    class function CanLoad(const Stream: TStream): Boolean; overload;

    property MajorVersion: Integer read FMajorVersion;
    property MinorVersion: Integer read FMinorVersion;
  end;

implementation

uses
  AnsiStrings;

resourcestring
  RStrInvalidFile = 'Invalid File';
  RStrUnsupportedVersion = 'Unsupported version';
  RStrNewlineCharacterExpected = 'newline character expected';
  RStrNotImplemented = 'Not implemented';
  RStrInvalidCharacter = 'Invalid character %s';
  RStrSpaceExpected = 'Space expected';

type
  TFileHeader = array [0..4] of AnsiChar;
  TFileVersion = array [0..2] of AnsiChar;

const
  CNumbers = ['0' .. '9'];
  CHexNumbers = ['0' .. '9', 'A'..'F', 'a'..'f'];
  CWhitespaces = [#0, ' ', #9, #10, #12, #13];

{ TPdfCrossReferenceEntry }

constructor TPdfCrossReferenceEntry.Create(ByteOffset, GenerationNumber: Integer;
  InUse: Boolean);
begin
  FByteOffset := ByteOffset;
  FGenerationNumber := GenerationNumber;
  FInUse := InUse;
end;


{ TPdfCrossReferenceTable }

constructor TPdfCrossReferenceTable.Create(Start: Integer);
begin
  FStart := Start;
end;


{ TPdfCustomObject }

constructor TPdfCustomObject.Create;
begin
  // nothing here yet
end;


{ TPdfObjectList }

constructor TPdfObjectList.Create;
begin
  FList := TObjectList.Create;
end;


{ TPdfFileReader }

constructor TPdfFileReader.Create(Stream: TStream; PdfFile: TPdfFile);
begin
  FOwnsStream := not (Stream is TMemoryStream);
  if FOwnsStream then
  begin
    FStream := TMemoryStream.Create;
    FStream.CopyFrom(Stream, Stream.Size - Stream.Position);
  end
  else
    FStream := TMemoryStream(Stream);

  FPdfFile := PdfFile;

  FObjects := TPdfObjectList.Create;
end;

destructor TPdfFileReader.Destroy;
begin
  if FOwnsStream then
    FStream.Free;

  FObjects.Free;
end;

procedure TPdfFileReader.Read;
begin
  FStream.Position := 0;
  ReadHeader;
  SkipWhiteSpaces;
  ReadBody;
//  ReadCrossReferenceTable(Stream);
end;

procedure TPdfFileReader.ReadCurrentChar;
begin
  FStream.Read(FCurrentChar, 1);
end;

function TPdfFileReader.ReadChar(const Character: AnsiChar): Boolean;
begin
  Result := False;
  while FStream.Position < FStream.Size do
  begin
    ReadCurrentChar;
    if Character = FCurrentChar then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TPdfFileReader.SkipWhiteSpaces;
begin
  while FCurrentChar in CWhitespaces do
    ReadCurrentChar;
end;

function TPdfFileReader.CheckString(const Text: AnsiString): Boolean;
var
  RemainingBytes: Cardinal;
  CompareText: AnsiString;
begin
  Result := False;
  SetLength(CompareText, Length(Text));
  if FCurrentChar = Text[1] then
  begin
    RemainingBytes := Length(Text) - 1;
    Result := FStream.Size >= RemainingBytes;
    CompareText[1] := FCurrentChar;
    if Result then
    begin
      FStream.Read(CompareText[2], RemainingBytes);
      Result := Text = CompareText;
      if Result then
        ReadCurrentChar
      else
        FStream.Position := FStream.Position - RemainingBytes;
    end;
    Exit;
  end;
end;

procedure TPdfFileReader.SkipSingleSpace;
begin
  if FCurrentChar <> ' ' then
    raise Exception.Create(RStrSpaceExpected);
  ReadCurrentChar;
end;

function TPdfFileReader.SkipUntil(const Text: AnsiString): Boolean;
var
  RemainingBytes: Cardinal;
  CompareText: AnsiString;
begin
  Result := False;
  SetLength(CompareText, Length(Text));
  while FStream.Position < FStream.Size do
  begin
    if FCurrentChar = Text[1] then
    begin
      RemainingBytes := Length(Text) - 1;
      Result := FStream.Size >= RemainingBytes;
      CompareText[1] := FCurrentChar;
      if Result then
      begin
        FStream.Read(CompareText[2], RemainingBytes);
        Result := Text = CompareText;
        if Result then
          ReadCurrentChar
        else
          FStream.Position := FStream.Position - RemainingBytes;
      end;
      Exit;
    end;
    ReadCurrentChar;
  end;
end;

function TPdfFileReader.ReadNumber: Integer;
var
  Number: AnsiString;
begin
  Number := FCurrentChar;
  while FStream.Position < FStream.Size do
  begin
    ReadCurrentChar;
    if FCurrentChar in CNumbers then
      Number := Number + FCurrentChar
    else
      Break;
  end;

  if Number = '' then
    raise Exception.Create('Number expected');

  Result := StrToInt(string(Number));
end;

function TPdfFileReader.ReadHexNumber: Integer;
var
  Number: AnsiString;
begin
  Number := FCurrentChar;
  while FStream.Position < FStream.Size do
  begin
    ReadCurrentChar;
    if FCurrentChar in CHexNumbers then
      Number := Number + FCurrentChar
    else
      Break;
  end;

  if Number = '' then
    raise Exception.Create('Number expected');

  Result := StrToInt('$' + string(Number));
end;

function TPdfFileReader.ReadString: AnsiString;
begin
  Result := '';
  repeat
    if not (FCurrentChar in CWhitespaces) then
      Result := Result + FCurrentChar
    else
      Break;

    ReadCurrentChar;
  until (FStream.Position >= FStream.Size);
end;

procedure TPdfFileReader.HandleLineBreak;
begin
  if FCurrentChar = #$D then
  begin
    ReadCurrentChar;
    if FCurrentChar = #$A then
      ReadCurrentChar;
  end
  else
  if FCurrentChar = #$A then
    ReadCurrentChar
  else
    raise Exception.Create(RStrNewlineCharacterExpected);
end;

procedure TPdfFileReader.ReadComment;
var
  Comment: AnsiString;
begin
  while FStream.Position < FStream.Size do
  begin
    ReadCurrentChar;
    if (FCurrentChar in ['%', #$D, #$A]) then
      Break;

    Comment := Comment + FCurrentChar;
  end;

  if FCurrentChar in [#$D, #$A] then
    HandleLineBreak
  else
    ReadCurrentChar;
end;

procedure TPdfFileReader.ReadObject;
var
  ObjectNumber, GenerationNumber: Integer;
begin
  ObjectNumber := ReadNumber;
  SkipWhiteSpaces;
  GenerationNumber := ReadNumber;
  SkipWhiteSpaces;
  if not CheckString('obj') then
    raise Exception.Create(RStrInvalidFile);
  SkipWhiteSpaces;

  case FCurrentChar of
    '<':
      begin
        ReadCurrentChar;
        if FCurrentChar = '<' then
          ReadDictionaryObject
        else
          ReadHexadecimalString;
      end;
    '(':
      ReadLiteralString;
    '[':
      ReadArrayObject;
    '0'..'9':
      ReadNumber;
    else
      raise Exception.Create(RStrNotImplemented);
  end;

  ReadCurrentChar;
  SkipWhiteSpaces;

  if CheckString('stream') then
  begin
    SkipUntil('endstream');
    ReadCurrentChar;
  end;

  if not CheckString('endobj') then
    raise Exception.Create(RStrInvalidFile);
  SkipWhiteSpaces;
end;

function TPdfFileReader.ReadNamedObject: AnsiString;
var
  CharNumber: Integer;
begin
  Result := '';

  Assert(FCurrentChar = '/');
  ReadCurrentChar;

  repeat
    if FCurrentChar = '#' then
    begin
      ReadCurrentChar;
      CharNumber := ReadHexNumber;
      FCurrentChar := AnsiChar(CharNumber);
    end;

    if not ((FCurrentChar in CWhitespaces) or (FCurrentChar in ['/', '>'])) then
      Result := Result + FCurrentChar
    else
      Break;

    ReadCurrentChar;
  until (FStream.Position >= FStream.Size);
end;

procedure TPdfFileReader.ReadArrayObject;
begin
  while (FStream.Position < FStream.Size) do
  begin
    ReadCurrentChar;
    case FCurrentChar of
      ']':
        Break;
      '0' .. '9':
        ReadNumber;
      '(':
        ReadLiteralString;
      '<':
        ReadHexadecimalString;
      '/':
        ReadNamedObject;
    end;
  end;
end;

procedure TPdfFileReader.ReadDictionaryObject;
var
  Key, ValueText: AnsiString;
  ValueNumber, ObjectNumber, GenerationNumber: Integer;
begin
  ReadCurrentChar;
  SkipWhiteSpaces;

  repeat
    if FCurrentChar = '>' then
    begin
      ReadCurrentChar;
      if FCurrentChar = '>' then
        break;
    end;

    Key := ReadNamedObject;
    SkipWhiteSpaces;
    case FCurrentChar of
      '0' .. '9':
        begin
          ValueNumber := ReadNumber;
          SkipWhiteSpaces;
          if FCurrentChar in CNumbers then
          begin
            ObjectNumber := ValueNumber;
            GenerationNumber := ReadNumber;
            SkipWhiteSpaces;
            if FCurrentChar <> 'R' then
              raise Exception.CreateFmt(RStrInvalidCharacter, [FCurrentChar]);
            ReadCurrentChar;
          end;
        end;
      '/':
        begin
          ValueText := ReadNamedObject;
        end;
      '[':
        begin
          ReadArrayObject;
          ReadCurrentChar;
        end;
      '<':
        begin
          ReadCurrentChar;
          if FCurrentChar = '<' then
          begin
            ReadDictionaryObject;

            // workaround
            ReadCurrentChar;
          end
          else
            ReadHexadecimalString;
        end;
    end;

    SkipWhiteSpaces;
  until FStream.Position >= FStream.Size;
end;

function TPdfFileReader.ReadHexadecimalString: AnsiString;
var
  Hex: AnsiString;
  Index: Integer;
begin
  Hex := '';

  repeat
    if (FCurrentChar = '>') then
      Break;

    if FCurrentChar in CHexNumbers then
      Hex := Hex + FCurrentChar
    else
    if not (FCurrentChar in CWhitespaces) then
      raise Exception.CreateFmt(RStrInvalidCharacter, [FCurrentChar]);

    ReadCurrentChar;
  until FStream.Position >= FStream.Size;

  if Odd(Length(Hex)) then
    Hex := Hex + '0';

  Result := '';
  for Index := 0 to (Length(Hex) div 2) - 1 do
    Result := Result + AnsiChar(StrToInt('$' + string(Hex[2 * Index + 1] + Hex[2 * Index + 2])));

  ReadCurrentChar;
end;

function TPdfFileReader.ReadLiteralString: AnsiString;
begin
  repeat
    ReadCurrentChar;
    if (FCurrentChar = ')') then
      Break;

    if (FCurrentChar = '\') then
    begin
      ReadCurrentChar;
      case FCurrentChar of
        'b':
          FCurrentChar := #8;
        't':
          FCurrentChar := #9;
        'n':
          FCurrentChar := #10;
        'f':
          FCurrentChar := #12;
        'r':
          FCurrentChar := #13;
        '(':
          FCurrentChar := '(';
        ')':
          FCurrentChar := ')';
        '\':
          FCurrentChar := '\';
        '0'..'7':
          begin
            //ReadOctal;
            raise Exception.Create(RStrNotImplemented);
          end;
         #10, #13:
           begin
             HandleLineBreak;
             Continue;
           end;
      end;
    end;

    Result := Result + FCurrentChar;
  until FStream.Position >= FStream.Size;

  ReadCurrentChar;
end;

procedure TPdfFileReader.ReadHeader;
var
  FileHeader: TFileHeader;
  FileVersion: TFileVersion;
begin
  // check for a minimum file size (can't be much lower than that)
  if FStream.Size < 67 then
    raise Exception.Create(RStrInvalidFile);

  // read file header
  FStream.Read(FileHeader, 5);

  if FileHeader <> '%PDF-' then
    raise Exception.Create(RStrInvalidFile);

  // read file version
  FStream.Read(FileVersion, 3);

  if (FileVersion[0] <> '1') or (FileVersion[1] <> '.') then
    raise Exception.Create(RStrInvalidFile);

  if FileVersion[2] in [#$A, #$D] then
  begin
    FileVersion[2] := '0';
    FStream.Seek(-1, soFromCurrent);
  end;

  if not (FileVersion[2] in ['0' .. '5', #$A, #$D]) then
    raise Exception.Create(RStrUnsupportedVersion);

  FPdfFile.FMinorVersion := StrToInt(string(FileVersion[2]));

  ReadCurrentChar;
  HandleLineBreak;
end;

procedure TPdfFileReader.ReadBody;
begin
  while FStream.Position < FStream.Size do
  begin
    if FCurrentChar = '%' then
      ReadComment
    else
    if FCurrentChar in ['0' .. '9'] then
      ReadObject
    else
    if (FCurrentChar = 'x') and CheckString('xref') then
      ReadCrossReferenceTable
    else
    if (FCurrentChar = 't') and CheckString('trailer') then
    begin
      ReadTrailer;
      break;
    end;
  end;
end;

procedure TPdfFileReader.ReadCrossReferenceTable;
var
  Start, Index, Count: Integer;
  ByteOffset, GenerationNumber: Integer;
  Keyword: AnsiChar;
begin
  SkipWhiteSpaces;
  Start := ReadNumber;
  SkipSingleSpace;
  Count := ReadNumber;
  HandleLineBreak;
  FCrossReferenceTable := TPdfCrossReferenceTable.Create(Start);
  SetLength(FCrossReferenceTable.FCrossReferences, Count);
  for Index := 0 to Count - 1 do
  begin
    ByteOffset := ReadNumber;
    SkipSingleSpace;
    GenerationNumber := ReadNumber;
    SkipSingleSpace;
    case FCurrentChar of
      'n', 'f':;
      else
        raise Exception.Create('Unknown keyword');
    end;
    Keyword := FCurrentChar;
    ReadCurrentChar;
    if FCurrentChar = ' ' then
      ReadCurrentChar;
    HandleLineBreak;

    FCrossReferenceTable.FCrossReferences[Index] := TPdfCrossReferenceEntry.Create(ByteOffset, GenerationNumber, Keyword = 'n');
  end;
  SkipWhiteSpaces;
end;

procedure TPdfFileReader.ReadTrailer;
var
  Offset: Integer;
begin
  if not ReadChar('<') then
    raise Exception.Create('Invalid File');
  if not ReadChar('<') then
    raise Exception.Create('Invalid File');

  ReadDictionaryObject;

  ReadCurrentChar;
  HandleLineBreak;

  if CheckString('startxref') then
  begin
    // read the byte offset to the last cross-reference secion
    HandleLineBreak;
    Offset := ReadNumber;
    HandleLineBreak;
  end;

  if not CheckString('%%EOF') then
    raise Exception.Create(RStrInvalidFile);
end;


{ TPdfFile }

constructor TPdfFile.Create;
begin
  FMajorVersion := 1;
  FMinorVersion := 0;
end;

class function TPdfFile.CanLoad(const FileName: TFileName): Boolean;
var
  FileStream: TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  with FileStream do
  try
    Result := CanLoad(FileStream);
  finally
    Free;
  end;
end;

class function TPdfFile.CanLoad(const Stream: TStream): Boolean;
var
  FileHeader: TFileHeader;
  FileVersion: TFileVersion;
begin
  Result := Stream.Size >= 67;

  if Result then
  begin
    // read file header
    Stream.Read(FileHeader, 5);

    // read file version
    Stream.Read(FileVersion, 3);

    Stream.Seek(-8, soFromCurrent);
    Result := (FileHeader = '%PDF-') and (FileVersion[0] = '1') and
      (FileVersion[1] = '.') and (FileVersion[2] in ['0' .. '5']);
    Stream.Seek(-8, soFromCurrent);
  end;
end;

procedure TPdfFile.LoadFromFile(const FileName: TFileName);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TPdfFile.LoadFromStream(const Stream: TStream);
var
  PdfReader: TPdfFileReader;
begin
  PdfReader := TPdfFileReader.Create(Stream, Self);
  try
    PdfReader.Read;
  finally
    PdfReader.Free;
  end;
end;


end.
