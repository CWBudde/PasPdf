unit PasPdf;

interface

uses
  Classes, SysUtils, Contnrs;

type
  TPdfFile = class;
  TPdfArray = class;
  TPdfDictionary = class;

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

  TPdfDictionaryCustomItem = class
  private
    FKey: AnsiString;
  public
    constructor Create(Key: AnsiString); virtual;

    property Key: AnsiString read FKey;
  end;

  TPdfDictionaryItemString = class(TPdfDictionaryCustomItem)
  private
    FValue: AnsiString;
  public
    constructor Create(Key, Value: AnsiString); reintroduce;

    property Value: AnsiString read FValue;
  end;

  TPdfDictionaryItemInteger = class(TPdfDictionaryCustomItem)
  private
    FValue: Integer;
  public
    constructor Create(Key: AnsiString; Value: Integer); reintroduce;

    property Value: Integer read FValue;
  end;

  TPdfDictionaryItemReal = class(TPdfDictionaryCustomItem)
  private
    FValue: Double;
  public
    constructor Create(Key: AnsiString; Value: Double); reintroduce;

    property Value: Double read FValue;
  end;

  TPdfDictionaryItemBoolean = class(TPdfDictionaryCustomItem)
  private
    FValue: Boolean;
  public
    constructor Create(Key: AnsiString; Value: Boolean); reintroduce;

    property Value: Boolean read FValue;
  end;

  TPdfDictionaryItemReference = class(TPdfDictionaryCustomItem)
  private
    FObjectNumber: Integer;
    FGenerationNumber: Integer;
  public
    constructor Create(Key: AnsiString; ObjectNumber, GenerationNumber: Integer); reintroduce;

    property ObjectNumber: Integer read FObjectNumber;
    property GenerationNumber: Integer read FGenerationNumber;
  end;

  TPdfDictionaryItemDictionary = class(TPdfDictionaryCustomItem)
  private
    FValue: TPdfDictionary;
  public
    constructor Create(Key: AnsiString; Value: TPdfDictionary); reintroduce;
    destructor Destroy; override;

    property Value: TPdfDictionary read FValue;
  end;

  TPdfDictionaryItemArray = class(TPdfDictionaryCustomItem)
  private
    FValue: TPdfArray;
  public
    constructor Create(Key: AnsiString; Value: TPdfArray); reintroduce;
    destructor Destroy; override;

    property Value: TPdfArray read FValue;
  end;

  TPdfDictionary = class
  private
    FList: TObjectList;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure Add(Key, Value: AnsiString); overload;
    procedure Add(Key: AnsiString; Value: Integer); overload;
    procedure Add(Key: AnsiString; Value: Double); overload;
    procedure Add(Key: AnsiString; Value: Boolean); overload;
    procedure Add(Key: AnsiString; Value: TPdfDictionary); overload;
    procedure Add(Key: AnsiString; Value: TPdfArray); overload;
  end;

  TPdfArray = class
  public
    procedure Add(Value: AnsiString); overload;
    procedure Add(Value: Integer); overload;
    procedure Add(Value: Double); overload;
    procedure AddNull;
  end;

  TPdfCustomObject = class
  private
    FObjectNumber: Integer;
    FGenerationNumber: Integer;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer); overload; virtual;

    property ObjectNumber: Integer read FObjectNumber;
    property GenerationNumber: Integer read FGenerationNumber;
  end;

  TPdfObjectNumber = class(TPdfCustomObject)
  private
    FValue: Double;
  public
    constructor Create(ObjectNumber, GenerationNumber:Integer; Value: Double); overload;

    property Value: Double read FValue;
  end;

  TPdfObjectString = class(TPdfCustomObject)
  private
    FValue: AnsiString;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer; Value: AnsiString); overload;

    property Value: AnsiString read FValue;
  end;

  TPdfObjectStream = class(TPdfCustomObject)
  private
    FDictionary: TPdfDictionary;
    FStream: TMemoryStream;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer;
      Dictionary: TPdfDictionary; Stream: TMemoryStream); reintroduce;

    property Stream: TMemoryStream read FStream;
  end;

  TPdfObjectDictionary = class(TPdfCustomObject)
  private
    FDictionary: TPdfDictionary;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer; Dictionary: TPdfDictionary); overload;
    destructor Destroy; override;

    property Dictionary: TPdfDictionary read FDictionary;
  end;

  TPdfObjectArray = class(TPdfCustomObject)
  private
    FArray: TPdfArray;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer; &Array: TPdfArray); overload;
    destructor Destroy; override;

    property &Array: TPdfArray read FArray;
  end;

  TPdfObjectList = class
  private
    FList: TObjectList;
    function GetItem(Index: Integer): TPdfCustomObject;
    function GetCount: Integer;
  public
    constructor Create;

    procedure AddObject(PdfObject: TPdfCustomObject);

    property Items[Index: Integer]: TPdfCustomObject read GetItem;
    property Count: Integer read GetCount;
  end;

  TPdfFileReader = class
  private
    FStream: TMemoryStream;
    FOwnsStream: Boolean;
    FPdfFile: TPdfFile;
    FCurrentChar: AnsiChar;
    FCrossReferenceTable: TPdfCrossReferenceTable;
    FObjects: TPdfObjectList;
    FStartCrossReferenceOffset: Integer;
    function ReadChar(const Character: AnsiChar): Boolean;
    function ReadReal: Double;
    function ReadInteger: Integer;
    function ReadHexNumber: Integer;
    procedure ReadNumber(out IntValue: Integer; out RealValue: Double;
      out IsIntValue: Boolean);
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
    function ReadDictionaryObject: TPdfDictionary;
    function ReadNamedObject: AnsiString;
    function ReadArray: TPdfArray;
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


