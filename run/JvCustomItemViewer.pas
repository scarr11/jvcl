{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvCustomItemViewer.PAS, released on 2003-12-01.

The Initial Developer of the Original Code is: Peter Th�rnqvist
All Rights Reserved.

Last Modified: 2003-12-27

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

Known Issues:
 TODO:
 * keyboard multiselect (ctrl+space)
 * caption editing
 * drag'n'drop insertion mark
 * text for imagelist viewer - DONE
 * text layout support (top, bottom) - DONE
 * drag'n'drop edge scrolling - DONE (almost, needs some tweaks to look good as well)
 * icons don't scale, should be handled differently - DONE (explicitly calls DrawIconEx)
-----------------------------------------------------------------------------}

{$I jvcl.inc}

unit JvCustomItemViewer;

interface

uses
  Windows, SysUtils, Forms, Messages, Classes, Controls,
  Graphics, StdCtrls, ComCtrls, ImgList, ExtCtrls,
  {$IFNDEF COMPILER6_UP}
  JvConsts,  // for clSkyBlue
  {$ENDIF COMPILER6_UP}
  JvExControls, JvExForms;

const
  CM_UNSELECTITEMS = WM_USER + 1;
  CM_DELETEITEM = WM_USER + 2;

type
  TJvItemViewerScrollBar = (tvHorizontal, tvVertical);
  TJvCustomItemViewer = class;

  TJvBrushPattern = class(TPersistent)
  private
    FPattern: TBitmap;
    FOddColor: TColor;
    FEvenColor: TColor;
    FActive: Boolean;
    procedure SetEvenColor(const Value: TColor);
    procedure SetOddColor(const Value: TColor);
  public
    function GetBitmap: TBitmap;
    constructor Create;
    destructor Destroy; override;

  published
    property Active: Boolean read FActive write FActive default True;
    property EvenColor: TColor read FEvenColor write SetEvenColor default clWhite;
    property OddColor: TColor read FOddColor write SetOddColor default clSkyBlue;
  end;

  // Base viewer options class. Derive from this when you need to add your own properties
  // to a viewer or publish the available ones. Declare a new Options property in
  // the viewer class (that only needs to call the inherited Options)
  // and override GetOptionsClass to return the property class type
  TJvCustomItemViewerOptions = class(TPersistent)
  private
    FVertSpacing: Integer;
    FHorzSpacing: Integer;
    FHeight: Integer;
    FWidth: Integer;
    FScrollBar: TJvItemViewerScrollBar;
    FOwner: TJvCustomItemViewer;
    FAutoCenter: Boolean;
    FSmooth: Boolean;
    FTracking: Boolean;
    FHotTrack: Boolean;
    FMultiSelect: Boolean;
    FBrushPattern: TJvBrushPattern;
    FLazyRead: Boolean;
    FAlignment: TAlignment;
    FLayout: TTextLayout;
    FShowCaptions: Boolean;
    FRightClickSelect: Boolean;
    FReduceMemoryUsage: Boolean;
    FDragAutoScroll: Boolean;
    procedure SetRightClickSelect(const Value: Boolean);
    procedure SetShowCaptions(const Value: Boolean);
    procedure SetAlignment(const Value: TAlignment);
    procedure SetLayout(const Value: TTextLayout);
    procedure SetHeight(const Value: Integer);
    procedure SetHorzSpacing(const Value: Integer);
    procedure SetScrollBar(const Value: TJvItemViewerScrollBar);
    procedure SetVertSpacing(const Value: Integer);
    procedure SetWidth(const Value: Integer);
    procedure SetAutoCenter(const Value: Boolean);
    procedure SetSmooth(const Value: Boolean);
    procedure SetTracking(const Value: Boolean);
    procedure SetHotTrack(const Value: Boolean);
    procedure SetMultiSelect(const Value: Boolean);
    procedure SetBrushPattern(const Value: TJvBrushPattern);
    procedure SetLazyRead(const Value: Boolean);
    procedure SetReduceMemoryUsage(const Value: Boolean);
  protected
    procedure Change; virtual;
  public
    constructor Create(AOwner: TJvCustomItemViewer); virtual;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
  protected
    property Owner: TJvCustomItemViewer read FOwner;
    property Alignment: TAlignment read FAlignment write SetAlignment default taCenter;
    property DragAutoScroll: Boolean read FDragAutoScroll write FDragAutoScroll default True;
    property Layout: TTextLayout read FLayout write SetLayout default tlBottom;
    property Width: Integer read FWidth write SetWidth default 120;
    property Height: Integer read FHeight write SetHeight default 120;
    property VertSpacing: Integer read FVertSpacing write SetVertSpacing default 4;
    property HorzSpacing: Integer read FHorzSpacing write SetHorzSpacing default 4;
    property ScrollBar: TJvItemViewerScrollBar read FScrollBar write SetScrollBar default tvVertical;
    property ShowCaptions: Boolean read FShowCaptions write SetShowCaptions default True;
    property LazyRead: Boolean read FLazyRead write SetLazyRead default True;
    property ReduceMemoryUsage: Boolean read FReduceMemoryUsage write SetReduceMemoryUsage default False;
    property AutoCenter: Boolean read FAutoCenter write SetAutoCenter;
    property Smooth: Boolean read FSmooth write SetSmooth default False;
    property Tracking: Boolean read FTracking write SetTracking default True;
    property HotTrack: Boolean read FHotTrack write SetHotTrack;
    property MultiSelect: Boolean read FMultiSelect write SetMultiSelect;
    property BrushPattern: TJvBrushPattern read FBrushPattern write SetBrushPattern;
    property RightClickSelect: Boolean read FRightClickSelect write SetRightClickSelect default False;
  end;

  TJvItemViewerOptionsClass = class of TJvCustomItemViewerOptions;

  TJvViewerItem = class(TPersistent)
  private
    FOwner: TJvCustomItemViewer;
    FData: Pointer;
    FState: TCustomDrawState;
    FDeleting: Boolean;
    procedure SetData(const Value: Pointer);
    procedure SetState(const Value: TCustomDrawState);
  protected
    function Changing: Boolean; virtual;
    procedure Changed; virtual;
    procedure ReduceMemoryUsage; virtual;
  public
    constructor Create(AOwner: TJvCustomItemViewer); virtual;
    procedure Delete;
  protected
    property Deleting: Boolean read FDeleting;
    property Owner: TJvCustomItemViewer read FOwner;
  public
    property State: TCustomDrawState read FState write SetState;
    property Data: Pointer read FData write SetData;
  end;

  TJvViewerItemClass = class of TJvViewerItem;

  // TODO
  TJvViewerDrawStage = (vdsBeforePaint, vdsAfterPaint);
  TJvViewerAdvancedDrawEvent = procedure(Sender: TObject; Stage: TJvViewerDrawStage;
    Canvas: TCanvas; R: TRect; var DefaultDraw: Boolean) of object;
  TJvViewerAdvancedItemDrawEvent = procedure(Sender: TObject; Stage: TJvViewerDrawStage;
    Index: Integer; State: TCustomDrawState; Canvas: TCanvas; ItemRect, TextRect: TRect;
    var DefaultDraw: Boolean) of object;

  TJvViewerItemDrawEvent = procedure(Sender: TObject; Index: Integer; State: TCustomDrawState;
    Canvas: TCanvas; ItemRect, TextRect: TRect) of object;
  TJvViewerItemChangingEvent = procedure(Sender: TObject; Item: TJvViewerItem; var Allow: Boolean) of object;
  TJvViewerItemChangedEvent = procedure(Sender: TObject; Item: TJvViewerItem) of object;

  TJvCustomItemViewer = class(TJvExScrollingWinControl)
  private
    FCanvas: TCanvas;
    FItems: TList;
    FOptions: TJvCustomItemViewerOptions;
    FTopLeft: TPoint;
    FItemSize: TSize;
    FOnDrawItem: TJvViewerItemDrawEvent;
    FDragImages: TDragImageList;
    FUpdateCount, FCols, FRows, FTempSelected, FSelectedIndex, FLastHotTrack: Integer;
    FBorderStyle: TBorderStyle;
    FTopLeftIndex: Integer;
    FBottomRightIndex: Integer;
    FOnScroll: TNotifyEvent;
    FOnOptionsChanged: TNotifyEvent;
    FOnItemChanged: TJvViewerItemChangedEvent;
    FOnItemChanging: TJvViewerItemChangingEvent;
    FScrollTimer: TTimer;
    ScrollEdge: Integer;
    procedure DoScrollTimer(Sender: TObject);

    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMNCHitTest(var Message: TMessage); message WM_NCHITTEST;
    procedure WMLButtonUp(var Message: TWMLButtonUp); message WM_LBUTTONUP;
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMRButtonDown(var Message: TWMRButtonDown); message WM_RBUTTONDOWN;
    procedure WMCancelMode(var Message: TWMCancelMode); message WM_CANCELMODE;

    procedure CMUnselectItem(var Message: TMessage); message CM_UNSELECTITEMS;
    procedure CMDeleteItem(var Message: TMessage); message CM_DELETEITEM;
    procedure CMCtl3DChanged(var Message: TMessage); message CM_CTL3DCHANGED;

    procedure SetOptions(const Value: TJvCustomItemViewerOptions);
    function GetItems(Index: Integer): TJvViewerItem;
    procedure SetItems(Index: Integer; const Value: TJvViewerItem);
    procedure SetSelectedIndex(const Value: Integer);
    procedure SetBorderStyle(const Value: TBorderStyle);
    function GetCount: Integer;
    procedure SetCount(const Value: Integer);
    function GetSelected(Item: TJvViewerItem): Boolean;
    procedure SetSelected(Item: TJvViewerItem; const Value: Boolean);
    procedure StopScrollTimer;
  protected
    procedure MouseLeave(Control: TControl); override;
    procedure DoGetDlgCode(var Code: TDlgCodes); override;
    procedure Resize; override;
    procedure DoSetFocus(APreviousControl: TWinControl); override;

    procedure DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean); override;
    procedure DoEndDrag(Sender: TObject; X, Y: Integer); override;
    procedure DragCanceled; override;

    procedure DoUnSelectItems(ExcludeIndex: Integer);
    procedure ToggleSelection(Index: Integer; SetSelection: Boolean);
    procedure ShiftSelection(Index: Integer; SetSelection: Boolean);
    procedure ScrollIntoView(Index: Integer);
    function FindFirstSelected: Integer;
    function FindLastSelected: Integer;
    procedure UpdateAll;
    procedure UpdateOffset;
    procedure CalcIndices;
    procedure DoReduceMemory;

    procedure CheckHotTrack;
    procedure InvalidateClipRect(R: TRect);
    function ItemRect(Index: Integer; IncludeSpacing: Boolean): TRect;
    function ColRowToIndex(ACol, ARow: Integer): Integer;
    procedure OptionsChanged;
    procedure Changed;

    function GetTextRect(const S: string; var ItemRect: TRect): TRect; virtual;
    function GetTextHeight: Integer; virtual;
    function GetDragImages: TDragImageList; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; virtual;
    procedure PaintWindow(DC: HDC); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure IndexToColRow(Index: Integer; var ACol, ARow: Integer);
    procedure DrawItem(Index: Integer; State: TCustomDrawState; Canvas: TCanvas; ItemRect, TextRect: TRect); virtual;
    function GetItemClass: TJvViewerItemClass; virtual;
    function GetOptionsClass: TJvItemViewerOptionsClass; virtual;
    function GetItemState(Index: Integer): TCustomDrawState; virtual;
    procedure ItemChanging(Item: TJvViewerItem; var AllowChange: Boolean); virtual;
    procedure ItemChanged(Item: TJvViewerItem); virtual;

    property TopLeftIndex: Integer read FTopLeftIndex;
    property BottomRightIndex: Integer read FBottomRightIndex;
    property UpdateCount: Integer read FUpdateCount;

    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property ParentColor default False;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property Selected[Item: TJvViewerItem]: Boolean read GetSelected write SetSelected;
    property Canvas: TCanvas read FCanvas;
    property Options: TJvCustomItemViewerOptions read FOptions write SetOptions;
    property Count: Integer read GetCount write SetCount;
    property Items[Index: Integer]: TJvViewerItem read GetItems write SetItems;
    property ItemSize: TSize read FItemSize;
    property OnDrawItem: TJvViewerItemDrawEvent read FOnDrawItem write FOnDrawItem;
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
    property OnOptionsChanged: TNotifyEvent read FOnOptionsChanged write FOnOptionsChanged;
    property OnItemChanging: TJvViewerItemChangingEvent read FOnItemChanging write FOnItemChanging;
    property OnItemChanged: TJvViewerItemChangedEvent read FOnItemChanged write FOnItemChanged;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure SelectAll;
    procedure SelectItems(StartIndex, EndIndex: Integer; AppendSelection: Boolean);
    procedure UnselectItems(StartIndex, EndIndex: Integer);
    procedure Clear;
    function Add(AItem: TJvViewerItem): Integer;
    procedure Insert(Index: Integer; AItem: TJvViewerItem);
    procedure Delete(Index: Integer);
    function IndexOf(Item: TJvViewerItem): Integer;
    function ItemAtPos(X, Y: Integer; Existing: Boolean): Integer; virtual;
  end;

  // Creates a 8x8 brush pattern with alternate odd and even colors
  // If the pattern already exists, no new pattern is created. Instead, the previous pattern is resued.
  // NB! Do *not* free the returned TBitmap! It is freed when the unit is finalized or when ClearBrushPatterns
  // is called
