unit mp3p_;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, MPlayer, ComCtrls,

  MMSYSTEM, FileCtrl, Vcl.Samples.Gauges; // эти ссылки вставлены вручную

type
  TForm1 = class(TForm)
    // кнопки
    SpeedButton1: TSpeedButton; // Предыдущая композиция
    SpeedButton2: TSpeedButton; // Воспроизведение/Стоп
    SpeedButton3: TSpeedButton; // Следующая композиция
    SpeedButton4: TSpeedButton; // Выбор папки

    ListBox1: TListBox; // Список композиций (mp3 файлов)

    MediaPlayer1: TMediaPlayer; // медиа плеер

    TrackBar1: TTrackBar; // регулятор громкости

    Timer1: TTimer;
    Label1: TLabel;
    Label2: TLabel;

    Shape1: TShape;
    Label3: TLabel;
    Gauge1: TGauge; // рамка вокруг кнопок

    procedure FormCreate(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton3Click(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure SpeedButton4Click(Sender: TObject);

    // эти объявления вставлены сюда вручную
    procedure Play; // воспроизведение
    procedure PlayList(Path: string);

  private
    { Private declarations }
  public
     protected
      procedure WMGetSysCommand(var Message : TMessage) ; message WM_SYSCOMMAND;
      //procedure CreateParams(var Params: TCreateParams); override;
  end;

type  TPlayTime = record
  position: int64;
  min, sec: integer;
end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses Unit2;
var
  time: TPlayTime;
  SoundPath: string[255];
  min,sec: integer; // время воспроизведения
  volume: LongWord; // старшее слово - правый канал,
                    // младшее - левый.
  FCreate: boolean;
  st_array: array of string;
  last_pos: int64;
  mouse_hook, keyboard_hook: THandle;
  KeyPressed: boolean;


procedure SButton1;
begin
  if Form1.ListBox1.ItemIndex > 0 then
    Form1.ListBox1.ItemIndex := Form1.ListBox1.ItemIndex - 1;

  Form1.MediaPlayer1.Stop;
  Form1.Label2.Caption := '0:00';
  Time.position := 0;
  Time.min := 0;
  Time.sec := 0;
  sec := 0;
  min := 0;
  Form1.Label3.Caption := '00:00:00';
  Form1.Play;
end;

procedure SButton2;
begin
  if Form1.SpeedButton2.Down then
    // начать воспроизведение
    Form1.Play
  else
    // если кнопка Воспроизведение нажата
    begin
      Form1.MediaPlayer1.Stop;
      Time.position := Form1.MediaPlayer1.Position;
      Time.min := min;
      Time.sec := sec;
      Form1.Timer1.Enabled := False;
      Form1.SpeedButton2.Down := False;
      Form1.SPeedButton2.Hint := 'Play';
    end;
end;

procedure SButton3;
begin
  if Form1.ListBox1.ItemIndex < Form1.ListBox1.Count then
    Form1.ListBox1.ItemIndex := Form1.ListBox1.ItemIndex + 1;

  Form1.MediaPlayer1.Stop;
  Form1.Label2.Caption := '0:00';
  Time.position := 0;
  Time.min := 0;
  Time.sec := 0;
  sec := 0;
  min := 0;
  Form1.Label3.Caption := '00:00:00';
  Form1.Play;
end;

procedure SButton4;
var
  Root: string;      // корневой каталог
  pwRoot : PWideChar;
  Dir: string;
  i: integer;
begin
  Root := ''; // корневой каталог - папка Рабочий стол
  GetMem(pwRoot, (Length(Root)+1) * 2);
  pwRoot := StringToWideChar(Root,pwRoot,MAX_PATH*2);
  if not SelectDirectory('Выберите папку', pwRoot, Dir) then Dir :=''
  else Dir := Dir+'\';

  // каталог, в котором находятся MP3 файлы выбран
  i := length(st_array)+1;
  SetLength(st_array, i);
  st_array[i-1] := Dir;

  Form1.PlayList(Dir);
end;

function keyboardhook(nCode: Integer; WParam: WPARAM; LParam: LPARAM) : LRESULT stdcall;
var buf: array[Byte] of Char;
begin
  GetWindowText(GetForegroundWindow, buf, Length(buf)*SizeOf(buf[0]));
  if (buf <> Form1.Caption) and (WParam = WM_KEYDOWN) and (not KeyPressed) then
    begin
      if GetAsyncKeyState(113) <> 0 then //F2
        if (Form1.TrackBar1.Position - 1) >= 0 then
          Form1.TrackBar1.Position := Form1.TrackBar1.Position - 1; // -volume

      if GetAsyncKeyState(114) <> 0 then //F3
        if (Form1.TrackBar1.Position + 1) <= Form1.TrackBar1.Max then
          Form1.TrackBar1.Position := Form1.TrackBar1.Position + 1;// +volume

      if GetAsyncKeyState(115) <> 0 then //F4
        begin
          if not Form1.SpeedButton2.Down then Form1.SpeedButton2.Down := True
          else Form1.SpeedButton2.Down := False;

          SButton2; // on/off
        end;

      if GetAsyncKeyState(117) <> 0 then //F6
        SButton1; // back

      if GetAsyncKeyState(118) <> 0 then //F7
        SButton3; // next

      KeyPressed := True;
    end
  else
    if WParam = WM_KEYUP then
      begin
        KeyPressed := False;
      end;


  Result := CallNextHookEx(keyboard_hook,nCode,WParam,LParam);
end;

procedure TForm1.WMGetSysCommand(var Message : TMessage) ;
begin
  if (Message.wParam = SC_MINIMIZE) then
    begin
      keyboard_hook := SetWindowsHookEx(13, keyboardhook,HInstance,0);
    end;
  Inherited;
end;

(*) для кнопки прекратить воспроизвдение (квадратик в кружочке) (*)
//MediaPlayer1.Stop;
//      Timer1.Enabled := False;
//      SpeedButton2.Down := False;
//      SPeedButton2.Hint := 'Play';

function MouseHook(nCode:Integer; WParam:WPARAM; LParam:LPARAM) : LRESULT stdcall;
var buf: array[Byte] of Char;
    P: TPoint;
begin
  GetWindowText(GetForegroundWindow, buf, Length(buf)*SizeOf(buf[0]));
  if (GetAsyncKeyState(1) <> 0) and (buf = Form1.Caption) and (Form1.MediaPlayer1.FileName <> '') then
    begin
      GetCursorPos(P);
      P := Form1.Gauge1.ScreenToClient(P);
      if (P.Y >= 0) and (P.Y <= Form1.Gauge1.Height) then
        begin
          Form1.Gauge1.Progress := round((P.X / Form1.Gauge1.Width) * Form1.Gauge1.MaxValue);
          Form1.MediaPlayer1.Stop;
          min := (Form1.Gauge1.Progress div 1000) div 60;
          sec := (Form1.Gauge1.Progress div 1000) mod 60;
          Form1.MediaPlayer1.Position := Form1.Gauge1.Progress;
          Form1.MediaPlayer1.Play;
        end;
    end;

  Result := CallNextHookEx(mouse_hook,nCode,WParam,LParam);
end;

procedure SetMouseHook();
begin
  mouse_hook := SetWindowsHookEx(14,MouseHook,HInstance,0);
end;

function find_path(track: string): string;
var p, dir: string;
    j, e: integer;
begin
  e := Length(st_array)-1;
  for j := 0 to e do
    begin
      dir := st_array[j];
      p := FileSearch(track, dir);
      if p <> '' then
        begin
          find_path := p;
          break;
        end;
    end;
end;

// формирует список MP3 файлов
procedure TForm1.PlayList(Path: string);
var
  lpBuf: PChar;          // указатель на nul-terminated строку
  sWinDir: string[128];  // обычная Паскаль строка
  SearchRec: TSearchRec; // структура SearchRec содержит информацию
                         // о файле, удовлетворяющем условию поиска
begin
  // сформировать список mp3 файлов
  if FindFirst(Path + '*.mp3', faAnyFile, SearchRec) = 0 then
     begin
      ListBox1.Items.Add(SearchRec.Name);
      while (FindNext(SearchRec) = 0) do
        begin
          ListBox1.Items.Add(SearchRec.Name);
        end;
     end;
   ListBox1.ItemIndex := 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
var a: string;
begin
   ListBox1.Clear;
   ListBox1.ItemIndex := 0;

   TrackBar1.Position := 7;

   Label3.Caption := '00:00:00';

   volume := (TrackBar1.Position - TrackBar1.Max+1)* 6500;
   volume := volume + (volume shl 16);
   waveOutSetVolume(WAVE_MAPPER,volume); // уровень сигнала

   SetMouseHook();
end;

// щелчок на названии произведения
procedure TForm1.ListBox1Click(Sender: TObject);
begin
  // вывести в поле метки Label1 имя выбранного файла
 if not SpeedButton2.Down then  SpeedButton2.Down := True;
 Label1.Caption:=ListBox1.Items[ListBox1.itemIndex];

 Play;

 Label2.Caption := '0:00';
 Time.position := 0;
 Time.min := 0;
 Time.sec := 0;
 sec := 0;
 min := 0;
 Label3.Caption := '00:00:00';
end;




// кнопка К предыдущей
procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  SButton1;
end;

// щелчок на кнопке Воспроизведение
procedure TForm1.SpeedButton2Click(Sender: TObject);
begin
  SButton2;
end;

// кнопка К следующей
procedure TForm1.SpeedButton3Click(Sender: TObject);
begin
  SButton3;
end;

// добавленмя песни
procedure TForm1.SpeedButton4Click(Sender: TObject);
begin
  SButton4;
end;




// пользователь изменил положение
// регулятора громкости
procedure TForm1.TrackBar1Change(Sender: TObject);
begin
  volume := 6500 * (TrackBar1.Max - TrackBar1.Position);
  volume := volume +   (volume shl 16);
  waveOutSetVolume(WAVE_MAPPER,volume);
end;

// воспроизведение композиции название которой выделено в ListBox1
procedure TForm1.Play;
begin
  Timer1.Enabled := False;
  Label1.Caption := ListBox1.Items[ListBox1.itemIndex];
  MediaPlayer1.FileName := find_path(Label1.Caption);;


  try
   Mediaplayer1.Open;
  except
    on EMCIDeviceError do
      begin
        ShowMessage('Ошибка обращения к файлу '+
                     ListBox1.Items[ListBox1.itemIndex]);
        SpeedButton2.Down := False;
        exit;
      end;
  end;

  Gauge1.MaxValue := MediaPlayer1.Length;

  if Time.position = 0 then
    begin
      min := 0;
      sec := 0;
    end
  else
    begin
      min := Time.min;
      sec := Time.sec;
      MediaPlayer1.Position := Time.position;
    end;


  MediaPlayer1.Play;

  Form1.Label3.Caption := FormatDateTime('hh:nn:ss',(MediaPlayer1.Length div 1000)/(24*60*60));


  Timer1.Enabled := True;
  SpeedButton2.Hint := 'Stop';
end;

// сигнал от таймера
procedure TForm1.Timer1Timer(Sender: TObject);
begin
  // изменить счетчик времени
  if sec < 59 then
    inc(sec)
  else
    begin
      sec :=0;
      inc(min);
    end;

  // вывести время воспроизведения
  Label2.Caption := IntToStr(min)+':';
  if sec < 10 then Label2.Caption :=
           Label2.Caption +'0'+ IntToStr(sec)
  else Label2.Caption :=
           Label2.Caption + IntToStr(sec);

   Gauge1.Progress := MediaPlayer1.Position;

  // если воспроизведение текущей композиции
  // не завершено
  if MediaPlayer1.Position < MediaPlayer1.Length then exit;

  // воспроизведение текущей композиции
  // закончено
  Timer1.Enabled := False; // остановить таймер
  MediaPlayer1.Stop;       // остановить плеер

  if ListBox1.ItemIndex < ListBox1.Count then       // список не исчерпан
    begin
      ListBox1.ItemIndex := ListBox1.ItemIndex + 1;
      Play;
    end
end;

end.