{ TPdfDictionaryCustomItem }

constructor TPdfDictionaryCustomItem.Create(Key: AnsiString);
begin
  inherited Create;

  FKey := Key;
end;


{ TPdfDictionaryItemString }

constructor TPdfDictionaryItemString.Create(Key, Value: AnsiString);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfDictionaryItemInteger }

constructor TPdfDictionaryItemInteger.Create(Key: AnsiString; Value: Integer);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfDictionaryItemReal }

constructor TPdfDictionaryItemReal.Create(Key: AnsiString; Value: Double);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfDictionaryItemBoolean }

constructor TPdfDictionaryItemBoolean.Create(Key: AnsiString; Value: Boolean);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfDictionaryItemReference }

constructor TPdfDictionaryItemReference.Create(Key: AnsiString; ObjectNumber,
  GenerationNumber: Integer);
begin
  inherited Create(Key);

  FObjectNumber := ObjectNumber;
  FGenerationNumber := GenerationNumber;
end;


{ TPdfDictionaryItemDictionary }

constructor TPdfDictionaryItemDictionary.Create(Key: AnsiString;
  Value: TPdfDictionary);
begin
  inherited Create(Key);

  FValue := Value;
end;

destructor TPdfDictionaryItemDictionary.Destroy;
begin
  FValue.Free;

  inherited;
end;


{ TPdfDictionaryItemArray }

constructor TPdfDictionaryItemArray.Create(Key: AnsiString;
  Value: TPdfArray);
begin
  inherited Create(Key);

  FValue := Value;
end;

destructor TPdfDictionaryItemArray.Destroy;
begin

  inherited;
end;


{ TPdfDictionary }

constructor TPdfDictionary.Create;
begin
  inherited;

  FList := TObjectList.Create;
end;

destructor TPdfDictionary.Destroy;
begin
  FList.Free;

  inherited;
end;

procedure TPdfDictionary.Add(Key, Value: AnsiString);
begin
  FList.Add(TPdfDictionaryItemString.Create(Key, Value));
end;

procedure TPdfDictionary.Add(Key: AnsiString; Value: TPdfDictionary);
begin
  FList.Add(TPdfDictionaryItemDictionary.Create(Key, Value));
end;

procedure TPdfDictionary.Add(Key: AnsiString; Value: Integer);
begin
  FList.Add(TPdfDictionaryItemInteger.Create(Key, Value));
end;

procedure TPdfDictionary.Add(Key: AnsiString; Value: Double);
begin
  FList.Add(TPdfDictionaryItemReal.Create(Key, Value));
end;

procedure TPdfDictionary.Add(Key: AnsiString; Value: Boolean);
begin
  FList.Add(TPdfDictionaryItemBoolean.Create(Key, Value));
end;

procedure TPdfDictionary.Add(Key: AnsiString; Value: TPdfArray);
begin
  FList.Add(TPdfDictionaryItemArray.Create(Key, Value));
end;


{ TPdfArray }

procedure TPdfArray.Add(Value: AnsiString);
begin

end;

