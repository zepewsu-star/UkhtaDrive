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
    Cockpit: TCastleImageControl;
    SteeringWheel: TCastleImageControl;
    HudSpeed: TCastleLabel;
    HudStatus: TCastleLabel;
    Fog: TCastleFog;
    Sun: TCastleDirectionalLight;
    NightMode: Boolean;
    procedure AddBox(const X, Y, Z, W, H, D: Single; const C: TVector4;
      const TextureUrl: String = ''; const NormalUrl: String = '';
      const TextureScaleX: Single = 1; const TextureScaleY: Single = 1);
    procedure AddBuilding(const X, Z, W, D, H: Single;
      const TextureUrl: String; const Floors, Bays: Integer);
    procedure AddTree(const X, Z: Single);
    procedure AddLamp(const X, Z: Single);
    procedure AddParkedCar(const X, Z: Single; const C: TVector4);
    procedure BuildWorld;
    procedure ApplyLighting;
    procedure UpdateCameraAndCockpit;
    function MouseSteeringAxis: Single;
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

procedure TViewDrive.AddBox(const X, Y, Z, W, H, D: Single; const C: TVector4;
  const TextureUrl: String; const NormalUrl: String;
  const TextureScaleX: Single; const TextureScaleY: Single);
var
  B: TCastleBox;
begin
  B := TCastleBox.Create(FreeAtStop);
  B.Size := Vector3(W, H, D);
  B.Translation := Vector3(X, Y, Z);
  B.Color := C;
  if TextureUrl <> '' then
  begin
    B.Texture := TextureUrl;
    B.TextureScale := Vector2(TextureScaleX, TextureScaleY);
  end;
  if NormalUrl <> '' then
    B.TextureNormalMap := NormalUrl;
  MainViewport.Items.Add(B);
end;

procedure TViewDrive.AddBuilding(const X, Z, W, D, H: Single;
  const TextureUrl: String; const Floors, Bays: Integer);
var
  RoofColor: TVector4;
begin
  AddBox(X, H * 0.5, Z, W, H, D, White, TextureUrl, '',
    Max(2.0, D / 8.0), Max(2.0, H / 8.0));
  RoofColor := Vector4(0.46, 0.49, 0.52, 1);
  AddBox(X, H + 0.22, Z, W + 0.45, 0.44, D + 0.45, RoofColor);

  { Entrance volume and canopy make the facade read less like a simple box. }
  if X < 0 then
  begin
    AddBox(X + W * 0.5 + 0.50, 1.35, Z + D * 0.22,
      1.05, 2.7, 3.2, Vector4(0.12, 0.14, 0.16, 1));
    AddBox(X + W * 0.5 + 1.05, 2.7, Z + D * 0.22,
      2.1, 0.16, 3.7, Vector4(0.30, 0.31, 0.33, 1));
  end else
  begin
    AddBox(X - W * 0.5 - 0.50, 1.35, Z + D * 0.22,
      1.05, 2.7, 3.2, Vector4(0.12, 0.14, 0.16, 1));
    AddBox(X - W * 0.5 - 1.05, 2.7, Z + D * 0.22,
      2.1, 0.16, 3.7, Vector4(0.30, 0.31, 0.33, 1));
  end;
end;

procedure TViewDrive.AddTree(const X, Z: Single);
var
  Trunk: TCastleCylinder;
  Crown1, Crown2, Crown3: TCastleCone;
begin
  Trunk := TCastleCylinder.Create(FreeAtStop);
  Trunk.Radius := 0.18;
  Trunk.Height := 4.4;
  Trunk.Slices := 12;
  Trunk.Color := Vector4(0.19, 0.12, 0.07, 1);
  Trunk.Translation := Vector3(X, 2.2, Z);
  MainViewport.Items.Add(Trunk);

  Crown1 := TCastleCone.Create(FreeAtStop);
  Crown1.BottomRadius := 2.3;
  Crown1.Height := 5.0;
  Crown1.Slices := 18;
  Crown1.Color := Vector4(0.055, 0.14, 0.10, 1);
  Crown1.Translation := Vector3(X, 4.7, Z);
  MainViewport.Items.Add(Crown1);

  Crown2 := TCastleCone.Create(FreeAtStop);
  Crown2.BottomRadius := 1.75;
  Crown2.Height := 4.4;
  Crown2.Slices := 18;
  Crown2.Color := Vector4(0.06, 0.16, 0.115, 1);
  Crown2.Translation := Vector3(X, 6.6, Z);
  MainViewport.Items.Add(Crown2);

  Crown3 := TCastleCone.Create(FreeAtStop);
  Crown3.BottomRadius := 1.15;
  Crown3.Height := 3.5;
  Crown3.Slices := 18;
  Crown3.Color := Vector4(0.09, 0.19, 0.14, 1);
  Crown3.Translation := Vector3(X, 8.1, Z);
  MainViewport.Items.Add(Crown3);
