[1mdiff --git a/Godot/entities/nonplayer/bug_ship_swooping_nonplayer.tscn b/Godot/entities/nonplayer/bug_ship_swooping_nonplayer.tscn[m
[1mindex 1ac04be..5a667bd 100644[m
[1m--- a/Godot/entities/nonplayer/bug_ship_swooping_nonplayer.tscn[m
[1m+++ b/Godot/entities/nonplayer/bug_ship_swooping_nonplayer.tscn[m
[36m@@ -67,8 +67,8 @@[m [mbullet_scene = ExtResource("2_fkier")[m
 curve = SubResource("Resource_rgbre")[m
 target_distance = 500.0[m
 loop = true[m
[31m-restart_signals = Array[StringName]([&"screen_wrapped"])[m
 start_signals = Array[StringName]([&"begin_dive"])[m
[32m+[m[32mstop_signals = Array[StringName]([&"screen_wrapped"])[m
 complete_signals = Array[StringName]([&"dive_complete"])[m
 [m
 [node name="SoundVoice3" parent="." index="12" instance=ExtResource("7_rgbre")][m
[1mdiff --git a/Godot/entities/nonplayer/spider_ship_swooping_nonplayer.tscn b/Godot/entities/nonplayer/spider_ship_swooping_nonplayer.tscn[m
[1mindex fd46e1d..977810c 100644[m
[1m--- a/Godot/entities/nonplayer/spider_ship_swooping_nonplayer.tscn[m
[1m+++ b/Godot/entities/nonplayer/spider_ship_swooping_nonplayer.tscn[m
[36m@@ -1,4 +1,4 @@[m
[31m-[gd_scene load_steps=22 format=3 uid="uid://bmypbxacxkn6p"][m
[32m+[m[32m[gd_scene load_steps=24 format=3 uid="uid://bmypbxacxkn6p"][m
 [m
 [ext_resource type="PackedScene" uid="uid://vu1t14u6qvjf" path="res://entities/generic/spider_ship_smooth.tscn" id="1_18u38"][m
 [ext_resource type="PackedScene" uid="uid://wghixqf83pas" path="res://scenes/entity components/brains/ai_swoop_brain.tscn" id="2_f0fqv"][m
[36m@@ -13,6 +13,8 @@[m
 [ext_resource type="PackedScene" uid="uid://domsc1hbv4rsy" path="res://scenes/entity components/arms/score_on_death_arm.tscn" id="11_otbcv"][m
 [ext_resource type="PackedScene" uid="uid://cvhjugy48g6ax" path="res://scenes/entity components/brains/ai_tractor_beam_brain.tscn" id="12_l5wtd"][m
 [ext_resource type="PackedScene" uid="uid://8yty18auwkgf" path="res://scenes/entity components/arms/tractor_beam_arm.tscn" id="13_e2h7j"][m
[32m+[m[32m[ext_resource type="PackedScene" uid="uid://cd5trsg3jfg2b" path="res://scenes/entity components/faces/tractor_beam_face.tscn" id="14_isa45"][m
[32m+[m[32m[ext_resource type="PackedScene" uid="uid://irkjutuwceju" path="res://scenes/entity components/guts/announcer_guts.tscn" id="16_bf6or"][m
 [m
 [sub_resource type="Resource" id="Resource_s7cy4"][m
 script = ExtResource("4_fkier")[m
[36m@@ -60,9 +62,9 @@[m [mnotes = Array[ExtResource("8_aafss")]([SubResource("Resource_vdwk6"), SubResourc[m
 metadata/_custom_type_script = "uid://d3l2c838cqwsm"[m
 [m
 [sub_resource type="ConvexPolygonShape2D" id="ConvexPolygonShape2D_e2h7j"][m
[31m-points = PackedVector2Array(0, 0, 100, 50, 100, -50)[m
[32m+[m[32mpoints = PackedVector2Array(0, 0, 100, 37.5, 100, -37.5)[m
 [m
[31m-[node name="BugShip" instance=ExtResource("1_18u38")][m
[32m+[m[32m[node name="SpiderShip" instance=ExtResource("1_18u38")][m
 groups = Array[StringName]([&"spider_ships", &"ships", &"enemies", &"bosses"])[m
 [m
 [node name="ScreenWrapLeg" parent="." index="0"][m
[36m@@ -78,9 +80,8 @@[m [mmax_health = 2[m
 curve = SubResource("Resource_rgbre")[m
 target_distance = 500.0[m
 loop = true[m
[31m-restart_signals = Array[StringName]([&"screen_wrapped"])[m
 start_signals = Array[StringName]([&"begin_dive"])[m
[31m-stop_signals = Array[StringName]([&"fire_tractor_beam"])[m
[32m+[m[32mstop_signals = Array[StringName]([&"fire_tractor_beam", &"screen_wrapped"])[m
 complete_signals = Array[StringName]([&"dive_complete"])[m
 [m
 [node name="SoundVoice3" parent="." index="13" instance=ExtResource("7_g0k2m")][m
[36m@@ -105,3 +106,8 @@[m [mcomponent_category = 0[m
 beam_shape = SubResource("ConvexPolygonShape2D_e2h7j")[m
 collision_mask = 0[m
 target_groups = Array[StringName]([&"players"])[m
[32m+[m
[32m+[m[32m[node name="TractorBeamFace" parent="." index="18" instance=ExtResource("14_isa45")][m
[32m+[m
[32m+[m[32m[node name="ReturnToFormationAnnouncerGuts" parent="." index="19" instance=ExtResource("16_bf6or")][m
[32m+[m[32mlisten_signals = Array[StringName]([&"tractor_beam_complete"])[m
[1mdiff --git a/Godot/entities/nonplayer/wasp_ship_swooping_nonplayer.tscn b/Godot/entities/nonplayer/wasp_ship_swooping_nonplayer.tscn[m
[1mindex 86fc818..dbcf871 100644[m
[1m--- a/Godot/entities/nonplayer/wasp_ship_swooping_nonplayer.tscn[m
[1m+++ b/Godot/entities/nonplayer/wasp_ship_swooping_nonplayer.tscn[m
[36m@@ -70,8 +70,8 @@[m [mbullet_scene = ExtResource("2_fkier")[m
 curve = SubResource("Resource_ysyd6")[m
 target_distance = 500.0[m
 loop = true[m
[31m-restart_signals = Array[StringName]([&"screen_wrapped"])[m
 start_signals = Array[StringName]([&"begin_dive"])[m
[32m+[m[32mstop_signals = Array[StringName]([&"screen_wrapped"])[m
 complete_signals = Array[StringName]([&"dive_complete"])[m
 [m
 [node name="SoundVoice3" parent="." index="12" instance=ExtResource("7_umhyd")][m
[1mdiff --git a/Godot/entities/player/bug_blaster_2_player.tscn b/Godot/entities/player/bug_blaster_2_player.tscn[m
[1mindex e3fc719..38f5150 100644[m
[1m--- a/Godot/entities/player/bug_blaster_2_player.tscn[m
[1m+++ b/Godot/entities/player/bug_blaster_2_player.tscn[m
[36m@@ -1,4 +1,4 @@[m
[31m-[gd_scene load_steps=8 format=3 uid="uid://cytjg8wb58tpp"][m
[32m+[m[32m[gd_scene load_steps=9 format=3 uid="uid://cytjg8wb58tpp"][m
 [m
 [ext_resource type="PackedScene" uid="uid://btfoj4emj6uld" path="res://entities/generic/sprite_ship.tscn" id="1_b0gck"][m
 [ext_resource type="PackedScene" path="res://scenes/core/infrastructure/cd_body.tscn" id="2_gyn25"][m
[36m@@ -7,11 +7,17 @@[m
 [ext_resource type="PackedScene" uid="uid://c1qciuyo0tvhf" path="res://scenes/entity components/guts/leader_tracker_guts.tscn" id="5_uf4lp"][m
 [ext_resource type="PackedScene" uid="uid://br86r51jieatg" path="res://scenes/entity components/brains/player_action_brain.tscn" id="5_vf8ie"][m
 [ext_resource type="PackedScene" uid="uid://ci8074saofo8y" path="res://scenes/entity components/brains/ai_escort_brain.tscn" id="6_oqelq"][m
[32m+[m[32m[ext_resource type="PackedScene" uid="uid://irkjutuwceju" path="res://scenes/entity components/guts/announcer_guts.tscn" id="8_aoipd"][m
 [m
[31m-[node name="SpriteShip" instance=ExtResource("1_b0gck")][m
[32m+[m[32m[node name="PlayerShip" instance=ExtResource("1_b0gck")][m
 groups = Array[StringName]([&"sprite_ships", &"ships", &"players"])[m
[32m+[m[32mcollision_radius = 8.0[m
 lock_y = true[m
 clamp_to_bounds = true[m
[32m+[m[32munlock_y_on = Array[StringName]([&"player_captured"])[m
[32m+[m[32mlock_y_on = Array[StringName]([&"escort_achieved"])[m
[32m+[m[32munclamp_bounds_on = Array[StringName]([&"player_captured"])[m
[32m+[m[32mclamp_bounds_on = Array[StringName]([&"escort_achieved"])[m
 [m
 [node name="GunArm" parent="." index="1"][m
 bullet_scene = ExtResource("2_vf8ie")[m
[36m@@ -37,7 +43,16 @@[m [mwake_on = Array[StringName]([&"player_captured"])[m
 [node name="LeaderTrackerGuts" parent="CapturedBody" index="0" instance=ExtResource("5_uf4lp")][m
 [m
 [node name="AIEscortBrain" parent="CapturedBody" index="1" instance=ExtResource("6_oqelq")][m
[31m-offset = Vector2(0, -8)[m
[32m+[m[32mblackboard_source = null[m
[32m+[m[32mtarget_entity_key = null[m
[32m+[m[32mtarget_groups = null[m
[32m+[m[32moffset = Vector2(0, -16)[m
[32m+[m[32mstop_when_close = false[m
[32m+[m[32mclose_distance = 0.0[m
[32m+[m[32mmove_direction_key = null[m
[32m+[m[32mmove_distance_key = null[m
[32m+[m[32marrived_signals = Array[StringName]([])[m
[32m+[m[32mcomponent_category = null[m
 [m
 [node name="RescuedBody" parent="." index="12" instance=ExtResource("2_gyn25")][m
 start_asleep = true[m
[36m@@ -46,6 +61,20 @@[m [mwake_on = Array[StringName]([&"leader_destroyed"])[m
 [m
 [node name="AIEscortBrain" parent="RescuedBody" index="0" instance=ExtResource("6_oqelq")][m
 blackboard_source = 1[m
[31m-target_entity_key = &"active_player"[m
[32m+[m[32mtarget_entity_key = &""[m
[32m+[m[32mtarget_groups = Array[StringName]([&"players"])[m
 offset = Vector2(16, 0)[m
[31m-close_distance = 0.01[m
[32m+[m[32mstop_when_close = null[m
[32m+[m[32mclose_distance = 0.1[m
[32m+[m[32mmove_direction_key = null[m
[32m+[m[32mmove_distance_key = null[m
[32m+[m[32marrived_signals = null[m
[32m+[m[32mcomponent_category = null[m
[32m+[m
[32m+[m[32m[node name="CapturedAnnouncer" parent="." index="13" instance=ExtResource("8_aoipd")][m
[32m+[m[32mlisten_signals = Array[StringName]([&"player_captured"])[m
[32m+[m[32mrebroadcast_signals = Array[StringName]([&"player_captured"])[m
[32m+[m
[32m+[m[32m[node name="RescuedAnnouncer2" parent="." index="14" instance=ExtResource("8_aoipd")][m
[32m+[m[32mlisten_signals = Array[StringName]([&"escort_achieved"])[m
[32m+[m[32mrebroadcast_signals = Array[StringName]([&"player_rescued"])[m
[1mdiff --git a/Godot/games/bug_blaster_2.tscn b/Godot/games/bug_blaster_2.tscn[m
[1mindex faf4a5d..70127fb 100644[m
[1m--- a/Godot/games/bug_blaster_2.tscn[m
[1m+++ b/Godot/games/bug_blaster_2.tscn[m
[36m@@ -1,4 +1,4 @@[m
[31m-[gd_scene load_steps=164 format=3 uid="uid://c0q0c0v84x80"][m
[32m+[m[32m[gd_scene load_steps=173 format=3 uid="uid://c0q0c0v84x80"][m
 [m
 [ext_resource type="Script" uid="uid://dm0uehngpvbh7" path="res://scripts/core/infrastructure/cd_game.gd" id="1_62wb8"][m
 [ext_resource type="PackedScene" uid="uid://cmbx6xnct372t" path="res://scenes/core/infrastructure/cd_collision_buffer.tscn" id="2_7y1r2"][m
[36m@@ -20,11 +20,11 @@[m
 [ext_resource type="PackedScene" uid="uid://ca4qbo05yiya" path="res://scenes/game components/directors/swoop_director.tscn" id="14_bnks8"][m
 [ext_resource type="Script" uid="uid://dlalvxnq5qb5x" path="res://scripts/core/resources/curves/cd_curve.gd" id="15_34iby"][m
 [ext_resource type="Script" uid="uid://dpgs8b1skt7t2" path="res://scripts/core/resources/curves/cd_sine_curve.gd" id="16_4yrl4"][m
[32m+[m[32m[ext_resource type="PackedScene" path="res://scenes/game components/managers/state_manager.tscn" id="16_ifna5"][m
 [ext_resource type="Script" uid="uid://dakcd8kk2xm44" path="res://scripts/core/resources/curves/cd_sequence_curve.gd" id="17_hm20g"][m
 [ext_resource type="Script" uid="uid://b7yxnmuk1vkya" path="res://scripts/core/resources/curves/cd_parabola_curve.gd" id="17_la2sg"][m
 [ext_resource type="PackedScene" uid="uid://b7uyqydnog2th" path="res://scenes/game components/directors/formation_director.tscn" id="18_156p0"][m
 [ext_resource type="PackedScene" uid="uid://b0n0yuhdj7x5x" path="res://entities/nonplayer/wasp_ship_swooping_nonplayer.tscn" id="18_sjgbx"][m
[31m-[ext_resource type="PackedScene" uid="uid://bf43dpgnegd46" path="res://scenes/game components/directors/state_director.tscn" id="19_g3xn7"][m
 [ext_resource type="PackedScene" uid="uid://bmypbxacxkn6p" path="res://entities/nonplayer/spider_ship_swooping_nonplayer.tscn" id="19_ldmk8"][m
 [ext_resource type="Script" uid="uid://2krdfmhel0jp" path="res://scripts/core/resources/behavior/cd_transition.gd" id="20_k70bp"][m
 [ext_resource type="Script" uid="uid://7j04axulu7rq" path="res://scripts/core/resources/curves/cd_circle_curve.gd" id="21_1nsuk"][m
[36m@@ -58,6 +58,7 @@[m
 [sub_resource type="Resource" id="Resource_q4h5u"][m
 script = ExtResource("4_xb0do")[m
 group_name = &"players"[m
[32m+[m[32mcollides_with = Array[StringName]([&"players"])[m
 metadata/_custom_type_script = "uid://b2ibop6r2cryj"[m
 [m
 [sub_resource type="Resource" id="Resource_qh32t"][m
[36m@@ -184,90 +185,6 @@[m [msleep_stages = Array[StringName]([&"Level5Stage"])[m
 wake_stages = Array[StringName]([&"Level1Stage"])[m
 metadata/_custom_type_script = "uid://1ag25dxeklvd"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_la2sg"][m
[31m-script = ExtResource("12_rgict")[m
[31m-additional_groups = Array[StringName]([&"swooping", &"left"])[m
[31m-metadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_s3e4k"][m
[31m-script = ExtResource("12_rgict")[m
[31m-additional_groups = Array[StringName]([&"swooping", &"right"])[m
[31m-metadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_owvki"][m
[31m-script = ExtResource("12_rgict")[m
[31m-additional_groups = Array[StringName]([&"swooping", &"bottom_left"])[m
[31m-metadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_ldmk8"][m
[31m-script = ExtResource("12_rgict")[m
[31m-additional_groups = Array[StringName]([&"swooping", &"bottom_right"])[m
[31m-metadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_qhmbs"][m
[31m-script = ExtResource("17_la2sg")[m
[31m-amplitude = -96.0[m
[31m-curvature = 4.0[m
[31m-direction = 2[m
[31m-curve_seed = 2[m
[31m-offset = Vector2(-32, 32)[m
[31m-reverse = true[m
[31m-metadata/_custom_type_script = "uid://b7yxnmuk1vkya"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_156p0"][m
[31m-script = ExtResource("16_4yrl4")[m
[31m-amplitude = 96.0[m
[31m-frequency = 2[m
[31m-offset = Vector2(0, 64)[m
[31m-metadata/_custom_type_script = "uid://dpgs8b1skt7t2"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_jix4n"][m
[31m-script = ExtResource("17_hm20g")[m
[31m-curves = Array[ExtResource("15_34iby")]([SubResource("Resource_qhmbs"), SubResource("Resource_156p0")])[m
[31m-metadata/_custom_type_script = "uid://dakcd8kk2xm44"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_1nsuk"][m
[31m-script = ExtResource("17_la2sg")[m
[31m-amplitude = 96.0[m
[31m-curvature = 4.0[m
[31m-direction = 2[m
[31m-curve_seed = 2[m
[31m-offset = Vector2(32, 32)[m
[31m-reverse = true[m
[31m-metadata/_custom_type_script = "uid://b7yxnmuk1vkya"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_1tdfd"][m
[31m-script = ExtResource("16_4yrl4")[m
[31m-amplitude = 96.0[m
[31m-frequency = 2[m
[31m-offset = Vector2(0, 64)[m
[31m-reverse = true[m
[31m-metadata/_custom_type_script = "uid://dpgs8b1skt7t2"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_g3xn7"][m
[31m-script = ExtResource("17_hm20g")[m
[31m-curves = Array[ExtResource("15_34iby")]([SubResource("Resource_1nsuk"), SubResource("Resource_1tdfd")])[m
[31m-metadata/_custom_type_script = "uid://dakcd8kk2xm44"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_2bq8q"][m
[31m-script = ExtResource("21_1nsuk")[m
[31m-radius_x = 48.0[m
[31m-radius_y = 48.0[m
[31m-loops = 2[m
[31m-curve_seed = -1[m
[31m-offset = Vector2(-192, 192)[m
[31m-reverse = true[m
[31m-metadata/_custom_type_script = "uid://7j04axulu7rq"[m
[31m-[m
[31m-[sub_resource type="Resource" id="Resource_rvvw1"][m
[31m-script = ExtResource("21_1nsuk")[m
[31m-radius_x = 48.0[m
[31m-radius_y = 48.0[m
[31m-loops = 2[m
[31m-curve_seed = -2[m
[31m-offset = Vector2(192, 192)[m
[31m-metadata/_custom_type_script = "uid://7j04axulu7rq"[m
[31m-[m
 [sub_resource type="Resource" id="Resource_4mgkk"][m
 script = ExtResource("22_jix4n")[m
 preferred_group = &"bosses"[m
[36m@@ -336,52 +253,109 @@[m [mminimum = 1.0[m
 maximum = 5.0[m
 metadata/_custom_type_script = "uid://bd5apwoshu3n6"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_r24yj"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_xatni"][m
 script = ExtResource("21_k70bp")[m
 signal_name = &"swoop_complete"[m
[32m+[m[32mmetadata/_custom_type_script = "uid://3ciu0vvrmmb7"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_k70bp"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_682rw"][m
 script = ExtResource("21_g3xn7")[m
 signal_names = Array[StringName]([&"swoop_complete"])[m
 metadata/_custom_type_script = "uid://ca0k2u53egerl"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_5kasm"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_sdj2a"][m
 script = ExtResource("20_k70bp")[m
 remove_groups = Array[StringName]([&"swooping"])[m
 add_groups = Array[StringName]([&"formation"])[m
 target_groups = Array[StringName]([&"swooping"])[m
[31m-trigger = SubResource("Resource_k70bp")[m
[31m-selector = SubResource("Resource_r24yj")[m
[32m+[m[32mtrigger = SubResource("Resource_682rw")[m
[32m+[m[32mselector = SubResource("Resource_xatni")[m
 metadata/_custom_type_script = "uid://2krdfmhel0jp"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_sdj2a"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_8klk8"][m
 script = ExtResource("27_1nsuk")[m
 metadata/_custom_type_script = "uid://bgl0fyqd8o0w5"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_dive_scaler"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_0na4m"][m
 script = ExtResource("25_hc4eh")[m
[31m-per_wave = -2.25[m
[31m-base = 10.0[m
[31m-minimum = 1.0[m
[32m+[m[32mper_wave = -1.0[m
[32m+[m[32mminimum = 5.0[m
 metadata/_custom_type_script = "uid://bd5apwoshu3n6"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_xatni"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_45xdf"][m
 script = ExtResource("24_gc4j8")[m
 interval = 10.0[m
[31m-wave_scaler = SubResource("Resource_dive_scaler")[m
[31m-random_variance = 1.0[m
[32m+[m[32mwave_scaler = SubResource("Resource_0na4m")[m
[32m+[m[32mrandom_variance = 2.0[m
 metadata/_custom_type_script = "uid://dm2djsydyr0u1"[m
 [m
[31m-[sub_resource type="Resource" id="Resource_682rw"][m
[32m+[m[32m[sub_resource type="Resource" id="Resource_huovk"][m
 script = ExtResource("20_k70bp")[m
 remove_groups = Array[StringName]([&"formation"])[m
 add_groups = Array[StringName]([&"diving"])[m
 target_groups = Array[StringName]([&"formation"])[m
[31m-trigger = SubResource("Resource_xatni")[m
[31m-selector = SubResource("Resource_sdj2a")[m
[32m+[m[32mtrigger = SubResource("Resource_45xdf")[m
[32m+[m[32mselector = SubResource("Resource_8klk8")[m
 entity_signals = Array[StringName]([&"begin_dive"])[m
 metadata/_custom_type_script = "uid://2krdfmhel0jp"[m
 [m
[32m+[m[32m[sub_resource type="Resource" id="Resource_lgav2"][m
[32m+[m[32mscript = ExtResource("21_k70bp")[m
[32m+[m[32msignal_name = &"player_captured"[m
[32m+[m[32mmetadata/_custom_type_script = "uid://3ciu0vvrmmb7"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_mo7to"][m
[32m+[m[32mscript = ExtResource("21_g3xn7")[m
[32m+[m[32msignal_names = Array[StringName]([&"player_captured"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://ca0k2u53egerl"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_17gxj"][m
[32m+[m[32mscript = ExtResource("20_k70bp")[m
[32m+[m[32mremove_groups = Array[StringName]([&"players"])[m
[32m+[m[32madd_groups = Array[StringName]([&"enemies"])[m
[32m+[m[32mtarget_groups = Array[StringName]([&"players"])[m
[32m+[m[32mtrigger = SubResource("Resource_mo7to")[m
[32m+[m[32mselector = SubResource("Resource_lgav2")[m
[32m+[m[32mmetadata/_custom_type_script = "uid://2krdfmhel0jp"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_tcsmy"][m
[32m+[m[32mscript = ExtResource("21_k70bp")[m
[32m+[m[32msignal_name = &"player_rescued"[m
[32m+[m[32mmetadata/_custom_type_script = "uid://3ciu0vvrmmb7"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_ex8ce"][m
[32m+[m[32mscript = ExtResource("21_g3xn7")[m
[32m+[m[32msignal_names = Array[StringName]([&"player_rescued"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://ca0k2u53egerl"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_wavnc"][m
[32m+[m[32mscript = ExtResource("20_k70bp")[m
[32m+[m[32mremove_groups = Array[StringName]([&"enemies"])[m
[32m+[m[32madd_groups = Array[StringName]([&"players"])[m
[32m+[m[32mtarget_groups = Array[StringName]([&"enemies"])[m
[32m+[m[32mtrigger = SubResource("Resource_ex8ce")[m
[32m+[m[32mselector = SubResource("Resource_tcsmy")[m
[32m+[m[32mmetadata/_custom_type_script = "uid://2krdfmhel0jp"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_vjjft"][m
[32m+[m[32mscript = ExtResource("21_k70bp")[m
[32m+[m[32msignal_name = &"dive_complete"[m
[32m+[m[32mmetadata/_custom_type_script = "uid://3ciu0vvrmmb7"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_tmxlt"][m
[32m+[m[32mscript = ExtResource("21_g3xn7")[m
[32m+[m[32msignal_names = Array[StringName]([&"dive_complete"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://ca0k2u53egerl"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_qsrt0"][m
[32m+[m[32mscript = ExtResource("20_k70bp")[m
[32m+[m[32mremove_groups = Array[StringName]([&"diving"])[m
[32m+[m[32madd_groups = Array[StringName]([&"formation"])[m
[32m+[m[32mtarget_groups = Array[StringName]([&"diving"])[m
[32m+[m[32mtrigger = SubResource("Resource_tmxlt")[m
[32m+[m[32mselector = SubResource("Resource_vjjft")[m
[32m+[m[32mmetadata/_custom_type_script = "uid://2krdfmhel0jp"[m
[32m+[m
 [sub_resource type="Resource" id="Resource_20wdp"][m
 script = ExtResource("25_hc4eh")[m
 per_wave = -1.1875[m
[36m@@ -400,6 +374,90 @@[m [mmetadata/_custom_type_script = "uid://dm2djsydyr0u1"[m
 script = ExtResource("26_gc4j8")[m
 metadata/_custom_type_script = "uid://b3xaxo1yp2dn1"[m
 [m
[32m+[m[32m[sub_resource type="Resource" id="Resource_la2sg"][m
[32m+[m[32mscript = ExtResource("12_rgict")[m
[32m+[m[32madditional_groups = Array[StringName]([&"swooping", &"left"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_s3e4k"][m
[32m+[m[32mscript = ExtResource("12_rgict")[m
[32m+[m[32madditional_groups = Array[StringName]([&"swooping", &"right"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_owvki"][m
[32m+[m[32mscript = ExtResource("12_rgict")[m
[32m+[m[32madditional_groups = Array[StringName]([&"swooping", &"bottom_left"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_ldmk8"][m
[32m+[m[32mscript = ExtResource("12_rgict")[m
[32m+[m[32madditional_groups = Array[StringName]([&"swooping", &"bottom_right"])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dcu4ocnin0htu"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_qhmbs"][m
[32m+[m[32mscript = ExtResource("17_la2sg")[m
[32m+[m[32mamplitude = -96.0[m
[32m+[m[32mcurvature = 4.0[m
[32m+[m[32mdirection = 2[m
[32m+[m[32mcurve_seed = 2[m
[32m+[m[32moffset = Vector2(-32, 32)[m
[32m+[m[32mreverse = true[m
[32m+[m[32mmetadata/_custom_type_script = "uid://b7yxnmuk1vkya"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_156p0"][m
[32m+[m[32mscript = ExtResource("16_4yrl4")[m
[32m+[m[32mamplitude = 96.0[m
[32m+[m[32mfrequency = 2[m
[32m+[m[32moffset = Vector2(0, 64)[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dpgs8b1skt7t2"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_jix4n"][m
[32m+[m[32mscript = ExtResource("17_hm20g")[m
[32m+[m[32mcurves = Array[ExtResource("15_34iby")]([SubResource("Resource_qhmbs"), SubResource("Resource_156p0")])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dakcd8kk2xm44"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_1nsuk"][m
[32m+[m[32mscript = ExtResource("17_la2sg")[m
[32m+[m[32mamplitude = 96.0[m
[32m+[m[32mcurvature = 4.0[m
[32m+[m[32mdirection = 2[m
[32m+[m[32mcurve_seed = 2[m
[32m+[m[32moffset = Vector2(32, 32)[m
[32m+[m[32mreverse = true[m
[32m+[m[32mmetadata/_custom_type_script = "uid://b7yxnmuk1vkya"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_1tdfd"][m
[32m+[m[32mscript = ExtResource("16_4yrl4")[m
[32m+[m[32mamplitude = 96.0[m
[32m+[m[32mfrequency = 2[m
[32m+[m[32moffset = Vector2(0, 64)[m
[32m+[m[32mreverse = true[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dpgs8b1skt7t2"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_g3xn7"][m
[32m+[m[32mscript = ExtResource("17_hm20g")[m
[32m+[m[32mcurves = Array[ExtResource("15_34iby")]([SubResource("Resource_1nsuk"), SubResource("Resource_1tdfd")])[m
[32m+[m[32mmetadata/_custom_type_script = "uid://dakcd8kk2xm44"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_2bq8q"][m
[32m+[m[32mscript = ExtResource("21_1nsuk")[m
[32m+[m[32mradius_x = 48.0[m
[32m+[m[32mradius_y = 48.0[m
[32m+[m[32mloops = 2[m
[32m+[m[32mcurve_seed = -1[m
[32m+[m[32moffset = Vector2(-192, 192)[m
[32m+[m[32mreverse = true[m
[32m+[m[32mmetadata/_custom_type_script = "uid://7j04axulu7rq"[m
[32m+[m
[32m+[m[32m[sub_resource type="Resource" id="Resource_rvvw1"][m
[32m+[m[32mscript = ExtResource("21_1nsuk")[m
[32m+[m[32mradius_x = 48.0[m
[32m+[m[32mradius_y = 48.0[m
[32m+[m[32mloops = 2[m
[32m+[m[32mcurve_seed = -2[m
[32m+[m[32moffset = Vector2(192, 192)[m
[32m+[m[32mmetadata/_custom_type_script = "uid://7j04axulu7rq"[m
[32m+[m
 [sub_resource type="Resource" id="Resource_x8buj"][m
 script = ExtResource("34_1nsuk")[m
 signals = Array[StringName]([&"ambience"])[m
[36m@@ -792,6 +850,29 @@[m [mtracked_actions = Array[StringName]([&"fire", &"thrust", &"thrust_end"])[m
 [node name="StageManager" parent="." instance=ExtResource("8_kgu26")][m
 rules = Array[ExtResource("9_vaj0o")]([SubResource("Resource_dsfuj"), SubResource("Resource_1ivtp"), SubResource("Resource_rule_l2l3"), SubResource("Resource_rule_l3l4"), SubResource("Resource_rule_l4l5"), SubResource("Resource_rule_l5l1")])[m
 [m
[32m+[m[32m[node name="FormationDirector" parent="." instance=ExtResource("18_156p0")][m
[32m+[m[32mposition = Vector2(320, 64)[m
[32m+[m[32mformations = Array[ExtResource("22_jix4n")]([SubResource("Resource_4mgkk"), SubResource("Resource_kgu26"), SubResource("Resource_vaj0o")])[m
[32m+[m[32mbreathing_amplitude = 0.25[m
[32m+[m[32mbreathing_duration = 10.0[m
[32m+[m[32mmarching_orders = Array[ExtResource("23_1k33r")]([SubResource("Resource_asuvp"), SubResource("Resource_5umtv"), SubResource("Resource_8nemr"), SubResource("Resource_sjgbx")])[m
[32m+[m[32mspeed_scaler = SubResource("Resource_speed_scaler")[m
[32m+[m[32mpreview_color = Color(1, 0.64705884, 0, 1)[m
[32m+[m[32mcomponent_category = 10[m
[32m+[m
[32m+[m[32m[node name="StateManager" parent="." instance=ExtResource("16_ifna5")][m
[32m+[m[32mtransitions = Array[ExtResource("20_k70bp")]([SubResource("Resource_sdj2a"), SubResource("Resource_huovk"), SubResource("Resource_17gxj"), SubResource("Resource_wavnc"), SubResource("Resource_qsrt0")])[m
[32m+[m
[32m+[m[32m[node name="ShootingDirector" parent="." instance=ExtResource("23_7jcia")][m
[32m+[m[32mtarget_groups = Array[StringName]([&"bug_ships", &"wasp_ships"])[m
[32m+[m[32mtrigger = SubResource("Resource_blp8l")[m
[32m+[m[32mselector = SubResource("Resource_hc4eh")[m
[32m+[m[32mcomponent_category = 10[m
[32m+[m
[32m+[m[32m[node name="AimingDirector" parent="." instance=ExtResource("27_hc4eh")][m
[32m+[m[32mtargeting_noise = 4.0[m
[32m+[m[32mcomponent_category = 10[m
[32m+[m
 [node name="Level1Stage" parent="." groups=["level_stages"] instance=ExtResource("8_4mgkk")][m
 start_asleep = true[m
 on_wake_signal = &"level_start"[m
[36m@@ -884,29 +965,6 @@[m [mlane_count = 2[m
 trigger_signals = Array[StringName]([&"spawning_complete_bottom_right"])[m
 preview_color = Color(0.75, 0.75, 0.75, 1)[m
 [m
[31m-[node name="FormationDirector" parent="Level1Stage" instance=ExtResource("18_156p0")][m
[31m-position = Vector2(320, 64)[m
[31m-formations = Array[ExtResource("22_jix4n")]([SubResource("Resource_4mgkk"), SubResource("Resource_kgu26"), SubResource("Resource_vaj0o")])[m
[31m-breathing_amplitude = 0.25[m
[31m-breathing_duration = 10.0[m
[31m-marching_orders = Array[ExtResource("23_1k33r")]([SubResource("Resource_asuvp"), SubResource("Resource_5umtv"), SubResource("Resource_8nemr"), SubResource("Resource_sjgbx")])[m
[31m-speed_scaler = SubResource("Resource_speed_scaler")[m
[31m-preview_color = Color(1, 0.64705884, 0, 1)[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="StateDirector" parent="Level1Stage" instance=ExtResource("19_g3xn7")][m
[31m-position = Vector2(320, -16)[m
[31m-transitions = Array[ExtResource("20_k70bp")]([SubResource("Resource_5kasm"), SubResource("Resource_682rw")])[m
[31m-[m
[31m-[node name="ShootingDirector" parent="Level1Stage" instance=ExtResource("23_7jcia")][m
[31m-trigger = SubResource("Resource_blp8l")[m
[31m-selector = SubResource("Resource_hc4eh")[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="AimingDirector" parent="Level1Stage" instance=ExtResource("27_hc4eh")][m
[31m-targeting_noise = 4.0[m
[31m-component_category = 10[m
[31m-[m
 [node name="SignalManager" parent="Level1Stage" instance=ExtResource("32_acn14")][m
 steps = Array[ExtResource("34_1nsuk")]([SubResource("Resource_x8buj"), SubResource("Resource_p87tt"), SubResource("Resource_ifna5"), SubResource("Resource_j0bx8"), SubResource("Resource_52c78"), SubResource("Resource_q4en4")])[m
 trigger = SubResource("Resource_acn14")[m
[36m@@ -1007,29 +1065,6 @@[m [mlane_count = 2[m
 trigger_signals = Array[StringName]([&"spawning_complete_bottom_right"])[m
 preview_color = Color(1, 0.5, 0.5, 1)[m
 [m
[31m-[node name="FormationDirector" parent="Level2Stage" instance=ExtResource("18_156p0")][m
[31m-position = Vector2(320, 64)[m
[31m-formations = Array[ExtResource("22_jix4n")]([SubResource("Resource_4mgkk"), SubResource("Resource_kgu26"), SubResource("Resource_vaj0o")])[m
[31m-breathing_amplitude = 0.25[m
[31m-breathing_duration = 10.0[m
[31m-marching_orders = Array[ExtResource("23_1k33r")]([SubResource("Resource_asuvp"), SubResource("Resource_5umtv"), SubResource("Resource_8nemr"), SubResource("Resource_sjgbx")])[m
[31m-speed_scaler = SubResource("Resource_speed_scaler")[m
[31m-preview_color = Color(0, 0.8, 1, 1)[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="StateDirector" parent="Level2Stage" instance=ExtResource("19_g3xn7")][m
[31m-position = Vector2(320, -16)[m
[31m-transitions = Array[ExtResource("20_k70bp")]([SubResource("Resource_5kasm"), SubResource("Resource_682rw")])[m
[31m-[m
[31m-[node name="ShootingDirector" parent="Level2Stage" instance=ExtResource("23_7jcia")][m
[31m-trigger = SubResource("Resource_blp8l")[m
[31m-selector = SubResource("Resource_hc4eh")[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="AimingDirector" parent="Level2Stage" instance=ExtResource("27_hc4eh")][m
[31m-targeting_noise = 4.0[m
[31m-component_category = 10[m
[31m-[m
 [node name="SignalManager" parent="Level2Stage" instance=ExtResource("32_acn14")][m
 steps = Array[ExtResource("34_1nsuk")]([SubResource("Resource_4ia1r"), SubResource("Resource_l2_s1"), SubResource("Resource_l2_s2"), SubResource("Resource_l2_s3"), SubResource("Resource_l2_s4"), SubResource("Resource_l2_s5")])[m
 trigger = SubResource("Resource_acn14")[m
[36m@@ -1128,29 +1163,6 @@[m [mlane_count = 2[m
 trigger_signals = Array[StringName]([&"spawning_complete_bottom_right"])[m
 preview_color = Color(0.6, 0, 1, 1)[m
 [m
[31m-[node name="FormationDirector" parent="Level3Stage" instance=ExtResource("18_156p0")][m
[31m-position = Vector2(320, 64)[m
[31m-formations = Array[ExtResource("22_jix4n")]([SubResource("Resource_4mgkk"), SubResource("Resource_kgu26"), SubResource("Resource_vaj0o")])[m
[31m-breathing_amplitude = 0.25[m
[31m-breathing_duration = 10.0[m
[31m-marching_orders = Array[ExtResource("23_1k33r")]([SubResource("Resource_asuvp"), SubResource("Resource_5umtv"), SubResource("Resource_8nemr"), SubResource("Resource_sjgbx")])[m
[31m-speed_scaler = SubResource("Resource_speed_scaler")[m
[31m-preview_color = Color(1, 0, 0.8, 1)[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="StateDirector" parent="Level3Stage" instance=ExtResource("19_g3xn7")][m
[31m-position = Vector2(320, -16)[m
[31m-transitions = Array[ExtResource("20_k70bp")]([SubResource("Resource_5kasm"), SubResource("Resource_682rw")])[m
[31m-[m
[31m-[node name="ShootingDirector" parent="Level3Stage" instance=ExtResource("23_7jcia")][m
[31m-trigger = SubResource("Resource_blp8l")[m
[31m-selector = SubResource("Resource_hc4eh")[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="AimingDirector" parent="Level3Stage" instance=ExtResource("27_hc4eh")][m
[31m-targeting_noise = 4.0[m
[31m-component_category = 10[m
[31m-[m
 [node name="SignalManager" parent="Level3Stage" instance=ExtResource("32_acn14")][m
 steps = Array[ExtResource("34_1nsuk")]([SubResource("Resource_umh4f"), SubResource("Resource_l3_s1"), SubResource("Resource_l3_s2"), SubResource("Resource_l3_s3"), SubResource("Resource_l3_s4"), SubResource("Resource_l3_s5")])[m
 trigger = SubResource("Resource_acn14")[m
[36m@@ -1251,29 +1263,6 @@[m [mlane_count = 2[m
 trigger_signals = Array[StringName]([&"spawning_complete_bottom_right"])[m
 preview_color = Color(0, 1, 0.5, 1)[m
 [m
[31m-[node name="FormationDirector" parent="Level4Stage" instance=ExtResource("18_156p0")][m
[31m-position = Vector2(320, 64)[m
[31m-formations = Array[ExtResource("22_jix4n")]([SubResource("Resource_4mgkk"), SubResource("Resource_kgu26"), SubResource("Resource_vaj0o")])[m
[31m-breathing_amplitude = 0.25[m
[31m-breathing_duration = 10.0[m
[31m-marching_orders = Array[ExtResource("23_1k33r")]([SubResource("Resource_asuvp"), SubResource("Resource_5umtv"), SubResource("Resource_8nemr"), SubResource("Resource_sjgbx")])[m
[31m-speed_scaler = SubResource("Resource_speed_scaler")[m
[31m-preview_color = Color(0.5, 1, 0, 1)[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="StateDirector" parent="Level4Stage" instance=ExtResource("19_g3xn7")][m
[31m-position = Vector2(320, -16)[m
[31m-transitions = Array[ExtResource("20_k70bp")]([SubResource("Resource_5kasm"), SubResource("Resource_682rw")])[m
[31m-[m
[31m-[node name="ShootingDirector" parent="Level4Stage" instance=ExtResource("23_7jcia")][m
[31m-trigger = SubResource("Resource_blp8l")[m
[31m-selector = SubResource("Resource_hc4eh")[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="AimingDirector" parent="Level4Stage" instance=ExtResource("27_hc4eh")][m
[31m-targeting_noise = 4.0[m
[31m-component_category = 10[m
[31m-[m
 [node name="SignalManager" parent="Level4Stage" instance=ExtResource("32_acn14")][m
 steps = Array[ExtResource("34_1nsuk")]([SubResource("Resource_drhtc"), SubResource("Resource_l4_s1"), SubResource("Resource_l4_s2"), SubResource("Resource_l4_s3")])[m
 trigger = SubResource("Resource_acn14")[m
[36m@@ -1372,29 +1361,6 @@[m [mformation_offset = 32.0[m
 trigger_signals = Array[StringName]([&"spawning_complete_bottom_right"])[m
 preview_color = Color(1, 0.4, 0.7, 1)[m
 [m
[31m-[node name="FormationDirector" parent="Level5Stage" instance=ExtResource("18_156p0")][m
[31m-position = Vector2(320, 64)[m
[31m-formations = Array[ExtResource("22_jix4n")]([SubResource("Resource_4mgkk"), SubResource("Resource_kgu26"), SubResource("Resource_vaj0o")])[m
[31m-breathing_amplitude = 0.25[m
[31m-breathing_duration = 10.0[m
[31m-marching_orders = Array[ExtResource("23_1k33r")]([SubResource("Resource_asuvp"), SubResource("Resource_5umtv"), SubResource("Resource_8nemr"), SubResource("Resource_sjgbx")])[m
[31m-speed_scaler = SubResource("Resource_speed_scaler")[m
[31m-preview_color = Color(1, 0.84, 0, 1)[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="StateDirector" parent="Level5Stage" instance=ExtResource("19_g3xn7")][m
[31m-position = Vector2(320, -16)[m
[31m-transitions = Array[ExtResource("20_k70bp")]([SubResource("Resource_5kasm"), SubResource("Resource_682rw")])[m
[31m-[m
[31m-[node name="ShootingDirector" parent="Level5Stage" instance=ExtResource("23_7jcia")][m
[31m-trigger = SubResource("Resource_blp8l")[m
[31m-selector = SubResource("Resource_hc4eh")[m
[31m-component_category = 10[m
[31m-[m
[31m-[node name="AimingDirector" parent="Level5Stage" instance=ExtResource("27_hc4eh")][m
[31m-targeting_noise = 4.0[m
[31m-component_category = 10[m
[31m-[m
 [node name="SignalManager" parent="Level5Stage" instance=ExtResource("32_acn14")][m
 steps = Array[ExtResource("34_1nsuk")]([SubResource("Resource_dq8qt"), SubResource("Resource_l5_s1"), SubResource("Resource_l5_s2"), SubResource("Resource_l5_s3"), SubResource("Resource_l5_s4"), SubResource("Resource_l5_s5")])[m
 trigger = SubResource("Resource_acn14")[m
[36m@@ -1459,11 +1425,20 @@[m [mgame_result = 1[m
 on_score_changed = Array[StringName]([&"life_lost"])[m
 on_condition_met = Array[StringName]([&"game_over"])[m
 [m
[31m-[node name="CdMark" parent="." instance=ExtResource("54_682rw")][m
[32m+[m[32m[node name="TractorMark" parent="." instance=ExtResource("54_682rw")][m
 position = Vector2(320, 265)[m
 groups = Array[StringName]([&"tractor_line"])[m
[31m-filter_groups = Array[StringName]([&"spider_ships"])[m
[32m+[m[32mfilter_groups = Array[StringName]([&"diving"])[m
 on_entered_entity = Array[StringName]([&"fire_tractor_beam"])[m
 [m
[31m-[node name="CollisionShape2D" type="CollisionShape2D" parent="CdMark"][m
[32m+[m[32m[node name="CollisionShape2D" type="CollisionShape2D" parent="TractorMark"][m
[32m+[m[32mshape = SubResource("RectangleShape2D_682rw")[m
[32m+[m
[32m+[m[32m[node name="DiveMark" parent="." instance=ExtResource("54_682rw")][m
[32m+[m[32mposition = Vector2(320, -16)[m
[32m+[m[32mgroups = Array[StringName]([&"tractor_line"])[m
[32m+[m[32mfilter_groups = Array[StringName]([&"diving"])[m
[32m+[m[32mon_entered_entity = Array[StringName]([&"begin_dive"])[m
[32m+[m
[32m+[m[32m[node name="CollisionShape2D" type="CollisionShape2D" parent="DiveMark"][m
 shape = SubResource("RectangleShape2D_682rw")[m
[1mdiff --git a/Godot/scripts/entity components/arms/triggered arms/tractor_beam_arm.gd b/Godot/scripts/entity components/arms/triggered arms/tractor_beam_arm.gd[m
[1mindex aea420d..4cf64f0 100644[m
[1m--- a/Godot/scripts/entity components/arms/triggered arms/tractor_beam_arm.gd[m	
[1m+++ b/Godot/scripts/entity components/arms/triggered arms/tractor_beam_arm.gd[m	
[36m@@ -125,11 +125,8 @@[m [mfunc _execute_capture(target: CDEntity) -> void:[m
 	target.blackboard[captor_blackboard_key] = entity[m
 	[m
 	## emit on target's entity bus[m
[31m-	if target.has_signal("player_captured"):[m
[31m-		target.bus_emit("player_captured")[m
[31m-		[m
[31m-	## emit on game bus[m
[31m-	game.bus_emit("player_captured")[m
[32m+[m	[32mfor sig in capture_signals:[m
[32m+[m		[32mtarget.bus_emit(sig)[m
 [m
 ## emit miss signals if no valid target was found[m
 func _emit_miss() -> void:[m
[1mdiff --git a/Godot/scripts/entity components/brains/ai movement/ai_escort_brain.gd b/Godot/scripts/entity components/brains/ai movement/ai_escort_brain.gd[m
[1mindex 1f5c889..08ea846 100644[m
[1m--- a/Godot/scripts/entity components/brains/ai movement/ai_escort_brain.gd[m	
[1m+++ b/Godot/scripts/entity components/brains/ai movement/ai_escort_brain.gd[m	
[36m@@ -1,7 +1,6 @@[m
 ## AIEscortBrain[m
[31m-## Blackboard-target variant of AIFormationBrain.[m
[31m-## Calculates vector toward a target entity (read from blackboard) + offset.[m
[31m-## Emits "move" direction intent for Legs to consume.[m
[32m+[m[32m## Blackboard-target or group-target variant of AIFormationBrain.[m
[32m+[m[32m## Calculates vector toward a target entity (read from blackboard or nearest from group) + offset.[m
 [m
 class_name AIEscortBrain extends CDEntityComponent[m
 [m
[36m@@ -16,6 +15,9 @@[m [menum BlackboardSource {[m
 ## key to read the target CDEntity from[m
 @export var target_entity_key: StringName = &"captured_by"[m
 [m
[32m+[m[32m## target groups to find the nearest entity from (overrides blackboard target)[m
[32m+[m[32m@export var target_groups: Array[StringName] = [][m
[32m+[m
 ## spatial offset from the target entity (e.g., floating above the captor)[m
 @export var offset: Vector2 = Vector2.ZERO[m
 [m
[36m@@ -23,8 +25,11 @@[m [menum BlackboardSource {[m
 @export var stop_when_close: bool = true[m
 @export var close_distance: float = 5.0[m
 [m
[32m+[m[32m@export_group("Blackboard Keys")[m
[32m+[m[32m@export var move_direction_key: StringName = &"move_direction"[m
[32m+[m[32m@export var move_distance_key: StringName = &"move_distance"[m
[32m+[m
 @export_group("Emit Signals")[m
[31m-@export var move_signals: Array[StringName] = [&"move"][m
 @export var arrived_signals: Array[StringName] = [&"escort_achieved"][m
 [m
 var _target_entity: CDEntity[m
[36m@@ -41,27 +46,49 @@[m [mfunc _physics_process(_delta: float) -> void:[m
 		var target_pos = _target_entity.global_position + offset[m
 		var distance = entity.global_position.distance_to(target_pos)[m
 		[m
[31m-		if stop_when_close and distance <= close_distance:[m
[31m-			entity.request_velocity_set(Vector2.ZERO)[m
[31m-			for sig in arrived_signals:[m
[31m-				entity.bus_emit(sig)[m
[31m-			return[m
[32m+[m		[32mif stop_when_close and distance <= close_distance:[m[41m                [m
[32m+[m			[32mentity.blackboard.erase(move_direction_key)[m[41m                   [m
[32m+[m			[32mentity.blackboard.erase(move_distance_key)[m[41m                    [m
[32m+[m			[32mfor sig in arrived_signals:[m[41m                                   [m
[32m+[m				[32mentity.bus_emit(sig)[m[41m                                      [m
[32m+[m			[32mreturn[m[41m [m
 			[m
 		var direction = (target_pos - entity.global_position).normalized()[m
 		[m
[31m-		## write direction to blackboard and emit move signal[m
[31m-		entity.blackboard["move_direction"] = direction[m
[31m-		for sig in move_signals:[m
[31m-			entity.bus_emit(sig)[m
[32m+[m		[32m## write direction and distance to blackboard and emit move signal[m
[32m+[m		[32mentity.blackboard[move_direction_key] = direction[m
[32m+[m		[32mentity.blackboard[move_distance_key] = distance[m
[32m+[m	[32melse:[m
[32m+[m		[32mentity.blackboard[move_direction_key] = Vector2.ZERO[m
[32m+[m		[32mentity.blackboard[move_distance_key] = 0.0[m
 [m
[31m-## check blackboard for target entity reference[m
[32m+[m[32m## check blackboard or groups for target entity reference[m
 func _update_target() -> void:[m
[31m-	var bb: Dictionary[m
[31m-	if blackboard_source == BlackboardSource.ENTITY:[m
[31m-		bb = entity.blackboard[m
[32m+[m	[32mvar new_target: CDEntity = null[m
[32m+[m[41m	[m
[32m+[m	[32mif not target_groups.is_empty():[m[41m                                      [m
[32m+[m		[32mvar closest_dist = INF[m[41m                                            [m
[32m+[m		[32mfor group_name in target_groups:[m[41m                                  [m
[32m+[m			[32mvar entities = game.group_registry.get_group(group_name)[m[41m      [m
[32m+[m			[32mfor ent in entities:[m[41m                                          [m
[32m+[m				[32mif not is_instance_valid(ent):[m[41m                            [m
[32m+[m					[32mcontinue[m[41m                                              [m
[32m+[m				[32mvar dist = entity.global_position.distance_squared_to(ent.global_position)[m[41m           [m
[32m+[m				[32mif dist < closest_dist:[m[41m                                   [m
[32m+[m					[32mclosest_dist = dist[m[41m                                   [m
[32m+[m					[32mnew_target = ent[m[41m  [m
 	else:[m
[31m-		bb = game.blackboard[m
[32m+[m		[32mvar bb: Dictionary[m
[32m+[m		[32mif blackboard_source == BlackboardSource.ENTITY:[m
[32m+[m			[32mbb = entity.blackboard[m
[32m+[m		[32melse:[m
[32m+[m			[32mbb = game.blackboard[m
[32m+[m		[32mif target_entity_key != &"":[m[41m                                      [m
[32m+[m			[32mvar potential_target = bb.get(target_entity_key)[m[41m              [m
[32m+[m			[32mif is_instance_valid(potential_target):[m[41m                       [m
[32m+[m				[32mnew_target = potential_target[m[41m                             [m
[32m+[m			[32melse:[m[41m                                                         [m
[32m+[m				[32mbb.erase(target_entity_key)[m
 		[m
[31m-	var new_target = bb.get(target_entity_key)[m
 	if new_target != _target_entity:[m
 		_target_entity = new_target[m
[1mdiff --git a/Godot/scripts/entity components/brains/player/player_action_brain.gd b/Godot/scripts/entity components/brains/player/player_action_brain.gd[m
[1mindex 8a6ffdc..60e44ac 100644[m
[1m--- a/Godot/scripts/entity components/brains/player/player_action_brain.gd[m	
[1m+++ b/Godot/scripts/entity components/brains/player/player_action_brain.gd[m	
[36m@@ -14,7 +14,7 @@[m [mfunc _ready() -> void:[m
 [m
 ## on initialize[m
 func _on_initialize() -> void:[m
[31m-	wake()[m
[32m+[m	[32m_connect_input_signals()[m
 [m
 ## on action pressed[m
 func _on_action_pressed(pid: int, action: StringName) -> void:[m
[36m@@ -31,24 +31,28 @@[m [mfunc _on_action_released(pid: int, action: StringName) -> void:[m
 ## on sleep                                                               [m
 func _on_sleep() -> void:                                                 [m
 	super._on_sleep()                                                     [m
[31m-	if is_instance_valid(game) and game.input_router:                     [m
[31m-		if game.input_router.input_action_pressed.is_connected(_on_action_pressed):  [m
[31m-			game.input_router.input_action_pressed.disconnect(_on_action_pressed)                                                                   [m
[31m-		if game.input_router.input_action_released.is_connected(_on_action_released):[m
[31m-			game.input_router.input_action_released.disconnect(_on_action_released)                                                                 [m
[32m+[m	[32m_disconnect_input_signals()[m
 																		  [m
 ## on wake                                                                [m
 func _on_wake() -> void:                                                  [m
 	super._on_wake()                                                      [m
[31m-	if is_instance_valid(game) and game.input_router:                     [m
[31m-		if not game.input_router.input_action_pressed.is_connected(_on_action_pressed):  [m
[31m-			game.input_router.input_action_pressed.connect(_on_action_pressed)                                                                      [m
[31m-		if not game.input_router.input_action_released.is_connected(_on_action_released):[m
[31m-			game.input_router.input_action_released.connect(_on_action_released)   [m
[32m+[m	[32m_connect_input_signals()[m
 [m
 ## on entity deactivating[m
 func _on_entity_deactivating() -> void:[m
 	super._on_entity_deactivating()[m
[32m+[m	[32m_disconnect_input_signals()[m
[32m+[m
[32m+[m[32m## --- Helpers ---[m
[32m+[m
[32m+[m[32mfunc _connect_input_signals() -> void:[m
[32m+[m	[32mif is_instance_valid(game) and game.input_router:[m
[32m+[m		[32mif not game.input_router.input_action_pressed.is_connected(_on_action_pressed):[m
[32m+[m			[32mgame.input_router.input_action_pressed.connect(_on_action_pressed)[m
[32m+[m		[32mif not game.input_router.input_action_released.is_connected(_on_action_released):[m
[32m+[m			[32mgame.input_router.input_action_released.connect(_on_action_released)[m
[32m+[m
[32m+[m[32mfunc _disconnect_input_signals() -> void:[m
 	if is_instance_valid(game) and game.input_router:[m
 		if game.input_router.input_action_pressed.is_connected(_on_action_pressed):[m
 			game.input_router.input_action_pressed.disconnect(_on_action_pressed)[m
[1mdiff --git a/Godot/scripts/entity components/guts/game logic/announcer_guts.gd b/Godot/scripts/entity components/guts/game logic/announcer_guts.gd[m
[1mindex 7c03f42..91e070c 100644[m
[1m--- a/Godot/scripts/entity components/guts/game logic/announcer_guts.gd[m	
[1m+++ b/Godot/scripts/entity components/guts/game logic/announcer_guts.gd[m	
[36m@@ -34,7 +34,7 @@[m [mfunc _on_initialize() -> void:[m
 ## called when any listen_signal fires; rebroadcasts on game bus if qualified[m
 func _on_any_input() -> void:[m
 	for rebroadcast: StringName in rebroadcast_signals:[m
[31m-		game.bus_emit(rebroadcast)[m
[32m+[m		[32mgame.bus_emit_from(rebroadcast, entity)[m
 [m
 ## --- cleanup ---[m
 [m
[1mdiff --git a/Godot/scripts/entity components/legs/directional adders/direct_movement_leg.gd b/Godot/scripts/entity components/legs/directional adders/direct_movement_leg.gd[m
[1mindex 43a9146..9235bea 100644[m
[1m--- a/Godot/scripts/entity components/legs/directional adders/direct_movement_leg.gd[m	
[1m+++ b/Godot/scripts/entity components/legs/directional adders/direct_movement_leg.gd[m	
[36m@@ -1,6 +1,7 @@[m
 ## DirectMovementLeg[m
 ## Hard-sets velocity from direction polled on the entity blackboard[m
 ## Zeros velocity when no direction is found (no momentum drift)[m
[32m+[m[32m## Optionally caps movement distance per frame to prevent overshooting[m
 [m
 class_name DirectMovementLeg extends CDEntityComponent[m
 [m
[36m@@ -13,6 +14,10 @@[m [mclass_name DirectMovementLeg extends CDEntityComponent[m
 ## key to read movement direction from (Vector2)[m
 @export var direction_key: StringName = &"move_direction"[m
 [m
[32m+[m[32m## optional key to read remaining move distance from (float)[m
[32m+[m[32m## if present, caps velocity so frame movement doesn't exceed this distance[m
[32m+[m[32m@export var distance_key: StringName = &"move_distance"[m
[32m+[m
 ## --- lifecycle ---[m
 [m
 ## ready[m
[36m@@ -27,10 +32,23 @@[m [mfunc _on_initialize() -> void:[m
 ## --- processing ---[m
 [m
 ## set velocity to direction * speed, or zero if no direction on blackboard[m
[32m+[m[32m## optionally caps speed if we would overshoot the target distance this frame[m
 func _physics_process(_delta: float) -> void:[m
 	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)[m
[32m+[m[41m	[m
 	if direction != Vector2.ZERO:[m
[31m-		entity.request_velocity_set(direction.normalized() * speed)[m
[32m+[m		[32mvar target_velocity: Vector2 = direction.normalized() * speed[m
[32m+[m[41m		[m
[32m+[m		[32m# Check if we need to cap distance to prevent overshooting[m
[32m+[m		[32mif distance_key != &"" and entity.blackboard.has(distance_key):[m
[32m+[m			[32mvar max_distance: float = entity.blackboard[distance_key][m
[32m+[m			[32mvar frame_distance: float = speed * _delta[m
[32m+[m[41m			[m
[32m+[m			[32mif frame_distance > max_distance and frame_distance > 0.0:[m
[32m+[m				[32m# Scale velocity to travel exactly max_distance this frame[m
[32m+[m				[32mtarget_velocity = target_velocity * (max_distance / frame_distance)[m
[32m+[m[41m				[m
[32m+[m		[32mentity.request_velocity_set(target_velocity)[m
 	else:[m
 		entity.request_velocity_set(Vector2.ZERO)[m
 [m
[36m@@ -38,4 +56,4 @@[m [mfunc _physics_process(_delta: float) -> void:[m
 [m
 ## on entity deactivating[m
 func _on_entity_deactivating() -> void:[m
[31m-	super._on_entity_deactivating()[m
\ No newline at end of file[m
[32m+[m	[32msuper._on_entity_deactivating()[m
[1mdiff --git a/Godot/scripts/game components/managers/state_manager.gd b/Godot/scripts/game components/managers/state_manager.gd[m
[1mindex 7f02879..bdcddfb 100644[m
[1m--- a/Godot/scripts/game components/managers/state_manager.gd[m	
[1m+++ b/Godot/scripts/game components/managers/state_manager.gd[m	
[36m@@ -115,4 +115,4 @@[m [mfunc _is_in_all_groups(entity: CDEntity, groups: Array[StringName]) -> bool:[m
 func reset() -> void:[m
 	_transitioned.clear()[m
 	for t in transitions:[m
[31m-		t.reset()[m
\ No newline at end of file[m
[32m+[m		[32mt.reset()[m
