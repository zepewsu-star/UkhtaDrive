program ukhta_drive_standalone;

{$ifdef MSWINDOWS}
  {$apptype GUI}
{$endif}

uses
  CastleWindow,
  GameInitialize;

begin
  Application.MainWindow.OpenAndRun;
end.