end;

procedure TViewDrive.AddLamp(const X, Z: Single);
var
  Pole: TCastleCylinder;
  Light: TCastlePointLight;
begin
  Pole := TCastleCylinder.Create(FreeAtStop);
  Pole.Radius := 0.075;
  Pole.Height := 8.3;
  Pole.Slices := 12;
  Pole.Color := Vector4(0.13, 0.14, 0.15, 1);
  Pole.Translation := Vector3(X, 4.15, Z);
  MainViewport.Items.Add(Pole);

  AddBox(X, 8.15, Z, 0.7, 0.18, 0.38,
    Vector4(1.0, 0.75, 0.39, 1));

  Light := TCastlePointLight.Create(FreeAtStop);
  Light.Translation := Vector3(X, 7.8, Z);
  Light.Color := Vector3(1.0, 0.72, 0.42);
  Light.Intensity := 9.5;
  Light.Radius := 24;
  MainViewport.Items.Add(Light);
end;

procedure TViewDrive.AddParkedCar(const X, Z: Single; const C: TVector4);
var
  DarkC: TVector4;
begin
  DarkC := Vector4(0.035, 0.045, 0.055, 1);
  AddBox(X, 0.55, Z, 1.86, 0.70, 4.45, C);
  AddBox(X, 1.08, Z - 0.12, 1.62, 0.54, 2.35, DarkC);
  AddBox(X, 1.35, Z - 0.10, 1.44, 0.12, 1.8, C);
end;

procedure TViewDrive.BuildWorld;
var
  Ground: TCastlePlane;
  I: Integer;
  RoadTex, SnowTex: String;
