@tool
extends Control
## Godot logo splash screen — vector polyline rendering with CRT menace effects.
## Reuses the same glitch/static/glow/scan/corrupt system as polybius_face.
## Shows for a configured duration, then emits boot_complete.

signal boot_complete

# --- Appearance ---
@export var face_color: Color = Color("ffb300"):
	set(v):
		face_color = v
		queue_redraw()

@export var line_width: float = 2.0:
	set(v):
		line_width = v
		queue_redraw()

@export var horizontal_offset: float = 0.0:
	set(v):
		horizontal_offset = v
		queue_redraw()

@export_group("Timing")
@export var display_duration: float = 3.0
@export var fade_in_duration: float = 0.5
@export var fade_out_duration: float = 0.3

# --- Menace Effects (same as polybius_face) ---
@export_group("Menace")

@export var glitch_enabled: bool = true
@export_range(0.0, 30.0) var glitch_intensity: float = 3.0
@export_range(0.0, 1.0) var glitch_chance: float = 0.06
@export_range(1.0, 20.0) var glitch_band_height: float = 4.0

@export var static_enabled: bool = true
@export_range(0.0, 1.0) var static_density: float = 0.03
@export_range(0.0, 1.0) var static_burst_chance: float = 0.04
@export_range(1.0, 4.0) var static_size: float = 1.5

@export var glow_enabled: bool = true
@export_range(0, 5) var glow_passes: int = 2
@export_range(2.0, 12.0) var glow_base_width: float = 4.0
@export_range(0.0, 1.0) var glow_intensity: float = 0.25
@export_range(0.0, 10.0) var glow_pulse_speed: float = 1.5
@export_range(0.0, 1.0) var glow_pulse_amount: float = 0.15

@export var scan_disruption_enabled: bool = true
@export_range(0.0, 1.0) var scan_disruption_chance: float = 0.03
@export_range(1.0, 6.0) var scan_disruption_thickness: float = 2.0
@export_range(0.0, 1.0) var scan_disruption_brightness: float = 0.3

@export var corrupt_flash_enabled: bool = true
@export_range(0.0, 1.0) var corrupt_flash_chance: float = 0.015
@export_range(0.0, 40.0) var corrupt_displacement: float = 8.0

# --- Runtime state ---
var _elapsed_time: float = 0.0
var _is_done: bool = false
var _alpha: float = 1.0  # Default 1.0 for editor preview; set to 0.0 at runtime

# --- Menace runtime state ---
var _glitch_timer: float = 0.0
var _glitch_active: bool = false
var _glitch_slices: Array = []

var _static_active: bool = false
var _static_particles: Array = []

var _scan_active: bool = false
var _scan_y: float = 0.0

var _corrupt_active: bool = false
var _corrupt_timer: float = 0.0
var _corrupt_seed: int = 0

# --- Logo polyline data (from SVG conversion) ---

