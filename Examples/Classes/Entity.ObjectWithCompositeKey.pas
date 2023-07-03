unit Entity.ObjectWithCompositeKey;

interface

type
  TObjectWithCompositeKey = class
  private
    FCategoryName : String;
    FTypeName : String;

    FCount : Integer;
  public
    constructor Create(const ACategoryName : String; const ATypeName : String; ACount : Integer);

    property CategoryName : String read FCategoryName;
    property TypeName : String read FTypeName;
    property Count : Integer read FCount;
  end;

implementation

constructor TObjectWithCompositeKey.Create(const ACategoryName : String; const ATypeName : String; ACount : Integer);
begin
  FCategoryName := ACategoryName;
  FTypeName := ATypeName;
  FCount := ACount;
end;

end.
