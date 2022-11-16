unit consominer2unit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IdTCPClient, IdGlobal, strutils, functions;

Type

   TSourcesData= packed record
     ip         : string;
     port       : integer;
     Shares     : integer;
     filled     : boolean;
     balance    : int64;
     payinterval: integer;
     FailedTrys : integer;
     end;

   TSolution = Packed record
     Hash   : string;
     Target : string;
     Diff   : string;
     end;

   {Pool payment info}
   TPayment = packed record
     block    : integer;
     ammount  : int64;
     OrderID  : string[60];
   end;

Procedure LoadSources();
Function GetPoolInfo(PoolIp:String;PoolPort:integer):String;
Function GetPoolSource(Ip:String;Port:integer):String;
Procedure SendPoolShare(Data:TSolution);
Function RandonStartPool():integer;
Function AllFilled():Boolean;
Procedure FillAllPools();
Procedure ClearAllPools();
Procedure SaveSource(LSource:TSourcesData);
Procedure SetStatusMsg(Lmessage:string;Lcolor:integer);
// Disk access
Procedure CreateConfig();
Procedure LoadConfig();
Function CheckSource():integer;
// Log manage
Procedure CreateLogFile();
Procedure Tolog(LLine:String);
Procedure CheckLog();

//*************
Procedure AddSolution(Data:TSolution);
Function SolutionsLength():Integer;
function GetSolution():TSolution;
Procedure ClearSolutions();
Procedure AddIntervalHashes(hashes:int64);
function GetTotalHashes : integer;
Procedure ResetIntervalHashes();
Procedure SetOMT(value:integer);
Procedure DecreaseOMT();
Function GetOMTValue():Integer;

Const
  AppVer = '1.2';
  HasheableChars = '!"#$%&'#39')*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~';

var
  ArrSources    : Array of TSourcesData;
  SourcesStr    : string = 'nosofish.xyz:8082 20.199.50.27:8082 144.24.45.44:8082 159.196.1.198:8082 pool.rukzuk.xyz:8082';
  ArrLogLines   : array of string;
  FinishProgram : boolean = false;
  MAXCPU        : integer = 0;
  CurrentBlock  : integer = 0;
  CurrSpeed     : integer = 0;
  CurrBlockAge  : integer = 0;
  ActivePool    : integer = 0;
  StatusMsg     : string = '';
  StatusColor   : integer;
  TimeOffSet    : integer = 0;
  // Files vars
  FileConfig    : Textfile;
  FileLog       : Textfile;
  // USer config
  MyAddress            : string;
  MyCPUCount,MyHAshlib : integer;
  MyRunTest            : boolean  = false;
  MyMaxShares          : integer = 5;
  // Miner Variables
  ArrHashLibs           : array[0..3] of integer;
  MAINPREFIX            : string = '';
  MinimunTargetDiff     : string = '00000';
  TargetHash            : string = '00000000000000000000000000000000';
  FinishMiners          : boolean = false;
  HashesForTest         : integer = 100000;
  ArrSolutions             : Array of TSolution;
  ThreadsIntervalHashes : integer = 0;
  OpenMinerThreads      : integer = 0;
  LastSpeedCounter      : int64 = 100000000;
    PoolMinningAddress  : string = '';
    WaitingNextBlock    : boolean = false;
    BlockCompleted      : boolean = false;
    WrongThisPool       : Integer = 0;
  // Update screen
  U_Headers          : boolean = false;
  U_BlockAge         : int64 = 0;
  U_ActivePool       : boolean = false;
  U_ClearPoolsScreen : boolean = false;
  U_WaitNextBlock    : boolean = false;
  // Crititical sections
  CS_Log          : TRTLCriticalSection;
  CS_ArrSources   : TRTLCriticalSection;
  CS_Solutions    : TRTLCriticalSection;
  CS_Interval     : TRTLCriticalSection;
  CS_MinerThreads : TRTLCriticalSection;

implementation



Function GetPoolInfo(PoolIp:String;PoolPort:integer):String;
var
  TCPClient : TidTCPClient;
  ResultLine : String = '';
Begin
Result := 'ERROR';
ResultLine := '';
TCPClient := TidTCPClient.Create(nil);
TCPclient.Host:=PoolIp;
TCPclient.Port:=PoolPort;
TCPclient.ConnectTimeout:= 3000;
TCPclient.ReadTimeout:=3000;
TRY
TCPclient.Connect;
TCPclient.IOHandler.WriteLn('POOLINFO');
ResultLine := TCPclient.IOHandler.ReadLn();
TCPclient.Disconnect();
EXCEPT on E:Exception do
   begin
   ResultLine := '';
   end;