begin
  RoadTex := 'castle-data:/visual/road_winter.jpg';
  SnowTex := 'castle-data:/visual/snow_winter.jpg';

  Ground := TCastlePlane.Create(FreeAtStop);
  Ground.Size := Vector2(1200, 1200);
  Ground.Color := White;
  Ground.Texture := SnowTex;
  Ground.TextureScale := Vector2(32, 32);
  MainViewport.Items.Add(Ground);

  Sun := TCastleDirectionalLight.Create(FreeAtStop);
  Sun.Color := Vector3(0.76, 0.82, 0.94);
  Sun.Direction := Vector3(0.30, -0.88, 0.30);
  MainViewport.Items.Add(Sun);

  Fog := TCastleFog.Create(FreeAtStop);
  Fog.VisibilityRange := 360;
  MainViewport.Fog := Fog;

  { Textured winter avenue. }
  AddBox(0, 0.04, -60, 24, 0.08, 1050, White,
    RoadTex, '', 3.0, 72.0);
  AddBox(-17.0, 0.09, -60, 9.0, 0.16, 1050, White,
    SnowTex, '', 2.0, 70.0);
  AddBox(17.0, 0.09, -60, 9.0, 0.16, 1050, White,
    SnowTex, '', 2.0, 70.0);
  AddBox(-12.2, 0.22, -60, 1.8, 0.42, 1050, White,
    SnowTex, '', 1.0, 70.0);
  AddBox(12.2, 0.22, -60, 1.8, 0.42, 1050, White,
    SnowTex, '', 1.0, 70.0);

  for I := -34 to 30 do
    AddBox(0, 0.092, I * 15, 0.17, 0.025, 7.0,
      Vector4(0.86, 0.84, 0.68, 1));

  { Intersections and side streets. }
  AddBox(0, 0.045, 145, 145, 0.09, 17, White,
    RoadTex, '', 10.0, 2.0);
  AddBox(0, 0.045, -80, 145, 0.09, 16, White,
    RoadTex, '', 10.0, 2.0);
  AddBox(0, 0.045, -285, 145, 0.09, 17, White,
    RoadTex, '', 10.0, 2.0);

  for I := -5 to 5 do
    AddBox(I * 1.75, 0.105, 82, 0.85, 0.028, 6.2,
      Vector4(0.83, 0.84, 0.82, 1));

  { Photo-derived facades. The geometry is still lightweight but the surface reads as a real city. }
  AddBuilding(-40, 215, 28, 38, 19,
    'castle-data:/visual/facade_1.jpg', 6, 7);
  AddBuilding(40, 210, 29, 36, 25,
    'castle-data:/visual/facade_2.jpg', 8, 7);
  AddBuilding(-43, 120, 35, 43, 28,
    'castle-data:/visual/facade_3.jpg', 9, 8);
  AddBuilding(42, 110, 32, 40, 19,
    'castle-data:/visual/facade_1.jpg', 6, 8);
  AddBuilding(-41, 25, 30, 38, 22,
    'castle-data:/visual/facade_2.jpg', 7, 7);
  AddBuilding(44, 15, 35, 44, 28,
    'castle-data:/visual/facade_3.jpg', 9, 9);
  AddBuilding(-42, -85, 34, 42, 25,
    'castle-data:/visual/facade_1.jpg', 8, 8);
  AddBuilding(41, -100, 31, 38, 19,
    'castle-data:/visual/facade_2.jpg', 6, 7);
  AddBuilding(-42, -198, 32, 41, 28,
    'castle-data:/visual/facade_3.jpg', 9, 8);
  AddBuilding(44, -212, 35, 43, 25,
    'castle-data:/visual/facade_1.jpg', 8, 9);
  AddBuilding(-40, -320, 30, 39, 19,
    'castle-data:/visual/facade_2.jpg', 6, 8);
  AddBuilding(43, -330, 33, 41, 28,
    'castle-data:/visual/facade_3.jpg', 9, 8);

  for I := -8 to 7 do
  begin
    AddLamp(-11.1, I * 55 + 5);
    AddLamp(11.1, I * 55 - 22);
    AddTree(-22.0, I * 57 + 18);
    AddTree(22.0, I * 57 - 8);
  end;

  AddParkedCar(-8.2, 178, Vector4(0.17, 0.23, 0.30, 1));
  AddParkedCar(8.1, 128, Vector4(0.42, 0.09, 0.07, 1));
  AddParkedCar(-8.2, 45, Vector4(0.57, 0.60, 0.63, 1));
  AddParkedCar(8.1, -20, Vector4(0.08, 0.12, 0.18, 1));
  AddParkedCar(-8.2, -135, Vector4(0.28, 0.30, 0.32, 1));
  AddParkedCar(8.1, -238, Vector4(0.34, 0.10, 0.09, 1));
  AddParkedCar(-8.1, -347, Vector4(0.15, 0.17, 0.20, 1));

  ApplyLighting;
end;

procedure TViewDrive.ApplyLighting;
begin
  if NightMode then
  begin
    MainViewport.BackgroundColor := Vector4(0.025, 0.045, 0.075, 1.0);
    Sun.Intensity := 0.25;
    Fog.Color := Vector3(0.06, 0.09, 0.14);
    Fog.VisibilityRange := 245;
    HudStatus.Caption := 'NIGHT  |  Mouse = steering  |  RMB = gas  |  LMB = brake';
  end else
  begin
    MainViewport.BackgroundColor := Vector4(0.29, 0.36, 0.46, 1.0);
    Sun.Intensity := 1.25;
    Fog.Color := Vector3(0.47, 0.53, 0.61);
    Fog.VisibilityRange := 360;
    HudStatus.Caption := 'UKHTA DRIVE 0.3  |  Mouse = steering  |  RMB = gas  |  LMB = brake';
  end;
end;

function TViewDrive.MouseSteeringAxis: Single;
var
  HalfW, V: Single;
begin
  if Container.PixelsWidth <= 0 then
    Exit(0);

  HalfW := Container.PixelsWidth * 0.5;
  V := (HalfW - Container.MousePosition.X) / (Container.PixelsWidth * 0.42);
  if Abs(V) < 0.035 then V := 0;
  if V > 1 then V := 1;
  if V < -1 then V := -1;
  Result := V;
end;

