unit GameCockpit3D;

interface

uses
  Classes, Math,
  CastleVectors, CastleViewport, CastleScene, CastleTransform;

type
  TCockpit3D = class
  private
    FOwner: TComponent;
    FViewport: TCastleViewport;
    FRoot: TCastleTransform;
    FWheelTilt: TCastleTransform;
    FWheelTurn: TCastleTransform;
    FSpeedNeedle: TCastleTransform;
    FTachNeedle: TCastleTransform;
    FInteriorLight: TCastlePointLight;

    function AddBoxTo(const Parent: TCastleTransform;
      const X, Y, Z, W, H, D: Single; const C: TVector4;
      const TextureUrl: String = ''; const NormalUrl: String = '';
      const RotAxisX: Single = 0; const RotAxisY: Single = 0;
      const RotAxisZ: Single = 0; const RotAngle: Single = 0;
      const Material: TPrimitiveMaterial = pmPhysical): TCastleBox;

    function AddCylinderTo(const Parent: TCastleTransform;
      const X, Y, Z, Radius, Height: Single; const C: TVector4;
      const RotAxisX: Single = 0; const RotAxisY: Single = 0;
      const RotAxisZ: Single = 0; const RotAngle: Single = 0;
      const Material: TPrimitiveMaterial = pmPhysical): TCastleCylinder;

    procedure AddWheelRing(const Parent: TCastleTransform;
      const Radius, Thickness, Z: Single; const Segments: Integer;
      const C: TVector4; const TextureUrl, NormalUrl: String);

    procedure AddLogoRing(const Parent: TCastleTransform;
      const CX, CY, Radius, Z: Single);

    procedure AddGauge(const X, Y, Z: Single; out NeedleRoot: TCastleTransform);
    procedure Build;
  public
    constructor Create(const AOwner: TComponent; const AViewport: TCastleViewport);
    procedure UpdatePose(const CarX, CarZ, CarYaw, Steering, Speed: Single);
    procedure SetNightMode(const Night: Boolean);
  end;

implementation

uses
  CastleColors;

function TCockpit3D.AddBoxTo(const Parent: TCastleTransform;
  const X, Y, Z, W, H, D: Single; const C: TVector4;
  const TextureUrl, NormalUrl: String;
  const RotAxisX, RotAxisY, RotAxisZ, RotAngle: Single;
  const Material: TPrimitiveMaterial): TCastleBox;
begin
  Result := TCastleBox.Create(FOwner);
  Result.Size := Vector3(W, H, D);
  Result.Translation := Vector3(X, Y, Z);
  Result.Color := C;
  Result.Material := Material;
  if TextureUrl <> '' then
  begin
    Result.Texture := TextureUrl;
    Result.TextureScale := Vector2(2.0, 2.0);
  end;
  if NormalUrl <> '' then
    Result.TextureNormalMap := NormalUrl;
  if RotAngle <> 0 then
    Result.Rotation := Vector4(RotAxisX, RotAxisY, RotAxisZ, RotAngle);
  Parent.Add(Result);
end;

function TCockpit3D.AddCylinderTo(const Parent: TCastleTransform;
  const X, Y, Z, Radius, Height: Single; const C: TVector4;
  const RotAxisX, RotAxisY, RotAxisZ, RotAngle: Single;
  const Material: TPrimitiveMaterial): TCastleCylinder;
begin
  Result := TCastleCylinder.Create(FOwner);
  Result.Radius := Radius;
  Result.Height := Height;
  Result.Slices := 28;
  Result.Translation := Vector3(X, Y, Z);
  Result.Color := C;
  Result.Material := Material;
  if RotAngle <> 0 then
    Result.Rotation := Vector4(RotAxisX, RotAxisY, RotAxisZ, RotAngle);
  Parent.Add(Result);
end;

procedure TCockpit3D.AddWheelRing(const Parent: TCastleTransform;
  const Radius, Thickness, Z: Single; const Segments: Integer;
  const C: TVector4; const TextureUrl, NormalUrl: String);
var
  I: Integer;
  A1, A2, MX, MY, DX, DY, Len, Theta: Single;
  Segment: TCastleCylinder;
