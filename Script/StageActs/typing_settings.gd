class_name StageTypingSettings
extends Resource
@export var typing_enabled := true
@export_range(1, 200, 1) var characters_per_second := 40.0
@export_range(0, 2, 0.01) var comma_pause := 0.10
@export_range(0, 3, 0.01) var punctuation_pause := 0.22
@export_range(0, 10, 0.05) var delay_before_typing := 0.0
@export_range(0, 10, 0.05) var delay_after_typing := 0.15
