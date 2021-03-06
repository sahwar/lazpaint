unit UToolSelect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, utool, utoolpolygon, utoolbasic, BGRABitmapTypes, BGRABitmap;

type

  { TToolSelectPoly }

  TToolSelectPoly = class(TToolGenericPolygon)
  protected
    function HandDrawingPolygonView({%H-}toolDest: TBGRABitmap): TRect; override;
    function FinalPolygonView(toolDest: TBGRABitmap): TRect; override;
    function GetIsSelectingTool: boolean; override;
    function GetFillColor: TBGRAPixel; override;
  end;

  { TToolSelectSpline }

  TToolSelectSpline = class(TToolGenericSpline)
  protected
    function HandDrawingPolygonView(toolDest: TBGRABitmap): TRect; override;
    function FinalPolygonView({%H-}toolDest: TBGRABitmap): TRect; override;
    function GetIsSelectingTool: boolean; override;
    function GetFillColor: TBGRAPixel; override;
  end;

  { TToolMagicWand }

  TToolMagicWand = class(TGenericTool)
  protected
    function GetIsSelectingTool: boolean; override;
    function DoToolDown(toolDest: TBGRABitmap; pt: TPoint; {%H-}ptF: TPointF;
      rightBtn: boolean): TRect; override;
  end;

  { TToolSelectionPen }

  TToolSelectionPen = class(TToolPen)
  protected
    function GetIsSelectingTool: boolean; override;
    function StartDrawing(toolDest: TBGRABitmap; ptF: TPointF; rightBtn: boolean): TRect; override;
    function ContinueDrawing(toolDest: TBGRABitmap; originF, destF: TPointF): TRect; override;
  end;

  { TToolSelectRect }

  TToolSelectRect = class(TToolRectangular)
  protected
    FCurrentBounds: TRect;
    function GetIsSelectingTool: boolean; override;
    function UpdateShape(toolDest: TBGRABitmap): TRect; override;
    function FinishShape(toolDest: TBGRABitmap): TRect; override;
    procedure PrepareDrawing(rightBtn: boolean); override;
    function BigImage: boolean;
    function ShouldFinishShapeWhenFirstMouseUp: boolean; override;
    function GetFillColor: TBGRAPixel; override;
    function GetPenColor: TBGRAPixel; override;
    function GetSelectRectMargin: single; virtual;
  public
    function Render(VirtualScreen: TBGRABitmap; VirtualScreenWidth, VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction):TRect; override;
  end;

  { TToolSelectEllipse }

  TToolSelectEllipse = class(TToolSelectRect)
  protected
    function FinishShape(toolDest: TBGRABitmap): TRect; override;
    function BorderTest(ptF: TPointF): TRectangularBorderTest; override;
    function RoundCoordinate(ptF: TPointF): TPointF; override;
    function GetSelectRectMargin: single; override;
    function GetStatusText: string; override;
  public
    function Render(VirtualScreen: TBGRABitmap; {%H-}VirtualScreenWidth, {%H-}VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction): TRect; override;
  end;

  { TToolTransformSelection }

  TToolTransformSelection = class(TGenericTransformTool)
  protected
    FKeepTransformOnDestroy: boolean;
    function GetKeepTransformOnDestroy: boolean; override;
    procedure SetKeepTransformOnDestroy(AValue: boolean); override;
  public
    procedure SelectionTransformChange;
    constructor Create(AManager: TToolManager); override;
    destructor Destroy; override;
  end;

  { TToolMoveSelection }

  TToolMoveSelection = class(TToolTransformSelection)
  protected
    handMoving: boolean;
    handOrigin: TPoint;
    function GetIsSelectingTool: boolean; override;
    function DoToolDown({%H-}toolDest: TBGRABitmap; pt: TPoint; {%H-}ptF: TPointF;
      {%H-}rightBtn: boolean): TRect; override;
    function DoToolMove({%H-}toolDest: TBGRABitmap; pt: TPoint; {%H-}ptF: TPointF): TRect; override;
    procedure DoToolMoveAfter(pt: TPoint; {%H-}ptF: TPointF); override;
  public
    function ToolUp: TRect; override;
    destructor Destroy; override;
  end;

  { TToolRotateSelection }

  TToolRotateSelection = class(TToolTransformSelection)
  protected
    class var HintShowed: boolean;
    handMoving: boolean;
    handOrigin: TPointF;
    snapRotate: boolean;
    snapAngle: single;
    FOriginalTransform: TAffineMatrix;
    FCurrentAngle: single;
    FCurrentCenter: TPointF;
    function GetIsSelectingTool: boolean; override;
    function DoToolDown({%H-}toolDest: TBGRABitmap; {%H-}pt: TPoint; ptF: TPointF;
      rightBtn: boolean): TRect; override;
    function DoToolMove({%H-}toolDest: TBGRABitmap; {%H-}pt: TPoint; ptF: TPointF): TRect; override;
    function GetStatusText: string; override;
    procedure UpdateTransform;
  public
    constructor Create(AManager: TToolManager); override;
    function ToolKeyDown(var key: Word): TRect; override;
    function ToolKeyUp(var key: Word): TRect; override;
    function ToolUp: TRect; override;
    function Render(VirtualScreen: TBGRABitmap; {%H-}VirtualScreenWidth, {%H-}VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction):TRect; override;
    destructor Destroy; override;
  end;

