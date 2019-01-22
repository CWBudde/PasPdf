unit PasPdf;

interface

uses
  Classes, SysUtils, Contnrs, PasPdfFileElements;

type
  TPdfFile = class;

  TPdfFileCrossReferenceEntry = class
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

  TPdfFileCrossReferenceTable = class
  private
    FStart: Integer;
    FCrossReferences: array of TPdfFileCrossReferenceEntry;
  public
    constructor Create(Start: Integer);
  end;

  TPdfFileReader = class
  private
    FStream: TMemoryStream;
    FOwnsStream: Boolean;
    FPdfFile: TPdfFile;
    FCurrentChar: AnsiChar;
    FCrossReferenceTable: TPdfFileCrossReferenceTable;
    FObjects: TPdfFileObjectList;
    FStartCrossReferenceOffset: Integer;
    function ReadChar(const Character: AnsiChar): Boolean;
    function ReadReal: Double;
    function ReadInteger: Integer;
    function ReadHexNumber: Integer;
    procedure ReadNumber(out IntValue: Integer; out RealValue: Double;
      out IsIntValue: Boolean);

    procedure SkipSingleSpace;
    procedure SkipWhiteSpaces;

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
    function ReadHexadecimalString: string;
    function ReadDictionaryObject: TPdfFileDictionary;
    function ReadNamedObject: AnsiString;
    function ReadArray: TPdfFileArray;
    function ReadStream: TMemoryStream;
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

{ TPdfFileCrossReferenceEntry }

constructor TPdfFileCrossReferenceEntry.Create(ByteOffset, GenerationNumber: Integer;
  InUse: Boolean);
begin
  FByteOffset := ByteOffset;
  FGenerationNumber := GenerationNumber;
  FInUse := InUse;
end;


{ TPdfFileCrossReferenceTable }

constructor TPdfFileCrossReferenceTable.Create(Start: Integer);
begin
  FStart := Start;
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

  FObjects := TPdfFileObjectList.Create;
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

function TPdfFileReader.ReadInteger: Integer;
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
  Dictionary: TPdfFileDictionary;
begin
  ObjectNumber := ReadInteger;
  SkipWhiteSpaces;
  GenerationNumber := ReadInteger;
  SkipWhiteSpaces;
  if not CheckString('obj') then
    raise Exception.Create(RStrInvalidFile);
  SkipWhiteSpaces;

  case FCurrentChar of
    '<':
      begin
        ReadCurrentChar;

        if FCurrentChar = '<' then
        begin
          Dictionary := ReadDictionaryObject;

          ReadCurrentChar;
          SkipWhiteSpaces;

          if CheckString('stream') then
          begin
            if FCurrentChar = #13 then
              ReadCurrentChar;
            if FCurrentChar <> #10 then
              raise Exception.Create('Line feed expected');
            ReadCurrentChar;

            FObjects.AddObject(TPdfFileObjectStream.Create(ObjectNumber,
              GenerationNumber, Dictionary, ReadStream));

            ReadCurrentChar;
          end
          else
            FObjects.AddObject(TPdfFileObjectDictionary.Create(ObjectNumber,
              GenerationNumber, Dictionary));
        end
        else
        begin
          FObjects.AddObject(TPdfFileObjectString.Create(ObjectNumber,
            GenerationNumber, ReadHexadecimalString));

          ReadCurrentChar;
        end;
      end;
    '(':
      begin
        FObjects.AddObject(TPdfFileObjectString.Create(ObjectNumber,
          GenerationNumber, string(ReadLiteralString)));
        ReadCurrentChar;
      end;
    '[':
      begin
        FObjects.AddObject(TPdfFileObjectArray.Create(ObjectNumber,
          GenerationNumber, ReadArray));
        ReadCurrentChar;
      end;
    '0'..'9':
      begin
        FObjects.AddObject(TPdfFileObjectNumber.Create(ObjectNumber,
          GenerationNumber, ReadReal));

        ReadCurrentChar;
      end;
    else
      raise Exception.Create(RStrNotImplemented);
  end;

  SkipWhiteSpaces;

  if not CheckString('endobj') then
    raise Exception.Create(RStrInvalidFile);
  SkipWhiteSpaces;
end;

function TPdfFileReader.ReadStream: TMemoryStream;
var
  CompareText: AnsiString;
begin
  Result := TMemoryStream.Create;
  SetLength(CompareText, 9);
  while FStream.Position < FStream.Size do
  begin
    if FCurrentChar = 'e' then
    begin
      CompareText[1] := FCurrentChar;
      if FStream.Size >= 8 then
      begin
        FStream.Read(CompareText[2], 8);
        if 'endstream' = CompareText then
        begin
          ReadCurrentChar;
          Exit;
        end
        else
          FStream.Position := FStream.Position - 8;
      end;
    end;

    Result.Write(FCurrentChar, 1);

    ReadCurrentChar;
  end;

  Result.Position := 0;
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

    if not ((FCurrentChar in CWhitespaces) or (FCurrentChar in ['/', '<', '>', '[', ']', '('])) then
      Result := Result + FCurrentChar
    else
      Break;

    ReadCurrentChar;
  until (FStream.Position >= FStream.Size);
end;

procedure TPdfFileReader.ReadNumber(out IntValue: Integer;
  out RealValue: Double; out IsIntValue: Boolean);
var
  Number: AnsiString;
begin
  Number := FCurrentChar;
  IsIntValue := True;
  while FStream.Position < FStream.Size do
  begin
    ReadCurrentChar;
    if FCurrentChar = '.' then
    begin
      if not IsIntValue then
        raise Exception.Create('Invalid float value');
      IsIntValue := False;
      Number := Number + AnsiString(FormatSettings.DecimalSeparator);
    end
    else
    if FCurrentChar in CNumbers then
        Number := Number + FCurrentChar
    else
      Break;
  end;

  if Number = '' then
    raise Exception.Create('Number expected');

  if IsIntValue then
  begin
    IntValue := StrToInt(string(Number));
    RealValue := IntValue;
  end
  else
  begin
    RealValue := StrToFloat(string(Number));
    IntValue := Round(RealValue);
  end;
