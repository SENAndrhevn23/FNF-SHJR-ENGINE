package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end

// =========================
// TYPES
// =========================

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
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

// =========================
// STREAM SYSTEM
// =========================

class SongStream
{
	public var sections:Array<SwagSection>;
	public var index:Int = 0;
	public var preloadTime:Float = 5000; // ms ahead

	public function new(song:SwagSong)
	{
		sections = song.notes;
	}

	public function getUpcomingSections(songPos:Float, bpm:Float):Array<SwagSection>
	{
		var result:Array<SwagSection> = [];

		while(index < sections.length)
		{
			var sec = sections[index];

			// convert beats → ms
			var secTime:Float = sec.sectionBeats * (60000 / bpm);

			if(secTime <= songPos + preloadTime)
			{
				result.push(sec);
				index++;
			}
			else break;
		}

		return result;
	}

	public function reset()
	{
		index = 0;
	}
}

// =========================
// SONG CLASS
// =========================

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	// =========================
	// CACHE + STREAM
	// =========================

	static var chartCache:Map<String, SwagSong> = new Map();
	public static var currentStream:SongStream;

	public static var chartPath:String;
	public static var loadedSongName:String;
	static var _lastPath:String;

	// =========================
	// LOAD
	// =========================

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;

		PlayState.SONG = getChart(jsonInput, folder);

		loadedSongName = folder;
		chartPath = _lastPath;

		#if windows
		chartPath = chartPath.replace('/', '\\');
		#end

		StageData.loadDirectory(PlayState.SONG);

		return PlayState.SONG;
	}

	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;

		var key = folder + "/" + jsonInput;

		// CACHE HIT
		if(chartCache.exists(key))
		{
			var cached = chartCache.get(key);
			currentStream = new SongStream(cached);
			return cached;
		}

		var rawData:String = null;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
			rawData = Assets.getText(_lastPath);

		var result:SwagSong = rawData != null ? parseJSON(rawData, jsonInput) : null;

		if(result != null)
		{
			chartCache.set(key, result);
			currentStream = new SongStream(result);
		}

		return result;
	}

	// =========================
	// PARSE
	// =========================

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);

		// Fix nested song
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		// Convert formats
		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1'))
					{
						trace('converting chart $nameForError with format $fmt...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}

		return songJson;
	}

	// =========================
	// CONVERT
	// =========================

	public static function convert(songJson:Dynamic)
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];

			for (sec in songJson.notes)
			{
				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;

				while(i < notes.length)
				{
					var note:Array<Dynamic> = notes[i];

					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
					}
					else i++;
				}
			}
		}

		for (section in songJson.notes)
		{
			if(section.sectionBeats == null || Math.isNaN(section.sectionBeats))
				section.sectionBeats = 4;

			for (note in section.sectionNotes)
			{
				var gottaHit:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHit ? 0 : 4);

				if(!Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]];
			}
		}
	}
}
