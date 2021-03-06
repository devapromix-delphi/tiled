﻿unit Mobs;

interface

uses
  Classes,
  Vcl.Graphics,
  Vcl.Imaging.PNGImage;

type
  TMobInfo = record
    Force: Integer;
    X: Integer;
    Y: Integer;
    Id: Integer;
    Level: Integer;
    Exp: Integer;
    Name: string;
    Life: Integer;
    MaxLife: Integer;
    MinDam: Integer;
    MaxDam: Integer;
    Radius: Integer;
    Strength: Integer;
    Dexterity: Integer;
    Intellect: Integer;
    Perception: Integer;
    Protection: Integer;
    Reach: Integer;
    SP: Integer;
    LP: Integer;
  end;

type
  TPlayer = class(TObject)
  private
    FIdx: Integer;
    FIsDefeat: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    property Idx: Integer read FIdx write FIdx;
    property IsDefeat: Boolean read FIsDefeat write FIsDefeat;
    function MaxExp(const Level: Integer): Integer;
    procedure Render(Canvas: TCanvas);
    procedure Defeat;
    procedure FindIdx;
    procedure Save;
    procedure Load;
  end;

type
  TMobs = class(TObject)
  private
    FForce: TStringList;
    FCoord: TStringList;
    FID: TStringList;
    FLevel: TStringList;
    FName: TStringList;
    FLife: TStringList;
    FDam: TStringList;
    FRad: TStringList;
    FAt1: TStringList;
    FAt2: TStringList;
    FReach: TStringList;
    FPoint: TStringList;
    FPlayer: TPlayer;
    FIsLook: Boolean;
    FLX: Byte;
    FLY: Byte;
    procedure Miss(Atk: TMobInfo);
    procedure Defeat(DefId: Integer; Def: TMobInfo);
    function Look(DX, DY: Integer): Boolean;
  public
    MobLB: TBitmap;
    Lifebar: TPNGImage;
    Frame: TPNGImage;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure ChLook;
    procedure LoadFromMap(const N: Integer);
    procedure Add(const Force, X, Y, Id, Level, Exp: Integer; N: string; L, MaxL, MinD, MaxD, R, Str, Dex, Int, Per, Prot, Reach, SP,
      LP: Integer); overload;
    procedure Add(const P: TMobInfo); overload;
    function BarWidth(CX, MX, GS: Integer): Integer;
    function Count: Integer;
    function Get(I: Integer): TMobInfo;
    function Del(I: Integer): Boolean;
    function IndexOf(const X, Y: Integer): Integer;
    procedure ModLife(const Index, Value: Integer);
    procedure ModExp(const Index, Value: Integer);
    procedure Move(const AtkId, DX, DY: Integer); overload;
    procedure Move(const DX, DY: Integer); overload;
    procedure Attack(const NX, NY, AtkId, DefId: Integer; Atk, Def: TMobInfo);
    procedure MoveToPosition(const I, DX, DY: Integer);
    procedure SetPosition(const I, X, Y: Integer);
    function GetDist(FromX, FromY, ToX, ToY: Single): Word;
    procedure Render(Canvas: TCanvas);
    property Player: TPlayer read FPlayer write FPlayer;
    property IsLook: Boolean read FIsLook write FIsLook;
    property LX: Byte read FLX write FLX;
    property LY: Byte read FLY write FLY;
  end;

implementation

uses
  SysUtils,
  Math,
  Dialogs,
  WorldMap,
  Mods,
  TiledMap,
  PathFind,
  MsgLog,
  Utils;

const
  F = '%d=%d';

  { TMobs }

function IsTilePassable(X, Y: Integer): Boolean; stdcall;
begin
  with Map.GetCurrentMap do
  begin
    Result := TiledObject[FMap[lrTiles][X][Y]].Passable;
    if (FMap[lrObjects][X][Y] >= 0) then
      Result := Result and TiledObject[FMap[lrObjects][X][Y]].Passable;
  end;
end;

function TMobs.BarWidth(CX, MX, GS: Integer): Integer;
var
  I: Integer;
begin
  if (CX = MX) and (CX = 0) then
  begin
    Result := 0;
    Exit;
  end;
  if (MX <= 0) then
    MX := 1;
  I := (CX * GS) div MX;
  if I <= 0 then
    I := 0;
  if (CX >= MX) then
    I := GS;
  Result := I;
