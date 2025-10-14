
extends RefCounted
class_name AssetResource

var name: String
var id: String
var tags: Array[String]
var folder_path: String
var _scene: Resource = null


var shallow_collections: Array[AssetCollection]:
	get():
		var shallow: Array[AssetCollection] = []
		for name in tags:
			shallow.push_back(AssetCollection.new(name, Color.TRANSPARENT))
		return shallow

func _init(resId: String, name: String, tags: Array[String] = [], folder_path: String = ""):
	self.name = name
	self.id = resId
	self.tags = tags
	self.folder_path = folder_path


var scene: Resource:
	get(): 
		if _scene == null:
			_scene = load(id)
			return _scene
		else:
			return _scene



func belongs_to_collection(collection : AssetCollection) -> bool:
	return tags.any(func(tag: String): return tag == collection.name)
	
	
func belongs_to_some_collection(collections: Array[AssetCollection]) -> bool:
	return collections.any(func(collection: AssetCollection):
		return self.belongs_to_collection(collection)
	)	
