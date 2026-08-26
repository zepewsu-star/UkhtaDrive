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
    procedure AddBox(const X, Y, Z, W, H, D: Single; const C: TVector4);
    procedure AddBuilding(const X, Z, W, D, H: Single;
      const C: TVector4; const Floors, Bays, Seed: Integer);
    procedure AddTree(const X, Z: Single);
    procedure AddLamp(const X, Z: Single);
    procedure AddParkedCar(const X, Z: Single; const C: TVector4);
    procedure BuildWorld;
    procedure ApplyLighting;
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

procedure TViewDrive.AddBuilding(const X, Z, W, D, H: Single;
  const C: TVector4; const Floors, Bays, Seed: Integer);
var
  F, B: Integer;
  RoadFaceX, WY, WZ, StepZ: Single;
  WC: TVector4;
begin
  AddBox(X, H * 0.5, Z, W, H, D, C);
  AddBox(X, H + 0.20, Z, W + 0.35, 0.38, D + 0.35,
    Vector4(0.82, 0.85, 0.87, 1));

  if X < 0 then
    RoadFaceX := X + W * 0.5 + 0.08
  else
    RoadFaceX := X - W * 0.5 - 0.08;

  if Bays > 1 then
    StepZ := (D - 4.2) / (Bays - 1)
  else
    StepZ := 0;

  for F := 0 to Floors - 1 do
  begin
    WY := 2.35 + F * 3.05;
    if WY > H - 1.0 then Break;

    AddBox(RoadFaceX, WY - 1.25, Z, 0.10, 0.09, D - 0.5,
      Vector4(0.40, 0.43, 0.46, 1));

    for B := 0 to Bays - 1 do
    begin
      WZ := Z - D * 0.5 + 2.1 + B * StepZ;
      if ((F * Bays + B + Seed) mod 5 = 0) or
         ((F * Bays + B + Seed) mod 7 = 0) then
        WC := Vector4(0.96, 0.72, 0.38, 1)
      else
        WC := Vector4(0.12, 0.17, 0.23, 1);
      AddBox(RoadFaceX, WY, WZ, 0.13, 1.35, 1.65, WC);
    end;
  end;

  AddBox(RoadFaceX, 1.15, Z + D * 0.25, 0.18, 2.25, 2.15,
    Vector4(0.08, 0.10, 0.13, 1));
  if X < 0 then
    AddBox(RoadFaceX + 0.65, 2.35, Z + D * 0.25, 1.35, 0.18, 2.75,
      Vector4(0.30, 0.32, 0.34, 1))
  else
    AddBox(RoadFaceX - 0.65, 2.35, Z + D * 0.25, 1.35, 0.18, 2.75,
      Vector4(0.30, 0.32, 0.34, 1));
end;

procedure TViewDrive.AddTree(const X, Z: Single);
var
  Trunk: TCastleCylinder;
  Crown1, Crown2, SnowTop: TCastleCone;
begin
  Trunk := TCastleCylinder.Create(FreeAtStop);
  Trunk.Radius := 0.22;
  Trunk.Height := 4.2;
  Trunk.Slices := 10;
  Trunk.Color := Vector4(0.20, 0.13, 0.08, 1);
  Trunk.Translation := Vector3(X, 2.1, Z);
  MainViewport.Items.Add(Trunk);

  Crown1 := TCastleCone.Create(FreeAtStop);
  Crown1.BottomRadius := 2.3;
  Crown1.Height := 5.8;
  Crown1.Slices := 14;
  Crown1.Color := Vector4(0.07, 0.18, 0.14, 1);
  Crown1.Translation := Vector3(X, 4.8, Z);
  MainViewport.Items.Add(Crown1);

  Crown2 := TCastleCone.Create(FreeAtStop);
  Crown2.BottomRadius := 1.75;
  Crown2.Height := 4.7;
  Crown2.Slices := 14;
  Crown2.Color := Vector4(0.06, 0.15, 0.12, 1);
  Crown2.Translation := Vector3(X, 7.1, Z);
  MainViewport.Items.Add(Crown2);

  SnowTop := TCastleCone.Create(FreeAtStop);
  SnowTop.BottomRadius := 0.95;
  SnowTop.Height := 2.7;
  SnowTop.Slices := 14;
  SnowTop.Color := Vector4(0.79, 0.84, 0.87, 1);
  SnowTop.Translation := Vector3(X, 8.35, Z);
  MainViewport.Items.Add(SnowTop);
end;

procedure TViewDrive.AddLamp(const X, Z: Single);
var
  Pole: TCastleCylinder;
  Light: TCastlePointLight;
begin
  Pole := TCastleCylinder.Create(FreeAtStop);
  Pole.Radius := 0.09;
  Pole.Height := 8.0;
  Pole.Slices := 10;
  Pole.Color := Vector4(0.15, 0.17, 0.19, 1);
  Pole.Translation := Vector3(X, 4.0, Z);
  MainViewport.Items.Add(Pole);

  AddBox(X, 7.85, Z, 0.55, 0.22, 0.42,
    Vector4(0.95, 0.73, 0.38, 1));

  Light := TCastlePointLight.Create(FreeAtStop);
  Light.Translation := Vector3(X, 7.65, Z);
  Light.Color := Vector3(1.0, 0.72, 0.42);
  Light.Intensity := 8.0;
  MainViewport.Items.Add(Light);
