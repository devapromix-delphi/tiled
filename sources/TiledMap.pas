unit TiledMap;

interface

uses
  System.Classes,
  Vcl.Imaging.PNGImage;

type
  TTiledMap = class(TObject)
  private type
    TLayer = array of array of Integer;
  private
    FWidth: Integer;
    FHeight: Integer;
    FTileSize: Integer;
    FOwner: TComponent;
    FName: string;
    FLevel: Integer;
  public type
    TLayerEnum = (lrTiles, lrObjects, lrItems, lrMonsters);
  public type
    TTiledObject = class(TObject)
    private
    public
      Image: TPNGImage;
      Name: string;
      TileType: string;
      Strength: Integer;
      Dexterity: Integer;
      Intellect: Integer;
      Perception: Integer;
      Protection: Integer;
      Reach: Integer;
      Level: Integer;
      Exp: Integer;
      Life: Integer;
      MinDam: Integer;
      MaxDam: Integer;
      Radius: Integer;
      Passable: Boolean;
      Transparent: Boolean;
      constructor Create;
      destructor Destroy; override;
    end;
  public
    FMap: array [TLayerEnum] of TLayer;
    Firstgid: array [TLayerEnum] of Integer;
    TiledObject: array of TTiledObject;
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property TileSize: Integer read FTileSize;
    property Name: string read FName;
    property Level: Integer read FLevel;
    function GetTileType(const L: TLayerEnum; const X, Y: Integer): string;
  end;

implementation

uses
  System.SysUtils,
  Math,
  Utils,
  Xml.XMLDoc,
  Xml.XMLIntf,
  System.IOUtils,
  Dialogs,
  Mods;

{ TTiledMap }

constructor TTiledMap.Create(AOwner: TComponent);
begin
  FOwner := AOwner;
  FWidth := 100;
  FHeight := 100;
  FTileSize := 32;
  FLevel := 0;
  FName := '';
end;

destructor TTiledMap.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(TiledObject) do
    FreeAndNil(TiledObject[I]);
  inherited;
end;

function TTiledMap.GetTileType(const L: TLayerEnum; const X, Y: Integer): string;
begin
  Result := '';
  if (FMap[L][X][Y] > 0) then
    Result := TiledObject[FMap[L][X][Y]].TileType;
end;

