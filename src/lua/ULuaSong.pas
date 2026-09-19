{* UltraStar Deluxe - Karaoke Game
 *
 * ULuaSong - custom addition for external controller support.
 *
 * Exposes a small "Song" module to Lua plugins:
 *
 *   Song.CanPlay()       -> boolean
 *     True only when the song select screen is actively shown in its
 *     normal (non-party, non-submenu) mode - i.e. any point after
 *     player selection, and we are not currently singing.
 *
 *   Song.Play(SearchText) -> boolean
 *     Does nothing and returns false if CanPlay() would return false,
 *     or if no song matches SearchText. Otherwise filters/selects the
 *     first matching song and starts it (fades to the sing screen),
 *     mirroring exactly what happens when a player types a search in
 *     the in-game "Jump to" (J) box and presses Enter twice - but
 *     done directly against game state instead of synthetic
 *     keystrokes, so it can report a definite success/failure result.
 *
 *   Song.NowPlaying() -> table {title, artist} or nil
 *     The title/artist of the song currently on the sing screen, or
 *     nil whenever the sing screen isn't the active screen (song
 *     select, scoring, party menus, etc).
 *}

unit ULuaSong;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses ULua;

function ULuaSong_CanPlay(L: Plua_State): Integer; cdecl;
function ULuaSong_Play(L: Plua_State): Integer; cdecl;
function ULuaSong_NowPlaying(L: Plua_State): Integer; cdecl;

const
  ULuaSong_Lib_f: array [0..3] of lual_reg = (
    (name:'CanPlay'; func:ULuaSong_CanPlay),
    (name:'Play'; func:ULuaSong_Play),
    (name:'NowPlaying'; func:ULuaSong_NowPlaying),
    (name:nil; func:nil)
  );

implementation
uses
  UDisplay,
  UGraphic,
  USongs,
  USong,
  UNote,
  ULuaUtils;

{ True only while ScreenSong is the active screen and it is in its
  normal single/duet-select mode - not mid-party-menu, not singing,
  not on any other screen. This is exactly "after player selection,
  not currently playing a song". }
function SongScreenIsSelectable: boolean;
begin
  Result :=
    (Display.CurrentScreen = @ScreenSong) and
    (ScreenSong.Mode = smNormal)
    or
    (Display.CurrentScreen = @ScreenScore);
end;

function ULuaSong_CanPlay(L: Plua_State): Integer; cdecl;
begin
  Lua_ClearStack(L);

  lua_pushBoolean(L, SongScreenIsSelectable);

  Result := 1;
end;

function ULuaSong_Play(L: Plua_State): Integer; cdecl;
var
  SearchText: String;
  FoundCount: Cardinal;
begin
  SearchText := luaL_checkstring(L, 1);

  Lua_ClearStack(L);
  Result := 1;

  if not SongScreenIsSelectable then
  begin
    // Not a valid time to play - do nothing, report failure.
    lua_pushBoolean(L, false);
    Exit;
  end;

  FoundCount := CatSongs.SetFilter(SearchText, fltAll);

  if (FoundCount = 0) then
  begin
    // No match - leave the filter cleared so we don't strand the UI
    // on a dead-end search, and report failure.
    CatSongs.SetFilter('', fltAll);
    lua_pushBoolean(L, false);
    Exit;
  end;

  // Select the first visible match (same call the in-game search
  // box makes after filtering) and start it.
  ScreenSong.SelectNext;
  ScreenSong.FixSelected;

  ScreenSong.StartSong;

  lua_pushBoolean(L, true);
end;

function ULuaSong_NowPlaying(L: Plua_State): Integer; cdecl;
begin
  Lua_ClearStack(L);
  Result := 1;

  if (Display.CurrentScreen <> @ScreenSing) or (CurrentSong = nil) then
  begin
    lua_pushNil(L);
    Exit;
  end;

  lua_createtable(L, 0, 2);

  lua_pushString(L, PChar(CurrentSong.Title));
  lua_setField(L, -2, 'title');

  lua_pushString(L, PChar(CurrentSong.Artist));
  lua_setField(L, -2, 'artist');
end;

end.
