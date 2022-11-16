program consominer2;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads, UTF8process,
  {$ENDIF}
  Classes, sysutils, consominer2unit, nosodig.crypto,NosoDig.Crypto68b, NosoDig.Crypto68, NosoDig.Crypto65,
  crt, functions, strutils;

Type
    TMainThread = class(TThread)
    protected
      procedure Execute; override;
    public
      Constructor Create(CreateSuspended : boolean);
    end;

    TMinerThread = class(TThread)
    private
      TNumber:integer;
    protected
      procedure Execute; override;
    public
      Constructor Create(CreateSuspended : boolean; const Thisnumber:integer);
    end;

    TNosoHashFn = function(S: String): THash32;
      THashLibs = (hl65, hl68, hl69, hl70);

    TNosoHashLib = packed record
      Name: String;
      HashFn: TNosoHashFn;
    end;

CONST
     NOSOHASH_LIBS: array[THashLibs] of TNosoHashLib =
    (
    (Name: 'NosoHash v65'; HashFn: @NosoHash65),
    (Name: 'NosoHash v68'; HashFn: @NosoHash68),
    (Name: 'NosoHash v69'; HashFn: @NosoHash68b),
    (Name: 'NosoHash v70'; HashFn: @NosoHash)
    );

var
  MainThread    : TMainThread;
  MinerThread   : TMinerThread;
  CurrHashLib   : THashLibs;


Constructor TMinerThread.Create(CreateSuspended : boolean; const Thisnumber:integer);
Begin
inherited Create(CreateSuspended);
Tnumber := ThisNumber;
FreeOnTerminate := True;
End;

procedure TMinerThread.Execute;
var
  BaseHash, ThisDiff : string;
  ThisHash : string = '';
  ThisSolution : TSolution;
  MyID : integer;
  ThisPrefix : string = '';
  MyCounter : int64 = 100000000;
  EndThisThread : boolean = false;
  ThreadBest  : string = '00000FFFFFFFFFFFFFFFFFFFFFFFFFFF';
Begin
if MyRunTest then MinimunTargetDiff := '00000';
MyID := TNumber-1;
ThisPrefix := MAINPREFIX+GetPrefix(MyID);
ThisPrefix := AddCharR('!',ThisPrefix,18);
ThreadBest := AddCharR('F',MinimunTargetDiff,32);
//SetStatusmsg(Format('Starting thread %d, MyRunTest %s',[TNumber,MyRunTest.ToString(true)]),green);
While ((not FinishMiners) and (not EndThisThread)) do
   begin
   BaseHash := ThisPrefix+MyCounter.ToString;
   Inc(MyCounter);
   ThisHash := NOSOHASH_LIBS[CurrHashLib].HashFn(BaseHash+PoolMinningAddress);
   {
   if Myhashlib = 70 then ThisHash := NosoHash(BaseHash+PoolMinningAddress)
   else if Myhashlib = 69 then ThisHash := NosoHash68b(BaseHash+PoolMinningAddress)
   else if Myhashlib = 68 then ThisHash := NosoHash68(BaseHash+PoolMinningAddress)
   else if Myhashlib = 65 then ThisHash := NosoHash65(BaseHash+PoolMinningAddress);
   }
   ThisDiff := GetHashDiff(TargetHash,ThisHash);
   if ThisDiff<ThreadBest then
      begin
      ThisSolution.Target:=TargetHash;
      ThisSolution.Hash  :=BaseHash;
      ThisSolution.Diff  :=ThisDiff;
      if not MyRunTest then
         begin
         if ThisHash = NosoHashOld(BaseHash+PoolMinningAddress) then
            begin
            AddSolution(ThisSolution);
            end;
         end;
      end;
   if MyRunTest then
      begin
      if MyCounter >= 100000000+HashesForTest then EndThisThread := true;
      end
   else
      begin
      if MyCounter mod 1000 =999 then AddIntervalHashes(1000);
      end;
   end;
DecreaseOMT;
End;

constructor TMainThread.Create(CreateSuspended : boolean);
Begin
inherited Create(CreateSuspended);
FreeOnTerminate := True;
End;

Procedure ClearPoolsScreen();
var
  counter : integer;
Begin
For counter := 0 to length(ArrSources)-1 do
   begin
   Gotoxy(3,12+(counter*2)); Write(Format('%0:-17s',[ArrSources[counter].ip]));
   Gotoxy(62,12+(counter*2)); Write(Format('%6s',[ArrSources[counter].shares.ToString]));
   Gotoxy(41,12+(counter*2)); Write(Format('%12s',[Int2Curr(ArrSources[counter].balance)]));
   Gotoxy(56,12+(counter*2)); Write(Format('%3s',[IntToStr(ArrSources[counter].payinterval)]));
   end;
U_ClearPoolsScreen := false;
End;

Procedure LaunchMiners();
var
  SourceResult : Boolean;
  Counter      : integer;