end;

procedure TMobs.Add(const Force, X, Y, Id, Level, Exp: Integer; N: string; L, MaxL, MinD, MaxD, R, Str, Dex, Int, Per, Prot, Reach, SP, LP: Integer);
begin
  FForce.Append(Force.ToString);
  FCoord.Append(Format(F, [X, Y]));
  FID.Append(Id.ToString);
  FLevel.Append(Format(F, [Level, Exp]));
  FName.Append(N);
  FLife.Append(Format(F, [L, MaxL]));
  FDam.Append(Format(F, [MinD, MaxD]));
  FRad.Append(R.ToString);
  FAt1.Append(Format(F, [Str, Dex]));
  FAt2.Append(Format(F, [Int, Per]));
  FReach.Append(Format(F, [Prot, Reach]));
  FPoint.Append(Format(F, [SP, LP]));
end;

procedure TMobs.Add(const P: TMobInfo);
begin
  Self.Add(P.Force, P.X, P.Y, P.Id, P.Level, P.Exp, P.Name, P.Life, P.MaxLife, P.MinDam, P.MaxDam, P.Radius, P.Strength, P.Dexterity, P.Intellect,
    P.Perception, P.Protection, P.Reach, P.SP, P.LP);
end;

procedure TMobs.Attack(const NX, NY, AtkId, DefId: Integer; Atk, Def: TMobInfo);
var
  Dam: Integer;
begin
  if (Math.RandomRange(0, Atk.Dexterity + 1) >= Math.RandomRange(0, Def.Dexterity + 1)) then
  begin
    Dam := Math.RandomRange(Atk.MinDam, Atk.MaxDam + 1);
    Dam := EnsureRange(Dam - Def.Protection, 1, 255);
    if (Math.RandomRange(0, Atk.Level + 1) > Math.RandomRange(0, 100)) then
    begin
      Dam := Dam + Atk.Strength;
      ModLife(DefId, -Dam);
      Log.Add(Format('%s: крит %d HP', [Def.Name, -Dam]));
    end
    else
    begin
      ModLife(DefId, -Dam);
      Log.Add(Format('%s: %d HP', [Def.Name, -Dam]));
    end;
  end
  else
    Miss(Atk);
  if Get(DefId).Life = 0 then
    Defeat(DefId, Def);
end;

procedure TMobs.ChLook;
var
  Plr: TMobInfo;
begin
  if Player.IsDefeat then
    Exit;
  IsLook := not IsLook;
  if IsLook then
  begin
    Plr := Get(Player.Idx);
    LX := Plr.X;
    LY := Plr.Y;
  end;
  Log.Turn;
end;

procedure TMobs.Clear;
begin
  FForce.Clear;
  FCoord.Clear;
  FID.Clear;
  FLevel.Clear;
  FName.Clear;
  FLife.Clear;
  FDam.Clear;
  FRad.Clear;
  FAt1.Clear;
  FAt2.Clear;
  FReach.Clear;
  FPoint.Clear;
end;

function TMobs.Count: Integer;
begin
  Result := FID.Count;
end;

constructor TMobs.Create;
begin
  FIsLook := False;
  Player := TPlayer.Create;
  MobLB := TBitmap.Create;
  Lifebar := TPNGImage.Create;
  Lifebar.LoadFromFile(GMods.GetPath('images', 'lifebar.png'));
  Frame := TPNGImage.Create;
  Frame.LoadFromFile(GMods.GetPath('images', 'frame.png'));
  FForce := TStringList.Create;
  FCoord := TStringList.Create;
  FID := TStringList.Create;
  FLevel := TStringList.Create;
  FName := TStringList.Create;
  FLife := TStringList.Create;
  FDam := TStringList.Create;
  FRad := TStringList.Create;
  FAt1 := TStringList.Create;
  FAt2 := TStringList.Create;
  FReach := TStringList.Create;
  FPoint := TStringList.Create;
end;

procedure TMobs.Defeat(DefId: Integer; Def: TMobInfo);
var
  I, Exp: Integer;
