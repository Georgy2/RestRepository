unit Repository.Rest;

interface

uses
  Memory,
  Repository.Base,
  Repository.Rest.Operations,
  Repository.Rest.ResponseExtractor,
  //
  Threading,
  Classes,
  SysUtils,
  RTTI,
  Rest.Client,
  Rest.Types,
  Generics.Collections,
  Generics.Defaults;
type
  BaseApiUrlAttribute = class (StoredAttribute);

  TFuturesHolder<T> = class
  private
    FFutures : TThreadList<IFuture<T>>;

    function Count() : integer;
  public
    constructor Create();
    destructor Destroy(); override;

    procedure Add(const AFuture : IFuture<T>);
    procedure Del(const AFuture : IFuture<T>);
    procedure Wait();
  end;

  TRestRepository<T : class> = class (TInterfacedObject, IRepository<T>, IAsyncRepository<T>)
  protected
    FHost : String;
    FAuthenticator : TCustomAuthenticator;
    FBaseApiUrl : String;
    FSelfType : TRttiType;

    //reference
    FThreadPool : TThreadPool;

    FFuturesHolder : TFuturesHolder<Unique<TRestResponse>>;
  private
    //raise ERest.Attributes
    procedure ScanAttributes(AType : TRttiType);

    //raise ERest.Attributes
    function GetRestOperationAttribute(const APath : String; AMethod : TRestRequestMethod) : RestOperationAttribute;
    //raise ERest.Attributes
    function GetDefaultRestOperationAttribute(AMethod : TRestRequestMethod) : RestOperationAttribute;

    //raise ERest.Parameters, ERest.UnwantedResult, ERest.Framework
    function SyncInvoke(AAttribute : RestOperationAttribute; ARequestBody : TObject; const AUriParamValues : TArray<TValue>; const AUriSegment : TValue) : IResponseExtractor<T>; overload;
    //raise ERest.Parameters
    procedure AsyncInvoke(AAttribute : RestOperationAttribute; ARequestBody : TObject; const AUriParamValues : TArray<TValue>; const AUriSegment : TValue; AResultHandler : TProc<TObject, IResponseExtractor<T>>); overload;
  public
    constructor Create(const AHost : String; AAuthenticator : TCustomAuthenticator; AThreadPool : TThreadPool);
    destructor Destroy(); override;

    //IRepository
    //raise ERest.Attributes, ERest.Parameters, ERest.UnwantedResult, ERest.Framework
    function Get(const AParameters : TArray<TValue> = []) : Unique<TObjectList<T>>;
    function Post(const AObject : T; const AParameters : TArray<TValue> = []) : Unique<T>;
    function Put(const AObject : T; const AParameters : TArray<TValue> = []) : Unique<T>;
    procedure Delete(const AId : TValue; const AParameters : TArray<TValue> = []);
    //IAsyncRepository
    //raise ERest.Attributes, ERest.Parameters
    procedure AsyncGet(const AHandler : TProc<TObject, Unique<TObjectList<T>>>; const AParameters : TArray<TValue> = []);
    procedure AsyncPost(const AHandler : TProc<TObject, Unique<T>>; const AObject : T; const AParameters : TArray<TValue> = []);
    procedure AsyncPut(const AHandler : TProc<TObject, Unique<T>>; const AObject : T; const AParameters : TArray<TValue> = []);
    procedure AsyncDelete(const AHandler : TProc<TObject>; const AId : TValue; const AParameters : TArray<TValue> = []);

    function SyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>) : IResponseExtractor<T>; overload;
    procedure AsyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>; AResultHandler : TProc<TObject, IResponseExtractor<T>>); overload;
    function SyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>; const AUriSegment : TValue) : IResponseExtractor<T>; overload;
    procedure AsyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>; const AUriSegment : TValue; AResultHandler : TProc<TObject, IResponseExtractor<T>>); overload;
  end;

