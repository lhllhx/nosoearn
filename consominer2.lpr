program consominer2;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads, UTF8process,
  {$ENDIF}
  Classes, sysutils, consominer2unit, nosodig.crypto,NosoDig.Crypto68b, NosoDig.Crypto68, NosoDig.Crypto65,
  functions, strutils, Noso_TUI;

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
  counter  : integer;
  PoolName : string;
Begin
For counter := 0 to length(ArrSources)-1 do
   begin
   PoolName := Format('%0:-17s',[ArrSources[counter].ip]);
   if length(PoolName)>16 then Setlength(PoolName,16);
   //Gotoxy(3,13+(counter)); Write(Format('%0:-17s',[PoolName]));
   TextOut(3,13+counter,Format('%0:-17s',[PoolName]),Lightgray,black);
   //Gotoxy(62,13+(counter)); Write(Format('%6s',[ArrSources[counter].shares.ToString]));
   TextOut(62,13+counter,Format('%6s',[ArrSources[counter].shares.ToString]),Lightgray,black);
   //Gotoxy(41,13+(counter)); Write(Format('%12s',[Int2Curr(ArrSources[counter].balance)]));
   TextOut(41,13+counter,Format('%12s',[Int2Curr(ArrSources[counter].balance)]),Lightgray,black);
   //Gotoxy(56,13+(counter)); Write(Format('%3s',[IntToStr(ArrSources[counter].payinterval)]));
   TextOut(56,13+counter,Format('%3s',[IntToStr(ArrSources[counter].payinterval)]),Lightgray,black);
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
While not FinishProgram do
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
MAinThreadIsFinished := true;
End;

Procedure Updateheader();
Begin
//Gotoxy(1,6);Write('==================================================================');
//Gotoxy(1,7);Write(format('| Address: %-37s %15s |',[myaddress,Int2Curr(MyAddressBalance)]));
TextOut(2,7,format(' Address: %-37s %15s ',[myaddress,Int2Curr(MyAddressBalance)]),lightgray,black);
//Gotoxy(1,8);Write(Format('| Block: %8s | Age: %3s | CPUs: %2s / %2s | Speed: %10s |',[IntToStr(CurrentBlock),IntToStr(CurrBlockAge),
//                IntToStr(MyCPUCount),IntToStr(MaxCPU),HashrateToShow(CurrSpeed)]));
TextOut(2,8,Format(' Block: %8s | Age: %3s | CPUs: %2s / %2s | Speed: %10s |',[IntToStr(CurrentBlock),IntToStr(CurrBlockAge),
                  IntToStr(MyCPUCount),IntToStr(MaxCPU),HashrateToShow(CurrSpeed)]),lightgray,black);
//Gotoxy(1,9);Write(Format('| Uptime: %8s | Payments: %3s | Received: %12s | %2s |',[Uptime(MinerStartUTC),IntToStr(ReceivedPayments),Int2curr(ReceivedNoso),IntToStr(MyHashLib)]));
TextOut(2,9,Format(' Uptime: %8s | Payments: %3s | Received: %12s | %2s |',[Uptime(MinerStartUTC),IntToStr(ReceivedPayments),Int2curr(ReceivedNoso),IntToStr(MyHashLib)]),lightgray,black);
DWindow(1,6,66,10,'',lightgray,black);
TextOut(1,10,LChar[10],lightgray,black);
TextOut(66,10,LChar[8],lightgray,black);
if MyDonation>0 then DLabel(2,6,' '+MyDonation.ToString+' % ',8,AlCenter,black,green);//XYMsg(2,6,' '+MyDonation.ToString+' % ',black, green);
U_Headers := false;
End;

Procedure UpdateBlockAge();
Begin
//GotoXy(11,9);Write(Format('%8s',[Uptime(MinerStartUTC)]));
TextOut(11,9,Format('%8s',[Uptime(MinerStartUTC)]),Lightgray,black);
//GotoXy(55,8);Write(Format('%10s',[HashrateToShow(GetTotalHashes)]));
TextOut(55,8,Format('%10s',[HashrateToShow(GetTotalHashes)]),Lightgray,black);
//GotoXy(26,8);Write(Format('%3s',[IntToStr(BlockAge)]));
TextOut(26,8,Format('%3s',[IntToStr(BlockAge)]),Lightgray,black);
GotoXy(1,25);
U_BlockAge := UTCTime;
End;