implementation

uses types, ugraph, LCLType, BGRATypewriter, LazPaintType, Math, BGRATransform;

{ TToolTransformSelection }

function TToolTransformSelection.GetKeepTransformOnDestroy: boolean;
begin
  result := FKeepTransformOnDestroy;
end;

procedure TToolTransformSelection.SetKeepTransformOnDestroy(AValue: boolean);
begin
  FKeepTransformOnDestroy:= AValue;
end;

procedure TToolTransformSelection.SelectionTransformChange;
var selectionChangeRect: TRect;
begin
  selectionChangeRect := Manager.Image.TransformedSelectionBounds;
  if not Manager.Image.SelectionLayerIsEmpty then
    Manager.Image.ImageMayChange(selectionChangeRect,False);
  if not IsRectEmpty(selectionChangeRect) then
  begin
    InflateRect(selectionChangeRect,1,1);
    Manager.Image.RenderMayChange(selectionChangeRect,true);
  end;
end;

constructor TToolTransformSelection.Create(AManager: TToolManager);
begin
  inherited Create(AManager);
  FKeepTransformOnDestroy:= False;
end;

destructor TToolTransformSelection.Destroy;
begin
  if not FKeepTransformOnDestroy and not IsAffineMatrixIdentity(Manager.Image.SelectionTransform) then
  begin
    Action.ApplySelectionTransform;
    ValidateAction;
  end;
  inherited Destroy;
end;

{ TToolRotateSelection }

function TToolRotateSelection.GetIsSelectingTool: boolean;
begin
  Result:= true;
end;

function TToolRotateSelection.DoToolDown(toolDest: TBGRABitmap; pt: TPoint;
  ptF: TPointF; rightBtn: boolean): TRect;
begin
  result := EmptyRect;
  if not handMoving and not Manager.Image.SelectionEmpty then
  begin
    if rightBtn then
    begin
      if FCurrentAngle <> 0 then
      begin
        SelectionTransformChange;
        FCurrentAngle := 0;
        FCurrentCenter := ptF;
        UpdateTransform;
        SelectionTransformChange;
      end else
      begin
        FCurrentAngle := 0;
        FCurrentCenter := ptF;
        UpdateTransform;
      end;
      result := OnlyRenderChange;
    end else
    begin
      handMoving := true;
      handOrigin := ptF;
    end;
  end;
end;