Begin
Setstatusmsg('Syncing...',yellow);
Repeat
   SourceResult := CheckSource;
   If not SourceResult then sleep(3000);
until SourceResult ;
U_Headers := true;
ResetIntervalHashes;
FinishMiners := false;
WrongThisPool := 0;
ClearSolutions();
LastSpeedCounter := 100000000;
for counter := 1 to MyCPUCount do
   begin
   MinerThread := TMinerThread.Create(true,counter);
   MinerThread.FreeOnTerminate:=true;
   MinerThread.Start;
   sleep(1);
   end;
SetOMT(MyCPUCount);
U_ActivePool := true;
End;

procedure TMainThread.Execute;
Begin
While not terminated do
   begin
   CheckLog;
   if SolutionsLength > 0 then
      SendPoolShare(GetSolution);
   if ( (blockage>=585) and (Not WaitingNextBlock) ) then
      begin
      FinishMiners     := true;
      WaitingNextBlock := true;
      Setstatusmsg('Waiting next block',green);
      end;
   if ( (blockAge>=10) and (blockage<584) ) then
      begin
      if WaitingNextBlock then
         begin
         WaitingNextBlock := false;
         ClearAllPools();
         U_ClearPoolsScreen := true;
         BlockCompleted := false;
         end
      else
         begin
         if AllFilled then
            begin
            if not BlockCompleted then
               begin
               BlockCompleted := true;
               Setstatusmsg('All shares completed for this block',green);
               end;
            end
         else
            begin
            if GetOMTValue =0 then
               LaunchMiners
            end;
         end
      end;
   sleep(1);
   end;
End;

Procedure Updateheader();
Begin
Gotoxy(1,6);Write('==================================================================');
Gotoxy(1,7);Write(format('| Address: %-39s | HashLib: %2s |',[myaddress,IntToStr(MyHashLib)]));
Gotoxy(1,8);Write(Format('| Block: %8s | Age: %3s | CPUs: %2s / %2s | Speed: %10s |',[IntToStr(CurrentBlock),IntToStr(CurrBlockAge),
                IntToStr(MyCPUCount),IntToStr(MaxCPU),HashrateToShow(CurrSpeed)]));
U_Headers := false;
End;

Procedure UpdateBlockAge();
Begin
GotoXy(26,8);Write(Format('%3s',[IntToStr(BlockAge)]));
GotoXy(55,8);Write(Format('%10s',[HashrateToShow(GetTotalHashes)]));
U_BlockAge := UTCTime;
End;

Procedure UpdateActivePool();
var
  counter : integer;
Begin
Textcolor(Green);
TextBackGround(White);
Gotoxy(3,12+(Activepool*2)); Write(Format('%0:-17s',[ArrSources[activepool].ip]));
Gotoxy(62,12+(Activepool*2)); Write(Format('%6s',[ArrSources[activepool].shares.ToString]));
Gotoxy(41,12+(Activepool*2)); Write(Format('%12s',[Int2Curr(ArrSources[activepool].balance)]));
Gotoxy(56,12+(Activepool*2)); Write(Format('%3s',[IntToStr(ArrSources[activepool].payinterval)]));
Textcolor(LightGray);
TextBackGround(Black);
U_ActivePool := false;
End;

Procedure PrintStatus(LText:String; LColor:integer);
Begin
Textcolor(LColor);
Gotoxy(1,24);ClrEOL;
Write(LText);
Textcolor(LightGray);
StatusMsg := '';
End;

Procedure ColorMsg(x,y:integer;LTexto:String;TexCol,BacCol:Integer);
Begin
Textcolor(TexCol);
TextBackGround(BacCOl);
GotoXy(x,y);write(LTexto);
Textcolor(LightGray);
TextBackGround(Black);
End;

Procedure Drawpools();
var
  ThisPool, ThisLine : string;
  PoolName, ThisMiners : string[20];
  Thisfee : integer;
  thisrate : int64;
  Counter : integer;
  DetectedPools : integer = 0;
  ThisBalance   : string;
  ThisPAyInterval : string;
  ThisShares      : string;
Begin
Gotoxy(1,9);Write('=====================================================================');
Gotoxy(1,10);Write(format('| %0:-17s | %6s | %6s | %12s | %3s | %6s |',['Pool','Miners','Fee','Balance','Pay','Shares']));
Gotoxy(1,11);Write('---------------------------------------------------------------------');
for counter :=0 to length(ArrSources)-1 do
    begin
    PoolName := Format('%0:-15s',[ArrSources[counter].ip]);
    ThisPool :=GetPoolInfo(ArrSources[counter].ip,ArrSources[counter].port);
    ThisMiners := Parameter(ThisPool,0);
    thisrate := StrToInt64Def(Parameter(ThisPool,1),0);
    thisfee := StrToIntDef(Parameter(ThisPool,2),0);
    ThisBalance := Int2Curr(ArrSources[counter].balance);
    ThisPayInterval := IntToStr(ArrSources[counter].payinterval);
    ThisShares      := IntToStr(ArrSources[counter].Shares);
    Gotoxy(1,12+(counter*2));Write(format('| %-17s | %6s | %6s | %12s | %3s | %6s |',[PoolName,ThisMiners,FormatFloat('0.00',ThisFee/100),ThisBalance,ThisPAyInterval,ThisShares]));
    Gotoxy(1,13+(counter*2));Write('---------------------------------------------------------------------');
    Inc(DetectedPools)
    end;