END{try};
TCPClient.Free;
if ResultLine <> '' then Result := ResultLine;
End;

Function GetPoolSource(Ip:String;Port:integer):String;
var
  TCPClient : TidTCPClient;
  ResultLine : String = '';
Begin
Result := 'ERROR';
ResultLine := '';
TCPClient := TidTCPClient.Create(nil);
TCPclient.Host:=IP;
TCPclient.Port:=Port;
TCPclient.ConnectTimeout:= 3000;
TCPclient.ReadTimeout:=3000;
TRY
TCPclient.Connect;
TCPclient.IOHandler.WriteLn('SOURCE '+MyAddress+' Cm2'+AppVer);
ResultLine := TCPclient.IOHandler.ReadLn(IndyTextEncoding_UTF8);
TCPclient.Disconnect();
EXCEPT on E:Exception do
   begin
   end;
END{try};
TCPClient.Free;
if Parameter(ResultLine,0)='OK' then
   begin
   Result := ResultLine;
   end;
End;

Procedure SendPoolShare(Data:TSolution);
var
  TCPClient  : TidTCPClient;
  IpandPor   : String = '';
  ResultLine : String = '';
  Trys       : integer = 0;
  Success    : boolean;
Begin
ResultLine := '';
TCPClient := TidTCPClient.Create(nil);
TCPclient.Host:=ArrSources[ActivePool].ip;
TCPclient.Port:=ArrSources[ActivePool].port;
TCPclient.ConnectTimeout:= 3000;
TCPclient.ReadTimeout:=3000;
REPEAT
Success := false;
Inc(Trys);
TRY
TCPclient.Connect;
TCPclient.IOHandler.WriteLn('SHARE '+Myaddress+' '+Data.Hash+' Cm2'+AppVer+' '+CurrentBlock.ToString+' '+Data.target);
ResultLine := TCPclient.IOHandler.ReadLn(IndyTextEncoding_UTF8);
TCPclient.Disconnect();
Success := true;
EXCEPT on E:Exception do
   begin
   Success := false;
   ToLog('Error sending share: '+E.Message);
   end;
END{try};
UNTIL ((Success) or (Trys = 5));
TCPClient.Free;
if Success then
   begin
   if resultLine = 'True' then
      begin
      Inc(ArrSources[ActivePool].shares);
      U_ActivePool := true;
      SetStatusMsg('Submmited share '+ArrSources[ActivePool].shares.ToString+' to '+ArrSources[ActivePool].ip,2{green});
      if ArrSources[ActivePool].shares >= MyMaxShares then
         begin
         ArrSources[ActivePool].filled:=true;
         ClearSolutions();
         Sleep(10);
         FinishMiners := true;
         end;
      end
   else
      begin
      SetStatusMsg('Rejected share : '+ResultLine,4{red});
      // Filter here if Shares limit was reached
      If AnsiContainsStr(ResultLine,'SHARES_LIMIT') then
         begin
         ClearSolutions();
         Sleep(10);
         FinishMiners := true;
         ArrSources[ActivePool].filled:=true;
         end;
      end;
   end
else // Not send
   begin
   ToLog('Unable to send solution to '+TCPclient.Host);
   SetStatusMsg('Connection error. Check your internet connection: '+WrongThisPool.ToString,4{red});
   Inc(WrongThisPool);
   if WrongThisPool = 3 then
      begin
      FinishMiners := true;
      ArrSources[ActivePool].filled:=true;
      ClearSolutions();
      end;
   //AddSolution(Data);
   end;
End;

Procedure LoadSources();
var
  ThisSource : string;
  Counter : integer = 0;
Begin
SetLEngth(ArrSources,0);
Repeat
   begin
   ThisSource := Parameter(SourcesStr,counter);
   If ThisSource<> '' then
      begin
      ThisSource := StringReplace(ThisSource,':',' ',[rfReplaceAll, rfIgnoreCase]);
      SetLEngth(ArrSources,length(ArrSources)+1);
      ArrSources[length(ArrSources)-1].ip:=Parameter(ThisSource,0);
      ArrSources[length(ArrSources)-1].port:=StrToIntDef(Parameter(ThisSource,1),8082);
      ArrSources[length(ArrSources)-1].filled:=false;
      ArrSources[length(ArrSources)-1].shares:=0;
      ArrSources[length(ArrSources)-1].balance:=0;
      ArrSources[length(ArrSources)-1].payinterval:=0;
      ArrSources[length(ArrSources)-1].FailedTrys:=0;
      end;
   Inc(Counter);
   end;
until ThisSource = '';
End;

Function RandonStartPool():integer;
Begin
result := Random(Length(ArrSources))-1;
End;