procedure TTiledMap.LoadFromFile(const FileName: string);
var
  XMLDoc: TXMLDocument;
  Node: IXMLNode;
  S, LayerName: string;
  Section: string;
  I, Count, ID: Integer;

  procedure LoadLayer(L: TLayerEnum);
  var
    X, Y: Integer;
    SL: TStringList;
    V: TArray<string>;
  begin
    SetLength(FMap[L], FWidth, FHeight);
    Node := XMLDoc.DocumentElement.ChildNodes[I].ChildNodes['data'];
    SL := TStringList.Create;
    SL.Text := Trim(Node.Text);
    for Y := 0 to FHeight - 1 do
    begin
      V := SL[Y].Split([',']);
      for X := 0 to FWidth - 1 do
        FMap[L][X][Y] := StrToIntDef(V[X], 0) - 1;
    end;
    FreeAndNil(SL);
  end;

  procedure LoadTileset(const FileName: string);
  var
    XMLDoc: TXMLDocument;
    Node, NodeProps, NodeProp: IXMLNode;
    I, J, Count, PropCount: Integer;
    Name, Value, TileType: string;
  begin
    XMLDoc := TXMLDocument.Create(FOwner);
    XMLDoc.LoadFromFile(FileName);
    try
      Count := XMLDoc.DocumentElement.ChildNodes.Count;
      for I := 0 to Count - 1 do
      begin
        Section := TPath.GetFileNameWithoutExtension(FileName);
        Node := XMLDoc.DocumentElement.ChildNodes[I];
        if Node.NodeName = 'tile' then
        begin
          TileType := Trim(Node.Attributes['type']);
          NodeProps := Node.ChildNodes['properties'];
          PropCount := NodeProps.ChildNodes.Count;
          Node := Node.ChildNodes['image'];
          SetLength(TiledObject, ID + 1);
          TiledObject[ID] := TTiledObject.Create;
          TiledObject[ID].TileType := TileType;
          TiledObject[ID].Image.LoadFromFile(GMods.GetPath('', Section + '\' + Trim(Node.Attributes['source'])));
          for J := 0 to PropCount - 1 do
          begin
            NodeProp := NodeProps.ChildNodes[J];
            Name := NodeProp.Attributes['name'];
            Value := NodeProp.Attributes['value'];
            if (Name = 'name') then
              TiledObject[ID].Name := Trim(Value);
            if (Section = 'tiles') then
            begin
              if (Name = 'passable') then
                TiledObject[ID].Passable := StrToBoolDef(Value, False);
              if (Name = 'transparent') then
                TiledObject[ID].Transparent := StrToBoolDef(Value, False);
            end;
            if Section = 'objects' then
            begin
              if (Name = 'passable') then
                TiledObject[ID].Passable := StrToBoolDef(Value, False);
              if (Name = 'transparent') then
                TiledObject[ID].Transparent := StrToBoolDef(Value, False);
            end;
            if Section = 'monsters' then
            begin
              if (Name = 'strength') then
                TiledObject[ID].Strength := StrToIntDef(Value, 1);
              if (Name = 'dexterity') then
                TiledObject[ID].Dexterity := StrToIntDef(Value, 1);
              if (Name = 'intellect') then
                TiledObject[ID].Intellect := StrToIntDef(Value, 1);
              if (Name = 'perception') then
                TiledObject[ID].Perception := StrToIntDef(Value, 1);
              if (Name = 'protection') then
                TiledObject[ID].Protection := StrToIntDef(Value, 0);
              if (Name = 'reach') then
                TiledObject[ID].Reach := StrToIntDef(Value, 0);
              if (Name = 'level') then
                TiledObject[ID].Level := StrToIntDef(Value, 1);
              if (Name = 'exp') then
                TiledObject[ID].Exp := StrToIntDef(Value, 0);
              if (Name = 'life') then
                TiledObject[ID].Life := StrToIntDef(Value, 5);
              if (Name = 'radius') then
                TiledObject[ID].Radius := StrToIntDef(Value, 1);
              if (Name = 'min_damage') then
                TiledObject[ID].MinDam := EnsureRange(StrToIntDef(Value, 1), 1, 250);
              if (Name = 'max_damage') then
                TiledObject[ID].MaxDam := EnsureRange(StrToIntDef(Value, 2), 2, 255);
            end;
          end;
          Inc(ID);
        end;
      end;
    finally
      FreeAndNil(XMLDoc);
    end;
  end;

  procedure LoadProperties(Node: IXMLNode);
  var
    N: IXMLNode;
    I: Integer;
    Name, Value: string;
  begin
    for I := 0 to Node.ChildNodes.Count - 1 do
    begin
      N := Node.ChildNodes[I];
      Name := Trim(N.Attributes['name']);
      Value := Trim(N.Attributes['value']);
      if Name = 'Name' then
        FName := Trim(Value);
      if Name = 'Level' then
        FLevel := StrToIntDef(Value, 0);
    end;
  end;

begin
  ID := 0;
  XMLDoc := TXMLDocument.Create(FOwner);
  XMLDoc.LoadFromFile(GMods.GetPath('maps', FileName));
  try
    FTileSize := StrToIntDef(XMLDoc.DocumentElement.Attributes['tilewidth'], 32);
    FWidth := StrToIntDef(XMLDoc.DocumentElement.Attributes['width'], 100);
    FHeight := StrToIntDef(XMLDoc.DocumentElement.Attributes['height'], 100);
    Count := XMLDoc.DocumentElement.ChildNodes.Count;
    for I := 0 to Count - 1 do
    begin
      Node := XMLDoc.DocumentElement.ChildNodes[I];
      if Node.NodeName = 'properties' then
      begin
        LoadProperties(Node);
        Continue;
      end;
      if Node.NodeName = 'tileset' then
      begin
        S := GMods.GetPath('maps', Trim(Node.Attributes['source']));
        Section := TPath.GetFileNameWithoutExtension(S);
        if Section = 'tiles' then
          Firstgid[lrTiles] := StrToInt(Trim(Node.Attributes['firstgid']));
        if Section = 'objects' then
          Firstgid[lrObjects] := StrToInt(Trim(Node.Attributes['firstgid']));
        if Section = 'items' then
          Firstgid[lrItems] := StrToInt(Trim(Node.Attributes['firstgid']));
        if Section = 'monsters' then
          Firstgid[lrMonsters] := StrToInt(Trim(Node.Attributes['firstgid']));
        LoadTileset(S);
        Continue;
      end;
      if Node.NodeName = 'layer' then
      begin
        LayerName := Trim(Node.Attributes['name']);
        if (LayerName = 'tiles') then
          LoadLayer(lrTiles);
        if (LayerName = 'objects') then
          LoadLayer(lrObjects);
        if (LayerName = 'items') then
          LoadLayer(lrItems);
        if (LayerName = 'monsters') then
          LoadLayer(lrMonsters);
      end;
    end;
  finally
    FreeAndNil(XMLDoc);
  end;
end;

{ TTiledMap.TTiledObject }

constructor TTiledMap.TTiledObject.Create;
begin
  Image := TPNGImage.Create;
end;

destructor TTiledMap.TTiledObject.Destroy;
begin
  FreeAndNil(Image);
  inherited;
end;

end.