end;

procedure TViewDrive.AddParkedCar(const X, Z: Single; const C: TVector4);
var
  DarkC: TVector4;
begin
  DarkC := Vector4(0.06, 0.08, 0.10, 1);
  AddBox(X, 0.55, Z, 1.82, 0.68, 4.35, C);
  AddBox(X, 1.03, Z - 0.15, 1.60, 0.52, 2.25, DarkC);
  AddBox(X, 1.31, Z - 0.10, 1.42, 0.12, 1.75, C);
  AddBox(X - 0.92, 0.32, Z - 1.35, 0.16, 0.42, 0.62, DarkC);
  AddBox(X + 0.92, 0.32, Z - 1.35, 0.16, 0.42, 0.62, DarkC);
  AddBox(X - 0.92, 0.32, Z + 1.35, 0.16, 0.42, 0.62, DarkC);
  AddBox(X + 0.92, 0.32, Z + 1.35, 0.16, 0.42, 0.62, DarkC);
end;

procedure TViewDrive.BuildWorld;
var
  Ground: TCastlePlane;
  I: Integer;
begin
  Ground := TCastlePlane.Create(FreeAtStop);
  Ground.Size := Vector2(1100, 1100);
  Ground.Color := Vector4(0.72, 0.78, 0.82, 1.0);
  MainViewport.Items.Add(Ground);

  Sun := TCastleDirectionalLight.Create(FreeAtStop);
  Sun.Color := Vector3(0.77, 0.82, 0.92);
  Sun.Direction := Vector3(0.28, -0.86, 0.35);
  MainViewport.Items.Add(Sun);

  Fog := TCastleFog.Create(FreeAtStop);
  Fog.VisibilityRange := 310;
  MainViewport.Fog := Fog;

  AddBox(0, 0.035, 0, 24, 0.07, 940,
    Vector4(0.115, 0.125, 0.135, 1));
  AddBox(-16.5, 0.08, 0, 8.0, 0.14, 940,
    Vector4(0.63, 0.67, 0.70, 1));
  AddBox(16.5, 0.08, 0, 8.0, 0.14, 940,
    Vector4(0.63, 0.67, 0.70, 1));
  AddBox(-12.0, 0.20, 0, 1.5, 0.40, 940,
    Vector4(0.80, 0.84, 0.87, 1));
  AddBox(12.0, 0.20, 0, 1.5, 0.40, 940,
    Vector4(0.80, 0.84, 0.87, 1));

  for I := -30 to 30 do
    AddBox(0, 0.082, I * 15, 0.18, 0.025, 7.0,
      Vector4(0.86, 0.84, 0.69, 1));
  AddBox(-9.6, 0.082, 0, 0.13, 0.025, 940,
    Vector4(0.75, 0.77, 0.76, 1));
  AddBox(9.6, 0.082, 0, 0.13, 0.025, 940,
    Vector4(0.75, 0.77, 0.76, 1));

  AddBox(0, 0.04, 145, 130, 0.08, 16,
    Vector4(0.13, 0.14, 0.15, 1));
  AddBox(0, 0.04, -80, 130, 0.08, 15,
    Vector4(0.13, 0.14, 0.15, 1));
  AddBox(0, 0.04, -285, 130, 0.08, 16,
    Vector4(0.13, 0.14, 0.15, 1));

  for I := -5 to 5 do
    AddBox(I * 1.75, 0.09, 85, 0.85, 0.026, 6.0,
      Vector4(0.82, 0.83, 0.81, 1));

  AddBuilding(-39, 220, 27, 37, 18.5,
    Vector4(0.44, 0.46, 0.49, 1), 6, 7, 1);
  AddBuilding(39, 215, 27, 34, 24.5,
    Vector4(0.49, 0.43, 0.38, 1), 8, 7, 3);
  AddBuilding(-43, 125, 34, 42, 27.5,
    Vector4(0.42, 0.47, 0.50, 1), 9, 8, 5);
  AddBuilding(42, 115, 31, 39, 18.5,
    Vector4(0.51, 0.48, 0.43, 1), 6, 8, 2);
  AddBuilding(-40, 30, 29, 36, 21.5,
    Vector4(0.50, 0.45, 0.41, 1), 7, 7, 9);
  AddBuilding(43, 22, 34, 43, 27.5,
    Vector4(0.40, 0.44, 0.49, 1), 9, 9, 4);
  AddBuilding(-42, -78, 33, 41, 24.5,
    Vector4(0.47, 0.49, 0.50, 1), 8, 8, 12);
  AddBuilding(41, -92, 30, 36, 18.5,
    Vector4(0.53, 0.47, 0.41, 1), 6, 7, 6);
  AddBuilding(-41, -190, 31, 40, 27.5,
    Vector4(0.42, 0.45, 0.48, 1), 9, 8, 15);
  AddBuilding(43, -205, 34, 42, 24.5,
    Vector4(0.49, 0.44, 0.39, 1), 8, 9, 11);
  AddBuilding(-40, -315, 29, 38, 18.5,
    Vector4(0.46, 0.48, 0.50, 1), 6, 8, 20);
  AddBuilding(42, -325, 32, 40, 27.5,
    Vector4(0.41, 0.45, 0.49, 1), 9, 8, 17);

  for I := -7 to 7 do
  begin
    AddLamp(-11.0, I * 55 + 5);
    AddLamp(11.0, I * 55 - 22);
  end;

  for I := -7 to 7 do
  begin
    AddTree(-21.5, I * 57 + 18);
    AddTree(21.5, I * 57 - 8);
  end;

  AddParkedCar(-8.0, 177, Vector4(0.18, 0.23, 0.29, 1));
  AddParkedCar(8.1, 126, Vector4(0.42, 0.09, 0.07, 1));
  AddParkedCar(-8.2, 44, Vector4(0.58, 0.60, 0.61, 1));
  AddParkedCar(8.0, -18, Vector4(0.08, 0.12, 0.18, 1));
  AddParkedCar(-8.0, -132, Vector4(0.28, 0.30, 0.32, 1));
  AddParkedCar(8.1, -235, Vector4(0.33, 0.10, 0.09, 1));
  AddParkedCar(-8.0, -344, Vector4(0.16, 0.18, 0.20, 1));

  ApplyLighting;