function CreateBrushPattern(const EvenColor: TColor = clWhite; const OddColor: TColor = clBtnFace): TBitmap;
// Decrements the reference count for a particular brush pattern. When the ref
// count reaches 0, the pattern is released
procedure ReleasePattern(EvenColor, OddColor: TColor);

// Clears the internal list of brush patterns.
// You don't have to call this procedure unless your program uses a lot of brush patterns
// that are only used short times
procedure ClearBrushPatterns;

function ViewerDrawText(Canvas: TCanvas; S: PChar; aLength: Integer;
  var R: TRect; Format: Cardinal; Alignment: TAlignment; Layout: TTextLayout; WordWrap: Boolean): Integer;
function CenterRect(InnerRect, OuterRect: TRect): TRect;

implementation

uses
  Math,
  JvJCLUtils, JvJVCLUtils;

const
  cScrollDelay = 400;
  cScrollIntervall = 30;

type
  TScrollEdge = (seNone, seLeft, seTop, seRight, seBottom);
  TColorPattern = record
    EvenColor, OddColor: TColor;
    UsageCount: Integer;
    Bitmap: TBitmap;
  end;

  TViewerDrawImageList = class(TDragImageList)
  protected
    procedure Initialize; override;
  end;

var
  __Patterns: array of TColorPattern;

procedure ReleasePattern(EvenColor, OddColor: TColor);
var
  i: Integer;
begin
  for i := 0 to Length(__Patterns) - 1 do
    if (__Patterns[i].EvenColor = EvenColor) and (__Patterns[i].OddColor = OddColor) then
    begin
      if __Patterns[i].UsageCount > 0 then
        Dec(__Patterns[i].UsageCount);
      if __Patterns[i].UsageCount = 0 then
        FreeAndNil(__Patterns[i].Bitmap);
      Break;
    end;
