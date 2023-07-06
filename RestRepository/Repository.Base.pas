unit Repository.Base;

interface
uses
  Memory,
  SysUtils,
  Rtti,
  Generics.Collections;
type

  IRepository<T : class> = interface
    function Get(const AParameters : TArray<TValue> = []) : Unique<TObjectList<T>>;
    function Post(const AObject : T; const AParameters : TArray<TValue> = []) : Unique<T>;
    function Put(const AObject : T; const AParameters : TArray<TValue> = []) : Unique<T>;
    procedure Delete(const AId : TValue; const AParameters : TArray<TValue> = []);
  end;

  IAsyncRepository<T : class> = interface
    procedure AsyncGet(const AHandler : TProc<TObject, Unique<TObjectList<T>>>; const AParameters : TArray<TValue> = []);
    procedure AsyncPost(const AHandler : TProc<TObject, Unique<T>>;const AObject : T; const AParameters : TArray<TValue> = []);
    procedure AsyncPut(const AHandler : TProc<TObject, Unique<T>>; const AObject : T; const AParameters : TArray<TValue> = []);
    procedure AsyncDelete(const AHandler : TProc<TObject>; const AId : TValue; const AParameters : TArray<TValue> = []);
  end;

implementation

end.
