unit pasMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls;

const
  WM_PROCESSSTART        = WM_USER + $F0;
  WM_PROCESSSTOP         = WM_USER + $F1;
  WM_PROCESSSBUFFERCLEAN = WM_USER + $F2;
  WM_PROCESSSBUFFERADDED = WM_USER + $F3;

type
  PSocketBuffer = ^TSocketBuffer;
  TSocketBuffer = packed record
    id: Cardinal;
    n: PSocketBuffer;
  end;

  TfrmMain = class(TForm)
    edtCreateCount: TEdit;
    btnCreate: TButton;
    mmoLog: TMemo;
    procedure btnCreateClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    BufferCount: Cardinal;

    procedure WMProcessStart(var msg: TMessage); message WM_PROCESSSTART;
    procedure WMProcessStop(var msg: TMessage); message WM_PROCESSSTOP;
    procedure WMProcessBufferClean(var msg: TMessage); message WM_PROCESSSBUFFERCLEAN;
    procedure WMProcessBufferAdded(var msg: TMessage); message WM_PROCESSSBUFFERADDED;

    procedure Log(const ALog: string);

    procedure AddBuffer;

    procedure ReadBuffer(ABufferId: integer);

    procedure BufferDispatch;
  end;

var
  frmMain: TfrmMain;

var
  FirstSocketBuffer: PSocketBuffer = nil;
  LastSocketBuffer: PSocketBuffer = nil;

  SocketBufferLock: TRTLCriticalSection;
  SocketBufferEvent: THandle;
  SocketRunCommandThreadTerminate: boolean = false;

implementation

uses ParallelJobs;

{$R *.dfm}

{ TfrmMain }

procedure TfrmMain.WMProcessStart(var msg: TMessage);
begin
  Log(Format('PROCESS START: %d', [msg.WParam]));
end;

procedure TfrmMain.WMProcessStop(var msg: TMessage);
begin
  Log(Format('PROCESS STOP: %d', [msg.WParam]));
end;

procedure TfrmMain.WMProcessBufferClean(var msg: TMessage);
begin
  Log(Format('PROCESS START: %d', [msg.WParam]));
end;

procedure TfrmMain.WMProcessBufferAdded(var msg: TMessage);
begin
  Log(Format('PROCESS START: %d', [msg.WParam]));
end;

procedure TfrmMain.Log(const ALog: string);
begin
  mmoLog.Lines.Add(DateTimeToStr(now) + ': ' + ALog);
end;

procedure TfrmMain.AddBuffer;
var
  NewBuffer: PSocketBuffer;
begin
  EnterCriticalSection(SocketBufferLock);
  try
    try
      New(NewBuffer);
      NewBuffer^.n := nil;
      NewBuffer^.id := BufferCount;
      
      Inc(BufferCount);

      if FirstSocketBuffer = nil then
        FirstSocketBuffer := NewBuffer;

      if LastSocketBuffer <> nil then
        LastSocketBuffer^.n := NewBuffer;

      LastSocketBuffer := NewBuffer;
    except
      // Exception manager...
    end;
  finally
    LeaveCriticalSection(SocketBufferLock);
    SetEvent(SocketBufferEvent);      
  end;
end;

procedure TfrmMain.btnCreateClick(Sender: TObject);
var
  i: integer;
begin
  for i := 1 to StrToInt(edtCreateCount.Text) do
    AddBuffer;
end;

procedure TfrmMain.ReadBuffer(ABufferId: integer);
begin
  Randomize;
  PostMessage(Handle, WM_PROCESSSTART, ABufferId, 0);
  Sleep(Random(5000));
  PostMessage(Handle, WM_PROCESSSTOP, ABufferId, 0);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  InitializeCriticalSection(SocketBufferLock);
  SocketBufferEvent := CreateEvent(nil, true, false, nil);

  ParallelJob(Self, @TfrmMain.BufferDispatch);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SocketRunCommandThreadTerminate := true;  

  SetEvent(SocketBufferEvent);
  CloseHandle(SocketBufferEvent);
end;

procedure TfrmMain.BufferDispatch;
var
  BufferStep, BufferStepNext: PSocketBuffer;

  procedure Run(ABuffer: PSocketBuffer);
  begin
    frmMain.ReadBuffer(ABuffer^.id);
    Dispose(ABuffer);
  end;
begin
  while not SocketRunCommandThreadTerminate do
  begin
    EnterCriticalSection(SocketBufferLock);
    try
      BufferStep := FirstSocketBuffer;
      while BufferStep <> nil do
      begin
        BufferStepNext := BufferStep^.n;
        ParallelJob(@Run, BufferStep);
        BufferStep := BufferStepNext;
      end;

      FirstSocketBuffer := nil;
      LastSocketBuffer := nil;
      ResetEvent(SocketBufferEvent);
    finally
      LeaveCriticalSection(SocketBufferLock);
    end;

    WaitForSingleObject(SocketBufferEvent, INFINITE);
  end;
end;

end.
