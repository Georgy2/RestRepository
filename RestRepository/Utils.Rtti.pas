unit Utils.Rtti;

interface
uses
  SysUtils,
  Rtti;

type
  RttiException = class (Exception);

  TFieldData = record
  private
    FField : TRttiField;
    FEqualityComparer : pointer;
    FComparer : pointer;
  public
    constructor Create(AField : TRttiField);
    function Equals(const Left, Right : TValue) : boolean;
    function Hash(const AValue : TValue) : integer;
    function Compare(const Left, Right : TValue) : integer;

    property Field : TRttiField read FField;
  end;

  function FindDefaultConstructor(AType : TRttiType) : TRttiMethod;
const
  ERR_TYPE_NOT_SUPPORTED = 'Type not supported: ';

implementation
uses
  TypInfo,
  Generics.Defaults;

function FindDefaultConstructor(AType : TRttiType) : TRttiMethod;
begin
  for var Method in AType.GetMethods() do
  begin
    if Method.IsConstructor and (Length(Method.GetParameters) = 0) then
      Exit(Method);
  end;
  Exit(nil);
end;

constructor TFieldData.Create(AField : TRttiField);
begin
  FField := AField;

  if FField.FieldType.IsOrdinal then
  begin
    FEqualityComparer := TEqualityComparer<integer>.Default();
    FComparer := TComparer<integer>.Default();
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    FEqualityComparer := TEqualityComparer<Int64>.Default();
    FComparer := TComparer<Int64>.Default();
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    FEqualityComparer := TEqualityComparer<Extended>.Default();
    FComparer := TComparer<Extended>.Default();
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    FEqualityComparer := TEqualityComparer<String>.Default();
    FComparer := TComparer<String>.Default();
  end
  else
    raise RttiException.Create(ERR_TYPE_NOT_SUPPORTED + FField.Name);
end;
function TFieldData.Equals(const Left, Right : TValue) : boolean;
begin
  if FField.FieldType.IsOrdinal then
  begin
    var Comparer := IEqualityComparer<integer>(FEqualityComparer);
    result := Comparer.Equals(Left.AsOrdinal, Right.AsOrdinal);
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    var Comparer := IEqualityComparer<Int64>(FEqualityComparer);
    result := Comparer.Equals(Left.AsInt64, Right.AsInt64);
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    var Comparer := IEqualityComparer<Extended>(FEqualityComparer);
    result := Comparer.Equals(Left.AsExtended, Right.AsExtended);
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    var Comparer := IEqualityComparer<String>(FEqualityComparer);
    result := Comparer.Equals(Left.AsString, Right.AsString);
  end
  else
    raise RttiException.Create('Unreachable: look at TFieldData.Create');
end;
function TFieldData.Hash(const AValue : TValue) : integer;
begin
  if FField.FieldType.IsOrdinal then
  begin
    var Comparer := IEqualityComparer<integer>(FEqualityComparer);
    result := Comparer.GetHashCode(AValue.AsOrdinal);
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    var Comparer := IEqualityComparer<Int64>(FEqualityComparer);
    result := Comparer.GetHashCode(AValue.AsInt64);
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    var Comparer := IEqualityComparer<Extended>(FEqualityComparer);
    result := Comparer.GetHashCode(AValue.AsExtended);
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    var Comparer := IEqualityComparer<String>(FEqualityComparer);
    result := Comparer.GetHashCode(AValue.AsString);
  end
  else
    raise RttiException.Create('Unreachable: look at TFieldData.Create');
end;
function TFieldData.Compare(const Left, Right : TValue) : integer;
begin
  if FField.FieldType.IsOrdinal then
  begin
    var Comparer := IComparer<integer>(FComparer);
    result := Comparer.Compare(Left.AsOrdinal, Right.AsOrdinal);
  end
  else if FField.FieldType.Handle = TypeInfo(Int64) then
  begin
    var Comparer := IComparer<Int64>(FComparer);
    result := Comparer.Compare(Left.AsInt64, Right.AsInt64);
  end
  else if FField.FieldType is TRttiFloatType then
  begin
    var Comparer := IComparer<Extended>(FComparer);
    result := Comparer.Compare(Left.AsExtended, Right.AsExtended);
  end
  else if FField.FieldType.Handle = TypeInfo(String) then
  begin
    var Comparer := IComparer<String>(FComparer);
    result := Comparer.Compare(Left.AsString, Right.AsString);
  end
  else
    raise RttiException.Create('Unreachable: look at TFieldData.Create');
end;

end.
