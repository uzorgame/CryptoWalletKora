; KORA Suite — Windows installer (Wallet + Market)
;
; One installer for both Windows products. The AppId below is the one the already-released
; Suite 3.5.0 shipped with, and it must not change: Inno recognises an existing installation
; by AppId alone. A new GUID would install a second copy beside the old one, leave the old
; entry in Programs and Features, and leave the user with two Koras.
;
; NOTHING in this script deletes user data during an install or an upgrade. The wallet's
; recovery phrases live encrypted in %APPDATA%\com.kora\kora_windows, and an upgrade has no
; business there. Only an uninstall may touch it, and only after the user has said so in
; answer to a question that defaults to keeping it.
;
; The wizard is restyled to the app's own look — #0A0A0A, square corners, monochrome — in the
; [Code] section. That is done by hand because Inno's own theming cannot reach it: with a
; custom WizardStyle keyword active, VCL Styles take over and colours set from Pascal
; Scripting are ignored. The two are mutually exclusive, so this uses plain "modern" and
; repaints every control itself.
;
; Build:  flutter build windows --release      (in WALLET\ and in MARKET\)
; Then:   ISCC.exe installer_combined.iss

#define AppName      "KORA Suite"
#define AppVersion   "5.1.1"
#define AppPublisher "Nahreba Mykhailo"

; Market is a sibling directory, not a subfolder. It used to live inside the wallet's own
; tree, which made every analyzer run walk into a second package.
#define WalletBuild  "build\windows\x64\runner\Release"
#define MarketBuild  "..\MARKET\build\windows\x64\runner\Release"
#define WalletExe    "kora_windows.exe"
#define MarketExe    "kora_widget.exe"

; The standalone KORA Market's AppId. This suite contains Market, so a machine carrying both
; ends up with two of it — the install offers to retire the standalone one.
#define StandaloneMarketId "{7C3E1A94-6B2D-4F58-9E71-2A5D8C0F3B14}_is1"