begin
  begin
    Exp := Def.Exp;
    Log.Add(Format('%s убит', [Def.Name]));
    Del(DefId);
    // Map.GetCurrentMap.FMap[lrMonsters][NX][NY] := -1;
    Player.Idx := -1;
    for I := 0 to Count - 1 do
      if FForce[I] = '1' then
      begin
        Player.Idx := I;
        Break;
      end;
    if Player.Idx = -1 then
      Player.Defeat
    else
      ModExp(Player.Idx, Exp);
  end;
end;

function TMobs.Del(I: Integer): Boolean;
begin
  FForce.Delete(I);
  FCoord.Delete(I);
  FID.Delete(I);
  FLevel.Delete(I);
  FName.Delete(I);
  FLife.Delete(I);
  FDam.Delete(I);
  FRad.Delete(I);
  FAt1.Delete(I);
  FAt2.Delete(I);
  FReach.Delete(I);
  FPoint.Delete(I);
  Result := True;
end;

destructor TMobs.Destroy;
begin
  FreeAndNil(FPlayer);
  FreeAndNil(MobLB);
  FreeAndNil(Lifebar);
  FreeAndNil(Frame);
  FreeAndNil(FForce);
  FreeAndNil(FCoord);
  FreeAndNil(FID);
  FreeAndNil(FLevel);
  FreeAndNil(FName);
  FreeAndNil(FLife);
  FreeAndNil(FDam);
  FreeAndNil(FRad);
  FreeAndNil(FAt1);
  FreeAndNil(FAt2);
  FreeAndNil(FReach);
  FreeAndNil(FPoint);
  inherited;
end;

function TMobs.Get(I: Integer): TMobInfo;
begin
  Result.Force := FForce[I].ToInteger;
  Result.X := FCoord.KeyNames[I].ToInteger;
  Result.Y := FCoord.ValueFromIndex[I].ToInteger;
  Result.Id := FID[I].ToInteger;
  Result.Level := FLevel.KeyNames[I].ToInteger;
  Result.Exp := FLevel.ValueFromIndex[I].ToInteger;
  Result.Name := FName[I];
  Result.Life := FLife.KeyNames[I].ToInteger;
  Result.MaxLife := FLife.ValueFromIndex[I].ToInteger;
  Result.MinDam := FDam.KeyNames[I].ToInteger;
  Result.MaxDam := FDam.ValueFromIndex[I].ToInteger;
  Result.Radius := FRad[I].ToInteger;
  Result.Strength := FAt1.KeyNames[I].ToInteger;
  Result.Dexterity := FAt1.ValueFromIndex[I].ToInteger;
  Result.Intellect := FAt2.KeyNames[I].ToInteger;
  Result.Perception := FAt2.ValueFromIndex[I].ToInteger;
  Result.Protection := FReach.KeyNames[I].ToInteger;
  Result.Reach := FReach.ValueFromIndex[I].ToInteger;
  Result.SP := FPoint.KeyNames[I].ToInteger;
  Result.LP := FPoint.ValueFromIndex[I].ToInteger;
end;

function TMobs.GetDist(FromX, FromY, ToX, ToY: Single): Word;
begin
  Result := Round(SQRT(SQR(ToX - FromX) + SQR(ToY - FromY)));
end;

function TMobs.IndexOf(const X, Y: Integer): Integer;
begin
  Result := FCoord.IndexOf(Format(F, [X, Y]));
end;

procedure TMobs.LoadFromMap(const N: Integer);
var
  I, J, F, X, Y: Integer;
begin
  J := 0;
  for Y := 0 to Map.GetMap(N).Height - 1 do
    for X := 0 to Map.GetMap(N).Width - 1 do
    begin
      F := 0;
      I := Map.GetMap(N).FMap[lrMonsters][X][Y];
      if I >= 0 then
      begin
        with Map.GetMap(N).TiledObject[I] do
        begin
          if LowerCase(Name) = 'player' then
          begin
            Player.Idx := J;
            F := 1;
          end;
          Add(F, X, Y, I, Level, Exp, Name, Life, Life, MinDam, MaxDam, Radius, Strength, Dexterity, Intellect, Perception, Protection, Reach, 0, 0);
          Inc(J);
        end;
      end;
    end;
end;