var _logo_body_0: PackedVector2Array = PackedVector2Array([
	Vector2(303.4, 53.5), Vector2(301.5, 54.0), Vector2(299.7, 54.4),
	Vector2(297.8, 54.9), Vector2(296.0, 55.4), Vector2(294.1, 56.0),
	Vector2(292.3, 56.6), Vector2(290.5, 57.2), Vector2(288.7, 57.9),
	Vector2(286.9, 58.6), Vector2(285.1, 59.3), Vector2(283.4, 60.1),
	Vector2(281.6, 61.0), Vector2(281.7, 62.5), Vector2(281.7, 64.0),
	Vector2(281.8, 65.5), Vector2(281.9, 67.0), Vector2(282.0, 68.5),
	Vector2(282.1, 70.0), Vector2(282.2, 71.5), Vector2(282.3, 73.0),
	Vector2(282.5, 74.4), Vector2(282.6, 75.9), Vector2(282.8, 77.4),
	Vector2(283.0, 78.9), Vector2(282.3, 79.3), Vector2(281.6, 79.7),
	Vector2(280.9, 80.1), Vector2(280.3, 80.6), Vector2(279.6, 81.0),
	Vector2(278.9, 81.4), Vector2(278.2, 81.8), Vector2(277.6, 82.2),
	Vector2(276.9, 82.7), Vector2(276.2, 83.1), Vector2(275.6, 83.6),
	Vector2(275.0, 84.1), Vector2(274.3, 84.6), Vector2(273.7, 85.1),
	Vector2(273.0, 85.6), Vector2(272.4, 86.1), Vector2(271.8, 86.6),
	Vector2(271.1, 87.0), Vector2(270.5, 87.6), Vector2(269.9, 88.1),
	Vector2(269.3, 88.6), Vector2(268.7, 89.1), Vector2(268.1, 89.7),
	Vector2(267.5, 90.2), Vector2(266.3, 89.5), Vector2(265.2, 88.7),
	Vector2(264.0, 88.0), Vector2(262.8, 87.3), Vector2(261.6, 86.5),
	Vector2(260.4, 85.8), Vector2(259.2, 85.1), Vector2(257.9, 84.4),
	Vector2(256.7, 83.7), Vector2(255.5, 83.1), Vector2(254.2, 82.4),
	Vector2(253.0, 81.8), Vector2(251.6, 83.3), Vector2(250.3, 84.7),
	Vector2(249.0, 86.3), Vector2(247.7, 87.8), Vector2(246.4, 89.3),
	Vector2(245.2, 90.9), Vector2(244.0, 92.5), Vector2(242.8, 94.2),
	Vector2(241.6, 95.8), Vector2(240.5, 97.5), Vector2(239.4, 99.2),
	Vector2(238.3, 101.0), Vector2(239.2, 102.2), Vector2(240.0, 103.5),
	Vector2(240.8, 104.8), Vector2(241.7, 106.0), Vector2(242.5, 107.3),
	Vector2(243.3, 108.5), Vector2(244.2, 109.7), Vector2(245.0, 110.9),
	Vector2(245.8, 112.0), Vector2(246.7, 113.1), Vector2(247.5, 114.2),
	Vector2(248.3, 115.2), Vector2(248.3, 150.0), Vector2(248.3, 154.5),
	Vector2(248.3, 158.5), Vector2(275.1, 161.0), Vector2(276.0, 161.3),
	Vector2(276.8, 161.9), Vector2(277.4, 162.7), Vector2(277.6, 163.7),
	Vector2(278.5, 175.4), Vector2(301.6, 177.0), Vector2(303.2, 166.2),
	Vector2(303.5, 165.3), Vector2(304.1, 164.5), Vector2(305.0, 164.0),
	Vector2(306.0, 163.8), Vector2(334.0, 163.8), Vector2(335.0, 164.0),
	Vector2(335.9, 164.5), Vector2(336.5, 165.3), Vector2(336.8, 166.2),
	Vector2(338.4, 177.0), Vector2(361.5, 175.4), Vector2(362.4, 163.7),
	Vector2(362.6, 162.7), Vector2(363.2, 161.9), Vector2(364.0, 161.3),
	Vector2(364.9, 161.0), Vector2(391.4, 158.5), Vector2(391.7, 155.0),
	Vector2(391.7, 115.2), Vector2(392.6, 114.0), Vector2(393.5, 112.8),
	Vector2(394.4, 111.6), Vector2(395.3, 110.4), Vector2(396.2, 109.2),
	Vector2(397.1, 108.0), Vector2(397.9, 106.8), Vector2(398.7, 105.6),
	Vector2(399.5, 104.4), Vector2(400.2, 103.2), Vector2(401.0, 102.1),
	Vector2(401.7, 101.0), Vector2(400.6, 99.2), Vector2(399.5, 97.5),
	Vector2(398.4, 95.8), Vector2(397.2, 94.2), Vector2(396.0, 92.5),
	Vector2(394.8, 90.9), Vector2(393.6, 89.3), Vector2(392.3, 87.8),
	Vector2(391.0, 86.3), Vector2(389.7, 84.7), Vector2(388.4, 83.3),
	Vector2(387.0, 81.8), Vector2(385.8, 82.4), Vector2(384.5, 83.1),
	Vector2(383.3, 83.7), Vector2(382.1, 84.4), Vector2(380.8, 85.1),
	Vector2(379.6, 85.8), Vector2(378.4, 86.5), Vector2(377.2, 87.3),
	Vector2(376.0, 88.0), Vector2(374.8, 88.7), Vector2(373.7, 89.5),
	Vector2(372.5, 90.2), Vector2(371.9, 89.7), Vector2(371.3, 89.1),
	Vector2(370.7, 88.6), Vector2(370.1, 88.1), Vector2(369.5, 87.6),
	Vector2(368.9, 87.0), Vector2(368.2, 86.6), Vector2(367.6, 86.1),
	Vector2(367.0, 85.6), Vector2(366.3, 85.1), Vector2(365.7, 84.6),
	Vector2(365.0, 84.1), Vector2(364.4, 83.6), Vector2(363.8, 83.1),
	Vector2(363.1, 82.7), Vector2(362.4, 82.2), Vector2(361.8, 81.8),
	Vector2(361.1, 81.4), Vector2(360.4, 81.0), Vector2(359.7, 80.6),
	Vector2(359.1, 80.1), Vector2(358.4, 79.7), Vector2(357.7, 79.3),
	Vector2(357.0, 78.9), Vector2(357.2, 77.4), Vector2(357.4, 75.9),
	Vector2(357.5, 74.4), Vector2(357.7, 73.0), Vector2(357.8, 71.5),
	Vector2(357.9, 70.0), Vector2(358.0, 68.5), Vector2(358.1, 67.0),
	Vector2(358.2, 65.5), Vector2(358.3, 64.0), Vector2(358.3, 62.5),
	Vector2(358.4, 61.0), Vector2(356.6, 60.1), Vector2(354.9, 59.3),
	Vector2(353.1, 58.6), Vector2(351.3, 57.9), Vector2(349.5, 57.2),
	Vector2(347.7, 56.6), Vector2(345.9, 56.0), Vector2(344.0, 55.4),
	Vector2(342.2, 54.9), Vector2(340.3, 54.4), Vector2(338.5, 54.0),
	Vector2(336.6, 53.5), Vector2(335.9, 54.8), Vector2(335.1, 56.1),
	Vector2(334.4, 57.4), Vector2(333.7, 58.7), Vector2(333.0, 60.0),
	Vector2(332.3, 61.3), Vector2(331.7, 62.6), Vector2(331.0, 63.9),
	Vector2(330.4, 65.3), Vector2(329.7, 66.6), Vector2(329.1, 67.9),
	Vector2(328.5, 69.3), Vector2(327.8, 69.2), Vector2(327.1, 69.1),
	Vector2(326.4, 69.0), Vector2(325.7, 68.9), Vector2(325.0, 68.8),
	Vector2(324.3, 68.8), Vector2(323.6, 68.7), Vector2(322.9, 68.7),
	Vector2(322.2, 68.6), Vector2(321.5, 68.6), Vector2(320.8, 68.6),
	Vector2(320.1, 68.6), Vector2(319.2, 68.6), Vector2(318.5, 68.6),
	Vector2(317.8, 68.6), Vector2(317.1, 68.7), Vector2(316.4, 68.7),
	Vector2(315.7, 68.8), Vector2(315.0, 68.8), Vector2(314.3, 68.9),
	Vector2(313.6, 69.0), Vector2(312.9, 69.1), Vector2(312.2, 69.2),
	Vector2(311.5, 69.3), Vector2(310.9, 67.9), Vector2(310.3, 66.6),
	Vector2(309.6, 65.3), Vector2(309.0, 63.9), Vector2(308.3, 62.6),
	Vector2(307.7, 61.3), Vector2(307.0, 60.0), Vector2(306.3, 58.7),
	Vector2(305.6, 57.4), Vector2(304.9, 56.1), Vector2(304.1, 54.8),
	Vector2(303.4, 53.5),
])