Procedure UpdateActivePool();
var
  counter  : integer;
  PoolName : string;
Begin
PoolName := Format('%0:-17s',[ArrSources[activepool].ip]);
if length(PoolName)>16 then Setlength(PoolName,16);
//Gotoxy(3,13+(Activepool)); Write(Format('%0:-17s',[PoolName]));
DLabel(3,13+ActivePool,PoolName,16,AlLeft,White,Blue);
//Gotoxy(62,13+(Activepool)); Write(Format('%6s',[ArrSources[activepool].shares.ToString]));
DLabel(62,13+Activepool,ArrSources[activepool].shares.ToString,6,AlRight,white,blue);
//Gotoxy(41,13+(Activepool)); Write(Format('%12s',[Int2Curr(ArrSources[activepool].balance)]));
DLabel(41,13+Activepool,Int2Curr(ArrSources[activepool].balance),12,AlRight,white,blue);
//Gotoxy(56,13+(Activepool)); Write(Format('%3s',[IntToStr(ArrSources[activepool].payinterval)]));
DLabel(56,13+Activepool,IntToStr(ArrSources[activepool].payinterval),3,AlRight,white,blue);
//Gotoxy(23,13+(Activepool)); Write(Format('%6s',[IntToStr(ArrSources[activepool].miners)]));
DLabel(23,13+Activepool,IntToStr(ArrSources[activepool].miners),6,AlRight,lightGray,Black);
//Gotoxy(32,13+(Activepool)); Write(Format('%6s',[FormatFloat('0.00',ArrSources[activepool].fee/100)]));
DLabel(32,13+Activepool,FormatFloat('0.00',ArrSources[activepool].fee/100),6,AlRight,lightGray,Black);
U_ActivePool := false;
End;

Procedure PrintStatus(LText:String; LColor:integer);
Begin
if WaitingNextBlock then LText := '';
DLabel(1,24,LText,70,AlCenter,LColor,Black);
StatusMsg := '';
End;

Procedure UpdateTotalPending();
Begin
//Gotoxy(41,13+length(ArrSources)); Write(Format('%12s',[Int2Curr(GetTotalPending)]));
DLabel(41,13+length(ArrSources),Int2Curr(GetTotalPending),12,AlRight,White,green);
U_TotalPending := false;
end;

Procedure UpdateNextBlockMessage();
Begin
{
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
}
DLabel(10,20,'',40,AlCenter,lightGray,black);
if WaitingNextBlock then
   begin
   DLabel(10,20,'Waiting next block',40,AlCenter,White,red);
   SetStatusmsg(' ',white);
   end;
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
//Gotoxy(1,10);Write('=====================================================================');
//Gotoxy(1,11);Write(format('| %0:-17s | %6s | %6s | %12s | %3s | %6s |',['Pool','Miners','Fee','Balance','Pay','Shares']));
//Gotoxy(1,12);Write('---------------------------------------------------------------------');
DWindow(1,10,69,12,'',lightgray,black);
TextOut(1,12,LChar[10],lightgray,black);
TextOut(69,12,LChar[6],lightgray,black);
TextOut(2,11,format(' %0:-17s | %6s | %6s | %12s | %3s | %6s ',['Pool','Miners','Fee','Balance','Pay','Shares']),yellow,black);
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
    //Gotoxy(1,13+(counter));Write(format('| %-17s | %6s | %6s | %12s | %3s | %6s |',[PoolName,ThisMiners,FormatFloat('0.00',ThisFee/100),ThisBalance,ThisPAyInterval,ThisShares]));
    TextOut(1,13+counter,format(Lchar[5]+' %-17s '+LChar[5]+' %6s '+LChar[5]+' %6s '+LChar[5]+' %12s '+LChar[5]+' %3s '+LChar[5]+' %6s '+LChar[5],[PoolName,ThisMiners,FormatFloat('0.00',ThisFee/100),ThisBalance,ThisPAyInterval,ThisShares]),lightgray,black);
    Inc(DetectedPools)
    end;
//Gotoxy(1,13+DetectedPools);Write('---------------------------------------------------------------------');
HorizLine(13+DetectedPools,1,69,lightgray,black);
TextOut(1,13+DetectedPools,LChar[9],white,black);
TextOut(69,13+DetectedPools,LChar[7],white,black);
if DetectedPools = 0 then
   begin
   Gotoxy(1,12);
   Write('No pools listed');
   end;