procedure TPdfArray.Add(Value: Integer);
begin

end;

procedure TPdfArray.Add(Value: Double);
begin

end;

procedure TPdfArray.AddNull;
begin

end;


{ TPdfCustomObject }

constructor TPdfCustomObject.Create(ObjectNumber, GenerationNumber: Integer);
begin
  inherited Create;

  FObjectNumber := ObjectNumber;
  FGenerationNumber := GenerationNumber;
end;


{ TPdfObjectNumber }

constructor TPdfObjectNumber.Create(ObjectNumber, GenerationNumber: Integer;
  Value: Double);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FValue := Value;
end;


{ TPdfObjectString }

constructor TPdfObjectString.Create(ObjectNumber, GenerationNumber: Integer;
  Value: AnsiString);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FValue := Value;
end;


{ TPdfObjectStream }

constructor TPdfObjectStream.Create(ObjectNumber, GenerationNumber: Integer;
  Dictionary: TPdfDictionary; Stream: TMemoryStream);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FDictionary := Dictionary;
  FStream := Stream;
end;


{ TPdfObjectDictionary }

constructor TPdfObjectDictionary.Create(ObjectNumber,
  GenerationNumber: Integer; Dictionary: TPdfDictionary);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FDictionary := Dictionary;
end;

destructor TPdfObjectDictionary.Destroy;
begin
  FDictionary.Free;

  inherited;
end;


{ TPdfObjectArray }

constructor TPdfObjectArray.Create(ObjectNumber, GenerationNumber: Integer;
  &Array: TPdfArray);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FArray := &Array;
end;

destructor TPdfObjectArray.Destroy;
begin
  FArray.Free;

  inherited;
end;


{ TPdfObjectList }

procedure TPdfObjectList.AddObject(PdfObject: TPdfCustomObject);
begin
  FList.Add(PdfObject);
end;

constructor TPdfObjectList.Create;
begin
  FList := TObjectList.Create;
end;

function TPdfObjectList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TPdfObjectList.GetItem(Index: Integer): TPdfCustomObject;
begin
  Result := TPdfCustomObject(FList.Items[Index]);
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
  Dictionary: TPdfDictionary;
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

            FObjects.AddObject(TPdfObjectStream.Create(ObjectNumber,
              GenerationNumber, Dictionary, ReadStream));

            ReadCurrentChar;
          end
          else
            FObjects.AddObject(TPdfObjectDictionary.Create(ObjectNumber,
              GenerationNumber, Dictionary));
        end
        else
        begin
          FObjects.AddObject(TPdfObjectString.Create(ObjectNumber,
            GenerationNumber, ReadHexadecimalString));

          ReadCurrentChar;
        end;
      end;
    '(':
      begin
        FObjects.AddObject(TPdfObjectString.Create(ObjectNumber,
          GenerationNumber, ReadLiteralString));
        ReadCurrentChar;
      end;
    '[':
      begin
        FObjects.AddObject(TPdfObjectArray.Create(ObjectNumber,
          GenerationNumber, ReadArray));
        ReadCurrentChar;
      end;
    '0'..'9':
      begin
        FObjects.AddObject(TPdfObjectNumber.Create(ObjectNumber,
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
          ReadCurrentChar
        else
          FStream.Position := FStream.Position - 8;
      end;
      Exit;
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
      Number := Number + FormatSettings.DecimalSeparator;
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

function TPdfFileReader.ReadArray: TPdfArray;
var
  IntValue: Integer;
  RealValue: Double;
  IsIntValue: Boolean;
begin
  Result := TPdfArray.Create;
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

function TPdfFileReader.ReadDictionaryObject: TPdfDictionary;
var
  Key, ValueText: AnsiString;
  IntValue, ObjectNumber, GenerationNumber: Integer;
  RealValue: Double;
  IsIntValue: Boolean;
  SubDictionary: TPdfDictionary;
  SubArray: TPdfArray;
begin
  ReadCurrentChar;
  SkipWhiteSpaces;

  Result := TPdfDictionary.Create;

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

function TPdfFileReader.ReadHexadecimalString: AnsiString;
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
      Result := Result + AnsiChar(Bytes[Index]);

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
  FCrossReferenceTable := TPdfCrossReferenceTable.Create(Start);
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

    FCrossReferenceTable.FCrossReferences[Index] := TPdfCrossReferenceEntry.Create(ByteOffset, GenerationNumber, Keyword = 'n');
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
