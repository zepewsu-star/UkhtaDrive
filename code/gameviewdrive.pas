unit GameViewDrive;

interface

uses
  Classes,
  CastleVectors, CastleViewport, CastleScene, CastleUIControls,
  CastleControls, CastleKeysMouse, CastleTransform,
  GameVehicle;

type
  TViewDrive = class(TCastleView)
  private
    MainViewport: TCastleViewport;
    Vehicle: TVehicleState;
    HudSpeed: TCastleLabel;
    HudHelp: TCastleLabel;
    Hood: TCastleBox;
    Dashboard: TCastleBox;
    NightMode: Boolean;
    procedure AddBox(const X, Y, Z, W, H, D: Single; const C: TVector4);
    procedure BuildWorld;
    procedure UpdateCameraAndCockpit;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

var
  ViewDrive: TViewDrive;

implementation

uses
  SysUtils, Math, CastleColors, CastleCameras;

constructor TViewDrive.Create(AOwner: TComponent);
begin
  inherited;
  NightMode := False;
end;

procedure TViewDrive.AddBox(const X, Y, Z, W, H, D: Single; const C: TVector4);
var
  B: TCastleBox;
begin
  B := TCastleBox.Create(FreeAtStop);
  B.Size := Vector3(W, H, D);
  B.Translation := Vector3(X, Y, Z);
  B.Color := C;
  MainViewport.Items.Add(B);
end;

procedure TViewDrive.BuildWorld;
var
  Ground: TCastlePlane;
  Sun: TCastleDirectionalLight;
  I: Integer;
begin
  Ground := TCastlePlane.Create(FreeAtStop);
  Ground.Size := Vector2(700, 700);
  Ground.Color := Vector4(0.78, 0.82, 0.84, 1.0);
  MainViewport.Items.Add(Ground);

  Sun := TCastleDirectionalLight.Create(FreeAtStop);
  Sun.Intensity := 2.5;
  Sun.Color := Vector3(0.96, 0.97, 1.0);
  Sun.Direction := Vector3(0.35, -0.85, 0.35);
  MainViewport.Items.Add(Sun);

  { Main avenue and yard roads. }
  AddBox(0, 0.03, 0, 620, 0.06, 24, Vector4(0.12, 0.13, 0.14, 1));
  AddBox(10, 0.035, 48, 11, 0.07, 92, Vector4(0.16, 0.17, 0.18, 1));
  AddBox(-18, 0.04, 40, 65, 0.08, 9, Vector4(0.17, 0.18, 0.19, 1));

  { Lane markings. }
  for I := -20 to 20 do
    AddBox(I * 14, 0.075, 0, 7, 0.025, 0.14, Vector4(0.92, 0.90, 0.68, 1));

  { Apartment blocks. }
  AddBox(-31, 7.5, 67, 54, 15, 14, Vector4(0.58, 0.52, 0.45, 1));
  AddBox(43, 7.5, 69, 30, 15, 13, Vector4(0.62, 0.58, 0.52, 1));
  AddBox(-62, 7.5, 34, 36, 15, 13, Vector4(0.54, 0.57, 0.59, 1));
  AddBox(66, 13.5, 32, 34, 27, 13, Vector4(0.48, 0.51, 0.54, 1));

  AddBox(-230, 13.5, -32, 55, 27, 16, Vector4(0.51, 0.53, 0.55, 1));
  AddBox(-160, 7.5, -32, 46, 15, 16, Vector4(0.63, 0.57, 0.50, 1));
  AddBox(-95, 7.5, -32, 42, 15, 16, Vector4(0.59, 0.53, 0.47, 1));
  AddBox(95, 13.5, -32, 48, 27, 16, Vector4(0.49, 0.52, 0.55, 1));
  AddBox(165, 7.5, -32, 45, 15, 16, Vector4(0.62, 0.56, 0.49, 1));
  AddBox(235, 13.5, -32, 52, 27, 16, Vector4(0.50, 0.52, 0.54, 1));

  AddBox(-220, 7.5, 32, 52, 15, 16, Vector4(0.59, 0.54, 0.48, 1));
  AddBox(-150, 13.5, 32, 48, 27, 16, Vector4(0.50, 0.53, 0.55, 1));
  AddBox(125, 7.5, 32, 48, 15, 16, Vector4(0.60, 0.55, 0.49, 1));
  AddBox(205, 13.5, 32, 55, 27, 16, Vector4(0.50, 0.53, 0.56, 1));