var _logo_body_1: PackedVector2Array = PackedVector2Array([
	Vector2(282.4, 116.8), Vector2(284.6, 117.0), Vector2(286.7, 117.4),
	Vector2(288.6, 118.1), Vector2(290.5, 119.0), Vector2(292.2, 120.1),
	Vector2(293.7, 121.5), Vector2(295.1, 123.0), Vector2(296.2, 124.7),
	Vector2(297.1, 126.6), Vector2(297.8, 128.5), Vector2(298.2, 130.6),
	Vector2(298.4, 132.8), Vector2(298.2, 134.9), Vector2(297.8, 137.0),
	Vector2(297.1, 139.0), Vector2(296.2, 140.8), Vector2(295.1, 142.5),
	Vector2(293.7, 144.1), Vector2(292.2, 145.4), Vector2(290.5, 146.6),
	Vector2(288.6, 147.5), Vector2(286.7, 148.2), Vector2(284.6, 148.6),
	Vector2(282.4, 148.8), Vector2(280.2, 148.6), Vector2(278.2, 148.2),
	Vector2(276.2, 147.5), Vector2(274.3, 146.6), Vector2(272.6, 145.4),
	Vector2(271.1, 144.1), Vector2(269.8, 142.5), Vector2(268.6, 140.8),
	Vector2(267.7, 139.0), Vector2(267.0, 137.0), Vector2(266.6, 134.9),
	Vector2(266.4, 132.8), Vector2(266.6, 130.6), Vector2(267.0, 128.5),
	Vector2(267.7, 126.6), Vector2(268.6, 124.7), Vector2(269.8, 123.0),
	Vector2(271.1, 121.5), Vector2(272.6, 120.1), Vector2(274.3, 119.0),
	Vector2(276.2, 118.1), Vector2(278.2, 117.4), Vector2(280.2, 117.0),
	Vector2(282.4, 116.8),
])

