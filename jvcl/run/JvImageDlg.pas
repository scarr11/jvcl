{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvImageDlg.PAS, released on 2001-02-28.

The Initial Developer of the Original Code is Sébastien Buysse [sbuysse@buypin.com]
Portions created by Sébastien Buysse are Copyright (C) 2001 Sébastien Buysse.
All Rights Reserved.

Contributor(s): Michael Beck [mbeck@bigfoot.com].

Last Modified: 2000-02-28

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

Known Issues:
-----------------------------------------------------------------------------}

{$I JVCL.INC}

unit JvImageDlg;

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms,
  JvImageForm, JvBaseDlg, JvTypes;

type
  TJvImageDialog = class(TJvCommonDialogP)
  private
    FPicture: TPicture;
    FTitle: string;
    procedure SetPicture(const Value: TPicture);
  protected
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Picture: TPicture read FPicture write SetPicture;
    property Title: string read FTitle write FTitle;
    procedure Execute; override;
  end;

implementation

resourcestring
  RC_ImageTitle = 'Image Viewer';

constructor TJvImageDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPicture := TPicture.Create;
  FTitle := RC_ImageTitle;
end;

destructor TJvImageDialog.Destroy;
begin
  FPicture.Free;
  inherited Destroy;
end;

procedure TJvImageDialog.Execute;
begin
  with TFormImg.Create(Application) do
  begin
    Image1.Picture.Assign(FPicture);
    ClientHeight := FPicture.Height;
    ClientWidth := FPicture.Width;
    Caption := FTitle;
    if (FPicture.Height <> 0) and (FPicture.Width <> 0) then
      ShowModal;
    Free;
  end;
end;

procedure TJvImageDialog.SetPicture(const Value: TPicture);
begin
  FPicture.Assign(Value);
end;

end.