procedure TMobs.ModExp(const Index, Value: Integer);
var
  SP, LP, Level, Exp, MaxExp: Integer;
begin
  Level := FLevel.KeyNames[Index].ToInteger;
  Exp := FLevel.ValueFromIndex[Index].ToInteger;
  SP := FPoint.KeyNames[Index].ToInteger;
  LP := FPoint.ValueFromIndex[Index].ToInteger;
  Exp := Exp + Value;
  Log.Add(Format('Опыт: +%d.', [Value]));
  MaxExp := Player.MaxExp(Level);
  if Exp > MaxExp then
  begin
    Log.Add('Новый уровень!');
    Level := Level + 1;
    SP := SP + 3;
    LP := LP + 1;
  end;
  FLevel[Index] := Format(F, [Level, Exp]);
  FPoint[Index] := Format(F, [SP, LP]);
end;

procedure TMobs.ModLife(const Index, Value: Integer);
var
  CurLife, MaxLife: Integer;
begin
  CurLife := FLife.KeyNames[Index].ToInteger + Value;
  MaxLife := FLife.ValueFromIndex[Index].ToInteger;
  CurLife := Math.EnsureRange(CurLife, 0, MaxLife);
  FLife[Index] := Format(F, [CurLife, MaxLife]);
end;

procedure TMobs.Move(const DX, DY: Integer);
var
  I, NX, NY: Integer;
  Plr, Enm: TMobInfo;
begin
  if Player.IsDefeat then
    Exit;
  Log.Turn;
  Move(Player.Idx, DX, DY);
  for I := Count - 1 downto 0 do
  begin
    if Player.Idx = -1 then
      Exit;
    if Get(I).Force = 0 then
    begin
      Plr := Get(Player.Idx);
      Enm := Get(I);
      NX := 0;
      NY := 0;
      if (GetDist(Enm.X, Enm.Y, Plr.X, Plr.Y) > Enm.Radius) or not IsPathFind(Map.GetCurrentMap.Width, Map.GetCurrentMap.Height, Enm.X, Enm.Y, Plr.X,
        Plr.Y, @IsTilePassable, NX, NY) then
        Continue;
      MoveToPosition(I, NX, NY);
    end
    else
    begin
    end;
  end;
end;

procedure TMobs.MoveToPosition(const I, DX, DY: Integer);
var
  M: TMobInfo;
  NX, NY: Integer;
begin
  NX := 0;
  NY := 0;
  M := Get(I);
  if DX < M.X then
    NX := -1;
  if DX > M.X then
    NX := 1;
  if DY < M.Y then
    NY := -1;
  if DY > M.Y then
    NY := 1;
  Move(I, NX, NY);
end;

procedure TMobs.Render(Canvas: TCanvas);
var
  I, X, Y: Integer;
  M: TMobInfo;
begin
  for I := 0 to Map.GetCurrentMapMobs.Count - 1 do
  begin
    M := Map.GetCurrentMapMobs.Get(I);
    Map.GetCurrentMapMobs.MobLB.Assign(Map.GetCurrentMapMobs.Lifebar);
    Map.GetCurrentMapMobs.MobLB.Width := Map.GetCurrentMapMobs.BarWidth(M.Life, M.MaxLife, 30);
    X := M.X * Map.GetCurrentMap.TileSize;
    Y := M.Y * Map.GetCurrentMap.TileSize;
    Canvas.Draw(X + 1, Y, Map.GetCurrentMapMobs.MobLB);
    Canvas.Draw(X, Y, Map.GetCurrentMap.TiledObject[M.Id].Image);
  end;
  if IsLook then
  begin
    Canvas.Draw(LX * Map.GetCurrentMap.TileSize, LY * Map.GetCurrentMap.TileSize, Map.GetCurrentMapMobs.Frame);
  end;
end;

function TMobs.Look(DX, DY: Integer): Boolean;
var
  S: string;
begin
  Result := False;
  if IsLook then
  begin
    FLX := EnsureRange(FLX + DX, 0, Map.GetCurrentMap.Width - 1);
    FLY := EnsureRange(FLY + DY, 0, Map.GetCurrentMap.Height - 1);
    S := '';
    with Map.GetCurrentMap do
    begin
      S := TiledObject[FMap[lrTiles][FLX][FLY]].Name;
      if (FMap[lrObjects][FLX][FLY] >= 0) then
        S := S + '/' + TiledObject[FMap[lrObjects][FLX][FLY]].Name;
    end;
    Log.Turn;
    Log.Add(S);
    Result := True;
  end;
