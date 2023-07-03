unit Entity.Base.Test;

interface

uses
  Entity.Base,
  DUnitX.TestFramework;

type
  [TestFixture]
  TBaseEntityTest = class
  public
    [Test]
    procedure Clone();
    [Test]
    procedure KeysCombinations();

    //more tests in Entity.Base.Key.Test
  end;

implementation
uses
  Memory;

type TCloneable = class (TEntity<TCloneable>)
  FInt : Integer;
  FInt64 : Int64;
  FString : String;
  FEnum : (eVal1, eVal2);
  FReal : Real;
  FDouble : Double;
  FExtended : Extended;
  FDateTime : TDateTime;
  FObject : TObject;
  FArray : TArray<Integer>;
end;

procedure TBaseEntityTest.Clone();
begin
  var Originl := TCloneable.Create();
  Originl.FInt := 1;
  Originl.FInt64 := Int64(MaxInt) + 1;
  Originl.FString := 's1';
  Originl.FEnum := eVal1;
  Originl.FReal := 0.1;
  Originl.FDouble := 0.01;
  Originl.FExtended := 0.001;
  Originl.FDateTime := TDateTime(1.1);
  Originl.FObject := self;
  Originl.FArray := [1, 2, 3];

  var Clone := Originl.Clone();

  Assert.AreEqual(Originl.FInt, Clone.FInt);
  Assert.AreEqual(Originl.FInt64, Clone.FInt64);
  Assert.AreEqual(Originl.FString, Clone.FString);
  Assert.AreEqual(Originl.FEnum, Clone.FEnum);
  Assert.AreEqual(Originl.FReal, Clone.FReal);
  Assert.AreEqual(Originl.FDouble, Clone.FDouble);
  Assert.AreEqual(Originl.FExtended, Clone.FExtended);
  Assert.AreEqual(Originl.FDateTime, Clone.FDateTime);
  Assert.AreSame(Originl.FObject, Clone.FObject);
  Assert.AreEqual(Originl.FArray, Clone.FArray);
end;

type TNoKeyOk = class (TEntity<TNoKeyOk>)
  FInt : Integer;
  FInt64 : Int64;
  FString : String;
end;
type TKeyOk = class (TEntity<TKeyOk>)
  [Key] FInt : Integer;
  FInt64 : Int64;
  FString : String;
end;
type TComplexKeyOk = class (TEntity<TComplexKeyOk>)
  [ComplexKey] FInt : Integer;
  [ComplexKey] FInt64 : Int64;
  FString : String;
end;
type TKeyAndComplexKeyBad = class (TEntity<TKeyAndComplexKeyBad>)
  [Key] [ComplexKey] FInt : Integer;
  [ComplexKey] FInt64 : Int64;
  FString : String;
end;
type TSeveralKeyBad = class (TEntity<TSeveralKeyBad>)
  [Key] FInt : Integer;
  [Key] FInt64 : Int64;
  FString : String;
end;

procedure TBaseEntityTest.KeysCombinations();
begin
  Assert.WillNotRaiseAny(procedure begin
                          var Dummy : Unique<TNoKeyOk> := TNoKeyOk.Create();
                        end);
  Assert.WillNotRaiseAny(procedure begin
                          var Dummy : Unique<TKeyOk> := TKeyOk.Create();
                        end);
  Assert.WillNotRaiseAny(procedure begin
                          var Dummy : Unique<TComplexKeyOk> := TComplexKeyOk.Create();
                        end);

  ///  if we try to instantiate some bad classes, an exception will be thrown.
  ///  but we cant catch them because thew occur during initialization
  ///
  //var Dummy : Unique<TKeyAndComplexKeyBad> := TKeyAndComplexKeyBad.Create();
  //var Dummy : Unique<TSeveralKeyBad> := TSeveralKeyBad.Create();
end;

initialization
  TDUnitX.RegisterTestFixture(TBaseEntityTest);
end.
