unit Entity.Base.Key;

interface
uses
  Utils.Rtti,
  SysUtils,
  Generics.Defaults,
  Rtti;

type
  KeyException = class (Exception);

  //could be used as key in dictionary
  TComplexKeyData = record
    Values : TArray<TValue>;
  end;

  //comparer for the class from above
  TComplexKeyDataComparer = class (TInterfacedObject, IEqualityComparer<TComplexKeyData>)
  private
    FFields : TArray<TFieldData>;
  public
    constructor Create(const AFields : TArray<TFieldData>);
    function Equals(const Left, Right: TComplexKeyData): Boolean; reintroduce;
    function GetHashCode(const Value: TComplexKeyData): Integer; reintroduce;
  end;

  IKeyProducer<ObjectType, KeyType> = interface
    function GetKey(const AEntity : ObjectType) : KeyType;
    function GetComparer() : IEqualityComparer<KeyType>;
  end;

  //class holds some fields of T and can represent TComplexKeyData and its comparer from object of T
  TComplexKeyProducer<T> = class (TInterfacedObject, IKeyProducer<T, TComplexKeyData>)
  private
    FTypeOfT : TRttiType;
    FFields : TArray<TFieldData>;
  public type
    KeyType = TComplexKeyData;
  public
    constructor Create(const AFieldNames : TArray<String>);
    function GetKey(const AEntity : T) : KeyType;
    function GetComparer() : IEqualityComparer<KeyType>;
  end;

const
  ERR_TYPE_NOT_SUPPORTED = 'Type not supported for key field: ';
  ERR_ARRAY_SIZES_NOT_MATCH = 'Array sizes do not match';
  ERR_FIELD_NOT_FOUND = 'Field not found: ';
  ERR_FIELD_CTOR_ERROR = 'Field error: ';

implementation
uses
  Utils.RttiContext,
  System.TypInfo,
  System.Hash;

constructor TComplexKeyDataComparer.Create(const AFields : TArray<TFieldData>);
begin
  inherited Create();
  FFields := AFields;
end;
function TComplexKeyDataComparer.Equals(const Left, Right: TComplexKeyData): Boolean;
begin
  if (Length(Left.Values) <> Length(FFields))
  or (Length(Right.Values) <> Length(FFields)) then
    raise KeyException.Create(ERR_ARRAY_SIZES_NOT_MATCH);

  for var I := 0 to Length(FFields) - 1 do
    if not FFields[I].Equals(Left.Values[I], Right.Values[I]) then
      Exit(false);

  Exit(true);
end;
function TComplexKeyDataComparer.GetHashCode(const Value: TComplexKeyData): Integer;
begin
  if (Length(Value.Values) <> Length(FFields)) then
    raise KeyException.Create(ERR_ARRAY_SIZES_NOT_MATCH);

  var Hash : Int64 := 17;

  for var I := 0 to Length(Value.Values) - 1 do
    Hash := Hash * 31 + FFields[I].Hash(Value.Values[I]);

  result := Integer(Hash mod MaxInt);
end;

constructor TComplexKeyProducer<T>.Create(const AFieldNames : TArray<String>);
begin
  inherited Create();

  FTypeOfT := GRttiCtx.GetType(TypeInfo(T));

  SetLength(FFields, Length(AFieldNames));
  for var I := 0 to Length(FFields) - 1 do
  begin
    var Field := FTypeOfT.GetField(AFieldNames[I]);
    if not assigned(Field) then
      raise KeyException.Create(ERR_FIELD_NOT_FOUND + AFieldNames[I]);

    try
      FFields[I] := TFieldData.Create(Field);
    except
      on E : RttiException do
        raise KeyException.Create(ERR_FIELD_CTOR_ERROR + E.Message);
      else
        raise;
    end;
  end;
end;
function TComplexKeyProducer<T>.GetKey(const AEntity : T) : KeyType;
var
  PData : pointer;
begin
  if FTypeOfT.IsInstance then
    PData := (ppointer(@AEntity))^
  else
    PData := pointer(@AEntity);

  SetLength(result.Values, Length(self.FFields));
  for var I := 0 to Length(FFields) - 1 do
    result.Values[I] := FFields[I].Field.GetValue(PData);
end;
function TComplexKeyProducer<T>.GetComparer() : IEqualityComparer<KeyType>;
begin
  result := TComplexKeyDataComparer.Create(FFields);
end;

end.