if DetectedPools = 0 then
   begin
   Gotoxy(1,12);
   Write('No pools listed');
   end;
End;

Procedure RunTest();
var
  CPUsToUse    : integer;
  LibToUse     : integer;
  TestStart, TestEnd, TestTime : Int64;
  LaunchThread : integer;
  CPUSpeed     : extended;
  ShowResult   : String;
Begin
ColorMsg(1,6,' Consominer2 tests',yellow,black);
writeln('');
Writeln('------------------------------------------------------------');
Writeln(Format('| CPUs  | Hashlib65  | Hashlib68  | Hashlib69  | Hashlib70  |',[]));
Writeln('------------------------------------------------------------');
For CPUsToUse := 1 to maxCPU do
   begin
   Write(Format('| %2s    |            |            |            |            |',[IntToStr(CPUsToUse)]));
   for LibToUse := 0 to 3 do
      begin
      if LibToUse = 0 then CurrHashLib := hl65;
      if LibToUse = 1 then CurrHashLib := hl68;
      if LibToUse = 2 then CurrHashLib := hl69;
      if LibToUse = 3 then CurrHashLib := hl70;
      ShowResult := Format('%10s',['Running ']);
      ColorMsg(11+(LibToUse*13),Wherey,ShowResult,black,red);
      TestStart := GetTickCount64;
      FinishMiners := false;
      SetOMT(CPUsToUse);
      for LaunchThread := 1 to CPUsToUse do
         begin
         MinerThread := TMinerThread.Create(true,LaunchThread);
         MinerThread.FreeOnTerminate:=true;
         MinerThread.Start;
         sleep(1);
         end;
      REPEAT
         sleep(1)
      UNTIL GetOMTValue = 0;
      TestEnd := GetTickCount64;
      TestTime := (TestEnd-TestStart);
      CPUSpeed := HashesForTest/(testtime/1000);
      ShowResult := Format('%11s',[FormatFloat('0.00',CPUSpeed*CPUsToUse)]);
      ColorMsg(11+(LibToUse*13),Wherey,ShowResult,green,black);
      end;
   writeLn();
   end;
Writeln('------------------------------------------------------------');
writeln('');
writeln('Test completed. Press enter to exit.');
End;

{$R *.res}

BEGIN
Randomize();
clrscr;
if not FileExists('consominer2.cfg') then CreateConfig();
if not FileExists('log.txt') then CreateLogFile();
MaxCPU:= {$IFDEF UNIX}GetSystemThreadCount{$ELSE}GetCPUCount{$ENDIF};
LoadConfig();
LoadSources();
Textcolor(white);
Writeln('    _____                         _                ___');
Writeln('   / ___/__  ___  ___ ___  __ _  (_)__  ___ ____  |_  |');
Writeln('  / /__/ _ \/ _ \(_-</ _ \/    \/ / _ \/ -_) __/ / __/ ');
Writeln('  \___/\___/_//_/___/\___/_/_/_/_/_//_/\__/_/   /____ ');
WriteLn();
Textcolor(green);
gotoxy(52,1);writeln('___');
gotoxy(51,2);writeln('|_  |');
gotoxy(50,3);writeln('/ __/');
gotoxy(49,4);writeln('/____');
Textcolor(LightGray);
ColorMsg(57,3,'V'+Appver,yellow,black);
ColorMsg(57,4,'PoPW',red,black);
if MyRunTest then
   begin
   RunTest();
   readln();
   exit;
   end;
if Myhashlib = 0 then CurrHashLib := hl65;
if Myhashlib = 1 then CurrHashLib := hl68;
if Myhashlib = 2 then CurrHashLib := hl69;
if Myhashlib = 3 then CurrHashLib := hl70;
Updateheader;
Drawpools;
SetStatusMsg('Consominer2 started!', green);
ActivePool := RandonStartPool;
//ToLog('Starting sesion');
MainThread := TMainThread.Create(true);
MainThread.FreeOnTerminate:=true;
MainThread.Start;
Repeat
   if StatusMsg <> '' then PrintStatus(StatusMsg,StatusColor);
   if U_Headers then UpdateHeader;
   if U_ActivePool then UpdateActivePool;
   if U_BlockAge <> UTCtime then UpdateBlockAge;
   if U_ClearPoolsScreen then ClearPoolsScreen;
   Sleep(1);
until FinishProgram;

END.

