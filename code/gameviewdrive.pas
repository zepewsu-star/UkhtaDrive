unit GameViewDrive;

interface

uses
  Classes,
  CastleVectors, CastleViewport, CastleScene, CastleUIControls,
  CastleControls, CastleKeysMouse, CastleTransform,
  GameVehicle, GameCockpit3D;

type
  TViewDrive = class(TCastleView)
  private
    MainViewport: TCastleViewport;
    Vehicle: TVehicleState;
    Cockpit3D: TCockpit3D;
    HudSpeed: TCastleLabel;
    HudStatus: TCastleLabel;
    Fog: TCastleFog;
    Sun: TCastleDirectionalLight;
    NightMode: Boolean;
    procedure AddBox(const X, Y, Z, W, H, D: Single; const C: TVector4;
      const TextureUrl: String = ''; const NormalUrl: String = '';
      const TexScale: Single = 1.0);
    procedure AddBuilding(const X, Z, W, D, H: Single; const Variant: Integer);
    procedure AddTree(const X, Z: Single);
    procedure AddLamp(const X, Z: Single);
    procedure AddParkedCar(const X, Z: Single; const C: TVector4);
    procedure BuildWorld;
    procedure ApplyLighting;
    procedure UpdateCameraAndCockpit;
    function ClampS(const V, AMin, AMax: Single): Single;
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
  SysUtils, Math, CastleColors, CastleCameras, CastleWindow;

constructor TViewDrive.Create(AOwner: TComponent);
begin
  inherited;
  NightMode := False;
end;

function TViewDrive.ClampS(const V, AMin, AMax: Single): Single;
begin
  if V < AMin then Result := AMin
  else if V > AMax then Result := AMax
  else Result := V;
end;

procedure TViewDrive.AddBox(const X, Y, Z, W, H, D: Single;
  const C: TVector4; const TextureUrl, NormalUrl: String;
  const TexScale: Single);
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
    B.TextureScale := Vector2(TexScale, TexScale);
  end;
  if NormalUrl <> '' then
    B.TextureNormalMap := NormalUrl;
  MainViewport.Items.Add(B);
end;

procedure TViewDrive.AddBuilding(const X, Z, W, D, H: Single; const Variant: Integer);
var
  Tex, Norm: String;
  RoofC: TVector4;
begin
  case Variant mod 3 of
    0:
      begin
        Tex := 'castle-data:/visual/facade_1.png';
        Norm := 'castle-data:/visual/facade_1_normal.png';
      end;
    1:
      begin
        Tex := 'castle-data:/visual/facade_2.png';
        Norm := 'castle-data:/visual/facade_2_normal.png';
      end;
    else
      begin
        Tex := 'castle-data:/visual/facade_3.png';
        Norm := 'castle-data:/visual/facade_3_normal.png';
      end;
  end;

  AddBox(X, H * 0.5, Z, W, H, D, Vector4(0.80, 0.80, 0.80, 1),
    Tex, Norm, 3.2);

  RoofC := Vector4(0.38, 0.40, 0.42, 1);
  AddBox(X, H + 0.18, Z, W + 0.35, 0.36, D + 0.35, RoofC);

  if X < 0 then
    AddBox(X + W * 0.5 + 0.60, 1.30, Z + D * 0.22,
      1.20, 2.60, 3.10, Vector4(0.16, 0.18, 0.20, 1))
  else
    AddBox(X - W * 0.5 - 0.60, 1.30, Z + D * 0.22,
      1.20, 2.60, 3.10, Vector4(0.16, 0.18, 0.20, 1));
end;

procedure TViewDrive.AddTree(const X, Z: Single);
var
  Trunk: TCastleCylinder;
  C1, C2, Snow: TCastleCone;
