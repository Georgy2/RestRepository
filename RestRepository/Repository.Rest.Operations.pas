unit Repository.Rest.Operations;

interface
uses
  Memory,
  //
  Threading,
  Rest.Client,
  Rest.Types,
  Rtti;
type

  //attributes
  //basic
  RestOperationAttribute = class (TCustomAttribute)
  private
    FPath : String;
    FMethod : TRestRequestMethod;
    FUriParamNames : TArray<String>;
  public
    constructor Create(const APath: string; const AMethod: TRestRequestMethod; const AUriParamNames : String);
    property Path : String read FPath;
    property Method : TRestRequestMethod read FMethod;
    property UriParamNames : TArray<String> read FUriParamNames;

    ///  <summary> TRestInvoker.Invoke </summary>
    function Invoke(const AHost : String; const ABaseApiURL: string; AAuthenticator : TCustomAuthenticator;
                  APayload : TObject; const AUriParamValues : TArray<TValue>; const AUriSegmentValue : TValue; AThreadPool : TThreadPool) : IFuture<Unique<TRESTResponse>>;
                  virtual;
  end;
  //aliases
  GetAttribute = class (RestOperationAttribute)
  public
    constructor Create(const APath: string; const AUriParamNames : String = '');
  end;
  PostAttribute = class (RestOperationAttribute)
  public
    constructor Create(const APath: string; const AUriParamNames : String = '');
  end;
  PutAttribute = class (RestOperationAttribute)
  public
    constructor Create(const APath: string; const AUriParamNames : String = '');
  end;

  //worker
  TRestInvoker = class
    //raise ERest.Parameters
    class procedure SetUriParams(ARestClient : TRestClient; const AUriParamNames : TArray<String>; const AUriParamValues : TArray<TValue>);
    class function AddUriSegment(const AUri : String; const AValue : TValue) : String;
  public
    ///  <summary> Asynchronous invocation of a REST request </summary>
    ///  <param name="AHostAndBaseApiURL"> </param>
    ///  <param name="AAuthenticator"> </param>
    ///  <param name="APath"> </param>
    ///  <param name="AMethod"> </param>
    ///  <param name="AUriParamNames"> </param>
    ///  <param name="APayload"> Any object or nil </param>
    ///  <param name="AUriParamValues"> </param>
    ///  <param name="AThreadPool"> </param>
    ///  <remarks>
    ///  raise ERest.Base descendants:
    ///     ERest.Parameters  - when invalid input parameters
    ///  </remarks>
    ///  <returns> Future with response </returns>
    class function Invoke(const AHostAndBaseApiURL: string; AAuthenticator : TCustomAuthenticator;
            const APath: string; const AMethod: TRestRequestMethod; const AUriParamNames : TArray<String>;
            APayload : TObject; const AUriParamValues : TArray<TValue>; const AUriSegmentValue : TValue; AThreadPool : TThreadPool) : IFuture<Unique<TRESTResponse>>;
  end;

  const
    ERR_REQUIRED_PARAMS = 'Required parameters: ';
    ERR_SEGMENT_NOT_STRINGABLE = 'URI segment parameter can not be casted to string';
    ERR_PARAMETER_NOT_STRINGABLE = 'URI parameter can not be casted to string: ';
implementation
uses
  Repository.Rest.ResponseExtractor,
  Repository.Rest.Errors,
  Rest.Json,
  SysUtils,
  StrUtils;

constructor RestOperationAttribute.Create(const APath: string; const AMethod: TRestRequestMethod; const AUriParamNames : String);
begin
  FPath := APath;
  FMethod := AMethod;
  FUriParamNames := SplitString(AUriParamNames, ',');
end;
function RestOperationAttribute.Invoke(const AHost : String; const ABaseApiURL: string; AAuthenticator : TCustomAuthenticator;
                  APayload : TObject; const AUriParamValues : TArray<TValue>; const AUriSegmentValue : TValue; AThreadPool : TThreadPool) : IFuture<Unique<TRESTResponse>>;
begin
  result := TRestInvoker.Invoke(AHost + ABaseApiURL, AAuthenticator, Path, Method, UriParamNames, APayload, AUriParamValues, AUriSegmentValue, AThreadPool);
