# RestRepository for Delphi

A small library for working with remote REST services.
Allows you to describe interactions in a declarative style.
Uses *Delphi 11*, *Delphi REST library*, *RTTI*, *generics*, and *smart records*.
For testing, *DUnitX* and *Delphi WebMock* are used.

## Simple Calls

    // Declare the class that the repository will work with
    TSomeData = class
      FKey: Int64;
    end;
    
    // Declare the repository
    [BaseApiUrl('/base_api_url')]
    [Get('')]
    [Post('')]
    [Put('')]
    [Delete('')]
    TSimpleRepo = class(TRestRepository<TSomeData>);

After this declaration, we can create a repository (using REST library authentication)

    var Uri := 'http://127.0.0.1:8080/';
    var Authenticator := THTTPBasicAuthenticator.Create('name', 'password');
    var Repo := TSimpleRepo.Create(Uri, Authenticator);

and we can call the retrieval function

    var ResList := Repo.Get();

and the add and update functions

    var ObjectPost := TSomeData.Create();
    var ResPostObject := Repo.Post(ObjectPost);
    var ObjectPut := TSomeData.Create();
    var ResPutObject := Repo.Put(ObjectPost);

and the delete function

    var Key := TValue.From<Integer>(123);
    Repo.Delete(Key);
    //or
    //Repo.Delete(123);

## Return Values

**Get** returns a list of values, so the expected result is a JSON list.
**Post** and **Put** return an object, so the expected result is a JSON object.
**Delete** doesn't return anything.
*Note: the values are returned in the **Unique** wrapper (described below)*

## Customization

All attributes and calls can be customized and represented as follows:

    //class attribute
    [Get('/command', 'param1,param2')]
    //corresponding call
    Repo.Get([Param1Value, Param2Value]);
    //invoked request
    //GET http://127.0.0.1:8080/base_api_url/command?param1=Param1Value&param2=Param2Value
    //with an empty request body
    
    [Post('/command', 'param1,param2')]
    //corresponding call
    Repo.Post(Object, [Param1Value, Param2Value]);
    //invoked request
    //POST http://127.0.0.1:8080/base_api_url/command?param1=Param1Value&param2=Param2Value
    //with the request body - JSON representation of the Object
    
    [Put('/command', 'param1,param2')]
    //corresponding call
    Repo.Put(Object, [Param1Value, Param2Value]);
    //invoked request
    //PUT http://127.0.0.1:8080/base_api_url/command?param1=Param1Value&param2=Param2Value
    //with the request body - JSON representation of the Object
    
    [Delete('/command', 'param1,param2')]
    //corresponding call
    Repo.Delete(Key {TValue}, [Param1Value, Param2Value]);
    //invoked request
    //DELETE http://127.0.0.1:8080/base_api_url/command/123456?param1=Param1Value&param2=Param2Value
    //where 123456 is the string representation of Key
    //with an empty request body

The number of parameters can be arbitrary.
Parameter names should be listed separated by commas, and all spaces in the string will be removed.
Parameter values are passed to the function as a TArray of TValue, and their types should support conversion to a string.

## Maximum customization

If you need to have multiple requests with the same method (e.g., multiple Get requests with different parameters),
or the request sends/returns a value of a different type (not the one specified in the repository class),
the call should be made as follows:

    [BaseApiUrl('/base_api_url')]
    [Get('/command1', 'param1,param2')]
    [Get('/command2', 'param1,param2')]
    TGetAndGetRepo = class (TRestRepository<TSomeData>);
    //var Repo := TGetAndGetRepo.Create(...);
    
    //result is list of TSomeData, ObjToSend - any class 
    var Result := Repo.SyncInvoke('/command1', rmGET, ObjToSend, [123, 'text']).AsObjectList();
    //result is TSomeData
    var Result := Repo.SyncInvoke('/command1', rmGET, ObjToSend, [123, 'text']).AsObject();
    //result is other class
    var Result := TOther(Repo.SyncInvoke('/command1', rmGET, ObjToSend, [123, 'text']).AsObjectType(TOther.Class));

## Errors

Possible exceptions are described in the module *Repository.Rest.Errors*:
- ERest.Base - the base class for all exception classes.
- ERest.Attributes - error in the definition of class attributes.
- ERest.Parameters - error in the passed parameters during the call.
- ERest.ResponseExtractor - error in converting the received response body to the desired type.
- ERest.Framework - Delphi REST framework error.
- ERest.UnwantedResult - the request result is not OK 200 (and not CREATED 201 for a POST request).

## Asynchronicity

All requests have an asynchronous version (**AsyncGet, AsyncPost, AsyncPut, AsyncDelete, AsyncInvoke**).
In this case, one of the parameters is a callback procedure that will be called upon completion of the request.
The callback procedure will receive the request result and the thrown exception object (or nil if it's absent).

## Additional types

- **Unique** - a smart record that wraps an object, an elementary analogue of unique_ptr.
  It deletes the stored object when it goes out of scope.
  It transfers the stored object when assigned.
- **IResponseExtractor** - stores the response body and can provide it as an object or a list.