begin
  Trunk := TCastleCylinder.Create(FreeAtStop);
  Trunk.Radius := 0.20;
  Trunk.Height := 4.0;
  Trunk.Slices := 12;
  Trunk.Color := Vector4(0.19, 0.12, 0.075, 1);
  Trunk.Translation := Vector3(X, 2.0, Z);
  MainViewport.Items.Add(Trunk);

  C1 := TCastleCone.Create(FreeAtStop);
  C1.BottomRadius := 2.15;
  C1.Height := 5.5;
  C1.Slices := 18;
  C1.Color := Vector4(0.055, 0.15, 0.105, 1);
  C1.Translation := Vector3(X, 4.7, Z);
  MainViewport.Items.Add(C1);

  C2 := TCastleCone.Create(FreeAtStop);
  C2.BottomRadius := 1.55;
  C2.Height := 4.3;
  C2.Slices := 18;
  C2.Color := Vector4(0.045, 0.13, 0.09, 1);
  C2.Translation := Vector3(X, 6.9, Z);
  MainViewport.Items.Add(C2);

  Snow := TCastleCone.Create(FreeAtStop);
  Snow.BottomRadius := 0.92;
  Snow.Height := 2.4;
  Snow.Slices := 18;
  Snow.Color := Vector4(0.82, 0.86, 0.89, 1);
  Snow.Translation := Vector3(X, 8.05, Z);
  MainViewport.Items.Add(Snow);
end;

procedure TViewDrive.AddLamp(const X, Z: Single);
var
  Pole: TCastleCylinder;
  Light: TCastlePointLight;
begin
  Pole := TCastleCylinder.Create(FreeAtStop);
  Pole.Radius := 0.075;
  Pole.Height := 8.1;
  Pole.Slices := 12;
  Pole.Color := Vector4(0.13, 0.14, 0.16, 1);
  Pole.Translation := Vector3(X, 4.05, Z);
  MainViewport.Items.Add(Pole);

  AddBox(X, 7.95, Z, 0.62, 0.20, 0.40,
    Vector4(0.94, 0.74, 0.42, 1));

  Light := TCastlePointLight.Create(FreeAtStop);
  Light.Translation := Vector3(X, 7.70, Z);
  Light.Color := Vector3(1.0, 0.70, 0.38);
  Light.Intensity := 7.5;
  Light.Radius := 22;
  MainViewport.Items.Add(Light);
end;

procedure TViewDrive.AddParkedCar(const X, Z: Single; const C: TVector4);
var
  DarkC: TVector4;
begin
  DarkC := Vector4(0.035, 0.045, 0.055, 1);
  AddBox(X, 0.53, Z, 1.82, 0.68, 4.30, C);
  AddBox(X, 1.00, Z - 0.10, 1.55, 0.50, 2.20, DarkC);
  AddBox(X, 1.28, Z - 0.10, 1.42, 0.11, 1.70, C);
  AddBox(X - 0.93, 0.32, Z - 1.34, 0.17, 0.44, 0.62, DarkC);
  AddBox(X + 0.93, 0.32, Z - 1.34, 0.17, 0.44, 0.62, DarkC);
  AddBox(X - 0.93, 0.32, Z + 1.34, 0.17, 0.44, 0.62, DarkC);
  AddBox(X + 0.93, 0.32, Z + 1.34, 0.17, 0.44, 0.62, DarkC);
end;

procedure TViewDrive.BuildWorld;
var
  Ground: TCastlePlane;
  I: Integer;
