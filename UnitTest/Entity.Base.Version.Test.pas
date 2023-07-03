unit Entity.Base.Version.Test;

interface

uses
  Entity.Base.Version,
  DUnitX.TestFramework;

type
  [TestFixture]
  TVersionTest = class
  public
    [Setup]
    procedure Setup();
    [TearDown]
    procedure TearDown();

    [Test]
    procedure Compare();
  end;

implementation
uses
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
end;

var
  Entity1Smallest : TSomeEntity;
  Entity2More1SameAs3 : TSomeEntity;
  Entity3More1SameAs2 : TSomeEntity;

procedure TVersionTest.Setup();
begin
  Entity1Smallest := TSomeEntity.Create();
  Entity1Smallest.FInt := 1;
  Entity1Smallest.FInt64 := Int64(MaxInt) + 1;
  Entity1Smallest.FString := 's1';
  Entity1Smallest.FEnum := eVal1;
  Entity1Smallest.FReal := 0.1;
  Entity1Smallest.FDouble := 0.01;
  Entity1Smallest.FExtended := 0.001;
  Entity1Smallest.FDateTime := TDateTime(1.1);

  Entity2More1SameAs3 := TSomeEntity.Create();
  Entity2More1SameAs3.FInt := 2;
  Entity2More1SameAs3.FInt64 := Int64(MaxInt) + 2;
  Entity2More1SameAs3.FString := 's2';
  Entity2More1SameAs3.FEnum := eVal2;
  Entity2More1SameAs3.FReal := 0.2;
  Entity2More1SameAs3.FDouble := 0.02;
  Entity2More1SameAs3.FExtended := 0.002;
  Entity2More1SameAs3.FDateTime := TDateTime(2.2);

  Entity3More1SameAs2 := TSomeEntity.Create();
  Entity3More1SameAs2.FInt := 2;
  Entity3More1SameAs2.FInt64 := Int64(MaxInt) + 2;
  Entity3More1SameAs2.FString := 's2';
  Entity3More1SameAs2.FEnum := eVal2;
  Entity3More1SameAs2.FReal := 0.2;
  Entity3More1SameAs2.FDouble := 0.02;
  Entity3More1SameAs2.FExtended := 0.002;
  Entity3More1SameAs2.FDateTime := TDateTime(2.2);
end;
procedure TVersionTest.TearDown();
begin
  Entity1Smallest.Free();
  Entity2More1SameAs3.Free();
  Entity3More1SameAs2.Free();
end;

procedure TVersionTest.Compare();
begin
  const FieldNames = ['FInt', 'FInt64', 'FString', 'FEnum', 'FReal', 'FDouble', 'FExtended', 'FDateTime'];
  for var FieldName in FieldNames do
  begin
    var Version : Unique<TVersionProducer<TSomeEntity>> := TVersionProducer<TSomeEntity>.Create(FieldName);
    var Comparer := Version.Get().GetComparer();
    var K1Sma := Version.Get().GetVersion(Entity1Smallest);
    var K2As3 := Version.Get().GetVersion(Entity2More1SameAs3);
    var K3As2 := Version.Get().GetVersion(Entity3More1SameAs2);

    Assert.IsTrue(Comparer.Compare(K1Sma, K2As3) < 0);
    Assert.IsTrue(Comparer.Compare(K2As3, K1Sma) > 0);
    Assert.IsTrue(Comparer.Compare(K1Sma, K1Sma) = 0);
    Assert.IsTrue(Comparer.Compare(K2As3, K3As2) = 0);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TVersionTest);

end.