var _logo_body_2: PackedVector2Array = PackedVector2Array([
	Vector2(357.6, 116.8), Vector2(359.8, 117.0), Vector2(361.8, 117.4),
	Vector2(363.8, 118.1), Vector2(365.7, 119.0), Vector2(367.4, 120.1),
	Vector2(368.9, 121.5), Vector2(370.2, 123.0), Vector2(371.4, 124.7),
	Vector2(372.3, 126.6), Vector2(373.0, 128.5), Vector2(373.4, 130.6),
	Vector2(373.6, 132.8), Vector2(373.4, 134.9), Vector2(373.0, 137.0),
	Vector2(372.3, 139.0), Vector2(371.4, 140.8), Vector2(370.2, 142.5),
	Vector2(368.9, 144.1), Vector2(367.4, 145.4), Vector2(365.7, 146.6),
	Vector2(363.8, 147.5), Vector2(361.8, 148.2), Vector2(359.8, 148.6),
	Vector2(357.6, 148.8), Vector2(355.4, 148.6), Vector2(353.3, 148.2),
	Vector2(351.4, 147.5), Vector2(349.5, 146.6), Vector2(347.8, 145.4),
	Vector2(346.3, 144.1), Vector2(344.9, 142.5), Vector2(343.8, 140.8),
	Vector2(342.9, 139.0), Vector2(342.2, 137.0), Vector2(341.8, 134.9),
	Vector2(341.6, 132.8), Vector2(341.8, 130.6), Vector2(342.2, 128.5),
	Vector2(342.9, 126.6), Vector2(343.8, 124.7), Vector2(344.9, 123.0),
	Vector2(346.3, 121.5), Vector2(347.8, 120.1), Vector2(349.5, 119.0),
	Vector2(351.4, 118.1), Vector2(353.3, 117.4), Vector2(355.4, 117.0),
	Vector2(357.6, 116.8),
])