end;

procedure ClearBrushPatterns;
var
  i: Integer;
begin
  for i := 0 to Length(__Patterns) - 1 do
    __Patterns[i].Bitmap.Free;
  SetLength(__Patterns, 0);
end;

function CreateBrushPattern(const EvenColor: TColor = clWhite; const OddColor: TColor = clBtnFace):
  TBitmap;
var
  i, X, Y: Integer;
  Found: Boolean;
begin
  Found := False;
  Result := nil;
  for i := 0 to Length(__Patterns) - 1 do
    if (__Patterns[i].EvenColor = EvenColor) and (__Patterns[i].OddColor = OddColor) then
    begin
      Result := __Patterns[i].Bitmap;
      Found := True;
      Break;
    end;

  if not Found then
  begin
    i := Length(__Patterns);
    SetLength(__Patterns, i + 1);
  end;
  if Result = nil then
  begin
    Result := TBitmap.Create;
    Result.Dormant; // preserve some DDB handles, use more memory
    Result.Width := 8; { must have this size }
    Result.Height := 8;
    with Result.Canvas do
    begin
      Brush.Style := bsSolid;
      Brush.Color := EvenColor;
      FillRect(Rect(0, 0, Result.Width, Result.Height));
      for Y := 0 to 7 do
        for X := 0 to 7 do
          if (Y mod 2) = (X mod 2) then { toggles between even/odd pixles }
            Pixels[X, Y] := OddColor; { on even/odd rows }
    end;
    __Patterns[i].EvenColor := EvenColor;
    __Patterns[i].OddColor := OddColor;
    __Patterns[i].Bitmap := Result;
  end;
  Inc(__Patterns[i].UsageCount);
end;

function ViewerDrawText(Canvas: TCanvas; S: PChar; aLength: Integer;
  var R: TRect; Format: Cardinal; Alignment: TAlignment; Layout: TTextLayout; WordWrap: Boolean): Integer;
const
  Alignments: array[TAlignment] of Cardinal = (DT_LEFT, DT_RIGHT, DT_CENTER);
  Layouts: array[TTextLayout] of Cardinal = (DT_TOP, DT_VCENTER, DT_BOTTOM);
  WordWraps: array[Boolean] of Cardinal = (DT_SINGLELINE, DT_WORDBREAK);
var
  Flags: Cardinal;
begin
  Flags := Format or Alignments[Alignment] or Layouts[Layout] or WordWraps[WordWrap];
  // (p3) Do we need BiDi support here?
  Result := DrawText(Canvas.Handle, S, aLength, R, Flags);
end;

function CenterRect(InnerRect, OuterRect: TRect): TRect;
begin
  OffsetRect(InnerRect, -InnerRect.Left + OuterRect.Left + (RectWidth(OuterRect) - RectWidth(InnerRect)) div 2,
    -InnerRect.Top + OuterRect.Top + (RectHeight(OuterRect) - RectHeight(InnerRect)) div 2);
  Result := InnerRect;
end;

{ TJvBrushPattern }

constructor TJvBrushPattern.Create;
begin
  inherited Create;
  FEvenColor := clWhite;
  FOddColor := clSkyBlue;
  FActive := True;
end;

destructor TJvBrushPattern.Destroy;
begin
  if FPattern <> nil then
    ReleasePattern(EvenColor, OddColor);
  FPattern := nil;
  inherited;
end;

function TJvBrushPattern.GetBitmap: TBitmap;
begin
  if Active then
  begin
    if FPattern = nil then
      FPattern := CreateBrushPattern(EvenColor, OddColor);
  end
  else
  begin
    if FPattern <> nil then
      ReleasePattern(EvenColor, OddColor);
    FPattern := nil;
  end;
  Result := FPattern;
end;

procedure TJvBrushPattern.SetEvenColor(const Value: TColor);
begin
  if FEvenColor <> Value then
  begin
    if FPattern <> nil then
      ReleasePattern(EvenColor, OddColor);
    FEvenColor := Value;
    FPattern := nil;
  end;
end;

procedure TJvBrushPattern.SetOddColor(const Value: TColor);
begin
  if FOddCOlor <> Value then
  begin
    if FPattern <> nil then
      ReleasePattern(EvenColor, OddColor);
    FOddColor := Value;
    FPattern := nil;
  end;
end;

{ TJvCustomItemViewerOptions }

procedure TJvCustomItemViewerOptions.Assign(Source: TPersistent);
begin
  if (Source is TJvCustomItemViewerOptions) and (Source <> Self) then
  begin
    FWidth := TJvCustomItemViewerOptions(Source).Width;
    FHeight := TJvCustomItemViewerOptions(Source).Height;
    FVertSpacing := TJvCustomItemViewerOptions(Source).VertSpacing;
    FHorzSpacing := TJvCustomItemViewerOptions(Source).HorzSpacing;
    FScrollBar := TJvCustomItemViewerOptions(Source).ScrollBar;
    FAutoCenter := TJvCustomItemViewerOptions(Source).AutoCenter;
    FSmooth := TJvCustomItemViewerOptions(Source).Smooth;
    FTracking := TJvCustomItemViewerOptions(Source).Tracking;
    FHotTrack := TJvCustomItemViewerOptions(Source).HotTrack;
    FMultiSelect := TJvCustomItemViewerOptions(Source).MultiSelect;
    BrushPattern.FEvenColor := BrushPattern.EvenColor;
    BrushPattern.FOddColor := BrushPattern.OddColor;
    BrushPattern.FActive := BrushPattern.Active;
    Change;
    Exit;
  end;
  inherited;
end;

procedure TJvCustomItemViewerOptions.Change;
begin
  if FOwner <> nil then
    FOwner.OptionsChanged;
end;

constructor TJvCustomItemViewerOptions.Create(AOwner: TJvCustomItemViewer);
begin
  inherited Create;
  FOwner := AOwner;
  FWidth := 120;
  FHeight := 120;
  FVertSpacing := 4;
  FHorzSpacing := 4;
  FScrollBar := tvVertical;
  FSmooth := False;
  FTracking := True;
  FLazyRead := True;
  FShowCaptions := False;
  FAlignment := taCenter;
  FLayout := tlBottom;
  FDragAutoScroll := True;
  FBrushPattern := TJvBrushPattern.Create;
end;

destructor TJvCustomItemViewerOptions.Destroy;
begin
  FBrushPattern.Free;
  inherited;
end;

procedure TJvCustomItemViewerOptions.SetAlignment(const Value: TAlignment);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    if ShowCaptions then
      Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetAutoCenter(const Value: Boolean);
begin
  if FAutoCenter <> Value then
  begin
    FAutoCenter := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetBrushPattern(
  const Value: TJvBrushPattern);
begin
  //  FBrushPattern := Value;
end;

procedure TJvCustomItemViewerOptions.SetHeight(const Value: Integer);
begin
  if FHeight <> Value then
  begin
    FHeight := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetHorzSpacing(const Value: Integer);
begin
  if FHorzSpacing <> Value then
  begin
    FHorzSpacing := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetHotTrack(const Value: Boolean);
begin
  if FHotTrack <> Value then
  begin
    FHotTrack := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetLayout(const Value: TTextLayout);
begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    if ShowCaptions then
      Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetLazyRead(const Value: Boolean);
begin
  if LazyRead <> Value then
  begin
    FLazyRead := Value;
    if not FLazyRead then
      FReduceMemoryUsage := False;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetMultiSelect(const Value: Boolean);