end;

procedure TViewDrive.ApplyLighting;
begin
  if NightMode then
  begin
    MainViewport.BackgroundColor := Vector4(0.035, 0.055, 0.085, 1.0);
    Sun.Intensity := 0.28;
    Fog.Color := Vector3(0.08, 0.11, 0.16);
    Fog.VisibilityRange := 235;
    HudStatus.Caption := 'NIGHT  |  N = dusk';
  end else
  begin
    MainViewport.BackgroundColor := Vector4(0.30, 0.37, 0.46, 1.0);
    Sun.Intensity := 1.18;
    Fog.Color := Vector3(0.48, 0.54, 0.61);
    Fog.VisibilityRange := 310;
    HudStatus.Caption := 'UKHTA DRIVE 0.2  |  WINTER DUSK  |  N = night';
  end;
end;

procedure TViewDrive.Start;
begin
  inherited;

  MainViewport := TCastleViewport.Create(FreeAtStop);
  MainViewport.FullSize := True;
  InsertBack(MainViewport);

  Vehicle := TVehicleState.Create;

  HudStatus := TCastleLabel.Create(FreeAtStop);
  HudStatus.FontSize := 15;
  HudStatus.Color := Vector4(0.92, 0.94, 0.96, 1);
  HudStatus.Left := 1190;
  HudStatus.Bottom := 855;

  BuildWorld;
  UpdateCameraAndCockpit;

  Cockpit := TCastleImageControl.Create(FreeAtStop);
  Cockpit.Url := 'castle-data:/visual/cockpit_base.png';
  Cockpit.Stretch := True;
  Cockpit.Width := 1600;
  Cockpit.Height := 900;
  Cockpit.Left := 0;
  Cockpit.Bottom := 0;
  InsertFront(Cockpit);

  SteeringWheel := TCastleImageControl.Create(FreeAtStop);
  SteeringWheel.Url := 'castle-data:/visual/steering.png';
  SteeringWheel.Stretch := True;
  SteeringWheel.Width := 440;
  SteeringWheel.Height := 440;
  SteeringWheel.Left := 330;
  SteeringWheel.Bottom := -12;
  SteeringWheel.RotationCenter := Vector2(0.5, 0.5);
  InsertFront(SteeringWheel);

  HudSpeed := TCastleLabel.Create(FreeAtStop);
  HudSpeed.FontSize := 20;
  HudSpeed.Color := Vector4(0.90, 0.96, 1.0, 1);
  HudSpeed.Left := 523;
  HudSpeed.Bottom := 259;
  InsertFront(HudSpeed);

  InsertFront(HudStatus);
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
  Dir := Vector3(Sin(Vehicle.Yaw), -0.030, -Cos(Vehicle.Yaw));
  MainViewport.Camera.SetWorldView(
    Vector3(Vehicle.X, 1.62, Vehicle.Z),
    Dir,
    Vector3(0, 1, 0));

  if SteeringWheel <> nil then
    SteeringWheel.Rotation := -Vehicle.Steering * 2.15;
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

  if Vehicle.Speed < -0.4 then
    HudSpeed.Caption := Format('R  %3d', [Round(Abs(Vehicle.Speed) * 3.6)])
  else
    HudSpeed.Caption := Format('D  %3d', [Round(Abs(Vehicle.Speed) * 3.6)]);
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
    ApplyLighting;
    Exit(True);
  end;
end;

end.
