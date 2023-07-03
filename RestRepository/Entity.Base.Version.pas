unit Entity.Base.Version;

interface

uses
  Utils.Rtti,
  SysUtils,
  Generics.Defaults,
  Rtti;

type
  VersionException = class (Exception);

  TVersionData = record
    Value : TValue;

    constructor Create(const AValue : TValue);
    class operator Implicit(const AValue : TValue) : TVersionData;
  end;

  TVersionDataComparer = class (TInterfacedObject, IComparer<TVersionData>)
  private
    FField : TFieldData;
  public
    constructor Create(const AField : TFieldData);
    function Compare(const Left, Right : TVersionData) : integer;
  end;

  IVersionProducer<ObjectType, VersionType> = interface
    function GetVersion(const AEntity : ObjectType) : VersionType;
    function GetComparer() : IComparer<VersionType>;
  end;

  TVersionProducer<T> = class (TInterfacedObject, IVersionProducer<T, TVersionData>)
  private
    FTypeOfT : TRttiType;
    FField : TFieldData;
  public type
    VersionType = TVersionData;
  public
    constructor Create(const AFieldName : String);
    function GetVersion(const AEntity : T) : VersionType;
    function GetComparer() : IComparer<VersionType>;
  end;

const
  ERR_FIELD_NOT_FOUND = 'Field not found: ';
  ERR_FIELD_CTOR_ERROR = 'Field error: ';

implementation
uses
  Utils.RttiContext;

constructor TVersionData.Create(const AValue : TValue);
begin
  self.Value := AValue;
end;
class operator TVersionData.Implicit(const AValue : TValue) : TVersionData;
begin
  result.Value := AValue;
end;

constructor TVersionDataComparer.Create(const AField : TFieldData);
begin
  inherited Create();
  FField := AField;
end;
function TVersionDataComparer.Compare(const Left, Right : TVersionData) : integer;
begin
  result := FField.Compare(Left.Value, Right.Value);
end;

constructor TVersionProducer<T>.Create(const AFieldName : String);
begin
  inherited Create();

  FTypeOfT := GRttiCtx.GetType(TypeInfo(T));

  var RttiField := FTypeOfT.GetField(AFieldName);
  if not assigned(RttiField) then
    raise VersionException.Create(ERR_FIELD_NOT_FOUND + AFieldName);

  try
    FField := TFieldData.Create(RttiField);
  except
    on E : RttiException do
      raise VersionException.Create(ERR_FIELD_CTOR_ERROR + E.Message);
    else
      raise;
  end;
end;
function TVersionProducer<T>.GetVersion(const AEntity : T) : VersionType;
var
  PData : pointer;
begin
  if FTypeOfT.IsInstance then
    PData := (ppointer(@AEntity))^
  else
    PData := pointer(@AEntity);

  result.Value := FField.Field.GetValue(PData);
end;
function TVersionProducer<T>.GetComparer() : IComparer<VersionType>;
begin
  result := TVersionDataComparer.Create(FField);
end;

end.
