unit PasPdfFileElements;

interface

uses
  Classes, SysUtils, Contnrs;

type
  TPdfFileArray = class;
  TPdfFileDictionary = class;

  TPdfFileDictionaryCustomItem = class
  private
    FKey: AnsiString;
  public
    constructor Create(Key: AnsiString); virtual;

    property Key: AnsiString read FKey;
  end;

  TPdfFileDictionaryItemString = class(TPdfFileDictionaryCustomItem)
  private
    FValue: AnsiString;
  public
    constructor Create(Key, Value: AnsiString); reintroduce;

    property Value: AnsiString read FValue;
  end;

  TPdfFileDictionaryItemInteger = class(TPdfFileDictionaryCustomItem)
  private
    FValue: Integer;
  public
    constructor Create(Key: AnsiString; Value: Integer); reintroduce;

    property Value: Integer read FValue;
  end;

  TPdfFileDictionaryItemReal = class(TPdfFileDictionaryCustomItem)
  private
    FValue: Double;
  public
    constructor Create(Key: AnsiString; Value: Double); reintroduce;

    property Value: Double read FValue;
  end;

  TPdfFileDictionaryItemBoolean = class(TPdfFileDictionaryCustomItem)
  private
    FValue: Boolean;
  public
    constructor Create(Key: AnsiString; Value: Boolean); reintroduce;

    property Value: Boolean read FValue;
  end;

  TPdfFileDictionaryItemReference = class(TPdfFileDictionaryCustomItem)
  private
    FObjectNumber: Integer;
    FGenerationNumber: Integer;
  public
    constructor Create(Key: AnsiString; ObjectNumber, GenerationNumber: Integer); reintroduce;

    property ObjectNumber: Integer read FObjectNumber;
    property GenerationNumber: Integer read FGenerationNumber;
  end;

  TPdfFileDictionaryItemDictionary = class(TPdfFileDictionaryCustomItem)
  private
    FValue: TPdfFileDictionary;
  public
    constructor Create(Key: AnsiString; Value: TPdfFileDictionary); reintroduce;
    destructor Destroy; override;

    property Value: TPdfFileDictionary read FValue;
  end;

  TPdfFileDictionaryItemArray = class(TPdfFileDictionaryCustomItem)
  private
    FValue: TPdfFileArray;
  public
    constructor Create(Key: AnsiString; Value: TPdfFileArray); reintroduce;
    destructor Destroy; override;

    property Value: TPdfFileArray read FValue;
  end;

  TPdfFileDictionary = class
  private
    FList: TObjectList;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure Add(Key, Value: AnsiString); overload;
    procedure Add(Key: AnsiString; Value: Integer); overload;
    procedure Add(Key: AnsiString; Value: Double); overload;
    procedure Add(Key: AnsiString; Value: Boolean); overload;
    procedure Add(Key: AnsiString; Value: TPdfFileDictionary); overload;
    procedure Add(Key: AnsiString; Value: TPdfFileArray); overload;
  end;

  TPdfFileArray = class
  private
    FList: TObjectList;
  public
    procedure Add(Value: string); overload;
    procedure Add(Value: AnsiString); overload;
    procedure Add(Value: Integer); overload;
    procedure Add(Value: Double); overload;
    procedure Add(Value: TPdfFileArray); overload;
    procedure AddNull;
  end;

  TPdfFileCustomObject = class
  private
    FObjectNumber: Integer;
    FGenerationNumber: Integer;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer); overload; virtual;

    property ObjectNumber: Integer read FObjectNumber;
    property GenerationNumber: Integer read FGenerationNumber;
  end;

  TPdfFileObjectNumber = class(TPdfFileCustomObject)
  private
    FValue: Double;
  public
    constructor Create(ObjectNumber, GenerationNumber:Integer; Value: Double); overload;

    property Value: Double read FValue;
  end;

  TPdfFileObjectString = class(TPdfFileCustomObject)
  private
    FValue: string;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer; Value: string); overload;

    property Value: string read FValue;
  end;

  TPdfFileObjectStream = class(TPdfFileCustomObject)
  private
    FDictionary: TPdfFileDictionary;
    FStream: TMemoryStream;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer;
      Dictionary: TPdfFileDictionary; Stream: TMemoryStream); reintroduce;

    property Stream: TMemoryStream read FStream;
  end;

  TPdfFileObjectDictionary = class(TPdfFileCustomObject)
  private
    FDictionary: TPdfFileDictionary;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer; Dictionary: TPdfFileDictionary); overload;
    destructor Destroy; override;

    property Dictionary: TPdfFileDictionary read FDictionary;
  end;

  TPdfFileObjectArray = class(TPdfFileCustomObject)
  private
    FArray: TPdfFileArray;
  public
    constructor Create(ObjectNumber, GenerationNumber: Integer; &Array: TPdfFileArray); overload;
    destructor Destroy; override;

    property &Array: TPdfFileArray read FArray;
  end;

  TPdfFileObjectList = class
  private
    FList: TObjectList;
    function GetItem(Index: Integer): TPdfFileCustomObject;
    function GetCount: Integer;
  public
    constructor Create;

    procedure AddObject(PdfObject: TPdfFileCustomObject);

    property Items[Index: Integer]: TPdfFileCustomObject read GetItem;
    property Count: Integer read GetCount;
  end;


implementation

{ TPdfFileDictionaryCustomItem }

constructor TPdfFileDictionaryCustomItem.Create(Key: AnsiString);
begin
  inherited Create;

  FKey := Key;
end;


{ TPdfFileDictionaryItemString }