begin
  for I := 0 to Segments - 1 do
  begin
    A1 := 2 * Pi * I / Segments;
    A2 := 2 * Pi * (I + 1) / Segments;
    MX := Radius * (Cos(A1) + Cos(A2)) * 0.5;
    MY := Radius * (Sin(A1) + Sin(A2)) * 0.5;
    DX := Radius * (Cos(A2) - Cos(A1));
    DY := Radius * (Sin(A2) - Sin(A1));
    Len := Sqrt(DX * DX + DY * DY);
    Theta := ArcTan2(DY, DX);

    Segment := AddCylinderTo(Parent, MX, MY, Z, Thickness, Len, C,
      0, 0, 1, Theta - Pi / 2, pmPhysical);
    if TextureUrl <> '' then
    begin
      Segment.Texture := TextureUrl;
      if NormalUrl <> '' then
        Segment.TextureNormalMap := NormalUrl;
    end;
  end;
end;

procedure TCockpit3D.AddLogoRing(const Parent: TCastleTransform;
  const CX, CY, Radius, Z: Single);
var
  I: Integer;
  A1, A2, MX, MY, DX, DY, Len, Theta: Single;
begin
  for I := 0 to 11 do
  begin
    A1 := 2 * Pi * I / 12;
    A2 := 2 * Pi * (I + 1) / 12;
    MX := CX + Radius * (Cos(A1) + Cos(A2)) * 0.5;
    MY := CY + Radius * (Sin(A1) + Sin(A2)) * 0.5;
    DX := Radius * (Cos(A2) - Cos(A1));
    DY := Radius * (Sin(A2) - Sin(A1));
    Len := Sqrt(DX * DX + DY * DY);
    Theta := ArcTan2(DY, DX);
    AddCylinderTo(Parent, MX, MY, Z, 0.0045, Len,
      Vector4(0.78, 0.81, 0.84, 1),
      0, 0, 1, Theta - Pi / 2, pmPhysical);
  end;
end;

procedure TCockpit3D.AddGauge(const X, Y, Z: Single; out NeedleRoot: TCastleTransform);
var
  GaugeRoot: TCastleTransform;
  I: Integer;
  A: Single;
begin
  GaugeRoot := TCastleTransform.Create(FOwner);
  GaugeRoot.Translation := Vector3(X, Y, Z);
  FRoot.Add(GaugeRoot);

  AddCylinderTo(GaugeRoot, 0, 0, 0, 0.165, 0.035,
    Vector4(0.33, 0.35, 0.37, 1), 1, 0, 0, Pi / 2);
  AddCylinderTo(GaugeRoot, 0, 0, 0.022, 0.145, 0.018,
    Vector4(0.018, 0.022, 0.028, 1), 1, 0, 0, Pi / 2, pmUnlit);

  for I := 0 to 11 do
  begin
    A := (220 - I * 20) * Pi / 180;
    AddBoxTo(GaugeRoot,
      Cos(A) * 0.115, Sin(A) * 0.115, 0.042,
      0.010, 0.026, 0.008,
      Vector4(0.60, 0.78, 0.93, 1),
      '', '', 0, 0, 1, A - Pi / 2, pmUnlit);
  end;

  NeedleRoot := TCastleTransform.Create(FOwner);
  NeedleRoot.Translation := Vector3(0, 0, 0.055);
  GaugeRoot.Add(NeedleRoot);
  AddBoxTo(NeedleRoot, 0, 0.060, 0, 0.012, 0.118, 0.009,
    Vector4(0.92, 0.18, 0.08, 1), '', '', 0, 0, 0, 0, pmUnlit);
  AddCylinderTo(NeedleRoot, 0, 0, 0.006, 0.022, 0.012,
    Vector4(0.72, 0.74, 0.75, 1), 1, 0, 0, Pi / 2);
end;

procedure TCockpit3D.Build;
var
  Dark, Dark2, Silver, ScreenBlue, Leather: TVector4;
  SoftTex, SoftNorm, LeatherTex, LeatherNorm, AluTex, AluNorm: String;
  I: Integer;
