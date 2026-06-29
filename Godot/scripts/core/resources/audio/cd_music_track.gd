## cd_music_track.gd
## Produces: a music track definition with loop points and crossfade.
## Consumes: nothing — pure data resource consumed by MusicSpeaker playlists.
class_name CDMusicTrack extends Resource

## the audio stream (OGG recommended for loop support)
@export var stream: AudioStream

## display metadata
@export var title: String = ""
@export var artist: String = ""

## loop region in seconds (0,0 = no loop, play once)
@export var loop_start: float = 0.0
@export var loop_end: float = 0.0

## crossfade duration for seamless loop transitions
@export var loopfade_duration: float = 1.0