function TToolRotateSelection.DoToolMove(toolDest: TBGRABitmap; pt: TPoint;
  ptF: TPointF): TRect;
var angleDiff: single;
begin
  if not HintShowed then
  begin
    Manager.ToolPopup(tpmCtrlRestrictRotation);
    HintShowed:= true;
  end;
  if handMoving and ((handOrigin.X <> ptF.X) or (handOrigin.Y <> ptF.Y)) then
  begin
    SelectionTransformChange;
    angleDiff := ComputeAngle(ptF.X-FCurrentCenter.X,ptF.Y-FCurrentCenter.Y)-
                 ComputeAngle(handOrigin.X-FCurrentCenter.X,handOrigin.Y-FCurrentCenter.Y);
    if snapRotate then
    begin
      snapAngle += angleDiff;
      FCurrentAngle := round(snapAngle/15)*15;
    end
     else
       FCurrentAngle := FCurrentAngle + angleDiff;
    UpdateTransform;
    SelectionTransformChange;
    handOrigin := ptF;
    result := OnlyRenderChange;
  end else
    result := EmptyRect;
end;

function TToolRotateSelection.GetStatusText: string;
begin
  Result:= 'α = '+FloatToStrF(FCurrentAngle,ffFixed,5,1);
end;

procedure TToolRotateSelection.UpdateTransform;
begin
  Manager.Image.SelectionTransform := AffineMatrixTranslation(FCurrentCenter.X,FCurrentCenter.Y)*
                                   AffineMatrixRotationDeg(FCurrentAngle)*
                                   AffineMatrixTranslation(-FCurrentCenter.X,-FCurrentCenter.Y)*FOriginalTransform;
end;

constructor TToolRotateSelection.Create(AManager: TToolManager);
begin
  inherited Create(AManager);
  FCurrentCenter := Manager.Image.SelectionTransform * Manager.Image.GetSelectionCenter;
  FOriginalTransform := Manager.Image.SelectionTransform;
  FCurrentAngle := 0;
end;

function TToolRotateSelection.ToolKeyDown(var key: Word): TRect;
begin
  result := EmptyRect;
  if key = VK_CONTROL then
  begin
    if not snapRotate then
    begin
      snapRotate := true;
      snapAngle := FCurrentAngle;

      if handMoving then
      begin
        SelectionTransformChange;
        FCurrentAngle := round(snapAngle/15)*15;
        UpdateTransform;
        SelectionTransformChange;
        result := OnlyRenderChange;
      end;
    end;
    Key := 0;
  end else
  if key = VK_ESCAPE then
  begin
    if FCurrentAngle <> 0 then
    begin
      SelectionTransformChange;
      FCurrentAngle := 0;
      UpdateTransform;
      SelectionTransformChange;
      result := OnlyRenderChange;
    end else
    begin
      FCurrentAngle := 0;
      UpdateTransform;
      result := OnlyRenderChange;
    end;
    Key := 0;
  end;
end;

function TToolRotateSelection.ToolKeyUp(var key: Word): TRect;
begin
  if key = VK_CONTROL then
  begin
    snapRotate := false;
    Key := 0;
  end;
  result := EmptyRect;
end;

function TToolRotateSelection.ToolUp: TRect;
begin
  handMoving:= false;
  Result:= EmptyRect;
end;

function TToolRotateSelection.Render(VirtualScreen: TBGRABitmap;
  VirtualScreenWidth, VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction): TRect;
var pictureRotateCenter: TPointF;
begin
  pictureRotateCenter := BitmapToVirtualScreen(FCurrentCenter);
  result := NicePoint(VirtualScreen, pictureRotateCenter.X,pictureRotateCenter.Y);
end;

destructor TToolRotateSelection.Destroy;
begin
  if handMoving then handMoving := false;
  inherited Destroy;
end;

{ TToolMoveSelection }

function TToolMoveSelection.GetIsSelectingTool: boolean;
begin
  result := true;
end;