begin
  if FMultiSelect <> Value then
  begin
    FMultiSelect := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetReduceMemoryUsage(
  const Value: Boolean);
begin
  if FReduceMemoryUsage <> Value then
  begin
    FReduceMemoryUsage := Value;
    if FReduceMemoryUsage then
    begin
      FLazyRead := True;
      FOwner.DoReduceMemory;
    end;
  end;
end;

procedure TJvCustomItemViewerOptions.SetRightClickSelect(const Value: Boolean);
begin
  FRightClickSelect := Value;
  // no need to tell owner
end;

procedure TJvCustomItemViewerOptions.SetScrollBar(const Value: TJvItemViewerScrollBar);
begin
  if FScrollBar <> Value then
  begin
    FScrollBar := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetShowCaptions(const Value: Boolean);
begin
  if FShowCaptions <> Value then
  begin
    FShowCaptions := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetSmooth(const Value: Boolean);
begin
  if FSmooth <> Value then
  begin
    FSmooth := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetTracking(const Value: Boolean);
begin
  if FTracking <> Value then
  begin
    FTracking := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetVertSpacing(const Value: Integer);
begin
  if FVertSpacing <> Value then
  begin
    FVertSpacing := Value;
    Change;
  end;
end;

procedure TJvCustomItemViewerOptions.SetWidth(const Value: Integer);
begin
  if FWidth <> Value then
  begin
    FWidth := Value;
    Change;
  end;
end;

{ TJvViewerItem }

procedure TJvViewerItem.Changed;
begin
  if FOwner <> nil then
    FOwner.ItemChanged(Self);
end;

function TJvViewerItem.Changing: Boolean;
begin
  Result := True;
  if FOwner <> nil then
    FOwner.ItemChanging(Self, Result);
end;

constructor TJvViewerItem.Create(AOwner: TJvCustomItemViewer);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TJvViewerItem.Delete;
begin
  if FOwner <> nil then
  begin
    FDeleting := True;
    PostMessage(FOwner.Handle, CM_DELETEITEM, Integer(Self), 0);
  end;
end;

procedure TJvViewerItem.ReduceMemoryUsage;
begin
  // override to perform whatever you can to reduce the memory usage
end;

procedure TJvViewerItem.SetData(const Value: Pointer);
begin
  if (FData <> Value) and Changing then
  begin
    FData := Value;
    Changed;
  end;
end;

procedure TJvViewerItem.SetState(const Value: TCustomDrawState);
begin
  if (FState <> Value) and Changing then
  begin
    FState := Value;
    Changed;
  end;
end;

{ TJvCustomItemViewer }

function TJvCustomItemViewer.Add(AItem: TJvViewerItem): Integer;
begin
  Assert(AItem is GetItemClass);
  Result := FItems.Add(AItem);
end;

procedure TJvCustomItemViewer.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TJvCustomItemViewer.CalcIndices;
begin
  FTopLeftIndex := ItemAtPos(0, 0, True);
  FBottomRightIndex := ItemAtPos(ClientWidth, ClientHeight, True);
  if FBottomRightIndex < 0 then
    FBottomRightIndex := ItemAtPos(ClientWidth, ClientHeight, False) - 1;
  if FTopLeftIndex < 0 then FTopLeftIndex := 0;
  if FTopLeftIndex >= Count then FTopLeftIndex := Count - 1;
  if FBottomRightIndex < 0 then FBottomRightIndex := 0;
  if FBottomRightIndex >= Count then FBottomRightIndex := Count - 1;
  DoReduceMemory;
end;

procedure TJvCustomItemViewer.OptionsChanged;
begin
  Changed;
  if Assigned(FOnOptionsChanged) then FOnOptionsChanged(self);
end;

procedure TJvCustomItemViewer.CheckHotTrack;
var
  P: TPoint;
  i: Integer;
begin
  if Options.HotTrack and GetCursorPos(P) then
  begin
    P := ScreenToClient(P);
    if not PtInRect(ClientRect, P) then
      i := -1
    else
      i := ItemAtPos(P.X, P.Y, True);
    // remove hot track state from previous item
    if (FLastHotTrack >= 0) and (FLastHotTrack < Count) and (i <> FLastHotTrack) then
      Items[FLastHotTrack].State := Items[FLastHotTrack].State - [cdsHot];
    if (i >= 0) and (i < Count) then
    begin
      Items[i].State := Items[i].State + [cdsHot];
      FLastHotTrack := i;
    end
    else
      FLastHotTrack := -1;
  end;
end;

procedure TJvCustomItemViewer.Clear;
var
  i: Integer;
begin
  BeginUpdate;
  try
    for i := 0 to FItems.Count - 1 do
      TObject(FItems[i]).Free;
    FItems.Count := 0;
  finally
    EndUpdate;
  end;
end;

procedure TJvCustomItemViewer.CMCtl3DChanged(var Message: TMessage);
begin
  if NewStyleControls and (FBorderStyle = bsSingle) then RecreateWnd;
  inherited;
end;

procedure TJvCustomItemViewer.CMDeleteItem(var Message: TMessage);
var
  i: Integer;
begin
  i := FItems.IndexOf(TObject(Message.wParam));
  if (i >= 0) and (i < Count) then
  begin
    Delete(i);
    InvalidateClipRect(ClientRect);
  end;
end;

procedure TJvCustomItemViewer.MouseLeave(Control: TControl);
begin
  if csDesigning in ComponentState then
    Exit;
  inherited MouseLeave(Control);
  CheckHotTrack;
end;

procedure TJvCustomItemViewer.CMUnselectItem(var Message: TMessage);
var
  i: Integer;
begin
  if (Message.WParam = Integer(self)) then
  begin
    BeginUpdate;
    try
      for i := 0 to Count - 1 do
        if (Integer(Items[i]) <> Message.LParam) and (cdsSelected in
          Items[i].State) then
          Items[i].State := Items[i].State - [cdsSelected];
    finally
      EndUpdate;
    end;
  end;
end;

function TJvCustomItemViewer.ColRowToIndex(ACol, ARow: Integer): Integer;
begin
  Result := ACol + ARow * FCols
end;

constructor TJvCustomItemViewer.Create(AOwner: TComponent);
begin
  inherited;
  ParentColor := False;
  ControlStyle := [csCaptureMouse, csDisplayDragImage, csClickEvents, csOpaque, csDoubleClicks];
  FItems := TList.Create;
  FOptions := GetOptionsClass.Create(self);
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := self;
  FSelectedIndex := -1;
  FLastHotTrack := -1;
  AutoScroll := False;
  HorzScrollBar.Smooth := Options.Smooth;
  HorzScrollBar.Tracking := Options.Tracking;
  VertScrollBar.Smooth := Options.Smooth;
  VertScrollBar.Tracking := Options.Tracking;
  DoubleBuffered := True;
  FBorderStyle := bsSingle;
  Width := 185;
  Height := 150;
  TabStop := True;
end;

procedure TJvCustomItemViewer.CreateParams(var Params: TCreateParams);
const
  BorderStyles: array[TBorderStyle] of DWORD = (0, WS_BORDER);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := Style or BorderStyles[BorderStyle];
    if NewStyleControls and Ctl3D and (BorderStyle = bsSingle) then
    begin
      Style := Style and not WS_BORDER;
      ExStyle := ExStyle or WS_EX_CLIENTEDGE;
    end;
  end;
  with Params.WindowClass do
    Style := Style or (CS_HREDRAW or CS_VREDRAW) { or CS_SAVEBITS};
end;

procedure TJvCustomItemViewer.Delete(Index: Integer);
begin
  TObject(FItems[Index]).Free;
  FItems.Delete(Index);
  if SelectedIndex >= Count then
    SelectedIndex := Count - 1;
