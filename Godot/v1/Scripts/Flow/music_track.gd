# A music track with metadata for the playlist system.
# Pairs an OGG stream with attribution info for the lower-third credit overlay.
# loop_start/loop_end define the seamless loop region (skips intro/outro on long runs).
# First play always starts from 0:00. Looping only activates after the first pass.

class_name MusicTrack extends Resource

@export var stream: AudioStreamOggVorbis
@export var loop_start: float = 0.0   # seconds — seek target when looping
@export var loop_end: float = -1.0    # seconds — trigger loop crossfade here (-1 = use full track length)
@export var song_title: String = ""
@export var song_credit: String = ""
@export var render_credit: String = ""