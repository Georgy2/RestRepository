unit Memory;

interface

type
  Unique<T : class> = record
    private
      FObject : T;
    public
      class operator Initialize(out AUni: Unique<T>);
      class operator Finalize (var AUni: Unique<T>);
      class operator Assign (var Dest: Unique<T>; const [ref] Src: Unique<T>);

      class operator Explicit(const AUni : Unique<T>): boolean;
      class operator Implicit(const AVal : T) : Unique<T>;

      procedure Reset(ANewVal : T);
      function Release() : T;
      function Get() : T;
  end;

implementation
uses
  SysUtils;

class operator Unique<T>.Initialize(out AUni: Unique<T>);
begin
  AUni.FObject := nil;
end;
class operator Unique<T>.Finalize (var AUni: Unique<T>);
begin
  FreeAndNil(AUni.FObject);
end;
class operator Unique<T>.Assign(var Dest: Unique<T>; const [ref] Src: Unique<T>);
begin
  if (Dest.FObject <> Src.FObject) then
    Dest.Reset(Src.Release())
  else
    Src.Release();
end;
class operator Unique<T>.Explicit(const AUni : Unique<T>): boolean;
begin
  result := AUni.FObject <> nil;
end;
class operator Unique<T>.Implicit(const AVal : T) : Unique<T>;
begin
  result.FObject := AVal;
end;
procedure Unique<T>.Reset(ANewVal : T);
begin
  FreeAndNil(FObject);
  FObject := ANewVal;
end;
function Unique<T>.Release() : T;
begin
  result := FObject;
  FObject := nil;
end;
function Unique<T>.Get() : T;
begin
  result := FObject;
end;

end.
