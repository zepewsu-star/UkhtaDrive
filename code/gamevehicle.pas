unit GameVehicle;

interface

type
  TDriveInput = record
    Gas: Boolean;
    Brake: Boolean;
    Left: Boolean;
    Right: Boolean;
    HandBrake: Boolean;
  end;

  TVehicleState = class
  private
    FX: Single;
    FZ: Single;
    FYaw: Single;
    FSpeed: Single;
    FSteering: Single;
    FOdometer: Double;
    function ClampS(const V, AMin, AMax: Single): Single;
  public
    constructor Create;
    procedure Reset;
    procedure Update(const SecondsPassed: Single; const Input: TDriveInput);
    procedure RestorePosition(const AX, AZ: Single);
    procedure StopAfterCollision;

    property X: Single read FX;
    property Z: Single read FZ;
    property Yaw: Single read FYaw;
    property Speed: Single read FSpeed;
    property Steering: Single read FSteering;
    property Odometer: Double read FOdometer;
  end;

implementation

uses Math;

constructor TVehicleState.Create;
begin
  inherited Create;
  Reset;
end;

function TVehicleState.ClampS(const V, AMin, AMax: Single): Single;
begin
  if V < AMin then Result := AMin
  else if V > AMax then Result := AMax
  else Result := V;
end;

procedure TVehicleState.Reset;
begin
  { Spawn in the middle of the main avenue, looking toward the city center. }
  FX := 0.0;
  FZ := 240.0;
  FYaw := 0.0;
  FSpeed := 0.0;
  FSteering := 0.0;
  FOdometer := 0.0;
end;

procedure TVehicleState.RestorePosition(const AX, AZ: Single);
begin
  FX := AX;
  FZ := AZ;
end;

procedure TVehicleState.StopAfterCollision;
begin
  FSpeed := -FSpeed * 0.10;
end;

procedure TVehicleState.Update(const SecondsPassed: Single; const Input: TDriveInput);
const
  WheelBase = 2.91;
  MaxSteer = 0.50;
  MaxForward = 55.0;
  MaxReverse = 8.0;
var
  Accel, BrakeForce, Rolling, Aero, TargetSteer, SteerSpeed: Single;
  OldSpeed, Travel: Single;
begin
  if SecondsPassed <= 0 then Exit;
  OldSpeed := FSpeed;

  if Input.Gas then
  begin
    if FSpeed >= 0 then
      Accel := 5.8 * (1.0 - ClampS(FSpeed / MaxForward, 0.0, 0.92))
    else
      Accel := 7.0;
    FSpeed := FSpeed + Accel * SecondsPassed;
  end;

  if Input.Brake then
  begin
    if FSpeed > 0.35 then
    begin
      BrakeForce := 10.5;
      FSpeed := FSpeed - BrakeForce * SecondsPassed;
    end else
      FSpeed := FSpeed - 3.2 * SecondsPassed;
  end;

  if not Input.Gas then
  begin
    Rolling := 0.18;
    if FSpeed > 0 then FSpeed := Max(0.0, FSpeed - Rolling * SecondsPassed)
    else if FSpeed < 0 then FSpeed := Min(0.0, FSpeed + Rolling * SecondsPassed);
  end;

  Aero := 0.0026 * FSpeed * Abs(FSpeed);
  FSpeed := FSpeed - Aero * SecondsPassed;
  if Input.HandBrake then FSpeed := FSpeed * Power(0.22, SecondsPassed);
  FSpeed := ClampS(FSpeed, -MaxReverse, MaxForward);

  TargetSteer := 0.0;
  if Input.Left then TargetSteer := TargetSteer + MaxSteer;
  if Input.Right then TargetSteer := TargetSteer - MaxSteer;
  SteerSpeed := 4.8 / (1.0 + Abs(FSpeed) * 0.035);
  FSteering := FSteering + (TargetSteer - FSteering) *
    ClampS(SteerSpeed * SecondsPassed, 0.0, 1.0);

  if Abs(FSpeed) > 0.05 then
    FYaw := FYaw + (FSpeed / WheelBase) * Tan(FSteering) * SecondsPassed;

  FX := FX + Sin(FYaw) * FSpeed * SecondsPassed;
  FZ := FZ - Cos(FYaw) * FSpeed * SecondsPassed;

  Travel := Abs((OldSpeed + FSpeed) * 0.5 * SecondsPassed);
  FOdometer := FOdometer + Travel / 1000.0;
end;

end.