end;

destructor TJvCustomItemViewer.Destroy;
begin
  StopScrollTimer;
  Clear;
  FItems.Free;
  FOptions.Free;
  FCanvas.Free;
  inherited;
end;

function TJvCustomItemViewer.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  WD: Integer;
begin
  if not inherited DoMouseWheel(Shift, WheelDelta, MousePos) then
  begin
    if ssCtrl in Shift then
      WD := WheelDelta * 3
    else
      WD := WheelDelta;
    if Options.ScrollBar = tvHorizontal then
      HorzScrollBar.Position := HorzScrollBar.Position - WD
    else
      VertScrollBar.Position := VertScrollBar.Position - WD;
    UpdateOffset;
    Invalidate;
  end;
  Result := True;
end;

procedure TJvCustomItemViewer.DoReduceMemory;
var
  i: Integer;
begin
  if Options.ReduceMemoryUsage then
  begin
    for i := 0 to FTopLeftIndex - 1 do
      if FItems[i] <> nil then
        Items[i].ReduceMemoryUsage;
    for i := FBottomRightIndex + 1 to Count - 1 do
      if FItems[i] <> nil then
        Items[i].ReduceMemoryUsage;
  end;
end;

procedure TJvCustomItemViewer.DrawItem(Index: Integer; State: TCustomDrawState;
  Canvas: TCanvas; ItemRect, TextRect: TRect);
begin
  if Assigned(FOnDrawItem) then
    FOnDrawItem(Self, Index, State, Canvas, ItemRect, TextRect);
end;

procedure TJvCustomItemViewer.EndUpdate;
begin
  Dec(FUpdateCount);
  if FUpdateCount <= 0 then
  begin
    FUpdateCount := 0;
    UpdateAll;
    Invalidate;
  end;
end;

function TJvCustomItemViewer.FindFirstSelected: Integer;
begin
  for Result := 0 to Count - 1 do
    if cdsSelected in Items[Result].State then
      Exit;
  Result := -1;
end;

function TJvCustomItemViewer.FindLastSelected: Integer;
begin
  for Result := Count - 1 downto 0 do
    if cdsSelected in Items[Result].State then
      Exit;
  Result := -1;
end;

function TJvCustomItemViewer.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TJvCustomItemViewer.GetDragImages: TDragImageList;
var
  B: TBitmap;
  P: TPoint;
  i: Integer;
  ItemRect, TextRect: TRect;
begin
  GetCursorPos(P);
  P := ScreenToClient(P);
  i := ItemAtPos(P.X, P.Y, True);
  // create an image of the currently selected item
  if i >= 0 then
  begin
    if FDragImages = nil then
      FDragImages := TViewerDrawImageList.Create(self);
    FDragImages.Clear;
    ItemRect := Rect(0, 0, ItemSize.cx, ItemSize.cy);
    InflateRect(ItemRect, -Options.HorzSpacing, -Options.VertSpacing);
    B := TBitmap.Create;
    try
      B.Width := ItemSize.cx;
      B.Height := ItemSize.cy;
      if Options.ShowCaptions then
        TextRect := GetTextRect('Wg', ItemRect)
      else
        TextRect := Rect(0, 0, 0, 0);
      DrawItem(i, Items[i].State + [cdsSelected, cdsFocused, cdsHot], B.Canvas, ItemRect, TextRect);
      FDragImages.Width := ItemSize.cx;
      FDragImages.Height := ItemSize.cy;
      FDragImages.AddMasked(B, B.TransparentColor);
    finally
      B.Free;
    end;
    //    FDragImages.SetDragImage(0, 0, 0);
    ItemRect := self.ItemRect(i, True);
    FDragImages.SetDragImage(0, P.X - ItemRect.Left, P.Y - ItemRect.Top);
    Result := FDragImages;
    SelectedIndex := i;
    Paint;
  end
  else
    Result := inherited GetDragimages;
end;

function TJvCustomItemViewer.GetItemClass: TJvViewerItemClass;
begin
  Result := TJvViewerItem;
end;

function TJvCustomItemViewer.GetItems(Index: Integer): TJvViewerItem;
begin
  Result := FItems[Index];
  if Result = nil then
    Result := GetItemClass.Create(Self);
  FItems[Index] := Result;
end;

function TJvCustomItemViewer.GetItemState(Index: Integer): TCustomDrawState;
begin
  // (p3) safer than calling Items[Index].State directly
  if (Index >= 0) and (Index < Count) then
    Result := Items[Index].State
  else
    Result := [];
end;

function TJvCustomItemViewer.GetOptionsClass: TJvItemViewerOptionsClass;
begin
  Result := TJvCustomItemViewerOptions;
end;

function TJvCustomItemViewer.GetSelected(Item: TJvViewerItem): Boolean;
begin
  Result := (Item <> nil) and (cdsSelected in Item.State);
end;

function TJvCustomItemViewer.GetTextHeight: Integer;
var
  R: TRect;
  S: string;
begin
  S := 'Wg';
  R := Rect(0, 0, 100, 100);
  Result := ViewerDrawText(Canvas, PChar(S), Length(S),
    R, DT_END_ELLIPSIS or DT_CALCRECT, taCenter, tlTop, False) + 4;
  //  Result := Canvas.TextHeight('Wg');
end;

function TJvCustomItemViewer.GetTextRect(const S: string; var ItemRect: TRect): TRect;
var
  TextHeight: Integer;
begin
  TextHeight := GetTextHeight;

  case Options.Layout of
    tlTop:
      begin
        Result := Rect(ItemRect.Left, ItemRect.Top, ItemRect.Right, ItemRect.Top + TextHeight);
        ItemRect.Top := Result.Top + TextHeight;
      end;
    tlBottom:
      begin
        Result := Rect(ItemRect.Left, ItemRect.Bottom - TextHeight,
          ItemRect.Right, ItemRect.Bottom);
        ItemRect.Bottom := Result.Top;
      end;
    tlCenter:
      begin
        Result := Rect(ItemRect.Left, ItemRect.Top + (RectHeight(ItemRect) - TextHeight) div 2 + 1,
          ItemRect.Right, 0);
        Result.Bottom := Result.Top + TextHeight;
      end;
  end;
end;

function TJvCustomItemViewer.IndexOf(Item: TJvViewerItem): Integer;
begin
  // (p3) need to do it like this because items aren't created until Items[] is called
  for Result := 0 to Count - 1 do
    if Items[Result] = Item then Exit;
  Result := -1;
end;

procedure TJvCustomItemViewer.IndexToColRow(Index: Integer; var ACol, ARow: Integer);
begin
  Assert(FCols > 0);
  ACol := Index mod FCols;
  ARow := Index div FCols;
end;

procedure TJvCustomItemViewer.Insert(Index: Integer; AItem: TJvViewerItem);
begin
  Assert(AItem is GetItemClass);
  FItems.Insert(Index, AItem);
end;

procedure TJvCustomItemViewer.InvalidateClipRect(R: TRect);
begin
  if IsRectEmpty(R) then
    R := Canvas.ClipRect;
  InvalidateRect(Handle, @R, True);
end;

function TJvCustomItemViewer.ItemAtPos(X, Y: Integer; Existing: Boolean): Integer;
var
  ARow, ACol: Integer;
begin
  Result := -1;
  if (FItemSize.cx < 1) or (FItemSize.cy < 1) then Exit;
  Dec(X, FTopLeft.X);
  Dec(Y, FTopLeft.Y);
  ACol := X div FItemSize.cx;
  ARow := Y div FItemSize.cy;
  if ((ACol < 0) or (ARow < 0) or (ACol >= FCols) or (ARow >= FRows)) and Existing then
    Exit;
  Result := ColRowToIndex(ACol, ARow);
  if (Result >= Count) and Existing then Result := -1;