function TToolMoveSelection.DoToolDown(toolDest: TBGRABitmap; pt: TPoint;
  ptF: TPointF; rightBtn: boolean): TRect;
begin
  if not handMoving then
  begin
    handMoving := true;
    handOrigin := pt;
  end;
  result := EmptyRect;
end;

function TToolMoveSelection.DoToolMove(toolDest: TBGRABitmap; pt: TPoint;
  ptF: TPointF): TRect;
var dx,dy: integer;
begin
  result := EmptyRect;
  if handMoving and ((handOrigin.X <> pt.X) or (handOrigin.Y <> pt.Y)) then
  begin
    SelectionTransformChange;
    dx := pt.X-HandOrigin.X;
    dy := pt.Y-HandOrigin.Y;
    Manager.Image.SelectionTransform := AffineMatrixTranslation(dx,dy) * Manager.Image.SelectionTransform;
    SelectionTransformChange;
    result := OnlyRenderChange;
  end;
end;

procedure TToolMoveSelection.DoToolMoveAfter(pt: TPoint; ptF: TPointF);
begin
  if handMoving then handOrigin := pt;
end;

function TToolMoveSelection.ToolUp: TRect;
begin
  handMoving := false;
  result := EmptyRect;
end;

destructor TToolMoveSelection.Destroy;
begin
  if handMoving then handMoving := false;
  inherited Destroy;
end;

{ TToolSelectEllipse }

function TToolSelectEllipse.FinishShape(toolDest: TBGRABitmap): TRect;
var
  rx,ry: single;
  previousBounds: TRect;
begin
  previousBounds := FCurrentBounds;
  ClearShape;
  rx := abs(rectDest.X-rectOrigin.X);
  ry := abs(rectDest.Y-rectOrigin.Y);
  toolDest.FillEllipseAntialias(rectOrigin.X,rectOrigin.Y,rx,ry,fillColor);
  FCurrentBounds := GetShapeBounds([PointF(rectOrigin.X-rx,rectOrigin.Y-ry),PointF(rectOrigin.X+rx,rectOrigin.Y+ry)],1);
  result := RectUnion(previousBounds,FCurrentBounds);
end;

function TToolSelectEllipse.BorderTest(ptF: TPointF): TRectangularBorderTest;
begin
  Result:=inherited BorderTest(ptF);
  if (result = [btOriginY,btOriginX]) or (result = [btDestY,btDestX]) then exit; //ok
  if (result = [btDestX,btOriginY]) then result := [btDestX] else
  if (result = [btDestY,btOriginX]) then result := [btDestY] else
    result := [];
end;

function TToolSelectEllipse.RoundCoordinate(ptF: TPointF): TPointF;
begin
  result := PointF(round(ptF.X*2)/2,round(ptF.Y*2)/2);
end;

function TToolSelectEllipse.GetSelectRectMargin: single;
begin
  Result:= 0;
end;

function TToolSelectEllipse.GetStatusText: string;
begin
  if rectDrawing or afterRectDrawing then
    result := 'x = '+inttostr(round(rectOrigin.x))+'|y = '+inttostr(round(rectOrigin.y))+'|'+
    'rx = '+FloatToStrF(abs(rectDest.x-rectOrigin.x),ffFixed,6,1)+'|ry = '+FloatToStrF(abs(rectDest.y-rectOrigin.y),ffFixed,6,1)
  else
    Result:=inherited GetStatusText;
end;

function TToolSelectEllipse.Render(VirtualScreen: TBGRABitmap;
  VirtualScreenWidth, VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction): TRect;
var toolPtF,toolPtF2: TPointF;
    rx,ry: single;
    ptsF: Array of TPointF;
    pts: array of TPoint;
    i: integer;
    curPt: TPointF;
