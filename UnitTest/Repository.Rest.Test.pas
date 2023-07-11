unit Repository.Rest.Test;

interface

uses
  Rtti,
  Repository.Rest,
  Repository.Rest.Operations,
  Rest.Client,
  WebMock,
  DUnitX.TestFramework,
  Threading;

type
  [TestFixture]
  TRestRepositoryTest = class
  private
    WebMock: TWebMock;
    Authenticator : TCustomAuthenticator;
    ThreadPool : TThreadPool;
  public
    [Setup]
    procedure Setup();
    [TearDown]
    procedure TearDown();

    [Test]
    procedure SimpleMethods();

    [Test]
    procedure WithoutDefaultMethods();

    [Test]
    procedure SpecializedMethods();
  end;

  TTestData = class
    FKey : Int64;
  end;

  [BaseApiUrl('/base_api_url')]
  [Get('')]
  [Post('')]
  [Put('')]
  [Delete('')]
  TSimpleMethodsRepo = class (TRestRepository<TTestData>);

  [BaseApiUrl('/base_api_url')]
  [Get('')]
  [Get('')]
  TWithoutDefaultMethodsRepo = class (TRestRepository<TTestData>);

  [BaseApiUrl('/base_api_url')]
  [Get('/get_method', 'param1')]
  [Put('/put_method', 'param1,param2')]
  [Post('', 'param1')]
  TSpecializedMethodsRepo = class (TRestRepository<TTestData>);

implementation
uses
  Repository.Rest.Errors,
  Rest.Types,
  Rest.Authenticator.Basic,
  WebMock.ResponseStatus;

procedure TRestRepositoryTest.Setup;
begin
  WebMock := TWebMock.Create();
  Authenticator := THTTPBasicAuthenticator.Create('test', 'test');
  ThreadPool := TThreadPool.Create();
end;

procedure TRestRepositoryTest.TearDown;
begin
  WebMock.Free();
  Authenticator.Free();
  ThreadPool.Free();
end;

procedure TRestRepositoryTest.SimpleMethods();
begin
  var Uri := WebMock.URLFor('');
  var Repo := TSimpleMethodsRepo.Create(Uri, Authenticator, ThreadPool);
  var ObjToSend := TTestData.Create();
  var ID := TValue.From<Integer>(123);
  var IdDtring := ID.ToString();

  WebMock.StubRequest('GET', '/base_api_url').ToRespond(TWebMockResponseStatus.OK).WithBody('[]');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Get();
  end, 'Get');
  //POST - OK
  WebMock.StubRequest('POST', '/base_api_url').ToRespond(TWebMockResponseStatus.OK).WithBody('{}');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Post(ObjToSend);
  end, 'Post');
  //POST - CREATED
  WebMock.StubRequest('POST', '/base_api_url').ToRespond(TWebMockResponseStatus.Created).WithBody('{}');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Post(ObjToSend);
  end, 'Post');
  WebMock.StubRequest('PUT', '/base_api_url').ToRespond(TWebMockResponseStatus.OK).WithBody('{}');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Put(ObjToSend);
  end, 'Put');
  WebMock.StubRequest('DELETE', '/base_api_url/' + IdDtring).ToRespond(TWebMockResponseStatus.OK).WithBody('');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Delete(ID);
  end, 'Delete');

end;

procedure TRestRepositoryTest.WithoutDefaultMethods();
begin
  var Uri := WebMock.URLFor('');
  var Repo := TWithoutDefaultMethodsRepo.Create(Uri, Authenticator, ThreadPool);
  var ObjToSend := TTestData.Create();

  Assert.WillRaise(procedure begin
    Repo.Get();
  end, ERest.Attributes, 'not unique attribute');

  Assert.WillRaise(procedure begin
    Repo.Post(ObjToSend);
  end, ERest.Attributes, 'no such attribute');
end;

procedure TRestRepositoryTest.SpecializedMethods();
begin
  var Uri := WebMock.URLFor('');
  var Repo := TSpecializedMethodsRepo.Create(Uri, Authenticator, ThreadPool);
  var ObjToSend := TTestData.Create();

  Assert.WillRaise(procedure begin
    Repo.Get();
  end, ERest.Parameters);

  WebMock.StubRequest('GET', '/base_api_url/get_method').WithQueryParam('param1', '123').ToRespond(TWebMockResponseStatus.OK).WithBody('[]');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Get([123]);
  end, 'get with one parameter');

  WebMock.StubRequest('PUT', '/base_api_url/put_method')
    .WithQueryParam('param1', '123')
    .WithQueryParam('param2', 'text')
    .ToRespond(TWebMockResponseStatus.OK).WithBody('{}');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Put(ObjToSend, [123, 'text']);
  end, 'put with payload and two parameters');

  WebMock.StubRequest('POST', '/base_api_url')
    .WithQueryParam('param1', '123')
    .ToRespond(TWebMockResponseStatus.OK).WithBody('{}');
  Assert.WillNotRaiseAny(procedure begin
    Repo.Post(ObjToSend, [123]);
  end, 'post with payload and one parameter');

  WebMock.StubRequest('GET', '/base_api_url/get_method').WithQueryParam('param1', '123').ToRespond(TWebMockResponseStatus.OK).WithBody('[]');
  Assert.WillNotRaiseAny(procedure begin
    Repo.SyncInvoke('/get_method', rmGET, nil, [123]);
  end, 'raw get with one parameter');

  WebMock.StubRequest('PUT', '/base_api_url/put_method')
    .WithQueryParam('param1', '123')
    .WithQueryParam('param2', 'text')
    .ToRespond(TWebMockResponseStatus.OK).WithBody('{}');
  Assert.WillNotRaiseAny(procedure begin
    Repo.SyncInvoke('/put_method', rmPUT, ObjToSend, [123, 'text']);
  end, 'raw put with payload and two parameters');
end;

initialization
  TDUnitX.RegisterTestFixture(TRestRepositoryTest);
end.