Function AllFilled():Boolean;
var
  counter : integer;
Begin
result := true;
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
    begin
    if ArrSources[counter].filled = false then
       begin
       result := false;
       break;
       end;
    end;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure FillAllPools();
var
  counter : integer;
Begin
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
   ArrSources[counter].filled := true;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure ClearAllPools();
var
  counter : integer;
Begin
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
   begin
   ArrSources[counter].filled     := false;
   ArrSources[counter].Shares     := 0;
   ArrSources[counter].FailedTrys := 0;

   end;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure SaveSource(LSource:TSourcesData);
var
  counter : integer;
Begin
EnterCriticalSection(CS_ArrSources);
For counter := 0 to length(ArrSources)-1 do
    begin
    if ArrSources[counter].ip = LSource.ip then
       begin
       ArrSources[counter] := LSource;
       break;
       end;
    end;
LeaveCriticalSection(CS_ArrSources);
End;

Procedure SetStatusMsg(Lmessage:string;Lcolor:integer);
Begin
Statusmsg := Lmessage;
StatusColor := LColor;
End;

Procedure CreateConfig();
Begin
TRY
rewrite(FileConfig);
writeln(FileConfig,'address N2kFAtGWLb57Qz91sexZSAnYwA3T7Cy');
writeln(FileConfig,'cpu 1');
writeln(FileConfig,'hashlib 70');
writeln(FileConfig,'test True');
writeln(FileConfig,'maxshares 0');
CloseFile(FileConfig);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure LoadConfig();
var
  linea : string;
Begin
TRY
reset(FileConfig);
while not eof(FileConfig) do
   begin
   readln(FileConfig,linea);
   if uppercase(Parameter(linea,0)) = 'ADDRESS' then MyAddress := Parameter(linea,1);
   if uppercase(Parameter(linea,0)) = 'CPU' then MyCPUCount := StrToIntDef(Parameter(linea,1),1);
   if uppercase(Parameter(linea,0)) = 'HASHLIB' then MyHashLib := StrToIntDef(Parameter(linea,1),70);
   if uppercase(Parameter(linea,0)) = 'TEST' then MyRunTest := StrToBoolDef(Parameter(linea,1),false);
   if uppercase(Parameter(linea,0)) = 'MAXSHARES' then MyMaxShares := StrToIntDef(Parameter(linea,1),9999);
   if MyMaxShares < 1 then MyMaxShares := 9999;
   end;
CloseFile(FileConfig);
EXCEPT ON E:EXCEPTION do
   begin
   ToLog('Error accessing data file: '+E.Message);
   exit
   end
END {TRY};
End;

Function CheckSource():integer;
var
  ReachedNodes : integer = 0;
  ThisSource   : TSourcesData;
  PoolString : String ='';
  PoolPayStr : string = '';
  PoolPayData : TPayment;
Begin
Result := 0;
Repeat
   Inc(ActivePool);
   if ActivePool>=length(ArrSources) then ActivePool := 0;
until not ArrSources[ActivePool].filled;
ThisSource := ArrSources[ActivePool];
ToLog('Connecting '+ThisSource.ip+' ...');
PoolString := GetPoolSource(ThisSource.ip,ThisSource.port);
if PoolString<> 'ERROR' then // Pool reached
   begin
   ToLog(ThisSource.ip+': '+PoolString);
   result := 1;
   MAINPREFIX             := Parameter(PoolString,1);
   PoolMinningAddress     := Parameter(PoolString,2);
   TargetHash             := Parameter(PoolString,4);
   CurrentBlock           := StrToIntDef(Parameter(PoolString,5),0);
   ThisSource.balance     := StrToInt64Def(Parameter(PoolString,6),0);
   ThisSource.payinterval := StrToIntDef(Parameter(PoolString,7),0);
   //PoolPayStr     := Parameter(PoolString,8);
   //PoolPayStr  := StringReplace(PoolPayStr,':',' ',[rfReplaceAll, rfIgnoreCase]);
   //PoolPayData.block:=StrToIntDef(Parameter(PoolPayStr,0),0);
   //PoolPayData.OrderID:=Parameter(PoolPayStr,2);
   {
   if ((PoolPayData.OrderID <> PoolLastPayment.OrderID) and (PoolPayData.ammount>0)) then
      begin
      PoolLastPayment := PoolPayData;
      InsertNewPayment(PoolLastPayment);
      Writeln('*** NEW POOL PAYMENT ***');
      ToLog(Format('%s -> %s',[Int2Curr(PoolPayData.ammount),PoolPayData.OrderID]));
      end;
   }
   TimeOffSet := UTCTime-StrToInt64Def(Parameter(PoolString,12),UTCTime);
   SaveSource(ThisSource);
   SetStatusMsg('Synced with pool '+ThisSource.ip,2{green});
   end
