unit Noso_TUI;

{$mode ObjFPC}{$H+}
{$codePage CP437}

interface

uses
  Classes, SysUtils, video, keyboard;

Type
  TAlign = (AlLeft, AlRight, AlCenter);
  TBorder = (BdSimple, BdDouble, BdBlock);

Procedure TextOut(X,Y : Word;Const S : String;FC,BC:word);
Procedure VertLine(Column,y1,y2,FroCol, BackCol:word;Limits:boolean = false);
Procedure HorizLine(filenum,x1,x2,FroCol, BackCol:word;Limits:boolean = false);
Procedure GotoXy(x,y:word);
Procedure DWindow(x1,y1,x2,y2:integer;title:String;FC,FB:word);
Procedure SetColor(color:word);
Procedure BKColor(color:word);
Procedure Cls();
Procedure SetBorder(LBorder:TBorder);
Procedure DLabel(x,y:word;Texto:String;Lwidth:integer;LAling:TAlign;forCol,BacCol:word);

// KeyBoard
Function KeyPressedCode:integer;

Const
  black = video.black;
  blue  = video.blue;
  green = video.green;
  cyan  = video.cyan;
  red   = video.red;
  magenta = video.magenta;
  brown = video.brown;
  lightGray = video.lightGray;
  darkGray = video.darkGray;
  lightBlue = video.lightBlue;
  lightGreen = video.lightGreen;
  lightCyan = video.lightCyan;
  lightRed = video.lightRed;
  lightMagenta = video.lightMagenta;
  yellow = video.yellow;
  white = video.white;

var
  Fcolor : word = video.red;
  BColor : word = video.blue;
  Borders : Array of string;
  ActiveBorderStile : TBorder = BdSimple;
  LChar    : string;


implementation

Procedure TextOut(X,Y : Word;Const S : String;FC,BC:word);
Var
  W,P,I,M : Word;
begin
  P:=((X-1)+(Y-1)*ScreenWidth);
  M:=Length(S);
  If P+M>ScreenWidth*ScreenHeight then
    M:=ScreenWidth*ScreenHeight-P;
  For I:=1 to M do
    VideoBuf^[P+I-1]:=Ord(S[i])+(FC + BC shl 4) shl 8;
UpdateScreen(true);
end;

Procedure VertLine(Column,y1,y2,FroCol, BackCol:word;Limits:boolean = false);
var
  Counter : integer;
Begin
for counter := y1 to y2 do
   begin
   TextOut(Column,counter,LChar[5],FroCol,BackCol);
   end;
if limits then
   begin
   TextOut(Column,y1,LChar[3],FroCol,BackCol);
   TextOut(Column,y2,LChar[8],FroCol,BackCol);
   end;
End;

Procedure HorizLine(filenum,x1,x2,FroCol, BackCol:word;Limits:boolean = false);
var
  Counter : integer;
Begin
for counter := x1 to x2 do
   begin
   TextOut(counter,filenum,LChar[2],FroCol,BackCol);
   end;
if limits then
   begin
   TextOut(x1,filenum,LChar[10],FroCol,BackCol);
   TextOut(x2,filenum,LChar[6],FroCol,BackCol);
   end;
End;

Procedure GotoXy(x,y:word);
Begin
SetCursorPos(x-1,y-1);
End;

Procedure DWindow(x1,y1,x2,y2:integer;title:String;FC,FB:word);
var
  counter  : integer;
  TitleX   : integer;
Begin
TextOut(x1,y1,LChar[1],FC,FB);
TextOut(x1,y2,LChar[9],FC,FB);
TextOut(x2,y1,LChar[4],FC,FB);
TextOut(x2,y2,LChar[7],FC,FB);
For counter := x1+1 to x2-1 do
  Begin
  TextOut(counter,y1,LChar[2],FC,FB);
  TextOut(counter,y2,LChar[2],FC,FB);
  end;
For counter := y1+1 to y2-1 do
  Begin
  TextOut(x1,counter,LChar[5],FC,FB);
  TextOut(x2,counter,LChar[5],FC,FB);
  end;
if Title <> '' then
   begin
   TitleX := (x2-x1) div 2;
   TitleX := TitleX-(Length(Title)div 2);
   TextOut(TitleX,y1,LChar[6],FC,FB);
   TextOut(TitleX+1,y1,' '+Title+' ',FC,FB);
   TextOut(TitleX+3+length(title),y1,LChar[10],FC,FB);
   end;
End;

Procedure SetColor(color:word);
Begin
FColor := color;
UpdateScreen(true);
End;

Procedure BKColor(color:word);
Begin
BColor := color;
UpdateScreen(true);
End;

Procedure Cls();
Begin
ClearScreen;
UpdateScreen(true);
End;

Procedure SetBorder(LBorder:TBorder);
Begin
ActiveBorderStile := LBorder;
LCHar := Borders[Ord(LBorder)];
End;

Procedure DLabel(x,y:word;Texto:String;Lwidth:integer;LAling:TAlign;forCol,BacCol:word);
var
  OutText : string;
  Whites  : integer;
Begin
if LEngth(Texto)>LWidth then SetLEngth(Texto,LWidth);
Whites := (LWidth div 2)-(LEngth(Texto) div 2);
if LAling = AlLeft then OutText := Format('%0:-'+Lwidth.ToString+'s',[Texto])
else if LAling = AlRight then OutText := Format('%0:'+Lwidth.ToString+'s',[Texto])
else OutText := Format('%0:-'+Lwidth.ToString+'s',[Space(Whites)+Texto]);
TextOut(X,Y,OutText,ForCol,BacCol);


End;

Function KeyPressedCode:integer;
var
  LKey : TKeyEvent;
Begin
result := 0;
LKey:=PollKeyEvent;
If LKey<>0 then
   begin
   LKey:=GetKeyEvent;
   Result :=  GetKeyEventCode(LKey);
   end;
End;

Initialization
InitVideo;
InitKeyBoard;
ScreenWidth := 80;
ScreenHeight := 25;
Setlength(Borders,3);
Borders[0] := #218#196#194#191#179#180#217#193#192#195;
Borders[1] := #201#205#203#187#186#185#188#202#200#204;
Borders[2] := #219#219#219#219#219#219#219#219#219#219;
SetBorder(bdSimple);

Finalization
DoneKeyBoard;
DoneVideo;
END.
