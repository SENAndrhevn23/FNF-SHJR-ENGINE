package backend;

import haxe.Json;
import lime.utils.Assets;
import objects.Note;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;
	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Array<Dynamic>>;
	var sectionBeats:Float;
	var mustHitSection:Bool;

	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public static var chartPath:String;
	public static var loadedSongName:String;

	static var _lastPath:String;

	// --------------------------------------------------
	// LOAD ENTRY
	// --------------------------------------------------

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;

		var song:SwagSong = getChart(jsonInput, folder);

		PlayState.SONG = song;
		loadedSongName = folder;
		chartPath = _lastPath;

		#if sys
		chartPath = chartPath.replace("/", "\\");
		#end

		StageData.loadDirectory(song);
		return song;
	}

	// --------------------------------------------------
	// FILE LOADING
	// --------------------------------------------------

	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		var raw:String = null;

		#if MODS_ALLOWED
		if (FileSystem.exists(_lastPath))
			raw = File.getContent(_lastPath);
		else
		#end
			raw = Assets.getText(_lastPath);

		if (raw == null) return null;

		return parseJSON(raw, jsonInput);
	}

	// --------------------------------------------------
	// JSON PARSER (FIXED ITERATION ISSUES)
	// --------------------------------------------------

	public static function parseJSON(raw:String, ?name:String = null, ?convertTo:String = "psych_v1"):SwagSong
	{
		var song:SwagSong = cast Json.parse(raw);

		// unwrap old format safely
		if (Reflect.hasField(song, "song"))
		{
			var inner:Dynamic = Reflect.field(song, "song");
			if (inner != null)
				song = cast inner;
		}

		// ensure arrays exist
		if (song.notes == null) song.notes = [];
		if (song.events == null) song.events = [];

		// --------------------------------------------------
		// SAFE SECTION ITERATION
		// --------------------------------------------------

		var sections:Array<SwagSection> = cast song.notes;

		for (section in sections)
		{
			if (section.sectionNotes == null)
				section.sectionNotes = [];

			var notes:Array<Array<Dynamic>> = cast section.sectionNotes;

			var i:Int = 0;
			while (i < notes.length)
			{
				var note:Array<Dynamic> = notes[i];

				if (note == null || note.length < 2)
				{
					i++;
					continue;
				}

				var gottaHit:Bool =
					(note[1] < 4)
					? section.mustHitSection
					: !section.mustHitSection;

				note[1] = (note[1] % 4) + (gottaHit ? 0 : 4);

				if (note.length > 3 && !Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]];

				i++;
			}
		}

		// --------------------------------------------------
		// FORMAT CONVERSION
		// --------------------------------------------------

		if (convertTo != null && convertTo.length > 0)
		{
			var fmt:String = song.format;
			if (fmt == null) fmt = song.format = "unknown";

			switch (convertTo)
			{
				case "psych_v1":
					if (!fmt.startsWith("psych_v1"))
					{
						trace('Converting chart $name to psych_v1');
						song.format = "psych_v1_convert";
						convert(song);
					}
			}
		}

		return song;
	}

	// --------------------------------------------------
	// LEGACY CONVERTER
	// --------------------------------------------------

	public static function convert(songJson:Dynamic)
	{
		if (songJson.notes == null) return;

		var sections:Array<Dynamic> = cast songJson.notes;

		for (sec in sections)
		{
			if (sec.sectionNotes == null) continue;

			var notes:Array<Array<Dynamic>> = cast sec.sectionNotes;

			var i:Int = 0;
			while (i < notes.length)
			{
				var note = notes[i];

				if (note != null && note[1] < 0)
				{
					if (songJson.events == null)
						songJson.events = [];

					songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
					notes.splice(i, 1);
				}
				else i++;
			}
		}
	}
}
