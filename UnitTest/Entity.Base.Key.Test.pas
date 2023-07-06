unit Entity.Base.Key.Test;

interface

uses
  Entity.Base.Key,
  DUnitX.TestFramework;

type
  [TestFixture]
  TComplexKeyTest = class
  public
    [Setup]
    procedure Setup();
    [TearDown]
    procedure TearDown();

    [Test]
    procedure SingleElementKeys();
    [Test]
    procedure MultiElementKeys();
    [Test]
    procedure InvalidKey();
  end;

implementation
uses
  SysUtils,
  Memory;

type TSomeEntity = class
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

var
  Entity1Unique : TSomeEntity;
  Entity2SameAs3 : TSomeEntity;
  Entity3SameAs2 : TSomeEntity;

procedure TComplexKeyTest.Setup();
begin
  Entity1Unique := TSomeEntity.Create();
  Entity1Unique.FInt := 1;
  Entity1Unique.FInt64 := Int64(MaxInt) + 1;
  Entity1Unique.FString := 's1';
  Entity1Unique.FEnum := eVal1;
  Entity1Unique.FReal := 0.1;
  Entity1Unique.FDouble := 0.01;
  Entity1Unique.FExtended := 0.001;
  Entity1Unique.FDateTime := TDateTime(1.1);

  Entity2SameAs3 := TSomeEntity.Create();
  Entity2SameAs3.FInt := 2;
  Entity2SameAs3.FInt64 := Int64(MaxInt) + 2;
  Entity2SameAs3.FString := 's2';
  Entity2SameAs3.FEnum := eVal2;
  Entity2SameAs3.FReal := 0.2;
  Entity2SameAs3.FDouble := 0.02;
  Entity2SameAs3.FExtended := 0.002;
  Entity2SameAs3.FDateTime := TDateTime(2.2);

  Entity3SameAs2 := TSomeEntity.Create();
  Entity3SameAs2.FInt := 2;
  Entity3SameAs2.FInt64 := Int64(MaxInt) + 2;
  Entity3SameAs2.FString := 's2';
  Entity3SameAs2.FEnum := eVal2;
  Entity3SameAs2.FReal := 0.2;
  Entity3SameAs2.FDouble := 0.02;
  Entity3SameAs2.FExtended := 0.002;
  Entity3SameAs2.FDateTime := TDateTime(2.2);
end;
procedure TComplexKeyTest.TearDown();
begin
  Entity1Unique.Free();
  Entity2SameAs3.Free();
  Entity3SameAs2.Free();
end;

procedure TComplexKeyTest.SingleElementKeys();
begin
  const FieldNames = ['FInt', 'FInt64', 'FString', 'FEnum', 'FReal', 'FDouble', 'FExtended', 'FDateTime'];
  for var FieldName in FieldNames do
  begin
    var ComplexKey := Unique<TComplexKeyProducer<TSomeEntity>>(TComplexKeyProducer<TSomeEntity>.Create([FieldName]));
    var Comparer := ComplexKey.Get().GetComparer();
    var K1Uni := ComplexKey.Get().GetKey(Entity1Unique);
    var K2As3 := ComplexKey.Get().GetKey(Entity2SameAs3);
    var K3As2 := ComplexKey.Get().GetKey(Entity3SameAs2);

    //different keys are different
    Assert.IsFalse(Comparer.Equals(K1Uni, K2As3));
    //key is equivalent to itself
    Assert.IsTrue(Comparer.Equals(K1Uni, K1Uni));
    //same keys of different objects are equivalent
    Assert.IsTrue(Comparer.Equals(K2As3, K3As2));

    //hash codes of different objects are different
    Assert.AreNotEqual(Comparer.GetHashCode(K1Uni), Comparer.GetHashCode(K2As3));
    //hash codes of same objects are equivalent
    Assert.AreEqual(Comparer.GetHashCode(K2As3), Comparer.GetHashCode(K3As2));
  end;
end;
procedure TComplexKeyTest.MultiElementKeys();
begin
  const FieldNameSets = ['FInt,FInt64', 'FString,FInt64', 'FExtended,FString,FReal', 'FString,FEnum', 'FReal,FEnum', 'FExtended,FDouble', 'FString,FExtended', 'FExtended,FEnum,FDateTime'];
  for var FieldNameSet in FieldNameSets do
  begin
    var FieldNamesArr := FieldNameSet.Split([',']);

    var ComplexKey := Unique<TComplexKeyProducer<TSomeEntity>>(TComplexKeyProducer<TSomeEntity>.Create(FieldNamesArr));
    var Comparer := ComplexKey.Get().GetComparer();
    var K1Uni := ComplexKey.Get().GetKey(Entity1Unique);
    var K2As3 := ComplexKey.Get().GetKey(Entity2SameAs3);
    var K3As2 := ComplexKey.Get().GetKey(Entity3SameAs2);

    //different keys are different
    Assert.IsFalse(Comparer.Equals(K1Uni, K2As3));
    //key is equivalent to itself
    Assert.IsTrue(Comparer.Equals(K1Uni, K1Uni));
    //same keys of different objects are equivalent
    Assert.IsTrue(Comparer.Equals(K2As3, K3As2));

    //hash codes of different objects are different
    Assert.AreNotEqual(Comparer.GetHashCode(K1Uni), Comparer.GetHashCode(K2As3));
    //hash codes of same objects are equivalent
    Assert.AreEqual(Comparer.GetHashCode(K2As3), Comparer.GetHashCode(K3As2));
  end;
end;
procedure TComplexKeyTest.InvalidKey();
begin
  const FieldNames = ['FObject', 'FArray'];
  for var FieldName in FieldNames do
  begin
    Assert.WillRaise(procedure begin
                      var ComplexKey := TComplexKeyProducer<TSomeEntity>.Create([FieldName]);
                      ComplexKey.Free();
                    end,
                    KeyException);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TComplexKeyTest);

end.
