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
  ThisChar      : Char;


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
  counter  : integer;
  PoolName : string;
Begin
For counter := 0 to length(ArrSources)-1 do
   begin
   PoolName := Format('%0:-17s',[ArrSources[counter].ip]);
   if length(PoolName)>16 then Setlength(PoolName,16);
   Gotoxy(3,13+(counter)); Write(Format('%0:-17s',[PoolName]));
   Gotoxy(62,13+(counter)); Write(Format('%6s',[ArrSources[counter].shares.ToString]));
   Gotoxy(41,13+(counter)); Write(Format('%12s',[Int2Curr(ArrSources[counter].balance)]));
   Gotoxy(56,13+(counter)); Write(Format('%3s',[IntToStr(ArrSources[counter].payinterval)]));
   end;
U_ClearPoolsScreen := false;
End;

Procedure LaunchMiners();
var
  SourceResult : integer;
  Counter      : integer;
Begin
Setstatusmsg('Syncing...',yellow);
Repeat
   SourceResult := CheckSource;
   If SourceResult=0 then sleep(1000);
until SourceResult>0;
if SourceResult=2 then exit;
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
While ((not terminated) or (FinishProgram)) do
   begin
   CheckLog;
   if SolutionsLength > 0 then
      SendPoolShare(GetSolution);
   if ( (blockage>=585) and (Not WaitingNextBlock) ) then
      begin
      FinishMiners     := true;
      WaitingNextBlock := true;
      U_WaitNextBlock  := true;
      ToLog('Started waiting next block');
      end;
   if ( (blockAge>=10) and (blockage<585) ) then
      begin
      if WaitingNextBlock then
         begin
         WaitingNextBlock := false;
         ClearAllPools();
         U_ClearPoolsScreen := true;
         BlockCompleted := false;
         ActivePool := RandonStartPool;
         U_WaitNextBlock := true;
         end
      else
         begin
         if AllFilled then
            begin
            if not BlockCompleted then
               begin
               BlockCompleted := true;
               Setstatusmsg('All shares completed for this block',green);
               ToLog('All filled on block '+CurrentBlock.ToString);
               end;
            end
         else
            begin
            if GetOMTValue =0 then
               LaunchMiners
            end;
         end
      end;
   sleep(10);
   end;
End;

Procedure ColorMsg(x,y:integer;LTexto:String;TexCol,BacCol:Integer);
Begin
Textcolor(TexCol);
TextBackGround(BacCOl);
GotoXy(x,y);write(LTexto);
Textcolor(LightGray);
TextBackGround(Black);
End;

Procedure Updateheader();
Begin
Gotoxy(1,6);Write('==================================================================');
Gotoxy(1,7);Write(format('| Address: %-37s %15s |',[myaddress,Int2Curr(MyAddressBalance)]));
Gotoxy(1,8);Write(Format('| Block: %8s | Age: %3s | CPUs: %2s / %2s | Speed: %10s |',[IntToStr(CurrentBlock),IntToStr(CurrBlockAge),
                IntToStr(MyCPUCount),IntToStr(MaxCPU),HashrateToShow(CurrSpeed)]));
Gotoxy(1,9);Write(Format('| Uptime: %8s | Payments: %3s | Received: %12s | %2s |',[Uptime(MinerStartUTC),IntToStr(ReceivedPayments),Int2curr(ReceivedNoso),IntToStr(MyHashLib)]));
if MyDonation>0 then ColorMsg(2,6,' '+MyDonation.ToString+' % ',black, green);
U_Headers := false;
End;

Procedure UpdateBlockAge();
Begin
GotoXy(11,9);Write(Format('%8s',[Uptime(MinerStartUTC)]));
GotoXy(55,8);Write(Format('%10s',[HashrateToShow(GetTotalHashes)]));
GotoXy(26,8);Write(Format('%3s',[IntToStr(BlockAge)]));
GotoXy(1,25);
U_BlockAge := UTCTime;
End;

Procedure UpdateActivePool();
var
  counter  : integer;
  PoolName : string;
Begin
Textcolor(white);
TextBackGround(blue);
PoolName := Format('%0:-17s',[ArrSources[activepool].ip]);
if length(PoolName)>16 then Setlength(PoolName,16);
Gotoxy(3,13+(Activepool)); Write(Format('%0:-17s',[PoolName]));
Gotoxy(62,13+(Activepool)); Write(Format('%6s',[ArrSources[activepool].shares.ToString]));
Gotoxy(41,13+(Activepool)); Write(Format('%12s',[Int2Curr(ArrSources[activepool].balance)]));
Gotoxy(56,13+(Activepool)); Write(Format('%3s',[IntToStr(ArrSources[activepool].payinterval)]));
Textcolor(LightGray);
TextBackGround(Black);
Gotoxy(23,13+(Activepool)); Write(Format('%6s',[IntToStr(ArrSources[activepool].miners)]));
Gotoxy(32,13+(Activepool)); Write(Format('%6s',[FormatFloat('0.00',ArrSources[activepool].fee/100)]));
U_ActivePool := false;
End;

Procedure PrintStatus(LText:String; LColor:integer);
Begin
Textcolor(LColor);
Gotoxy(1,24);ClrEOL;
if WaitingNextBlock then LText := '';
Write(LText);
Textcolor(LightGray);
StatusMsg := '';
End;

Procedure UpdateTotalPending();
Begin
TextBackGround(Green);
TextColor(white);
Gotoxy(41,18); Write(Format('%12s',[Int2Curr(GetTotalPending)]));
Textcolor(LightGray);
TextBackGround(Black);
U_TotalPending := false;
end;