end;

function TPdfFileReader.ReadArray: TPdfFileArray;
var
  IntValue: Integer;
  RealValue: Double;
  IsIntValue: Boolean;
begin
  Result := TPdfFileArray.Create;
  ReadCurrentChar;
  while (FStream.Position < FStream.Size) do
  begin
    case FCurrentChar of
      ']':
        Break;
      '+', '-', '0' .. '9':
        begin
          ReadNumber(IntValue, RealValue, IsIntValue);
          if IsIntValue then
            Result.Add(IntValue)
          else
            Result.Add(RealValue);
        end;
      '(':
        Result.Add(ReadLiteralString);
      '<':
        begin
          ReadCurrentChar;

          Result.Add(ReadHexadecimalString);
        end;
      '[':
        begin
          Result.Add(ReadArray);

          ReadCurrentChar;
        end;
      '/':
        Result.Add(ReadNamedObject);
      'R':
        begin
          ReadCurrentChar;
          // TODO convert previous numbers as reference
        end;
      'n':
        begin
          if not CheckString('null') then
            raise Exception.Create(RStrNotImplemented);

          Result.AddNull;
        end;
    end;

    SkipWhiteSpaces;
  end;
end;

function TPdfFileReader.ReadDictionaryObject: TPdfFileDictionary;
var
  Key, ValueText: AnsiString;
  IntValue, ObjectNumber, GenerationNumber: Integer;
  RealValue: Double;
  IsIntValue: Boolean;
  SubDictionary: TPdfFileDictionary;
  SubArray: TPdfFileArray;
begin
  ReadCurrentChar;
  SkipWhiteSpaces;

  Result := TPdfFileDictionary.Create;

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
      '-', '+', '0' .. '9':
        begin
          ReadNumber(IntValue, RealValue, IsIntValue);

          if IsIntValue then
          begin
            SkipWhiteSpaces;
            if FCurrentChar in CNumbers then
            begin
              ObjectNumber := IntValue;
              GenerationNumber := ReadInteger;
              SkipWhiteSpaces;
              if FCurrentChar <> 'R' then
                raise Exception.CreateFmt(RStrInvalidCharacter, [FCurrentChar]);
              ReadCurrentChar;
            end;
          end
          else
            raise Exception.Create(RStrNotImplemented);
        end;
      '/':
        begin
          ValueText := ReadNamedObject;
          Result.Add(Key, ValueText);
        end;
      '[':
        begin
          SubArray := ReadArray;
          Result.Add(Key, SubArray);

          // workaround
          ReadCurrentChar;
        end;
      '(':
        Result.Add(Key, ReadLiteralString);
      '<':
        begin
          ReadCurrentChar;
          if FCurrentChar = '<' then
          begin
            SubDictionary := ReadDictionaryObject;

            Result.Add(Key, SubDictionary);

            // workaround
            ReadCurrentChar;
          end
          else
            ReadHexadecimalString;
        end;
      't':
        begin
          if CheckString('true') then
            Result.Add(Key, True)
          else
            raise Exception.Create(RStrNotImplemented);
        end;
      'f':
        begin
          if CheckString('false') then
            Result.Add(Key, False)
          else
            raise Exception.Create(RStrNotImplemented);
        end;
    end;

    SkipWhiteSpaces;
  until FStream.Position >= FStream.Size;
end;

function TPdfFileReader.ReadReal: Double;
var
  Number: AnsiString;
begin
  Number := FCurrentChar;
  while FStream.Position < FStream.Size do
  begin
    ReadCurrentChar;
    if FCurrentChar in ['+', '-', '0' .. '9', '.'] then
      Number := Number + FCurrentChar
    else
      Break;
  end;

  if Number = '' then
    raise Exception.Create('Number expected');

  Result := StrToInt(string(Number));
end;

function TPdfFileReader.ReadHexadecimalString: string;
var
  Hex: AnsiString;
  Bytes: TBytes;
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

  SetLength(Bytes, Length(Hex) div 2);
  for Index := 0 to (Length(Hex) div 2) - 1 do
    Bytes[Index] := StrToInt('$' + string(Hex[2 * Index + 1] + Hex[2 * Index + 2]));

  Result := '';
  if (Length(Hex) > 4) and (Bytes[0] = $FE) and (Bytes[1] = $FF) then
  begin
    with TStringStream.Create(Bytes) do
    try
      Result := DataString;
    finally
      Free;
    end;
    Delete(Result, 1, 1);
  end
  else
    for Index := 0 to Length(Bytes) - 1 do
      Result := Result + string(AnsiChar(Bytes[Index]));

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
  Start := ReadInteger;
  SkipSingleSpace;
  Count := ReadInteger;
  HandleLineBreak;
  FCrossReferenceTable := TPdfFileCrossReferenceTable.Create(Start);
  SetLength(FCrossReferenceTable.FCrossReferences, Count);
  for Index := 0 to Count - 1 do
  begin
    ByteOffset := ReadInteger;
    SkipSingleSpace;
    GenerationNumber := ReadInteger;
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

    FCrossReferenceTable.FCrossReferences[Index] := TPdfFileCrossReferenceEntry.Create(ByteOffset, GenerationNumber, Keyword = 'n');
  end;
  SkipWhiteSpaces;
end;

procedure TPdfFileReader.ReadTrailer;
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
    FStartCrossReferenceOffset := ReadInteger;
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