end;

procedure TMobs.Miss(Atk: TMobInfo);
begin
  Log.Add(Format('%s промахивается.', [Atk.Name]));
end;

procedure TMobs.Move(const AtkId, DX, DY: Integer);
var
  NX, NY, DefId, I, Dam: Integer;
  Atk, Def: TMobInfo;
  ObjType, ItemType: string;
begin
  if Look(DX, DY) or (Player.Idx = -1) then
    Exit;
  Atk := Get(AtkId);
  if Atk.Life <= 0 then
    Exit;
  NX := Atk.X + DX;
  NY := Atk.Y + DY;

  if (NX < 0) and Map.Go(drMapLeft) then
  begin
    Log.Add(Map.GetCurrentMap.Name);
    Map.GetCurrentMapMobs.SetPosition(Map.GetCurrentMapMobs.Player.Idx, Map.GetCurrentMap.Width - 1, NY);
    Exit;
  end;
  if (NX > Map.GetCurrentMap.Width - 1) and Map.Go(drMapRight) then
  begin
    Log.Add(Map.GetCurrentMap.Name);
    Map.GetCurrentMapMobs.SetPosition(Map.GetCurrentMapMobs.Player.Idx, 0, NY);
    Exit;
  end;
  if (NY < 0) and Map.Go(drMapUp) then
  begin
    Log.Add(Map.GetCurrentMap.Name);
    Map.GetCurrentMapMobs.SetPosition(Map.GetCurrentMapMobs.Player.Idx, NX, Map.GetCurrentMap.Height - 1);
    Exit;
  end;
  if (NY > Map.GetCurrentMap.Height - 1) and Map.Go(drMapDown) then
  begin
    Log.Add(Map.GetCurrentMap.Name);
    Map.GetCurrentMapMobs.SetPosition(Map.GetCurrentMapMobs.Player.Idx, NX, 0);
    Exit;
  end;

  if (NX < 0) or (NX > Map.GetCurrentMap.Width - 1) then
    Exit;
  if (NY < 0) or (NY > Map.GetCurrentMap.Height - 1) then
    Exit;

  ObjType := Map.GetCurrentMap.GetTileType(lrObjects, NX, NY);
  ItemType := Map.GetCurrentMap.GetTileType(lrItems, NX, NY);

  if not IsTilePassable(NX, NY) then
    Exit;

  if (ObjType = 'closed_door') or (ObjType = 'hidden_door') or (ObjType = 'closed_chest') or (ObjType = 'trapped_chest') then
  begin
    Inc(Map.GetCurrentMap.FMap[lrObjects][NX][NY]);
    if (ObjType = 'closed_chest') then
    begin
      Map.GetCurrentMap.FMap[lrItems][NX][NY] := RandomRange(Map.GetCurrentMap.Firstgid[lrItems], Map.GetCurrentMap.Firstgid[lrMonsters]) - 1;
    end;
    Exit;
  end;

  if (ItemType <> '') then
  begin
    Log.Add('Ваша добыча: ' + ItemType);
    Map.GetCurrentMap.FMap[lrItems][NX][NY] := -1;
    Exit;
  end;

  DefId := Self.IndexOf(NX, NY);
  if DefId >= 0 then
  begin
    Def := Get(DefId);
    if Atk.Force <> Def.Force then
    begin
      Self.Attack(NX, NY, AtkId, DefId, Atk, Def);
    end;
    Exit;
  end;
  SetPosition(AtkId, NX, NY);
end;

procedure TMobs.SetPosition(const I, X, Y: Integer);
begin
  FCoord[I] := Format(F, [X, Y]);
end;

{ TPlayer }

constructor TPlayer.Create;
begin
  Idx := -1;
  IsDefeat := False;
end;

procedure TPlayer.Defeat;
begin
  IsDefeat := True;
  ShowMessage('DEFEAT!!!');
end;

destructor TPlayer.Destroy;
begin

  inherited;
