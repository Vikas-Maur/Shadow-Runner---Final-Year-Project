class_name ProcGenRequest
extends RefCounted

var seed: int = 1
var width: int = 96
var height: int = 32
var algorithm: StringName = &"rule_based"
var logical_layers: Array[StringName] = [&"ground", &"stealth"]
var params: Dictionary = {}
var agent_overrides: Array[Dictionary] = []

static func from_dict(data: Dictionary) -> ProcGenRequest:
	var request := ProcGenRequest.new()
	request.seed = int(data.get("seed", request.seed))
	request.width = int(data.get("width", request.width))
	request.height = int(data.get("height", request.height))
	request.algorithm = StringName(data.get("algorithm", request.algorithm))
	var params_value: Variant = data.get("params", {})
	if params_value is Dictionary:
		request.params = (params_value as Dictionary).duplicate(true)
	else:
		request.params = {}

	var layers_value: Variant = data.get("logical_layers", request.logical_layers)
	if layers_value is Array:
		request.logical_layers.clear()
		for layer_name in layers_value:
			request.logical_layers.append(StringName(layer_name))

	var overrides_value: Variant = data.get("agent_overrides", [])
	if overrides_value is Array:
		for override in overrides_value:
			if override is Dictionary:
				var override_data: Dictionary = (override as Dictionary).duplicate(true)
				request.agent_overrides.append(override_data)

	return request

func to_dictionary() -> Dictionary:
	var layers: Array[String] = []
	for layer_name in logical_layers:
		layers.append(String(layer_name))
	return {
		"seed": seed,
		"width": width,
		"height": height,
		"algorithm": String(algorithm),
		"logical_layers": layers,
		"params": params.duplicate(true),
		"agent_overrides": agent_overrides.duplicate(true)
	}
