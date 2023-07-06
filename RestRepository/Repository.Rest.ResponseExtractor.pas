unit Repository.Rest.ResponseExtractor;

interface
uses
  Memory,
  //
  Rtti,
  Rest.Client,
  Generics.Collections;

type
  IResponseExtractor<T : class> = interface
    function AsObjectsList() : TObjectList<T>;
    function AsObject() : T;
    function AsObjectType(AClass : TClass) : TObject;
  end;

  ///  <remarks>
  ///  raise ERest.Base descendants : ERest.ResponseExtractor
  ///  </remarks>
  TRestResponseExtractor<T : class> = class (TInterfacedObject, IResponseExtractor<T>)
  private
    FResponse : Unique<TRestResponse>;
  public
    constructor Create(AResponse : Unique<TRestResponse>);
    function AsObjectsList() : TObjectList<T>;
    function AsObject() : T;
    function AsObjectType(AClass : TClass) : TObject;

    class function ResponseAsObject(AResponse : TRestResponse) : T; overload;
    class function ResponseAsObject(AResponse : TRestResponse; AClass : TClass) : TObject; overload;
    class function ResponseAsObjectOnErrorNil(AResponse : TRestResponse) : T;
  end;

const
  ERR_NOT_JSON_ARRAY = 'Response value is not valid Json array: ';
  ERR_NOT_JSON_OBJECT = 'Response value is not valid Json object: ';
  ERR_CONVERSION = 'Conversion error: ';
implementation
uses
  Repository.Rest.Errors,
  Utils.RttiContext,
  Utils.Rtti,
  Json,
  Rest.Json,
  Rest.JsonReflect;

constructor TRestResponseExtractor<T>.Create(AResponse : Unique<TRestResponse>);
begin
  FResponse := AResponse;
end;
function TRestResponseExtractor<T>.AsObjectsList() : TObjectList<T>;
begin
  var JVal := FResponse.Get().JSONValue;
  if (JVal = nil) or not (JVal is TJSONArray) then
    raise ERest.ResponseExtractor.Create(ERR_NOT_JSON_ARRAY + FResponse.Get().Content);

  var JArr := JVal as TJSONArray;
  var Objects := Unique<TObjectList<T>>(TObjectList<T>.Create());

  var CTor := FindDefaultConstructor(GRttiCtx.GetType(T));
  var NewObject : T;

  for var i := 0 to JArr.Count - 1 do
  begin
    NewObject := CTor.Invoke(T, []).AsType<T>();
    try
      var JObj := JArr.Items[i] as TJSONObject;
      TJson.JsonToObject(NewObject, JObj);
    except
      on ex : EConversionError do
      begin
        NewObject.free();
        raise ERest.ResponseExtractor.Create(ERR_CONVERSION + ex.Message);
      end
      else
      begin
        NewObject.free();
        raise;
      end;
    end;
    Objects.Get().Add(NewObject);
  end;

  Result := Objects.Release();
end;
function TRestResponseExtractor<T>.AsObject() : T;
begin
  result := ResponseAsObject(FResponse.Get());
end;
function TRestResponseExtractor<T>.AsObjectType(AClass : TClass) : TObject;
begin
  result := ResponseAsObject(FResponse.Get(), AClass);
end;

class function TRestResponseExtractor<T>.ResponseAsObject(AResponse : TRestResponse) : T;
begin
  result := ResponseAsObject(AResponse, T) as T;
end;
class function TRestResponseExtractor<T>.ResponseAsObject(AResponse : TRestResponse; AClass : TClass) : TObject;
begin
  var JVal := AResponse.JSONValue;
  if (JVal = nil) or not (JVal is TJSONObject) then
    raise ERest.ResponseExtractor.Create(ERR_NOT_JSON_OBJECT + AResponse.Content);

  var CTor := FindDefaultConstructor(GRttiCtx.GetType(AClass));
  result := nil;
  try
    result := CTor.Invoke(AClass, []).AsObject();
    TJson.JsonToObject(result, JVal as TJSONObject);
  except
    on ex : EConversionError do
    begin
      result.Free();
      raise ERest.ResponseExtractor.Create(ERR_CONVERSION + ex.Message);
    end
    else
    begin
      result.Free();
      raise;
    end;
  end;
end;

class function TRestResponseExtractor<T>.ResponseAsObjectOnErrorNil(AResponse : TRestResponse) : T;
begin
  try
    result := ResponseAsObject(AResponse);
  except
    result := nil;
  end;
end;

end.