else
   begin
   Inc(ArrSources[ActivePool].FailedTrys);
   Tolog('Connection error. Check your internet connection');
   if ArrSources[ActivePool].FailedTrys >= 5 then
      begin
      ArrSources[ActivePool].filled:=true;
      result := 2;
      end
   else SetStatusMsg(format('Failed connecting to %s (%d)',[ThisSource.ip,ArrSources[ActivePool].FailedTrys]),4{red});
   end;
End;

Procedure CreateLogFile();
Begin
TRY
   rewrite(FileLog);
   CloseFile(FileLog);
EXCEPT ON E:EXCEPTION do
   begin
   end
END {TRY};
End;

Procedure Tolog(LLine:String);
Begin
EnterCriticalSection(CS_Log);
Insert(LLine,ArrLogLines,Length(ArrLogLines));
EnterCriticalSection(CS_Log);
End;

Procedure CheckLog();
Begin
EnterCriticalSection(CS_Log);
If length(ArrLogLines) > 0 then
   begin
   TRY
   Append(FileLog);
   While Length(ArrLogLines)>0 do
      begin
      WriteLn(FileLog,ArrLogLines[0]);
      Delete(ArrLogLines,0,1);
      end;
   CloseFile(FileLog);
   EXCEPT ON E:EXCEPTION DO
      //WriteLn(E.Message);
   END; {Try}
   end;
LeaveCriticalSection(CS_Log);
End;

Procedure AddSolution(Data:TSolution);
Begin
EnterCriticalSection(CS_Solutions);
Insert(Data,ArrSolutions,length(ArrSolutions));
LeaveCriticalSection(CS_Solutions);
End;

Function SolutionsLength():Integer;
Begin
EnterCriticalSection(CS_Solutions);
Result := length(ArrSolutions);
LeaveCriticalSection(CS_Solutions);
End;

function GetSolution():TSolution;
Begin
result := Default(TSolution);
EnterCriticalSection(CS_Solutions);
if length(ArrSolutions)>0 then
   begin
   result := ArrSolutions[0];
   delete(ArrSolutions,0,1);
   end;
LeaveCriticalSection(CS_Solutions);
End;

Procedure ClearSolutions();
Begin
EnterCriticalSection(CS_Solutions);
Setlength(ArrSolutions,0);
LeaveCriticalSection(CS_Solutions);
End;

Procedure AddIntervalHashes(hashes:int64);
Begin
EnterCriticalSection(CS_Interval);
ThreadsIntervalHashes := ThreadsIntervalHashes+hashes;
LeaveCriticalSection(CS_Interval);
End;

function GetTotalHashes : integer;
Begin
EnterCriticalSection(CS_Interval);
Result := ThreadsIntervalHashes;
ThreadsIntervalHashes := 0;
LeaveCriticalSection(CS_Interval);
End;

Procedure ResetIntervalHashes();
Begin
EnterCriticalSection(CS_Interval);
ThreadsIntervalHashes := 0;
LeaveCriticalSection(CS_Interval);
End;

Procedure SetOMT(value:integer);
Begin
EnterCriticalSection(CS_MinerThreads);
OpenMinerThreads := value;
LeaveCriticalSection(CS_MinerThreads);
End;

Procedure DecreaseOMT();
Begin
EnterCriticalSection(CS_MinerThreads);
OpenMinerThreads := OpenMinerThreads-1;
LeaveCriticalSection(CS_MinerThreads);
End;

Function GetOMTValue():Integer;
Begin
EnterCriticalSection(CS_MinerThreads);
Result := OpenMinerThreads;
LeaveCriticalSection(CS_MinerThreads);
End;


INITIALIZATION
Assignfile(FileConfig, 'consominer2.cfg');
Assignfile(FileLog, 'log.txt');
ArrHashLibs[0]:=65;ArrHashLibs[1]:=68;ArrHashLibs[2]:=69;ArrHashLibs[3]:=70;
InitCriticalSection(CS_Log);
InitCriticalSection(CS_ArrSources);
InitCriticalSection(CS_Solutions);
InitCriticalSection(CS_Interval);
InitCriticalSection(CS_MinerThreads);

SetLength(ArrSolutions,0);
SetLength(ArrLogLines,0);


FINALIZATION
DoneCriticalSection(CS_Log);
DoneCriticalSection(CS_ArrSources);
DoneCriticalSection(CS_Solutions);
DoneCriticalSection(CS_Interval);
DoneCriticalSection(CS_MinerThreads);

END. // END UNIT

