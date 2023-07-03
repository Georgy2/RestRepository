unit Entity.Base;

interface
uses
  Entity.Base.Key,
  SysUtils,
  Rtti;

type
  EntityException = class (Exception);

  TEntity<T : class> = class
  public type
    KeyProducerType = TComplexKeyProducer<T>;
    KeyType = KeyProducerType.KeyType;
  private
    class var FStoredTypeCtor : TRttiMethod;
    class var FStoredType : TRttiType;
    class var FKeyProducer : IKeyProducer<T, KeyType>;

    class procedure ScanAttributes();
  public
    class constructor Create();

    function Clone() : T; virtual;
    procedure From(const AOriginal : T);

    class property KeyProducer : IKeyProducer<T, KeyType> read FKeyProducer;
  end;

  //attributes
  //only one allowed
  KeyAttribute = class (TCustomAttribute);
  //several is allowed
  ComplexKeyAttribute = class (TCustomAttribute);

  function FindDefaultConstructor(AType : TRttiType) : TRttiMethod;
  function ExtactFieldNames(const AFields : TArray<TRttiField>) : TArray<String>;
const
  ERR_KEY_AND_COMPLEXKEY_TOGETHER = 'Using <Key> and <ComplexKey> both together is not allowed';
  ERR_SEVERAL_KEY_ATTRIBS = 'Several <Key> attributes is not allowed, use <ComplexKey> instead';
  ERR_KEY_CTOR = 'Error creating key: ';
implementation
uses
  Utils.RttiContext;

function FindDefaultConstructor(AType : TRttiType) : TRttiMethod;
begin
  for var Method in AType.GetMethods() do
  begin
    if Method.IsConstructor and (Length(Method.GetParameters) = 0) then
      Exit(Method);
  end;
  Exit(nil);
end;
function ExtactFieldNames(const AFields : TArray<TRttiField>) : TArray<String>;
begin
  for var Field in AFields do
    result := result + [Field.Name];
end;

class procedure TEntity<T>.ScanAttributes();
begin
  var SingleKeyFields : TArray<TRttiField>;
  var ComplexKeyFields : TArray<TRttiField>;

  for var Field in FStoredType.GetFields() do
  begin
    for var Attrib in Field.GetAttributes() do
    begin
      if Attrib is KeyAttribute then
        SingleKeyFields := SingleKeyFields + [Field]
      else if Attrib is ComplexKeyAttribute then
        ComplexKeyFields := ComplexKeyFields + [Field]
      else
        ;
    end;
  end;

  //errors
  //single and complex both
  if (Length(SingleKeyFields) > 0) and (Length(ComplexKeyFields) > 0) then
    raise EntityException.Create(ERR_KEY_AND_COMPLEXKEY_TOGETHER);
  //more than one single
  if (Length(SingleKeyFields) > 1) then
    raise EntityException.Create(ERR_SEVERAL_KEY_ATTRIBS);

  //set
  try
    if (Length(SingleKeyFields) = 1) then
      FKeyProducer := KeyProducerType.Create(ExtactFieldNames(SingleKeyFields))
    else if (Length(ComplexKeyFields) > 0) then
      FKeyProducer := KeyProducerType.Create(ExtactFieldNames(ComplexKeyFields))
    else
      FKeyProducer := nil;
  except
    on E : KeyException do
      raise EntityException.Create(ERR_KEY_CTOR + E.Message);
    else
      raise;
  end;

end;

class constructor TEntity<T>.Create();
begin
  FStoredType := GRttiCtx.GetType(T);
  FStoredTypeCtor := FindDefaultConstructor(FStoredType);

  ScanAttributes();
end;
function TEntity<T>.Clone() : T;
begin
  result := FStoredTypeCtor.Invoke(T, []).AsType<T>;
  TEntity<T>(result).From(self);
end;
procedure TEntity<T>.From(const AOriginal : T);
var
  SrcType : TRTTIType;
  Field : TRttiField;
begin
  for Field in FStoredType.GetFields() do
  begin
    Field.SetValue(self, Field.GetValue(pointer(AOriginal)));
  end;
end;

end.