const
  ERR_NO_ATTRIBUTE_WITH_NAME = 'Required attribute not found: ';
  ERR_NO_ATTRIBUTE_WITH_PATH_TYPE = 'Attribute not found with path %s and type %s';
  ERR_NO_DEFAULT_ATTRIBUTE_WITH_METHOD =  'Could not select default attribute for method: ';
  ERR_NO_ATTRIBUTE_WITH_METHOD =  'Could not find any attribute for method: ';
implementation
uses
  Repository.Rest.Errors,
  Utils.RttiContext,
  StrUtils;

function TFuturesHolder<T>.Count() : integer;
begin
  try
    result := FFutures.LockList().Count;
  finally
    FFutures.UnlockList();
  end;
end;
constructor TFuturesHolder<T>.Create();
begin
  FFutures := TThreadList<IFuture<T>>.Create();
end;
destructor TFuturesHolder<T>.Destroy();
begin
  Wait();
  FFutures.Free();
end;
procedure TFuturesHolder<T>.Add(const AFuture : IFuture<T>);
begin
  FFutures.Add(AFuture);
end;
procedure TFuturesHolder<T>.Del(const AFuture : IFuture<T>);
begin
  FFutures.Remove(AFuture);
end;
procedure TFuturesHolder<T>.Wait();
begin
  while Count() > 0 do
    Sleep(50);
end;

procedure TRestRepository<T>.ScanAttributes(AType : TRttiType);
begin
  var BaseApiUrlAttrib := AType.GetAttribute<BaseApiUrlAttribute>();
  if not assigned(BaseApiUrlAttrib) then
    raise ERest.Attributes.Create(ERR_NO_ATTRIBUTE_WITH_NAME + BaseApiUrlAttribute.ClassName);
  FBaseApiUrl := BaseApiUrlAttrib.Name;
end;
function TRestRepository<T>.GetRestOperationAttribute(const APath : String; AMethod : TRestRequestMethod) : RestOperationAttribute;
begin
  for var Attrib in FSelfType.GetAttributes() do
  begin
    if Attrib is RestOperationAttribute then
    begin
      var AttribCasted := Attrib as RestOperationAttribute;
      if (AttribCasted.Path.Equals(APath)) and (AttribCasted.Method = AMethod) then
        Exit(AttribCasted);
    end;
  end;
  raise ERest.Attributes.Create(Format(ERR_NO_ATTRIBUTE_WITH_PATH_TYPE,  [APath, TRttiEnumerationType.GetName(AMethod)]));
end;
function TRestRepository<T>.GetDefaultRestOperationAttribute(AMethod : TRestRequestMethod) : RestOperationAttribute;
begin
  result := nil;
  for var Attrib in FSelfType.GetAttributes() do
  begin
    if Attrib is RestOperationAttribute then
    begin
      var AttribCasted := Attrib as RestOperationAttribute;
      if (AttribCasted.Method = AMethod) then
      begin
        if assigned(result) then
          raise ERest.Attributes.Create(ERR_NO_DEFAULT_ATTRIBUTE_WITH_METHOD + TRttiEnumerationType.GetName(AMethod));
        result := AttribCasted;
      end;
    end;
  end;
  if result = nil then
    raise ERest.Attributes.Create(ERR_NO_ATTRIBUTE_WITH_METHOD + TRttiEnumerationType.GetName(AMethod));
end;

constructor TRestRepository<T>.Create(const AHost : String; AAuthenticator : TCustomAuthenticator; AThreadPool : TThreadPool);
begin
  FHost := AHost;
  FAuthenticator := AAuthenticator;

  FThreadPool := AThreadPool;
  FFuturesHolder := TFuturesHolder<Unique<TRestResponse>>.Create();

  FSelfType := GRttiCtx.GetType(self.ClassInfo);
  ScanAttributes(FSelfType);
end;
destructor TRestRepository<T>.Destroy();
begin
  FFuturesHolder.Wait();
  FFuturesHolder.Free();
end;

function TRestRepository<T>.SyncInvoke(AAttribute : RestOperationAttribute; ARequestBody : TObject; const AUriParamValues : TArray<TValue>; const AUriSegment : TValue) : IResponseExtractor<T>;
begin
  var Future := AAttribute.Invoke(FHost, FBaseApiUrl, FAuthenticator, ARequestBody, AUriParamValues, AUriSegment, FThreadPool);
  try
    result := TRestResponseExtractor<T>.Create(Future.Value);
  except
    on Ex : EAggregateException do
      if Ex.Count = 1 then
      begin
        raise Ex.ExtractSingle();
      end
      else
        raise;
    else
      raise;
  end;
