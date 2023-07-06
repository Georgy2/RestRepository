unit Repository.Rest.Errors;

interface
uses
  SysUtils,
  Threading;

type

  TSpringRestErrorMessage = class
  public
    {"timestamp": "2099-06-11T13:38:29.868+00:00",
    "status": 400,
    "error": "Bad Request",
    "errors": "...",
    "message": "",
    "path": "/dummy"}
    FTimestamp : String;
    FStatus : integer;
    FError : String;
    FErrors : String;
    FMessage : String;
    FPath : String;
  end;

  ERest = record
  type
    //base
    Base = class (Exception);
    //specific
    UnwantedResult = class (Base)
    private
      FCode : integer;
      FSpringMessage : TSpringRestErrorMessage;
    public
      constructor Create(ACode : integer; AMessage : String; ASpringMessage : TSpringRestErrorMessage);
      destructor Destroy(); override;
      property Code : integer read FCode;
      property SpringMessage : TSpringRestErrorMessage read FSpringMessage;
    end;
    Attributes = class (Base);
    Parameters = class (Base);
    ResponseExtractor = class (Base);
    Framework = class (Base);   //Any ERESTException

    //utils
    class function ErrorToString(AError : TObject) : String; static;
  end;

  EAggregateExceptionHelper = class helper for EAggregateException
    function ExtractSingle(): Exception;
  end;

  function SwapToAggregtedExceptionIfAny(ASource : TObject) : TObject;
implementation

constructor ERest.UnwantedResult.Create(ACode : integer; AMessage : String; ASpringMessage : TSpringRestErrorMessage);
begin
  inherited Create(AMessage);
  FCode := ACode;
  FSpringMessage := ASpringMessage;
end;
destructor ERest.UnwantedResult.Destroy();
begin
  FSpringMessage.Free();
end;

class function ERest.ErrorToString(AError : TObject) : String;
begin
  if AError is ERest.UnwantedResult then
  begin
    var Err := AError as ERest.UnwantedResult;
    if assigned(Err.FSpringMessage) and not Err.FSpringMessage.FMessage.IsEmpty() then
      result := Err.FSpringMessage.FMessage
    else if assigned(Err.FSpringMessage) then
      result := Err.FSpringMessage.FError
    else
    begin
      result := Format('Error code %d with message "%s"', [Err.Code, Err.Message]);
    end;
  end
  else if AError is ERest.Base then
    result := (AError as ERest.Base).Message
  else if AError is Exception then
    result := (AError as Exception).Message
  else
    result := 'Unknown error: ' + AError.ClassName;
end;

function EAggregateExceptionHelper.ExtractSingle() : Exception;
begin
	result := nil;
	with self do
  begin
    if Count <> 1 then
      exit;

    result := FInnerExceptions[0];
    FInnerExceptions := [];
  end;
end;

function SwapToAggregtedExceptionIfAny(ASource : TObject) : TObject;
begin
  if (ASource is EAggregateException) and ((ASource as EAggregateException).Count = 1) then
  begin
    result := (ASource as EAggregateException).ExtractSingle();
    ASource.Free();
  end
  else
    result := ASource;
end;

end.