end;

procedure TJvCustomItemViewer.ItemChanged(Item: TJvViewerItem);
var
  i: Integer;
begin
  if FUpdateCount <> 0 then Exit;
  if (Item <> nil) then
  begin
    i := FItems.IndexOf(Item);
    if i > -1 then
    begin
      if (cdsSelected in Item.State) and not Options.MultiSelect then
        FSelectedIndex := i;
      InvalidateClipRect(ItemRect(i, True));
    end;
  end
  else
    Changed;
  if Assigned(FOnItemChanged) then
    FOnItemChanged(self, Item);
end;

procedure TJvCustomItemViewer.ItemChanging(Item: TJvViewerItem;
  var AllowChange: Boolean);
begin
  AllowChange := True;
  if Assigned(FOnItemChanging) then
    FOnItemChanging(self, Item, AllowChange);
end;

function TJvCustomItemViewer.ItemRect(Index: Integer; IncludeSpacing: Boolean): TRect;
var
  ACol, ARow: Integer;
begin
  IndexToColRow(Index, ACol, ARow);
  if (Index < 0) or (Index >= Count) then
  begin
    Result := Rect(0, 0, 0, 0);
    Exit;
  end;
  Result := Rect(0, 0, FItemSize.cx, FItemSize.cy);
  OffsetRect(Result, FTopLeft.X + FItemSize.cx * ACol,
    FTopLeft.Y + FItemSize.cy * ARow);
  if not IncludeSpacing then
    InflateRect(Result, -Options.HorzSpacing, -Options.VertSpacing);
end;

procedure TJvCustomItemViewer.KeyDown(var Key: Word; Shift: TShiftState);
var
  aIndex: Integer;
begin
  inherited;
  aIndex := -1;
  if Focused then
    case Key of
      VK_UP:
        aIndex := SelectedIndex - FCols;
      VK_DOWN:
        aIndex := SelectedIndex + FCols;
      VK_LEFT:
        aIndex := SelectedIndex - 1;
      VK_RIGHT:
        aIndex := SelectedIndex + 1;
      VK_SPACE:
        Click;
    end;
  if (aIndex >= 0) and (aIndex < Count) then
  begin
    if Options.MultiSelect then
      DoUnSelectItems(aIndex);
    SelectedIndex := aIndex;
    ScrollIntoView(aIndex);
  end;
end;

procedure TJvCustomItemViewer.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  CheckHotTrack;
end;

procedure TJvCustomItemViewer.Paint;
var
  i: Integer;
  ItemRect, TextRect, AClientRect: TRect;

  function IsRectVisible(const R: TRect): Boolean;
  begin
    Result := (R.Top < AClientRect.Bottom) and (R.Bottom > AClientRect.Top) and
      (R.Left < AClientRect.Right) and (R.Right > AClientRect.Left)
  end;
begin
  //  inherited;
  if FUpdateCount <> 0 then Exit;
  AClientRect := ClientRect;
  Canvas.Brush.Color := Color;
  Canvas.Pen.Color := Font.Color;
  Canvas.Font := Font;
  //  Canvas.FillRect(Canvas.ClipRect);
  if (FUpdateCount <> 0) or (Count = 0) or (ClientWidth <= 0)
    or (ClientHeight <= 0) or (FItemSize.cx <= 0) or (FItemSize.cy <= 0) then
    Exit;
  ItemRect := Rect(0, 0, ItemSize.cx, ItemSize.cy);
  InflateRect(ItemRect, -Options.HorzSpacing, -Options.VertSpacing);
  if Options.ShowCaptions then
  begin
    TextRect := GetTextRect('Wg', ItemRect);
    OffsetRect(TextRect, FTopLeft.X, FTopLeft.Y);
  end
  else
    TextRect := Rect(0, 0, 0, 0);
  OffsetRect(ItemRect, FTopLeft.X, FTopLeft.Y);
  //  Canvas.FillRect(Rect(Left, Top, Width, Height));
  for i := 0 to Count - 1 do
  begin
    if not Items[i].Deleting then
    begin
      if not Options.LazyRead or IsRectVisible(ItemRect) then
        DrawItem(i, GetItemState(i), Canvas, ItemRect, TextRect);
      if (i + 1) mod FCols = 0 then
      begin
        OffsetRect(ItemRect, -ItemRect.Left + Options.HorzSpacing + FTopLeft.X, ItemSize.cy);
        if Options.ShowCaptions then
          OffsetRect(TextRect, -TextRect.Left + Options.HorzSpacing + FTopLeft.X, ItemSize.cy);
      end
      else
      begin
        OffsetRect(ItemRect, ItemSize.cx, 0);
        if Options.ShowCaptions then
          OffsetRect(TextRect, ItemSize.cx, 0);
      end;
    end;
  end;
end;

procedure TJvCustomItemViewer.PaintWindow(DC: HDC);
begin
  FCanvas.Lock;
  try
    FCanvas.Handle := DC;
    try
      TControlCanvas(FCanvas).UpdateTextFlags;
      Paint;
    finally
      FCanvas.Handle := 0;
    end;
  finally
    FCanvas.Unlock;
  end;
end;

procedure TJvCustomItemViewer.ScrollIntoView(Index: Integer);
var
  Rect: TRect;
begin
  Rect := ItemRect(Index, True);
  Dec(Rect.Left, HorzScrollBar.Margin);
  Inc(Rect.Right, HorzScrollBar.Margin);
  Dec(Rect.Top, VertScrollBar.Margin);
  Inc(Rect.Bottom, VertScrollBar.Margin);
  if Rect.Left < 0 then
    with HorzScrollBar do
      Position := Position + Rect.Left
  else if Rect.Right > ClientWidth then
  begin
    if Rect.Right - Rect.Left > ClientWidth then
      Rect.Right := Rect.Left + ClientWidth;
    with HorzScrollBar do
      Position := Position + Rect.Right - ClientWidth;
  end;
  if Rect.Top < 0 then
    with VertScrollBar do
      Position := Position + Rect.Top
  else if Rect.Bottom > ClientHeight then
  begin
    if Rect.Bottom - Rect.Top > ClientHeight then
      Rect.Bottom := Rect.Top + ClientHeight;
    with VertScrollBar do
      Position := Position + Rect.Bottom - ClientHeight;
  end;
  UpdateAll;
  Invalidate;
end;

procedure TJvCustomItemViewer.SetBorderStyle(const Value: TBorderStyle);
begin
  if Value <> FBorderStyle then
  begin
    FBorderStyle := Value;
    RecreateWnd;
  end;
end;

procedure TJvCustomItemViewer.SetCount(const Value: Integer);
var
  i: Integer;
  Obj: TJvViewerItem;
begin
  if Value <> Count then
  begin
    BeginUpdate;
    try
      if Value = 0 then
        Clear
      else
      begin
        for i := FItems.Count - 1 downto Value - 1 do
        begin
          Obj := TJvViewerItem(FItems[i]);
          FItems[i] := nil; // avoid concurrent access to a destroying item
          FreeAndNil(Obj);
        end;
        FItems.Count := Value;
        // (p3) new items are nil, but that's OK because we create them as needed
      end;
      if FSelectedIndex >= Value then
        FSelectedIndex := -1;
    finally
      EndUpdate;
      UpdateAll;
      if HandleAllocated then
        InvalidateClipRect(Canvas.ClipRect);
    end;
  end;
end;

procedure TJvCustomItemViewer.SetItems(Index: Integer;
  const Value: TJvViewerItem);