var _logo_body_3: PackedVector2Array = PackedVector2Array([
	Vector2(320.0, 126.2), Vector2(321.4, 126.3), Vector2(322.6, 126.8),
	Vector2(323.6, 127.5), Vector2(324.4, 128.5), Vector2(325.0, 129.6),
	Vector2(325.1, 130.8), Vector2(325.1, 145.5), Vector2(325.0, 146.8),
	Vector2(324.4, 147.9), Vector2(323.6, 148.8), Vector2(322.6, 149.6),
	Vector2(321.4, 150.0), Vector2(320.0, 150.2), Vector2(318.6, 150.0),
	Vector2(317.4, 149.6), Vector2(316.4, 148.8), Vector2(315.6, 147.9),
	Vector2(315.0, 146.8), Vector2(314.9, 145.5), Vector2(314.9, 130.8),
	Vector2(315.0, 129.6), Vector2(315.6, 128.5), Vector2(316.4, 127.5),
	Vector2(317.4, 126.8), Vector2(318.6, 126.3), Vector2(320.0, 126.2),
])

var _logo_jaw: PackedVector2Array = PackedVector2Array([
	Vector2(367.9, 166.5), Vector2(367.1, 178.3), Vector2(366.8, 179.3),
	Vector2(366.2, 180.1), Vector2(365.4, 180.7), Vector2(364.4, 180.9),
	Vector2(336.2, 182.9), Vector2(335.3, 182.9), Vector2(334.4, 182.4),
	Vector2(333.7, 181.8), Vector2(333.2, 180.8), Vector2(331.5, 169.5),
	Vector2(308.5, 169.5), Vector2(306.9, 180.5), Vector2(306.7, 181.2),
	Vector2(306.1, 182.1), Vector2(305.2, 182.7), Vector2(304.2, 182.9),
	Vector2(275.6, 180.9), Vector2(274.6, 180.7), Vector2(273.8, 180.1),
	Vector2(273.2, 179.3), Vector2(272.9, 178.3), Vector2(272.1, 166.5),
	Vector2(248.3, 164.2), Vector2(248.3, 165.5), Vector2(248.3, 166.7),
	Vector2(248.3, 167.9), Vector2(248.3, 168.9), Vector2(248.3, 169.7),
	Vector2(249.0, 176.1), Vector2(250.9, 181.6), Vector2(253.9, 186.6),
	Vector2(258.1, 191.0), Vector2(263.2, 194.9), Vector2(269.2, 198.2),
	Vector2(276.1, 201.1), Vector2(283.7, 203.4), Vector2(292.0, 205.2),
	Vector2(300.9, 206.5), Vector2(310.2, 207.3), Vector2(320.0, 207.6),
	Vector2(329.8, 207.3), Vector2(339.1, 206.5), Vector2(348.0, 205.2),
	Vector2(356.3, 203.4), Vector2(363.9, 201.1), Vector2(370.7, 198.2),
	Vector2(376.8, 194.9), Vector2(381.9, 191.0), Vector2(386.1, 186.6),
	Vector2(389.1, 181.6), Vector2(391.0, 176.1), Vector2(391.7, 170.1),
	Vector2(391.7, 169.3), Vector2(391.7, 168.4), Vector2(391.7, 167.3),
	Vector2(391.7, 166.1), Vector2(391.7, 164.8), Vector2(367.9, 166.5),
])

var _logo_left_eye: PackedVector2Array = PackedVector2Array([
	Vector2(294.5, 133.7), Vector2(294.4, 135.2), Vector2(294.2, 136.5),
	Vector2(293.7, 137.9), Vector2(293.1, 139.1), Vector2(292.3, 140.2),
	Vector2(291.4, 141.2), Vector2(290.4, 142.1), Vector2(289.3, 142.9),
	Vector2(288.1, 143.5), Vector2(286.8, 144.0), Vector2(285.4, 144.2),
	Vector2(283.9, 144.3), Vector2(282.5, 144.2), Vector2(281.1, 144.0),
	Vector2(279.8, 143.5), Vector2(278.6, 142.9), Vector2(277.5, 142.1),
	Vector2(276.4, 141.2), Vector2(275.5, 140.2), Vector2(274.8, 139.1),
	Vector2(274.2, 137.9), Vector2(273.7, 136.5), Vector2(273.4, 135.2),
	Vector2(273.3, 133.7), Vector2(273.7, 132.9), Vector2(274.2, 132.1),
	Vector2(274.8, 131.0), Vector2(275.5, 129.7), Vector2(276.4, 128.4),
	Vector2(277.5, 127.1), Vector2(278.6, 125.9), Vector2(279.8, 124.8),
	Vector2(281.1, 123.9), Vector2(282.5, 123.3), Vector2(283.9, 123.1),
	Vector2(285.4, 123.2), Vector2(286.8, 123.5), Vector2(288.1, 124.0),
	Vector2(289.3, 124.6), Vector2(290.4, 125.3), Vector2(291.4, 126.2),
	Vector2(292.3, 127.2), Vector2(293.1, 128.4), Vector2(293.7, 129.6),
	Vector2(294.2, 130.9), Vector2(294.4, 132.3), Vector2(294.5, 133.7),
])