end;

procedure TViewDrive.Start;
begin
  inherited;

  MainViewport := TCastleViewport.Create(FreeAtStop);
  MainViewport.FullSize := True;
  MainViewport.BackgroundColor := Vector4(0.47, 0.59, 0.72, 1.0);
  InsertBack(MainViewport);

  BuildWorld;
  Vehicle := TVehicleState.Create;

  { Simple first-person cockpit placeholders. They are moved with the camera. }
  Hood := TCastleBox.Create(FreeAtStop);
  Hood.Size := Vector3(1.9, 0.16, 1.35);
  Hood.Color := Vector4(0.12, 0.16, 0.19, 1);
  MainViewport.Items.Add(Hood);

  Dashboard := TCastleBox.Create(FreeAtStop);
  Dashboard.Size := Vector3(2.15, 0.38, 0.45);
  Dashboard.Color := Vector4(0.035, 0.038, 0.042, 1);
  MainViewport.Items.Add(Dashboard);

  HudSpeed := TCastleLabel.Create(FreeAtStop);
  HudSpeed.FontSize := 24;
  HudSpeed.Color := White;
  HudSpeed.Anchor(hpLeft, 18);
  HudSpeed.Anchor(vpTop, -18);
  InsertFront(HudSpeed);

  HudHelp := TCastleLabel.Create(FreeAtStop);
  HudHelp.FontSize := 16;
  HudHelp.Color := White;
  HudHelp.Caption := 'UKHTA DRIVE 0.1' + NL +
    'W/S - gas/brake   A/D - steering   SPACE - handbrake' + NL +
    'R - reset   N - day/night';
  HudHelp.Anchor(hpLeft, 18);
  HudHelp.Anchor(vpBottom, 18);
  InsertFront(HudHelp);

  UpdateCameraAndCockpit;
end;

procedure TViewDrive.Stop;
begin
  FreeAndNil(Vehicle);
  inherited;
end;

procedure TViewDrive.UpdateCameraAndCockpit;
var
  Dir, RightV: TVector3;
  CamX, CamZ: Single;
begin
  Dir := Vector3(Sin(Vehicle.Yaw), -0.02, -Cos(Vehicle.Yaw));
  MainViewport.Camera.SetWorldView(
    Vector3(Vehicle.X, 1.55, Vehicle.Z),
    Dir,
    Vector3(0, 1, 0));

  CamX := Vehicle.X;
  CamZ := Vehicle.Z;
  RightV := Vector3(Cos(Vehicle.Yaw), 0, Sin(Vehicle.Yaw));

  Hood.Translation := Vector3(
    CamX + Dir.X * 1.65,
    0.82,
    CamZ + Dir.Z * 1.65);
  Hood.Rotation := Vector4(0, 1, 0, Vehicle.Yaw);

  Dashboard.Translation := Vector3(
    CamX + Dir.X * 0.88,
    1.08,
    CamZ + Dir.Z * 0.88);
  Dashboard.Rotation := Vector4(0, 1, 0, Vehicle.Yaw);
end;

procedure TViewDrive.Update(const SecondsPassed: Single; var HandleInput: Boolean);
var
  Input: TDriveInput;
begin
  inherited;

  Input.Gas := Container.Pressed[keyW] or Container.Pressed[keyArrowUp];
  Input.Brake := Container.Pressed[keyS] or Container.Pressed[keyArrowDown];
  Input.Left := Container.Pressed[keyA] or Container.Pressed[keyArrowLeft];
  Input.Right := Container.Pressed[keyD] or Container.Pressed[keyArrowRight];
  Input.HandBrake := Container.Pressed[keySpace];

  Vehicle.Update(SecondsPassed, Input);
  UpdateCameraAndCockpit;

  HudSpeed.Caption := Format('%d km/h   ODO %.2f km',
    [Round(Abs(Vehicle.Speed) * 3.6), Vehicle.Odometer]);
end;

function TViewDrive.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit;

  if Event.IsKey(keyR) then
  begin
    Vehicle.Reset;
    UpdateCameraAndCockpit;
    Exit(True);
  end;

  if Event.IsKey(keyN) then
  begin
    NightMode := not NightMode;
    if NightMode then
      MainViewport.BackgroundColor := Vector4(0.045, 0.065, 0.10, 1)
    else
      MainViewport.BackgroundColor := Vector4(0.47, 0.59, 0.72, 1);
    Exit(True);
  end;
end;

end.