End;

Procedure UpdateNewPayment();
Begin
//TextBackGround(Green);
//TextColor(white);
//Gotoxy(37,6); Write(Format(' New payment: %12s ',[Int2Curr(U_NewPayment)]));
DLabel(37,6,Format(' New payment: %12s ',[Int2Curr(U_NewPayment)]),30,AlCenter,white,Green);
//Textcolor(LightGray);
//TextBackGround(Black);
Gotoxy(32,9); Write(Format('%3s',[IntToStr(ReceivedPayments)]));
Gotoxy(46,9); Write(Format('%12s',[Int2Curr(ReceivedNoso)]));
U_NewPayment := 0;
End;

Procedure UpdateNosoBalance();
Begin
Gotoxy(50,7);Write(format('%15s',[Int2Curr(MyAddressBalance)]));
U_AddressNosoBalance := false;
End;

Function RunConfig:integer;
var
  ExitCode  : integer;
  IsDone    : boolean = false;
  ActiveRow : integer = 9;
  GetEdit   : TEditData;
  NavKey    : integer;

   procedure showData();
   Begin
   DLabel(22,9,MyAddress,38,AlLeft,lightgray,black);
   DLabel(22,10,MyCPUCount.ToString,38,AlLeft,lightgray,black);
   DLabel(22,11,MyHAshlib.ToString,38,AlLeft,lightgray,black);
   DLabel(22,12,MyMaxShares.ToString,38,AlLeft,lightgray,black);
   DLabel(22,13,MyDonation.ToString,38,AlLeft,lightgray,black);
   Dlabel(2,15,'Save & Run',17,alCenter,black,brown);
   Dlabel(22,15,'Save & Exit',17,alCenter,black,brown);
   Dlabel(42,15,'Exit',17,alCenter,black,brown);
   End;

