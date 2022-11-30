unit Noso_TUI;

{$mode ObjFPC}{$H+}
{$codePage CP437}

interface

uses
  Classes, SysUtils, video, keyboard;

Type
  TAlign = (AlLeft, AlRight, AlCenter);
  TBorder = (BdSimple, BdDouble, BdBlock);

  TEditData = Record
    OutString : string;
    OutKey    : integer;
  end;

Procedure TextOut(X,Y : Word;Const S : String;FC,BC:word;update:boolean = true);
Procedure VertLine(Column,y1,y2,FroCol, BackCol:word;Limits:boolean = false);
Procedure HorizLine(filenum,x1,x2,FroCol, BackCol:word;Limits:boolean = false);
Procedure GotoXy(x,y:word);
Procedure DWindow(x1,y1,x2,y2:integer;title:String;FC,FB:word);
Procedure SetColor(color:word);
Procedure BKColor(color:word);
Procedure Cls(x1:integer = 0;y1:integer=0;x2:integer=0;y2:integer=0);
Procedure ClrLine(LNumber:integer;bkcolor:word=black);
Procedure SetBorder(LBorder:TBorder);
Procedure DLabel(x,y:word;Texto:String;Lwidth:integer;LAling:TAlign;forCol,BacCol:word);

// KeyBoard
Function KeyPressedCode:integer;
Function ReadEditScreen(x,y:integer;InitialString:String;EditWidth:Integer):TEditData;
Function ReadNavigationKey():integer;

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

Procedure TextOut(X,Y : Word;Const S : String;FC,BC:word;update:boolean = true);
Var
  W,P,I,M : Word;
begin
  P:=((X-1)+(Y-1)*ScreenWidth);
  M:=Length(S);
  If P+M>ScreenWidth*ScreenHeight then
    M:=ScreenWidth*ScreenHeight-P;
  For I:=1 to M do
    VideoBuf^[P+I-1]:=Ord(S[i])+(FC + BC shl 4) shl 8;
if update then UpdateScreen(true);
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
TextOut(x1,y1,LChar[1],FC,FB,false);
TextOut(x1,y2,LChar[9],FC,FB,false);
TextOut(x2,y1,LChar[4],FC,FB,false);
TextOut(x2,y2,LChar[7],FC,FB,false);
For counter := x1+1 to x2-1 do
  Begin
  TextOut(counter,y1,LChar[2],FC,FB,false);
  TextOut(counter,y2,LChar[2],FC,FB,false);
  end;
For counter := y1+1 to y2-1 do
  Begin
  TextOut(x1,counter,LChar[5],FC,FB,false);
  TextOut(x2,counter,LChar[5],FC,FB,false);
  end;
if Title <> '' then
   begin
   TitleX := (x2-x1) div 2;
   TitleX := TitleX-(Length(Title)div 2);
   TextOut(TitleX,y1,LChar[6],FC,FB,false);
   TextOut(TitleX+1,y1,' '+Title+' ',FC,FB,false);
   TextOut(TitleX+3+length(title),y1,LChar[10],FC,FB,false);
   end;
UpdateScreen(true);
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

Procedure Cls(x1:integer = 0;y1:integer=0;x2:integer=0;y2:integer=0);
var
  row,col : integer;
Begin
if x1 = 0 then ClearScreen
else
   begin
   for row := y1 to y2 do
      begin
      for col := x1 to x2 do
         begin
         TextOut(col,row,' ',fcolor,bcolor,false);
         end;
      end;
   end;
UpdateScreen(true);
End;

Procedure ClrLine(LNumber:integer;bkcolor:word=black);
var
  counter : integer;
Begin
for counter := 1 to ScreenWidth do
   TextOut(counter,lnumber,' ',fcolor,bkcolor,false);
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

Function ReadEditScreen(x,y:integer;InitialString:String;EditWidth:Integer):TEditData;
var
  currentValue, ToShow : string;
  IsDone       : boolean = false;
  KChar: Char;
  K: TKeyEvent;
  KCode : integer;
  ExitCode     : integer;
Begin
Dlabel(x,y,Initialstring,EditWidth,AlLEft,black,white);
Gotoxy(x+length(InitialString),y);
currentValue := InitialString;
Repeat
   sleep(1);
   K := PollKeyEvent;
   if K <> 0 then
      begin
      K := GetKeyEvent;
      K := TranslateKeyEvent(K);
      KCode := GetKeyEventCode(K);
      KChar := GetKeyEventChar(K);
      if KChar = #27 then
         begin
         CurrentValue := InitialString;
         ExitCode := 72;
         IsDone := true;
         end
      else if KChar=#13 then
         begin
         ExitCode := 80;
         IsDone := true;
         end
      else if KCode=65319 then
         begin
         ExitCode := 80;
         IsDone := true;
         end
      else if KCode=65313 then
         begin
         ExitCode := 72;
         IsDone := true;
         end
      else if KChar=#8 then
         begin
         if Length(currentValue)>0 then
            begin
            Setlength(CurrentValue,Length(currentValue)-1);
            if length(currentValue)>EditWidth-1 then
               Dlabel(x,y,RightStr(currentValue,EditWidth-1),EditWidth,AlLeft,black,white)
            else Dlabel(x,y,currentValue,EditWidth,AlLEft,black,white);
            if length(currentValue)>EditWidth-1 then Gotoxy(x+EditWidth-1,y)
            else Gotoxy(x+length(currentValue),y);
            end;
         end
      else
         begin
         CurrentValue := currentValue+KChar;
         if length(currentValue)>EditWidth-1 then
            Dlabel(x,y,RightStr(currentValue,EditWidth-1),EditWidth,AlLeft,black,white)
         else Dlabel(x,y,currentValue,EditWidth,AlLEft,black,white);
         if length(currentValue)>EditWidth-1 then Gotoxy(x+EditWidth-1,y)
         else Gotoxy(x+length(currentValue),y);
         end;
      end;
until IsDone ;
Result.OutKey:=ExitCode;
Result.OutString:=CurrentValue;
End;

Function ReadNavigationKey():integer;
var
  IsDone       : boolean = false;
  KChar: Char;
  K: TKeyEvent;
  KCode : integer;
  ExitCode     : integer;
Begin
Repeat
   sleep(1);
   K := PollKeyEvent;
   if K <> 0 then
      begin
      K := GetKeyEvent;
      K := TranslateKeyEvent(K);
      KCode := GetKeyEventCode(K);
      KChar := GetKeyEventChar(K);
      if KChar = #27 then
         begin
         ExitCode := 27;
         IsDone := true;
         end
      else if KChar=#13 then
         begin
         ExitCode := 13;
         IsDone := true;
         end
      else if KCode=65319 then
         begin
         ExitCode := 80;
         IsDone := true;
         end
      else if KCode=65313 then
         begin
         ExitCode := 72;
         IsDone := true;
         end
      else if KCode=65315 then
         begin
         ExitCode := 75;
         IsDone := true;
         end
      else if KCode=65317 then
         begin
         ExitCode := 77;
         IsDone := true;
         end
      end;
until isdone;
Result := ExitCode;

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