begin
  Dark := Vector4(0.045, 0.050, 0.058, 1);
  Dark2 := Vector4(0.018, 0.022, 0.028, 1);
  Silver := Vector4(0.56, 0.59, 0.62, 1);
  ScreenBlue := Vector4(0.08, 0.34, 0.55, 1);
  Leather := Vector4(0.065, 0.055, 0.050, 1);

  SoftTex := '';
  SoftNorm := '';
  LeatherTex := '';
  LeatherNorm := '';
  AluTex := '';
  AluNorm := '';

  FRoot := TCastleTransform.Create(FOwner);
  FViewport.Items.Add(FRoot);

  AddBoxTo(FRoot, -0.73, 1.215, -1.04, 0.72, 0.24, 0.46, Dark, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.00, 1.205, -1.06, 0.72, 0.23, 0.48, Dark, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.73, 1.205, -1.05, 0.72, 0.23, 0.47, Dark, SoftTex, SoftNorm);
  AddBoxTo(FRoot, -0.39, 1.385, -1.00, 0.70, 0.13, 0.22, Dark2, SoftTex, SoftNorm, 1, 0, 0, -0.08);
  AddBoxTo(FRoot, 0.34, 1.355, -1.01, 0.50, 0.10, 0.20, Dark2, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.00, 1.105, -0.812, 2.03, 0.035, 0.045, Silver, AluTex, AluNorm);

  AddBoxTo(FRoot, 0.36, 1.50, -0.955, 0.47, 0.255, 0.055, Dark2, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.36, 1.50, -0.920, 0.405, 0.195, 0.018, ScreenBlue, '', '', 0, 0, 0, 0, pmUnlit);
  AddBoxTo(FRoot, 0.36, 1.285, -0.895, 0.52, 0.12, 0.09, Dark2, SoftTex, SoftNorm);
  for I := 0 to 5 do
    AddBoxTo(FRoot, 0.17 + I * 0.075, 1.285, -0.842, 0.035, 0.038, 0.012,
      Vector4(0.56, 0.58, 0.60, 1), '', '', 0, 0, 0, 0, pmUnlit);

  for I := 0 to 5 do
  begin
    AddBoxTo(FRoot, -0.74 + I * 0.055, 1.19, -0.810, 0.020, 0.080, 0.014, Dark2);
    AddBoxTo(FRoot, 0.63 + I * 0.055, 1.19, -0.810, 0.020, 0.080, 0.014, Dark2);
  end;

  AddGauge(-0.53, 1.385, -0.865, FSpeedNeedle);
  AddGauge(-0.25, 1.385, -0.865, FTachNeedle);

  FWheelTilt := TCastleTransform.Create(FOwner);
  FWheelTilt.Translation := Vector3(-0.39, 1.205, -0.555);
  FWheelTilt.Rotation := Vector4(1, 0, 0, -0.22);
  FRoot.Add(FWheelTilt);

  FWheelTurn := TCastleTransform.Create(FOwner);
  FWheelTilt.Add(FWheelTurn);
  AddWheelRing(FWheelTurn, 0.235, 0.027, 0.0, 30, Leather, LeatherTex, LeatherNorm);
  AddBoxTo(FWheelTurn, -0.115, -0.010, 0.012, 0.195, 0.040, 0.045, Dark, SoftTex, SoftNorm, 0, 0, 1, 0.18);
  AddBoxTo(FWheelTurn, 0.115, -0.010, 0.012, 0.195, 0.040, 0.045, Dark, SoftTex, SoftNorm, 0, 0, 1, -0.18);
  AddBoxTo(FWheelTurn, 0.000, -0.120, 0.012, 0.050, 0.185, 0.045, Dark, SoftTex, SoftNorm);
  AddCylinderTo(FWheelTurn, 0, -0.015, 0.025, 0.092, 0.060, Dark2, 1, 0, 0, Pi / 2);
  AddCylinderTo(FWheelTurn, 0, -0.015, 0.061, 0.070, 0.020, Vector4(0.09, 0.10, 0.11, 1), 1, 0, 0, Pi / 2);
  AddLogoRing(FWheelTurn, -0.048, -0.015, 0.030, 0.078);
  AddLogoRing(FWheelTurn, -0.016, -0.015, 0.030, 0.079);
  AddLogoRing(FWheelTurn,  0.016, -0.015, 0.030, 0.080);
  AddLogoRing(FWheelTurn,  0.048, -0.015, 0.030, 0.081);

  AddBoxTo(FRoot, 0.18, 0.77, -0.44, 0.46, 0.23, 1.05, Dark, LeatherTex, LeatherNorm, 1, 0, 0, 0.08);
  AddBoxTo(FRoot, 0.18, 0.90, -0.43, 0.39, 0.025, 0.94, Silver, AluTex, AluNorm);
  AddBoxTo(FRoot, 0.18, 0.94, -0.20, 0.18, 0.085, 0.28, Dark2, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.18, 1.045, -0.25, 0.070, 0.22, 0.090, Vector4(0.10, 0.10, 0.11, 1), LeatherTex, LeatherNorm, 1, 0, 0, -0.15);

  AddBoxTo(FRoot, -1.02, 1.02, -0.24, 0.13, 0.62, 1.50, Dark, LeatherTex, LeatherNorm);
  AddBoxTo(FRoot,  1.02, 1.02, -0.24, 0.13, 0.62, 1.50, Dark, LeatherTex, LeatherNorm);
  AddBoxTo(FRoot, -0.94, 1.28, -0.35, 0.16, 0.09, 1.12, Silver, AluTex, AluNorm);
  AddBoxTo(FRoot,  0.94, 1.28, -0.35, 0.16, 0.09, 1.12, Silver, AluTex, AluNorm);

  AddCylinderTo(FRoot, -0.94, 1.63, -0.72, 0.065, 0.92, Vector4(0.16, 0.16, 0.17, 1), 1, 0, 0, -0.26);
  AddCylinderTo(FRoot,  0.94, 1.63, -0.72, 0.065, 0.92, Vector4(0.16, 0.16, 0.17, 1), 1, 0, 0, -0.26);
  AddBoxTo(FRoot, 0.00, 2.02, -0.49, 1.90, 0.12, 0.32, Vector4(0.19, 0.19, 0.20, 1));

  AddBoxTo(FRoot, 0.00, 1.80, -0.56, 0.40, 0.16, 0.075, Dark2, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.00, 1.80, -0.518, 0.34, 0.105, 0.012, Vector4(0.22, 0.29, 0.35, 1), '', '', 0, 0, 0, 0, pmUnlit);
  AddBoxTo(FRoot, -1.13, 1.40, -0.54, 0.25, 0.13, 0.20, Dark2, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 1.13, 1.40, -0.54, 0.25, 0.13, 0.20, Dark2, SoftTex, SoftNorm);
  AddBoxTo(FRoot, 0.00, 0.86, -2.05, 1.86, 0.12, 1.62, Vector4(0.17, 0.18, 0.19, 1), AluTex, AluNorm, 1, 0, 0, -0.025);

  FInteriorLight := TCastlePointLight.Create(FOwner);
  FInteriorLight.Translation := Vector3(0.15, 1.92, -0.05);
  FInteriorLight.Color := Vector3(1.0, 0.78, 0.58);
  FInteriorLight.Intensity := 0.75;
  FInteriorLight.Radius := 3.2;
  FRoot.Add(FInteriorLight);
