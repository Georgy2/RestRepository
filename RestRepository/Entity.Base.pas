unit Entity.Base;

interface
uses
  Entity.Base.Key,
  Entity.Base.Version,
  SysUtils,
  Rtti;

type
  EntityException = class (Exception);

  TEntity<T : class> = class
  public type
    KeyProducerType = TComplexKeyProducer<T>;
    KeyType = KeyProducerType.KeyType;
    VersionProducerType = TVersionProducer<T>;
    VersionType = TVersionProducer<T>.VersionType;
  private
    class var FStoredTypeCtor : TRttiMethod;
    class var FStoredType : TRttiType;
    class var FKeyProducer : IKeyProducer<T, KeyType>;
    class var FVersionProducer : IVersionProducer<T, VersionType>;

    class procedure ScanAttributes();
  public
    class constructor Create();

    ///  <summary>
    ///  Create copy of self
    ///  </summary>
    ///  <returns>
    ///  new copy
    ///  </returns>
    function Clone() : T; virtual;
    ///  <summary>
    ///  set all from the source
    ///  </summary>
    ///  <param name = 'AOriginal'>
    ///  source
    ///  </param>
    procedure From(const AOriginal : T);

    class property KeyProducer : IKeyProducer<T, KeyType> read FKeyProducer;
    class property VersionProducer : IVersionProducer<T, VersionType> read FVersionProducer;
  end;

  //attributes
  //only one allowed
  KeyAttribute = class (TCustomAttribute);
  //several is allowed
  ComplexKeyAttribute = class (TCustomAttribute);
  //version
  VersionAttribute = class (TCustomAttribute);

  function ExtactFieldNames(const AFields : TArray<TRttiField>) : TArray<String>;
const
  ERR_KEY_AND_COMPLEXKEY_TOGETHER = 'Using <Key> and <ComplexKey> both together is not allowed';
  ERR_SEVERAL_KEY_ATTRIBS = 'Several <Key> attributes is not allowed, use <ComplexKey> instead';
  ERR_SEVERAL_VERSION_ATTRIBS = 'Several <Version> attributes is not allowed';
  ERR_KEY_CTOR = 'Error creating key: ';
  ERR_VERSION_CTOR = 'Error creating version: ';
implementation
uses
  Utils.Rtti,
  Utils.RttiContext;

function ExtactFieldNames(const AFields : TArray<TRttiField>) : TArray<String>;
begin
  for var Field in AFields do
    result := result + [Field.Name];
end;

class procedure TEntity<T>.ScanAttributes();
begin
  var SingleKeyFields : TArray<TRttiField>;
  var ComplexKeyFields : TArray<TRttiField>;
  var VersionFields : TArray<TRttiField>;

  for var Field in FStoredType.GetFields() do
  begin
    for var Attrib in Field.GetAttributes() do
    begin
      if Attrib is KeyAttribute then
        SingleKeyFields := SingleKeyFields + [Field]
      else if Attrib is ComplexKeyAttribute then
        ComplexKeyFields := ComplexKeyFields + [Field]
      else if Attrib is VersionAttribute then
        VersionFields := VersionFields + [Field]
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
  //more than one version field
  if (Length(VersionFields) > 1) then
    raise EntityException.Create(ERR_SEVERAL_VERSION_ATTRIBS);

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

  try
    if (Length(VersionFields) > 0) then
      FVersionProducer := VersionProducerType.Create(VersionFields[0].Name)
    else
      FVersionProducer := nil;
  except
    on E : VersionException do
      raise EntityException.Create(ERR_VERSION_CTOR + E.Message);
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