end;
procedure TRestRepository<T>.AsyncInvoke(AAttribute : RestOperationAttribute; ARequestBody : TObject; const AUriParamValues : TArray<TValue>; const AUriSegment : TValue; AResultHandler : TProc<TObject, IResponseExtractor<T>>);
begin
  var Future := AAttribute.Invoke(FHost, FBaseApiUrl, FAuthenticator, ARequestBody, AUriParamValues, AUriSegment, FThreadPool);
  FFuturesHolder.Add(Future);

  var ThreadProc : TProc := procedure()
  begin
    var ResponseExtractor : IResponseExtractor<T> := nil;
    var Error : Unique<TObject>;
    try
      ResponseExtractor := TRestResponseExtractor<T>.Create(Future.Value);
    except
      Error := SwapToAggregtedExceptionIfAny(AcquireExceptionObject());
    end;

    TThread.Synchronize(nil, TThreadProcedure(procedure
    begin
      AResultHandler(Error.Get(), ResponseExtractor);
    end));

    FFuturesHolder.Del(Future);
  end;

  var Task := TTask.Create(ThreadProc, FThreadPool);
  Task.Start();
end;

function TRestRepository<T>.SyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>) : IResponseExtractor<T>;
begin
  result := SyncInvoke(GetRestOperationAttribute(APath, AMethod), ARequestBody, AUriParamValues, TValue.Empty);
end;
procedure TRestRepository<T>.AsyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>; AResultHandler : TProc<TObject, IResponseExtractor<T>>);
begin
  AsyncInvoke(GetRestOperationAttribute(APath, AMethod), ARequestBody, AUriParamValues, TValue.Empty, AResultHandler);
end;
function TRestRepository<T>.SyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>; const AUriSegment : TValue) : IResponseExtractor<T>;
begin
  result := SyncInvoke(GetRestOperationAttribute(APath, AMethod), ARequestBody, AUriParamValues, AUriSegment);
end;
procedure TRestRepository<T>.AsyncInvoke(const APath : String; AMethod : TRestRequestMethod; ARequestBody : TObject; AUriParamValues : TArray<TValue>; const AUriSegment : TValue; AResultHandler : TProc<TObject, IResponseExtractor<T>>);
begin
  AsyncInvoke(GetRestOperationAttribute(APath, AMethod), ARequestBody, AUriParamValues, AUriSegment, AResultHandler);
end;

function TRestRepository<T>.Get(const AParameters : TArray<TValue> = []) : Unique<TObjectList<T>>;
begin
  result := SyncInvoke(GetDefaultRestOperationAttribute(TRestRequestMethod.rmGET), nil, AParameters, TValue.Empty).AsObjectsList();
end;
function TRestRepository<T>.Post(const AObject : T; const AParameters : TArray<TValue> = []) : Unique<T>;
begin
  //201 (CREATED) allowed
  try
    result := SyncInvoke(GetDefaultRestOperationAttribute(TRestRequestMethod.rmPOST), AObject, AParameters, TValue.Empty).AsObject();
  except
    on E : ERest.UnwantedResult do
      if (E as ERest.UnwantedResult).Code <> 201 then
        raise;
    else
      raise;
  end;
end;
function TRestRepository<T>.Put(const AObject : T; const AParameters : TArray<TValue> = []) : Unique<T>;
begin
  result := SyncInvoke(GetDefaultRestOperationAttribute(TRestRequestMethod.rmPUT), AObject, AParameters, TValue.Empty).AsObject();
end;
procedure TRestRepository<T>.Delete(const AId : TValue; const AParameters : TArray<TValue> = []);
begin
  SyncInvoke(GetDefaultRestOperationAttribute(TRestRequestMethod.rmDelete), nil, AParameters, AId);
end;

