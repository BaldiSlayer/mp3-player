program mp3p;

uses
  Forms,
  MP3P_ in 'MP3P_.PAS' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