constructor TPdfFileDictionaryItemString.Create(Key, Value: AnsiString);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfFileDictionaryItemInteger }

constructor TPdfFileDictionaryItemInteger.Create(Key: AnsiString; Value: Integer);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfFileDictionaryItemReal }

constructor TPdfFileDictionaryItemReal.Create(Key: AnsiString; Value: Double);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfFileDictionaryItemBoolean }

constructor TPdfFileDictionaryItemBoolean.Create(Key: AnsiString; Value: Boolean);
begin
  inherited Create(Key);

  FValue := Value;
end;


{ TPdfFileDictionaryItemReference }

constructor TPdfFileDictionaryItemReference.Create(Key: AnsiString; ObjectNumber,
  GenerationNumber: Integer);
begin
  inherited Create(Key);

  FObjectNumber := ObjectNumber;
  FGenerationNumber := GenerationNumber;
end;


{ TPdfFileDictionaryItemDictionary }

constructor TPdfFileDictionaryItemDictionary.Create(Key: AnsiString;
  Value: TPdfFileDictionary);
begin
  inherited Create(Key);

  FValue := Value;
end;

destructor TPdfFileDictionaryItemDictionary.Destroy;
begin
  FValue.Free;

  inherited;
end;


{ TPdfFileDictionaryItemArray }

constructor TPdfFileDictionaryItemArray.Create(Key: AnsiString;
  Value: TPdfFileArray);
begin
  inherited Create(Key);

  FValue := Value;
end;

destructor TPdfFileDictionaryItemArray.Destroy;
begin

  inherited;
end;


{ TPdfFileDictionary }

constructor TPdfFileDictionary.Create;
begin
  inherited;

  FList := TObjectList.Create;
end;

destructor TPdfFileDictionary.Destroy;
begin
  FList.Free;

  inherited;
end;

procedure TPdfFileDictionary.Add(Key, Value: AnsiString);
begin
  FList.Add(TPdfFileDictionaryItemString.Create(Key, Value));
end;

procedure TPdfFileDictionary.Add(Key: AnsiString; Value: TPdfFileDictionary);
begin
  FList.Add(TPdfFileDictionaryItemDictionary.Create(Key, Value));
end;

procedure TPdfFileDictionary.Add(Key: AnsiString; Value: Integer);
begin
  FList.Add(TPdfFileDictionaryItemInteger.Create(Key, Value));
end;

procedure TPdfFileDictionary.Add(Key: AnsiString; Value: Double);
begin
  FList.Add(TPdfFileDictionaryItemReal.Create(Key, Value));
end;

procedure TPdfFileDictionary.Add(Key: AnsiString; Value: Boolean);
begin
  FList.Add(TPdfFileDictionaryItemBoolean.Create(Key, Value));
end;

procedure TPdfFileDictionary.Add(Key: AnsiString; Value: TPdfFileArray);
begin
  FList.Add(TPdfFileDictionaryItemArray.Create(Key, Value));
end;


{ TPdfFileArray }

procedure TPdfFileArray.Add(Value: string);
begin

end;

procedure TPdfFileArray.Add(Value: Integer);
begin

end;

procedure TPdfFileArray.Add(Value: Double);
begin

end;

procedure TPdfFileArray.Add(Value: TPdfFileArray);
begin

end;

procedure TPdfFileArray.Add(Value: AnsiString);
begin

end;

procedure TPdfFileArray.AddNull;
begin

end;


{ TPdfFileCustomObject }

constructor TPdfFileCustomObject.Create(ObjectNumber, GenerationNumber: Integer);
begin
  inherited Create;

  FObjectNumber := ObjectNumber;
  FGenerationNumber := GenerationNumber;
end;


{ TPdfFileObjectNumber }

constructor TPdfFileObjectNumber.Create(ObjectNumber, GenerationNumber: Integer;
  Value: Double);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FValue := Value;
end;


{ TPdfFileObjectString }

constructor TPdfFileObjectString.Create(ObjectNumber, GenerationNumber: Integer;
  Value: string);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FValue := Value;
end;


{ TPdfFileObjectStream }

constructor TPdfFileObjectStream.Create(ObjectNumber, GenerationNumber: Integer;
  Dictionary: TPdfFileDictionary; Stream: TMemoryStream);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FDictionary := Dictionary;
  FStream := Stream;
end;


{ TPdfFileObjectDictionary }

constructor TPdfFileObjectDictionary.Create(ObjectNumber,
  GenerationNumber: Integer; Dictionary: TPdfFileDictionary);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FDictionary := Dictionary;
end;

destructor TPdfFileObjectDictionary.Destroy;
begin
  FDictionary.Free;

  inherited;
end;


{ TPdfFileObjectArray }

constructor TPdfFileObjectArray.Create(ObjectNumber, GenerationNumber: Integer;
  &Array: TPdfFileArray);
begin
  inherited Create(ObjectNumber, GenerationNumber);

  FArray := &Array;
end;

destructor TPdfFileObjectArray.Destroy;
begin
  FArray.Free;

  inherited;
end;


{ TPdfFileObjectList }

procedure TPdfFileObjectList.AddObject(PdfObject: TPdfFileCustomObject);
begin
  FList.Add(PdfObject);
end;

constructor TPdfFileObjectList.Create;
begin
  FList := TObjectList.Create;
end;

function TPdfFileObjectList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TPdfFileObjectList.GetItem(Index: Integer): TPdfFileCustomObject;
begin
  Result := TPdfFileCustomObject(FList.Items[Index]);
end;


end.