procedure TViewDrive.Start;
begin
  inherited;

  MainViewport := TCastleViewport.Create(FreeAtStop);
  MainViewport.FullSize := True;
  InsertBack(MainViewport);

  Vehicle := TVehicleState.Create;

  HudStatus := TCastleLabel.Create(FreeAtStop);
  HudStatus.FontSize := 14;
  HudStatus.Color := Vector4(0.94, 0.96, 0.98, 0.92);
  HudStatus.Anchor(hpMiddle);
  HudStatus.Anchor(vpTop, -18);

  BuildWorld;

  { High-detail cockpit reference overlay. Windshield area is transparent. }
  Cockpit := TCastleImageControl.Create(FreeAtStop);
  Cockpit.Url := 'castle-data:/visual/cockpit_hq.png';
  Cockpit.Stretch := True;
  Cockpit.Width := 1600;
  Cockpit.Height := 900;
  Cockpit.Left := 0;
  Cockpit.Bottom := 0;
  InsertFront(Cockpit);

  SteeringWheel := TCastleImageControl.Create(FreeAtStop);
  SteeringWheel.Url := 'castle-data:/visual/steering_hq.png';
  SteeringWheel.Stretch := True;
  SteeringWheel.Width := 450;
  SteeringWheel.Height := 450;
  SteeringWheel.Left := 265;
  SteeringWheel.Bottom := -5;
  SteeringWheel.RotationCenter := Vector2(0.5, 0.5);
  InsertFront(SteeringWheel);

  HudSpeed := TCastleLabel.Create(FreeAtStop);
  HudSpeed.FontSize := 20;
  HudSpeed.Color := Vector4(0.84, 0.93, 1.0, 1);
  HudSpeed.Left := 500;
  HudSpeed.Bottom := 245;
  InsertFront(HudSpeed);

  InsertFront(HudStatus);

  Container.MousePosition := Vector2(Container.PixelsWidth * 0.5,
    Container.PixelsHeight * 0.5);
  UpdateCameraAndCockpit;
end;

procedure TViewDrive.Stop;
begin
  FreeAndNil(Vehicle);
  inherited;
end;

procedure TViewDrive.UpdateCameraAndCockpit;
var
  Dir: TVector3;
begin
  Dir := Vector3(Sin(Vehicle.Yaw), -0.024, -Cos(Vehicle.Yaw));
  MainViewport.Camera.SetWorldView(
    Vector3(Vehicle.X, 1.62, Vehicle.Z),
    Dir,
    Vector3(0, 1, 0));

  if SteeringWheel <> nil then
    SteeringWheel.Rotation := -Vehicle.Steering * 3.4;
end;

procedure TViewDrive.Update(const SecondsPassed: Single; var HandleInput: Boolean);
var
  Input: TDriveInput;
begin
  inherited;

  Input.Gas := (buttonRight in Container.MousePressed) or
    Container.Pressed[keyW] or Container.Pressed[keyArrowUp];
  Input.Brake := (buttonLeft in Container.MousePressed) or
    Container.Pressed[keyS] or Container.Pressed[keyArrowDown];
  Input.SteeringAxis := MouseSteeringAxis;
  Input.Left := Container.Pressed[keyA] or Container.Pressed[keyArrowLeft];
  Input.Right := Container.Pressed[keyD] or Container.Pressed[keyArrowRight];
  Input.HandBrake := Container.Pressed[keySpace];

  Vehicle.Update(SecondsPassed, Input);
  UpdateCameraAndCockpit;

  if Vehicle.Speed < -0.4 then
    HudSpeed.Caption := Format('R  %3d km/h', [Round(Abs(Vehicle.Speed) * 3.6)])
  else
    HudSpeed.Caption := Format('D  %3d km/h', [Round(Abs(Vehicle.Speed) * 3.6)]);
end;

function TViewDrive.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited;
  if Result then Exit;

  if Event.IsKey(keyR) then
  begin
    Vehicle.Reset;
    Container.MousePosition := Vector2(Container.PixelsWidth * 0.5,
      Container.PixelsHeight * 0.5);
    UpdateCameraAndCockpit;
    Exit(True);
  end;

  if Event.IsKey(keyN) then
  begin
    NightMode := not NightMode;
    ApplyLighting;
    Exit(True);
  end;
end;

end.