end;

constructor TCockpit3D.Create(const AOwner: TComponent; const AViewport: TCastleViewport);
begin
  inherited Create;
  FOwner := AOwner;
  FViewport := AViewport;
  Build;
end;

procedure TCockpit3D.UpdatePose(const CarX, CarZ, CarYaw, Steering, Speed: Single);
var
  SpeedNorm, TachNorm: Single;
begin
  FRoot.Translation := Vector3(CarX, 0, CarZ);
  FRoot.Rotation := Vector4(0, 1, 0, -CarYaw);

  if FWheelTurn <> nil then
    FWheelTurn.Rotation := Vector4(0, 0, 1, Steering * 3.25);

  SpeedNorm := Abs(Speed) * 3.6 / 220.0;
  if SpeedNorm > 1 then SpeedNorm := 1;
  if FSpeedNeedle <> nil then
    FSpeedNeedle.Rotation := Vector4(0, 0, 1, (140 - SpeedNorm * 280) * Pi / 180);

  TachNorm := Abs(Speed) / 35.0;
  if TachNorm > 1 then TachNorm := 1;
  if FTachNeedle <> nil then
    FTachNeedle.Rotation := Vector4(0, 0, 1, (140 - TachNorm * 250) * Pi / 180);
end;

procedure TCockpit3D.SetNightMode(const Night: Boolean);
begin
  if FInteriorLight = nil then Exit;
  if Night then
    FInteriorLight.Intensity := 3.8
  else
    FInteriorLight.Intensity := 0.75;
end;

end.