var _logo_right_eye: PackedVector2Array = PackedVector2Array([
	Vector2(345.5, 133.7), Vector2(345.6, 135.2), Vector2(345.8, 136.5),
	Vector2(346.3, 137.9), Vector2(346.9, 139.1), Vector2(347.7, 140.2),
	Vector2(348.6, 141.2), Vector2(349.6, 142.1), Vector2(350.7, 142.9),
	Vector2(351.9, 143.5), Vector2(353.2, 144.0), Vector2(354.6, 144.2),
	Vector2(356.1, 144.3), Vector2(357.5, 144.2), Vector2(358.9, 144.0),
	Vector2(360.2, 143.5), Vector2(361.4, 142.9), Vector2(362.5, 142.1),
	Vector2(363.6, 141.2), Vector2(364.5, 140.2), Vector2(365.2, 139.1),
	Vector2(365.8, 137.9), Vector2(366.3, 136.5), Vector2(366.6, 135.2),
	Vector2(366.7, 133.7), Vector2(366.3, 132.9), Vector2(365.8, 132.1),
	Vector2(365.2, 131.0), Vector2(364.5, 129.7), Vector2(363.6, 128.4),
	Vector2(362.5, 127.1), Vector2(361.4, 125.9), Vector2(360.2, 124.8),
	Vector2(358.9, 123.9), Vector2(357.5, 123.3), Vector2(356.1, 123.1),
	Vector2(354.6, 123.2), Vector2(353.2, 123.5), Vector2(351.9, 124.0),
	Vector2(350.7, 124.6), Vector2(349.6, 125.3), Vector2(348.6, 126.2),
	Vector2(347.7, 127.2), Vector2(346.9, 128.4), Vector2(346.3, 129.6),
	Vector2(345.8, 130.9), Vector2(345.6, 132.3), Vector2(345.5, 133.7),
])

@onready var _text_label: Label = $MadeInGodotLabel

func _ready() -> void:
	# Hide label at runtime — we draw it through _draw() for glow support
	if not Engine.is_editor_hint():
		_alpha = 0.0
		if _text_label:
			_text_label.visible = false
		_begin_boot_sequence()

func _begin_boot_sequence() -> void:
	# Fade in, hold, then emit boot_complete (no fade-out — scroll transition handles removal)
	var tween := create_tween()
	# Fade in
	tween.tween_method(_set_alpha, 0.0, 1.0, fade_in_duration)
	# Hold
	tween.tween_interval(display_duration)
	# Done
	tween.tween_callback(_on_boot_done)

func _set_alpha(val: float) -> void:
	_alpha = val
	queue_redraw()

func _on_boot_done() -> void:
	_is_done = true
	boot_complete.emit()

## Called by ArcadeOrchestrator to kill the boot tween when skipping
func kill_tween() -> void:
	var tweens = get_children().filter(func(c): return c is Tween)
	for t in tweens:
		t.kill()

func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_menace(delta)
	queue_redraw()

# ─── Menace Effect Updates (mirrored from polybius_face) ────────

