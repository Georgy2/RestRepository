unit Memory.Test;

interface

uses
  Memory,
  DUnitX.TestFramework;

type
  [TestFixture]
  TUniqueTest = class
  public
    [Test]
    procedure ManualReset();
    [Test]
    procedure OutOfScopeReset();
    [Test]
    procedure SetOtherValue();
    [Test]
    procedure SetValueTwice();
  end;

implementation

type TDummy = class
  class var FCounter : integer;
public
  class constructor CreateClass();
  constructor Create();
  destructor Destroy(); override;
  class property Count : integer read FCounter;
end;
class constructor TDummy.CreateClass();
begin
  FCounter := 0;
end;
constructor TDummy.Create();
begin
  inc(FCounter);
end;
destructor TDummy.Destroy();
begin
  dec(FCounter);
end;

procedure TUniqueTest.ManualReset();
begin
  var UniqueDummy := Unique<TDummy>(TDummy.Create());
  Assert.AreEqual(1, TDummy.Count);
  UniqueDummy.Reset(nil);
  Assert.AreEqual(0, TDummy.Count);
end;
procedure TUniqueTest.OutOfScopeReset();
begin
  begin
    var UniqueDummy := Unique<TDummy>(TDummy.Create());
    Assert.AreEqual(1, TDummy.Count);
  end;
  Assert.AreEqual(0, TDummy.Count);
end;
procedure TUniqueTest.SetOtherValue();
begin
  //set up value, free old value when new is assigned, reset out of scope
  begin
    var Dummy1 := TDummy.Create();
    var Dummy2 := TDummy.Create();
    Assert.AreEqual(2, TDummy.Count);

    var UniqueDummy : Unique<TDummy> := Dummy1; //implicit cast and assignment
    Assert.AreSame(Dummy1, UniqueDummy.Get());
    UniqueDummy := Dummy2;                      //implicit cast and assignment, old value(Dummy1) destroyed here
    Assert.AreEqual(1, TDummy.Count);
    Assert.AreSame(Dummy2, UniqueDummy.Get());
  end;
  Assert.AreEqual(0, TDummy.Count);
end;
procedure TUniqueTest.SetValueTwice();
begin
  //set same value twice
  begin
    var Dummy1 := TDummy.Create();
    Assert.AreEqual(1, TDummy.Count);

    var UniqueDummy : Unique<TDummy>;
    UniqueDummy := Dummy1;                      //first implicit cast and assignment
    Assert.AreSame(Dummy1, UniqueDummy.Get());

    Assert.AreEqual(1, TDummy.Count);

    UniqueDummy := Dummy1;                      //second implicit cast and assignment (safe)
    Assert.AreSame(Dummy1, UniqueDummy.Get());
    Assert.AreEqual(1, TDummy.Count);
  end;
  Assert.AreEqual(0, TDummy.Count);
end;

initialization
  TDUnitX.RegisterTestFixture(TUniqueTest);

end.