begin
  Ground := TCastlePlane.Create(FreeAtStop);
  Ground.Size := Vector2(1200, 1200);
  Ground.Color := Vector4(0.90, 0.92, 0.94, 1);
  Ground.Texture := 'castle-data:/visual/snow_winter.png';
  Ground.TextureNormalMap := 'castle-data:/visual/snow_normal.png';
  Ground.TextureScale := Vector2(44, 44);
  MainViewport.Items.Add(Ground);

  Sun := TCastleDirectionalLight.Create(FreeAtStop);
  Sun.Color := Vector3(0.82, 0.86, 0.95);
  Sun.Direction := Vector3(0.25, -0.88, 0.34);
  Sun.Intensity := 1.05;
  MainViewport.Items.Add(Sun);

  Fog := TCastleFog.Create(FreeAtStop);
  Fog.VisibilityRange := 330;
  MainViewport.Fog := Fog;

  AddBox(0, 0.035, 0, 24.0, 0.07, 980,
    Vector4(0.95, 0.95, 0.95, 1),
    'castle-data:/visual/road_winter.png',
    'castle-data:/visual/road_normal.png', 46);

  AddBox(-16.0, 0.08, 0, 7.0, 0.14, 980, Vector4(0.66, 0.68, 0.70, 1));
  AddBox(16.0, 0.08, 0, 7.0, 0.14, 980, Vector4(0.66, 0.68, 0.70, 1));
  AddBox(-12.0, 0.22, 0, 1.6, 0.44, 980, Vector4(0.84, 0.87, 0.89, 1),
    'castle-data:/visual/snow_winter.png', 'castle-data:/visual/snow_normal.png', 32);
  AddBox(12.0, 0.22, 0, 1.6, 0.44, 980, Vector4(0.84, 0.87, 0.89, 1),
    'castle-data:/visual/snow_winter.png', 'castle-data:/visual/snow_normal.png', 32);

  for I := -32 to 32 do
    AddBox(0, 0.083, I * 15, 0.17, 0.025, 7.0, Vector4(0.86, 0.82, 0.61, 1));
  AddBox(-9.5, 0.083, 0, 0.13, 0.025, 980, Vector4(0.72, 0.74, 0.74, 1));
  AddBox(9.5, 0.083, 0, 0.13, 0.025, 980, Vector4(0.72, 0.74, 0.74, 1));

  AddBox(0, 0.04, 150, 132, 0.08, 17, Vector4(0.24, 0.25, 0.26, 1),
    'castle-data:/visual/road_winter.png', 'castle-data:/visual/road_normal.png', 8);
  AddBox(0, 0.04, -76, 132, 0.08, 16, Vector4(0.24, 0.25, 0.26, 1),
    'castle-data:/visual/road_winter.png', 'castle-data:/visual/road_normal.png', 8);
  AddBox(0, 0.04, -286, 132, 0.08, 17, Vector4(0.24, 0.25, 0.26, 1),
    'castle-data:/visual/road_winter.png', 'castle-data:/visual/road_normal.png', 8);

  for I := -5 to 5 do
    AddBox(I * 1.75, 0.092, 88, 0.86, 0.026, 5.8, Vector4(0.84, 0.85, 0.83, 1));

  AddBuilding(-39, 220, 27, 37, 18.5, 0);
  AddBuilding(39, 214, 27, 34, 24.5, 1);
  AddBuilding(-43, 125, 34, 42, 27.5, 2);
  AddBuilding(42, 114, 31, 39, 18.5, 0);
  AddBuilding(-40, 30, 29, 36, 21.5, 1);
  AddBuilding(43, 20, 34, 43, 27.5, 2);
  AddBuilding(-42, -80, 33, 41, 24.5, 0);
  AddBuilding(41, -94, 30, 36, 18.5, 1);
  AddBuilding(-41, -190, 31, 40, 27.5, 2);
  AddBuilding(43, -205, 34, 42, 24.5, 0);
  AddBuilding(-40, -315, 29, 38, 18.5, 1);
  AddBuilding(42, -326, 32, 40, 27.5, 2);

  for I := -7 to 7 do
  begin
    AddLamp(-11.0, I * 56 + 5);
    AddLamp(11.0, I * 56 - 23);
    AddTree(-21.5, I * 58 + 19);
    AddTree(21.5, I * 58 - 9);
  end;

  AddParkedCar(-8.1, 177, Vector4(0.12, 0.18, 0.25, 1));
  AddParkedCar(8.1, 126, Vector4(0.37, 0.06, 0.05, 1));
  AddParkedCar(-8.2, 44, Vector4(0.55, 0.57, 0.58, 1));
  AddParkedCar(8.0, -18, Vector4(0.06, 0.10, 0.16, 1));
  AddParkedCar(-8.0, -132, Vector4(0.25, 0.27, 0.29, 1));
  AddParkedCar(8.1, -236, Vector4(0.30, 0.07, 0.06, 1));
  AddParkedCar(-8.0, -344, Vector4(0.13, 0.15, 0.17, 1));

  ApplyLighting;
end;

procedure TViewDrive.ApplyLighting;
begin
  if NightMode then
  begin
    MainViewport.BackgroundColor := Vector4(0.025, 0.040, 0.070, 1);
    Sun.Intensity := 0.22;
    Fog.Color := Vector3(0.055, 0.075, 0.115);
    Fog.VisibilityRange := 230;
    HudStatus.Caption := 'UKHTA DRIVE 0.4 3D PBR  |  NIGHT  |  mouse = steering  |  RMB gas  LMB brake';
    if Cockpit3D <> nil then Cockpit3D.SetNightMode(True);
  end else
  begin
    MainViewport.BackgroundColor := Vector4(0.28, 0.36, 0.46, 1);
    Sun.Intensity := 1.05;
    Fog.Color := Vector3(0.48, 0.55, 0.62);
    Fog.VisibilityRange := 330;
    HudStatus.Caption := 'UKHTA DRIVE 0.4 3D PBR  |  mouse = steering  |  RMB gas  LMB brake  |  N night';
    if Cockpit3D <> nil then Cockpit3D.SetNightMode(False);
  end;