func _update_menace(delta: float) -> void:
	if glitch_enabled:
		if _glitch_active:
			_glitch_timer -= delta
			if _glitch_timer <= 0.0:
				_glitch_active = false
				_glitch_slices.clear()
		else:
			if randf() < glitch_chance:
				_glitch_active = true
				_glitch_timer = randf_range(0.03, 0.12)
				_generate_glitch_slices()
	else:
		_glitch_active = false
		_glitch_slices.clear()
	
	if static_enabled:
		if _static_active:
			_static_particles.clear()
			_generate_static_particles()
			if randf() > static_burst_chance * 3.0:
				_static_active = false
		else:
			_static_particles.clear()
			if randf() < static_burst_chance:
				_static_active = true
				_generate_static_particles()
	else:
		_static_active = false
		_static_particles.clear()
	
	if scan_disruption_enabled:
		if _scan_active:
			_scan_y += delta * 800.0
			if _scan_y > size.y:
				_scan_active = false
		else:
			if randf() < scan_disruption_chance:
				_scan_active = true
				_scan_y = -20.0
	else:
		_scan_active = false
	
	if corrupt_flash_enabled:
		if _corrupt_active:
			_corrupt_timer -= delta
			if _corrupt_timer <= 0.0:
				_corrupt_active = false
		else:
			if randf() < corrupt_flash_chance:
				_corrupt_active = true
				_corrupt_timer = randf_range(0.03, 0.08)
				_corrupt_seed = randi()
	else:
		_corrupt_active = false

func _generate_glitch_slices() -> void:
	_glitch_slices.clear()
	var face_h: float = 360.0
	var num_slices: int = randi_range(1, 4)
	for _i in num_slices:
		var y_start: float = randf_range(0.0, face_h)
		var y_end: float = y_start + randf_range(glitch_band_height, glitch_band_height * 4.0)
		var x_off: float = randf_range(-glitch_intensity, glitch_intensity)
		_glitch_slices.append({"y_start": y_start, "y_end": y_end, "x_offset": x_off})

func _generate_static_particles() -> void:
	_static_particles.clear()
	var count: int = int(static_density * 500.0)
	for _i in count:
		_static_particles.append({"x": randf_range(0.0, 640.0), "y": randf_range(0.0, 360.0)})

func _get_glitch_offset_for_y(y: float) -> float:
	if not _glitch_active or _glitch_slices.is_empty():
		return 0.0
	for slice in _glitch_slices:
		if y >= slice.y_start and y <= slice.y_end:
			return slice.x_offset
	return 0.0

func _corrupt_point(p: Vector2) -> Vector2:
	if not _corrupt_active:
		return p
	var seed_val := _corrupt_seed
	var px := p.x + _seeded_rand(seed_val, int(p.x) * 7 + int(p.y) * 13) * corrupt_displacement
	var py := p.y + _seeded_rand(seed_val + 1, int(p.x) * 11 + int(p.y) * 3) * corrupt_displacement
	return Vector2(px, py)

func _seeded_rand(s: int, index: int) -> float:
	var v := s ^ (index * 1664525 + 1013904223)
	v = (v >> 16) ^ v
	v = v * 0x45d9f3b
	v = (v >> 16) ^ v
	return (float(v & 0x7FFFFFFF) / float(0x7FFFFFFF)) * 2.0 - 1.0

# ─── Drawing ────────────────────────────────────────────────────

