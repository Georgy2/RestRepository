unit Repository.Rest.ResponseExtractor.Test;

interface

uses
  Repository.Rest.ResponseExtractor,
  Repository.Rest.Errors,
  Rest.Client,
  DUnitX.TestFramework;

type
  [TestFixture]
  TResponseExtractorTest = class
  public
    [Test]
    procedure ExtractGoodObject();
    [Test]
    procedure ExtractGoodList();
    [Test]
    procedure ExtractBadObject();
  end;

implementation

type
  TCustomRestResponseHelper = class helper for TCustomRESTResponse
    procedure DirtySetContent(const AContent : String);
  end;

procedure TCustomRestResponseHelper.DirtySetContent(const AContent : String);
begin
  with self do
  begin
    FContent := AContent;
  end;
end;

type
  TDummy = class
    FInteger : integer;
    FString : String;
  end;
const
  DummyGood = '{"Integer": 1, "String": "string1"}';
  DummyGoodOtherFormat = '{"I_nteg_er_": "not integer", "String": 2}';
  DummyGoodEmpty = '{}';
  DummyArrayGood = '[ {"Integer": 1, "String": "string1"}, {"Integer": 2, "String": "string2"} ]';
  DummyBadNotJson = 'nweoinf489n589h9';
  DummyBadNotJsonObject = '[ {"Integer": 1, "String": "string1"}, {"Integer": 2, "String": "string2"} ]';

procedure TResponseExtractorTest.ExtractGoodObject();
begin
  const Strings = [DummyGood, DummyGoodOtherFormat, DummyGoodEmpty];
  for var JString in Strings do
  begin
    var Resp := TRESTResponse.Create(nil);
    Resp.DirtySetContent(JString);

    var RespExtr : IResponseExtractor<TDummy> := TRestResponseExtractor<TDummy>.Create(Resp);

    Assert.WillNotRaiseAny(procedure begin
      var Obj := RespExtr.AsObject();
      Obj.Free();
    end);
    Assert.WillNotRaiseAny(procedure begin
      var Obj := RespExtr.AsObjectType(TDummy) as TDummy;
      Obj.Free();
    end);
  end;
end;
procedure TResponseExtractorTest.ExtractGoodList();
begin
  var Resp := TRESTResponse.Create(nil);
  Resp.DirtySetContent(DummyArrayGood);

  var RespExtr : IResponseExtractor<TDummy> := TRestResponseExtractor<TDummy>.Create(Resp);

  Assert.WillNotRaiseAny(procedure begin
    var ObjList := RespExtr.AsObjectsList();
    ObjList.Free();
  end);
end;
procedure TResponseExtractorTest.ExtractBadObject();
begin
  const Strings = [DummyBadNotJson, DummyBadNotJsonObject];
  for var JString in Strings do
  begin
    var Resp := TRESTResponse.Create(nil);
    Resp.DirtySetContent(JString);

    var RespExtr : IResponseExtractor<TDummy> := TRestResponseExtractor<TDummy>.Create(Resp);

    Assert.WillRaise(procedure begin
      var Obj := RespExtr.AsObject();
    end, ERest.ResponseExtractor);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TResponseExtractorTest);

end.
