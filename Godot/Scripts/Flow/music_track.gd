# A music track with metadata for the playlist system.
# Pairs an OGG stream with attribution info for the lower-third credit overlay.

class_name MusicTrack extends Resource

@export var stream: AudioStreamOggVorbis
@export var song_title: String = ""
@export var song_credit: String = ""
@export var render_credit: String = ""