procedure TRestRepository<T>.AsyncGet(const AHandler : TProc<TObject, Unique<TObjectList<T>>>; const AParameters : TArray<TValue> = []);
begin
  var Attribute := GetDefaultRestOperationAttribute(TRestRequestMethod.rmGET);
  var Future := Attribute.Invoke(FHost, FBaseApiUrl, FAuthenticator, nil, AParameters, TValue.Empty, FThreadPool);

  var ThreadProc : TProc := procedure()
  begin
    var Res : Unique<TObjectList<T>> := nil;
    var Error : Unique<TObject>;
    try
      Res := TRestResponseExtractor<T>.Create(Future.Value).AsObjectsList();
    except
      Error := SwapToAggregtedExceptionIfAny(AcquireExceptionObject());
    end;

    TThread.Synchronize(nil, TThreadProcedure(procedure
    begin
      AHandler(Error.Get(), Res);
    end));
  end;

  var Task := TTask.Create(ThreadProc, FThreadPool);
  Task.Start();
end;
procedure TRestRepository<T>.AsyncPost(const AHandler : TProc<TObject, Unique<T>>; const AObject : T; const AParameters : TArray<TValue> = []);
begin
  var Attribute := GetDefaultRestOperationAttribute(TRestRequestMethod.rmPOST);
  var Future := Attribute.Invoke(FHost, FBaseApiUrl, FAuthenticator, AObject, AParameters, TValue.Empty, FThreadPool);

  var ThreadProc : TProc := procedure()
  begin
    var Res : Unique<T> := nil;
    var Error : Unique<TObject>;
    try
      Res := TRestResponseExtractor<T>.Create(Future.Value).AsObject();
    except
      Error := SwapToAggregtedExceptionIfAny(AcquireExceptionObject());
    end;

    //201 (CREATED) allowed
    if (Error.Get() is ERest.UnwantedResult)
    and ((Error.Get() as ERest.UnwantedResult).Code = 201) then
      Error := nil;

    TThread.Synchronize(nil, TThreadProcedure(procedure
    begin
      AHandler(Error.Get(), Res);
    end));
  end;

  var Task := TTask.Create(ThreadProc, FThreadPool);
  Task.Start();
end;
procedure TRestRepository<T>.AsyncPut(const AHandler : TProc<TObject, Unique<T>>; const AObject : T; const AParameters : TArray<TValue> = []);
begin
  var Attribute := GetDefaultRestOperationAttribute(TRestRequestMethod.rmPUT);
  var Future := Attribute.Invoke(FHost, FBaseApiUrl, FAuthenticator, AObject, AParameters, TValue.Empty, FThreadPool);

  var ThreadProc : TProc := procedure()
  begin
    var Res : Unique<T> := nil;
    var Error : Unique<TObject>;
    try
      Res := TRestResponseExtractor<T>.Create(Future.Value).AsObject();
    except
      Error := SwapToAggregtedExceptionIfAny(AcquireExceptionObject());
    end;

    TThread.Synchronize(nil, TThreadProcedure(procedure
    begin
      AHandler(Error.Get(), Res);
    end));

  end;

  var Task := TTask.Create(ThreadProc, FThreadPool);
  Task.Start();
end;
procedure TRestRepository<T>.AsyncDelete(const AHandler : TProc<TObject>; const AId : TValue; const AParameters : TArray<TValue> = []);
begin
  var Attribute := GetDefaultRestOperationAttribute(TRestRequestMethod.rmDELETE);
  var Future := Attribute.Invoke(FHost, FBaseApiUrl, FAuthenticator, nil, AParameters, AId, FThreadPool);

  var ThreadProc : TProc := procedure()
  begin
    var Error : Unique<TObject>;
    try
      TRestResponseExtractor<T>.Create(Future.Value);
    except
      Error := SwapToAggregtedExceptionIfAny(AcquireExceptionObject());
    end;

    TThread.Synchronize(nil, TThreadProcedure(procedure
    begin
      AHandler(Error.Get());
    end));
  end;

  var Task := TTask.Create(ThreadProc, FThreadPool);
  Task.Start();
end;

end.