Begin
Result := 0;
BKColor(black);
cls(1,7,80,25);
DWindow(1,8,60,14,'',white,black);
VertLine(20,8,14,white,black,true);
TextOut(3,9,'Noso address',yellow,black);
TextOut(3,10,Format('CPUs [%d]',[MaxCPU]),yellow,black);
TextOut(3,11,'Hashlib',yellow,black);
TextOut(3,12,'Block shares',yellow,black);
TextOut(3,13,'Donate %',yellow,black);
showData;
ClrLine(25);
DLabel(1,25,#24' '#25' Navigate',15,AlCenter,white,green);
DLabel(17,25,'ENTER Select',15,AlCenter,white,green);
Repeat
   If ActiveRow > 16 then ActiveRow := 9;
   If ActiveRow < 9 then ActiveRow := 16;
   if ActiveRow=9 then
      begin
      GetEdit := ReadEditScreen(22,ActiveRow,MyAddress,38);
      if GetEdit.OutKey = 80 then Inc(ActiveRow);
      if GetEdit.OutKey = 72 then Dec(ActiveRow);
      MyAddress := GetEdit.OutString;
      showData;
      end
   else if ActiveRow = 10 then
      begin
      GetEdit := ReadEditScreen(22,ActiveRow,MyCPUCount.ToString,38);
      if GetEdit.OutKey = 80 then Inc(ActiveRow);
      if GetEdit.OutKey = 72 then Dec(ActiveRow);
      MyCPUCount := StrToIntDef(GetEdit.OutString,MyCPUCount);
      showData;
      end
   else if ActiveRow = 11 then
      begin
      GetEdit := ReadEditScreen(22,ActiveRow,MyHAshlib.ToString,38);
      if GetEdit.OutKey = 80 then Inc(ActiveRow);
      if GetEdit.OutKey = 72 then Dec(ActiveRow);
      MyHAshlib := StrToIntDef(GetEdit.OutString,MyHAshlib);
      showData;
      end
   else if ActiveRow = 12 then
      begin
      GetEdit := ReadEditScreen(22,ActiveRow,MyMaxShares.ToString,38);
      if GetEdit.OutKey = 80 then Inc(ActiveRow);
      if GetEdit.OutKey = 72 then Dec(ActiveRow);
      MyMaxShares := StrToIntDef(GetEdit.OutString,MyMaxShares);
      showData;
      end
   else if ActiveRow = 13 then
      begin
      GetEdit := ReadEditScreen(22,ActiveRow,MyDonation.ToString,38);
      if GetEdit.OutKey = 80 then Inc(ActiveRow);
      if GetEdit.OutKey = 72 then Dec(ActiveRow);
      MyDonation := StrToIntDef(GetEdit.OutString,MyDonation);
      showData;
      end
   else if ActiveRow = 14 then
      begin
      Dlabel(2,15,'Save & Run',17,alCenter,white,Green);
      GotoXy(2,15);
      NavKey := ReadNavigationKey;
      if Navkey = 77 then ActiveRow := 15;
      if Navkey = 72 then ActiveRow := 13;
      if Navkey = 80 then ActiveRow := 9;
      if navkey = 13 then
         begin
         MyRunTest := false;
         Createconfig();
         result:=1;
         IsDone := true;
         end;
      ShowData;
      end
   else if ActiveRow = 15 then
      begin
      Dlabel(22,15,'Save & Exit',17,alCenter,white,green);
      GotoXy(22,15);
      NavKey := ReadNavigationKey;
      if Navkey = 77 then ActiveRow := 16;
      if Navkey = 75 then ActiveRow := 14;
      if Navkey = 72 then ActiveRow := 13;
      if Navkey = 80 then ActiveRow := 9;
      if navkey = 13 then
         begin
         Createconfig();
         result:=2;
         IsDone := true;
         end;
      ShowData;
      end
   else if ActiveRow = 16 then
      begin
      Dlabel(42,15,'Exit',17,alCenter,white,green);
      GotoXy(42,15);
      NavKey := ReadNavigationKey;
      if Navkey = 75 then ActiveRow := 15;
      if Navkey = 72 then ActiveRow := 13;
      if Navkey = 80 then ActiveRow := 9;
      if navkey = 13 then
         begin
         result:=3;
         IsDone := true;
         end;
      ShowData;
      end;
until IsDone ;
End;

Function RunTest():boolean;
var
  CPUsToUse    : integer;
  LibToUse     : integer;
  TestStart, TestEnd, TestTime : Int64;
  LaunchThread : integer;
  CPUSpeed     : extended;
  ShowResult   : String;
  ExitCode     : integer;
Begin
DLabel(1,6,'Consominer2 configuration',60,AlCenter,yellow,Green);
TextOut(1,25,' ENTER to run test, ESC to skip it ',White,green);
GotoXy(1,25);
Repeat
   sleep(1);
   ExitCode := KeyPressedCode;
until  (ExitCode = 283) or (ExitCode=7181);
if exitCode = 7181 then
   begin
   ClrLine(25);
   TextOut(1,25,' Running speed test. Please wait ',White,green);
   DWindow(1,8,61,10,'',white,black);
   //Writeln('------------------------------------------------------------');
   //Writeln(Format('| CPUs  | Hashlib65  | Hashlib68  | Hashlib69  | Hashlib70  |',[]));
   //Writeln('-------------------------------------------------------------');
   DLabel(2,9,Format(' CPUs  | Hashlib65  | Hashlib68  | Hashlib69  | Hashlib70',[]),59,AlLeft,yellow,black);
   TextOut(1,10,LChar[10],white,black);
   TextOut(61,10,LChar[6],white,black);
   For CPUsToUse := 1 to maxCPU do
      begin
      //Write(Format('| %2s    |            |            |            |            |',[IntToStr(CPUsToUse)]));
      Dlabel(1,10+CPUsToUse,Format(LChar[5]+' %2s    '+LChar[5]+'            '+LChar[5]+'            '+LChar[5]+'            '+LChar[5]+'            '+LChar[5],[IntToStr(CPUsToUse)]),61,AlLEft,lightGray,black);
      for LibToUse := 0 to 3 do
         begin
         if LibToUse = 0 then CurrHashLib := hl65;
         if LibToUse = 1 then CurrHashLib := hl68;
         if LibToUse = 2 then CurrHashLib := hl69;
         if LibToUse = 3 then CurrHashLib := hl70;
         ShowResult := Format('%10s',['Running ']);
         //XYMsg(11+(LibToUse*13),Wherey,ShowResult,black,red);
         DLabel(11+(LibToUse*13),10+CPUsToUse,ShowResult,10,AlRight,black, red);
         GotoXy(11+(LibToUse*13),10+CPUsToUse);
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
         //XYmsg(11+(LibToUse*13),Wherey,ShowResult,green,black);
         DLabel(11+(LibToUse*13),10+CPUsToUse,ShowResult,10,AlRight,green, black);
         end;
      //writeLn();
      end;
   //Writeln('------------------------------------------------------------');
   //TextOut(1,11+CpusToUse,'------------------------------------------------------------',white,black);
   HorizLine(11+CpusToUse,1,61,white,black);
   TextOut(1,11+cpustouse,LChar[9],white,black);
   TextOut(61,11+cpustouse,LChar[7],white,black);
   //writeln('');
   ClrLine(25);
   TextOut(1,25,' Test completed. Press [C] to configure, Alt-X to exit. ',White,green);
   end
else
   begin
   ClrLine(25);
   TextOut(1,25,' Press [C] to configure, Alt-X to exit. ',White,green);
   end;
GotoXy(1,25);
Repeat
   sleep(1);
   ExitCode := KeyPressedCode;
until  (ExitCode = 11520) or (ExitCode=11843) or (ExitCode=11875);
if ExitCode = 11520 then result := true
else result := false;
End;

BEGIN
Randomize();
cls;
if not FileExists('consominer2.cfg') then CreateConfig();
if not FileExists('log.txt') then CreateLogFile();
if not FileExists('payments.dat') then CreatePaymentsFile();
if not FileExists('payments.txt') then CreateRAWPaymentsFile();
MaxCPU:= {$IFDEF UNIX}GetSystemThreadCount{$ELSE}GetCPUCount{$ENDIF};
LoadConfig();
CreateConfig();
LoadSources();
LoadPreviousPayments;
//Textcolor(white);
//GotoXy(1,1);
//Writeln('    _____                         _');
//Writeln('   / ___/__  ___  ___ ___  __ _  (_)__  ___ ____');
//Writeln('  / /__/ _ \/ _ \(_-</ _ \/    \/ / _ \/ -_) __/');
//Writeln('  \___/\___/_//_/___/\___/_/_/_/_/_//_/\__/_/');
//WriteLn();
TextOut(1,1,'    _____                         _',white,black);
TextOut(1,2,'   / ___/__  ___  ___ ___  __ _  (_)__  ___ ____',white,black);
TextOut(1,3,'  / /__/ _ \/ _ \(_-</ _ \/    \/ / _ \/ -_) __/',white,black);
TextOut(1,4,'  \___/\___/_//_/___/\___/_/_/_/_/_//_/\__/_/',white,black);
//Textcolor(green);
//gotoxy(52,1);writeln('___');
//gotoxy(51,2);writeln('|_  |');
//gotoxy(50,3);writeln('/ __/');
//gotoxy(49,4);writeln('/____');
TextOut(52,1,'___',green,black);
TextOut(51,2,'|_  |',green,black);
TextOut(50,3,'/ __/',green,black);
TextOut(49,4,'/____',green,black);
//Textcolor(LightGray);
//XYMsg(57,3,'V'+Appver,yellow,black);
DLabel(57,3,'V'+Appver,4,AlLeft,yellow,black);
//XYMsg(57,4,'PoPW',red,black);
DLabel(57,4,'PoPw',4,AlLeft,red,black);
if MyRunTest then
   begin
   if RunTest then exit
   else
      begin
      if Runconfig>1 then exit
      else cls(1,6,80,25);
      end;
   end;
MinerStartUTC := UTCTime;
if Myhashlib = 65 then CurrHashLib := hl65
else if Myhashlib = 68 then CurrHashLib := hl68
else if Myhashlib = 69 then CurrHashLib := hl69
else CurrHashLib := hl70;
Updateheader;
//XYMsg(1,25,' Alt+X for exit ',Black,LightGray);
DLabel(1,25,' Alt+X for exit ',16,AlLeft,black,LightGray);
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
   until KeyPressedCode = 11520;
FinishMiners := true;
FinishProgram := true;
Repeat
   sleep(1);
until(GetOMTValue = 0);
until FinishProgram;
cls;
GotoXy(1,1);
Writeln('Consominer2 miners threads closed');
Writeln('Closing MainThread...');
Repeat
   sleep(1);
until(MAinThreadIsFinished);
sleep(100);
Writeln('Done. Bye!');
END.