[Setup]
AppId={{C7E2A401-F3B5-4D89-BCF1-0A5274839261}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\KORA Suite
DefaultGroupName=KORA Suite
AllowNoIcons=yes
LicenseFile=privacy_policy.rtf
OutputDir=installer_output
OutputBaseFilename=KoraSuite_Setup_v{#AppVersion}
SetupIconFile=windows\runner\resources\installer_icon.ico
UninstallDisplayIcon={app}\wallet\{#WalletExe}
Compression=lzma2/ultra64
SolidCompression=yes
DisableDirPage=no
DisableProgramGroupPage=no
MinVersion=10.0

; An upgrade must land where the previous version is, not where this script's default points.
; Both are on by default; they are stated because they are what makes the install in-place.
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes

; Per-user, with no mode dialog. PrivilegesRequiredOverridesAllowed=dialog would put a stock
; "Select Setup Install Mode" window on screen BEFORE InitializeWizard runs — the one surface
; the dark theming below could never reach, and the first thing anyone would see.
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

WizardStyle=modern
DisableWelcomePage=no

; One set of artwork for both installers, kept where it is generated rather than copied here.
; Two copies would drift, and the one that drifted would be the one nobody was looking at.
#define Art "..\MARKET\installer"
WizardImageFile={#Art}\wizard-202x386.png,{#Art}\wizard-269x515.png,{#Art}\wizard-336x643.png,{#Art}\wizard-430x824.png,{#Art}\wizard-534x1022.png
WizardSmallImageFile={#Art}\wizard-small-58.png,{#Art}\wizard-small-83.png,{#Art}\wizard-small-110.png,{#Art}\wizard-small-159.png
WizardImageAlphaFormat=none
WizardImageStretch=yes
WizardImageBackColor=$000A0A0A

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Components]
Name: "wallet"; Description: "KORA Wallet  —  multi-chain crypto wallet"; Types: full compact custom; Flags: fixed
Name: "market"; Description: "KORA Market  —  live market prices"; Types: full custom

[Tasks]
Name: "desktopwallet"; Description: "Create a desktop shortcut for KORA Wallet"; GroupDescription: "Desktop shortcuts:"; Components: wallet
Name: "desktopmarket"; Description: "Create a desktop shortcut for KORA Market"; GroupDescription: "Desktop shortcuts:"; Components: market

[Files]
Source: "{#WalletBuild}\{#WalletExe}";        DestDir: "{app}\wallet"; Components: wallet; Flags: ignoreversion
Source: "{#WalletBuild}\*.dll";               DestDir: "{app}\wallet"; Components: wallet; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#WalletBuild}\data\*";              DestDir: "{app}\wallet\data"; Components: wallet; Flags: ignoreversion recursesubdirs createallsubdirs

Source: "{#MarketBuild}\{#MarketExe}";        DestDir: "{app}\market"; Components: market; Flags: ignoreversion
Source: "{#MarketBuild}\*.dll";               DestDir: "{app}\market"; Components: market; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#MarketBuild}\data\*";              DestDir: "{app}\market\data"; Components: market; Flags: ignoreversion recursesubdirs createallsubdirs

; The policy again, carried into Setup's temp directory rather than installed. The licence
; box is loaded from it by hand in [Code] — see LoadLicence — because loading it through
; LicenseFile leaves the text in the rich edit's default character format, which is black,
; and black on the #0A0A0A wizard page is a policy nobody can read.
Source: "privacy_policy.rtf"; Flags: dontcopy

[Icons]
Name: "{group}\KORA Wallet"; Filename: "{app}\wallet\{#WalletExe}"; Components: wallet
Name: "{group}\KORA Market"; Filename: "{app}\market\{#MarketExe}"; Components: market
Name: "{group}\{cm:UninstallProgram,KORA Suite}"; Filename: "{uninstallexe}"

Name: "{autodesktop}\KORA Wallet"; Filename: "{app}\wallet\{#WalletExe}"; Components: wallet; Tasks: desktopwallet
Name: "{autodesktop}\KORA Market"; Filename: "{app}\market\{#MarketExe}"; Components: market; Tasks: desktopmarket

[Run]
Filename: "{app}\wallet\{#WalletExe}"; Description: "Launch KORA Wallet"; Flags: nowait postinstall skipifsilent unchecked; Components: wallet
Filename: "{app}\market\{#MarketExe}"; Description: "Launch KORA Market"; Flags: nowait postinstall skipifsilent unchecked; Components: market

; Program files only. The two data directories below are the ones this installer put there;
; the user's wallets are somewhere else entirely and are handled in [Code], with a question.
[UninstallDelete]
Type: filesandordirs; Name: "{app}\wallet\data"
Type: filesandordirs; Name: "{app}\market\data"

; ============================================================================
;  Dark / square / monochrome wizard, plus the update-or-remove question
; ============================================================================
[Code]

{ TColor is $00BBGGRR. Every value here is a neutral grey, so the red/blue swap is a no-op;
  a non-grey accent would have to be byte-swapped by hand. }
const
  clBg      = $000A0A0A;  { #0A0A0A  page and form background          }
  clSurface = $00111111;  { #111111  fields, buttons, progress track   }
  clFg      = $00F0F0F0;  { #F0F0F0  text, progress fill               }
  clFgMuted = $008A8A8A;  { #8A8A8A  disabled text                     }
  clLine    = $00232323;  { the 10% hairline, flattened onto #0A0A0A   }

  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;   { Win10 17763..18984 }
  DWMWA_USE_IMMERSIVE_DARK_MODE     = 20;   { Win10 18985+       }
  DWMWA_WINDOW_CORNER_PREFERENCE    = 33;   { Win11 22000+       }
  DWMWCP_DONOTROUND                 = 1;

  PBM_SETBKCOLOR  = $2001;
  PBM_SETBARCOLOR = $0409;
  PBS_SMOOTH      = $01;
  BM_CLICK        = $00F5;

  GWL_STYLE        = -16;
  GWL_EXSTYLE      = -20;
  WS_BORDER        = $00800000;
  WS_EX_CLIENTEDGE = $00000200;
  WS_EX_STATICEDGE = $00020000;
  SWP_NOSIZE = $01; SWP_NOMOVE = $02; SWP_NOZORDER = $04;
  SWP_NOACTIVATE = $10; SWP_FRAMECHANGED = $20;

  OFFSCREEN_TOP = 30000;

  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  SuiteKey     = '{C7E2A401-F3B5-4D89-BCF1-0A5274839261}_is1';

{ delayload: the DLLs are opened on first call, so a missing one can never abort Setup at
  startup. No setuponly flag — these are called from the uninstaller's form too. }
function DwmSetWindowAttribute(hwnd: HWND; dwAttribute: Cardinal;
  var pvAttribute: Integer; cbAttribute: Cardinal): Integer;
  external 'DwmSetWindowAttribute@dwmapi.dll stdcall delayload';

function SetWindowTheme(hwnd: HWND; pszSubAppName, pszSubIdList: WideString): Integer;
  external 'SetWindowTheme@uxtheme.dll stdcall delayload';

function ApiSetWindowPos(hWnd, hWndInsertAfter: HWND; X, Y, cx, cy: Integer;
  uFlags: Cardinal): Integer;
  external 'SetWindowPos@user32.dll stdcall';

function ApiGetWindowLong(hWnd: HWND; nIndex: Integer): Longint;
  external 'GetWindowLongW@user32.dll stdcall';

function ApiSetWindowLong(hWnd: HWND; nIndex: Integer; dwNewLong: Longint): Longint;
  external 'SetWindowLongW@user32.dll stdcall';

var
  GBtnReal: array of TNewButton;   { the real buttons, parked off-screen }
  GBtnFace: array of TPanel;       { the visible dark square             }
  GBtnText: array of TLabel;       { its caption                         }
  GTickCtrl: array of TWinControl;  { checkboxes and radios whose caption we redraw }
  GTickText: array of TLabel;       { the caption we drew for each }
  GLines: array of TPanel;         { our own hairlines and button outlines }

  GChoicePage: TInputOptionWizardPage;   { update or remove }
  GRetireStandalone: TInputOptionWizardPage;
  GHadSuite: Boolean;
  GHadStandaloneMarket: Boolean;
  GExiting: Boolean;                     { leaving on purpose, not cancelling }
  GLicence: AnsiString;                  { the policy as RTF, loaded once }

{ ---- finding what is already on the machine ------------------------------- }

{ Looks in both hives because the previous version may have been installed per-user or
  per-machine, and which one it was is not knowable from here. }
function InstalledAt(SubKey: String; var Location: String): Boolean;
begin
  Result := RegQueryStringValue(HKCU, UninstallKey + SubKey, 'UninstallString', Location) or
            RegQueryStringValue(HKLM, UninstallKey + SubKey, 'UninstallString', Location);
end;

function Installed(SubKey: String): Boolean;
var
  Ignored: String;
begin
  Result := InstalledAt(SubKey, Ignored);
end;

{ Runs a product's own uninstaller and waits. Its own uninstaller is used rather than deleting
  files here, so that its Programs-and-Features entry goes with it. }
function RunUninstaller(SubKey: String; Silent: Boolean): Boolean;
var
  Command, Args: String;
  ResultCode: Integer;
begin
  Result := False;
  if not InstalledAt(SubKey, Command) then
    Exit;
  { The stored string is a quoted path; Inno's own uninstaller takes /SILENT. }
  Command := RemoveQuotes(Command);
  if Silent then
    Args := '/SILENT /NORESTART'
  else
    Args := '/NORESTART';
  Result := Exec(Command, Args, '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
end;

{ ---- square corners and dark caption ------------------------------------- }

function WinBuild: Cardinal;
var
  V: TWindowsVersion;
begin
  GetWindowsVersionEx(V);
  if V.NTPlatform then
    Result := V.Build
  else
    Result := 0;
end;

{ Triple-guarded so it cannot break an older Windows: a build gate, delayload, and a try.
  On Windows 10 attribute 33 would merely return E_INVALIDARG, but the gate stops it being
  sent at all. }
procedure ApplyDwm(H: HWND);
var
  V: Integer;
  B: Cardinal;
begin
  if H = 0 then
    Exit;
  B := WinBuild;
  try
    if B >= 18985 then begin
      V := 1;
      DwmSetWindowAttribute(H, DWMWA_USE_IMMERSIVE_DARK_MODE, V, SizeOf(V));
    end else if B >= 17763 then begin
      V := 1;
      DwmSetWindowAttribute(H, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, V, SizeOf(V));
    end;
    if B >= 22000 then begin
      V := DWMWCP_DONOTROUND;
      DwmSetWindowAttribute(H, DWMWA_WINDOW_CORNER_PREFERENCE, V, SizeOf(V));
    end;
  except
    { attribute unsupported on this OS — ignore }
  end;
end;

{ ---- low level helpers ---------------------------------------------------- }

{ Removes the themed 3D frame from an edit, memo or rich edit. }
procedure StripBorder(WC: TWinControl);
var
  L: Longint;
begin
  L := ApiGetWindowLong(WC.Handle, GWL_EXSTYLE);
  ApiSetWindowLong(WC.Handle, GWL_EXSTYLE,
    L and (not WS_EX_CLIENTEDGE) and (not WS_EX_STATICEDGE));
  L := ApiGetWindowLong(WC.Handle, GWL_STYLE);
  ApiSetWindowLong(WC.Handle, GWL_STYLE, L and (not WS_BORDER));
  ApiSetWindowPos(WC.Handle, 0, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED);
end;

{ Hands a control to comctl32's dark-mode drawing — light text, dark scrollbars, and a focus
  indicator that suits a dark surface. }
procedure UseDarkMode(WC: TWinControl);
begin
  try
    SetWindowTheme(WC.Handle, 'DarkMode_Explorer', '');
  except
  end;
end;

{ Removes the visual style from a control so its own Color and Font are honoured again. }
procedure DeTheme(WC: TWinControl);
begin
  try
    SetWindowTheme(WC.Handle, ' ', ' ');
  except
  end;
end;

{ A themed TPanel paints its parent's background and silently ignores Color. ParentBackground
  must be off before Color means anything. }
procedure SolidPanel(P: TPanel; AColor: TColor);
begin
  P.BevelOuter := bvNone;
  P.BevelKind := bkNone;
  P.ParentBackground := False;
  P.Color := AColor;
end;

{ Remembers a panel of ours so a later repaint pass can put its colour back. }
procedure RememberLine(P: TPanel);
var
  N: Integer;
begin
  N := GetArrayLength(GLines);
  SetArrayLength(GLines, N + 1);
  GLines[N] := P;
end;

function NewLine(AParent: TWinControl; L, T, W, H: Integer): TPanel;
begin
  Result := TPanel.Create(AParent);
  Result.Parent := AParent;
  SolidPanel(Result, clLine);
  Result.SetBounds(L, T, W, H);
  RememberLine(Result);
end;

{ A one-pixel hairline behind a control, in place of the themed border. }
procedure Frame1px(C: TControl);
var
  P: TPanel;
begin
  if C.Parent = nil then
    Exit;
  P := NewLine(C.Parent, C.Left - 1, C.Top - 1, C.Width + 2, C.Height + 2);
  P.SendToBack;
  C.BringToFront;
end;

{ The progress bar ignores Color because it is a themed comctl32 control. Killing the theme
  first makes PBM_SETBKCOLOR and PBM_SETBARCOLOR take effect. }
procedure StyleProgressBar(PB: TNewProgressBar);
var
  L: Longint;
begin
  try
    SetWindowTheme(PB.Handle, ' ', ' ');
  except
  end;
  L := ApiGetWindowLong(PB.Handle, GWL_STYLE);
  ApiSetWindowLong(PB.Handle, GWL_STYLE, L or PBS_SMOOTH);
  SendMessage(PB.Handle, PBM_SETBKCOLOR, 0, clSurface);
  SendMessage(PB.Handle, PBM_SETBARCOLOR, 0, clFg);
end;

{ ---- pass A: recolour every control --------------------------------------- }
{ TControl publishes neither Color nor Font, so a generic walk still needs one branch per
  class. These cover every control the stock wizard and uninstall form contain. }

procedure PaintTree(P: TWinControl); forward;

{ ---- readable captions on ticks and radios -------------------------------- }
{
  Neither theming state gives a legible caption on a dark page, so the caption is drawn here.

  Stripping the theme hands the label back to the classic BUTTON renderer, which fills the
  text background with COLOR_BTNFACE — a light-grey box the exact size of the words. That box
  is what sat behind "I accept the agreement". Leaving the theme on and asking comctl32 for
  DarkMode_Explorer gives a correct dark indicator but the theme then owns the text too, and
  it draws it dark on dark.

  So: keep the themed indicator, blank the control's own caption, and put a TLabel where the
  caption used to be. Clicks on the label are forwarded to the control, so the whole row
  behaves exactly as it did.
}
procedure TickClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(GTickText) - 1 do
    if Sender = GTickText[I] then begin
      if GTickCtrl[I].Enabled then PostMessage(GTickCtrl[I].Handle, BM_CLICK, 0, 0);
      Exit;
    end;
end;

procedure Relabel(WC: TWinControl; ACaption: String);
var
  I, N: Integer;
  L: TLabel;
begin
  { Identity, not caption. PaintTree runs again on every page change, and an "already blank"
    test is wrong for Inno's Preparing page: FPreparingYesRadio and FPreparingNoRadio ship
    with a '*' placeholder and only receive their real captions when that page is actually
    needed — so a caption-based guard let them through twice and drew two overlapping labels. }
  for I := 0 to GetArrayLength(GTickCtrl) - 1 do
    if GTickCtrl[I] = WC then begin
      if (ACaption <> '') and (ACaption <> '*') then GTickText[I].Caption := ACaption;
      GTickText[I].Visible := WC.Visible;
      Exit;
    end;

  if (ACaption = '') or (ACaption = '*') then Exit;

  N := GetArrayLength(GTickCtrl);
  SetArrayLength(GTickCtrl, N + 1);
  SetArrayLength(GTickText, N + 1);
  GTickCtrl[N] := WC;

  L := TLabel.Create(WC.Parent);
  L.Parent := WC.Parent;
  L.Transparent := True;
  L.AutoSize := True;
  L.Caption := ACaption;
  L.Font := WizardForm.Font;
  L.Font.Color := clFg;
  L.Cursor := crHand;
  L.OnClick := @TickClick;
  { Restores the Alt accelerator. The caption moved off the control, and with it the underlined
    letter's binding — Alt+A no longer reached "I accept the agreement". FocusControl gives the
    label's accelerator back to the control it labels. }
  L.FocusControl := WC;
  { Beside the indicator, centred against the control's own height. }
  L.Left := WC.Left + ScaleX(20);
  L.Top := WC.Top + (WC.Height - L.Height) div 2;
  { A label for a hidden control must be hidden too, or it lingers on a page whose control
    Inno never showed. }
  L.Visible := WC.Visible;
  GTickText[N] := L;

  if WC is TNewCheckBox then TNewCheckBox(WC).Caption := '';
  if WC is TNewRadioButton then TNewRadioButton(WC).Caption := '';

  { Narrowed to the indicator. The control still spans the page, and a caption-less BUTTON
    draws its focus rectangle around that whole width — a hairline box running to the right
    margin. The words are the label's now, and the label takes the clicks over them. }
  WC.Width := ScaleX(16);
end;

procedure PaintOne(C: TControl);
begin
  if C is TNewProgressBar then begin
    StyleProgressBar(TNewProgressBar(C));
  end else if C is TBevel then begin
    C.Visible := False;            { a TBevel's colour is not settable — hide it }
  end else if C is TNewButton then begin
    { skinned in pass B }
  end else if C is TBitmapImage then begin
    TBitmapImage(C).BackColor := clBg;
  end else if C is TNewCheckListBox then begin
    TNewCheckListBox(C).Color := clBg;
    TNewCheckListBox(C).Font.Color := clFg;
    TNewCheckListBox(C).BorderStyle := bsNone;
    UseDarkMode(TNewCheckListBox(C));
  end else if C is TNewListBox then begin
    TNewListBox(C).Color := clSurface;
    TNewListBox(C).Font.Color := clFg;
    TNewListBox(C).BorderStyle := bsNone;
    UseDarkMode(TNewListBox(C));
  end else if C is TRichEditViewer then begin
    TRichEditViewer(C).Color := clSurface;
    TRichEditViewer(C).Font.Color := clFg;
    StripBorder(TRichEditViewer(C));
    UseDarkMode(TRichEditViewer(C));
  end else if C is TNewMemo then begin
    TNewMemo(C).Color := clSurface;
    TNewMemo(C).Font.Color := clFg;
    StripBorder(TNewMemo(C));
    UseDarkMode(TNewMemo(C));
  end else if C is TNewEdit then begin
    { A themed EDIT paints its own white client area and ignores Color. }
    DeTheme(TNewEdit(C));
    TNewEdit(C).Color := clSurface;
    TNewEdit(C).Font.Color := clFg;
    StripBorder(TNewEdit(C));
  end else if C is TNewCheckBox then begin
    UseDarkMode(TNewCheckBox(C));
    TNewCheckBox(C).Color := clBg;
    Relabel(TNewCheckBox(C), TNewCheckBox(C).Caption);
  end else if C is TNewRadioButton then begin
    UseDarkMode(TNewRadioButton(C));
    TNewRadioButton(C).Color := clBg;
    Relabel(TNewRadioButton(C), TNewRadioButton(C).Caption);
  end else if C is TNewStaticText then begin
    TNewStaticText(C).Color := clBg;
    TNewStaticText(C).Font.Color := clFg;
  end else if C is TNewLinkLabel then begin
    TNewLinkLabel(C).Color := clBg;
    TNewLinkLabel(C).Font.Color := clFg;
  end else if C is TLabel then begin
    TLabel(C).Transparent := True;
    TLabel(C).Font.Color := clFg;
  end else if C is TNewNotebookPage then begin
    TNewNotebookPage(C).Color := clBg;
  end else if C is TPanel then begin
    SolidPanel(TPanel(C), clBg);
  end;

  if C is TWinControl then
    PaintTree(TWinControl(C));
end;

procedure PaintTree(P: TWinControl);
var
  I: Integer;
begin
  for I := 0 to P.ControlCount - 1 do
    PaintOne(P.Controls[I]);
end;

{ ---- pass B: flat square buttons ------------------------------------------ }
{
  TNewButton is a themed Windows BUTTON: its Color is ignored by the renderer, and Inno's
  scripting wrapper exposes no ownerdraw hook. Removing the theme yields the grey Windows-95
  button, not a dark one.

  So each real button is PARKED off-screen rather than hidden. Visible stays True, which keeps
  the Default/Cancel handling and the Alt accelerators alive — Enter and Esc still work with
  no keyboard hooks. A hairline outline plus a dark face and a caption is drawn at the
  original bounds and forwards clicks with BM_CLICK.
}

procedure BtnClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(GBtnReal) - 1 do
    if (Sender = GBtnFace[I]) or (Sender = GBtnText[I]) then begin
      if GBtnReal[I].Enabled and GBtnReal[I].Visible then
        PostMessage(GBtnReal[I].Handle, BM_CLICK, 0, 0);
      Exit;
    end;
end;

{ Mirrors caption, enabled and visible from the real buttons onto the faces. Has to run
  whenever Inno changes them: Next becomes Install becomes Finish, buttons go dead during the
  copy, Back and Cancel disappear on the last page. }
procedure SkinButtons;
var
  I: Integer;
  S: String;
begin
  for I := 0 to GetArrayLength(GBtnReal) - 1 do begin
    S := GBtnReal[I].Caption;
    StringChangeEx(S, '&', '', True);
    GBtnText[I].Caption := S;
    GBtnText[I].Left := (GBtnFace[I].Width - GBtnText[I].Width) div 2;
    GBtnText[I].Top := (GBtnFace[I].Height - GBtnText[I].Height) div 2;
    GBtnFace[I].Parent.Visible := GBtnReal[I].Visible;
    GBtnFace[I].Enabled := GBtnReal[I].Enabled;
    if not GBtnReal[I].Enabled then begin
      GBtnFace[I].Color := clBg;
      GBtnText[I].Font.Color := clFgMuted;
    end else if GBtnReal[I] = WizardForm.NextButton then begin
      { The primary action is inverted — white face, black text — exactly as the app's own
        selected segmented button is. On a #0A0A0A page a #111111 face is invisible. }
      GBtnFace[I].Color := clFg;
      GBtnText[I].Font.Color := clBg;
    end else begin
      GBtnFace[I].Color := clSurface;
      GBtnText[I].Font.Color := clFg;
    end;
  end;
end;

procedure MakeFakeButton(B: TNewButton);
var
  N: Integer;
  Frame: TPanel;
begin
  N := GetArrayLength(GBtnReal);
  SetArrayLength(GBtnReal, N + 1);
  SetArrayLength(GBtnFace, N + 1);
  SetArrayLength(GBtnText, N + 1);
  GBtnReal[N] := B;

  Frame := TPanel.Create(B.Parent);
  Frame.Parent := B.Parent;
  Frame.SetBounds(B.Left - 1, B.Top - 1, B.Width + 2, B.Height + 2);
  SolidPanel(Frame, clLine);
  RememberLine(Frame);
  if B.Parent = WizardForm then
    Frame.Anchors := [akRight, akBottom];

  GBtnFace[N] := TPanel.Create(Frame);
  GBtnFace[N].Parent := Frame;
  GBtnFace[N].SetBounds(1, 1, B.Width, B.Height);
  SolidPanel(GBtnFace[N], clSurface);
  GBtnFace[N].Anchors := [akLeft, akTop, akRight, akBottom];
  GBtnFace[N].Cursor := crHand;
  GBtnFace[N].OnClick := @BtnClick;

  GBtnText[N] := TLabel.Create(GBtnFace[N]);
  GBtnText[N].Parent := GBtnFace[N];
  GBtnText[N].Transparent := True;
  GBtnText[N].AutoSize := True;
  GBtnText[N].Font := B.Font;
  GBtnText[N].Font.Color := clFg;
  GBtnText[N].Cursor := crHand;
  GBtnText[N].OnClick := @BtnClick;

  B.TabStop := False;
  B.Top := OFFSCREEN_TOP;
end;

{ Collects one parent's buttons before skinning them, so the child list is never mutated
  while it is being walked. }
procedure SkinTree(P: TWinControl);
var
  I, N: Integer;
  L: array of TNewButton;
begin
  N := 0;
  SetArrayLength(L, P.ControlCount);
  for I := 0 to P.ControlCount - 1 do
    if P.Controls[I] is TNewButton then begin
      L[N] := TNewButton(P.Controls[I]);
      N := N + 1;
    end else if P.Controls[I] is TWinControl then
      SkinTree(TWinControl(P.Controls[I]));
  for I := 0 to N - 1 do
    MakeFakeButton(L[I]);
end;

{ ---- the update-or-remove question ---------------------------------------- }

procedure MakeChoicePages;
begin
  GChoicePage := CreateInputOptionPage(wpWelcome,
    'KORA is already installed',
    'Version ' + '{#AppVersion}' + ' can replace it, or the existing one can be removed.',
    'Choose what this installer should do. Updating keeps every wallet, recovery phrase and '
    + 'setting exactly as it is — nothing in your app data is touched.',
    True, False);
  GChoicePage.Add('Update the installed KORA (keeps all wallets and settings)');
  GChoicePage.Add('Remove KORA from this computer');
  GChoicePage.SelectedValueIndex := 0;

  { Unticked, and honest about the cost.

    An earlier draft of this page promised "Market's own settings are kept either way" and
    then ran the standalone's uninstaller, which deletes %APPDATA%\com.korawallet\kora_widget
    — the only settings directory Market has, and the same one the copy in this suite reads.
    The promise was false, and it was ticked by default, so the destructive reading was the
    one that happened unless the user intervened. Now it says what it does and asks first. }
  GRetireStandalone := CreateInputOptionPage(GChoicePage.ID,
    'A separate KORA Market is installed',
    'This suite already contains Market.',
    'Leaving both installed means two copies of Market, two shortcuts and two entries in '
    + 'Programs and Features. Removing the separate one also resets Market''s settings — '
    + 'which coins are listed, and where the window sits — because both copies read the '
    + 'same folder.',
    False, False);
  GRetireStandalone.Add('Remove the separate KORA Market installation (resets Market''s settings)');
  GRetireStandalone.Values[0] := False;
end;

{ ---- events --------------------------------------------------------------- }

function InitializeSetup: Boolean;
begin
  GHadSuite := Installed(SuiteKey);
  GHadStandaloneMarket := Installed('{#StandaloneMarketId}');
  Result := True;
end;

{ Keeps the painted Next button honest about whether the real one is enabled.

  Setup enables Next on the licence page from the accept radio's own OnClick, but SkinButtons
  only runs on a page change — so accepting the agreement enabled the real button while the
  face the user sees stayed in its disabled colours. A button that looks dead is a button
  nobody presses, which is exactly the report: "Next cannot be clicked".

  The stock handler is called first and then the faces are repainted, so Setup's own logic is
  untouched. }
procedure LicenceChoiceClicked(Sender: TObject);
begin
  { The stock handler's whole job on this page is this one line, so it is done here rather
    than chained — Inno's scripting has no way to call a saved event back. }
  WizardForm.NextButton.Enabled := WizardForm.LicenseAcceptedRadio.Checked;
  SkinButtons;
end;

procedure WatchLicenceRadios;
begin
  WizardForm.LicenseAcceptedRadio.OnClick := @LicenceChoiceClicked;
  WizardForm.LicenseNotAcceptedRadio.OnClick := @LicenceChoiceClicked;
end;

{ Loads the policy as RTF and puts it into the licence box itself.

  Going through LicenseFile is not enough. The box is a rich edit; text arriving that way keeps
  the control's default character format, which is black, and setting
  TRichEditViewer.Font.Color from here does not reach text that is already loaded. Sampled from
  the running wizard, the glyphs were #0B0600 on a #111111 panel — the policy was on screen and
  unreadable. Assigning RTFText hands the control a document carrying its own colour table,
  which it does honour. }
procedure LoadLicence;
begin
  try
    ExtractTemporaryFile('privacy_policy.rtf');
    if LoadStringFromFile(ExpandConstant('{tmp}\privacy_policy.rtf'), GLicence) then begin
      WizardForm.LicenseMemo.UseRichEdit := True;
      WizardForm.LicenseMemo.RTFText := GLicence;
    end;
  except
    { leave whatever LicenseFile produced rather than blanking the box }
  end;
end;

procedure InitializeWizard;
begin
  WizardForm.Color := clBg;
  WizardForm.Font.Color := clFg;

  MakeChoicePages;

  PaintTree(WizardForm);
  LoadLicence;
  WatchLicenceRadios;

  Frame1px(WizardForm.DirEdit);
  Frame1px(WizardForm.GroupEdit);
  Frame1px(WizardForm.ReadyMemo);
  Frame1px(WizardForm.TasksList);
  Frame1px(WizardForm.ComponentsList);
  Frame1px(WizardForm.ProgressGauge);

  { The stock folder glyphs are full-colour Windows icons. A yellow folder is the one thing on
    screen that is not monochrome, so it goes; the indent it leaves reads as a margin. }
  WizardForm.SelectDirBitmapImage.Visible := False;
  WizardForm.SelectGroupBitmapImage.Visible := False;

  { our own hairline in place of the hidden stock bevel }
  NewLine(WizardForm, 0, WizardForm.CancelButton.Top - ScaleY(12),
    WizardForm.ClientWidth, 1).Anchors := [akLeft, akRight, akBottom];

  SkinTree(WizardForm);
  SkinButtons;
  ApplyDwm(WizardForm.Handle);
end;

{ The two questions are only questions if there is something to answer them about. }
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  if PageID = GChoicePage.ID then
    Result := not GHadSuite
  else if PageID = GRetireStandalone.ID then
    Result := not GHadStandaloneMarket
  else
    Result := False;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = GChoicePage.ID) and (GChoicePage.SelectedValueIndex = 1) then begin
    { Removal is the user's own uninstaller run, shown rather than silenced: it is where the
      question about keeping wallet data is asked, and that question must not be answered on
      their behalf. }
    RunUninstaller(SuiteKey, False);

    { Only leave if it actually went. An uninstaller that was cancelled, or that failed, used
      to be followed by Setup closing anyway — so the user was left with KORA still installed
      and no sign that the removal had not happened. }
    if Installed(SuiteKey) then begin
      MsgBox('KORA is still installed.' + #13#10#13#10 +
             'The removal did not finish, so nothing has changed. You can try again, or go '
             + 'back and choose Update instead.', mbInformation, MB_OK);
      Result := False;
      Exit;
    end;

    { GExiting suppresses the "Setup is not complete… Exit Setup?" confirmation. Without it,
      a user who had just deliberately removed KORA and watched the uninstaller finish was
      asked whether they wanted to abandon an installation they never started — and answering
      No put them back on this page with nothing left to install. }
    GExiting := True;
    Result := False;
    WizardForm.Close;
  end;
end;

{ See GExiting above. Cancel is confirmed everywhere except the deliberate exit after a
  removal, which is not a cancellation at all. }
procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if GExiting then Confirm := False;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    if GHadStandaloneMarket and GRetireStandalone.Values[0] then
      RunUninstaller('{#StandaloneMarketId}', True);
  end;
  SkinButtons;
end;

{ Puts our own panels back after a repaint pass has painted them page-background. }
procedure RestoreLines;
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(GLines) - 1 do
    GLines[I].Color := clLine;
end;

{ A page is restyled when it is first shown, not only at startup. Some controls are not in
  their final state during InitializeWizard. Repainting on entry is idempotent. }
procedure CurPageChanged(CurPageID: Integer);
begin
  PaintTree(WizardForm);
  RestoreLines;
  SkinButtons;
  ApplyDwm(WizardForm.Handle);
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
begin
  SkinButtons;
end;

{ ---- uninstall ------------------------------------------------------------ }

procedure InitializeUninstallProgressForm;
begin
  UninstallProgressForm.Color := clBg;
  UninstallProgressForm.Font.Color := clFg;
  PaintTree(UninstallProgressForm);
  SkinTree(UninstallProgressForm);
  SkinButtons;
  ApplyDwm(UninstallProgressForm.Handle);
end;

{
  The wallet data question.

  %APPDATA%\com.kora\kora_windows holds flutter_secure_storage.dat — the recovery phrases,
  encrypted under the app passphrase — and shared_preferences.json, which is the record of
  which wallets exist. Deleting them destroys access to any funds whose phrase is not written
  down elsewhere.

  An earlier version of this script deleted both without asking, as part of every uninstall.
  It also aimed at the userappdata root plus kora_windows, one directory short of the real
  path, so it happened to miss — the correct-looking fix to that path would have turned a
  silent no-op into silent, irreversible data loss.

  So it is asked, once, in plain words, defaulting to No.
}
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  WalletData, MarketData: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;

  WalletData := ExpandConstant('{userappdata}\com.kora\kora_windows');
  MarketData := ExpandConstant('{userappdata}\com.korawallet\kora_widget');

  { Market's settings are preferences — window position, which coins are listed. Nothing is
    lost that cannot be set again, so they go without a question. Only Market's own folder is
    removed, never the shared parent, which another Kora product may be using.

    But only if no separate KORA Market is left behind. Both binaries are the same Flutter app
    with the same company and product name, so they read one directory: uninstalling the suite
    while the standalone stays installed would have reset a program the user did not touch. }
  if DirExists(MarketData) and not Installed('{#StandaloneMarketId}') then
    DelTree(MarketData, True, True, True);

  if not DirExists(WalletData) then
    Exit;

  if MsgBox(
       'Delete your wallets from this computer?' + #13#10#13#10 +
       'KORA''s program files have been removed. Your wallets, recovery phrases and settings '
       + 'are still stored, and reinstalling KORA would find them again.' + #13#10#13#10 +
       'Choosing Yes deletes them permanently. Any wallet whose recovery phrase you have not '
       + 'written down elsewhere becomes unreachable, and the funds in it cannot be '
       + 'recovered by anyone.' + #13#10#13#10 +
       'Delete them?',
       mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
  begin
    { Asked twice, because the first answer is given while reading and the second is given
      about a decision. Only this branch may remove it. }
    if MsgBox(
         'This cannot be undone.' + #13#10#13#10 +
         'Delete every wallet and recovery phrase stored on this computer?',
         mbError, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DelTree(WalletData, True, True, True);
  end;
end;
