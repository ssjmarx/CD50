## LassoArm                                                               
## Spawns the lasso bullet payload and optional effect when fired.                            
## Reads the firing entity and passes it to the bullet so the bullet knows who to report back to.
## Writes generic captor/target keys to the blackboard for visual effects to read.

class_name LassoArm extends CDEntityComponent                             

@export var bullet_pool: CDObjectPool                                     
@export var bullet_scene: PackedScene  
## Optional effect (e.g. LassoEffect, muzzle flash) spawned at fire position
@export var effect_scene: PackedScene
  
## optional spawn context to apply to each projectile                     
@export var spawn_context: CDSpawnContext = null                          

## rotate projectile to match entity's facing direction                   
@export var inherit_rotation: bool = true                                
  
@export_group("Blackboard Keys")                                          
@export var captor_key: StringName = &"lasso_captor"                            
@export var target_key: StringName = &"lasso_target"
@export var bullet_captor_key: StringName = &"captor"

@export_group("Listen Signals")                                           
@export var fire_signals: Array[StringName] = [&"fire_tractor_beam"]      
 
## ready                                                                  
func _ready() -> void:                                                    
	component_category = CDEnums.ComponentCategory.INTERACTION            
	super._ready()                                                        
	
## connect fire signals                                                   
func _on_initialize() -> void:                                            
	for sig in fire_signals:                                              
		self.bus_connect(sig, _on_fire)                                   
		  
## catch signal and defer to avoid physics state errors                   
func _on_fire() -> void:                                                  
	call_deferred("_deferred_fire")                                       
	 
## spawn bullet, write blackboard, and spawn effect
func _deferred_fire() -> void:                                            
	var bullet: CDEntity = null                                        
	  
	## acquire from pool or instantiate fresh                             
	if bullet_pool:                                                       
		bullet = bullet_pool.acquire()                                    
		if bullet == null:                                                
			return                                                        
		bullet.global_position = global_position                          
	elif bullet_scene:                                                    
		bullet = bullet_scene.instantiate()                               
		bullet.global_position = global_position                          
	else:                                                                 
		return                                                            
		 
	CDUtilities.apply_spawn_context(bullet, spawn_context)              
  
	if inherit_rotation:                                                  
		bullet.rotation = global_rotation                                 
		bullet.velocity = bullet.velocity.rotated(global_rotation)        
		 
	# Write captor reference to bullet (for capture logic)                                    
	bullet.blackboard[bullet_captor_key] = entity                              
	
	# Write generic captor/target keys to entity blackboard for effects to read
	entity.blackboard[captor_key] = entity
	entity.blackboard[target_key] = bullet
	
	# Spawn effect if assigned
	if effect_scene:
		var effect = effect_scene.instantiate()
		# Add as a child of the entity so it can read the blackboard instantly
		entity.add_child(effect)
		# Set local position to zero so it doesn't double-offset from the arm
		effect.position = Vector2.ZERO
		  
	## activate pooled entity or add to scene tree                        
	if bullet_pool:                                                       
		bullet.activate()                                                 
	else:                                                                 
		game.add_child(bullet)                                           
		  
## disconnect fire signals on deactivation                                
func _on_entity_deactivating() -> void:                                   
	super._on_entity_deactivating()                                       
	for sig in fire_signals:                                              
		if entity.is_connected(sig, _on_fire):                            
			entity.disconnect(sig, _on_fire)
