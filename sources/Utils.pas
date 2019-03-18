unit Utils;

interface

function GetPath(SubDir: string): string;

implementation

uses SysUtils;

function GetPath(SubDir: string): string;
begin
  Result := ExtractFilePath(ParamStr(0));
  Result := IncludeTrailingPathDelimiter(Result + SubDir);
end;

end.
