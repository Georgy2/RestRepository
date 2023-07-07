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
  DeleteAttribute = class (RestOperationAttribute)
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

function CombineUri(const ABegin : String; const AEnd : String) : String;
const Slash : Char = '/';
begin
  result := ABegin.TrimRight([Slash]) + Slash + AEnd.TrimLeft([Slash]);
end;

constructor RestOperationAttribute.Create(const APath: string; const AMethod: TRestRequestMethod; const AUriParamNames : String);
begin
  FPath := APath;
  FMethod := AMethod;
  FUriParamNames := SplitString(AUriParamNames, ',');
end;
function RestOperationAttribute.Invoke(const AHost : String; const ABaseApiURL: string; AAuthenticator : TCustomAuthenticator;
                  APayload : TObject; const AUriParamValues : TArray<TValue>; const AUriSegmentValue : TValue; AThreadPool : TThreadPool) : IFuture<Unique<TRESTResponse>>;
begin
  result := TRestInvoker.Invoke(CombineUri(AHost, ABaseApiURL), AAuthenticator, Path, Method, UriParamNames, APayload, AUriParamValues, AUriSegmentValue, AThreadPool);
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
constructor DeleteAttribute.Create(const APath: string; const AUriParamNames : String);
begin
  inherited Create(APath, TRestRequestMethod.rmDELETE, AUriParamNames);
end;

class procedure TRestInvoker.SetUriParams(ARestClient : TRestClient; const AUriParamNames : TArray<String>; const AUriParamValues : TArray<TValue>);
begin
  if Length(AUriParamNames) <> Length(AUriParamValues) then
    raise ERest.Parameters.Create(ERR_REQUIRED_PARAMS + String.Join(', ', AUriParamNames));

  for var i := 0 to Length(AUriParamNames) - 1 do
  begin
    var ValueAsString : String;
    try
      ValueAsString := AUriParamValues[i].ToString();
    except
      raise ERest.Parameters.Create(ERR_PARAMETER_NOT_STRINGABLE + IntToStr(i));
    end;
    ARestClient.AddParameter(AUriParamNames[i], ValueAsString, TRESTRequestParameterKind.pkQUERY);  //pkURLSEGMENT
  end;
end;
class function TRestInvoker.AddUriSegment(const AUri : String; const AValue : TValue) : String;
begin
  if AValue.IsEmpty then
    result := AUri
  else
  begin
    try
      result := CombineUri(AUri, AValue.ToString());
    except
      raise ERest.Parameters.Create(ERR_SEGMENT_NOT_STRINGABLE);
    end;
  end;
end;

class function TRestInvoker.Invoke(const AHostAndBaseApiURL: string; AAuthenticator : TCustomAuthenticator;
            const APath: string; const AMethod: TRestRequestMethod; const AUriParamNames : TArray<String>;
            APayload : TObject; const AUriParamValues : TArray<TValue>; const AUriSegmentValue : TValue; AThreadPool : TThreadPool) : IFuture<Unique<TRESTResponse>>;
begin

  //prepare (using parameters) inside sender thread...
  var FullPath := AddUriSegment(AHostAndBaseApiURL, AUriSegmentValue);
  var RestClient := TRESTClient.Create(FullPath);
  RestClient.Authenticator := AAuthenticator;
  RestClient.Accept := '*/*';
  SetUriParams(RestClient, AUriParamNames, AUriParamValues);
  //
  var Response := TRESTResponse.Create(nil);
  //
  var Request  := TRestRequest.Create(RestClient);
  Request.SynchronizedEvents := false; //!
  Request.Response := Response;
  Request.Method := AMethod;
  Request.Resource := APath;
  //
  if APayload <> nil then
  begin
    Request.AddBody(TJson.ObjectToJsonObject(APayload), ooREST);
  end;
  //...and do not use input parameters below

  //closures does not call smart record's .assign!
  var TaskFunc : TFunc<Unique<TRESTResponse>> := function() : Unique<TRESTResponse>
  begin
    try
    try
      Request.Execute();
      if Response.StatusCode <> 200 then
      begin
        var SpringErrMsg := TRestResponseExtractor<TSpringRestErrorMessage>.ResponseAsObjectOnErrorNil(Response);
        raise ERest.UnwantedResult.Create(Response.StatusCode, Response.Content, SpringErrMsg);
      end;
    except
      on ex : ERESTException do
      begin
        Response.Free();
        raise ERest.Framework.Create(ex.Message);
      end
      else
      begin
        Response.Free();
        raise;
      end;
    end;
    finally
      RestClient.Free();
    end;
    result := Response;
  end;

  result := TTask.Future<Unique<TRESTResponse>>(TaskFunc, AThreadPool);
end;

end.