Procedure UpdateNextBlockMessage();
Begin
Gotoxy(1,19);ClrEOL;
Gotoxy(1,20);ClrEOL;
Gotoxy(1,21);ClrEOL;
Gotoxy(1,22);ClrEOL;
Gotoxy(1,23);ClrEOL;
TextBackGround(Red);
TextColor(white);
if WaitingNextBlock then
   Begin
   Gotoxy(26,19);Write(' __        __    _ _    ');
   Gotoxy(26,20);Write(' \ \      / /_ _(_) |_  ');
   Gotoxy(26,21);Write('  \ \ /\ / / _` | | __| ');
   Gotoxy(26,22);Write('   \ V  V / (_| | | |_  ');
   Gotoxy(26,22);Write('    \_/\_/ \__,_|_|\__| ');
   Gotoxy(26,23);Write('                        ');
   SetStatusmsg(' ',white);
   end;
Textcolor(LightGray);
TextBackGround(Black);
U_WaitNextBlock := false;
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
Gotoxy(1,10);Write('=====================================================================');
Gotoxy(1,11);Write(format('| %0:-17s | %6s | %6s | %12s | %3s | %6s |',['Pool','Miners','Fee','Balance','Pay','Shares']));
Gotoxy(1,12);Write('---------------------------------------------------------------------');
for counter :=0 to length(ArrSources)-1 do
    begin
    PoolName := Format('%0:-17s',[ArrSources[counter].ip]);
    if length(PoolName)>16 then Setlength(PoolName,16);
    ThisPool := GetPoolInfo(ArrSources[counter].ip,ArrSources[counter].port);
    ThisMiners := Parameter(ThisPool,0);
    thisrate := StrToInt64Def(Parameter(ThisPool,1),0);
    thisfee := StrToIntDef(Parameter(ThisPool,2),0);
    ThisBalance := Int2Curr(ArrSources[counter].balance);
    ThisPayInterval := IntToStr(ArrSources[counter].payinterval);
    ThisShares      := IntToStr(ArrSources[counter].Shares);
    Gotoxy(1,13+(counter));Write(format('| %-17s | %6s | %6s | %12s | %3s | %6s |',[PoolName,ThisMiners,FormatFloat('0.00',ThisFee/100),ThisBalance,ThisPAyInterval,ThisShares]));
    Inc(DetectedPools)
    end;
Gotoxy(1,13+DetectedPools);Write('---------------------------------------------------------------------');
if DetectedPools = 0 then
   begin
   Gotoxy(1,12);
   Write('No pools listed');
   end;
End;

Procedure UpdateNewPayment();
Begin
TextBackGround(Green);
TextColor(white);
Gotoxy(37,6); Write(Format(' New payment: %12s ',[Int2Curr(U_NewPayment)]));
Textcolor(LightGray);
TextBackGround(Black);
Gotoxy(32,9); Write(Format('%3s',[IntToStr(ReceivedPayments)]));
Gotoxy(46,9); Write(Format('%12s',[Int2Curr(ReceivedNoso)]));
U_NewPayment := 0;
End;

Procedure UpdateNosoBalance();
Begin
Gotoxy(50,7);Write(format('%15s',[Int2Curr(MyAddressBalance)]));
U_AddressNosoBalance := false;
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
if not FileExists('payments.dat') then CreatePaymentsFile();
if not FileExists('payments.txt') then CreateRAWPaymentsFile();
MaxCPU:= {$IFDEF UNIX}GetSystemThreadCount{$ELSE}GetCPUCount{$ENDIF};
LoadConfig();
CreateConfig();
LoadSources();
LoadPreviousPayments;
Textcolor(white);
Writeln('    _____                         _');
Writeln('   / ___/__  ___  ___ ___  __ _  (_)__  ___ ____');
Writeln('  / /__/ _ \/ _ \(_-</ _ \/    \/ / _ \/ -_) __/');
Writeln('  \___/\___/_//_/___/\___/_/_/_/_/_//_/\__/_/');
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
MinerStartUTC := UTCTime;
if Myhashlib = 65 then CurrHashLib := hl65
else if Myhashlib = 68 then CurrHashLib := hl68
else if Myhashlib = 69 then CurrHashLib := hl69
else CurrHashLib := hl70;
Updateheader;
ColorMsg(1,25,' Alt+X for exit ',Black,LightGray);
Drawpools;
SetStatusMsg('Consominer2 started!', green);
ActivePool := RandonStartPool;
//ToLog('Starting sesion');
MainThread := TMainThread.Create(true);
MainThread.FreeOnTerminate:=true;
MainThread.Start;
Repeat
   Repeat
   if StatusMsg <> '' then PrintStatus(StatusMsg,StatusColor);
   if U_Headers then UpdateHeader;
   if U_ActivePool then UpdateActivePool;
   if U_ClearPoolsScreen then ClearPoolsScreen;
   if U_WaitNextBlock then UpdateNextBlockMessage;
   if U_AddressNosoBalance then UpdateNosoBalance;
   if U_TotalPending then UpdateTotalPEnding;
   if U_NewPayment>0 then UpdateNewPayment;
   if U_BlockAge <> UTCtime then UpdateBlockAge;
   Sleep(1);
   until KeyPressed;
   ThisChar := Readkey;
   if ThisChar = #0 then
      begin
      ThisChar:=Readkey;
      if ThisChar=#45 then // alt+x
         begin
         FinishMiners := true;
         FinishProgram := true;
         Repeat
            sleep(1);
         until GetOMTValue = 0;
         end
      end;
until FinishProgram;
clrscr;
Writeln('Consominer2 closed!');
END.