end;

procedure TPlayer.FindIdx;
var
  I: Integer;
  P: TMobInfo;
begin
  Idx := -1;
  for I := 0 to Map.GetCurrentMapMobs.Count - 1 do
  begin
    P := Map.GetCurrentMapMobs.Get(I);
    if P.Force = 1 then
    begin
      Idx := I;
      Break;
    end;
  end;
end;

procedure TPlayer.Render(Canvas: TCanvas);
var
  S: string;
  M: TMobInfo;
begin
  if Map.GetCurrentMapMobs.Player.IsDefeat then
    Exit;
  M := Map.GetCurrentMapMobs.Get(Idx);
  S := Format('%s HP:%d/%d Dam:%d-%d P:%d Lev:%d Exp:%d/%d SP/LP:%d/%d STR/DEX/INT/PER: %d/%d/%d/%d',
    [M.Name, M.Life, M.MaxLife, M.MinDam, M.MaxDam, M.Protection, M.Level, M.Exp, MaxExp(M.Level), M.SP, M.LP, M.Strength, M.Dexterity, M.Intellect,
    M.Perception]);
  Canvas.TextOut(0, Map.GetCurrentMap.TileSize * (Map.GetCurrentMap.Height + 4), S);
end;

procedure TPlayer.Load;
var
  Path: string;
  SL: TStringList;
  M: TMobInfo;
  Level, Exp, MaxLife, MinDam, MaxDam, Str, Dex, Int, Per, Prot, SP, LP: Integer;
begin
  if IsDefeat then
    Exit;
  Path := GetPath('saves') + 'player.sav';
  if not FileExists(Path) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path, TEncoding.UTF8);
    Level := StrToInt(SL[0]);
    Exp := StrToInt(SL[1]);
    MaxLife := StrToInt(SL[2]);
    MinDam := StrToInt(SL[3]);
    MaxDam := StrToInt(SL[4]);
    Str := StrToInt(SL[5]);
    Dex := StrToInt(SL[6]);
    Int := StrToInt(SL[7]);
    Per := StrToInt(SL[8]);
    Prot := StrToInt(SL[9]);
    SP := StrToInt(SL[10]);
    LP := StrToInt(SL[11]);
    M := Map.GetCurrentMapMobs.Get(Idx);
    Map.GetCurrentMapMobs.Del(Idx);
    M.Level := Level;
    M.Exp := Exp;
    M.Life := MaxLife;
    M.MaxLife := MaxLife;
    M.MinDam := MinDam;
    M.MaxDam := MaxDam;
    M.Strength := Str;
    M.Dexterity := Dex;
    M.Intellect := Int;
    M.Perception := Per;
    M.Protection := Prot;
    M.SP := SP;
    M.LP := LP;
    Map.GetCurrentMapMobs.Add(M);
    Map.GetCurrentMapMobs.Player.FindIdx;
  finally
    FreeAndNil(SL);
  end;
end;

function TPlayer.MaxExp(const Level: Integer): Integer;
var
  I: Integer;
begin
  Result := 10;
  for I := 1 to Level do
    Result := Result + ((Level * 10) + Round(Result * 0.33));
end;

procedure TPlayer.Save;
var
  P: TMobInfo;
  Path: string;
  SL: TStringList;
begin
  if IsDefeat then
    Exit;
  Path := GetPath('saves') + 'player.sav';
  SL := TStringList.Create;
  P := Map.GetCurrentMapMobs.Get(Idx);
  try
    SL.Append(IntToStr(P.Level));
    SL.Append(IntToStr(P.Exp));
    SL.Append(IntToStr(P.MaxLife));
    SL.Append(IntToStr(P.MinDam));
    SL.Append(IntToStr(P.MaxDam));
    SL.Append(IntToStr(P.Strength));
    SL.Append(IntToStr(P.Dexterity));
    SL.Append(IntToStr(P.Intellect));
    SL.Append(IntToStr(P.Perception));
    SL.Append(IntToStr(P.Protection));
    SL.Append(IntToStr(P.SP));
    SL.Append(IntToStr(P.LP));
    SL.SaveToFile(Path, TEncoding.UTF8);
  finally
    FreeAndNil(SL);
  end;
end;

end.
