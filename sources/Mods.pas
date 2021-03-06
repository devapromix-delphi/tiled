unit Mods;

interface

uses
  System.Classes;

type
  TMods = class(TObject)
  private const
    Default = 'elvion';
  private
    FSL: TStringList;
    FCurrent: string;
    function GetCurValue(const Name: string; DefValue: string): string; overload;
    function GetCurValue(const Name: string; DefValue: Integer): Integer; overload;
  public
    constructor Create;
    destructor Destroy; override;
    function GetPath(const SubDir, FileName: string): string;
    procedure SetCurrent(const FileName, MapFileName: string); overload;
    property Current: string read FCurrent;
  end;

var
  GMods: TMods;

implementation

uses
  System.SysUtils,
  Utils,
  WorldMap,
  Dialogs,
  Mobs;

{ TMods }

constructor TMods.Create;
begin
  FSL := TStringList.Create;
  FCurrent := Default;
end;

destructor TMods.Destroy;
begin
  FreeAndNil(FSL);
  inherited;
end;

function TMods.GetCurValue(const Name: string; DefValue: Integer): Integer;
var
  I: Integer;
begin
  I := FSL.IndexOfName(Name);
  Result := StrToIntDef(FSL.ValueFromIndex[I], DefValue);
end;

function TMods.GetCurValue(const Name: string; DefValue: string): string;
var
  I: Integer;
begin
  I := FSL.IndexOfName(Name);
  Result := FSL.ValueFromIndex[I];
end;

function TMods.GetPath(const SubDir, FileName: string): string;
begin
  Result := Utils.GetPath('mods' + PathDelim + Current + PathDelim + SubDir) + FileName;
  if not FileExists(Result) then
    Result := Utils.GetPath('mods' + PathDelim + Default +PathDelim + SubDir) + FileName;
end;

procedure TMods.SetCurrent(const FileName, MapFileName: string);
begin
  FCurrent := FileName;
  FSL.LoadFromFile(GetPath('', 'mod.cfg'), TEncoding.UTF8);
  Map.LoadFromFile(MapFileName);
end;

initialization

GMods := TMods.Create;

finalization

FreeAndNil(GMods);

end.