begin
  result := EmptyRect;
  if afterRectDrawing then
  begin
    curPt := BitmapToVirtualScreen(rectOrigin);
    result := RectUnion(result, NicePoint(VirtualScreen, curPt.X,curPt.Y));
    curPt := BitmapToVirtualScreen(rectDest);
    result := RectUnion(result, NicePoint(VirtualScreen, curPt.X,curPt.Y));
    if RenderAllCornerPositions then
    begin
      curPt := BitmapToVirtualScreen(PointF(rectDest.X,rectOrigin.Y));
      result := RectUnion(result, NicePoint(VirtualScreen, curPt.X,curPt.Y));
      curPt := BitmapToVirtualScreen(PointF(rectOrigin.X,rectDest.Y));
      result := RectUnion(result, NicePoint(VirtualScreen, curPt.X,curPt.Y));
    end;
  end;

  if rectDrawing and BigImage then
  begin
    rx := abs(rectDest.X-rectOrigin.X);
    ry := abs(rectDest.Y-rectOrigin.Y);

    toolPtF := pointf(rectOrigin.X-rx,rectOrigin.Y-ry);
    toolPtF2 := pointf(rectOrigin.X+rx,rectOrigin.Y+ry);

    toolPtF := BitmapToVirtualScreen(toolPtF);
    toolPtF2 := BitmapToVirtualScreen(toolPtF2);
    toolPtF2.x -= 1;
    toolPtF2.y -= 1;

    result := RectUnion(result,rect(floor(toolPtF.x),floor(toolPtF.y),ceil(toolPtF2.x)+1,ceil(toolptF2.y)+1));

    if Assigned(VirtualScreen) then
    begin
      ptsF := VirtualScreen.ComputeEllipseContour((toolPtF.X+toolPtF2.X)/2,
        (toolPtF.Y+toolPtF2.Y)/2,(toolPtF2.X-toolPtF.X)/2,(toolPtF2.Y-toolPtF.Y)/2,0.1);

      setlength(pts, length(ptsF));
      for i := 0 to high(pts) do
        pts[i] := point(round(ptsF[i].x),round(ptsF[i].y));
      setlength(pts, length(pts)+1);
      pts[high(pts)] := pts[0];

      virtualscreen.DrawPolyLineAntialias(pts,BGRA(255,255,255,192),BGRA(0,0,0,192),FrameDashLength,False);
    end;
  end;
end;

{ TToolSelectRect }

function TToolSelectRect.GetIsSelectingTool: boolean;
begin
  Result:= true;
end;

function TToolSelectRect.UpdateShape(toolDest: TBGRABitmap): TRect;
begin
  if not BigImage then
    result := FinishShape(toolDest)
  else
    result := OnlyRenderChange;
end;

function TToolSelectRect.FinishShape(toolDest: TBGRABitmap): TRect;
var
  sx,sy :integer;
  previousBounds: TRect;
begin
  previousBounds := FCurrentBounds;
  ClearShape;
  if rectDest.X > rectOrigin.X then sx := 1 else sx := -1;
  if rectDest.Y > rectOrigin.Y then sy := 1 else sy := -1;

  toolDest.FillRectAntialias(rectOrigin.X-0.5*sx,rectOrigin.Y-0.5*sy,rectDest.X+0.5*sx,rectDest.Y+0.5*sy,fillColor);
  FCurrentBounds := GetShapeBounds([PointF(rectOrigin.X,rectOrigin.Y),PointF(rectDest.X,rectDest.Y)],1);
  result := RectUnion(previousBounds,FCurrentBounds);
end;

procedure TToolSelectRect.PrepareDrawing(rightBtn: boolean);
begin
  inherited PrepareDrawing(rightBtn);
  FCurrentBounds := EmptyRect;
end;

function TToolSelectRect.BigImage: boolean;
begin
  result := GetToolDrawingLayer.NbPixels > 480000;
end;

function TToolSelectRect.ShouldFinishShapeWhenFirstMouseUp: boolean;
begin
  result := BigImage;
end;

