unit GameCockpit3D;

interface

uses
  Classes,
  CastleVectors, CastleViewport, CastleScene, CastleTransform;

type
  TCockpit3D = class
  private
    FOwner: TComponent;
    FViewport: TCastleViewport;
    FRoot: TCastleTransform;
    FStaticScene: TCastleScene;
    FWheelPivot: TCastleTransform;
    FWheelScene: TCastleScene;
    FSpeedNeedle: TCastleTransform;
    FInteriorLight: TCastlePointLight;
  public
    constructor Create(const AOwner: TComponent; const AViewport: TCastleViewport);
    procedure UpdatePose(const CarX, CarZ, CarYaw, Steering, Speed: Single);
    procedure SetNightMode(const Night: Boolean);
  end;

implementation

uses
  Math, CastleColors, CastleRenderOptions;

constructor TCockpit3D.Create(const AOwner: TComponent;
  const AViewport: TCastleViewport);
var
  Needle: TCastleBox;
begin
  inherited Create;
  FOwner := AOwner;
  FViewport := AViewport;

  FRoot := TCastleTransform.Create(FOwner);
  FViewport.Items.Add(FRoot);

  FStaticScene := TCastleScene.Create(FOwner);
  FStaticScene.Load('castle-data:/cockpit/cockpit_static.glb');
  FStaticScene.Collides := False;
  FRoot.Add(FStaticScene);

  FWheelPivot := TCastleTransform.Create(FOwner);
  FWheelPivot.Translation := Vector3(-0.06, 1.235, -0.57);
  FRoot.Add(FWheelPivot);

  FWheelScene := TCastleScene.Create(FOwner);
  FWheelScene.Load('castle-data:/cockpit/steering.glb');
  FWheelScene.Collides := False;
  FWheelPivot.Add(FWheelScene);

  FSpeedNeedle := TCastleTransform.Create(FOwner);
  FSpeedNeedle.Translation := Vector3(-0.245, 1.305, -1.258);
  FRoot.Add(FSpeedNeedle);

  Needle := TCastleBox.Create(FOwner);
  Needle.Size := Vector3(0.105, 0.009, 0.006);
  Needle.Color := Vector4(0.95, 0.035, 0.020, 1);
  Needle.Material := pmUnlit;
  Needle.Translation := Vector3(0.048, 0, 0);
  FSpeedNeedle.Add(Needle);

  FInteriorLight := TCastlePointLight.Create(FOwner);
  FInteriorLight.Translation := Vector3(0.18, 1.72, -0.18);
  FInteriorLight.Color := Vector3(1.0, 0.58, 0.30);
  FInteriorLight.Intensity := 0.18;
  FInteriorLight.Radius := 3.2;
  FRoot.Add(FInteriorLight);
end;

procedure TCockpit3D.UpdatePose(const CarX, CarZ, CarYaw, Steering, Speed: Single);
var
  Kmh, Angle: Single;
begin
  FRoot.Translation := Vector3(CarX, 0, CarZ);
  FRoot.Rotation := Vector4(0, 1, 0, -CarYaw);

  FWheelPivot.Rotation := Vector4(0, 0, 1, Steering * 4.8);

  Kmh := Abs(Speed) * 3.6;
  if Kmh > 220 then Kmh := 220;
  Angle := DegToRad(215 - (Kmh / 220) * 250);
  FSpeedNeedle.Rotation := Vector4(0, 0, 1, Angle);
end;

procedure TCockpit3D.SetNightMode(const Night: Boolean);
begin
  if Night then
    FInteriorLight.Intensity := 0.85
  else
    FInteriorLight.Intensity := 0.18;
end;

end.