var
  Item: TJvViewerItem;
begin
  Item := FItems[Index];
  if Item <> Value then
  begin
    if Item = nil then
      Item := GetItemClass.Create(Self);
    Item.Assign(Value);
    FItems[Index] := Item;
    Changed;
  end;
end;

procedure TJvCustomItemViewer.SetOptions(const Value: TJvCustomItemViewerOptions);
begin
  FOptions.Assign(Value);
  Changed;
end;

procedure TJvCustomItemViewer.SetSelected(Item: TJvViewerItem;
  const Value: Boolean);
begin
  if (Item <> nil) and not (cdsSelected in Item.State) then
    Item.State := Item.State + [cdsSelected];
end;

procedure TJvCustomItemViewer.SetSelectedIndex(const Value: Integer);
begin
  //  if (FSelectedIndex <> Value) then
  begin
    if (FSelectedIndex >= 0) and (FSelectedIndex < Count) and (cdsSelected in Items[FSelectedIndex].State) then
      Items[FSelectedIndex].State := Items[FSelectedIndex].State - [cdsSelected];

    FSelectedIndex := Value;

    if (Value >= 0) and (Value < Count) and not (cdsSelected in Items[Value].State) then
      Items[Value].State := Items[Value].State + [cdsSelected];
  end;
end;

procedure TJvCustomItemViewer.ToggleSelection(Index: Integer; SetSelection:
  Boolean);
begin
  if cdsSelected in Items[Index].State then
  begin
    Items[Index].State := Items[Index].State - [cdsSelected];
    if Index = SelectedIndex then
      SelectedIndex := FindFirstSelected;
  end
  else
  begin
    Items[Index].State := Items[Index].State + [cdsSelected];
    if SetSelection then
      FSelectedIndex := Index;
  end;
end;

procedure TJvCustomItemViewer.ShiftSelection(Index: Integer; SetSelection: Boolean);

  function InRange(Value, Min, Max: Integer): Boolean;
  begin
    Result := (Value >= Min) and (Value <= Max);
  end;

  procedure Swap(var X, Y: Integer);
  var
    i: Integer;
  begin
    i := X;
    X := Y;
    Y := i;
  end;

var
  i,
    AFromCol, AFromRow,
    AToCol, AToRow,
    ACurrCol, ACurrRow: Integer;
begin
  BeginUpdate;
  try
    if SelectedIndex < 0 then
      SelectedIndex := 0;
    IndexToColRow(SelectedIndex, AFromCol, AFromRow);
    IndexToColRow(Index, AToCol, AToRow);
    if AFromCol > AToCol then
      Swap(AFromCol, AToCol);
    if AFromRow > AToRow then
      Swap(AFromRow, AToRow);
    for i := 0 to Count - 1 do
    begin
      IndexToColRow(i, ACurrCol, ACurrRow);
      // access private variables so we don't trigger any OnChange event(s) by accident
      if InRange(ACurrCol, AFromCol, AToCol) and InRange(ACurrRow, AFromRow, AToRow) then
        Items[i].FState := Items[i].FState + [cdsSelected]
      else
        Items[i].FState := Items[i].FState - [cdsSelected];
    end;
  finally
    EndUpdate;
  end;
end;

procedure TJvCustomItemViewer.DoUnSelectItems(ExcludeIndex: Integer);
var
  Item: TJvViewerItem;
begin
  if (ExcludeIndex >= 0) and (ExcludeIndex < Count) then
    Item := Items[ExcludeIndex]
  else
    Item := nil;
  PostMessage(Handle, CM_UNSELECTITEMS, Integer(self), Integer(Item));
end;

procedure TJvCustomItemViewer.UpdateAll;
begin
  if (csDestroying in ComponentState) or (Parent = nil) then Exit;
  HandleNeeded;
  if not HandleAllocated then Exit;

  HorzScrollBar.Smooth := Options.Smooth;
  VertScrollBar.Smooth := Options.Smooth;
  HorzScrollBar.Tracking := Options.Tracking;
  VertScrollBar.Tracking := Options.Tracking;

  FItemSize.cx := Options.Width + Options.HorzSpacing;
  FItemSize.cy := Options.Height + Options.VertSpacing;
  if Options.ShowCaptions then
    Inc(FItemSize.cy, GetTextHeight);
  if (FItemSize.cy < 1) or (FItemSize.cx < 1) or (Count < 1) then Exit;
  if Options.ScrollBar = tvHorizontal then
  begin
    if Options.AutoCenter then
      FRows := ClientHeight div FItemSize.cy
    else
      FRows := (Height + FItemSize.cy div 3) div FItemSize.cy;
    if FRows > Count then FRows := Count;
    if FRows < 1 then FRows := 1;
    //    if (ClientHeight mod FItemSize.cy > FItemSize.cy div 2) then
    //      Inc(FRows);
    FCols := Count div FRows;
    if FCols < 1 then FCols := 1;
    while (FRows * FCols) < Count do
      Inc(FCols);
    HorzScrollbar.Visible := True;
    VertScrollbar.Visible := False;
  end
  else
  begin
    if Options.AutoCenter then
      FCols := ClientWidth div FItemSize.cx
    else
      FCols := (Width + FItemSize.cx div 3) div FItemSize.cx;
    if FCols > Count then FCols := Count;
    if FCols < 1 then FCols := 1;
    //    if (ClientWidth mod FItemSize.cx > FItemSize.cx div 2) then
    //      Inc(FCols);
    FRows := Count div FCols;
    if FRows < 1 then FRows := 1;
    while (FRows * FCols) < Count do
      Inc(FRows);
    HorzScrollbar.Visible := False;
    VertScrollbar.Visible := True;
  end;
  HorzScrollbar.Range := FCols * FItemSize.cx;
  VertScrollbar.Range := FRows * FItemSize.cy;
  UpdateOffset;
  CalcIndices;
  CheckHotTrack;
end;

procedure TJvCustomItemViewer.UpdateOffset;
begin
  if Options.AutoCenter then
  begin
    FTopLeft.X := (ClientWidth - FCols * FItemSize.cx) div 2;
    FTopLeft.Y := (ClientHeight - FRows * FItemSize.cy) div 2;
  end
  else
  begin
    FTopLeft.X := Options.HorzSpacing div 2;
    FTopLeft.Y := Options.VertSpacing div 2;
  end;
  if FTopLeft.X < Options.HorzSpacing div 2 then
    FTopLeft.X := Options.HorzSpacing div 2;
  if FTopLeft.Y < Options.VertSpacing div 2 then
    FTopLeft.Y := Options.VertSpacing div 2;
  if HorzScrollBar.Visible then
    Dec(FTopLeft.X, HorzScrollBar.Position);
  if VertScrollBar.Visible then
    Dec(FTopLeft.Y, VertScrollBar.Position);
end;

procedure TJvCustomItemViewer.DoGetDlgCode(var Code: TDlgCodes);
begin
  Code := [dcWantArrows];
end;

procedure TJvCustomItemViewer.WMHScroll(var Message: TWMHScroll);
begin
  inherited;
  UpdateAll;
  InvalidateClipRect(ClientRect);
  if Assigned(FOnScroll) then FOnScroll(self);
end;

procedure TJvCustomItemViewer.WMLButtonDown(var Message: TWMLButtonDown);
var
  P: TPoint;
begin
  with Message do
  begin
    P := SmallPointToPoint(Pos);
    FTempSelected := ItemAtPos(P.X, P.Y, True);
    if CanFocus then SetFocus;
  end;
  inherited;
end;

procedure TJvCustomItemViewer.WMLButtonUp(var Message: TWMLButtonUp);
var
  P: TPoint;
  i: Integer;
