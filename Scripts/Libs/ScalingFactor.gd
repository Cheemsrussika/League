# res://Skills/ScalingFactor.gd
extends Resource
class_name ScalingFactor

enum ScaleSource { CASTER, TARGET }

@export var stat: Unit.Stat = Unit.Stat.AD
@export var scale_amount: float = 0.1 # 0.1 = 10%
@export var source: ScaleSource = ScaleSource.CASTER