func _draw() -> void:
	var pulse: float = 0.0
	if glow_enabled:
		pulse = sin(_elapsed_time * glow_pulse_speed) * glow_pulse_amount
	
	var draw_color := Color(face_color.r, face_color.g, face_color.b, _alpha)
	if _corrupt_active and corrupt_flash_enabled:
		draw_color = Color(face_color.g, face_color.r, face_color.b * 0.5, _alpha)
	
	# Glow passes (behind crisp lines)
	if glow_enabled and glow_passes > 0:
		for pass_idx in glow_passes:
			var extra_width: float = glow_base_width * float(pass_idx + 1)
			var alpha: float = (glow_intensity + pulse) / float(pass_idx + 1) * _alpha
			var glow_color := Color(draw_color.r, draw_color.g, draw_color.b, clamp(alpha, 0.0, 1.0))
			_draw_all_polylines(glow_color, line_width + extra_width, true)
	
	# Crisp lines
	_draw_all_polylines(draw_color, line_width, false)
	
	# Text with glow
	_draw_text_glow(draw_color, pulse)
	
	# Static overlay
	if _static_active and static_enabled:
		var static_color := Color(draw_color.r, draw_color.g, draw_color.b, 0.6)
		for p in _static_particles:
			draw_rect(Rect2(p.x, p.y, static_size, static_size), static_color)
	
	# Scan disruption
	if _scan_active and scan_disruption_enabled:
		var scan_color := Color(draw_color.r, draw_color.g, draw_color.b, scan_disruption_brightness)
		draw_rect(Rect2(0.0, _scan_y, size.x, scan_disruption_thickness), scan_color)
		var trail_color := Color(draw_color.r, draw_color.g, draw_color.b, scan_disruption_brightness * 0.3)
		draw_rect(Rect2(0.0, _scan_y - scan_disruption_thickness * 2.0, size.x, scan_disruption_thickness * 0.5), trail_color)

func _draw_all_polylines(color: Color, width: float, is_glow_pass: bool) -> void:
	# Main body outline
	_draw_polyline_menace(_logo_body_0, color, width, is_glow_pass)
	# Left eye socket
	_draw_polyline_menace(_logo_body_1, color, width, is_glow_pass)
	# Right eye socket
	_draw_polyline_menace(_logo_body_2, color, width, is_glow_pass)
	# Nose/mouth
	_draw_polyline_menace(_logo_body_3, color, width, is_glow_pass)
	# Jaw
	_draw_polyline_menace(_logo_jaw, color, width, is_glow_pass)
	# Eyes
	_draw_polyline_menace(_logo_left_eye, color, width, is_glow_pass)
	_draw_polyline_menace(_logo_right_eye, color, width, is_glow_pass)

func _draw_text_glow(draw_color: Color, pulse: float) -> void:
	if not _text_label:
		return
	if _alpha < 0.01:
		return
	
	var font: Font = _text_label.get_theme_font("font")
	var font_size: int = _text_label.get_theme_font_size("font_size")
	var text: String = _text_label.text
	
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var text_x := (640.0 - text_width) / 2.0
	var text_y := _text_label.position.y + font.get_ascent(font_size)
	
	# Glitch offset for text
	var x_off: float = 0.0
	if _glitch_active and glitch_enabled:
		x_off = _get_glitch_offset_for_y(text_y)
	if _corrupt_active and corrupt_flash_enabled:
		x_off += _seeded_rand(_corrupt_seed, int(_elapsed_time * 100.0)) * corrupt_displacement * 0.5
		if randf() < 0.3:
			return  # Random text drop during corrupt
	
	var pos := Vector2(text_x + x_off, text_y)
	
	# Glow passes using outline
	if glow_enabled and glow_passes > 0:
		for pass_idx in glow_passes:
			var outline_size: int = int(glow_base_width * float(pass_idx + 1) * 0.5)
			var alpha: float = (glow_intensity + pulse) / float(pass_idx + 1) * _alpha
			var glow_color := Color(draw_color.r, draw_color.g, draw_color.b, clamp(alpha, 0.0, 1.0))
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_size, glow_color)
	
	# Crisp text
	var text_color := Color(draw_color.r, draw_color.g, draw_color.b, _alpha * 0.8)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

func _draw_polyline_menace(points: PackedVector2Array, color: Color, width: float, is_glow_pass: bool) -> void:
	if points.size() < 2:
		return
	
	var modified := PackedVector2Array()
	for p in points:
		var pt := p
		pt.x += horizontal_offset
		if _glitch_active and glitch_enabled and not is_glow_pass:
			pt.x += _get_glitch_offset_for_y(pt.y)
		if _corrupt_active and corrupt_flash_enabled:
			pt = _corrupt_point(pt)
		modified.append(pt)
	
	draw_polyline(modified, color, width, true)