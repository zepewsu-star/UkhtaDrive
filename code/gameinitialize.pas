unit GameInitialize;

interface

implementation

uses
  SysUtils,
  CastleWindow,
  GameViewDrive;

var
  Window: TCastleWindow;

procedure ApplicationInitialize;
begin
  Window.Container.LoadSettings('castle-data:/CastleSettings.xml');
  ViewDrive := TViewDrive.Create(Application);
  Window.Container.View := ViewDrive;
end;

initialization
  Application.OnInitialize := @ApplicationInitialize;
  Window := TCastleWindow.Create(Application);
  Application.MainWindow := Window;
  Window.Width := 1600;
  Window.Height := 900;
  Window.ParseParameters;
end.
