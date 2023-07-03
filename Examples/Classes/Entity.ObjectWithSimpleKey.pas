unit Entity.ObjectWithSimpleKey;

interface

type
  TObjectWithSimpleKey = class
  private
    FId : Int64;
    FName : String;
  public
    constructor Create(AId : Int64; const AName : String);

    property Id : Int64 read FId;
    property Name : String read FName;
  end;

implementation

constructor TObjectWithSimpleKey.Create(AId : Int64; const AName : String);
begin
  FId := AId;
  FName := AName;
end;

end.
