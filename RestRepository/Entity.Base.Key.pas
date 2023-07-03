unit Entity.Base.Key;

interface
uses
  SysUtils,
  Generics.Collections,
  Generics.Defaults,
  Rtti;

type
  KeyException = class (Exception);

  TFieldData = record
  private
    FField : TRttiField;
    FComparer : pointer;
  public
    constructor Create(AField : TRttiField);
    function Equals(const Left, Right : TValue) : boolean;
    function Hash(const AValue : TValue) : integer;
  end;

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
    constructor Create(AFieldNames : TArray<String>);
    function GetKey(const AEntity : T) : TComplexKeyData;
    function GetComparer() : IEqualityComparer<TComplexKeyData>;
  end;

const
  ERR_TYPE_NOT_SUPPORTED = 'Type not supported for key field: ';
  ERR_ARRAY_SIZES_NOT_MATCH = 'Array sizes do not match';
  ERR_FIELD_NOT_FOUND = 'Field not found: ';

implementation
uses
  Utils.RttiContext,
  System.TypInfo,
  System.Hash;

constructor TFieldData.Create(AField : TRttiField);
begin
  FField := AField;

  if FField.FieldType.IsOrdinal then
  begin
    FComparer := TEqualityComparer<integer>.Default();
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    FComparer := TEqualityComparer<Int64>.Default();
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    FComparer := TEqualityComparer<Extended>.Default();
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    FComparer := TEqualityComparer<String>.Default();
  end
  else
    raise KeyException.Create(ERR_TYPE_NOT_SUPPORTED + FField.Name);
end;
function TFieldData.Equals(const Left, Right : TValue) : boolean;
begin
  if FField.FieldType.IsOrdinal then
  begin
    var Comparer := IEqualityComparer<integer>(FComparer);
    result := Comparer.Equals(Left.AsOrdinal, Right.AsOrdinal);
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    var Comparer := IEqualityComparer<Int64>(FComparer);
    result := Comparer.Equals(Left.AsInt64, Right.AsInt64);
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    var Comparer := IEqualityComparer<Extended>(FComparer);
    result := Comparer.Equals(Left.AsExtended, Right.AsExtended);
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    var Comparer := IEqualityComparer<String>(FComparer);
    result := Comparer.Equals(Left.AsString, Right.AsString);
  end
  else
    raise KeyException.Create('Unreachable: look at TFieldData.Create');
end;
function TFieldData.Hash(const AValue : TValue) : integer;
begin
  if FField.FieldType.IsOrdinal then
  begin
    var Comparer := IEqualityComparer<integer>(FComparer);
    result := Comparer.GetHashCode(AValue.AsOrdinal);
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    var Comparer := IEqualityComparer<Int64>(FComparer);
    result := Comparer.GetHashCode(AValue.AsInt64);
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    var Comparer := IEqualityComparer<Extended>(FComparer);
    result := Comparer.GetHashCode(AValue.AsExtended);
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    var Comparer := IEqualityComparer<String>(FComparer);
    result := Comparer.GetHashCode(AValue.AsString);
  end
  else
    raise KeyException.Create('Unreachable: look at TFieldData.Create');
end;

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

constructor TComplexKeyProducer<T>.Create(AFieldNames : TArray<String>);
begin
  inherited Create();

  FTypeOfT := GRttiCtx.GetType(TypeInfo(T));

  SetLength(FFields, Length(AFieldNames));
  for var I := 0 to Length(FFields) - 1 do
  begin
    var Field := FTypeOfT.GetField(AFieldNames[I]);
    if not assigned(Field) then
      raise KeyException.Create(ERR_FIELD_NOT_FOUND + AFieldNames[I]);

    FFields[I] := TFieldData.Create(Field);
  end;
end;
function TComplexKeyProducer<T>.GetKey(const AEntity : T) : TComplexKeyData;
var
  PData : pointer;
begin
  if FTypeOfT.IsInstance then
    PData := (ppointer(@AEntity))^
  else
    PData := pointer(@AEntity);

  SetLength(result.Values, Length(self.FFields));
  for var I := 0 to Length(FFields) - 1 do
    result.Values[I] := FFields[I].FField.GetValue(PData);
end;
function TComplexKeyProducer<T>.GetComparer() : IEqualityComparer<TComplexKeyData>;
begin
  result := TComplexKeyDataComparer.Create(FFields);
end;

end.