function TToolSelectRect.GetFillColor: TBGRAPixel;
begin
  if swapedColor then result := BGRABlack else
    result := BGRAWhite;
end;

function TToolSelectRect.GetPenColor: TBGRAPixel;
begin
  result := BGRAPixelTransparent;
end;

function TToolSelectRect.GetSelectRectMargin: single;
begin
  result := 0.5;
end;

function TToolSelectRect.Render(VirtualScreen: TBGRABitmap;
  VirtualScreenWidth, VirtualScreenHeight: integer; BitmapToVirtualScreen: TBitmapToVirtualScreenFunction): TRect;
var toolPtF,toolPtF2: TPointF;
    rLeft,rTop,rRight,rBottom: Single;
    pt1,pt2: TPoint;
    penWidth,i: integer;
begin
  result := inherited Render(VirtualScreen,VirtualScreenWidth,VirtualScreenHeight, BitmapToVirtualScreen);
  if rectDrawing and BigImage then
  begin
    if rectDest.X > rectOrigin.X then
    begin
      rLeft := rectOrigin.x;
      rRight := rectDest.x;
    end else
    begin
      rRight := rectOrigin.x;
      rLeft := rectDest.x;
    end;
    if rectDest.Y > rectOrigin.Y then
    begin
      rTop := rectOrigin.Y;
      rBottom := rectDest.Y;
    end else
    begin
      rBottom := rectOrigin.Y;
      rTop := rectDest.Y;
    end;

    toolPtF := BitmapToVirtualScreen(pointf(rLeft-GetSelectRectMargin,rTop-GetSelectRectMargin));
    toolPtF2 := BitmapToVirtualScreen(pointf(rRight+GetSelectRectMargin,rBottom+GetSelectRectMargin));
    toolPtF2.x -= 1;
    toolPtF2.y -= 1;
    pt1 := point(round(toolPtF.X),round(toolPtF.Y));
    pt2 := point(round(toolPtF2.X),round(toolPtF2.Y));

    if Manager.Image.ZoomFactor > 3 then penWidth := 2 else penWidth := 1;
    result := RectUnion(result,rect(pt1.x-(penWidth-1),pt1.y-(penWidth-1),pt2.x+1+(penWidth-1),pt2.y+1+(penWidth-1)));

    if Assigned(VirtualScreen) then
    begin
      for i := 0 to penWidth-1 do
        virtualScreen.DrawpolylineAntialias([point(pt1.x-(penWidth-1)+i,pt1.y-(penWidth-1)+i),
                 point(pt2.x+i,pt1.y-(penWidth-1)+i),point(pt2.x+i,pt2.y+i),
                 point(pt1.x-(penWidth-1)+i,pt2.y+i),point(pt1.x-(penWidth-1)+i,pt1.y-(penWidth-1)+i)],BGRA(255,255,255,192),BGRA(0,0,0,192),FrameDashLength,False);
    end;
  end;
end;

{ TToolSelectSpline }

function TToolSelectSpline.HandDrawingPolygonView(toolDest: TBGRABitmap): TRect;
var
  splinePoints: ArrayOfTPointF;
begin
  if Manager.ToolSplineEasyBezier then
  begin
    NeedCurveMode;
    splinePoints := ComputeEasyBezier(polygonPoints,FCurveMode,True, EasyBezierMinimumDotProduct);
  end else
    splinePoints := toolDest.ComputeClosedSpline(polygonPoints,Manager.ToolSplineStyle);
  FRenderedPolygonPoints := splinePoints;

  if length(splinePoints) > 2 then
  begin
    toolDest.FillPolyAntialias(splinePoints, fillColor);
    result := GetShapeBounds(splinePoints,1);
  end else
    result := EmptyRect;
end;

function TToolSelectSpline.FinalPolygonView(toolDest: TBGRABitmap): TRect;
begin
  if FAfterHandDrawing then
    result := HandDrawingPolygonView(toolDest)
  else
    result := EmptyRect;
