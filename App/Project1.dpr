program Project1;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  Entity.Base.Key in '..\RestRepository\Entity.Base.Key.pas',
  Entity.Base in '..\RestRepository\Entity.Base.pas',
  Entity.Base.Version in '..\RestRepository\Entity.Base.Version.pas',
  Memory in '..\RestRepository\Memory.pas',
  Repository.Base in '..\RestRepository\Repository.Base.pas',
  Repository.Rest.Errors in '..\RestRepository\Repository.Rest.Errors.pas',
  Repository.Rest.Operations in '..\RestRepository\Repository.Rest.Operations.pas',
  Repository.Rest in '..\RestRepository\Repository.Rest.pas',
  Repository.Rest.ResponseExtractor in '..\RestRepository\Repository.Rest.ResponseExtractor.pas',
  Utils.Rtti in '..\RestRepository\Utils.Rtti.pas',
  Utils.RttiContext in '..\RestRepository\Utils.RttiContext.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