begin
  with Message do
  begin
    P := SmallPointToPoint(Pos);
    i := ItemAtPos(P.X, P.Y, True);
    if (i = FTempSelected) and (i >= 0) and (i < Count) then
    begin
      if Options.MultiSelect then
      begin
        if (ssCtrl in KeysToShiftState(Keys)) then
          ToggleSelection(FTempSelected, True)
        else if ssShift in KeysToShiftState(Keys) then
          ShiftSelection(FTempSelected, True)
        else
        begin
          DoUnSelectItems(FTempSelected);
          SelectedIndex := FTempSelected;
          Invalidate;
        end;
      end
      else
        SelectedIndex := FTempSelected;
    end
    else if i < 0 then
      //    begin
      DoUnSelectItems(-1);
    //      SelectedIndex := -1;
    //    end;
  end;
  FTempSelected := -1;
  inherited;
end;

procedure TJvCustomItemViewer.WMNCHitTest(var Message: TMessage);
begin
  // enable scroll bars at design-time
  DefaultHandler(Message);
end;

procedure TJvCustomItemViewer.WMPaint(var Message: TWMPaint);
begin
  ControlState := ControlState + [csCustomPaint];
  inherited;
  ControlState := ControlState - [csCustomPaint];
end;

procedure TJvCustomItemViewer.WMRButtonDown(var Message: TWMRButtonDown);
var
  P: TPoint;
begin
  StopScrollTimer;
  if Options.RightClickSelect then
    with Message do
    begin
      P := SmallPointToPoint(Pos);
      FTempSelected := ItemAtPos(P.X, P.Y, True);
      if CanFocus then SetFocus;
      SelectedIndex := FTempSelected;
      Invalidate;
    end;
  inherited;
end;

procedure TJvCustomItemViewer.DoSetFocus(APreviousControl: TWinControl);
begin
  inherited DoSetFocus(APreviousControl);
  if APreviousControl = Self then
  begin
    if SelectedIndex >= 0 then
      Invalidate;
  end;
end;

procedure TJvCustomItemViewer.Resize;
begin
  UpdateAll;
  if HandleAllocated then
    InvalidateClipRect(ClientRect);
  inherited Resize;
end;

procedure TJvCustomItemViewer.WMVScroll(var Message: TWMVScroll);
begin
  inherited;
  UpdateAll;
  InvalidateClipRect(ClientRect);
  if Assigned(FOnScroll) then FOnScroll(self);
end;

procedure TJvCustomItemViewer.Changed;
begin
  inherited Changed;
  if (FUpdateCount = 0) and HandleAllocated then
  begin
    UpdateAll;
    if not Options.MultiSelect then
      DoUnSelectItems(SelectedIndex);
    InvalidateClipRect(ClientRect);
  end;
end;

procedure TJvCustomItemViewer.DoScrollTimer(Sender: TObject);
var
  DoInvalidate: Boolean;
begin
  FScrollTimer.Enabled := False;
  FScrollTimer.Interval := cScrollIntervall;
  DoInvalidate := False;
  case TScrollEdge(ScrollEdge) of
    seLeft:
      if (Options.ScrollBar = tvHorizontal) and HorzScrollBar.Visible and (HorzScrollBar.Position > 0) then
        DoInvalidate := PostMessage(Handle, WM_HSCROLL, SB_LINELEFT, 0);
    seTop:
      if (Options.ScrollBar = tvVertical) and VertScrollBar.Visible and (VertScrollBar.Position > 0) then
        DoInvalidate := PostMessage(Handle, WM_VSCROLL, SB_LINELEFT, 0);
    seRight:
      if (Options.ScrollBar = tvHorizontal) and HorzScrollBar.Visible and (HorzScrollBar.Position < HorzScrollBar.Range)
        then
        DoInvalidate := PostMessage(Handle, WM_HSCROLL, SB_LINERIGHT, 0);
    seBottom:
      if (Options.ScrollBar = tvVertical) and VertScrollBar.Visible and (VertScrollBar.Position < VertScrollBar.Range)
        then
        DoInvalidate := PostMessage(Handle, WM_VSCROLL, SB_LINERIGHT, 0);
  end;
  if (ScrollEdge <> Ord(seNone)) and DoInvalidate then
    Invalidate;
  //  UpdateWindow(Handle);
  FScrollTimer.Enabled := True;
end;

procedure TJvCustomItemViewer.DragOver(Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
const
  cEdgeSize = 4;
begin
  inherited;
  if Accept and Options.DragAutoScroll then
  begin
    if X <= cEdgeSize then
      ScrollEdge := Ord(seLeft)
    else if X >= ClientWidth - cEdgeSize then
      ScrollEdge := Ord(seRight)
    else if Y <= cEdgeSize then
      ScrollEdge := Ord(seTop)
    else if Y >= CLientHeight - cEdgeSize then
      ScrollEdge := Ord(seBottom)
    else
      ScrollEdge := Ord(seNone);
    if (ScrollEdge = Ord(seNone)) and Assigned(FScrollTimer) then
      StopScrollTimer
    else if (ScrollEdge <> Ord(seNone)) and not Assigned(FScrollTimer) then
    begin
      FScrollTimer := TTimer.Create(nil);
      FScrollTimer.Enabled := False;
      FScrollTimer.Interval := cScrollDelay;
      FScrollTimer.OnTimer := DoScrollTimer;
      FScrollTimer.Enabled := True;
    end;
  end
  else
    StopScrollTimer;
end;

procedure TJvCustomItemViewer.DragCanceled;
begin
  inherited;
  StopScrollTimer;
end;

procedure TJvCustomItemViewer.DoEndDrag(Sender: TObject; X, Y: Integer);
begin
  inherited;
  StopScrollTimer;
end;

procedure TJvCustomItemViewer.WMCancelMode(var Message: TWMCancelMode);
begin
  inherited;
  StopScrollTimer;
end;

procedure TJvCustomItemViewer.StopScrollTimer;
begin
  if FScrollTimer <> nil then
  begin
    FreeAndNil(FScrollTimer);
    UpdateWindow(Handle);
  end;
end;

procedure TJvCustomItemViewer.SelectAll;
begin
  SelectItems(0, Count - 1, True);
end;

procedure TJvCustomItemViewer.SelectItems(StartIndex, EndIndex: Integer;
  AppendSelection: Boolean);
var
  i, AIndex: Integer;
begin
  AIndex := SelectedIndex;
  BeginUpdate;
  if not AppendSelection then
    DoUnselectItems(-1);
  try
    for i := Max(StartIndex, 0) to Min(Count - 1, EndIndex) do
      Items[i].FState := Items[i].FState + [cdsSelected];
    if (AIndex >= StartIndex) and (AIndex <= EndIndex) then
      FSelectedIndex := AIndex
    else
      FSelectedIndex := StartIndex;
  finally
    EndUpdate;
  end;
end;

procedure TJvCustomItemViewer.UnselectItems(StartIndex, EndIndex: Integer);
var
  i: Integer;
begin
  BeginUpdate;
  try
    for i := Max(0, StartIndex) to Min(EndIndex, Count - 1) do
      Items[i].FState := Items[i].FState - [cdsSelected];
    if (SelectedIndex >= StartIndex) and (Selectedindex <= EndIndex) then
      FSelectedIndex := FindFirstSelected;
  finally
    EndUpdate;
  end;
end;

{ TViewerDrawImageList }

procedure TViewerDrawImageList.Initialize;
begin
  inherited;
  DragCursor := crArrow;
end;

initialization
  LoadOLeDragCursors;
finalization
  ClearBrushPatterns;

end.

