## LassoArm                                                               
## Spawns the lasso bullet payload when fired.                            
## Reads the firing entity and passes it to the bullet so the bullet knows who to report back to 

class_name LassoArm extends CDEntityComponent                             

@export var bullet_pool: CDObjectPool                                     
@export var bullet_scene: PackedScene  
  
## optional spawn context to apply to each projectile                     
@export var spawn_context: CDSpawnContext = null                          

## rotate projectile to match entity's facing direction                   
@export var inherit_rotation: bool = true                                
  
@export_group("Blackboard Keys")                                          
@export var captor_key: StringName = &"captor"                            

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
	 
## spawn bullet and initialize capture payload                            
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
		 
	# Write captor reference to bullet                                    
	bullet.blackboard[captor_key] = entity                              
	
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
