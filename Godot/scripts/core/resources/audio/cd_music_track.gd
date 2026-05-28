## defines a single music track for MusicSpeaker playlists
class_name CDMusicTrack extends Resource

@export var stream: AudioStream
@export var title: String = ""
@export var artist: String = ""
@export var loop_start: float = 0.0
@export var loop_end: float = 0.0
@export var loopfade_duration: float = 1.0
