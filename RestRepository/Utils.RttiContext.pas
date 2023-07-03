unit Utils.RttiContext;

interface
uses
  Rtti;

var
  GRttiCtx : TRttiContext;

implementation

initialization
  GRttiCtx := TRttiContext.Create();
finalization
  GRttiCtx.Free();

end.