end;

procedure TViewDrive.Start;
begin
  inherited;

  MainViewport := TCastleViewport.Create(FreeAtStop);
  MainViewport.FullSize := True;
  MainViewport.Camera.ProjectionNear := 0.035;
  MainViewport.Camera.ProjectionFar := 1400;
  MainViewport.Camera.Perspective.FieldOfView := DegToRad(66);
  MainViewport.ScreenSpaceAmbientOcclusion := True;
  MainViewport.ScreenSpaceReflections := True;
  MainViewport.ScreenSpaceReflectionsSurfaceGlossiness := 0.58;
  InsertBack(MainViewport);

  Vehicle := TVehicleState.Create;

  HudStatus := TCastleLabel.Create(FreeAtStop);
  HudStatus.FontSize := 15;
  HudStatus.Color := Vector4(0.90, 0.94, 0.98, 1);
  HudStatus.Left := 20;
  HudStatus.Bottom := 858;

  HudSpeed := TCastleLabel.Create(FreeAtStop);
  HudSpeed.FontSize := 18;
  HudSpeed.Color := Vector4(0.72, 0.88, 1.0, 1);
  HudSpeed.Left := 20;
  HudSpeed.Bottom := 820;

  BuildWorld;
  Sun.Shadows := True;

  Cockpit3D := TCockpit3D.Create(FreeAtStop, MainViewport);

  InsertFront(HudSpeed);
  InsertFront(HudStatus);

  Container.MousePosition := Vector2(Container.PixelsWidth * 0.5,
    Container.PixelsHeight * 0.5);
  UpdateCameraAndCockpit;
end;

procedure TViewDrive.Stop;
begin
  FreeAndNil(Cockpit3D);
  FreeAndNil(Vehicle);
  inherited;
end;

procedure TViewDrive.UpdateCameraAndCockpit;
var
  Dir: TVector3;
begin
  Dir := Vector3(Sin(Vehicle.Yaw), -0.028, -Cos(Vehicle.Yaw));

  MainViewport.Camera.SetWorldView(
    Vector3(Vehicle.X, 1.62, Vehicle.Z),
    Dir,
    Vector3(0, 1, 0));

  if Cockpit3D <> nil then
    Cockpit3D.UpdatePose(Vehicle.X, Vehicle.Z, Vehicle.Yaw,
      Vehicle.Steering, Vehicle.Speed);
end;

procedure TViewDrive.Update(const SecondsPassed: Single; var HandleInput: Boolean);
var
  Input: TDriveInput;
  CenterX, MouseSteer: Single;
begin
  inherited;

  if Container.PixelsWidth > 10 then
  begin
    CenterX := Container.PixelsWidth * 0.5;
    MouseSteer := (CenterX - Container.MousePosition.X) / (CenterX * 0.80);
    Input.Steering := ClampS(MouseSteer, -1.0, 1.0);
  end else
    Input.Steering := 0;

  if Container.Pressed[keyA] or Container.Pressed[keyArrowLeft] then
    Input.Steering := 1.0
  else if Container.Pressed[keyD] or Container.Pressed[keyArrowRight] then
    Input.Steering := -1.0;

  Input.Gas :=
    (buttonRight in Container.MousePressed) or
    Container.Pressed[keyW] or Container.Pressed[keyArrowUp];

  Input.Brake :=
    (buttonLeft in Container.MousePressed) or
    Container.Pressed[keyS] or Container.Pressed[keyArrowDown];

  Input.HandBrake := Container.Pressed[keySpace];

  Vehicle.Update(SecondsPassed, Input);
  UpdateCameraAndCockpit;

  if Vehicle.Speed < -0.4 then
    HudSpeed.Caption := Format('R   %3d km/h', [Round(Abs(Vehicle.Speed) * 3.6)])
  else
    HudSpeed.Caption := Format('D   %3d km/h', [Round(Abs(Vehicle.Speed) * 3.6)]);
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

  if Event.IsKey(keyF11) then
  begin
    Application.MainWindow.FullScreen := not Application.MainWindow.FullScreen;
    Exit(True);
  end;
end;

end.