end;

constructor GetAttribute.Create(const APath: string; const AUriParamNames : String);
begin
  inherited Create(APath, TRestRequestMethod.rmGET, AUriParamNames);
end;
constructor PostAttribute.Create(const APath: string; const AUriParamNames : String);
begin
  inherited Create(APath, TRestRequestMethod.rmPOST, AUriParamNames);
end;
constructor PutAttribute.Create(const APath: string; const AUriParamNames : String);
begin
  inherited Create(APath, TRestRequestMethod.rmPUT, AUriParamNames);
end;

class procedure TRestInvoker.SetUriParams(ARestClient : TRestClient; const AUriParamNames : TArray<String>; const AUriParamValues : TArray<TValue>);
begin
  if Length(AUriParamNames) <> Length(AUriParamValues) then
    raise ERest.Parameters.Create(ERR_REQUIRED_PARAMS + String.Join(', ', AUriParamNames));

  for var i := 0 to Length(AUriParamNames) - 1 do
  begin
    var ValueAsString : TValue;
    if not AUriParamValues[i].TryCast(TypeInfo(String), ValueAsString) then
      raise ERest.Parameters.Create(ERR_PARAMETER_NOT_STRINGABLE + IntToStr(i));
    ARestClient.AddParameter(AUriParamNames[i], ValueAsString.AsString, TRESTRequestParameterKind.pkQUERY);  //pkURLSEGMENT
  end;
end;
class function TRestInvoker.AddUriSegment(const AUri : String; const AValue : TValue) : String;
begin
  if AValue.IsEmpty then
    result := AUri
  else
  begin
    var ValueAsString : TValue;
    if not AValue.TryCast(TypeInfo(String), ValueAsString) then
      raise ERest.Parameters.Create(ERR_SEGMENT_NOT_STRINGABLE);
    result := AUri + '/' + ValueAsString.AsString;
  end;
end;

class function TRestInvoker.Invoke(const AHostAndBaseApiURL: string; AAuthenticator : TCustomAuthenticator;
            const APath: string; const AMethod: TRestRequestMethod; const AUriParamNames : TArray<String>;
            APayload : TObject; const AUriParamValues : TArray<TValue>; const AUriSegmentValue : TValue; AThreadPool : TThreadPool) : IFuture<Unique<TRESTResponse>>;
begin

  //prepare (using parameters) inside sender thread...
  var FullPath := AddUriSegment(AHostAndBaseApiURL, AUriSegmentValue);
  var RestClient : Unique<TRESTClient> := TRESTClient.Create(FullPath);
  RestClient.Get().Authenticator := AAuthenticator;
  RestClient.Get().Accept := '*/*';
  SetUriParams(RestClient.Get(), AUriParamNames, AUriParamValues);
  //
  var Response : Unique<TRESTResponse> := TRESTResponse.Create(nil);
  //
  var Request : Unique<TRestRequest> := TRestRequest.Create(RestClient.Get());
  Request.Get().SynchronizedEvents := false; //!
  Request.Get().Response := Response.Get();
  Request.Get().Method := AMethod;
  Request.Get().Resource := APath;
  //
  if APayload <> nil then
  begin
    Request.Get().AddBody(TJson.ObjectToJsonObject(APayload), ooREST);
  end;
  //...and do not use input parameters below

  var TaskFunc : TFunc<Unique<TRESTResponse>> := function() : Unique<TRESTResponse>
  begin
    try
      Request.Get().Execute();
      if Response.Get().StatusCode <> 200 then
      begin
        var SpringErrMsg := TRestResponseExtractor<TSpringRestErrorMessage>.ResponseAsObjectOnErrorNil(Response.Get());
        raise ERest.UnwantedResult.Create(Response.Get().StatusCode, Response.Get().Content, SpringErrMsg);
      end;
    except
      on ex : ERESTException do
        raise ERest.Framework.Create(ex.Message)
      else
        raise;
    end;

    result := Response;
  end;

  result := TTask.Future<Unique<TRESTResponse>>(TaskFunc, AThreadPool);
end;

end.