end;

function TToolSelectSpline.GetIsSelectingTool: boolean;
begin
  Result:= true;
end;

function TToolSelectSpline.GetFillColor: TBGRAPixel;
begin
  if swapedColor then
    result := BGRABlack
  else
    result := BGRAWhite;
end;

{ TToolSelectionPen }

function TToolSelectionPen.GetIsSelectingTool: boolean;
begin
  Result:= true;
end;

function TToolSelectionPen.StartDrawing(toolDest: TBGRABitmap; ptF: TPointF;
  rightBtn: boolean): TRect;
begin
  if rightBtn then penColor := BGRABlack else penColor := BGRAWhite;
  toolDest.DrawLineAntialias(ptF.X,ptF.Y,ptF.X,ptF.Y,penColor,Manager.ToolPenWidth,True);
  result := GetShapeBounds([ptF],Manager.ToolPenWidth+1);
  Action.NotifyChange(toolDest, result);
end;

function TToolSelectionPen.ContinueDrawing(toolDest: TBGRABitmap; originF,
  destF: TPointF): TRect;
begin
  toolDest.DrawLineAntialias(destF.X,destF.Y,originF.X,originF.Y,penColor,Manager.ToolPenWidth,False);
  result := GetShapeBounds([destF,originF],Manager.ToolPenWidth+1);
  Action.NotifyChange(toolDest, result);
end;

{ TToolMagicWand }

function TToolMagicWand.GetIsSelectingTool: boolean;
begin
  Result:= true;
end;

function TToolMagicWand.DoToolDown(toolDest: TBGRABitmap; pt: TPoint;
  ptF: TPointF; rightBtn: boolean): TRect;
var penColor: TBGRAPixel;
begin
  if not Manager.Image.CurrentLayerVisible then
  begin
    result := EmptyRect;
    exit;
  end;
  if rightBtn then penColor := BGRABlack else penColor := BGRAWhite;
  Manager.Image.SelectedImageLayerReadOnly.ParallelFloodFill(pt.X,pt.Y,toolDest,penColor,fmDrawWithTransparency,Manager.ToolTolerance);
  Manager.Image.SelectionMayChangeCompletely;
  ValidateAction;
  result := rect(0,0,Manager.Image.Width,Manager.Image.Height);
end;

{ TToolSelectPoly }

function TToolSelectPoly.HandDrawingPolygonView(toolDest: TBGRABitmap): TRect;
begin
  result := EmptyRect;
  //nothing
end;

function TToolSelectPoly.FinalPolygonView(toolDest: TBGRABitmap): TRect;
var
  i: Integer;
begin
  if length(polygonPoints) > 2 then
  begin
    toolDest.FillPolyAntialias(polygonPoints, fillColor);
    result := GetShapeBounds(polygonPoints,1);
  end else
    result := EmptyRect;
  setlength(FRenderedPolygonPoints, length(polygonPoints));
  for i := 0 to high(polygonPoints) do
    FRenderedPolygonPoints[i] := polygonPoints[i];
end;

function TToolSelectPoly.GetIsSelectingTool: boolean;
begin
  result := true;
end;

function TToolSelectPoly.GetFillColor: TBGRAPixel;
begin
  if swapedColor then
    result := BGRABlack
  else
    result := BGRAWhite;
end;

initialization

  RegisterTool(ptMagicWand,TToolMagicWand);
  RegisterTool(ptSelectPen,TToolSelectionPen);
  RegisterTool(ptSelectRect,TToolSelectRect);
  RegisterTool(ptSelectEllipse,TToolSelectEllipse);
  RegisterTool(ptSelectPoly,TToolSelectPoly);
  RegisterTool(ptSelectSpline,TToolSelectSpline);
  RegisterTool(ptMoveSelection,TToolMoveSelection);
  RegisterTool(ptRotateSelection,TToolRotateSelection);

end.

