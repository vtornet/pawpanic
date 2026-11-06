class_name Poop
extends Node3D
## Caca. Hay que cogerla y llevarla al contenedor. Si te la pisas, resbalas.

var poop_id := 0
var carried_by := 0


static func create(data: Dictionary) -> Poop:
	var p := Poop.new()
	p.poop_id = data["id"]
	p.name = "Poop_%d" % p.poop_id
	p.position = data["pos"]
	var c := Color(0.32, 0.2, 0.1)
	p.add_child(Shapes.cylinder(0.22, 0.1, c, Vector3(0, 0.05, 0)))
	p.add_child(Shapes.cylinder(0.15, 0.09, c.lightened(0.05), Vector3(0, 0.14, 0)))
	p.add_child(Shapes.cylinder(0.08, 0.08, c.lightened(0.1), Vector3(0, 0.22, 0)))

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	cfg.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	cfg.add_property(NodePath(".:carried_by"))
	cfg.property_set_replication_mode(NodePath(".:carried_by"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = cfg
	p.add_child(sync)
	return p


func on_floor() -> bool:
	return carried_by == 0
