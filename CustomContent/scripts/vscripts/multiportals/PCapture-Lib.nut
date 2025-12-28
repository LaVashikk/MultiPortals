/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                               |
 +---------------------------------------------------------------------------------+
| Author:                                                                           |
|     One-of-a-Kind - laVashik                                                      |
 +---------------------------------------------------------------------------------+
| pcapture-lib.nut                                                                  |
|       The main file in the library. initializes required parts of the library     |
|    GitHud repo: https://github.com/LaVashikk/PCapture-LIB                          |
+----------------------------------------------------------------------------------+ */

local version = "PCapture-Lib 4.0 Release Candidate"
local rootScope = getroottable()

// `Self` must be in any case, even if the script is run directly by the interpreter
if (!("self" in this)) {
    self <- Entities.First()
} else {
    getroottable()["self"] <- self
}

if("LIB_VERSION" in getroottable() && version.find("Debug") == null) {
    printl("\n")
    dev.warning("PCapture-Lib already initialized.")
    if(LIB_VERSION != version) {
        printl("\n======================== WARNING ========================")
        printl("Attempting to initialize different versions of the PCapture-Lib library!")
        macros.fprint("Inited version \"{}\" != \"{}\"", LIB_VERSION, version)
        printl("==========================================================\n")
    }
    return
}

/*
 * Global Tables Initialization:
 *
 * This section initializes the fundamental global tables required for the PCapture Library.
 * These tables are essential for ensuring the correct functioning 
 * of the library's various components during runtime.
*/
::pcapEntityCache <- {}
::EntitiesScopes <- {}
::TracePlusIgnoreEnts <- {}

/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Data Structure Maestro - laVashik ^v^                                        |
+----------------------------------------------------------------------------------+
|   The Improved Data Types module, offering enhanced versions of standard VScripts|
|   data structures like arrays, lists, and trees for efficient data management.   |
+----------------------------------------------------------------------------------+ */

::pcapEntity <- class {
    CBaseEntity = null;

    /* 
     * Constructor for the entity object.
     *
     * @param {CBaseEntity} entity - The entity object.
    */
    constructor(entity) { 
        if (!entity || !entity.IsValid()) throw("pcapEntity: invalid entity");
        if(typeof entity == "pcapEntity")
            entity = entity.CBaseEntity

        this.CBaseEntity = entity
        EntitiesScopes[this.CBaseEntity] <- {}
        entity.ValidateScriptScope()
        entity.GetScriptScope().selfEx <- this // todo: no docs about it
    }

    /*
     * Sets the angles of the entity.
     *
     * @param {Vector} angles - The angle vector.
    */
    function SetAngles2(angles) {
        this.CBaseEntity.SetAngles(angles.x, angles.y, angles.z)
    }


    // Destroys the entity. 
    function Destroy(fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.Destroy, fireDelay, null, this)
        
        if(!this.CBaseEntity || !this.CBaseEntity.IsValid()) return
        this.CBaseEntity.Destroy()
        this.CBaseEntity = null
    }


    /*
     * Kills the entity.
     *
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function Kill(fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.Kill, fireDelay, null, this)

        if(!this.CBaseEntity || !this.CBaseEntity.IsValid()) return
        EntFireByHandle(this.CBaseEntity, "kill")
        this.CBaseEntity = null
    }


    /*
     * Dissolves the entity using an env_entity_dissolver entity, creating a visual effect of the entity dissolving away.
     *
     * This method utilizes an env_entity_dissolver entity to create the dissolve effect. If the entity doesn't have a targetname, 
     * a unique targetname is assigned to it before initiating the dissolve process. 
    */
    function Dissolve(fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.Dissolve, fireDelay, null, this)

        if(!dissolver || !dissolver.IsValid()) throw("The entity 'dissolver' is missing, the Dissolve method will not work.")
        if(this.GetName() == "")
            this.SetUniqueName("targetname")
        for(local entity; entity = Entities.FindByName(entity, this.GetName()); ) if(!macros.IsEqual(this, entity)) {
            this.SetUniqueName()
            break
        }

        dissolver.SetKeyValue("target", this.GetName())
        EntFireByHandle(dissolver, "dissolve")

        this.SetUserData("Dissolved", true)
    }


    /*
     * Checks if the entity is valid.
     *
     * @returns {bool} - True if the entity is valid, false otherwise.
    */
    function IsValid() {
        return this.CBaseEntity && this.CBaseEntity.IsValid() && !this.GetUserData("Dissolved")
    }


    /*
     * Checks if this entity is the player entity.
     * 
     * @returns {bool} - True if this entity is the player, false otherwise.
    */
    function IsPlayer() {
        return this.CBaseEntity.GetClassname() == "player"
    }

    /*
     * Gets the eye position of the player entity.
     *
     * @returns {Vector|null} - The eye position as a Vector, or null if the entity is not a player.
     * 
     * This method retrieves the position from which the player's view is rendered. It is important to note that this method only works with player entities.
     * For non-player entities, it returns GetCenter. 
    */
     function EyePosition() {
        if(this.IsPlayer()) return this.CBaseEntity.EyePosition()
        return this.GetCenter()
    }

    /*
     * Gets the eye angles of the player entity. 
     *
     * @returns {Vector|null} - The eye angles as a Vector representing pitch, yaw, and roll, or null if the entity is not a player.
     *
     * This method retrieves the orientation of the player's view. It is important to note that this method only works with player entities.
     * For non-player entities, it returns GetAngles. 
    */
    function EyeAngles() {
        if(this.IsPlayer()) return this.GetUserData("Eye").GetAngles()
        return this.GetAngles()
    }

    /* 
     * Gets the forward vector from the player entity's eye position, indicating the direction the player is looking. 
     *
     * @returns {Vector|null} - The forward vector as a Vector, or null if the entity is not a player.
     *
     * This method retrieves the direction in which the player is facing. It is important to note that this method only works with player entities.
     * For non-player entities, it returns GetForwardVector.
    */
    function EyeForwardVector() {
        if(this.IsPlayer()) return this.GetUserData("Eye").GetForwardVector()
        return this.GetForwardVector()
    }

    /*
     * Sets the key-value pair of the entity.  
     *
     * @param {string} key - The key of the key-value pair.
     * @param {int|float|Vector|string} value - The value of the key-value pair.
    */
    function SetKeyValue(key, value, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetKeyValue, fireDelay, [key, value], this)

        this.SetUserData(key, value)

        switch (typeof value) {
            case "integer":
                return this.CBaseEntity.__KeyValueFromInt(key, value);
            case "float":
                return this.CBaseEntity.__KeyValueFromFloat(key, value);
            case "Vector":
                return this.CBaseEntity.__KeyValueFromVector(key, value);
            case "string":
                return this.CBaseEntity.__KeyValueFromString(key, value);
        }
        
        return this.CBaseEntity.__KeyValueFromString(key, value.tostring());
    }


    /*
     * Connects an output of the entity to a target entity and input, allowing for parameter overrides, delays, and limited trigger counts.
     *
     * @param {string} outputName - The name of the output to connect.
     * @param {string|CBaseEntity|pcapEntity} target - The target entity or its targetname to connect the output to.
     * @param {string} input - The name of the input on the target entity to connect to.
     * @param {string} param - An optional parameter override for the input. (default: "")
     * @param {number} delay - An optional delay in seconds before triggering the input. (default: 0) 
     * @param {number} fires - The number of times the output should fire before becoming inactive. -1 indicates unlimited fires. (default: -1) 
     * 
     * This method provides a way to establish connections between entities, allowing them to trigger actions on each other based on outputs and inputs. 
    */
     function AddOutput(outputName, target, input, param = "", delay = 0, fires = -1) {
        if(typeof target == "instance" || typeof target == "pcapEntity")
            target = target.GetName()
        this.SetKeyValue(outputName, target + "\x001B" + input + "\x001B" + param + "\x001B" + delay + "\x001B" + fires)
    }

    /* 
     * Connects an output of the entity to a script function or string, allowing for delays and limited trigger counts. 
     * 
     * @param {string} outputName - The name of the output to connect.
     * @param {string|function} script - The VScripts code or function name to execute when the output is triggered.
     * @param {number} delay - An optional delay in seconds before executing the script. (default: 0) 
     * @param {number} fires - The number of times the output should fire before becoming inactive. -1 indicates unlimited fires. (default: -1) 
     * 
     * This method provides a way to connect entity outputs directly to script code, allowing for custom actions to be performed when the output is triggered.
    */
    function ConnectOutputEx(outputName, script, delay = 0, fires = -1) {
        if(typeof script == "function") {
            local funcName = script.getinfos().name
            local src = script.getinfos().src
            if(!funcName || src == "unnamedbuffer") { // If scripts is an anonymous function, assign it a unique name and add it to the root scope
                funcName = UniqueString("OutputFunc")
                getroottable()[funcName] <- script
            }
            script = funcName + "()"
        } else {
            return this.ConnectOutput(outputName, script)
        }

        this.AddOutput(outputName, "!self", "RunScriptCode", script, delay, fires)
    }

    /*
     * Connects a script function to an input of the entity, allowing external code to react to input events.
     * 
     * @param {string} inputName - The name of the input to connect to.
     * @param {function} closure - The function to execute when the input is triggered. 
     * 
     * This function enables the association of custom logic with specific entity inputs, facilitating communication and interaction between entities and external scripts.
    */
    function SetInputHook(inputName, closure) {
        if(this.ValidateScriptScope() == false) return
        this.GetScriptScope()["Input" + inputName] <- closure
        // This is a quick hack to address a bug where the game sometimes calls `Inputname` instead of `InputName` (Valve, why?)
        this.GetScriptScope()["Input" + inputName.tolower()] <- closure
    }

    /*
     * Plays a sound on the entity.
     *
     * @param {string} soundName - The name of the sound to play.
     * @param {number} fireDelay - An optional delay in seconds before playing the sound. (default: 0)
     * @param {string} eventName - The name of the event to schedule the sound playback under. (default: "global")
     *
     * This function is an enhanced version of the built-in EmitSound method, allowing for delayed sound playback 
     * and cancellation using ScheduleEvent.Cancel.
    */
    function EmitSound(soundName, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.EmitSound, fireDelay, [soundName], this)

        this.CBaseEntity.EmitSound(soundName)
    }

    /*
     * Plays a sound on the entity with advanced options, including volume control and looping.
     *
     * @param {string} soundName - The name of the sound to play.
     * @param {number} volume - The volume of the sound (0-10). (default: 10)
     * @param {boolean} looped - Whether the sound should loop. (default: false)
     * @param {number} fireDelay - An optional delay in seconds before playing the sound. (default: 0)
     * @param {string} eventName - The name of the event to schedule the sound playback under. (default: "global")
     *
     * This function provides more control over sound playback compared to EmitSound. It allows you to adjust the volume,
     * loop sounds that are not inherently loopable, and stop the sound playback using StopSoundEx.
    */
    function EmitSoundEx(soundName, volume = 10, looped = false, fireDelay = 0, eventName = "global") { // add volume and loop flag
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.EmitSoundEx, fireDelay, [soundName], this)
        
        // for updating volume if sound active
        local soundEnt = this.GetUserData(soundName)
        if(soundEnt && soundEnt.IsValid()) 
            return soundEnt.SetAbsOrigin(this.GetOrigin() + Vector(0, 0, 3000 - volume * 300))
        
        // SO FKING CURSED WORKAROUND EVER!
        local soundEnt = entLib.CreateProp("prop_physics", Vector(), ALWAYS_PRECACHED_MODEL)
        soundEnt.SetAbsOrigin(this.GetOrigin() + Vector(0, 0, 3000 - volume * 300))
        soundEnt.SetParent(this)
        soundEnt.SetKeyValue("rendermode", 5)
        soundEnt.SetAlpha(0)

        local soundTime = macros.GetSoundDuration(soundName)
        this.SetUserData(soundName, soundEnt)
        soundEnt.EmitSound(soundName)
        
        if(!looped) return soundEnt.Destroy(soundTime)
        ScheduleEvent.AddInterval(soundEnt, soundEnt.EmitSound, soundTime, soundTime, [soundName], soundEnt) // :>
    }

    /*
     * Stops a sound played using EmitSoundEx.
     *
     * @param {string} soundName - The name of the sound to stop.
     * @param {number} fireDelay - An optional delay in seconds before stopping the sound. (default: 0)
     * @param {string} eventName - The name of the event to schedule the sound stop under. (default: "global")
     *
     * This function allows you to interrupt sounds that were started using EmitSoundEx. It ensures the sound is stopped
     * and the associated entity is cleaned up.
    */
    function StopSoundEx(soundName, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0) {
            return ScheduleEvent.Add(eventName, this.StopSoundEx, fireDelay, [soundName], this)
        }

        local soundEnt = this.GetUserData(soundName)
        if(!soundEnt || !soundEnt.IsValid()) return

        ScheduleEvent.TryCancel(soundEnt)
        soundEnt.SetOrigin(Vector(0, 0, 10000))
        soundEnt.Destroy(0.04)
    }


    /*
     * Sets the targetname of the entity.
     *
     * @param {string} name - The targetname to be set.
    */
    function SetName(name, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetName, fireDelay, [name], this)
        
        this.SetKeyValue("targetname", name)
    }

    /*
     * Sets a unique targetname for the entity using the provided prefix.
     *
     * @param {string} prefix - The prefix to be used for the unique targetname. (optional, default="u")
    */
    function SetUniqueName(prefix = "pcapEnt", fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetUniqueName, fireDelay, [prefix], this)
        
        this.SetKeyValue("targetname", UniqueString(prefix))
    }


    /*
     * Sets the parent of the entity.
     *
     * @param {string|CBaseEntity|pcapEntity} parent - The parent entity object or its targetname.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetParent(parentEnt, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetParent, fireDelay, [parentEnt], this)
        
        if(typeof parentEnt != "string") {
            local Pent = entLib.FromEntity(parentEnt)
            local hasUniqueName = true
            if(Pent.GetName() == "") 
                Pent.SetUniqueName("parent")
            for(local entity; entity = Entities.FindByName(entity, Pent.GetName()); ) if(!macros.IsEqual(Pent, entity)) {
                Pent.SetUniqueName("parent")
                break
            }
            parentEnt = Pent.GetName()
        }
        
        EntFireByHandle(this.CBaseEntity, "SetParent", parentEnt)            
    }

    /*
     * Gets a list of all DIRECT children of this entity.
     * This function is not recursive and will not find grandchildren.
     *
     * @returns {List} A List containing all direct child pcaptEntity objects.
    */
    function GetChildren() {
        local childrenList = List()

        local child = this.CBaseEntity.FirstMoveChild(); 
        while(child) {
            childrenList.append(entLib.FromEntity(child));
            child = child.NextMovePeer();
        }

        return childrenList;
    }

    /*
     * Recursively finds all descendants (children, grandchildren, etc.) of this entity.
     * Performs a depth-first search of the entity hierarchy.
     *
     * @returns {List} A List containing all descendant pcaptEntity objects.
    */    
    function GetAllChildrenRecursively() {
        local descendantsList = List();
        _findDescendantsRecursive(this.CBaseEntity, descendantsList);

        return descendantsList;
    }


    /*
     * Sets the collision of the entity.
     *
     * @param {number} solidType - The type of collision.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetCollision(solidType, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetCollision, fireDelay, [solidType], this)
        
        EntFireByHandle(this.CBaseEntity, "SetSolidtype", solidType.tostring()) 
        this.SetUserData("Solidtype", solidType)
    }


    /*
     * Sets the collision group of the entity.
     *
     * @param {number} collisionGroup - The collision group.
    */
    function SetCollisionGroup(collisionGroup, fireDelay = 0, eventName = "global") {
        this.SetKeyValue("CollisionGroup", collisionGroup, fireDelay, eventName)
    }
    

    /* 
     * Starts playing the specified animation.
     *
     * @param {string} animationName - The name of the animation to play.
     * @param {number} fireDelay - Delay in seconds before starting the animation.
    */
    function SetAnimation(animationName, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetAnimation, fireDelay, [animationName], this)
        
        EntFireByHandle(this.CBaseEntity, "SetAnimation", animationName)
        this.SetUserData("animation", animationName)
    }


    /*
     * Sets the alpha (opacity) of the entity.
     *
     * @param {number} opacity - The alpha value (0-255).
     * @param {number} fireDelay - Delay in seconds before applying.
     * Note: Don't forget to set "rendermode" to 5 for alpha to work.
    */
    function SetAlpha(opacity, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetAlpha, fireDelay, [opacity], this)
        
        EntFireByHandle(this.CBaseEntity, "Alpha", opacity.tostring())
        this.SetUserData("alpha", opacity)
    }


    /*
     * Sets the color of the entity.
     *
     * @param {string|Vector} colorValue - The color value as a string (e.g., "255 0 0") or a Vector.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetColor(colorValue, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetColor, fireDelay, [colorValue], this)
        
        if(typeof colorValue == "Vector") 
            colorValue = macros.VecToStr(colorValue)

        EntFireByHandle(this.CBaseEntity, "Color", colorValue)
        this.SetUserData("color", colorValue)
    }


    /*
     * Sets the skin of the entity.
     *
     * @param {number} skin - The skin number.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetSkin(skin, fireDelay = 0, eventName = "global") { 
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetSkin, fireDelay, [skin], this)
        
        EntFireByHandle(this.CBaseEntity, "skin", skin.tostring())
        this.SetUserData("skin", skin)
    }


    /*
     * Sets whether the entity should be drawn or not. 
     *
     * @param {boolean} isEnabled - True to enable drawing, false to disable.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetDrawEnabled(isEnabled, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetDrawEnabled, fireDelay, [isEnabled], this)
        
        local action = isEnabled ? "EnableDraw" : "DisableDraw"
        EntFireByHandle(this.CBaseEntity, action)
        this.SetUserData("IsDraw", isEnabled)
    }

    function Disable(fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.Disable, fireDelay, null, this)
        
        EntFireByHandle(this.CBaseEntity, "Disable")
        this.SetTraceIgnore(true)
    }

    function Enable(fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.Enable, fireDelay, null, this)
        
        EntFireByHandle(this.CBaseEntity, "Enable")
        this.SetTraceIgnore(false)
    }

    /*
     * Checks if the entity is set to be drawn.
     * 
     * @returns {boolean} - True if the entity is set to be drawn, false otherwise.
    */
    function IsDrawEnabled() {
        return this.GetUserData("IsDraw")
    }

    /*
     * Sets whether the entity should be ignored during traces.
     * 
     * @param {boolean} isEnabled - True to ignore the entity during traces, false otherwise.
    */
    function SetTraceIgnore(isEnabled, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetTraceIgnore, fireDelay, [isEnabled], this)
        
        this.SetUserData("TracePlusIgnore", isEnabled)
        TracePlusIgnoreEnts[this.CBaseEntity] <- isEnabled
    }

    function IsTraceIgnored() {
        return this.GetUserData("TracePlusIgnore")
    }

    /*
     * Sets the spawnflags for the entity.
     *
     * @param {number} flag - The spawnflags value to set.
    */
    function SetSpawnflags(flag, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetSpawnflags, fireDelay, [flag], this)
        
        this.SetKeyValue("SpawnFlags", flag)
    }


    /*
     * Sets the scale of the entity's model.
     *
     * @param {number} scaleValue - The scale value.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetModelScale(scaleValue, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetModelScale, fireDelay, [scaleValue], this)
        
        EntFireByHandle(this.CBaseEntity, "AddOutput", "ModelScale " + scaleValue)
        this.SetUserData("ModelScale", scaleValue)
        // hack for entity update
        EntFireByHandle(this.CBaseEntity, "SetBodyGroup", "1"); EntFireByHandle(this.CBaseEntity, "SetBodyGroup", "0", 0.02)
    }

    /*
     * Gets the current model scale of the entity.
     *
     * @returns {number} - The current model scale value.
    */
    function GetModelScale() {
        local res = this.GetUserData("ModelScale")
        return res ? res : 1
    }


    /*
    * Sets the absolute center of the entity in world space.
    * This will override any parent-relative positioning.
    *
    * @param {Vector} vector - The desired absolute center vector in world coordinates.
    */
    function SetAbsCenter(vector) {
        local offset = this.CBaseEntity.GetCenter() - this.CBaseEntity.GetOrigin()
        this.CBaseEntity.SetAbsOrigin( vector - offset )
    }

    /*
     * Sets the center of the entity.
     *
     * @param {Vector} vector - The center vector.
    */
    function SetCenter(vector) {
        local offset = this.CBaseEntity.GetCenter() - this.CBaseEntity.GetOrigin()
        this.CBaseEntity.SetOrigin( vector - offset )
    }

    /*
     * Sets a context value for the entity.
     *
     * @param {string} name - The name of the context value.
     * @param {any} value - The value to set.
     * @param {number} fireDelay - Delay in seconds before applying.
    */
    function SetContext(name, value, fireDelay = 0, eventName = "global") {
        if(fireDelay != 0)
            return ScheduleEvent.Add(eventName, this.SetContext, fireDelay, [name, value], this)
        
        EntFireByHandle(this.CBaseEntity, "AddContext", (name + ":" + value))
        this.SetUserData(name, value)
    }
    
    /* 
     * Stores an arbitrary value associated with the entity.
     *
     * @param {string} name - The name of the value.  
     * @param {any} value - The value to store.
    */
    function SetUserData(name, value) {
        EntitiesScopes[this.CBaseEntity][name.tolower()] <- value
    }

    /*
     * Gets a stored user data value.
     *
     * @param {string} name - The name of the value to get.
     * @returns {any} - The stored value, or null if not found.
    */ 
    function GetUserData(name) {
        name = name.tolower()
        if(name in EntitiesScopes[this.CBaseEntity])
            return EntitiesScopes[this.CBaseEntity][name]
        return null
    }

    /*
     * Calculates the local coordinates (position and angles) of this entity relative to its move parent.
     * If the entity has no parent, its world coordinates are returned.
     *
     * @returns {table} A table containing the local coordinates: { pos = <Vector>, ang = <Vector> }.
    */    
    function GetLocalCoords() {
        local pParent = this.CBaseEntity.GetMoveParent();
        if (!pParent) {
            // If there's no parent, local coordinates are equal to world coordinates.
            return { pos = this.GetOrigin(), ang = this.GetAngles() };
        }

        // Get the world positions and angles of both entities
        local childWorldPos = this.GetOrigin();
        local parentWorldPos = pParent.GetOrigin();

        local childWorldAng = this.GetAngles();
        local parentWorldAng = pParent.GetAngles();

        // Calculate the offset vector in world coordinates
        local worldOffset = childWorldPos - parentWorldPos;

        // "Unrotate" the world offset vector by the parent's angles to get the local position
        local localPos = math.vector.unrotate(worldOffset, parentWorldAng);
        local localAng = childWorldAng - parentWorldAng;

        return { pos = localPos, ang = localAng };
    }

    /*
     * A function that sets the entity's absolute origin in world space using teleportation.
     * This function bypasses interpolation, making the position change instantaneous.
     *
     * @param {Vector} desiredAbsVec - The desired absolute position in world coordinates.
    */
    function SetAbsOrigin(desiredAbsVec) {
        local pParent = this.CBaseEntity.GetMoveParent()

        // If there is no parent, local coordinates are equivalent to absolute coordinates.
        if (!pParent) {
            return this.CBaseEntity.SetOrigin(desiredAbsVec)
        }

        // We have parent, so we need to convert the desired ABSOLUTE coordinates into LOCAL coordinates.
        local parentWorldPos = pParent.GetOrigin()
        local parentWorldAng = pParent.GetAngles()

        // Calculate the offset vector from the parent to the desired point in world coordinates.
        local worldOffsetVector = desiredAbsVec - parentWorldPos

        // Transform the world offset vector into a local one.
        local localPos = math.vector.unrotate(worldOffsetVector, parentWorldAng)

        this.SetOrigin(localPos)
    }

    /*
     * Sets the entity's absolute origin using the native engine method.
     * Unlike the custom SetAbsOrigin, this method handles attachment parents correctly.
     * However, it causes client-side interpolation (visual sliding) when moving the entity.
     *
     * @param {Vector} desiredAbsVec - The desired absolute position in world coordinates.
    */
    function SetAbsOriginNative(desiredAbsVec) {
        this.CBaseEntity.SetAbsOrigin(desiredAbsVec)
    }

    /*
     * Checks if the bounding box of an entity is a cube (all sides have equal length).
     *
     * @returns {boolean} - True if the bounding box is a cube, false otherwise.
    */
    function IsSquareBbox() {
        // Get the minimum and maximum coordinates of the bounding box
        local mins = this.GetBoundingMins();
        local maxs = this.GetBoundingMaxs();
        
        // Calculate the size of the bounding box along each axis
        local sizeX = abs(maxs.x - mins.x)
        local sizeY = abs(maxs.y - mins.y)
        local sizeZ = abs(maxs.z - mins.z)

        // Check if the sizes are equal along all axes
        return sizeX == sizeY && sizeY == sizeZ;
    }

    //! TODO ADD TO DOCS
    function GetBoundingCenter() {
        return (this.CBaseEntity.GetBoundingMaxs() - this.CBaseEntity.GetBoundingMins()) * 0.5
    }

    /* 
     * Returns the axis-aligned bounding box (AABB) of the entity.
     *
     * @returns {table} - The minimum bounds, maximum bounds, and center of the entity.
    */ 
    function GetAABB() {
        return {
            min = this.CreateAABB(0),
            center = this.CreateAABB(4),
            max = this.CreateAABB(7)
        }
    }

    /* 
     * Gets the index of the entity.
     *
     * @returns {int} - The index of the entity.
    */
    function GetIndex() {
        return this.CBaseEntity.entindex()
    }


    /*
     * Gets the value of the key-value pair of the entity.
     * Note: only works if you used the SetKeyValue function!
     *
     * @param {string} key - The key of the key-value pair.
     * @returns {any} - The value of the key-value pair.
    */
    function GetKeyValue(key) {
        local value = this.GetUserData(key)
        if(value != null)
            return value

        switch(key) {
            case "model":
                return this.GetModelName()
                break
            case "health":
                return this.GetHealth()
                break
            case "targetname":
                return this.GetName()
                break
        }

        return null
    }


    /*
     * Gets the spawnflags for the entity.
     * Note: only works if you used the SetKeyValue function!
     *
     * @returns {int|null} - The spawnflags value.
    */ 
    function GetSpawnflags() {
        return this.GetUserData("spawnflags")
    }


    /*
     * Gets the alpha/opacity value of the entity.
     * Note: only works if you used the SetKeyValue function!
     * 
     * @returns {int|null} - The alpha value.
    */
    function GetAlpha() {
        local alpha = this.GetUserData("alpha")
        return alpha != null ? alpha : 255
    }


    /*
     * Gets the color value of the entity.
     * Note: only works if you used the SetKeyValue function!
     *
     * @returns {string|null} - The color value.
    */
    function GetColor() {
        local color = this.GetUserData("color")
        return color ? color : "255 255 255"
    }


    /*
     * Gets the skin of the entity.
     * Note: only works if you used the SetKeyValue function!
     *
     * @returns {number|null} - The skin number.
    */
    function GetSkin() {
        local skin = this.GetUserData("skin")
        return skin ? skin : 0
    }


    /*
     * Gets the prefix of the entity name.
     *
     * @returns {string} - The prefix of the entity name.
    */
    function GetNamePrefix() {
        return macros.GetPrefix(this.GetName())
    }


    /*
     * Gets the postfix of the entity name.
     *
     * @returns {string} - The postfix of the entity name.
    */
    function GetNamePostfix() {
        return macros.GetPostfix(this.GetName())
    }

    /*
     * Retrieves the partner instance of the entity, prioritizing the actual partner entity if available, and falling back to user-stored partner data if necessary.
     *
     * @returns {Entity|null} - The partner entity, or null if no partner is found.
     * 
     * This method first attempts to retrieve the actual partner entity using the `GetPartnerInstance` method of the underlying CBaseEntity.
     * If no partner entity is found, it then checks for a partner stored in the entity's user data under the key "partner". This can be useful in situations where the partner relationship is not directly established through entity properties but is managed through custom logic. 
    */
    function GetPartnerInstance() {
        if(this.CBaseEntity instanceof CLinkedPortalDoor)
            return entLib.FromEntity(this.CBaseEntity.GetPartnerInstance())
        return FindPartnerForPropPortal(this)
    }


    /*
     * Gets the oriented bounding box of the entity.
     *
     * @param {number} stat - 0 for min bounds, 7 for max bounds, 4 for center bounds. 
     * @returns {Vector} - The bounds vector.
    */
    function CreateAABB(stat) { 
        local angles = this.GetAngles()
        if(stat == 4) 
            angles = Vector(45, 45, 45)

        local all_vertex = this.GetBBoxPoints()
        local x = array(8)
        local y = array(8)
        local z = array(8)

        foreach(idx, vec in all_vertex) {
            x[idx] = vec.x
            y[idx] = vec.y
            z[idx] = vec.z
        }

        x.sort(); y.sort(); z.sort()
 
        local result
        if(stat == 4) { // centered
            result = ( Vector(x[7], y[7], z[7]) - Vector(x[0], y[0], z[0]) ) * 0.5
        } 
        else {
            result = Vector(x[stat], y[stat], z[stat])
        }
        
        return result
    }

    /*
     * Gets the 8 vertices of the axis-aligned bounding box.
     *
     * @returns {Array<Vector>} - The 8 vertices of the bounding box.  
    */
    function GetBBoxPoints() {
        local max = this.GetBoundingMaxs();
        local min = this.GetBoundingMins();
        local angles = this.GetAngles()
    
        local getVertex = macros.GetVertex
        return [
            getVertex(max, min, min, angles), // 0 - Right-Bottom-Front
            getVertex(max, max, min, angles), // 1 - Right-Top-Front
            getVertex(min, max, min, angles), // 2 - Left-Top-Front
            getVertex(min, min, min, angles), // 3 - Left-Bottom-Front 
            getVertex(min, min, max, angles), // 4 - Left-Bottom-Back
            getVertex(min, max, max, angles), // 5 - Left-Top-Back
            getVertex(max, max, max, angles), // 6 - Right-Top-Back
            getVertex(max, min, max, angles), // 7 - Right-Bottom-Back
        ]
    }

    /*
     * Gets the faces of the entity's bounding box as an array of triangle vertices.
     *
     * @returns {array} - An array of 12 Vector triplets, where each triplet represents the three vertices of a triangle face.
    */
    function GetBBoxFaces() {
        local vertices = this.GetBBoxPoints()
        local getTriangle = macros.GetTriangle
        return [
            /* Bottom face triangles */ 
            getTriangle(vertices[0], vertices[3], vertices[4]), // Face 0: Right-Bottom-Front, Left-Bottom-Front, Left-Bottom-Back
            getTriangle(vertices[0], vertices[4], vertices[7]), // Face 1: Right-Bottom-Front, Left-Bottom-Back, Right-Bottom-Back

            /* Top face triangles */ 
            getTriangle(vertices[1], vertices[2], vertices[5]), // Face 2: Right-Top-Front, Left-Top-Front, Left-Top-Back
            getTriangle(vertices[1], vertices[5], vertices[6]), // Face 3: Right-Top-Front, Left-Top-Back, Right-Top-Back

            /* Left face triangles */ 
            getTriangle(vertices[3], vertices[2], vertices[5]), // Face 4: Left-Bottom-Front, Left-Top-Front, Left-Top-Back 
            getTriangle(vertices[3], vertices[5], vertices[4]), // Face 5: Left-Bottom-Front, Left-Top-Back, Left-Bottom-Back

            /* Right face triangles */ 
            getTriangle(vertices[0], vertices[1], vertices[6]), // Face 6: Right-Bottom-Front, Right-Top-Front, Right-Top-Back
            getTriangle(vertices[0], vertices[6], vertices[7]), // Face 7: Right-Bottom-Front, Right-Top-Back, Right-Bottom-Back

            /* Front face triangles */ 
            getTriangle(vertices[0], vertices[1], vertices[2]), // Face 8: Right-Bottom-Front, Right-Top-Front, Left-Top-Front 
            getTriangle(vertices[0], vertices[2], vertices[3]), // Face 9: Right-Bottom-Front, Left-Top-Front, Left-Bottom-Front

            /* Back face triangles */
            getTriangle(vertices[7], vertices[6], vertices[5]), // Face 10: Right-Bottom-Back, Right-Top-Back, Left-Top-Back 
            getTriangle(vertices[7], vertices[5], vertices[4])  // Face 11: Right-Bottom-Back, Left-Top-Back, Left-Bottom-Back 
        ]
    }

    /*
     * Checks if this entity is equal to another entity based on their entity indices.
     *
     * @param {pcapEntity} other - The other entity to compare.
     * @returns {boolean} - True if the entities are equal, false otherwise.
    */
    function IsEqual(other) return this.entindex() == other.entindex()

    /*
     * Converts the entity object to a string.
     *
     * @returns {string} - The string representation of the entity.
    */
    function _tostring() return "pcapEntity: " + this.CBaseEntity + ""

    /*
     * Returns the type of the entity object.
     *
     * @returns {string} - The type of the entity object.
    */
    function _typeof() return "pcapEntity"
}

/*
 * Internal helper function to perform a recursive depth-first search for descendants.
 * This should not be called directly.
 *
 * @param {CBaseEntity} pCurrentParent - The entity to search for children of.
 * @param {List} resultList - The list to append found children to.
*/
::_findDescendantsRecursive <- function(pCurrentParent, resultList) {
    local child = pCurrentParent.FirstMoveChild();

    while (child) {
        resultList.append(entLib.FromEntity(child));
        _findDescendantsRecursive(child, resultList);
        child = child.NextMovePeer();
    }
}

function pcapEntity::ConnectOutput(output, funcName) this.CBaseEntity.ConnectOutput(output, funcName)
function pcapEntity::DisconnectOutput(output, funcName) this.CBaseEntity.DisconnectOutput(output, funcName)
function pcapEntity::PrecacheSoundScript(sound_name) this.CBaseEntity.PrecacheSoundScript(sound_name)
function pcapEntity::IsSequenceFinished() return this.CBaseEntity.IsSequenceFinished()
function pcapEntity::SpawnEntity() this.CBaseEntity.SpawnEntity()

function pcapEntity::GetAngles() return this.CBaseEntity.GetAngles()
function pcapEntity::GetAngularVelocity() return this.CBaseEntity.GetAngularVelocity()
function pcapEntity::GetBoundingMaxs() return this.CBaseEntity.GetBoundingMaxs()
function pcapEntity::GetBoundingMins() return this.CBaseEntity.GetBoundingMins()
function pcapEntity::GetCenter() return this.CBaseEntity.GetCenter()
function pcapEntity::GetClassname() return this.CBaseEntity.GetClassname()
function pcapEntity::GetForwardVector() return this.CBaseEntity.GetForwardVector()
function pcapEntity::GetHealth() return this.CBaseEntity.GetHealth()
function pcapEntity::GetLeftVector() return this.CBaseEntity.GetLeftVector()
function pcapEntity::GetMaxHealth() return this.CBaseEntity.GetMaxHealth()
function pcapEntity::GetModelKeyValues() return this.CBaseEntity.GetModelKeyValues()
function pcapEntity::GetModelName() return this.CBaseEntity.GetModelName()
function pcapEntity::GetName() return this.CBaseEntity.GetName()
function pcapEntity::GetOrigin() return this.CBaseEntity.GetOrigin()
function pcapEntity::GetScriptId() return this.CBaseEntity.GetScriptId()
function pcapEntity::GetUpVector() return this.CBaseEntity.GetUpVector()
function pcapEntity::GetPartnername() return this.CBaseEntity.GetPartnername()
function pcapEntity::ValidateScriptScope() return this.CBaseEntity.ValidateScriptScope()
function pcapEntity::GetScriptScope() return this.CBaseEntity.GetScriptScope()
function pcapEntity::entindex() return this.CBaseEntity.entindex()

function pcapEntity::SetForwardVector(vector) this.CBaseEntity.SetForwardVector(vector)
function pcapEntity::SetHealth(health) this.CBaseEntity.SetHealth(health)
function pcapEntity::SetMaxHealth(health) this.CBaseEntity.SetMaxHealth(health)
function pcapEntity::SetModel(model_name) this.CBaseEntity.SetModel(model_name)
function pcapEntity::SetOrigin(vector) this.CBaseEntity.SetOrigin(vector)
function pcapEntity::SetAngles(x, y, z) this.CBaseEntity.SetAngles(x, y, z)
function pcapEntity::SetVelocity(vector) this.CBaseEntity.SetVelocity(vector)
function pcapEntity::SetBBox(mins, maxs) this.CBaseEntity.SetSize(mins, maxs)
function pcapEntity::SetSize(mins, maxs) this.CBaseEntity.SetSize(mins, maxs)

// KeyValues manipulation
function pcapEntity::__KeyValueFromInt(key, value) return this.CBaseEntity.__KeyValueFromInt(key, value)
function pcapEntity::__KeyValueFromFloat(key, value) return this.CBaseEntity.__KeyValueFromFloat(key, value)
function pcapEntity::__KeyValueFromString(key, value) return this.CBaseEntity.__KeyValueFromString(key, value)
function pcapEntity::__KeyValueFromVector(key, value) return this.CBaseEntity.__KeyValueFromVector(key, value)

// Hierarchy & Movement relations
function pcapEntity::FirstMoveChild() return this.CBaseEntity.FirstMoveChild()
function pcapEntity::GetMoveParent() return this.CBaseEntity.GetMoveParent()
function pcapEntity::GetRootMoveParent() return this.CBaseEntity.GetRootMoveParent()
function pcapEntity::NextMovePeer() return this.CBaseEntity.NextMovePeer()
function pcapEntity::GetOwner() return this.CBaseEntity.GetOwner()
function pcapEntity::SetOwner(ent) this.CBaseEntity.SetOwner(ent)

// State & Game
function pcapEntity::GetPreTemplateName() return this.CBaseEntity.GetPreTemplateName()
function pcapEntity::GetTeam() return this.CBaseEntity.GetTeam()
function pcapEntity::SetTeam(team) this.CBaseEntity.SetTeam(team)
function pcapEntity::GetSoundDuration(soundName, actorModel = "") return this.CBaseEntity.GetSoundDuration(soundName, actorModel)

// Transform & Velocity
function pcapEntity::GetVelocity() return this.CBaseEntity.GetVelocity()
function pcapEntity::SetAngularVelocity(pitch, yaw, roll) this.CBaseEntity.SetAngularVelocity(pitch, yaw, roll)
::entLib <- class {
    /*
     * Creates an entity of the specified classname with the provided keyvalues.
     *
     * @param {string} classname - The classname of the entity.
     * @param {table} keyvalues - The key-value pairs for the entity.
     * @returns {pcapEntity} - The created entity object.
    */
    function CreateByClassname(classname, keyvalues = {}) {
        // Validate parameters
        if (typeof classname != "string")
            throw("CreateByClassname: 'classname' must be a string, got " + typeof classname)
        if (classname == "")
            throw("CreateByClassname: 'classname' cannot be an empty string")
        if (typeof keyvalues != "table")
            throw("CreateByClassname: 'keyvalues' must be a table, got " + typeof keyvalues)

        local new_entity = entLib.FromEntity(Entities.CreateByClassname(classname))
        if (!new_entity)
            throw("CreateByClassname: Failed to create entity with classname '" + classname + "'")

        foreach(key, value in keyvalues) {
            new_entity.SetKeyValue(key, value)
        }

        pcapEntityCache[new_entity.CBaseEntity] <- new_entity

        return new_entity
    }


    /*
     * Creates a prop entity with the specified parameters.
     * 
     * @param {string} classname - The classname of the prop.
     * @param {Vector} origin - The initial origin (position) of the prop.
     * @param {string} modelname - The model name of the prop.
     * @param {number} activity - The initial activity of the prop. (optional, default=1)
     * @param {table} keyvalues - Additional key-value pairs for the prop. (optional)
     * @returns {pcapEntity} - The created prop entity object.
    */
    function CreateProp(classname, origin, modelname, activity = 1, keyvalues = {}) {
        // Validate parameters
        if (typeof classname != "string")
            throw("CreateProp: 'classname' must be a string, got " + typeof classname)
        if (classname == "")
            throw("CreateProp: 'classname' cannot be an empty string")
        if (typeof origin != "Vector")
            throw("CreateProp: 'origin' must be a Vector, got " + typeof origin)
        if (typeof modelname != "string")
            throw("CreateProp: 'modelname' must be a string, got " + typeof modelname)
        if (modelname == "")
            throw("CreateProp: 'modelname' cannot be an empty string")
        if (typeof activity != "integer" && typeof activity != "float")
            throw("CreateProp: 'activity' must be a number, got " + typeof activity)
        if (typeof keyvalues != "table")
            throw("CreateProp: 'keyvalues' must be a table, got " + typeof keyvalues)

        local new_entity = entLib.FromEntity(::CreateProp(classname, origin, modelname, activity))
        if (!new_entity)
            throw("CreateProp: Failed to create prop with classname '" + classname + "' and model '" + modelname + "'")

        foreach(key, value in keyvalues) {
            new_entity.SetKeyValue(key, value)
        }
        
        pcapEntityCache[new_entity.CBaseEntity] <- new_entity

        return new_entity
    }
    

    /*
     * Wraps a CBaseEntity object in a pcapEntity object.
     *
     * @param {CBaseEntity} CBaseEntity - The CBaseEntity object to wrap.
     * @returns {pcapEntity} - The wrapped entity object.
    */
    function FromEntity(CBaseEntity) {
        if (CBaseEntity == null)
            return null
        if (typeof CBaseEntity == "pcapEntity")
            return CBaseEntity
        if (typeof CBaseEntity != "instance")
            throw("FromEntity: Expected CBaseEntity instance or pcapEntity, got " + typeof CBaseEntity)
        
        return entLib.__init(CBaseEntity)
    }

    
    /*
     * Finds an entity with the specified classname.
     *
     * @param {string} classname - The classname to search for.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindByClassname(classname, start_ent = null) {
        // Validate parameters
        if (typeof classname != "string")
            throw("FindByClassname: 'classname' must be a string, got " + typeof classname)
        if (classname == "")
            throw("FindByClassname: 'classname' cannot be an empty string")
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindByClassname: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = Entities.FindByClassname(start_ent, classname)
        return entLib.__init(new_entity)
    }


    /*
     * Finds an entity with the specified classname within a given radius from the origin.
     *
     * @param {string} classname - The classname to search for.
     * @param {Vector} origin - The origin position.
     * @param {number} radius - The search radius.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindByClassnameWithin(classname, origin, radius, start_ent = null) {
        // Validate parameters
        if (typeof classname != "string")
            throw("FindByClassnameWithin: 'classname' must be a string, got " + typeof classname)
        if (classname == "")
            throw("FindByClassnameWithin: 'classname' cannot be an empty string")
        if (typeof origin != "Vector")
            throw("FindByClassnameWithin: 'origin' must be a Vector, got " + typeof origin)
        if (typeof radius != "integer" && typeof radius != "float")
            throw("FindByClassnameWithin: 'radius' must be a number, got " + typeof radius)
        if (radius <= 0)
            throw("FindByClassnameWithin: 'radius' must be greater than zero, got " + radius)
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindByClassnameWithin: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = Entities.FindByClassnameWithin(start_ent, classname, origin, radius)
        return entLib.__init(new_entity)
    }
    
    
    /* 
     * Finds an entity with the specified targetname within the given starting entity.
     *
     * @param {string} targetname - The targetname to search for.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindByName(targetname, start_ent = null) {
        // Validate parameters
        if (typeof targetname != "string")
            throw("FindByName: 'targetname' must be a string, got " + typeof targetname)
        if (targetname == "")
            throw("FindByName: 'targetname' cannot be an empty string")
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindByName: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = Entities.FindByName(start_ent, targetname)
        return entLib.__init(new_entity)
    }


    /*
     * Finds an entity with the specified targetname within a given radius from the origin.
     *
     * @param {string} targetname - The targetname to search for.
     * @param {Vector} origin - The origin position.
     * @param {number} radius - The search radius.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindByNameWithin(targetname, origin, radius, start_ent = null) {
        // Validate parameters
        if (typeof targetname != "string")
            throw("FindByNameWithin: 'targetname' must be a string, got " + typeof targetname)
        if (targetname == "")
            throw("FindByNameWithin: 'targetname' cannot be an empty string")
        if (typeof origin != "Vector")
            throw("FindByNameWithin: 'origin' must be a Vector, got " + typeof origin)
        if (typeof radius != "integer" && typeof radius != "float")
            throw("FindByNameWithin: 'radius' must be a number, got " + typeof radius)
        if (radius <= 0)
            throw("FindByNameWithin: 'radius' must be greater than zero, got " + radius)
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindByNameWithin: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = Entities.FindByNameWithin(start_ent, targetname, origin, radius)
        return entLib.__init(new_entity)
    }


    /* 
     * Finds an entity with the specified model within the given starting entity.
     *
     * @param {string} model - The model to search for.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindByModel(model, start_ent = null) {
        // Validate parameters
        if (typeof model != "string")
            throw("FindByModel: 'model' must be a string, got " + typeof model)
        if (model == "")
            throw("FindByModel: 'model' cannot be an empty string")
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindByModel: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = Entities.FindByModel(start_ent, model)
        return entLib.__init(new_entity)
    }


    /*
     * Finds an entity with the specified model within a given radius from the origin.
     *
     * @param {string} model - The model to search for.
     * @param {Vector} origin - The origin position.
     * @param {number} radius - The search radius.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindByModelWithin(model, origin, radius, start_ent = null) {
        // Validate parameters
        if (typeof model != "string")
            throw("FindByModelWithin: 'model' must be a string, got " + typeof model)
        if (model == "")
            throw("FindByModelWithin: 'model' cannot be an empty string")
        if (typeof origin != "Vector")
            throw("FindByModelWithin: 'origin' must be a Vector, got " + typeof origin)
        if (typeof radius != "integer" && typeof radius != "float")
            throw("FindByModelWithin: 'radius' must be a number, got " + typeof radius)
        if (radius <= 0)
            throw("FindByModelWithin: 'radius' must be greater than zero, got " + radius)
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindByModelWithin: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = null
        for(local ent; ent = Entities.FindByClassnameWithin(ent, "*", origin, radius);) {
            if(ent.GetModelName() == model && ent != start_ent) {
                new_entity = ent;
                break;
            }
        }

        return entLib.__init(new_entity)
    }


    /*
     * Finds entities within a sphere defined by the origin and radius.
     *
     * @param {Vector} origin - The origin position of the sphere.
     * @param {number} radius - The radius of the sphere.
     * @param {CBaseEntity|pcapEntity} start_ent - The starting entity to search within. (optional)
     * @returns {pcapEntity|null} - The found entity object, or null if not found.
    */
    function FindInSphere(origin, radius, start_ent = null) {
        // Validate parameters
        if (typeof origin != "Vector")
            throw("FindInSphere: 'origin' must be a Vector, got " + typeof origin)
        if (typeof radius != "integer" && typeof radius != "float")
            throw("FindInSphere: 'radius' must be a number, got " + typeof radius)
        if (radius <= 0)
            throw("FindInSphere: 'radius' must be greater than zero, got " + radius)
        
        if (start_ent != null) {
            if (typeof start_ent == "pcapEntity")
                start_ent = start_ent.CBaseEntity
            else if (typeof start_ent != "instance")
                throw("FindInSphere: 'start_ent' must be a CBaseEntity or pcapEntity, got " + typeof start_ent)
        }

        local new_entity = Entities.FindInSphere(start_ent, origin, radius)
        return entLib.__init(new_entity)
    }


    /* 
     * Initializes an entity object.
     *
     * @param {CBaseEntity} entity - The entity object.
     * @returns {pcapEntity|null} - A new entity object or null if invalid.
    */
    function __init(CBaseEntity) {
        if (!CBaseEntity || !CBaseEntity.IsValid())
            return null

        if (CBaseEntity in pcapEntityCache) {
            return pcapEntityCache[CBaseEntity]
        } else {
            local pcapEnt = pcapEntity(CBaseEntity)
            pcapEntityCache[CBaseEntity] <- pcapEnt
            return pcapEnt
        }
    }
}

/*
* Enhanced arrays module.
*/
::ArrayEx <- class {
    // The internal array. 
    arr = null
    
    // The internal table representation. 
    table = null;
    tableIsValid = false;
    
    /*
     * Constructor for ArrayEx.
     * 
     * Creates a new ArrayEx object from a variable number of arguments.
     *
     * @param {...} ... - A variable number of arguments representing the initial elements of the array.
    */
    constructor(...) {
        this.arr = array(vargc);
        this.table = {};
        
        for(local i = 0; i < vargc; i++) {
            this.arr[i] = vargv[i]
        }
    }

    /*
     * Creates a new ArrayEx object from an existing array.
     *
     * If the input array is already an ArrayEx object, it is returned directly.
     *
     * @param {array} array - The initial array to use for the ArrayEx object.
     * @returns {ArrayEx} - The newly created or the input ArrayEx object.
    */
    function FromArray(array) {
        // if it's already an ArrayEx, just return it.
        if(typeof array == "ArrayEx")
            return array
        
        if(typeof array != "array") throw("ArrayEx.FromArray: Invalid argument. This function only accepts a standard 'array' for conversion. Got type '" + typeof array + "' instead.")

        local arrayEx = ArrayEx()
        arrayEx.arr = array
        return arrayEx
    }

    /*
     * Creates a new ArrayEx object with a specified size, optionally filled with a default value.
     *
     * @param {int} numberOfItems - The desired number of elements in the array.
     * @param {any} fillValue - The value to fill the array with (defaults to null).
     * @returns {ArrayEx} - The newly created ArrayEx object.
    */
    function WithSize(numberOfItems, fillValue = null) {
        return ArrayEx.FromArray(array(numberOfItems, fillValue))
    } 

    /*
     * Append a value to the array.
     * 
     * @param {any} val - The value to append.
     * @returns {ArrayEx} - The ArrayEx instance for chaining.
    */
    function append(val) {
        this._pushToTable(val)
        arr.append(val);
        return this
    }

    /*
     * Apply a function to each element and modify the array in-place.
     * 
     * @param {Function} func - The function to apply.
     * @returns {ArrayEx} - The ArrayEx instance for chaining.
    */
    function apply(func) {
        foreach(idx, value in arr) {
            arr[idx] = func(value, idx)
        }
        this.totable(true)
        return this
    }

    /*
     * Clear the array and table.
     * 
     * @returns {ArrayEx} - The ArrayEx instance for chaining.
    */
    function clear() {
        this.arr.clear()
        this.table.clear()
        this.tableIsValid = false
        return this
    }

    /*
     * Extend the array with another array.
     * 
     * @param {array|ArrayEx} other - The array to extend from.
     * @returns {ArrayEx} - The ArrayEx instance for chaining.
    */
    function extend(other) {
        if(typeof other == "ArrayEx") {
            other = other.arr
        }

        arr.extend(other);
        this.totable(true)
         
        return this
    }

    /*
     * Filter the array by a predicate function.
     * 
     * @param {Function} condition(index, value, newArray) - The predicate function. 
     * @returns {ArrayEx} - The filtered array.
    */
    function filter(condition) {
        local newArray = ArrayEx()
        foreach(idx, val in arr) {
            if(condition(idx, val, newArray))
                newArray.append(val)
        }
        return newArray
    }

    /*
     * Check if the array contains a value.
     * 
     * @param {any} match - The value to find.
     * @returns {boolean} - Whether the value is found.
    */
    function contains(match) { 
        if(!this.tableIsValid) this.totable()
        return match.tostring() in this.table
    }

    /*
     * Search for a value in the array.
     * 
     * @param {any|Function} match - The value or predicate to search for.
     * @returns {int|null} - The index of the match or null.
    */
    function search(match) {
        if(typeof match == "function") {
            foreach(idx, val in this.arr) {
                if(match(val))
                    return idx
            }
        }
        else {
            foreach(idx, val in this.arr) {
                if(val == match)
                    return idx
            }
        }

        return null
    }

    /*
     * Insert a value into the array.
     * 
     * @param {int} idx - The index to insert at.
     * @param {any} val - The value to insert.
     * @returns {ArrayEx} - The ArrayEx instance for chaining.
    */
    function insert(idx, val) {
        this._pushToTable(val)
        arr.insert(idx, val)
        return this
    }

    /*
     * Get the array length.
     * 
     * @returns {int} - The array length.
    */
    function len() {
        return this.arr.len()
    }

    /*
     * Map the array to a new array via a function.
     * 
     * @param {Function} func - The mapping function.
     * @returns {ArrayEx} - The mapped array.
    */
    function map(func) {
        if(typeof func != "function") throw("ArrayEx.map: The 'func' argument must be a function, but got " + typeof func);
        local newArray = array(this.len())
        foreach(idx, value in arr) {
            newArray[idx] = func(value, idx)
        }
        return ArrayEx.FromArray(newArray)
    }

    /*
     * Reduce the array to a single value.
     * 
     * @param {Function} func - The reducer function, which takes the accumulator and current item as arguments.
     * @param {any} initial - The initial value of the accumulator.
     * @returns {any} - The reduced value.
    */
    function reduce(func, initial) {
        local accumulator = initial
        foreach(item in arr) {
            accumulator = func(accumulator, item)
        }
        return accumulator
    }

    /*
     * Return a new array with only unique elements.
     * 
     * @returns {ArrayEx} - The new array with unique elements.
    */
    function unique() {
        local seen = {}
        local result = ArrayEx()
        
        foreach(value in this.arr) {
            value = value.tostring()
            if(value in seen) continue
            seen[value] <- true    
            result.append(value)
        }

        return result
    }

    /*
     * Pop a value off the end of the array.
     * 
     * @returns {any} - The popped value.
    */
    function pop() {
        local pop = arr.pop()
        this._deleteFromTable(pop)
        return pop
    }

    /*
     * Append a value to the array.
     * 
     * @param {any} val - The value to append.
     * @returns {ArrayEx} - The ArrayEx instance for chaining.
    */
    function push(val) {
        this.append(val)
        return this
    }

    /*
     * Remove an element by index.
     * 
     * @param {int} idx - The index to remove.
     * @returns {any} - The value of the removed element.
    */
    function remove(idx) {
        local value = arr[idx]
        this._deleteFromTable(arr[idx])
        arr.remove(idx);
        return value
    }

    /*
     * Resize the array.
     * 
     * @param {int} size - The new size.
     * @param {any} fill - The fill value for new slots.
    */
    function resize(size, fill = null) {
        arr.resize(size, fill);
        this.totable(true)
        return this
    }

    /*
     * Reverse the array in-place.
     * 
     * @returns {ArrayEx} - The reversed array.
    */
    function reverse() {
        arr.reverse();
        return this
    }

    /*
     * Slice a portion of the array.
     * 
     * @param {int} startIndex - The start index.
     * @param {int} endIndex - The end index. (optional)
     * @returns {ArrayEx} - The sliced array.
    */
    function slice(startIndex, endIndex = null) {
        return ArrayEx.FromArray(arr.slice(startIndex, endIndex || this.len()))
    }

    /*
     * Sort the array.
     * 
     * @param {Function} func - Optional compare function.
     * @returns {ArrayEx} - The sorted array.
    */
    function sort(func = null) {
        func ? arr.sort(func) : arr.sort()
        return this
    }

    /*
     * Get the last element.
     * 
     * @returns {any} - The last element.
    */
    function top() {
        return arr.top();
    }

    /*
     * Join the array into a string.
     * 
     * @param {string} joinstr - The separator string.
     * @returns {string} - The joined string.
    */
    function join(joinstr = "") {
        if(this.len() == 0) return ""
        
        local string = ""
        foreach(elem in this.arr) {
            string += elem + joinstr
        }
        return joinstr.len() != 0 ? string.slice(0, joinstr.len() * -1) : string
    }

    /*
     * Retrieve the element at the specified index in the array.
     * 
     * @param {integer} idx - The index of the element to retrieve.
     * @param {any} defaultVal - Optional default value to return if the index is out of bounds. Defaults to null.
     * @returns {any} - The element at the specified index or the default value if the index is out of bounds.
    */
    function get(idx, defaultVal = null) {
        if(this.len() > idx)
            return this.arr[idx]
        return defaultVal
    }

    /*
     * Convert the array to a table.
     * 
     * @param {boolean} reacreate - Whether to recreate the table.
     * @returns {table} - The table representation.
    */
    function totable(reacreate = false) {
        if(this.table.len() > 0 && !reacreate) return this.table

        tableIsValid = true
        this.table.clear()
        foreach(element in arr) {
            if(element != null) this.table[element.tostring()] <- null
        }
        return this.table
    }

    function tolist() {
        local list = List()
        foreach(idx, value in this.arr) {
            list.append(value)
        }
        return list
    }

    /*
     * Delete a value from the internal table.
     * 
     * @param {any} val - The value to delete.
    */
    function _deleteFromTable(val) {
        if(val in this.table)
            this.table.rawdelete(val)
    }

    /*
     * Add a value to the internal table.
     * 
     * @param {any} val - The value to add.
    */
    function _pushToTable(val) {
        if(this.table.len() != 0)
            this.table[val.tostring()] <- null
    }

    function Clone() {
        return ArrayEx.FromArray(clone this.arr)
    }

    /*
     * Convert the array to a string.
     * 
     * @returns {string} - The string representation.
    */
    function _tostring() return format("Array: [%s]", this.join(", "))
    
    /*
     * Get the type name.
     * 
     * @returns {"ArrayEx"}
    */
    function _typeof () return "ArrayEx";
    
    /*
     * Get an element by index.
     * 
     * @param {int} idx - The index.
     * @returns {any} - The element.
    */
    function _get(idx) return arr[idx];
    
    /*
     * Set an element by index.
     * 
     * @param {int} idx - The index.
     * @param {any} val - The new value.
    */
    function _set(idx, val) return arr[idx] = val;

    function _cloned() return this.Clone()


    function _nexti(previdx) {
        if(this.arr.len() == 0) return null
        if (previdx == null) return 0;
		return previdx < this.arr.len() - 1 ? previdx + 1 : null;
	}
}
::__listnodetostring <- function () {return this.value.tostring()}
::ListNode <- function(value) return {
    value = value,
    _prevRef = null,
    _nextRef = null,

    tostring = __listnodetostring
} 

::List <- class {
    length = 0;
    firstNode = null;
    lastNode = null;

    /*
     * Constructor for a list.
     *
     * @param {...any} vargv - The initial values to add to the list.
    */
    constructor(...) {
        this.firstNode = ListNode(null);
        this.lastNode = this.firstNode;
        
        for(local i = 0; i < vargc; i++) {
            this.append(vargv[i])
        }
    }

    /*
     * Creates a new list from an array.
     * 
     * @param {array} array - The array to create the list from.
     * @returns {List} - The new list containing the elements from the array.
    */
    function FromArray(array) {
        if(typeof array != "array") throw("Expected array, got " + typeof array)
        local list = List()
        foreach(val in array) 
            list.append(val)
        return list
    }

    /*
     * Gets the length of the list.
     *
     * @returns {number} - The number of elements in the list.
    */
    function len() {
        return this.length;
    }

    /*
     * Appends a value to the end of the list.
     * 
     * @param {any} value - The value to append.
     * @returns {List} - The List instance for chaining.
    */
    function append(value) {
        local next_node = ListNode(value);
        local current_node = this.lastNode;

        current_node._nextRef = next_node;
        next_node._prevRef = current_node;

        this.lastNode = next_node;
        this.length++;
        return this
    }

    /*
     * Inserts a value at a specific index in the list.
     * 
     * @param {number} index - The index to insert the value at.
     * @param {any} value - The value to insert.
     * @returns {List} - The List instance for chaining.
    */
    function insert(idx, value) {
        if(this.length == 0 || idx >= this.length) 
            return this.append(value)
        local node = this.getNode(idx)
        local newNode = ListNode(value)

        newNode._nextRef = node
        newNode._prevRef = node._prevRef
        
        node._prevRef._nextRef = newNode 
        node._prevRef = newNode

        this.length++
        return this
    }

    /*
     * Gets the node at a specific index in the list.
     * 
     * @param {number} index - The index of the node to retrieve.
     * @returns {ListNode} - The node at the specified index.
     * @throws {Error} - If the index is out of bounds.
    */
    function getNode(idx) {
        if (idx >= this.length || idx < 0) {
            throw("the index '" + idx + "' does not exist!");
        }

        // If the index is in the first half, we search from the beginning
        if (idx < this.length / 2) {
            local node = this.firstNode._nextRef;
            for (local i = 0; i < idx; i++) {
                node = node._nextRef;
            }
            return node;
        } 
        // Otherwise, we search from the end
        else {
            local node = this.lastNode;
            for (local i = this.length - 1; i > idx; i--) {
                node = node._prevRef;
            }
            return node;
        }
        return node;
    }

    /*
     * Gets the value at a specific index in the list.
     * 
     * @param {number} index - The index of the value to retrieve.
     * @param {any} defaultValue - The value to return if the index is out of bounds. (optional)
     * @returns {any} - The value at the specified index or the default value if the index is out of bounds.
    */
    function get(idx, defaultValue = null) {
        if (idx >= this.length)
            return defaultValue

        return this.getNode(idx).value
    }

    /*
     * Removes the node at a specific index from the list.
     * 
     * @param {number} index - The index of the node to remove.
     * @returns {any} - The value of the removed element.
    */
    function remove(idx) {
        local node = this.getNode(idx);
        local value = node.value
        local next = node._nextRef;
        local prev = node._prevRef;
        
        node._nextRef = null;
        node._prevRef = null;

        if (prev) {
            prev._nextRef = next; 
        } else {
            this.firstNode._nextRef = next;
        }
    
        if (next) {
            next._prevRef = prev;
        } else { 
            this.lastNode = prev; 
        } 

        this.length--;
        return value
    }

    /*
     * Removes the last element from the list and returns its value.
     * 
     * @returns {any} - The value of the removed element.
    */
    function pop() {
        if(this.length == 0) throw("pop() on a empty list")

        local current = this.lastNode;
        this.lastNode = current._prevRef;
        this.lastNode._nextRef = null;
        this.length--
        // current.drop()
        return current.value;
    }

    /*
     * Gets the value of the last element in the list.
     * 
     * @returns {any} - The value of the last element.
    */
    function top() {
        if(this.length == 0) throw("top() on a empty list")
        return this.lastNode.value
    }

    function first() {
        if(this.length == 0) throw("first() on a empty list")
        return this.firstNode._nextRef.value
    }

    /*
     * Reverses the order of the elements in the list in-place.
     * @returns {List} - The List instance for chaining.
    */
    function reverse() {
        if (this.length <= 1) return this;

        local new_tail = this.firstNode._nextRef;
        local new_head = this.lastNode;

        local current = this.firstNode._nextRef;
        local prev = this.firstNode; 

        while (current) {
            local next = current._nextRef; 
            
            current._nextRef = prev;
            current._prevRef = next;

            prev = current;
            current = next;
        }

        this.firstNode._nextRef = new_head;
        new_head._prevRef = this.firstNode;

        this.lastNode = new_tail;
        this.lastNode._nextRef = null; 

        return this;
    }

    /*
     * Slice a portion of the list.
     *
     * @param {int} startIndex - The start index.
     * @param {int} endIndex - The end index. (optional)
     * @returns {List} - The sliced list.
    */
    function slice(startIndex, endIndex = null) {
        if(endIndex == null) endIndex = this.len()

        local result = List()
        foreach(idx, value in this.iter()) {
            if(idx < startIndex || idx >= endIndex) continue
            result.append(value)
        }
        return result
    }

    /*
     * Resize the list.
     * 
     * @param {int} size - The new size.
     * @param {any} fill - The fill value for new slots.
     * @returns {List} - The List instance for chaining.
    */
    function resize(size, fill = null) {
        if(size < 0) throw("Size cannot be negative.")
        local diff = size - this.len()
        
        if(diff > 0) {
            // Add elements
            for(local i = 0; i < diff; i++)
                this.append(fill)
            return this
        }

        // Remove elements
        for (local i = 0; i < -diff; i++)
            this.pop();
        return this
    }

    /*
     * Sorts the list in ascending order using merge sort.
     *
     * @returns {List} - The List instance for chaining.
    */
    function sort() {
        this.firstNode._nextRef = _mergeSort(this.firstNode._nextRef)
        
        // Update _prevRef and _nextRef links after sorting
        local current = this.firstNode._nextRef;
        local previous = this.firstNode;
        while (current) {
            current._prevRef = previous;
            if (previous) {
                previous._nextRef = current; 
            }
            previous = current; 
            current = current._nextRef; 
        } 

        // Update lastNode to point to the last node after sorting 
        this.lastNode = previous; 
        
        return this
    }

    function _mergeSort(head) {
        if (head == null || head._nextRef == null) {
            return head  // List with one or zero elements already sorted
        }
    
        // Splitting the list into two parts
        local middle = _findMiddleNode(head)
        local nextToMiddle = middle._nextRef 
        middle._nextRef = null 
    
        // Recursive sorting of two halves
        local left = _mergeSort(head)
        local right = _mergeSort(nextToMiddle) 
    
        // Merging sorted halves
        return _merge(left, right) 
    }
    
    
    function _findMiddleNode(head) {
        local slow = head
        local fast = head._nextRef
        while (fast != null && fast._nextRef != null) {
            slow = slow._nextRef
            fast = fast._nextRef._nextRef 
        }
        return slow 
    }
    
    
    function _merge(left, right) {
        local dummyHead = ListNode(null)
        local current = dummyHead
    
        while (left != null && right != null) {
            if (left.value <= right.value) {
                current._nextRef = left
                left = left._nextRef 
            } else {
                current._nextRef = right
                right = right._nextRef 
            } 
            current = current._nextRef
        } 
    
        // Add the remaining elements
        current._nextRef = left != null ? left : right
    
        return dummyHead._nextRef 
    }

    function SwapNode(node1, node2) {
        if (node1 == node2) return;
        
        local t = node1.value
        node1.value = node2.value
        node2.value = t;
    }


    /*
     * Removes all elements from the list.
     * @returns {List} - The List instance for chaining.
    */
    function clear() {
        if(this.length == 0) return
        
        local current = this.firstNode._nextRef;
        while (current) {
            local next_node = current._nextRef;
            current._prevRef = null;
            current._nextRef = null;

            current = next_node;
        }

        this.firstNode._nextRef = null;
        this.lastNode = this.firstNode;
        this.length = 0;
        return this
    }

    /*
     * More productive than the built-in iterator.
    */
    function iter() {
        if(this.length == 0) return
        local current = this.firstNode._nextRef;
        local next;
        while (current) {
            next = current._nextRef
            yield current.value
            current = next;
        }
    }

    /*
     * Similar to `iter`, but returns the node instead of the node's value.
    */
    function rawIter() {
        local current = this.firstNode._nextRef;
        while (current) {
            yield current
            current = current._nextRef;
        }
    }

    /*
     * Joins the elements of the list into a string, separated by the specified delimiter.
     * 
     * @param {string} joinstr - The delimiter to use between elements. (optional, default="")
     * @returns {string} - The joined string.
    */
    function join(joinstr = "") {
        if(this.length == 0) return ""
        
        local string = ""
        foreach(elem in this.iter()) {
            string += elem + joinstr
        }

        return joinstr.len() != 0 ? string.slice(0, joinstr.len() * -1) : string
    }

    /*
     * Apply a function to each element and modify the list in-place.
     * 
     * @param {Function} func - The function to apply.
     * @returns {List} - The List instance for chaining.
    */
    function apply(func) {
        foreach(idx, value in this.iter()) {
            this[idx] = func(value, idx)
        }
        return this
    }

    /*
     * Extends the list by appending all elements from another iterable.
     * 
     * @param {iterable} other - The iterable to append elements from.
     * @returns {List} - The List instance for chaining.
    */
    function extend(other) {
        local iter = typeof other == "List" ? other.iter() : other
        foreach(val in iter) 
            this.append(val)
        return this
    }

    // function _unsafeFastExtend(otherLis) { // todo for actions
    //     this.lastNode._nextRef = otherLis.firstNode._nextRef
    //     otherLis.firstNode._nextRef._prevRef = this.lastNode
    //     this.lastNode = otherLis.firstNode._nextRef
    //     return this
    // }

    /*
     * Searches for a value or a matching element in the list.
     * 
     * @param {any|Function} match - The value to search for or a predicate function.
     * @returns {number|null} - The index of the match or null if not found.
    */
    function search(match) {
        if(typeof match == "function") {
            foreach(idx, val in this.iter()) {
                if(match(val))
                    return idx
            }
        }
        else {
            foreach(idx, val in this.iter()) {
                if(val == match)
                    return idx
            }
        }

        return null
    }

    /*
     * Returns a new list with only the unique elements from the original list.
     *
     * @returns {List} - The new list with unique elements.
    */
    function unique() {
        local seen = {}
        local result = List()

        foreach(value in this.iter()) {
            if(value in seen) continue
            seen[value] <- true    
            result.append(value)
        }

        return result
    }

    /*
     * Creates a new list by applying a function to each element of this list.
     * 
     * @param {Function} func - The function to apply to each element.
     * @returns {List} - The new list with the mapped values.
    */
    function map(func) {
        if(typeof func != "function") throw("List.map: The 'func' argument must be a function, but got " + typeof func);
        local newList = List()
        foreach(idx, value in this.iter()) {
            newList.append(func(value, idx))
        }
        return newList
    }

    /*
     * Filter the list by a predicate function.
     * 
     * @param {Function} condition(index, value, newList) - The predicate function. 
     * @returns {List} - The filtered list.
    */
    function filter(condition) {
        local newList = List()
        foreach(idx, val in this.iter()) {
            if(condition(idx, val, newList))
                newList.append(val)
        }
        return newList
    }

    /*
     * Applies a function to an accumulator and each element in the list (from left to right)
     * to reduce it to a single value.
     *
     * @param {function} func - The function to apply to each element and accumulator.
     * @param {any} initial - The initial value of the accumulator.
     * @returns {any} - The final reduced value.
    */
    function reduce(func, initial) {
        local accumulator = initial
        foreach(item in this.iter()) {
            accumulator = func(accumulator, item)
        }
        return accumulator
    }

    /*
     * Convert the list to a table.
     * 
     * @returns {table} - The table representation.
    */
    function totable() {
        local table = {}
        foreach(element in this.iter()) {
            if(element != null) // null can't be the key 
                table[element] <- null
        }
        return table
    }

    /*
     * Converts the list to an array.
     * 
     * @returns {array} - An array containing the elements of the list.
    */
    function toarray() {
        local array = ArrayEx.WithSize(this.length)
        foreach(idx, value in this.iter()) {
            array[idx] = value
        }
        return array
    }

    // Metamethods
    function _tostring() return format("List: [%s]", this.join(", "))
    function _typeof () return "List";
    function _get(idx) return this.getNode(idx).value;
    function _set(idx, val) return this.getNode(idx).value = val

    //* OUTDATED! The standard iterator, it's terrible! Use `.iter()` method
    function _nexti(previdx) {
        local callstack = "\nCallstack:\n"
        // Start at level 2 to skip this _nexti function and the internal VM call.
        for (local level = 2; ; level++) {
            local info = getstackinfos(level)
            // Stop when we've gone through the entire stack.
            if (info == null) break
            
            // Format the information for readability.
            local source = ("src" in info) ? info.src : "unknown_source"
            local line = ("line" in info) ? info.line : "?"
            local func = ("func" in info) ? info.func : "global_scope"
            
            callstack += "  at " + source + ":" + line + " in function '" + func + "'\n"
        }

        local errorMessage = "DEPRECATED ITERATION: Standard 'foreach' is not supported for List. " +
                             "Please use the high-performance '.iter()' method instead.\n\n" +
                             "Example: foreach (item in yourList.iter()) { ... }" +
                             callstack

        printl(errorMessage)
        throw(errorMessage)
    }
}
/*
 * A node in an AVL tree.
*/
::treeNode <- class {
    // The value stored in the node. 
    value = null;
    // The left child node. 
    l = null;
    // The right child node. 
    r = null; 
    // The height of the node. 
    h = 1; 

    /*
     * Constructor for a tree node.
     *
     * @param {any} value - The value to store in the node.
    */
    constructor(value) {
        this.value = value;
    }

    function _tostring() return format("treeNode(%i)", this.value);
    
    function _typeof() return "treeNode"
}

/*
 * An AVL tree implementation.
 *
 * An AVL tree is a self-balancing binary search tree where the heights of the two child subtrees of any node differ by at most one.
*/
::AVLTree <- class {
    // The root node of the tree. 
    root = null;
    // The number of nodes in the tree. 
    size = 0;
    // A cache of the inorder traversal of the tree. 
    inorderCache = null;

    /*
     * Constructor for an AVL tree.
     *
     * @param {...any} vargv - The initial values to add to the tree.
    */
    constructor(...) {
        for (local i = 0; i < vargc; i++) {
            this.insert(vargv[i]);
        }
    }

    /*
     * Creates a new AVL tree from an array.
     * 
     * @param {array} array - The array to create the tree from.
     * @returns {AVLTree} - The new tree containing the elements from the array.
    */
    function FromArray(array) {
        local tree = AVLTree()
        foreach(val in array) 
            tree.insert(val)
        return tree
    }

    // --- Basic Methods ---

    /*
     * Gets the number of nodes in the tree.
     *
     * @returns {number} - The number of nodes in the tree.
    */
    function len() {
        return this.size;
    }

    /*
     * Converts the tree to an array using inorder traversal.
     *
     * @returns {ArrayEx} - An array containing the tree nodes in ascending order.
    */
    function toarray() { 
        if(this.inorderCache == null) 
            this.inorderCache = this.inorderTraversal()

        return this.inorderCache
    }

    /*
     * Converts the tree to a list using inorder traversal.
     *
     * @returns {List} - A list containing the tree nodes in ascending order.
    */
    function tolist() {
        local result = List();
        this._inorder(this.root, result);
        return result;
    }

    function _tostring() {
        local values = this.toarray()
        return format("AVLTree: {%s}", values.join(", "));
    }

    function _typeof() {
        return "AVLTree";
    }

    function _get(idx) {
        local values = this.toarray()
        if (idx < 0 || idx >= values.len()) {
            throw Error("the index '" + idx + "' does not exist");
        }
        return values[idx];
    }

    function _nexti(previdx) {
        local len = this.len();
        if (len == 0) return null;
        if (previdx == null) return 0;
        return previdx < len - 1 ? previdx + 1 : null;
    }

    // --- Insertion Methods --- 

    /*
     * Inserts a new node with the given key into the tree.
     *
     * @param {any} key - The key of the node to insert.
    */
    function insert(key) {
        this.root = this._insert(this.root, key);
        this.size++
        this.inorderCache = null;
    }

    /*
     * Recursive helper function for inserting a node into the tree.
     *
     * @param {treeNode|null} node - The current node being examined.
     * @param {any} key - The key of the node to insert.
     * @returns {treeNode} - The root node of the subtree after insertion.
    */
    function _insert(node, key) {
        if (node == null) {
            return treeNode(key);
        } else if (key < node.value) {
            node.l = _insert(node.l, key);
        } else {
            node.r = _insert(node.r, key);
        }
    
        // Update height
        node.h = 1 + math.max(_getHeight(node.l), _getHeight(node.r));

        // Update the balance factor and balance the tree
        local balanceFactor = _balanceFactor(node);

        // Left Left Case
        if (balanceFactor > 1 && key < node.l.value) {
            return _rRotate(node);
        }

        // Right Right Case
        if (balanceFactor < -1 && key > node.r.value) {
            return _lRotate(node);
        }

        // Left Right Case
        if (balanceFactor > 1 && key > node.l.value) {
            node.l = _lRotate(node.l);
            return _rRotate(node);
        }

        // Right Left Case
        if (balanceFactor < -1 && key < node.r.value) {
            node.r = _rRotate(node.r);
            return _lRotate(node);
        }

        return node;
    }

    // --- Balancing Methods ---

    /*
     * Performs a left rotation on the given node.
     *
     * @param {treeNode} x - The node to rotate.
     * @returns {treeNode} - The new root node of the subtree after rotation.
    */
    function _lRotate(x) {
        local y = x.r;
        local T2 = y.l;

        y.l = x;
        x.r = T2;

        x.h = 1 + math.max(_getHeight(x.l), _getHeight(x.r));
        y.h = 1 + math.max(_getHeight(y.l), _getHeight(y.r));

        return y;
    }

    /*
     * Performs a right rotation on the given node.
     *
     * @param {treeNode} x - The node to rotate.
     * @returns {treeNode} - The new root node of the subtree after rotation.
    */
    function _rRotate(x) {
        local y = x.l;
        local T3 = y.r;

        y.r = x;
        x.l = T3;

        x.h = 1 + math.max(_getHeight(x.l), _getHeight(x.r));
        y.h = 1 + math.max(_getHeight(y.l), _getHeight(y.r));

        return y;
    }

    // --- Height & Balance Methods ---

    /*
     * Gets the height of a node.
     *
     * @param {treeNode|null} node - The node to get the height of.
     * @returns {number} - The height of the node, or 0 if the node is null. 
    */
    function _getHeight(node) {
        if (node == null) {
            return 0;
        }
        return node.h;
    }

    /*
     * Gets the balance factor of a node.
     *
     * The balance factor is the difference in height between the left and right subtrees of the node.
     *
     * @param {treeNode|null} node - The node to get the balance factor of.
     * @returns {number} - The balance factor of the node.
    */
    function _balanceFactor(node) {
        if (node == null) {
            return 0;
        }
        return _getHeight(node.l) - _getHeight(node.r);
    }

    // --- Search Methods ---

    /*
     * Searches for a node with the given value in the tree.
     *
     * @param {any} value - The value to search for.
     * @returns {treeNode|null} - The node with the matching value, or null if not found.
    */
    function search(value) {
        return this._search(this.root, value);
    }

    /*
     * Recursive helper function for searching for a node in the tree.
     *
     * @param {treeNode|null} node - The current node being examined.
     * @param {any} value - The value to search for.
     * @returns {treeNode|null} - The node with the matching value, or null if not found. 
    */
    function _search(node, value) {
        if (!node || node.value == value) {
            return node;
        }

        if (value < node.value) {
            return this._search(node.l, value);
        } else {
            return this._search(node.r, value);
        }
    }

    // --- Removal Methods  ---

    /*
     * Removes the node with the given value from the tree.
     *
     * @param {any} value - The value of the node to remove.
    */
    function remove(value) {
        this.root = this._remove(this.root, value);
        this.size--
        this.inorderCache = null
    }

    /*
     * Recursive helper function for removing a node from the tree.
     *
     * @param {treeNode|null} node - The current node being examined.
     * @param {any} value - The value of the node to remove. 
     * @returns {treeNode|null} - The root node of the subtree after removal.
    */
    function _remove(node, value) {
        if (!node) {
            return null;
        }

        if (value < node.value) {
            node.l = this._remove(node.l, value);
        } else if (value > node.value) {
            node.r = this._remove(node.r, value);
        } else {
            // Node found, handle deletion based on number of children
            if (!node.l || !node.r) {
                local temp = node.l ? node.l : node.r;
                node = temp; // Replace node with its child
            } else {
                // Node has two children, find inorder successor
                local temp = this.min(node.r);
                node.value = temp.value;
                node.r = this._remove(node.r, temp.value);
            }
        }

        if (!node) {
            return node;
        }

        // Balance the tree
        node.h = 1 + math.max(_getHeight(node.l), _getHeight(node.r));

        local balanceFactor = _balanceFactor(node);

        // Balance the tree
        // Left Left Case
        if (balanceFactor > 1 && _balanceFactor(node.l) >= 0) {
            return _rRotate(node);
        }

        // Left Right Case
        if (balanceFactor > 1 && _balanceFactor(node.l) < 0) {
            node.l = _lRotate(node.l);
            return _rRotate(node);
        }

        // Right Right Case
        if (balanceFactor < -1 && _balanceFactor(node.r) <= 0) {
            return _lRotate(node);
        }

        // Right Left Case
        if (balanceFactor < -1 && _balanceFactor(node.r) > 0) {
            node.r = _rRotate(node.r);
            return _lRotate(node);
        }

        return node;
    }

    // --- Min/Max Methods ---

    /*
     * Gets the minimum value in the tree.
     *
     * @returns {any} - The minimum value in the tree.
    */
    function GetMin() return this.min(this.root).value
    
    /*
     * Gets the maximum value in the tree.
     *
     * @returns {any} - The maximum value in the tree.
    */
    function GetMax() return this.max(this.root).value

    function min(node) {
        local current = node;
        while (current && current.l) {
            current = current.l;
        }
        return current;
    }

    function max(node) {
        local current = node;
        while (current && current.r) {
            current = current.r;
        }
        return current;
    }

    // --- Traversal Methods ---

    /*
     * Performs an inorder traversal of the tree and returns the nodes in ascending order.
     *
     * @returns {ArrayEx} - An array containing the tree nodes in ascending order.
    */
    function inorderTraversal() {
        local result = ArrayEx();
        this._inorder(this.root, result);
        return result;
    }

    /*
     * Recursive helper function for inorder traversal.
     *
     * @param {treeNode|null} node - The current node being visited.
     * @param {ArrayEx} result - The array to store the traversed nodes. 
    */
    function _inorder(node, result) {
        if (node) {
            this._inorder(node.l, result);
            result.append(node.value);
            this._inorder(node.r, result);
        }
    }

    // Print the tree
    function printTree() return this._print(this.root, "", true)

    function _print(currPtr, indent, last) {
        if(currPtr != null) {
            print(indent)
            if(last) {
                print("R----")
                indent += "     "
            }
            else {
                print("L----")
                indent += "|    "
            }
            printl(currPtr.value)
            this._print(currPtr.l, indent, false)
            this._print(currPtr.r, indent, true)
        }
    }
}

// dissolve entity for pcapEnts
if(("dissolver" in getroottable()) == false) {
    ::dissolver <- entLib.CreateByClassname("env_entity_dissolver", {targetname = "@dissolver"})
} 
/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Visionary Mathematician - laVashik :O                                        |
+----------------------------------------------------------------------------------+
|    The core mathematical module, providing essential functions and objects for   |
|    performing calculations, transformations, and interpolations in VScripts.     |
+----------------------------------------------------------------------------------+ */

::math <- {}

/*
 * Finds the minimum value among the given arguments.
 *
 * @param {...number} vargv - The numbers to compare.
 * @returns {number} - The minimum value.
*/
math["min"] <- function(...) {
    if (vargc == 0) throw("math.min: no arguments");
    local min = vargv[0]
    for(local i = 0; i< vargc; i++) {
        if(min > vargv[i])
            min = vargv[i]
    }
    
    return min
}


/*
 * Finds the maximum value among the given arguments.
 *
 * @param {...number} vargv - The numbers to compare.
 * @returns {number} - The maximum value.
*/
math["max"] <- function(...) {
    if (vargc == 0) throw("math.max: no arguments");
    local max = vargv[0]
    for(local i = 0; i< vargc; i++) {
        if(vargv[i] > max)
            max = vargv[i]
    }

    return max
}


/*
 * Clamps a number within the specified range.
 *
 * @param {number} number - The number to clamp.
 * @param {number} min - The minimum value.
 * @param {number} max - The maximum value (optional).
 * @returns {number} - The clamped value.
*/
math["clamp"] <- function(number, min, max = 99999) { 
    if ( number < min ) return min;
    if ( number > max ) return max;
    return number
}


/*
 * Rounds a number to the specified precision.
 *
 * @param {number} value - The number to round.
 * @param {int} precision - The precision (e.g., 1000 for rounding to three decimal places).
 * @returns {number} - The rounded value.
*/
math["round"] <- function(value, precision = 1) {
    return floor(value * precision + 0.5) / precision
}


/*
 * Returns the sign of a number.
 *
 * @param {number} x - The number.
 * @returns {number} - The sign of the number (-1, 0, or 1).
*/
math["Sign"] <- function(x) {
    if (x > 0) {
        return 1;
    } else if (x < 0) {
        return -1;
    } else {
        return 0;
    }
}


/*
 * Copies the sign of one value to another.
 *
 * @param {number} value - The value to copy the sign to.
 * @param {number} sign - The sign to copy.
 * @returns {number} - The value with the copied sign.
*/
math["copysign"] <- function(value, sign) {
    local mag = value < 0 ? -value : value;
    return (sign < 0) ? -mag : mag;
}


/*
 * Remaps a value from the range [A, B] to the range [C, D].
 *
 * If A is equal to B, the value will be clamped to C or D depending on its relationship to B.
 *
 * @param {number} value - The value to remap.
 * @param {number} A - The start of the input range.
 * @param {number} B - The end of the input range.
 * @param {number} C - The start of the output range.
 * @param {number} D - The end of the output range.
 * @returns {number} - The remapped value.
*/
math["RemapVal"] <- function( value, A, B, C, D )
{
    if ( A == B )
    {
        if ( value >= B )
            return D;
        return C;
    };
    return C + (D - C) * (value - A) / (B - A);
}   
math["vector"] <- {}
local mVector = math["vector"]

/*
 * Checks if two vectors are approximately equal, within a certain precision.
 * This function rounds the components of both vectors before comparing them.
 *
 * @param {Vector} vector - The first vector.
 * @param {Vector} other - The second vector.
 * @param {int} precision - The precision factor (e.g., 1000 for rounding to three decimal places).
 * @returns {boolean} - True if the vectors are approximately equal, false otherwise.
*/
mVector["IsEqual"] <- function(vector, other, precision = 1000) {
    vector = math.vector.round(vector, precision)
    other = math.vector.round(other, precision)
    return vector.x == other.x && 
            vector.y == other.y && 
            vector.z == other.z
}


/*
 * Compares two vectors based on their lengths.
 *
 * @param {Vector} vector - The first vector.
 * @param {Vector} other - The second vector.
 * @returns {int} - 1 if the first vector is longer, -1 if the second vector is longer, and 0 if they have equal lengths.
*/mVector["cmp"] <- function(vector, other) {
    local l1 = vector.Length()
    local l2 = other.Length()
    if(l1 > l2) return 1
    if(l1 < l2) return -1
    return 0
}


/*
 * Performs element-wise multiplication of two vectors.
 *
 * @param {Vector} vector - The first vector.
 * @param {Vector} other - The second vector.
 * @returns {Vector} - A new vector with the result of the element-wise multiplication.
*/
mVector["mul"] <- function(vector, other) {
    return Vector(vector.x * other.x, vector.y * other.y, vector.z * other.z)
}

/*
 * Rotates a vector by a given angle.
 *
 * @param {Vector} vector - The vector to rotate.
 * @param {Vector} angle - The Euler angles in degrees (pitch, yaw, roll) representing the rotation.
 * @returns {Vector} - The rotated vector. 
*/
mVector["rotate"] <- function(vector, angle) {
    return math.Quaternion.fromEuler(angle).rotateVector(vector)
}

/*
 * Un-rotates a vector by a given angle.
 *
 * @param {Vector} vector - The vector to un-rotate.
 * @param {Vector} angle - The Euler angles in degrees (pitch, yaw, roll) representing the rotation to reverse.
 * @returns {Vector} - The un-rotated vector.
*/
mVector["unrotate"] <- function(vector, angle) {
    return math.Quaternion.fromEuler(angle).unrotateVector(vector)
}

/*
 * Generates a random vector within the specified range.
 *
 * If `min` and `max` are both vectors, each component of the resulting vector will be a random value between the corresponding components of `min` and `max`.
 * If `min` and `max` are numbers, all components of the resulting vector will be random values between `min` and `max`.
 *
 * @param {Vector|number} min - The minimum values for each component or a single minimum value for all components.
 * @param {Vector|number} max - The maximum values for each component or a single maximum value for all components.
 * @returns {Vector} - The generated random vector.
*/
mVector["random"] <- function(min, max) {
    if(typeof min == "Vector" && typeof max == "Vector") 
        return Vector(RandomFloat(min.x, max.x), RandomFloat(min.y, max.y), RandomFloat(min.z, max.z))
    return Vector(RandomFloat(min, max), RandomFloat(min, max), RandomFloat(min, max))
}

/*
 * Reflects a direction vector off a surface with a given normal.
 *
 * @param {Vector} dir - The direction vector to reflect.
 * @param {Vector} normal - The normal vector of the surface.
 * @returns {Vector} - The reflected direction vector.
*/
mVector["reflect"] <- function(dir, normal) {
    return dir - normal * (dir.Dot(normal) * 2)
}

/*
 * Clamps the components of a vector within the specified range.
 *
 * @param {Vector} vector - The vector to clamp.
 * @param {number} min - The minimum value for each component.
 * @param {number} max - The maximum value for each component.
 * @returns {Vector} - The clamped vector.
*/
mVector["clamp"] <- function(vector, min = 0, max = 255) {
    return Vector(math.clamp(vector.x, min, max), math.clamp(vector.y, min, max), math.clamp(vector.z, min, max)) 
}

/*
 * Resizes a vector to a new length while maintaining its direction.
 *
 * @param {Vector} vector - The vector to resize.
 * @param {number} newLength - The desired new length of the vector.
 * @returns {Vector} - The resized vector with the specified length.
*/
mVector["resize"] <- function(vector, newLength) {
    local currentLength = vector.Length()
    return vector * (newLength / currentLength)
}

/*
 * Rounds the elements of a vector to the specified precision.
 *
 * @param {Vector} vec - The vector to round.
 * @param {int} precision - The precision (e.g., 1000 for rounding to three decimal places).
 * @returns {Vector} - The rounded vector.
*/
mVector["round"] <- function(vec, precision = 1000) {
    vec.x = floor(vec.x * precision + 0.5) / precision
    vec.y = floor(vec.y * precision + 0.5) / precision
    vec.z = floor(vec.z * precision + 0.5) / precision
    return vec
}

/* 
 * Returns a vector with the signs (-1, 0, or 1) of each component of the input vector.
 * 
 * @param {Vector} vec - The input vector.
 * @returns {Vector} - A new vector with the signs of the input vector's components.
*/
mVector["sign"] <- function(vec) {
    return Vector(math.Sign(vec.x), math.Sign(vec.y), math.Sign(vec.z))
}

/* 
 * Calculates the absolute value of each component in a vector.
 *
 * @param {Vector} vector - The vector to calculate the absolute values for.
 * @returns {Vector} - A new vector with the absolute values of the original vector's components.
*/
mVector["abs"] <- function(vector) {
    return Vector(::abs(vector.x), ::abs(vector.y), ::abs(vector.z)) 
}

math["lerp"] <- {}
local lerp = math["lerp"]


/*
 * Performs linear interpolation (lerp) between start and end based on the parameter t.
 *
 * @param {number} start - The starting value.
 * @param {number} end - The ending value.
 * @param {number} t - The interpolation parameter.
 * @returns {number} - The interpolated value.
*/
lerp["number"] <- function(start, end, t) {
    return start * (1 - t) + end * t;
}


/*
 * Performs linear interpolation (lerp) between two vectors.
 *
 * @param {Vector} start - The starting vector.
 * @param {Vector} end - The ending vector.
 * @param {number} t - The interpolation parameter.
 * @returns {Vector} - The interpolated vector.
*/
lerp["vector"] <- function(start, end, t) {
    return Vector(math.lerp.number(start.x, end.x, t), math.lerp.number(start.y, end.y, t), math.lerp.number(start.z, end.z, t));
}


/*
 * Performs linear interpolation (lerp) between two colors.
 *
 * @param {Vector|string} start - The starting color vector or string representation (e.g., "255 0 0").
 * @param {Vector|string} end - The ending color vector or string representation.
 * @param {number} t - The interpolation parameter.
 * @returns {string} - The interpolated color string representation (e.g., "128 64 0").
*/
lerp["color"] <- function(start, end, t) {
    if (type(start) == "string") {
        start = macros.StrToVec(start)
    }
    if (type(end) == "string") {
        end = macros.StrToVec(end)
    }

    return floor(math.lerp.number(start.x, end.x, t)) + " " + floor(math.lerp.number(start.y, end.y, t)) + " " + floor(math.lerp.number(start.z, end.z, t))
}

// SLERP for vector 
lerp["sVector"] <- function(start, end, t) {
    local q1 = math.Quaternion.fromEuler(start)
    local q2 = math.Quaternion.fromEuler(end)
    return q1.slerp(q2, t).toVector()
}

/*
 * Performs smooth interpolation between two values using a smoothstep function.
 *
 * @param {number} edge0 - The lower edge of the interpolation range.
 * @param {number} edge1 - The upper edge of the interpolation range.
 * @param {number} value - The interpolation parameter.
 * @returns {number} - The interpolated value.
*/
lerp["SmoothStep"] <- function(edge0, edge1, value) {
    if(edge0 == edge1) return 0
    local t = math.clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t)
}


/*
 * Performs linear interpolation between two values.
 *
 * @param {number} f1 - The start value.
 * @param {number} f2 - The end value.
 * @param {number} i1 - The start interpolation parameter.
 * @param {number} i2 - The end interpolation parameter.
 * @param {number} value - The interpolation parameter.
 * @returns {number} - The interpolated value.
*/
lerp["FLerp"] <- function( f1, f2, i1, i2, value ) {
    if(i1 == i2) return f2
    return f1 + (f2 - f1) * (value - i1) / (i2 - i1);
}
// More info here: https://gizma.com/easing/

math["ease"] <- {}
local ease = math["ease"]

ease["InSine"] <- function(t) { 
    return 1 - cos((t * PI) / 2);
}

ease["OutSine"] <- function(t) { 
    return sin((t * PI) / 2);
}

ease["InOutSine"] <- function(t) { 
    return -(cos(PI * t) - 1) / 2;
}

ease["InQuad"] <- function(t) { 
    return t * t; 
}

ease["OutQuad"] <- function(t) { 
    return 1 - (1 - t) * (1 - t); 
}

ease["InOutQuad"] <- function(t) { 
    return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
}

ease["InCubic"] <- function(t) { 
    return t * t * t;
}

ease["OutCubic"] <- function(t) { 
    return 1 - pow(1 - t, 3);
}

ease["InOutCubic"] <- function(t) { 
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
}

ease["InQuart"] <- function(t) {
    return t * t * t * t; 
}

ease["OutQuart"] <- function(t) { 
    return 1 - pow(1 - t, 4);
}

ease["InOutQuart"] <- function(t) { 
    return t < 0.5 ? 8 * t * t * t * t : 1 - pow(-2 * t + 2, 4) / 2;
}

ease["InQuint"] <- function(t) { 
    return t * t * t * t * t;
}

ease["OutQuint"] <- function(t) { 
    return 1 - pow(1 - t, 5);
}

ease["InOutQuint"] <- function(t) { 
    return t < 0.5 ? 16 * t * t * t * t * t : 1 - pow(-2 * t + 2, 5) / 2;
}

ease["InExpo"] <- function(t) { 
    return t == 0 ? 0 : pow(2, 10 * t - 10);
}

ease["OutExpo"] <- function(t) { 
    return t == 1 ? 1 : 1 - pow(2, -10 * t);
}

ease["InOutExpo"] <- function(t) { 
    return t == 0 ? 0 : t == 1 ? 1 : t < 0.5 ? pow(2, 20 * t - 10) / 2 : (2 - pow(2, -20 * t + 10)) / 2;
}

ease["InCirc"] <- function(t) { 
    return 1 - sqrt(1 - pow(t, 2));
}

ease["OutCirc"] <- function(t) { 
    return sqrt(1 - pow(t - 1, 2));
}

ease["InOutCirc"] <- function(t) { 
    return t < 0.5 ? (1 - sqrt(1 - pow(2 * t, 2))) / 2 : (sqrt(1 - pow(-2 * t + 2, 2)) + 1) / 2;
}

ease["InBack"] <- function(t) { 
    local c1 = 1.70158;
    local c3 = c1 + 1;
    return c3 * t * t * t - c1 * t * t;
}

ease["OutBack"] <- function(t) { 
    local c1 = 1.70158;
    local c3 = c1 + 1;
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
}

ease["InOutBack"] <- function(t) { 
    local c1 = 1.70158;
    local c2 = c1 * 1.525;
    return t < 0.5
       ? (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
       : (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2;
}

ease["InElastic"] <- function(t) { 
    local c4 = (2 * PI) / 3;
    return t == 0
        ? 0
        : t == 1
        ? 1
        : -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * c4);
}

ease["OutElastic"] <- function(t) { 
    local c4 = (2 * PI) / 3;
    return t == 0
    ? 0
    : t == 1
    ? 1
    : pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1;
}

ease["InOutElastic"] <- function(t) { 
    local c5 = (2 * PI) / 4.5;
    return t == 0
    ? 0
    : t == 1
    ? 1
    : t < 0.5
    ? -(pow(2, 20 * t - 10) * sin((20 * t - 11.125) * c5)) / 2
    : (pow(2, -20 * t + 10) * sin((20 * t - 11.125) * c5)) / 2 + 1;
}

ease["InBounce"] <- function(t) { 
    return 1 - math.ease.OutBounce(1 - t); // todo
}

ease["OutBounce"] <- function(t) { 
    local n1 = 7.5625;
    local d1 = 2.75;
    if (t < 1 / d1) {
    return n1 * t * t;
    } else if (t < 2 / d1) {
        return n1 * (t -= 1.5 / d1) * t + 0.75;
    } else if (t < 2.5 / d1) {
        return n1 * (t -= 2.25 / d1) * t + 0.9375;
    } else {
        return n1 * (t -= 2.625 / d1) * t + 0.984375;
    }
}

ease["InOutBounce"] <- function(t) { 
    return t < 0.5
    ? (1 - math.ease.OutBounce(1 - 2 * t)) / 2
    : (1 + math.ease.OutBounce(2 * t - 1)) / 2;
}
math["Quaternion"] <- class {
    x = null;
    y = null;
    z = null;
    w = null;
    
    /*
     * Creates a new quaternion.
     *
     * @param {number} x - The x component.
     * @param {number} y - The y component.
     * @param {number} z - The z component.
     * @param {number} w - The w component.
    */
    constructor(x,y,z,w) {
        this.x = x
        this.y = y
        this.z = z
        this.w = w
    }

    /*
     * Creates a new quaternion from Euler angles.
     *
     * @param {Vector} angles - The Euler angles in degrees (pitch, yaw, roll).
     * @returns {Quaternion} - The new quaternion.
    */
    function fromEuler(angles) {
        // Convert angles to radians
        local pitch = angles.z * 0.5 / 180 * PI
        local yaw = angles.y * 0.5 / 180 * PI
        local roll = angles.x * 0.5 / 180 * PI

        // Calculate sine and cosine values
        local sRoll = sin(roll);
        local cRoll = cos(roll);
        local sPitch = sin(pitch);
        local cPitch = cos(pitch);
        local sYaw = sin(yaw);
        local cYaw = cos(yaw);

        // Calculate quaternion components
        return math.Quaternion(
            cYaw * cRoll * sPitch - sYaw * sRoll * cPitch,
            cYaw * sRoll * cPitch + sYaw * cRoll * sPitch,
            sYaw * cRoll * cPitch - cYaw * sRoll * sPitch,
            cYaw * cRoll * cPitch + sYaw * sRoll * sPitch
        )
    }

    /*
     * Creates a new quaternion from a vector.
     *
     * @param {Vector} vector - The vector.
     * @returns {Quaternion} - The new quaternion with the vector's components as x, y, z, and w set to 0.
    */
    function fromVector(vector) {
        return math.Quaternion(vector.x, vector.y, vector.z, 0)
    }


    /*
     * Rotates a vector by the quaternion.
     *
     * @param {Vector} vector - The vector to rotate.
     * @returns {Vector} - The rotated vector.
    */
    function rotateVector(vector) {
        // Convert vector to quaternion
        local vecQuaternion = this.fromVector(vector)
    
        // Find the inverse quaternion
        local inverse = math.Quaternion(
            -this.x,
            -this.y,
            -this.z,
            this.w
        )
    
        // Apply quaternion rotations to the vector
        local rotatedQuaternion = this * vecQuaternion * inverse;
    
        // Return the result as a rotated vector
        return Vector(rotatedQuaternion.x, rotatedQuaternion.y, rotatedQuaternion.z);
    }
    
    /*
     * Un-rotates a vector by the quaternion.
     *
     * @param {Vector} vector - The vector to un-rotate.
     * @returns {Vector} - The un-rotated vector.
    */
    function unrotateVector(vector) {
        local vecQuaternion = this.fromVector(vector)

        // Find the conjugate quaternion
        local conjugateQuaternion = math.Quaternion(
            -this.x,
            -this.y,
            -this.z,
            this.w
        );
        
        // Apply quaternion rotations to the vector with inverse rotation angles
        local unrotatedQuaternion = conjugateQuaternion * vecQuaternion * this;
    
        // Return the result as an un-rotated vector
        return Vector(unrotatedQuaternion.x, unrotatedQuaternion.y, unrotatedQuaternion.z);
    }

    /*
     * Performs spherical linear interpolation (slerp) between two quaternions.
     *
     * @param {Quaternion} targetQuaternion - The target quaternion to interpolate towards.
     * @param {Number} t - The interpolation parameter between 0 and 1.
     * @returns {Quaternion} - The interpolated quaternion.
    */
    function slerp(targetQuaternion, t) {
        // Normalize quaternions
        local quaternion1 = this.normalize()
        local quaternion2 = targetQuaternion.normalize()

        // Calculate angle between quaternions
        local cosTheta = quaternion1.x * quaternion2.x + quaternion1.y * quaternion2.y + quaternion1.z * quaternion2.z + quaternion1.w * quaternion2.w;

        // If angle is negative, invert the second quaternion
        if (cosTheta < 0) {
            quaternion2.x *= -1;
            quaternion2.y *= -1;
            quaternion2.z *= -1;
            quaternion2.w *= -1;
            cosTheta *= -1;
        }

        // Calculate interpolation values
        local theta = acos(cosTheta);
        local sinTheta = sin(theta);
        local weight1 = sin((1 - t) * theta) / sinTheta;
        local weight2 = sin(t * theta) / sinTheta;

        // Interpolate quaternions
        local resultQuaternion = math.Quaternion(
            weight1 * quaternion1.x + weight2 * quaternion2.x,
            weight1 * quaternion1.y + weight2 * quaternion2.y,
            weight1 * quaternion1.z + weight2 * quaternion2.z,
            weight1 * quaternion1.w + weight2 * quaternion2.w
        );

        return resultQuaternion.normalize()
    }

    /*
     * Normalizes the quaternion.
     *
     * @returns {Quaternion} - The normalized quaternion.
    */
    function normalize() {
        local magnitude = this.length()
        if(magnitude == 0) throw "Quaternion.normalize: zero length"

        return math.Quaternion(
            this.x / magnitude,
            this.y / magnitude,
            this.z / magnitude,
            this.w / magnitude
        )
    }

    /*
     * Calculates the dot product of two quaternions.
     * 
     * @param {Quaternion} other - The other quaternion.
     * @returns {number} - The dot product.
    */
    function dot(other) {
        return this.x * other.x + this.y * other.y + this.z * other.z + this.w * other.w;
    }

    /*
     * Calculates the length (magnitude) of the quaternion.
     * 
     * @returns {number} - The length of the quaternion.
    */
    function length() {
        return sqrt(this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w);
    }

    /*
     * Calculates the inverse of the quaternion.
     * 
     * @returns {Quaternion} - The inverse quaternion.
    */
    function inverse() {
        local len2 = this.length() * this.length();
        if (len2 == 0) throw "Quaternion.inverse: zero length";
        return math.Quaternion(-this.x / len2, -this.y / len2, -this.z / len2, this.w / len2);
    }

    /*
     * Creates a quaternion from an axis and an angle.
     * 
     * @param {Vector} axis - The axis of rotation (normalized vector).
     * @param {number} angle - The angle of rotation in radians.
     * @returns {Quaternion} - The quaternion.
    */
    function fromAxisAngle(axis, angle) {
        local halfAngle = angle * 0.5;
        local sinHalfAngle = sin(halfAngle);
        return math.Quaternion(axis.x * sinHalfAngle, axis.y * sinHalfAngle, axis.z * sinHalfAngle, cos(halfAngle));
    }

    /*
     * Converts the quaternion to an axis and an angle.
     * 
     * @returns {table} - A table with keys "axis" (Vector) and "angle" (number).
    */
    function toAxisAngle() {
        local scale = sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
        if (scale < 0.001) {
            return { axis = Vector(1, 0, 0), angle = 0 };
        }
        return { 
            axis = Vector(this.x / scale, this.y / scale, this.z / scale), 
            angle = 2 * acos(this.w) 
        };
    }


    /*
     * Converts the quaternion to a vector representing Euler angles.
     *
     * @returns {Vector} - The vector representing Euler angles in degrees.
    */
    function toVector() {
        local sinr_cosp = 2 * (this.w * this.x + this.y * this.z);
        local cosr_cosp = 1 - 2 * (this.x * this.x + this.y * this.y);
        local roll = atan2(sinr_cosp, cosr_cosp);

        local sinp = 2 * (this.w * this.y - this.z * this.x);
        local pitch;
        if (abs(sinp) >= 1) {
            pitch = math.copysign(PI / 2, sinp); // PI/2 or -PI/2
        } else {
            pitch = asin(sinp);
        }

        local siny_cosp = 2 * (this.w * this.z + this.x * this.y);
        local cosy_cosp = 1 - 2 * (this.y * this.y + this.z * this.z);
        local yaw = atan2(siny_cosp, cosy_cosp);

        // Convert angles to degrees
        local x = pitch * 180 / PI;
        local y = yaw * 180 / PI;
        local z = roll * 180 / PI;

        return Vector( x, y, z )
    }

    /* 
     * Checks if two quaternions are equal based on their components and length.
     *
     * @param {Quaternion} other - The other quaternion to compare.
     * @returns {boolean} - True if the quaternions are equal, false otherwise.
    */
    function IsEqual(other) {
        return this.cmp(other) == 0
    }

    /*
     * Compares two quaternions based on their magnitudes.
     *
     * @param {Quaternion} other - The other quaternion to compare.
     * @returns {number} - 1 if this quaternion's magnitude is greater, -1 if less, 0 if equal.
    */
    function cmp(other) {
        if (typeof other != "Quaternion") {
            throw "Cannot compare quaternion with non-quaternion type";
        }
    
        local thisMagnitude = math.round(this.length(), 10000);
        local otherMagnitude = math.round(other.length(), 10000);

        if (thisMagnitude > otherMagnitude) {
            return 1;
        } else if (thisMagnitude < otherMagnitude) {
            return -1;
        } else {
            return 0; 
        }
    }

    function _cmp(other) return this.cmp(other)


    function _add(other) {
        return math.Quaternion(
            this.x + other.x,
            this.y + other.y,
            this.z + other.z,
            this.w + other.w
        )
    }


    function _sub(other) {
        return math.Quaternion(
            this.x - other.x,
            this.y - other.y,
            this.z - other.z,
            this.w - other.w
        )
    }
    
    /*
     * Multiplies two quaternions.
     *
     * @param {Quaternion} other - The other quaternion.
     * @returns {Quaternion} - The multiplication result.
    */
    function _mul(other) {
        if(typeof other == "Quaternion") {
            return math.Quaternion(
                this.w * other.x + this.x * other.w + this.y * other.z - this.z * other.y,
                this.w * other.y - this.x * other.z + this.y * other.w + this.z * other.x,
                this.w * other.z + this.x * other.y - this.y * other.x + this.z * other.w,
                this.w * other.w - this.x * other.x - this.y * other.y - this.z * other.z
            )
        }

        return math.Quaternion( 
            this.x * other,
            this.y * other,
            this.z * other,
            this.w * other
        )
    }

    function _tostring() {
        return "Quaternion: (" + x + ", " + y + ", " + z + ", " + w + ")"
    }

    function _typeof() {
        return "Quaternion"
    }
}
math["Matrix"] <- class {
    a = 1; b = 0; c = 0;
    d = 0; e = 1; f = 0;
    g = 0; h = 0; k = 1;

    /*
     * Creates a new matrix.
     * 
     * @param {number} a - The value at row 1, column 1.
     * @param {number} b - The value at row 1, column 2.
     * @param {number} c - The value at row 1, column 3.
     * @param {number} d - The value at row 2, column 1.
     * @param {number} e - The value at row 2, column 2.
     * @param {number} f - The value at row 2, column 3.
     * @param {number} g - The value at row 3, column 1.
     * @param {number} h - The value at row 3, column 2.
     * @param {number} k - The value at row 3, column 3.
    */
    constructor(a = 1, b = 0, c = 0,
                d = 0, e = 1, f = 0,
                g = 0, h = 0, k = 1
        ) {
            this.a = a; this.b = b; this.c = c;
            this.d = d; this.e = e; this.f = f;
            this.g = g; this.h = h; this.k = k;
        }
    /*
     * Creates a rotation matrix from Euler angles.
     * 
     * @param {Vector} angles - Euler angles in degrees (pitch, yaw, roll).
     * @returns {Matrix} - The rotation matrix.
    */
    function fromEuler(angles) {
        local sinX = sin(-angles.z / 180 * PI);
        local cosX = cos(-angles.z / 180 * PI);
        local sinY = sin(-angles.x / 180 * PI);
        local cosY = cos(-angles.x / 180 * PI);
        local sinZ = sin(-angles.y / 180 * PI);
        local cosZ = cos(-angles.y / 180 * PI);
        return math.Matrix(
            cosY * cosZ, -sinX * -sinY * cosZ + cosX * sinZ, cosX * -sinY * cosZ + sinX * sinZ,
            cosY * -sinZ, -sinX * -sinY * -sinZ + cosX * cosZ, cosX * -sinY * -sinZ + sinX * cosZ,
            sinY, -sinX * cosY, cosX * cosY
        );
    }

    /*
     * Rotates a point using the matrix.
     * 
     * @param {Vector} point - The point to rotate.
     * @returns {Vector} - The rotated point.
    */
    function rotateVector(point) {
        return Vector(
            point.x * this.a + point.y * this.b + point.z * this.c,
            point.x * this.d + point.y * this.e + point.z * this.f,
            point.x * this.g + point.y * this.h + point.z * this.k
        );
    }

    /*
     * Unrotates a point using the matrix.
     * 
     * @param {Vector} point - The point to unrotate.
     * @returns {Vector} - The unrotated point.
    */
    function unrotateVector(point) {
        return Vector(
            point.x * this.a + point.y * this.d + point.z * this.g,
            point.x * this.b + point.y * this.e + point.z * this.h,
            point.x * this.c + point.y * this.f + point.z * this.k
        );
    }

    /*
     * Transposes the matrix.
     * 
     * @returns {Matrix} - The transposed matrix.
    */
    function transpose() {
        return math.Matrix(
            this.a, this.d, this.g,
            this.b, this.e, this.h,
            this.c, this.f, this.k
        );
    }

    /*
     * Calculates the inverse of the matrix.
     * 
     * @returns {Matrix} - The inverse matrix.
     * @throws {Error} - If the matrix is singular (determinant is zero).
    */
    function inverse() {
        local det = this.determinant();
        if (det == 0) {
            throw "Matrix is singular (determinant is zero)"
        }
        local invDet = 1 / det;
        return math.Matrix(
            (this.e * this.k - this.f * this.h) * invDet,
            (this.c * this.h - this.b * this.k) * invDet,
            (this.b * this.f - this.c * this.e) * invDet,
            (this.f * this.g - this.d * this.k) * invDet,
            (this.a * this.k - this.c * this.g) * invDet,
            (this.c * this.d - this.a * this.f) * invDet,
            (this.d * this.h - this.e * this.g) * invDet,
            (this.b * this.g - this.a * this.h) * invDet,
            (this.a * this.e - this.b * this.d) * invDet
        );
    }

    /*
     * Calculates the determinant of the matrix.
     * 
     * @returns {number} - The determinant of the matrix.
    */
    function determinant() {
        return this.a * (this.e * this.k - this.f * this.h) -
               this.b * (this.d * this.k - this.f * this.g) +
               this.c * (this.d * this.h - this.e * this.g);
    }

    /*
     * Scales the matrix by a given factor.
     * 
     * @param {number} factor - The scaling factor.
     * @returns {Matrix} - The scaled matrix.
    */
    function scale(factor) {
        return math.Matrix(
            this.a * factor, this.b * factor, this.c * factor,
            this.d * factor, this.e * factor, this.f * factor,
            this.g * factor, this.h * factor, this.k * factor
        );
    }

    /*
     * Rotates the matrix around the X axis by a given angle.
     * 
     * @param {number} angle - The angle of rotation in radians.
     * @returns {Matrix} - The rotated matrix.
    */
    function rotateX(angle) {
        local sinAngle = sin(angle);
        local cosAngle = cos(angle);
        return math.Matrix(
            1, 0, 0,
            0, cosAngle, -sinAngle,
            0, sinAngle, cosAngle
        ) * this;
    }

    /*
     * Multiplies two matrices.
     * 
     * @param {Matrix} other - The other matrix.
     * @returns {Matrix} - The result of the multiplication.
    */
    function _mul(other) {
        return math.Matrix(
            this.a * other.a + this.b * other.d + this.c * other.g,
            this.a * other.b + this.b * other.e + this.c * other.h,
            this.a * other.c + this.b * other.f + this.c * other.k,
            this.d * other.a + this.e * other.d + this.f * other.g,
            this.d * other.b + this.e * other.e + this.f * other.h,
            this.d * other.c + this.e * other.f + this.f * other.k,
            this.g * other.a + this.h * other.d + this.k * other.g,
            this.g * other.b + this.h * other.e + this.k * other.h,
            this.g * other.c + this.h * other.f + this.k * other.k
        );
    }

    /*
     * Adds two matrices.
     * 
     * @param {Matrix} other - The other matrix.
     * @returns {Matrix} - The result of the addition.
    */
    function _add(other) {
        return math.Matrix(
            this.a + other.a, this.b + other.b, this.c + other.c,
            this.d + other.d, this.e + other.e, this.f + other.f,
            this.g + other.g, this.h + other.h, this.k + other.k
        );
    }

    /*
     * Subtracts two matrices.
     * 
     * @param {Matrix} other - The other matrix.
     * @returns {Matrix} - The result of the subtraction.
    */
    function _sub(other) {
        return math.Matrix(
            this.a - other.a, this.b - other.b, this.c - other.c,
            this.d - other.d, this.e - other.e, this.f - other.f,
            this.g - other.g, this.h - other.h, this.k - other.k
        );
    }

    /*
     * Checks if two matrices are equal based on their components and sum.
     *
     * @param {Matrix} other - The other matrix to compare.
     * @returns {boolean} - True if the matrices are equal, false otherwise.
    */
    function IsEqual(other) {
        return this.cmp(other) == 0
    }

    /*
     * Compares two matrices based on the sum of their components.
     *
     * @param {Matrix} other - The other matrix to compare.
     * @returns {number} - 1 if this matrix's sum is greater, -1 if less, 0 if equal.
    */
    function cmp(other) {
        if (typeof other != "Matrix") {
            throw "Cannot compare matrix with non-matrix type";
        }
    
        local thisSum = a + b - c + d + e + f - g + h - k;
        local otherSum = other.a + other.b - other.c + other.d + other.e + other.f - other.g + other.h - other.k;
        
        if (thisSum > otherSum) {
            return 1;
        } else if (thisSum < otherSum) {
            return -1;
        } else {
            return 0;
        }
    }

    function _cmp(other) return this.cmp(other)

    function _tostring() {
        return "Matrix: {" + a + ", " + b + ", " + c + "\n\t " + d + ", " + e + ", " + f + "\n\t " + g + ", " + h + ", " + k + "}"
    }

    function _typeof() {
        return "Matrix"
    }
}

/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Event Orchestrator - laVashik ・人・                                          |
+----------------------------------------------------------------------------------+
|   The Events module, offering an advanced event scheduling and management system | 
|   for creating complex, timed events with precision and control.                 |
+----------------------------------------------------------------------------------+ */ 


::ScheduleEvent <- {
    // Object to store scheduled events 
    eventsList = {global = List()},
    
    Add = null,
    AddActions = null,
    AddInterval = null,

    Cancel = null,
    CancelAll = null,
    
    GetEvent = null,
    
    IsValid = null,
}

/*
 * Represents a scheduled action.
 *
 * This class encapsulates information about an action that is scheduled to be executed at a specific time.
*/
::ScheduleAction <- class {
    // The entity that created the event. 
    scope = null;
    // The action to execute when the scheduled time arrives.  
    action = null;
    // The time at which the action is scheduled to be executed. 
    executionTime = null;
    // Optional arguments to pass to the action function.  
    args = null;

    /*
     * Constructor for a ScheduleAction object.
     *
     * @param {pcapEntity} scope - The entity that created the event.
     * @param {string|function} action - The action to execute when the event is triggered.
     * @param {number} delay - The time at which the event is scheduled to be executed.
     * @param {array|null} args - Optional arguments to pass to the action function. 
    */
    constructor(scope, action, delay, args = null) {
        this.scope = scope
        this.action = action
        this.executionTime = delay + Time()

        if(args != null && typeof args != "array") throw("arguments must be an array, but got " + typeof args)
        this.args = args
    }

    /* 
     * Executes the scheduled action. 
     *
     * If the action is a string, it is compiled into a function before execution.
     * If arguments are provided, they are passed to the action function. 
     *
     * @returns {any} - The result of the action function. 
    */
    function run() {
        if(type(this.action) == "string")
            this.action = compilestring(action)

        if(this.args == null) {
            return this.action.call(scope)
        }
        
        local actionArgs = [this.scope]
        actionArgs.extend(this.args)
        return this.action.acall(actionArgs)
    }

    /*
     * Processes a generator action.
     * 
     * @param {Generator} generator - The generator to be processed.
     * @returns {any} - The result of processing the generator.
    */
    function processGenerator(generator, eventName) {
        if(generator.getstatus() == "dead") return
        local delay = resume generator
        if(delay == null) return
        
        try {delay = delay.tofloat()} 
        catch(err) {throw "Invalid value for sleep. " + err}
        if (delay <= 0.0) delay = FrameTime()
        
        if(eventName in ScheduleEvent.eventsList) {
            ScheduleEvent.Add(eventName, generator, delay, null, this.scope)
        } else {
            dev.warning("Generator pause will not take effect as the event '{}' no longer exists in the schedule.", eventName)
        }
    }

    function GetInfo() return "[Scope] " + scope + "\n[Action] " + this.action + "\n[executionTime] " + executionTime
    function _typeof() return "ScheduleAction"
    function _tostring() return "ScheduleAction: (" + this.executionTime + ")"
    function _cmp(other) {    
        if (this.executionTime > other.executionTime) return 1;
        else if (this.executionTime < other.executionTime) return -1;
        return 0; 
    }
}
/*
 * Adds a single action to a scheduled event with the specified name.
 *
 * @param {string|any} eventName - The name of the event to add the action to. If the event does not exist, it is created.
 * @param {string|function} action - The action to execute when the scheduled time arrives. This can be a string containing VScripts code or a function object.
 * @param {number} timeDelay - The delay in seconds before executing the action.
 * @param {array|null} args - An optional array of arguments to pass to the action function.
 * @param {object} scope - The scope in which to execute the action (default is `this`). 
*/
ScheduleEvent["Add"] <- function(eventName, action, timeDelay, args = null, scope = this) {
    if (typeof action != "string" && typeof action != "function" && typeof action != "native function" && typeof action != "generator") throw("ScheduleEvent.Add: 'action' must be a function or a string, but got " + typeof action);
    if (typeof timeDelay != "integer" && typeof timeDelay != "float") throw("ScheduleEvent.Add: 'timeDelay' must be a number, but got " + typeof timeDelay);
    local argsType = typeof args;
    if(args && argsType != "array" && argsType != "ArrayEx" && argsType != "List") throw("ScheduleEvent.Add: 'args' must be an array, List, or null, but got " + typeof args)

    if ( !(eventName in ScheduleEvent.eventsList) ) {
        ScheduleEvent.eventsList[eventName] <- List()
        dev.trace("Created new Event - \"{}\"", eventName)
    }

    local newScheduledEvent = ScheduleAction(scope, action, timeDelay, args)
    local currentActionList = ScheduleEvent.eventsList[eventName]


    if(currentActionList.len() == 0 || currentActionList.top() <= newScheduledEvent) {
        currentActionList.append(newScheduledEvent)
        return
    } 
    
    //* --- A binary search.
    local low = 0
    local high = currentActionList.len() - 1
    local mid

    local tempActionArr = currentActionList.toarray()
    while (low <= high) {
        mid = (low + high) / 2
        if (tempActionArr[mid] < newScheduledEvent) {
            low = mid + 1
        }
        else if (tempActionArr[mid] > newScheduledEvent) {
            high = mid - 1
        }
        else {
            low = mid
            break
        }
    }
    
    currentActionList.insert(low, newScheduledEvent)
}

/*
 * Adds an action to a scheduled event that will be executed repeatedly at a fixed interval. 
 *
 * @param {string|any} eventName - The name of the event to add the interval to. If the event does not exist, it is created.
 * @param {string|function} action - The action to execute at each interval.
 * @param {number} interval - The time interval in seconds between executions of the action.
 * @param {number} initialDelay - The initial delay in seconds before the first execution of the action (default is 0). 
 * @param {array|null} args - An optional array of arguments to pass to the action function. 
 * @param {object} scope - The scope in which to execute the action (default is `this`). 
*/ 
ScheduleEvent["AddInterval"] <- function(eventName, action, interval, initialDelay = 0, args = null, scope = this) {
    if (typeof action != "string" && typeof action != "function" && typeof action != "native function" && typeof action != "generator") throw("ScheduleEvent.AddInterval: 'action' must be a function or a string, but got " + typeof action);
    if (typeof interval != "integer" && typeof interval != "float") throw("ScheduleEvent.AddInterval: 'interval' must be a number, but got " + typeof interval);
    if (interval <= 0) throw("ScheduleEvent.AddInterval: 'interval' must be a positive number, but got " + interval);
    if (typeof initialDelay != "integer" && typeof initialDelay != "float") throw("ScheduleEvent.AddInterval: 'initialDelay' must be a number, but got " + typeof initialDelay);
    local argsType = typeof args;
    if(args && argsType != "array" && argsType != "ArrayEx" && argsType != "List") throw("ScheduleEvent.AddInterval: 'args' must be an array, List, or null, but got " + typeof args)


    ScheduleEvent.Add(eventName, action, initialDelay, args, scope)
    ScheduleEvent.Add(eventName, ScheduleEvent.AddInterval, initialDelay + interval, [eventName, action, interval, 0, args, scope], scope)
}

/*
 * Adds multiple actions to a scheduled event, ensuring they are sorted by execution time.
 *
 * @param {string|any} eventName - The name of the event to add the actions to. If the event does not exist, it is created.
 * @param {array|List} actions - An array or List of `ScheduleAction` objects to add to the event.
 * @param {boolean} noSort - If true, the actions will not be sorted by execution time (default is false).
 * 
 * **Caution:** Use the `noSort` parameter with care. Incorrect usage may lead to unexpected behavior or break the event scheduling logic. 
*/ 
ScheduleEvent["AddActions"] <- function(eventName, actions, noSort = false) { 
    local actionsType = typeof actions;
    if (actionsType != "array" && actionsType != "List" && actionsType != "ArrayEx") throw("ScheduleEvent.AddActions: 'actions' must be an array or a List, but got " + actionsType);
    if (actions.len() > 0) {
        if (typeof actions[0] != "ScheduleAction") {
            dev.warning("ScheduleEvent.AddActions: The 'actions' container does not appear to hold ScheduleAction objects. This might cause errors.");
        }
    }

    if(eventName in ScheduleEvent.eventsList) {
        ScheduleEvent.eventsList[eventName].extend(actions)
        ScheduleEvent.eventsList[eventName].sort()
        if(developer() > 0) dev.trace("Added {} actions to Event \"{}\".", actions.len(), eventName)
        return 
    } 

    if(!noSort) actions.sort()

    if(typeof actions == "List") {
        ScheduleEvent.eventsList[eventName] <- actions
    } else {
        ScheduleEvent.eventsList[eventName] <- List.FromArray(actions)
    }

    if(developer() > 0) dev.trace("Created new Event \"{}\" with {} actions.", eventName, actions.len())
}


/*
 * Cancels a scheduled event with the given name, optionally after a delay.
 *
 * @param {string|any} eventName - The name of the event to cancel.
 * @param {number} delay - An optional delay in seconds before canceling the event.
*/  
ScheduleEvent["Cancel"] <- function(eventName, delay = 0) {
    if(eventName == "global")
        throw("The global event cannot be closed!")
    if(!(eventName in ScheduleEvent.eventsList))
        throw("There is no event named " + eventName)
    if(delay > 0)
        return ScheduleEvent.Add("global", format("ScheduleEvent.Cancel(\"%s\")", eventName), delay)
    
    ScheduleEvent.eventsList.rawdelete(eventName)
        
    if(developer() > 0) dev.trace("Event \"{}\" closed! Actial events: {}", eventName, macros.GetKeys(ScheduleEvent.eventsList))
}

/*
 * Attempts to cancel a scheduled event with the given name, optionally after a delay.
 *
 * @param {string|any} eventName - The name of the event to cancel.
 * @param {number} delay - An optional delay in seconds before attempting to cancel the event.
 * @returns {boolean} - True if the event was found and canceled, false otherwise.
 * 
 * This function is similar to `ScheduleEvent.Cancel`, but it does not throw an error if the event is not found.
 * It's useful for situations where you're unsure if an event exists and want to attempt cancellation without risking errors.
*/
ScheduleEvent["TryCancel"] <- function(eventName, delay = 0) {
    if(delay > 0) 
        return ScheduleEvent.Add("global", ScheduleEvent.TryCancel, delay, [eventName])
    local isValid = ScheduleEvent.IsValid(eventName) 
    if(isValid) ScheduleEvent.Cancel(eventName)
    return isValid
}

/*
* Cancels all scheduled events and actions, effectively clearing the event scheduler.
*/
ScheduleEvent["CancelAll"] <- function() {
    ScheduleEvent.eventsList = {global = ScheduleEvent.eventsList["global"]}
    dev.trace("Scheduled events have been canceled!")
}

/* 
* Cancels all scheduled events and actions, EVEN GLOBAL!! effectively clearing the event scheduler.
* Undocumented unsafe function. You must understand what you are doing!
*/
ScheduleEvent["UNSAFE_ClearWithGlobal"] <- function() {
    ScheduleEvent.eventsList = {global = List()}
    dev.trace("All scheduled events have been canceled!")
}


/*
 * Gets info about a scheduled event.
 * 
 * @param {string|any} eventName - Name of event to get info for.
 * @returns {List|null} - The event info object or null if not found.
*/
ScheduleEvent["GetEvent"] <- function(eventName) {
    return eventName in ScheduleEvent.eventsList ? ScheduleEvent.eventsList[eventName] : null
}


/*
 * Checks if event is valid
 * 
 * @param {string|any} eventName - Name of event to get info for.
 * @returns {bool} - Object exists or not.
*/
ScheduleEvent["IsValid"] <- function(eventName) {
    return eventName in ScheduleEvent.eventsList
}
/*
 * Executes scheduled events when their time is up. 
 * 
 * This function iterates over all scheduled events and checks if their scheduled execution time has arrived. 
 * If so, it executes the event's action and removes it from the list of scheduled events. 
 * The function then schedules itself to run again after a short delay to continue processing events.
*/
::ScheduledEventLoop <- function() {
    local time = Time() + 0.0001
    local eventsToDelete = List() // Buffer for safe deletion

    // Iterate over each event name and its corresponding event list. 
    foreach(eventName, eventInfo in ScheduleEvent.eventsList) {
        local event 
        // Process events until the list is empty or the next event's time hasn't arrived yet.  
        while(eventInfo.length > 0 && time >= (event = eventInfo.first()).executionTime) {
            eventInfo.remove(0)
            try {
                local gtor = event.action
                if(typeof event.action == "generator" || typeof (gtor = event.run()) == "generator") {
                    event.processGenerator(gtor, eventName)
                }
            }
            catch(exception) {
                // ScheduleEvent unwinding
                macros.fprint("\nSCHEDULED EVENT\n[Name] {}\n{}\n[Exception] {}\n[Event Action List] {}\n[Time] {}", eventName, event.GetInfo(), exception, ScheduleEvent.eventsList[eventName], time)

                if(typeof event.action == "function" || typeof event.action == "native function") {
                    printl("\nFUNCTION INFO")
                    foreach(key, val in event.action.getinfos()) {
                        if(type(val) == "array") val = ArrayEx.FromArray(val)
                        macros.fprint("[{}] {}", key.toupper(), val)
                    }
                }

                printl("-------------------------------------------------\n");
                SendToConsole("playvol resource/warning.wav 1")
            }
        }
        
        if(eventName != "global" && eventInfo.length == 0) {
            eventsToDelete.append(eventName) 
        }
    }

    // Safely delete events after completion of the main loop.
    foreach (eventName in eventsToDelete.iter()) {
        if (eventName in ScheduleEvent.eventsList) {
            ScheduleEvent.eventsList.rawdelete(eventName)
            if(developer() > 0) dev.trace("Event {} closed.", eventName)
        }
    }
}

// Create a logic_timer to process the event loop.
if(!Entities.FindByName(null, "@ScheduledEventLoop")) {
    local timer = entLib.CreateByClassname("logic_timer", {RefireTime=0.001, targetname="@ScheduledEventLoop"})
    timer.ConnectOutput("OnTimer", "ScheduledEventLoop")
    EntFire("@ScheduledEventLoop", "Enable")
}
/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Squirrel Whisperer - laVashik :>                                             |
+----------------------------------------------------------------------------------+
|       A toolbox of versatile utilities for script execution, debugging, file     |
|       operations, and entity manipulation, empowering VScripts developers.       | 
+----------------------------------------------------------------------------------+ */ 

::LoggerLevels <- class {
    Trace = 1
    Debug = 5
    Info = 10
    Warning = 30
    Error = 60
    Off = 1000
}


/*
 * A collection of debugging utilities. 
*/
::dev <- {
    /*
     * Draws the bounding box of an entity for the specified time.
     * 
     * @param {CBaseEntity|pcapEntity} ent - The entity to draw the bounding box for.
     * @param {Vector} color - The color of the box.
     * @param {number} time - The duration of the display in seconds. 
    */
    DrawEntityBBox = function(ent, color, time) {
        if (developer() == 0) return
        DebugDrawBox(ent.GetOrigin(), ent.GetBoundingMins(), ent.GetBoundingMaxs(), color.x, color.y, color.z, 9, time)
    },

    /*
     * Draws the AABB of an entity for the specified time.
     * 
     * @param {CBaseEntity|pcapEntity} ent - The entity to draw the bounding box for.
     * @param {Vector} color - The color of the box.
     * @param {number} time - The duration of the display in seconds. 
    */
    DrawEntityAABB = function(ent, color, time) {
        if (developer() == 0) return
        DebugDrawBox(ent.GetOrigin(), ent.CreateAABB(0), ent.CreateAABB(7), color.x, color.y, color.z, 9, time)
    },

    /*
     * Draws a box at the specified vector position for the specified time.
     * 
     * @param {Vector} vector - The position of the box.
     * @param {Vector} color - The color of the box. (optional)
     * @param {number} time - The duration of the display in seconds. (optional)
    */
    drawbox = function(vector, color = Vector(125, 125, 125), time = 0.05) {
        if (developer() == 0) return
        DebugDrawBox(vector, Vector(-1,-1,-1), Vector(1,1,1), color.x, color.y, color.z, 100, time)
    },

    // only for PCapture-LIB debugging
    trace = function(msg, ...) {
        if (developer() == 0 || LibLogger > LoggerLevels.Trace) return
        // region - repeatable code, thanks to Squirrel
        local args = array(vargc + 2)
        args[0] = this
        args[1] = msg

        for(local i = 0; i< vargc; i++) {
            args[i + 2] = vargv[i]
        }
        // endregion

        local msg = macros.format.acall(args)
        printl("-- PCapture-Lib [" + Time().tostring() + "]: " + msg)
    },

    /*
     * Logs a debug message to the console if debug logging is enabled. 
     *
     * @param {string} msg - The debug message string containing `{}` placeholders. 
    */ 
    debug = function(msg, ...) {
        if (developer() == 0 || LibLogger > LoggerLevels.Debug) return
        // region - repeatable code, thanks to Squirrel
        local args = array(vargc + 2)
        args[0] = this
        args[1] = msg

        for(local i = 0; i< vargc; i++) {
            args[i + 2] = vargv[i]
        }
        // endregion

        local msg = macros.format.acall(args)
        printl("[VScripts Debug (" + Time().tostring() + ")]: " + msg)
    },


    /*
     * Logs a info message to the console only if developer mode is enabled.
     * 
     * @param {string} msg - The message to log string containing `{}` placeholders.
    */
    info = function(msg, ...) {
        if (developer() == 0 || LibLogger > LoggerLevels.Info) return
        // region - repeatable code, thanks to Squirrel
        local args = array(vargc + 2)
        args[0] = this
        args[1] = msg

        for(local i = 0; i< vargc; i++) {
            args[i + 2] = vargv[i]
        }
        // endregion

        local msg = macros.format.acall(args)
        printl("• " + msg)
    },

    /*
     * Displays a warning message in a specific format.
     * 
     * @param {string} msg - The warning message string containing `{}` placeholders. 
    */
    warning = function(msg, ...) {
        if (developer() == 0 || LibLogger > LoggerLevels.Warning) return
        local pattern = "► Warning ({} [{}]): " + msg
        // region - repeatable code, thanks to Squirrel
        local info = dev._getInfo()
        local args = array(vargc + 4)
        args[0] = this
        args[1] = pattern // pattern
        args[2] = info[0] // func name
        args[3] = info[1] // func line

        for(local i = 0; i< vargc; i++) {
            args[i + 4] = vargv[i]
        }
        // endregion
        printl(macros.format.acall(args))
    },

    /* 
     * Displays an error message in a specific format.
     * 
     * @param {string} msg - The error message string containing `{}` placeholders.
    */
    error = function(msg, ...) {
        if (developer() == 0 || LibLogger > LoggerLevels.Error) return
        local pattern = "▄▀ *ERROR*: [func = {}; line = {}] | " + msg
        // region - repeatable code, thanks to Squirrel
        local info = dev._getInfo()
        local args = array(vargc + 4)
        args[0] = this
        args[1] = pattern // pattern
        args[2] = info[0] // func name
        args[3] = info[1] // func line

        for(local i = 0; i< vargc; i++) {
            args[i + 4] = vargv[i]
        }
        // endregion
        printl(macros.format.acall(args))
        SendToConsole("playvol resource/warning.wav 1")
    },

    _getInfo = function() {
        local last_info
        for(local i = 0; getstackinfos(i); i++)
            last_info = i 
        local info = getstackinfos(last_info)
        
        local funcName = getstackinfos(last_info).func
        if (funcName == "main" || funcName == "unknown")
            funcName = "file " + info.src
            
        local line = info.line
        return [funcName, line]
    }
}
/*
 * Represents a file for reading and writing.
*/
::File <- class {
    // The path to the file.  
    path = null;
    // The name of the file without the extension. 
    name = null;

    /*
     * Constructor for a File object.
     *
     * @param {string} path - The path to the file.
    */
    constructor(path) {
        path = split(path, "/").top()
        this.name = split(path, "/").top()

        if(path.find(".log") == null) {
            path += ".log"
        } else {
            this.name = this.name.slice(0, -4)
        }
        
        this.path = path
        if(!(this.name in getroottable()))
            getroottable()[this.name] <- []
    }

    /*
     * Appends text to the file.
     *
     * @param {string} text - The text to append. 
    */
    function write(text) {
        local cmd = "script " + name + ".append(\\\"" + text + "\\\");"
        this._write(cmd)
    }

    function writeRawData(text) {
        this._write(text)
    }

    /*
     * Writes a command to the console to manipulate the file.
     *
     * @param {string} command - The command to execute. 
    */
    function _write(command) {
        SendToConsole("con_logfile cfg/" + this.path)
        SendToConsole("script printl(\"" + command + "\")")
        SendToConsole("con_logfile off")
    }

    /* 
     * Reads the lines of the file and returns them as an array.
     *
     * @returns {array} - An array of strings, where each string is a line from the file. 
    */
    function readlines() {
        if(this.name in getroottable()) 
            return getroottable()[this.name]
        return []
    }

    /* 
     * Reads the entire contents of the file and returns it as a string.
     * 
     * @returns {string} - The contents of the file as a string. 
    */
    function read() {
        local result = ""
        foreach(line in this.readlines()){
            result += line + "\n"
        }
        return result
    }

    /*
     * Clears the contents of the file. 
    */
    function clear() {
        this._write("script " + name + ".clear()")
    }

    /*
     * Updates information about the file by executing it. 
    */
    function updateInfo() {
        getroottable()[this.name].clear()
        SendToConsole("exec " + path)
    }
}
if("GetPlayerEx" in getroottable()) {
    return
}

/*
* Limits frametime to avoid zero values.
*
* @returns {number} Clamped frametime
*/
::_frametime <- FrameTime
/*
 * Returns the current frame time, ensuring it is never zero. 
 * 
 * This function overrides the standard FrameTime function to prevent issues that can arise from zero frame times. 
 * If the frame time is zero, it returns a small default value (0.016). 
 *
 * @returns {number} - The current frame time. 
*/
::FrameTime <- function() {
    local tick = _frametime()
    if(tick == 0)
        return 0.016
    return tick
}

::_uniquestring <- UniqueString
/*
 * Generates a unique string with the specified prefix. 
 * 
 * This function overrides the standard UniqueString function to include a prefix in the generated string. 
 *
 * @param {string} prefix - The prefix to use for the unique string. (optional, default="u") 
 * @returns {string} - The generated unique string. 
*/ 
::UniqueString <- function(prefix = "u") {
    return prefix + "_" + _uniquestring().slice(0, -1)
}

::_EntFireByHandle <- EntFireByHandle
/*
 * Wrapper for EntFireByHandle to handle PCapLib objects.
 *
 * This function overrides the standard EntFireByHandle function to handle pcapEntity objects and extract the underlying CBaseEntity objects. 
 * It also allows specifying an activator and caller entity. 
 *
 * @param {CBaseEntity|pcapEntity} target - The target entity to trigger the input on. 
 * @param {string} action - The name of the input to trigger. 
 * @param {string} value - The value to pass to the input. (optional)
 * @param {number} delay - The delay in seconds before triggering the input. (optional)
 * @param {CBaseEntity|pcapEntity} activator - The activator entity (the entity that triggered the input). (optional)
 * @param {CBaseEntity|pcapEntity} caller - The caller entity (the entity that called the function). (optional) 
*/
::EntFireByHandle <- function(target, action, value = "", delay = 0, activator = null, caller = null, eventName = null) {
    // Extract the underlying entity from the pcapEntity wrapper 
    if (typeof target == "pcapEntity") 
        target = target.CBaseEntity
    if (typeof activator == "pcapEntity")
        activator = activator.CBaseEntity
    if (typeof caller == "pcapEntity")
        caller = target.CBaseEntity

    if(!eventName) 
        return _EntFireByHandle(target, action, value, delay, activator, caller)
    ScheduleEvent.Add(eventName, _EntFireByHandle, delay, [target, action, value, 0, activator, caller])
}

/*
* Retrieves a player entity with extended functionality.
*
* @param {int} index - The index of the player (0-based).
* @returns {pcapEntity} - An extended player entity with additional methods.
*/
::GetPlayerEx <- function(index = 0) {
    if(!IsMultiplayer()) 
        return entLib.FromEntity(GetPlayer())

    if(index >= AllPlayers.len()) return null
    return AllPlayers[index]
}
::InitedPortals <- {}

/*
 * Creates a `func_portal_detector` entity with specified key-value pairs and settings for portal detection.
 * 
 * This function is not part of the public API.
*/
::_CreatePortalDetector <- function(extraKey, extraValue) {
    local detector = entLib.CreateByClassname("func_portal_detector", {solid = 0, CollisionGroup = 10})
    detector.SetKeyValue(extraKey, extraValue)
    detector.SetBBox(Vector(32000, 32000, 32000) * -1, Vector(32000, 32000, 32000))
    detector.SetTraceIgnore(true)
    EntFireByHandle(detector, "Enable")
    
    return detector
}

/*
 * Initializes a portal pair for portal casting (tracing lines through portals). 
 * 
 * This function creates a detector entity with a specific `LinkageGroupID` and connects its `OnStartTouchPortal`
 *  to a script function that sets the activator entity's health to the portal's `LinkageGroupID`. 
 * This allows for identifying the paired portal during portal traces. 
 * 
 * @param {number} id - The ID of the portal pair.
*/
::InitPortalPair <- function(id) {
    // If it was previously initialized, just turn on the detector.
    if(id in InitedPortals) return InitedPortals[id]

    local detector = _CreatePortalDetector("LinkageGroupID", id)

    // The "free variables" syntax is different in Sq2 and Sq3, which is why I try to avoid executing it
    detector.ConnectOutputEx("OnStartTouchPortal", compilestring("activator.SetHealth(" + id + ")"))
    detector.ConnectOutputEx("OnEndTouchPortal", compilestring("activator.SetHealth(9999)"))
    // Marking the portal as initialized
    InitedPortals[id] <- detector
    
    return detector
}

/*
 * Initializes linked portal doors for portal tracing.
 * This function is not part of the public API.
 * 
 * This function iterates through all entities of class "linked_portal_door" and performs the following actions:
 * 1. Check if this entity has been processed before. 
 * 2. Extracts bounding box dimensions from the portal's model name (assuming a specific naming convention).
 * 3. Rotates the bounding box dimensions based on the portal's angles. 
 * 4. Sets the bounding box of the portal using the calculated dimensions. 
 * 
 * This function is called automatically at the initialization.
*/
::SetupLinkedPortals <- function() {
    local portalStateHandler = function(state) {
        local p = entLib.FromEntity(self)
        p.SetTraceIgnore(state)
        local p2 = p.GetPartnerInstance()
        if(p2) p2.SetTraceIgnore(state) 
        return true
    }
    // Iterate through all linked_portal_door entities.  
    for(local portal; portal = entLib.FindByClassname("linked_portal_door", portal);) {
        // Skip if the portal already processed
        if(portal.GetUserData("processed"))
            continue
    
        portal.SetInputHook("Open", function():(portalStateHandler) {return portalStateHandler(false)})
        portal.SetInputHook("Close", function():(portalStateHandler) {return portalStateHandler(true)})

        local partner = portal.GetPartnerInstance()
    
        // Skip if the portal model name is empty (no bounding box information available).  
        if(portal.GetModelName() == "") 
            continue
        
        // Extract bounding box dimensions from the model name (assuming a specific format). 
        local wpInfo = split(portal.GetModelName(), " ")
        // Rotate the bounding box dimensions based on the portal's angles.  
        local wpBBox = math.vector.abs(Vector(8, wpInfo[0].tointeger(), wpInfo[1].tointeger()))
        // Set the bounding box of the portal using the calculated dimensions.  
        portal.SetBBox(wpBBox * -1, wpBBox)
        portal.SetUserData("processed", true)
    }
}

/*
 * Finds the partner portal for a given `prop_portal` entity.
 * 
 * @param {pcapEntity} portal - The `prop_portal` entity to find the partner for. 
 * @returns {pcapEntity|null} - The partner portal entity, or `null` if no partner is found. 
*/
::FindPartnerForPropPortal <- function(portal) {    
    // Find the partner portal entity based on the determined model name.  
    local portalPairId = portal.GetHealth()
    // for(local partner; partner = entLib.FindByModel(mdl, partner);) { 
    for(local partner; partner = entLib.FindByClassname("prop_portal", partner);) { 
        local partnerPairId = partner.GetHealth() 
        if(portalPairId != partnerPairId || partner.entindex() == portal.entindex() || partner.GetClassname() != "prop_portal" || partner.GetUserData("TracePlusIgnore"))
            continue
        
        return partner 
    }

    return null
}

/*
 * Checks if the given entity is a blue portal.
 *
 * @param {pcapEntity} ent - The entity to check.
 * @returns {boolean} - True if the entity is a blue portal, false otherwise.
*/
::IsBluePortal <- function(ent) { 
    return ent.GetModelName().find("portal2") == null
}
::macros <- {}

/* 
 * Precaches a sound script or a list of sound scripts for later use.
 * 
 * @param {string|array|ArrayEx|List} sound_path - The path to the sound script or a list of paths.
*/
macros["Precache"] <- function(soundPath) {
    if(typeof soundPath == "string")
        return self.PrecacheSoundScript(soundPath)
    local iter = typeof soundPath == "List" ? soundPath.iter() : soundPath
    foreach(path in iter)
        self.PrecacheSoundScript(path)
}


/* 
 * Gets a value from a table, returning a default value if the key is not found. 
 *
 * @param {table} table - The table to retrieve the value from. 
 * @param {any} key - The key of the value to get. 
 * @param {any} defaultValue - The default value to return if the key is not found. (optional) 
 * @returns {any} - The value associated with the key, or the default value if the key is not found. 
*/ 
macros["GetFromTable"] <- function(table, key, defaultValue = null) {
    if(key in table && table[key] != null) 
        return table[key]
    return defaultValue
}

/* 
 * Gets a list of all keys in a table.
 *
 * @param {table} table - The table to retrieve the keys from.
 * @returns {List} - A list containing all the keys in the table.
*/ 
macros["GetKeys"] <- function(table) {
    local result = List()
    foreach(key, _ in table) {
        result.append(key)
    }
    return result
}

/*
 * Gets a list of all values in a table.
 *
 * @param {table} table - The table to retrieve the values from.
 * @returns {List} - A list containing all the values in the table.
*/ 
macros["GetValues"] <- function(table) {
    local result = List()
    foreach(value in table) {
        result.append(value)
    }
    return result
}

/*
 * Inverts a table, swapping keys and values.
 *
 * @param {table} table - The table to invert.
 * @returns {table} - A new table with keys and values swapped.
*/ 
macros["InvertTable"] <- function(table) {
    local result = {}
    foreach(key, value in table) {
        result[value] <- key
    }
    return result
}

/*
 * Prints the keys and values of an iterable object to the console. 
 *
 * @param {iterable} iterable - The iterable object to print.
*/
macros["PrintIter"] <- function(iterable) {
    iterable = typeof iterable == "List" ? iterable.iter() : iterable
    foreach(k, i in iterable) 
        macros.fprint("{}: {}", k, i)
}

/*
 * Generates a list of numbers within a specified range.
 *
 * @param {number} start - The starting value of the range.
 * @param {number} end - The ending value of the range.
 * @param {number} [step=1] - The increment between each value in the range.
 * @returns {List} - A list of numbers within the specified range.
*/ 
macros["Range"] <- function(start, end, step = 1) {
    if(step == 0) throw("macros.Range: step must be non-zero");
    
    local result = List()
    for (local i = start; i <= end; i += step) {
        result.append(i)
    }
    return result
}

/*
 * Generates an iterator that yields numbers within a specified range.
 *
 * @param {number} start - The starting value of the range.
 * @param {number} end - The ending value of the range.
 * @param {number} [step=1] - The increment between each value in the range.
 * @yields {number} - The next number in the range.
*/ 
macros["RangeIter"] <- function(start, end, step = 1) {
    if(step == 0) throw("macros.RangeIter: step must be non-zero");

    for (local i = start; i <= end; i += step) {
        yield i
    }
    return null
}

/*
 * Searches for a matching string in an array, considering wildcard '*'.
 *
 * @param {array|ArrayEx} iter - The array to search in.
 * @param {string} match - The string to search for.
 * @returns {int|null} - The index of the first matching element, or null if not found. 
 *           If the first element of iter is '*', returns 0. 
*/
macros["MaskSearch"] <- function(iter, match) {
    if(iter.len() == 0) return null
    if(iter[0] == "*") return 0

    foreach(idx, val in typeof iter == "List" ? iter.iter() : iter) {
        if(match.find(val) >= 0)
            return idx
    }
    return null
}

/*
 * Prints a formatted message to the console.
 * 
 * @param {string} msg - The message string containing `{}` placeholders.
 * @param {any} vargs... - Additional arguments to substitute into the placeholders.
*/
macros["format"] <- function(msg, ...) {
    // If you are sure of what you are doing, you don't have to use it
    local subst_count = 0;
    for (local i = 0; i < msg.len() - 1; i++) {
        if (msg.slice(i, i+2) == "{}") {
            subst_count++; 
        }
    }

    if (subst_count != vargc)
        throw("Discrepancy between the number of arguments and substitutions")

    local args = array(vargc)
    for(local i = 0; i< vargc; i++) {
        args[i] = vargv[i]
    }

    if (msg.slice(0, 2) == "{}") {
        msg = args[0] + msg.slice(2); 
        args.remove(0); 
    }

    local parts = split(msg, "{}");
    local result = "";

    for (local i = 0; i < parts.len(); i++) {
        result += parts[i];
        if (i < args.len()) {
            local txt = args[i]
            result += ("" + txt);
        }
    }

    return result
}

/*
 * Prints a formatted message to the console.
 *
 * This function is similar to dev.format, but it automatically calls printl 
 * with the formatted message. 
 *
 * @param {string} msg - The message string containing `{}` placeholders. 
 * @param {any} vargs... - Additional arguments to substitute into the placeholders. 
*/
macros["fprint"] <- function(msg, ...) {
    local args = array(vargc + 2)
    args[0] = this
    args[1] = msg

    for(local i = 0; i< vargc; i++) {
        args[i + 2] = vargv[i]
    }

    printl(macros.format.acall(args))
}
::dev.fprint <- macros.fprint // fallback for earlier version of the lib

/*
 * Compiles a function from a string representation.
 * This function is similar to dev.format.
 *
 * @param {string} funcBody - The body of the function to be compiled.
 * @param {any} vargs... - Additional arguments to substitute into the placeholders.
 * @returns {function} - The compiled function.
*/
macros["CompileFromStr"] <- function(funcBody, ...) {
    local args = array(vargc + 2)
    args[0] = this
    args[1] = funcBody

    for(local i = 0; i< vargc; i++) {
        args[i + 2] = vargv[i]
    }

    return compilestring(macros.format.acall(args))
}

/* 
 * Calculates the distance between two vectors.
 *
 * @param {Vector} vec1 - The first vector.
 * @param {Vector} vec2 - The second vector.
 * @returns {number} - The distance between the vectors.
*/
macros["GetDist"] <- function(vec1, vec2) {
    return (vec2 - vec1).Length()
}

/* 
 * Converts a string to a Vector object.
 * 
 * @param {string} str - The string representation of the vector, e.g., "x y z".
 * @param {string} sep - The separator string.
 * @returns {Vector} - The converted vector.
*/
macros["StrToVec"] <- function(str, sep = " ") {
    local str_arr = split(str, sep)
    if (str_arr.len() != 3) throw(format("macros.StrToVec: Input string '%s' is malformed. Expected 3 components separated by '%s', but got %d.", str, sep, str_arr.len()));
    try {
        local vec = Vector(str_arr[0].tofloat(), str_arr[1].tofloat(), str_arr[2].tofloat())
        return vec
    }
    catch(ex) {
        throw(format("macros.StrToVec: Failed to convert components of string '%s' to numbers. Details: %s", str, ex));
    }

}

/*
 * Converts a Vector object to a string representation.
 * 
 * @param {Vector} vec - The vector to convert. 
 * @returns {string} - The separator string.
*/
macros["VecToStr"] <- function(vec, sep = " ") {
    return vec.x + sep + vec.y + sep + vec.z 
}

/*
 * Gets the duration of a sound by its name. 
 * 
 * @param {string} soundName - The name of the sound. 
 * @returns {number} - The duration of the sound in seconds.
*/
macros["GetSoundDuration"] <- function(soundName) {
    return self.GetSoundDuration(soundName, "")
}

/*
 * Creates a simple console alias.
 *
 * @param {string} key - The alias name.
 * @param {string} action - The command to be executed when the alias is called.
 * @returns {void}
*/
macros["CreateAlias"] <- function(key, action) {
    SendToConsole(::format("alias \"%s\" \"%s\"", key, action))
}

/*
 * Creates a primitive console command.
 *
 * @param {string} key - The name of the command.
 * @param {string} command - The command to be executed.
*/
 macros["CreateCommand"] <- function(key, command) {
    SendToConsole(::format("setinfo %s \"\"", key))
    macros.CreateAlias(key, command)
}

/*
 * Checks if two values are equal, handling different data types.
 *
 * @param {any} val1 - The first value.
 * @param {any} val2 - The second value.
 * @returns {boolean} - True if the values are equal, false otherwise. 
*/
macros["IsEqual"] <- function(val1, val2) {
    if((typeof val1 == "instance" || typeof val2 == "instance") && (val1 instanceof CBaseEntity || val2 instanceof CBaseEntity)) 
        return val1.entindex() == val2.entindex()
    
        switch (typeof val1) {
        case "integer": 
            return val1 == val2 
        case "float": 
            return math.round(val1, 1000) == math.round(val2, 1000)
        case "Vector": 
            return math.vector.IsEqual(val1, val2)
        case "instance": 
            return val1 == val2; 
        case "Quaternion": 
        case "Matrix": 
        case "pcapEntity": 
            return val1.IsEqual(val2)  
    }
}

/*
 * Creates a deep copy of a container (table, array, ArrayEx, or List).
 * Note: The container must not have circular references.
 *
 * @param {table|array|ArrayEx|List} container - The container to be copied.
 * @returns {table|array|ArrayEx|List} - A deep copy of the container.
*/
macros["DeepCopy"] <- function(container, _ = null) { 
    switch (typeof container) {
        case "table": 
            local result = clone container; 
            foreach( k,v in container) result[k] = macros.DeepCopy(v); 
            return result; 
        
        case "array": 
            local a = array(container.len());
            for (local i=0; i<container.len(); i++) a[i] = macros.DeepCopy(container[i]);
            return a;

        case "ArrayEx": 
        case "List":
            return container.map(macros.DeepCopy); 
        
        default: return container; 
    }
}


/*
 * Gets the prefix of an entity name. 
 *
 * @param {string} name - The entity name. 
 * @returns {string} - The prefix of the entity name, or the original name if no "-" is found. 
*/
macros["GetPrefix"] <- function(name) {
    local parts = split(name, "-")
    if(parts.len() == 0)
        return name
    
    local lastPartLength = parts.pop().len()
    local prefix = name.slice(0, -lastPartLength)
    return prefix;
}


/* 
 * Gets the postfix of an entity name. 
 *
 * @param {string} name - The entity name. 
 * @returns {string} - The postfix of the entity name, or the original name if no "-" is found. 
*/
macros["GetPostfix"] <- function(name) {
    local parts = split(name, "-")
    if(parts.len() == 0)
        return name

    local lastPartLength = parts[0].len();
    local prefix = name.slice(lastPartLength);
    return prefix;
}

/*
 * Calculates the end position of a ray cast from the player's eyes.
 * 
 * @param {CBaseEntity|pcapEntity} player - The player entity.
 * @param {number} distance - The distance of the ray cast.
 * @returns {Vector} - The end position of the ray cast. 
*/
macros["GetEyeEndpos"] <- function(player, distance) {
    if(typeof player != "pcapEntity") 
        player = entLib.FromEntity(player)
    return player.EyePosition() + player.EyeForwardVector() * distance
}

/*
 * Gets one vertex of the bounding box based on x, y, z bounds.
 * 
 * @param {Vector} x - The x bounds.
 * @param {Vector} y - The y bounds.  
 * @param {Vector} z - The z bounds.
 * @param {Vector} ang - The angle vector.
 * @returns {Vector} - The vertex.
*/
macros["GetVertex"] <- function(x, y, z, ang) {
    return math.vector.rotate(Vector(x.x, y.y, z.z), ang)
}

/*
 * Creates a triangle representation from three vertices. 
 *
 * @param {Vector} v1 - The first vertex of the triangle.
 * @param {Vector} v2 - The second vertex of the triangle.
 * @param {Vector} v3 - The third vertex of the triangle.
 * @returns {table} - A table containing the origin and vertices of the triangle.
*/
macros["GetTriangle"] <- function(v1, v2, v3) {
    return {
        origin = (v1 + v2 + v3) * 0.3333,
        vertices = [v1, v2, v3]
    }
}

/*
 * Creates a rectangle object from four vertices. 
 *
 * @param {Vector} v1 - The first vertex.
 * @param {Vector} v2 - The second vertex. 
 * @param {Vector} v3 - The third vertex. 
 * @param {Vector} v4 - The fourth vertex.
 * @returns {table} - A table representing the rectangle with 'origin' and 'vertices' properties. 
*/
macros["GetRectangle"] <- function(v1, v2, v3, v4) {
    return {
        origin = (v1 + v2 + v3 + v4) * 0.25,
        vertices = [v1, v2, v3, v4]
    }
}

/*
 * Checks if a point is inside a bounding box. 
 * 
 * @param {Vector} point - The point to check.
 * @param {Vector} bMin - The minimum corner of the bounding box. 
 * @param {Vector} bMax - The maximum corner of the bounding box. 
 * @returns {boolean} - True if the point is inside the bounding box, false otherwise.
*/
macros["PointInBBox"] <- function(point, bMin, bMax) {
    return (
        point.x >= bMin.x && point.x <= bMax.x &&
        point.y >= bMin.y && point.y <= bMax.y &&
        point.z >= bMin.z && point.z <= bMax.z
    )
}

/*
 * Checks if a point is within the defined bounds of the map using raycasts.
 *
 * @param {Vector} point - The point to check.
 * @returns {boolean} - True if the point is within the bounds, false otherwise.
*/
macros["PointInBounds"] <- function(point) {
    local m = 64000
    return (
        TraceLine(point, point + Vector(m, 0, 0), null) >= 0.98 ||
        TraceLine(point, point - Vector(m, 0, 0), null) >= 0.98 ||
        TraceLine(point, point + Vector(0, m, 0), null) >= 0.98 ||
        TraceLine(point, point - Vector(0, m, 0), null) >= 0.98 || 
        TraceLine(point, point + Vector(0, 0, m), null) >= 0.98 ||
        TraceLine(point, point - Vector(0, 0, m), null) >= 0.98
    ) == false
}


/*
 * Creates a function that animates a property of one or more entities.
 * 
 * @param {string} name - The name of the animation. This name is used to identify the animation internally. 
 * @param {function} propertySetterFunc - A function that takes an entity and a value, and sets a property on that entity. This function will be called repeatedly during the animation to update the property.
 * @param {function} valueCalculator (optional) - A custom function that calculates the animated value for each step. 
 * @returns {function} - A function that can be used to start the animation. This function takes the following arguments:
 *   * `entities` {array|pcapEntity} - An array of entities or a single entity to animate.
 *   * `startValue` {any} - The starting value for the property.
 *   * `endValue` {any} - The ending value for the property.
 *   * `time` {number} - The duration of the animation in seconds.
 *   * `animSetting` {table} (optional) - A table of additional animation settings. See the `AnimEvent` constructor for details.
*/
macros["BuildAnimateFunction"] <- function(name, propertySetterFunc, valueCalculator = null) {
    if (typeof propertySetterFunc != "function") throw("macros.BuildAnimateFunction: 'propertySetterFunc' must be a function, but got " + typeof propertySetterFunc);
    if (valueCalculator != null && typeof valueCalculator != "function") throw("macros.BuildAnimateFunction: 'valueCalculator' must be a function or null, but got " + typeof valueCalculator);

    return function(entities, startValue, endValue, time, animSetting = {}) : (name, propertySetterFunc, valueCalculator) {
        if(!entities) throw(name+" Anim: entities cannot be null")
        if(time <= 0) throw(name+" Anim: time must be positive")
    
        local animSetting = AnimEvent(name, animSetting, entities, time) 
        local varg = {
            start = startValue,
            delta = endValue - startValue,
            easeFunc = animSetting.easeFunc
        }

        animate.applyAnimation(
            animSetting,
            valueCalculator ? valueCalculator : function(step, steps, v) {return v.start + v.delta * v.easeFunc(step / steps)},
            propertySetterFunc,
            varg
        ) 

        return animSetting.delay
    }
}

/*
 * Same as BuildAnimateFunction, only for creating RealTime animations.
*/
macros["BuildRTAnimateFunction"] <- function(name, propertySetterFunc, valueCalculator = null) {
    return function(entities, startValue, endValue, time, animSetting = {}) : (name, propertySetterFunc, valueCalculator) {
        local animSetting = AnimEvent(name, animSetting, entities, time) 
        local varg = {
            start = startValue,
            delta = endValue - startValue,
            easeFunc = animSetting.easeFunc
        }

        animate.applyRTAnimation(
            animSetting,
            valueCalculator ? valueCalculator : function(step, steps, v) {return v.start + v.delta * v.easeFunc(step / steps)},
            propertySetterFunc,
            varg
        ) 

        return animSetting.delay
    }
}
// Collides with everything.
const COLLISION_GROUP_NONE = 0

// Collides with nothing but world and static stuff.
const COLLISION_GROUP_DEBRIS = 1

// Same as debris, but hits triggers.
const COLLISION_GROUP_DEBRIS_TRIGGER = 2 

// Like DEBRIS, but doesn't collide with same group.
const COLLISION_GROUP_INTERACTIVE_DEBRIS = 3

// Collides with everything except interactive debris or debris.
const COLLISION_GROUP_INTERACTIVE = 4

// Used by players, ignores PASSABLE_DOOR.
const COLLISION_GROUP_PLAYER = 5

// Breakable glass, ignores same group and NPC line-of-sight.
const COLLISION_GROUP_BREAKABLE_GLASS = 6

// Driveable vehicles, always collides with VEHICLE_CLIP.
const COLLISION_GROUP_VEHICLE = 7

// Player movement collision.
const COLLISION_GROUP_PLAYER_MOVEMENT = 8

// Used by NPCs, always collides with DOOR_BLOCKER.
const COLLISION_GROUP_NPC = 9

// Entities inside vehicles, no collisions. 
const COLLISION_GROUP_IN_VEHICLE = 10 

// Weapons, including dropped ones. 
const COLLISION_GROUP_WEAPON = 11 

// Only collides with VEHICLE.
const COLLISION_GROUP_VEHICLE_CLIP = 12

// Projectiles, ignore other projectiles.
const COLLISION_GROUP_PROJECTILE = 13

// Blocks NPCs, may collide with some projectiles.
const COLLISION_GROUP_DOOR_BLOCKER = 14

// Passable doors, allows players through.
const COLLISION_GROUP_PASSABLE_DOOR = 15 

// Dissolved entities, only collide with NONE.
const COLLISION_GROUP_DISSOLVING = 16

// Pushes props away from the player.
const COLLISION_GROUP_PUSHAWAY = 17

// NPCs potentially stuck in a player.
const COLLISION_GROUP_NPC_ACTOR = 18

// NPCs in scripted sequences with collisions disabled. 
const COLLISION_GROUP_NPC_SCRIPTED = 19

// It doesn't seem to be used anywhere in the engine.
const COLLISION_GROUP_PZ_CLIP = 20

// Solid only to the camera's test trace (Outdated).
const COLLISION_GROUP_CAMERA_SOLID = 21

// Solid only to the placement tool's test trace (Outdated).
const COLLISION_GROUP_PLACEMENT_SOLID = 22

// Held objects that shouldn't collide with players.
const COLLISION_GROUP_PLAYER_HELD = 23

// Cubes need a collision group that acts roughly like COLLISION_GROUP_NONE but doesn't collide with debris or interactive.
const COLLISION_GROUP_WEIGHTED_CUBE = 24

// No collision at all.
const SOLID_NONE = 0 

// Uses Quake Physics engine.
const SOLID_BSP = 1 

// Uses an axis-aligned bounding box (AABB).
const SOLID_AABB = 2

// Uses an oriented bounding box (OBB).
const SOLID_OBB = 3 

// Uses an OBB constrained to yaw rotation.
const SOLID_OBB_YAW = 4 

// Custom/test solid type.
const SOLID_CUSTOM = 5 

// Uses VPhysics engine for realistic physics. 
const SOLID_VPHYSICS = 6 
if("AllPlayers" in getroottable()) return

::AllPlayers <- ArrayEx()
const PLAYER_DEATH_MARKER = -999

/* 
 * Gets an array of all players in the game. 
 *
 * @returns {array} - An array of pcapEntity objects representing the players. 
*/
::GetPlayers <- function() { // -> ArrayEx
    return AllPlayers
}


/* 
 * Tracks players joining the game and initializes their. 
 *
 * This function iterates over all player entities in the game, attaching eye control 
 * and initializing new portal pairs for each new player. It calls OnPlayerJoin for 
 * each player added to the AllPlayers list.
*/
::TrackPlayerJoins <- function() {
    for(local player; player = entLib.FindByClassname("player", player);) {
        if(player.GetUserData("Eye")) continue // if already inited (AllPlayers.contains(player))
        
        // Attach eye control to the new player
        AttachEyeControl(player)
        // Initialize a new portal pair for this player:
        InitPortalPair(AllPlayers.len())
        
        AllPlayers.append(player)
        // Trigger join event
        OnPlayerJoined(player)
    }
}

/* 
 * Handles player events in MP, such as health checks and death events. 
 *
 * This function iterates over all players in the AllPlayers list, checking if 
 * each player is valid and updating their state accordingly. It calls OnDeath 
 * for dead players and schedules their respawn logic.
*/
::HandlePlayerEventsMP <- function() {
    local playersToRemove = []
    foreach(idx, player in AllPlayers){
        if(!player.IsValid()) {
            OnPlayerLeft(player)
            playersToRemove.append(idx)
            continue
        }
        
        if(player.GetHealth() > 0 || player.GetHealth() == PLAYER_DEATH_MARKER) continue

        OnPlayerDeath(player)
        ScheduleEvent.AddInterval("global", _monitorRespawn, 0.3, 0, null, player)
        player.SetHealth(PLAYER_DEATH_MARKER)
    }

    if(playersToRemove.len() > 0) {
        for(local i = playersToRemove.len() - 1; i >= 0; i--) {
            AllPlayers.remove(playersToRemove[i])
        }        
    } 
}

::HandlePlayerEventsSP <- function() {
    local h = AllPlayers[0].GetHealth()
    if(h > 0 || h == PLAYER_DEATH_MARKER) return
    OnPlayerDeath(AllPlayers[0])
    AllPlayers[0].SetHealth(PLAYER_DEATH_MARKER)
}

/* 
 * Monitors player respawn status. 
*/
function _monitorRespawn() {
    if(this.GetHealth() > 0)
        return OnPlayerRespawn(this)
}


/* 
 * Attaches eye control entities to all players in the game. 
 *
 * This function creates logic_measure_movement and info_target entities for each player to track their eye position and angles. 
 * It is called automatically at the initialization of the library and periodically in multiplayer games. 
*/
function AttachEyeControl(player) {
    if(player.GetUserData("Eye")) return

    local controlName = UniqueString("eyeControl")
    local eyeControlEntity = entLib.CreateByClassname("logic_measure_movement", {
        targetname = controlName, measuretype = 1}
    )

    local eyeName = UniqueString("eyePoint")
    local eyePointEntity = entLib.CreateByClassname("info_target", {targetname = eyeName})

    local playerName = player.GetName() == "" ? "!player" : player.GetName()

    EntFireByHandle(eyeControlEntity, "setmeasuretarget", playerName)
    EntFireByHandle(eyeControlEntity, "setmeasurereference", controlName);
    EntFireByHandle(eyeControlEntity, "SetTargetReference", controlName);
    EntFireByHandle(eyeControlEntity, "Settarget", eyeName);
    EntFireByHandle(eyeControlEntity, "Enable")

    player.SetUserData("Eye", eyePointEntity)
}


// Empty Hooks
function OnPlayerJoined(player) {}
function OnPlayerLeft(player) {}
function OnPlayerDeath(player) {}
function OnPlayerRespawn(player) {}
ScheduleEvent.Add("global", function() {
commands_separator <- ",\n"

// Basic information
macros.CreateCommand("PCapLib_version", "script printl(::LIB_VERSION)")

// Logger level control commands
macros.CreateCommand("PCapLib_level_trace", "script ::LibLogger = LoggerLevels.Trace")
macros.CreateCommand("PCapLib_level_debug", "script ::LibLogger = LoggerLevels.Debug")
macros.CreateCommand("PCapLib_level_info", "script ::LibLogger = LoggerLevels.Info")
macros.CreateCommand("PCapLib_level_warn", "script ::LibLogger = LoggerLevels.Warning")
macros.CreateCommand("PCapLib_level_error", "script ::LibLogger = LoggerLevels.Error")
macros.CreateCommand("PCapLib_level_off", "script ::LibLogger = LoggerLevels.Off")

// Schedule event control commands
macros.CreateCommand("PCapLib_schedule_list", "script printl(macros.GetKeys(ScheduleEvent.eventsList).join(commands_separator))")
macros.CreateCommand("PCapLib_schedule_clear", "script ScheduleEvent.CancelAll()")

// Information dump commands
macros.CreateCommand("PCapLib_vscript_event_list", "script printl(macros.GetKeys(::AllScriptEvents).join(commands_separator))")
macros.CreateCommand("PCapLib_players_list", "script printl(AllPlayers.join(commands_separator))")

// Simple debug commands
macros.CreateCommand("script_FrameTime", "script printl(FrameTime())")
}, 1, null, this)

::LibLogger <- LoggerLevels.Info
::MAX_PORTAL_CAST_DEPTH <- 4
::ALWAYS_PRECACHED_MODEL <- "models/weapons/w_portalgun.mdl" // needed for pcapEntity::EmitSoundEx

/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Ray Tracing Virtuoso - laVashik ˙▿˙                                          |
+----------------------------------------------------------------------------------+
|       The TracePlus module, taking ray tracing to the next level with advanced   |
|       features like portal support and precise collision detection algorithms.   |
+----------------------------------------------------------------------------------+ */

::TracePlus <- {
    Result = {},
    Portals = {},
    FromEyes = {},

    Settings = null,
    defaultSettings = null,

    Cheap = null,
    Bbox = null,
}

::USE_LEGACY_BBOXCAST_ANALYZER <- false

function TracePlus::InvalidateEntity(ent) {
    local idx = ent.entindex()
    if(idx in EntBufferTable) {
        EntBufferTable[idx].lastFrameTime = -1
    }
}

local results = TracePlus["Result"]

results["Cheap"] <- class {
    traceHandler = null;
    hitpos = null;

    surfaceNormal = null;
    portalEntryInfo = null;

    /*
     * Constructor for a CheapTraceResult object.
     *
     * @param {table} traceHandler - The trace handler object containing trace information.
     * @param {Vector} hitpos - The hit position of the trace.
    */
    constructor(traceHandler, hitpos) {
        this.traceHandler = traceHandler
        this.hitpos = hitpos
    }

    /*
     * Gets the start position of the trace.
     *
     * @returns {Vector} - The start position.
    */
    function GetStartPos() {
        return this.traceHandler.startpos
    }

    /*
     * Gets the end position of the trace.
     *
     * @returns {Vector} - The end position.
    */
    function GetEndPos() {
        return this.traceHandler.endpos
    }

    /*
     * Gets the hit position of the trace.
     *
     * @returns {Vector} - The hit position. 
    */
    function GetHitPos() {
        return this.hitpos
    }

    /*
     * Gets the fraction of the trace distance where the hit occurred.
     *
     * @returns {number} - The hit fraction.
    */
    function GetFraction() {
        return this.traceHandler.fraction
    }

    /*
     * Checks if the trace hit anything.
     *
     * @returns {boolean} - True if the trace hit something, false otherwise.
    */
    function DidHit() {
        return this.traceHandler.fraction != 1
    }

    /*
     * Gets the normalized direction vector of the trace.
     *
     * @returns {Vector} - The direction vector.
    */
    function GetDir() {
        local dir = (this.traceHandler.endpos - this.traceHandler.startpos); dir.Norm()
        return dir
    }

    /*
     * Gets the portal entry information for the trace.
     * 
     * @returns {CheapTraceResult|null} - The portal entry information, or null if not available.
    */
    function GetPortalEntryInfo() {
        return this.portalEntryInfo
    }

    /*
     * Gets an array of all portal entry information for the trace, including nested portals.
     * 
     * @returns {List} - An array of CheapTraceResult objects representing portal entries.
    */
    function GetAggregatedPortalEntryInfo() {
        local list = List(this)
        for(local trace = this; trace = trace.portalEntryInfo;) {
            list.append(trace)
        }
        return list.reverse()
    }

    /*
     * Gets the impact normal of the surface hit by the trace.
     *
     * @returns {Vector} - The impact normal vector.
    */
    function GetImpactNormal() {
        // If the surface normal is already calculated, return it
        if(this.surfaceNormal)
            return this.surfaceNormal
        
        this.surfaceNormal = CalculateImpactNormal(this.traceHandler.startpos, this.hitpos)
        return this.surfaceNormal 
    } 

    function _typeof() return "TraceResult"
    function _tostring() {
        return "TraceResult | startpos: " + GetStartPos() + ", endpos: " + GetEndPos() + ", fraction: " + GetFraction() + ", hitpos: " + GetHitPos()
    }
}



// Don't forget, the class extension is broken in VScripts
// Valvo's, I hate u :<
results["Bbox"] <- class {
    traceHandler = null;
    hitpos = null;
    hitent = null;

    surfaceNormal = null;
    portalEntryInfo = null;

    /*
     * Constructor for a BboxTraceResult object.
     *
     * @param {table} traceHandler - The trace handler object containing trace information.
     * @param {Vector} hitpos - The hit position of the trace.
     * @param {CBaseEntity} hitent - The entity hit by the trace.
    */
    constructor(traceHandler, hitpos, hitent) {
        this.traceHandler = traceHandler
        this.hitpos = hitpos
        this.hitent = hitent
    }

    /*
     * Gets the start position of the trace.
     *
     * @returns {Vector} - The start position.
    */
    function GetStartPos() {
        return this.traceHandler.startpos
    }

    /*
     * Gets the end position of the trace.
     *
     * @returns {Vector} - The end position.
    */
    function GetEndPos() {
        return this.traceHandler.endpos
    }

    /*
     * Gets the hit position of the trace.
     *
     * @returns {Vector} - The hit position. 
    */
    function GetHitPos() {
        return this.hitpos
    }

    /*
     * Gets the entity hit by the trace.
     *
     * @returns {pcapEntity|null} - The hit entity, or null if no entity was hit.
    */
    function GetEntity() {
        if(this.hitent && this.hitent.IsValid())
            return entLib.FromEntity(this.hitent)
    }

    /*
     * Gets the classname of the entity hit by the trace.
     *
     * @returns {string|null} - The classname of the hit entity, or null if no entity was hit.
    */
    function GetEntityClassname() {
        return (this.hitent && this.hitent.IsValid()) ? this.hitent.GetClassname() : null 
    }

    /*
     * Gets the list of entities that were ignored during the trace. 
     *
     * @returns {array|CBaseEntity|null} - The list of ignored entities, or null if no entities were ignored.
    */
    function GetIngoreEntities() {
        return this.traceHandler.ignoreEntities
    }

    /*
     * Gets the settings used for the trace.
     *
     * @returns {TraceSettings} - The trace settings object. 
    */
    function GetTraceSettings() {
        return this.traceHandler.settings
    }

    /*
     * Checks if the trace hit anything.
     *
     * @returns {boolean} - True if the trace hit something, false otherwise.
    */
    function DidHit() {
        return this.GetFraction() != 1
    }

    /*
     * Checks if the trace hit the world geometry (not an entity). 
     *
     * @returns {boolean} - True if the trace hit the world, false otherwise.
    */
    function DidHitWorld() {
        return !this.hitent && DidHit()
    }

    /*
     * Gets the fraction of the trace distance where the hit occurred.
     *
     * @returns {number} - The hit fraction. 
    */
    function GetFraction() {
        return macros.GetDist(this.traceHandler.startpos, this.hitpos) / macros.GetDist(this.traceHandler.startpos, this.traceHandler.endpos)
    }

    /*
     * Gets the normalized direction vector of the trace.
     *
     * @returns {Vector} - The direction vector.
    */
    function GetDir() {
        local dir = (this.traceHandler.endpos - this.traceHandler.startpos); dir.Norm()
        return dir
    }

    /*
     * Gets the portal entry information for the trace. 
     * 
     * @returns {BboxTraceResult|null} - The portal entry information, or null if not available.
    */
    function GetPortalEntryInfo() {
        return this.portalEntryInfo
    }

    /*
     * Gets an array of all portal entry information for the trace, including nested portals.
     * 
     * @returns {List} - An array of BboxTraceResult objects representing portal entries.
    */
    function GetAggregatedPortalEntryInfo() {
        local list = List(this)
        for(local trace = this; trace = trace.portalEntryInfo;) {
            list.append(trace)
        }
        return list.reverse()
    }

    /*
     * Gets the impact normal of the surface hit by the trace.
     *
     * @returns {Vector} - The impact normal vector.
    */
    function GetImpactNormal() {
        // If the surface normal is already calculated, return it
        if(this.surfaceNormal)
            return this.surfaceNormal

        local hitEnt = this.GetEntity()
        if(hitEnt) {
            this.surfaceNormal = CalculateImpactNormalFromBbox(this.GetStartPos(), this.hitpos, hitEnt)
        } else {
            this.surfaceNormal = CalculateImpactNormal(this.GetStartPos(), this.hitpos)
        }

        return this.surfaceNormal
    } 

    function _typeof() return "BboxTraceResult"
    function _tostring() {
        return "TraceResult | startpos: " + GetStartPos() + ", endpos: " + GetEndPos() + ", hitpos: " + GetHitPos() + ", entity: " + GetEntity()
    }
}
/*
 * Settings for ray traces.
*/
TracePlus["Settings"] <- class {
    id = null;
    ignoreAllClasses = false;
    
    // An array of entity classnames to ignore during traces. 
    ignoreClasses = ArrayEx("viewmodel", "weapon_", "beam", "light",
        "trigger_", "phys_", "env_", "point_", "info_", "vgui_", "logic_",
        "clone", "prop_portal", "portal_base2D", "func_clip", "func_instance",
        "func_portal_detector", 
        "worldspawn", "soundent", "player_manager", "bodyque", "ai_network"
    );
    // An array of entity classnames to prioritize during traces.  
    priorityClasses = ArrayEx();
    // An array of entity model names to ignore during traces. 
    ignoredModels = ArrayEx();


    // A custom function to determine if a ray should hit an entity. 
    shouldRayHitEntity = null;
    // A custom function to determine if an entity should be ignored during a trace. 
    shouldIgnoreEntity = null;

    depthAccuracy = 5;
    bynaryRefinement = false;

    /*
     * Creates a new TraceSettings object with default values or from a table of settings. 
     * 
     * @param {table} settingsTable - A table containing settings to override the defaults. (optional)
     * @returns {TraceSettings} - A new TraceSettings object.
    */
    function new(settingsTable = {}) {
        local result = TracePlus.Settings()
        result.id = UniqueString("TracePlus")

        // Set the ignoreClasses setting from the settings table or use the default. 
        result.SetIgnoredClasses(macros.GetFromTable(settingsTable, "ignoreClasses", TracePlus.Settings.ignoreClasses))
        // Set the priorityClasses setting from the settings table or use the default. 
        result.SetPriorityClasses(macros.GetFromTable(settingsTable, "priorityClasses", TracePlus.Settings.priorityClasses))
        // Set the ignoredModels setting from the settings table or use the default. 
        result.SetIgnoredModels(macros.GetFromTable(settingsTable, "ignoredModels", TracePlus.Settings.ignoredModels))
        
        // Set the shouldRayHitEntity setting from the settings table or use the default.  
        result.SetCollisionFilter(macros.GetFromTable(settingsTable, "shouldRayHitEntity", null))
        // Set the shouldIgnoreEntity setting from the settings table or use the default. 
        result.SetIgnoreFilter(macros.GetFromTable(settingsTable, "shouldIgnoreEntity", null))

        // Set the depth accuracy for the BBox trace. Lower values are more precise for hitting thin objects but cost more performance. Default is 5.
        result.SetDepthAccuracy(macros.GetFromTable(settingsTable, "depthAccuracy", 5))
        // Enable or disable binary refinement. This performs an extra search step to get a more accurate hit position, which is vital for calculating correct surface normals. Default is false.
        result.SetBynaryRefinement(macros.GetFromTable(settingsTable, "bynaryRefinement", false))
        
        return result
    }


    /*
     * Sets the list of entity classnames to ignore during traces.
     *
     * @param {array|ArrayEx} ignoreClassesArray - An array or ArrayEx containing entity classnames to ignore. 
    */
    function SetIgnoredClasses(ignoreClassesArray) {
        if(typeof ignoreClassesArray != "array" && typeof ignoreClassesArray != "ArrayEx") throw("TracePlus.Settings.SetIgnoredClasses: Invalid argument type. Expected an 'array' or 'ArrayEx', but got " + typeof ignoreClassesArray)

        this.ignoreClasses = ArrayEx.FromArray(ignoreClassesArray)
        this.ignoreAllClasses = this.ignoreClasses && this.ignoreClasses.contains("*")
        
        return this
    }

    /*
     * Sets the list of entity classnames to prioritize during traces.
     *
     * @param {array|ArrayEx} priorityClassesArray - An array or ArrayEx containing entity classnames to prioritize. 
    */
    function SetPriorityClasses(priorityClassesArray) {
        if(typeof priorityClassesArray != "array" && typeof priorityClassesArray != "ArrayEx") throw("TracePlus.Settings.SetPriorityClasses: Invalid argument type. Expected an 'array' or 'ArrayEx', but got " + typeof priorityClassesArray)

        this.priorityClasses = ArrayEx.FromArray(priorityClassesArray)
        return this
    }

    /*
     * Sets the list of entity model names to ignore during traces.
     *
     * @param {array|ArrayEx} ignoredModelsArray - An array or ArrayEx containing entity model names to ignore. 
    */
    function SetIgnoredModels(ignoredModelsArray) {
        if(typeof ignoredModelsArray != "array" && typeof ignoredModelsArray != "ArrayEx") throw("TracePlus.Settings.SetIgnoredModels: Invalid argument type. Expected an 'array' or 'ArrayEx', but got " + typeof ignoredModelsArray)

        this.ignoredModels = ArrayEx.FromArray(ignoredModelsArray)
        return this
    }

    function SetDepthAccuracy(value) {
        this.depthAccuracy = math.clamp(value, 0.3, 15)
        return this
    }

    function SetBynaryRefinement(bool) {
        this.bynaryRefinement = bool
        return this
    }

    /*
     * Appends an entity classname to the list of ignored classes. 
     *
     * @param {string} className - The classname to append. 
    */
    function AppendIgnoredClass(className) {
        if(typeof className != "string") throw("TracePlus.Settings.AppendIgnoredClass: Invalid argument type. Expected a 'string', but got " + typeof className)

        // CoW Mechanism
        if(this.ignoreClasses == TracePlus.Settings.ignoreClasses)
            this.ignoreClasses = this.ignoreClasses.Clone()
        
        this.ignoreClasses.append(className)
        this.ignoreAllClasses = this.ignoreClasses && this.ignoreClasses.contains("*")
        
        return this
    }

    /*
     * Appends an entity classname to the list of priority classes. 
     *
     * @param {string} className - The classname to append. 
    */
    function AppendPriorityClasses(className) {
        if(typeof className != "string") throw("TracePlus.Settings.AppendPriorityClasses: Invalid argument type. Expected a 'string', but got " + typeof className)

        // CoW Mechanism
        if(this.priorityClasses == TracePlus.Settings.priorityClasses)
            this.priorityClasses = this.priorityClasses.Clone()
        
        this.priorityClasses.append(className)
        return this
    }

    /*
     * Appends an entity model name to the list of ignored models. 
     *
     * @param {string} modelName - The model name to append. 
    */
    function AppendIgnoredModel(modelName) {
        if(typeof modelName != "string") throw("TracePlus.Settings.AppendIgnoredModel: Invalid argument type. Expected a 'string', but got " + typeof modelName)

        // CoW Mechanism
        if(this.ignoredModels == TracePlus.Settings.ignoredModels)
            this.ignoredModels = this.ignoredModels.Clone()

        this.ignoredModels.append(modelName)
        return this
    }

    /* 
     * Gets the list of entity classnames to ignore during traces. 
     *
     * @returns {ArrayEx} - An ArrayEx containing the ignored classnames. 
    */
    function GetIgnoreClasses() {
        return this.ignoreClasses
    }

    /*
     * Gets the list of entity classnames to prioritize during traces. 
     *
     * @returns {ArrayEx} - An ArrayEx containing the priority classnames. 
    */
    function GetPriorityClasses() {
        return this.priorityClasses
    }

    /*
     * Gets the list of entity model names to ignore during traces. 
     *
     * @returns {ArrayEx} - An ArrayEx containing the ignored model names. 
    */
    function GetIgnoredModels() {
        return this.ignoredModels
    }

    /*
     * Sets a custom function to determine if a ray should hit an entity. 
     *
     * @param {function} filterFunction - The filter function to set. 
    */
    function SetCollisionFilter(filterFunction) { // aka. SetHitFilter
        this.shouldRayHitEntity = filterFunction
        return this
    }

    /*
     * Sets a custom function to determine if an entity should be ignored during a trace. 
     *
     * @param {function} filterFunction - The filter function to set. 
    */
    function SetIgnoreFilter(filterFunction) {
        this.shouldIgnoreEntity = filterFunction
        return this
    }

    /*
     * Gets the custom collision filter function. 
     *
     * @returns {function|null} - The collision filter function, or null if not set. 
    */
    function GetCollisionFilter() {
        return this.shouldRayHitEntity
    }

    /*
     * Gets the custom ignore filter function. 
     *
     * @returns {function|null} - The ignore filter function, or null if not set. 
    */
    function GetIgnoreFilter() {
        return this.shouldIgnoreEntity
    }

    /*
     * Applies the custom collision filter function to an entity. 
     *
     * @param {CBaseEntity|pcapEntity} entity - The entity to check.
     * @returns {boolean} - True if the ray should hit the entity, false otherwise. 
    */
    function ApplyCollisionFilter(entity) {
        return this.shouldRayHitEntity ? this.shouldRayHitEntity(entity) : false
    }

    /*
     * Applies the custom ignore filter function to an entity. 
     *
     * @param {CBaseEntity|pcapEntity} entity - The entity to check.
     * @returns {boolean} - True if the entity should be ignored, false otherwise. 
    */
    function ApplyIgnoreFilter(entity) {
        return this.shouldIgnoreEntity ? this.shouldIgnoreEntity(entity) : false
    }

    /*
     * Updates the list of entities to ignore during a trace, including the player entity.
     *
     * @param {array|CBaseEntity|null} ignoreEntities - The current list of entities to ignore.
     * @param {CBaseEntity|pcapEntity} newEnt - The new entity to add to the ignore list.
     * @returns {array} - The updated list of entities to ignore. 
    */
    function UpdateIgnoreEntities(ignoreEntities, newEnt) {
        // Check if any entities should be ignored during the trace 
        if (ignoreEntities) {
            // If ignoreEntities is an array, append the player entity to it 
            if (typeof ignoreEntities == "array" || typeof ignoreEntities == "ArrayEx") {
                ignoreEntities.append(newEnt)
            }
            // If ignoreEntities is a single entity, create a new array with both the player and ignoreEntities 
            else {
                ignoreEntities = [newEnt, ignoreEntities]
            }
        }
        // If no ignoreEntities is provided, ignore the player only 
        else {
            ignoreEntities = newEnt
        }

        return ignoreEntities
    }

    function Clone() {
        local set = TracePlus.Settings()
            .SetIgnoredClasses(this.ignoreClasses.Clone())
            .SetPriorityClasses(this.priorityClasses.Clone())
            .SetIgnoredModels(this.ignoredModels.Clone())
            .SetCollisionFilter(this.shouldRayHitEntity)
            .SetIgnoreFilter(this.shouldIgnoreEntity)
            .SetBynaryRefinement(this.bynaryRefinement)
            .SetDepthAccuracy(this.depthAccuracy)
        set.id = this.id
        return set
    }

    function _typeof() return "TraceSettings"
    function _cloned() return this.Clone()
}
TracePlus.defaultSettings = TracePlus.Settings.new()

// Haha, pseudo-constuctor-class
/*
 * Performs a cheap (fast but less accurate) trace.
 *
 * @param {Vector} startpos - The start position of the trace.
 * @param {Vector} endpos - The end position of the trace. 
 * @returns {CheapTraceResult} - The trace result object.
*/
 TracePlus["Cheap"] <- function(startpos, endpos) {
    local SCOPE = {}

    SCOPE.startpos <- startpos
    SCOPE.endpos <- endpos
    // SCOPE.type <- "CheapTrace"

    SCOPE.fraction <- TraceLine(startpos, endpos, null)
    local hitpos = startpos + (endpos - startpos) * SCOPE.fraction

    return TracePlus.Result.Cheap(SCOPE, hitpos)
}


/* 
 * Performs a cheap trace from the player's eyes. 
 *
 * @param {number} distance - The distance of the trace. 
 * @param {CBaseEntity|pcapEntity} player - The player entity.
 * @returns {CheapTraceResult} - The trace result object.
*/
TracePlus["FromEyes"]["Cheap"] <- function(distance, player) {
    // Calculate the start and end positions of the trace
    local startpos = player.EyePosition()
    local endpos = macros.GetEyeEndpos(player, distance)

    return TracePlus.Cheap(startpos, endpos)
}
/*
 * Performs a bbox cast (trace with bounding box) from the specified start and end positions. 
 *
 * @param {Vector} startPos - The start position of the trace.
 * @param {Vector} endPos - The end position of the trace.
 * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. (optional)
 * @param {TraceSettings} settings - The settings to use for the trace. (optional, defaults to TracePlus.defaultSettings) 
 * @returns {BboxTraceResult} - The trace result object. 
*/
TracePlus["Bbox"] <- function(startPos, endPos, ignoreEntities = null, settings = TracePlus.defaultSettings) {
    if(typeof startPos != "Vector") throw("TracePlus.Bbox: 'startPos' argument must be a Vector, but got " + typeof startPos);
    if(typeof endPos != "Vector") throw("TracePlus.Bbox: 'endPos' argument must be a Vector, but got " + typeof endPos);
    if(typeof settings != "TraceSettings")  throw("TracePlus.Bbox: 'settings' argument must be a TraceSettings, but got " + typeof settings);
    if(ignoreEntities != null) {
        local ignoreType = typeof ignoreEntities;
        if (ignoreType == "array" || ignoreType == "ArrayEx" || ignoreType == "List") {
            foreach(idx, ent in ignoreEntities) {
                if(!ent || !ent.IsValid()) throw(format("TracePlus.Bbox: 'ignoreEntities' array/list contains a not-valid entity at index %d", idx))
                if (typeof ent != "pcapEntity" && !(ent instanceof CBaseEntity)) {
                    throw(format("TracePlus.Bbox: 'ignoreEntities' array/list contains a non-entity value at index %d (got %s). It must contain only entity handles.", idx, typeof ent));
                }
            }
        } else if (ignoreType != "pcapEntity" && !(ignoreEntities instanceof CBaseEntity)) {
            throw("TracePlus.Bbox: 'ignoreEntities' argument must be an entity handle, an array/list of entities, or null, but got " + ignoreType);
        }
    }

    local SCOPE = {} // TODO potential place for improvement
    
    SCOPE.startpos <- startPos;
    SCOPE.endpos <- endPos;
    SCOPE.ignoreEntities <- ignoreEntities 
    SCOPE.settings <- settings

    local BboxAnalyzer = USE_LEGACY_BBOXCAST_ANALYZER ? LegacyBboxAnalyzer : BboxTraceAnalyzer
    local result = BboxAnalyzer(startPos, endPos, ignoreEntities, settings)
    
    return TracePlus.Result.Bbox(SCOPE, result.hitpos, result.hitent)
}

/*
 * Performs a bbox cast from the player's eyes. 
 *
 * @param {number} distance - The distance of the trace. 
 * @param {CBaseEntity|pcapEntity} player - The player entity.
 * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. (optional)
 * @param {TraceSettings} settings - The settings to use for the trace. (optional, defaults to TracePlus.defaultSettings) 
 * @returns {BboxTraceResult} - The trace result object. 
*/
TracePlus["FromEyes"]["Bbox"] <- function(distance, player, ignoreEntities = null, settings = TracePlus.defaultSettings) {
    // Calculate the start and end positions of the trace
    local startPos = player.EyePosition()
    local endPos = macros.GetEyeEndpos(player, distance)

    ignoreEntities = TracePlus.Settings.UpdateIgnoreEntities(ignoreEntities, player)

    // Perform the bboxcast trace and return the trace result
    return TracePlus.Bbox(startPos, endPos, ignoreEntities, settings)
}
/*
 * Applies portal transformations to a trace, calculating a new start and end position for the trace after passing through the portal. 
 *
 * @param {Vector} startPos - The original start position of the trace. 
 * @param {Vector} hitPos - The hit position of the trace on the portal. 
 * @param {int} rayDist - Distance of the new ray. 
 * @param {pcapEntity} portal - The portal entity. 
 * @param {pcapEntity} partnerPortal - The partner portal entity. 
 * @returns {table} - A table containing the new startPos and endPos for the trace after passing through the portal. 
*/ 
::_ApplyPortal <- function(startPos, hitPos, rayDist, portal, partnerPortal) {
    local portalAngles = portal.GetAngles();
    local partnerAngles = partnerPortal.GetAngles();
    local offset = math.vector.unrotate(hitPos - portal.GetOrigin(), portalAngles);
    local dir = math.vector.unrotate(hitPos - startPos, portalAngles);

    offset = Vector(offset.x * -1, offset.y * -1, offset.z)
    dir = Vector(dir.x * -1, dir.y * -1, dir.z)

    dir = math.vector.rotate(dir, partnerAngles)
    dir.Norm()

    local newStart = partnerPortal.GetOrigin() + math.vector.rotate(offset, partnerAngles)
    return {
        startPos = newStart,
        endPos = newStart + dir * rayDist
    }
}


/*
 * Performs a cheap trace with portal support. 
 * 
 * @param {Vector} startPos - The start position of the trace.
 * @param {Vector} endPos - The end position of the trace.  
 * @returns {CheapTraceResult} - The trace result object, including information about portal entries.
*/
TracePlus["PortalCheap"] <- function(startPos, endPos) {
    local length = (endPos - startPos).Length()
    local previousTraceData 
    // Portal castings
    for (local i = 0; i < MAX_PORTAL_CAST_DEPTH; i++) {
        local traceData = TracePlus.Cheap(startPos, endPos)
        traceData.portalEntryInfo = previousTraceData

        local hitPos = traceData.GetHitPos()
        length -= (hitPos - startPos).Length()

        // Find a nearby portal entity. 
        local portal = entLib.FindByClassnameWithin("prop_portal", hitPos, 5) 
        if(!portal)
            portal = entLib.FindByClassnameWithin("linked_portal_door", hitPos, 10)
        if(!portal)
            return traceData

        local normal = traceData.GetImpactNormal()
        if(normal.Dot(portal.GetForwardVector()) < 0.8)
            return traceData
        
        local partnerPortal = portal.GetPartnerInstance()
        if (partnerPortal == null) {
            return traceData 
        }

        // Calculate new start and end positions for the trace after passing through the portal. 
        local ray = _ApplyPortal(startPos, hitPos, length, portal, partnerPortal);
        // Adjust the start position slightly to prevent the trace from getting stuck.  
        startPos = ray.startPos + partnerPortal.GetForwardVector() 
        endPos = ray.endPos
        previousTraceData = traceData
    }
    return previousTraceData
}

/*
 * Performs a cheap trace with portal support from the player's eyes. 
 *
 * @param {number} distance - The distance of the trace. 
 * @param {CBaseEntity|pcapEntity} player - The player entity.
 * @returns {CheapTraceResult} - The trace result object.
*/
 TracePlus["FromEyes"]["PortalCheap"] <- function(distance, player) {
    // Calculate the start and end positions of the trace
    local startpos = player.EyePosition()
    local endpos = macros.GetEyeEndpos(player, distance)

    return TracePlus.PortalCheap(startpos, endpos)
}


/*
 * Performs a bbox cast with portal support. 
 * 
 * @param {Vector} startPos - The start position of the trace.
 * @param {Vector} endPos - The end position of the trace.
 * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. (optional) 
 * @param {TraceSettings} settings - The settings to use for the trace. (optional, defaults to TracePlus.defaultSettings) 
 * @returns {BboxTraceResult} - The trace result object, including information about portal entries.
*/
TracePlus["PortalBbox"] <- function(startPos, endPos, ignoreEntities = null, settings = TracePlus.defaultSettings) {
    local length = (endPos - startPos).Length()
    local previousTraceData 
    // Portal castings
    for (local i = 0; i < MAX_PORTAL_CAST_DEPTH; i++) {
        local traceData = TracePlus.Bbox(startPos, endPos, ignoreEntities, settings)
        traceData.portalEntryInfo = previousTraceData 

        local hitPos = traceData.GetHitPos()
        local portal = traceData.GetEntity()
        length -= (hitPos - startPos).Length()

        if(!portal || portal.GetClassname() != "linked_portal_door")
            portal = entLib.FindByClassnameWithin("prop_portal", hitPos, 1) // todo: i should optimize it...
        if(!portal) 
            return traceData 
        
        local partnerPortal = portal.GetPartnerInstance()
        if (partnerPortal == null) {
            dev.warning("Portal {} doesn't have a partner ;(", portal)
            return traceData 
        }
        
        if(portal.GetUserData("TracePlusIgnore") || partnerPortal.GetUserData("TracePlusIgnore"))
            return traceData

        if(portal.GetClassname() == "prop_portal") {
            local normal = traceData.GetImpactNormal()
            if(normal.Dot(portal.GetForwardVector()) < 0.8)
                return traceData
        }
        
        ignoreEntities = TracePlus.Settings.UpdateIgnoreEntities(ignoreEntities, partnerPortal)

        // Calculate new start and end positions for the trace after passing through the portal.  
        local ray = _ApplyPortal(startPos, hitPos, length, portal, partnerPortal);
        // Adjust the start position slightly to prevent the trace from getting stuck. 
        startPos = ray.startPos + partnerPortal.GetForwardVector() * 7 // Workaround to avoid the TraceLine starting inside a wall.
        endPos = ray.endPos
        previousTraceData = traceData 
    }
    return previousTraceData 
}

/* 
 * Performs a bbox cast with portal support from the player's eyes. 
 *
 * @param {number} distance - The distance of the trace. 
 * @param {CBaseEntity|pcapEntity} player - The player entity.
 * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. (optional)
 * @param {TraceSettings} settings - The settings to use for the trace. (optional, defaults to TracePlus.defaultSettings) 
 * @returns {BboxTraceResult} - The trace result object. 
*/
 TracePlus["FromEyes"]["PortalBbox"] <- function(distance, player, ignoreEntities = null, settings = TracePlus.defaultSettings) {
    // Calculate the start and end positions of the trace
    local startPos = player.EyePosition()
    local endPos = macros.GetEyeEndpos(player, distance)
    ignoreEntities = TracePlus.Settings.UpdateIgnoreEntities(ignoreEntities, player)

    // Perform the bboxcast trace and return the trace result
    return TracePlus.PortalBbox(startPos, endPos, ignoreEntities, settings)
}

// Enhanced entity cache with aggressive caching
class BufferedEntity {
    // todo: if this well be global and bbox will be changed, stuff broke
    entity = null;
    origin = null;
    bboxMax = null;
    bboxMin = null;

    // Cached rounded origin
    roundedOriginX = null;
    roundedOriginY = null;
    roundedOriginZ = null;
    
    // Cached expensive C++ calls
    classname = null;
    modelname = null;
    entindex = null;
    
    // Optimization flags
    ignoreChecksCalc = false;
    skipEntity = false;
    
    // Cache for shouldHitEntity
    cachedShouldHit = null;
    cachedTraceId = null;  // ID of last trace
    // cachedSettingsId = null; // todo: maybe for future improvements

    constructor(entity) { 
        this.entity = entLib.FromEntity(entity)
        this.entindex = entity.entindex()  // Cache once!
        this.origin = entity.GetOrigin()
        this.classname = entity.GetClassname()  // Cache once!
        this.modelname = entity.GetModelName()  // Cache once!

        // round and CACHE!
        this.roundedOriginX = floor(this.origin.x * 1000.0 + 0.5)
        this.roundedOriginY = floor(this.origin.y * 1000.0 + 0.5)
        this.roundedOriginZ = floor(this.origin.z * 1000.0 + 0.5)

        // perhaps for future improvements
        // cachedSettingsId = id
        
        // This is needed for optimization with avoiding a lot of quaternion rotations
        if(this.entity.IsSquareBbox()) {
            this.bboxMax = entity.GetBoundingMaxs() + origin
            this.bboxMin = entity.GetBoundingMins() + origin
        }
        else {
            this.bboxMax = this.entity.CreateAABB(7) + origin
            this.bboxMin = this.entity.CreateAABB(0) + origin
        }
    }
    
    function _tostring() return this.entity.tostring()
}

::EntBufferTable <- {} // To avoid repeated operations on objects that do not change their position.
::_traceIdCounter <- 0 

/*
 * A class for performing precise trace line analysis. 
 * 
 * This class provides methods for tracing lines with more precision and considering entity priorities and ignore settings. 
*/
::BboxTraceAnalyzer <- class {
    settings = null;
    hitpos = null;
    hitent = null;
    hitnormal = null; // todo: this is cheap normal, but only for axis-box. How can i use it? no clue
    traceId = null;  

    /*
     * Constructor for BboxTraceAnalyzer.
     *
     * @param {Vector} startpos - The start position of the trace.
     * @param {Vector} endpos - The end position of the trace.
     * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. 
     * @param {TraceSettings} settings - The settings to use for the trace. 
    */ 
    constructor(startpos, endpos, ignoreEntities, settings) {
        if(typeof settings != "TraceSettings") throw("Invalid trace settings provided. Expected an instance of TracePlus.Settings")
        this.settings = settings
        this.traceId = _traceIdCounter++
        
        local result = this.Trace(startpos, endpos, ignoreEntities)
        this.hitpos = result[0]
        this.hitent = result[1]
        // this.hitnormal = result[2]
    }

    function Trace(startPos, endPos, ignoreEntities) array(hitPos, hitEnt, hitNormal) 
    function shouldHitEntityCached(BEnt, ignoreEntities) bool
    function _isPriorityEntity(classname) bool
    function _isIgnoredEntity(classname) bool
    function _isIgnoredModels(modelname) bool
}

/*
 * Performs a precise trace line analysis using analytical ray-AABB intersection. 
 *
 * This method subdivides the trace into segments and uses the slab method to find
 * exact intersection points with entity bounding boxes.
 * 
 * @param {Vector} startPos - The start position of the trace.
 * @param {Vector} endPos - The end position of the trace.
 * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. 
 * @returns {array} - An array containing [hitPos, hitEntity, hitNormal]. 
*/
function BboxTraceAnalyzer::Trace(startPos, endPos, ignoreEntities) {
    // Preventing VScript errors and ensuring correct results even with a broken TraceLine
    if(macros.PointInBounds(startPos) == false) return [startPos, null, null]

    // Get the hit position from the fast trace
    local hitPos = startPos + (endPos - startPos) * TraceLine(startPos, endPos, null)
    local dist = hitPos - startPos

    const JumpPercent = 0.25
    const HalfJump = 0.125
    local halfSegment = dist * HalfJump
    local searchRadius = halfSegment.Length()
    
    // Use array instead of List for better performance [// todo: maybe create with some capacity, or use global one with shadowing indecies? \\]
    local entBuffer = [] 
    
    // Pre-compute for quick ignore checks
    local ignoreType = ignoreEntities ? typeof ignoreEntities : null
    local singleIgnoreIdx = null
    if(ignoreType && ignoreType != "array" && ignoreType != "ArrayEx" && ignoreType != "List") {
        // if(ignoreType == "instance" || ignoreType == "pcapEntity") { 
        try {
            singleIgnoreIdx = ignoreEntities.entindex()
        } catch(e) {}
    }

    // Pre-compute ignoreIdxSet for O(1) lookup
    local ignoreIdxSet = {}
    if(ignoreType == "array" || ignoreType == "ArrayEx") {
        foreach(mask in ignoreEntities) ignoreIdxSet[mask.entindex()] <- true
    } else if(ignoreType == "List") {
        foreach(mask in ignoreEntities.iter()) ignoreIdxSet[mask.entindex()] <- true
    }

    dev.debug("========================= TRACE START =========================")
    for(local segment = 0.0; segment < 1.0; segment += JumpPercent) {
        //* "DIRTY" Search - collect candidate entities near the current segment
        local segmentCenter = startPos + dist * (segment + HalfJump)
        local segmentStart = segmentCenter - halfSegment
        local segmentEnd = segmentCenter + halfSegment

        for(local ent; ent = Entities.FindByClassnameWithin(ent, "*", segmentCenter, searchRadius);) {
            local idx = ent.entindex()
            
            // == Avoid expensive shouldHitEntity == 
            // 1. Quick single-entity ignore check
            if(singleIgnoreIdx != null && idx == singleIgnoreIdx) continue
            // 2.Entity should 'Ignore Trace' check // todo change comment
            if((ent in TracePlusIgnoreEnts) && TracePlusIgnoreEnts[ent] == true) continue
            // 3. Ignore entities set check
            if(idx in ignoreIdxSet) continue

            local BEnt = null
            
            // Optimized cache check with inline Vector comparison :p
            if(idx in EntBufferTable) { 
                BEnt = EntBufferTable[idx]
                if(BEnt.entity.IsValid()) {
                    local cachedOrigin = BEnt.origin
                    local currentOrigin = ent.GetOrigin()
                    
                    // Inline rounded comparison
                    local rx = floor(currentOrigin.x * 1000.0 + 0.5)
                    local ry = floor(currentOrigin.y * 1000.0 + 0.5)
                    local rz = floor(currentOrigin.z * 1000.0 + 0.5)
                    if(BEnt.roundedOriginX == rx && 
                        BEnt.roundedOriginY == ry && 
                        BEnt.roundedOriginZ == rz) {
                        // Cache hit - entity hasn't moved
                    } else {
                        // Position changed - rebuild cache
                        BEnt = BufferedEntity(ent)
                        BEnt.cachedTraceId = this.traceId
                        EntBufferTable[idx] <- BEnt
                    }
                } else {
                    // Weird... Invalid/outdated entity with same id - let's rebuild
                    BEnt = BufferedEntity(ent)
                    BEnt.cachedTraceId = this.traceId
                    // BEnt.cachedSettingsId = this.settings.id
                    EntBufferTable[idx] <- BEnt
                }
            } else {
                // Not in cache - create new
                BEnt = BufferedEntity(ent)
                BEnt.cachedTraceId = this.traceId
                EntBufferTable[idx] <- BEnt
            }
            
            // Check shouldHitEntity, now with caching :}
            if(!this.shouldHitEntityCached(BEnt)) continue
            

            // This handles the specific case where the trace starts *inside* an entity's bounding box.
            if(segment == 0.0 && macros.PointInBBox(startPos, BEnt.bboxMin, BEnt.bboxMax)) {
                BEnt.skipEntity = true
                continue
            }
            if(BEnt.skipEntity) continue

            // Quick broad-phase check
            if(BEnt.ignoreChecksCalc || RayAabbIntersectFast(segmentStart, segmentEnd, BEnt.bboxMin, BEnt.bboxMax)) {
                dev.debug("Added {}", BEnt.entity) // DEBUG
                entBuffer.append(BEnt)
            } else {
                BEnt.ignoreChecksCalc = true
            }
        }

        // The "dirty search" didn't turn up anything? Check the next segment
        if(entBuffer.len() == 0) continue

        //* Analytic narrow-phase: compute exact hit using 'slab method'
        local bestT = 999999999.9
        local bestEnt = null
        local bestNormal = null

        foreach(BEnt in entBuffer) {
            // Get precise intersection data using optimized slab method [i actually unrolled loop, lol]
            local res = RayAabbHitOptimized(segmentStart, segmentEnd, BEnt.bboxMin, BEnt.bboxMax)
            if(!res[0]) continue

            local tEnter = res[1]
            // Clamp to valid range [0, 1]
            if(tEnter < 0.0) tEnter = 0.0
            else if(tEnter > 1.0) tEnter = 1.0

            // Keep track of the closest hit
            if(tEnter < bestT) {
                bestT = tEnter
                bestEnt = BEnt
                bestNormal = res[3]
            }
        }

        // If we found a hit in this segment, return immediately
        if(bestEnt != null) {
            local hitPoint = segmentStart + (segmentEnd - segmentStart) * bestT

            // Optional: refine the hit point (only if needed and worth the cost)
            if(this.settings.bynaryRefinement && bestT > 0.01 && bestT < 0.99) {
                local refined = BinaryRefinementSearchFast(segmentStart, segmentEnd, bestEnt.bboxMin, bestEnt.bboxMax, bestT)
                if(refined != null) hitPoint = refined
            }
            
            return [hitPoint, bestEnt.entity, bestNormal]
        }
        
        // Clear buffer for next segment
        entBuffer.clear()
    }

    // No entity was hit; return world hit position
    return [hitPos, null, null]
}

/*
 * Optimized AABB intersection - unrolled loop, fewer operations.
 * 
 * @param {Vector} start - The start point of the ray segment.
 * @param {Vector} end - The end point of the ray segment. 
 * @param {Vector} bmin - The minimum corner of the AABB.
 * @param {Vector} bmax - The maximum corner of the AABB.
 * @returns {array} - [hit:boolean, t_enter:float, t_exit:float, normal:Vector|null]
*/
function RayAabbHitOptimized(start, end, bmin, bmax) {
    // Pre-compute direction once
    local dx = end.x - start.x
    local dy = end.y - start.y  
    local dz = end.z - start.z
    const EPS = 0.000001

    local tEnter = 0.0
    local tExit = 1.0
    local nAxis = -1
    local nSign = 0.0

    // Unrolled X axis
    local adx = fabs(dx)
    if(adx < EPS) {
        if(start.x < bmin.x || start.x > bmax.x) return [false, 0, 0, null]
    } else {
        local invDx = 1.0 / dx
        local t1 = (bmin.x - start.x) * invDx
        local t2 = (bmax.x - start.x) * invDx
        
        if(t1 > t2) {
            if(t2 > tEnter) { tEnter = t2; nAxis = 0; nSign = 1.0 }
            if(t1 < tExit) tExit = t1
        } else {
            if(t1 > tEnter) { tEnter = t1; nAxis = 0; nSign = -1.0 }
            if(t2 < tExit) tExit = t2
        }
        if(tEnter > tExit) return [false, 0, 0, null]
    }

    // Unrolled Y axis
    local ady = fabs(dy)
    if(ady < EPS) {
        if(start.y < bmin.y || start.y > bmax.y) return [false, 0, 0, null]
    } else {
        local invDy = 1.0 / dy
        local t1 = (bmin.y - start.y) * invDy
        local t2 = (bmax.y - start.y) * invDy
        
        if(t1 > t2) {
            if(t2 > tEnter) { tEnter = t2; nAxis = 1; nSign = 1.0 }
            if(t1 < tExit) tExit = t1
        } else {
            if(t1 > tEnter) { tEnter = t1; nAxis = 1; nSign = -1.0 }
            if(t2 < tExit) tExit = t2
        }
        if(tEnter > tExit) return [false, 0, 0, null]
    }

    // Unrolled Z axis
    local adz = fabs(dz)
    if(adz < EPS) {
        if(start.z < bmin.z || start.z > bmax.z) return [false, 0, 0, null]
    } else {
        local invDz = 1.0 / dz
        local t1 = (bmin.z - start.z) * invDz
        local t2 = (bmax.z - start.z) * invDz
        
        if(t1 > t2) {
            if(t2 > tEnter) { tEnter = t2; nAxis = 2; nSign = 1.0 }
            if(t1 < tExit) tExit = t1
        } else {
            if(t1 > tEnter) { tEnter = t1; nAxis = 2; nSign = -1.0 }
            if(t2 < tExit) tExit = t2
        }
        if(tEnter > tExit) return [false, 0, 0, null]
    }

    // Final range check
    if(tExit < 0.0 || tEnter > 1.0) return [false, 0, 0, null]

    // todo; Build cheap normal vector - only if we have a hit
    // local n = Vector(0, 0, 0) 
    // if(nAxis == 0) n.x = nSign
    // else if(nAxis == 1) n.y = nSign
    // else n.z = nSign

    return [true, tEnter, tExit, null]
}

/*
 * Fast AABB intersection check for broad phase (no normal calculation).
 * 
 * @param {Vector} start - Ray start point.
 * @param {Vector} end - Ray end point.
 * @param {Vector} bmin - AABB minimum.
 * @param {Vector} bmax - AABB maximum.
 * @returns {boolean} - True if intersection exists.
*/
function RayAabbIntersectFast(start, end, bmin, bmax) {
    local dx = end.x - start.x
    local dy = end.y - start.y
    local dz = end.z - start.z
    
    local tmin = 0.0
    local tmax = 1.0
    
    // X axis - optimized with early exit
    if(dx != 0.0) {
        local invDx = 1.0 / dx
        local t1 = (bmin.x - start.x) * invDx
        local t2 = (bmax.x - start.x) * invDx
        if(t1 > t2) { local tmp = t1; t1 = t2; t2 = tmp }
        if(t1 > tmin) tmin = t1
        if(t2 < tmax) tmax = t2
        if(tmin > tmax) return false
    } else if(start.x < bmin.x || start.x > bmax.x) return false
    
    // Y axis
    if(dy != 0.0) {
        local invDy = 1.0 / dy
        local t1 = (bmin.y - start.y) * invDy
        local t2 = (bmax.y - start.y) * invDy
        if(t1 > t2) { local tmp = t1; t1 = t2; t2 = tmp }
        if(t1 > tmin) tmin = t1
        if(t2 < tmax) tmax = t2
        if(tmin > tmax) return false
    } else if(start.y < bmin.y || start.y > bmax.y) return false
    
    // Z axis
    if(dz != 0.0) {
        local invDz = 1.0 / dz
        local t1 = (bmin.z - start.z) * invDz
        local t2 = (bmax.z - start.z) * invDz
        if(t1 > t2) { local tmp = t1; t1 = t2; t2 = tmp }
        if(t1 > tmin) tmin = t1
        if(t2 < tmax) tmax = t2
        if(tmin > tmax) return false
    } else if(start.z < bmin.z || start.z > bmax.z) return false
    
    return true
}

/*
 * Optimized binary refinement - fewer iterations, smarter window.
 * 
 * @param {Vector} rayStart - Ray segment start.
 * @param {Vector} rayEnd - Ray segment end.
 * @param {Vector} bMin - AABB minimum.
 * @param {Vector} bMax - AABB maximum.
 * @param {float} tEnter - Approximate entry point.
 * @returns {Vector|null} - Refined hit point or null.
*/
function BinaryRefinementSearchFast(rayStart, rayEnd, bMin, bMax, tEnter) {
    // Narrow window around tEnter
    local dir = rayEnd - rayStart
    local window = 0.03  // Smaller window = fewer checks
    local leftT = tEnter - window
    local rightT = tEnter + window
    if(leftT < 0.0) leftT = 0.0
    if(rightT > 1.0) rightT = 1.0
    
    local searchStart = rayStart + dir * leftT
    local searchEnd = rayStart + dir * rightT
    local searchDir = searchEnd - searchStart
    
    local closestHitPoint = null
    local left = 0.0
    local right = 1.0

    // Reduced iterations: 6 instead of 10 (good enough precision)
    for(local i = 0; i < 6; i++) {
        local middle = (left + right) * 0.5  // Avoid division
        local currentPoint = searchStart + searchDir * middle
        
        // Inline PointInBBox for speed
        if(currentPoint.x >= bMin.x && currentPoint.x <= bMax.x &&
           currentPoint.y >= bMin.y && currentPoint.y <= bMax.y &&
           currentPoint.z >= bMin.z && currentPoint.z <= bMax.z) {
            closestHitPoint = currentPoint
            right = middle
        } else {
            left = middle
        }
    }
    
    return closestHitPoint
}

/*
 * Cached version of shouldHitEntity to avoid redundant checks.
 * 
 * @param {BufferedEntity} BEnt - Buffered entity with cache.
 * @returns {boolean} - True if should check for hit.
*/
function BboxTraceAnalyzer::shouldHitEntityCached(BEnt) {
    // Try use cached result
    if(BEnt.cachedTraceId == this.traceId && BEnt.cachedShouldHit != null) {
        return BEnt.cachedShouldHit
    }
    
    local ent = BEnt.entity.CBaseEntity
    
    // Settings filters
    if(settings.ApplyIgnoreFilter(ent)) {
        dev.debug("- {} IgnoreFilter", ent)
        BEnt.cachedShouldHit = false
        return false
    }
    
    if(settings.ApplyCollisionFilter(ent)) {
        dev.debug("- {} CollisionFilter", ent)
        BEnt.cachedShouldHit = true
        return true
    }

    // Use cached classname and modelname (no C++ calls!)
    if(_isIgnoredEntity(BEnt.classname) && !_isPriorityEntity(BEnt.classname)) {
        dev.debug("- {} _isIgnoredEntity", ent)
        BEnt.cachedShouldHit = false
        return false
    }
    
    if(_isIgnoredModels(BEnt.modelname)) {
        dev.debug("- {} _isIgnoredModels", ent)
        BEnt.cachedShouldHit = false
        return false
    }

    dev.debug("- {} none of all, then should!", ent)
    BEnt.cachedShouldHit = true
    return true
}

/*
 * Check if entity class is in the priority list.
 *
 * @param {string} entityClass - Entity class name to check.
 * @returns {boolean} True if entity class is prioritized.
*/
function BboxTraceAnalyzer::_isPriorityEntity(entityClass) {
    if(settings.GetPriorityClasses().len() == 0) return false
    return settings.GetPriorityClasses().search(function(v) : (entityClass) { 
        return entityClass.find(v) >= 0 
    }) != null
}

/* 
 * Check if entity class should be ignored.
 *
 * @param {string} entityClass - Entity class name to check.
 * @returns {boolean} True if entity class should be ignored.
*/
function BboxTraceAnalyzer::_isIgnoredEntity(entityClass) {
    if(settings.GetIgnoreClasses().len() == 0) return false
    if(settings.GetIgnoreClasses().contains("*")) return true
    return settings.GetIgnoreClasses().search(function(v) : (entityClass) { 
        return entityClass.find(v) >= 0 
    }) != null
}

/* 
 * Check if entity model is in the ignored models list.
 *
 * @param {string} entityModel - The model name of the entity.
 * @returns {boolean} True if the model should be ignored.
*/
function BboxTraceAnalyzer::_isIgnoredModels(entityModel) {
    if(settings.GetIgnoredModels().len() == 0 || entityModel == "") return false
    return settings.GetIgnoredModels().search(function(v) : (entityModel) { 
        return entityModel.find(v) >= 0 
    }) != null
}
const LegacyJumpPercent = 0.25

/*
 * TODO
*/
::LegacyBboxAnalyzer <- class {
    settings = null;
    hitpos = null;
    hitent = null;

    /*
     * Constructor for LegacyBboxAnalyzer.
     *
     * @param {Vector} startpos - The start position of the trace.
     * @param {Vector} endpos - The end position of the trace.
     * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. 
     * @param {TraceSettings} settings - The settings to use for the trace. 
    */ 
    constructor(startpos, endpos, ignoreEntities, settings) {
        if(typeof settings != "TraceSettings") throw("Invalid trace settings provided. Expected an instance of TracePlus.Settings")
        this.settings = settings
        
        local result = this.Trace(startpos, endpos, ignoreEntities)
        this.hitpos = result[0]
        this.hitent = result[1]
    }
}

/*
 * Performs a precise trace line analysis. 
 *
 * This method subdivides the trace into smaller segments and checks for entity collisions along the way, 
 * considering entity priorities and ignore settings.
 * 
 * @param {Vector} startPos - The start position of the trace.
 * @param {Vector} endPos - The end position of the trace.
 * @param {array|CBaseEntity|null} ignoreEntities - A list of entities or a single entity to ignore during the trace. 
 * @returns {array} - An array containing the hit position and the hit entity (or null). 
*/
function LegacyBboxAnalyzer::Trace(startPos, endPos, ignoreEntities) {
    // Preventing VScript errors and ensuring correct results even with a broken TraceLine
    if(macros.PointInBounds(startPos) == false) return [startPos, null]
    
    // Get the hit position from the fast trace
    local hitPos = startPos + (endPos - startPos) * TraceLine(startPos, endPos, null)
    local dist = hitPos - startPos
    local entBuffer = List()

    local halfSegment = dist * LegacyJumpPercent * 0.5
    local segmentsLenght = halfSegment * 2
    local searchRadius = halfSegment.Length()
    local searchSteps = searchRadius / this.settings.depthAccuracy
   
    for(local segment = 0; segment < 1; segment += LegacyJumpPercent) {

        //* "DIRTY" Search
        local segmentCenter = startPos + dist * (segment + LegacyJumpPercent * 0.5)
        // dev.drawbox(segmentCenter, Vector(255,0,0), 6)
        for (local ent; ent = Entities.FindByClassnameWithin(ent, "*", segmentCenter, searchRadius);) {
            if (!ent || !this.shouldHitEntity(ent, ignoreEntities)) continue

            local idx = ent.entindex()
            local BEnt = null
            // small cache system
            if(idx in EntBufferTable && EntBufferTable[idx].entity.IsValid() && this.math.vector.IsEqual(EntBufferTable[idx].origin, ent.GetOrigin())) {
                BEnt = EntBufferTable[idx]
            }
            else {
                BEnt = BufferedEntity(ent)
                EntBufferTable[idx] <- BEnt
            }

            // This handles the specific case where the trace starts *inside* an entity's bounding box.
            // It's crucial for allowing traces to originate from within large volumes (e.g., a trigger_multiple)
            // without immediately hitting that volume itself. The entity is flagged and will be ignored
            // for the entire duration of this trace, allowing the ray to 'escape' and hit what's next.
            if(segment==0 && macros.PointInBBox(startPos, BEnt.bboxMin, BEnt.bboxMax)) {
                BEnt.skipEntity = true
                continue
            }

            if(BEnt.skipEntity) {
                continue
            }
            
            if(BEnt.ignoreChecksCalc || RayAabbIntersectFast(startPos, endPos, BEnt.bboxMin, BEnt.bboxMax)) 
                entBuffer.append(BEnt)
            else BEnt.ignoreChecksCalc = true

        }

        // The "dirty search" didn't turn up anything? Check the next segment
        if(entBuffer.len() == 0) continue
        
        //* Deep Search
        local segmentStart = segmentCenter - halfSegment
        for (local i = 0.0; i <= searchSteps; i++) {
            local rayPart = segmentStart + segmentsLenght * (i / searchSteps)
            
            foreach(ent in entBuffer.iter()) {
                if(macros.PointInBBox(rayPart, ent.bboxMin, ent.bboxMax)) {
                    if(this.settings.bynaryRefinement) 
                        return [BinaryRefinementSearch(rayPart - halfSegment * 0.5, rayPart + halfSegment * 0.5, ent.bboxMin, ent.bboxMax), ent.entity]
                    return [rayPart, ent.entity] // VSquirrel doesn't support tuples, so i use arrays
                }
            }

        }
        

        // Cleanup buffer
        entBuffer.clear()
    }

    // Is entiti not found? Returning hitpos
    return [hitPos, null]
}

function RayAabbIntersect(start, end, min, max) { // todo: can i use RayAabbIntersectFast for this?
    local dir = end - start;

    local tEnter = -999999.0;
    local tExit = 999999.0;

    foreach(axis in ["x", "y", "z"]) {
        local startVal = start[axis];
        local minVal = min[axis];
        local maxVal = max[axis];
        local dirVal = dir[axis];

        if (fabs(dirVal) < 0.000001) {
            if (startVal < minVal || startVal > maxVal) {
                return false;
            }
        } else {
            local tMin = (minVal - startVal) / dirVal;
            local tMax = (maxVal - startVal) / dirVal;

            if (tMin > tMax) {
                local temp = tMin;
                tMin = tMax;
                tMax = temp;
            }

            if (tMin > tEnter)
                tEnter = tMin;
            
            if (tMax < tExit)
                tExit = tMax;

            if (tEnter > tExit)
                return false;
        }
    }

    return tExit >= 0.0 && tEnter <= 1.0;
}


function BinaryRefinementSearch(rayStart, rayEnd, bMin, bMax) {
    // Binary search between rayStart and rayEnd
    local closestHitPoint = null
    local left = 0.0
    local right = 1.0

    for(local i = 0; i < 10; i++) {
        local middle = (left + right) / 2.0
        local currentPoint = rayStart + (rayEnd - rayStart) * middle

        if(macros.PointInBBox(currentPoint, bMin, bMax)) {
            // If a point is inside bbox, we store it as a potential hit point
            closestHitPoint = currentPoint
            // Keep searching closer to the beginning (left half of the segment)
            right = middle
        } 
        // If the point is outside bbox, continue searching near the end (right half of the segment)
        else left = middle
        
    }

    return closestHitPoint
}

/*
* Check if entity should be ignored.
*
* @param {Entity} ent - Entity to check.
* @param {Entity|array} ignoreEntities - Entities being ignored. 
* @returns {boolean} True if should ignore.
*/
function LegacyBboxAnalyzer::shouldHitEntity(ent, ignoreEntities) { 
    if(ent in TracePlusIgnoreEnts && TracePlusIgnoreEnts[ent])
        return false
    
    if(settings.ApplyIgnoreFilter(ent))
        return false

    if(settings.ApplyCollisionFilter(ent))
        return true

    if(ignoreEntities) {
        // Processing for arrays
        local type = typeof ignoreEntities 
        if (type == "array" || type == "ArrayEx") {
            foreach (mask in ignoreEntities) {
                if(ent.entindex() == mask.entindex()) return false 
            }
        } 
        else if(type == "List") {
            foreach (mask in ignoreEntities.iter()) {
                if(ent.entindex() == mask.entindex()) return false 
            }
        }
        // (ignoreEntities instanceof CBaseEntity || type == "pcapEntity") 
        else if(ent.entindex() == ignoreEntities.entindex()) return false
    }

    local classname = ent.GetClassname()
    if (_isIgnoredEntity(classname) && !_isPriorityEntity(classname)) {
        return false
    }
    
    if(_isIgnoredModels(ent.GetModelName())) {
        return false
    }

    return true
}

/*
* Check if entity is a priority class.
*
* @param {string} entityClass - Entity class name.
* @returns {boolean} True if priority.
*/
function LegacyBboxAnalyzer::_isPriorityEntity(entityClass) {
    if(settings.GetPriorityClasses().len() == 0) 
        return false
    return settings.GetPriorityClasses().search(function(val):(entityClass) {
        return entityClass.find(val) >= 0
    }) != null
}

/* 
* Check if entity is an ignored class.
*
* @param {string} entityClass - Entity class name.
* @returns {boolean} True if ignored.
*/
function LegacyBboxAnalyzer::_isIgnoredEntity(entityClass) {
    if(settings.GetIgnoreClasses().len() == 0) 
        return false
    if(settings.GetIgnoreClasses().contains("*"))
        return true
    return settings.GetIgnoreClasses().search(function(val):(entityClass) {
        return entityClass.find(val) >= 0
    }) != null
}

/* 
* Check if the entity model is in the list of ignored models.
*
* @param {string} entityModel - The model name of the entity.
* @returns {boolean} True if the model is ignored, false otherwise. 
*/
function LegacyBboxAnalyzer::_isIgnoredModels(entityModel) {
    if(settings.GetIgnoredModels().len() == 0 || entityModel == "") 
        return false
    return settings.GetIgnoredModels().search(function(val):(entityModel) {
        return entityModel.find(val) >= 0
    }) != null
}
/*
 * Calculates the normal vector of a triangle.
 * * @param {Vector} v1 - The first vertex. 
 * @param {Vector} v2 - The second vertex.
 * @param {Vector} v3 - The third vertex. 
 * @returns {Vector} - The normal vector of the triangle. 
*/
::_calculateNormal <- function(v1, v2, v3) {
    // Calculate two edge vectors of the triangle. 
    local edge1 = v2 - v1
    local edge2 = v3 - v1

    // Calculate the normal vector using the cross product of the edge vectors.
    local normal = edge1.Cross(edge2)
    normal.Norm()

    return normal 
}

// Fast coordinate system transformations
function _worldToLocal(entity, worldPoint, R) {
    local origin = entity.GetOrigin()
    return R.unrotateVector(worldPoint - origin)
}
function _localDirToWorld(localDir, R) {
    // For normal/direction: rotation only, no translation
    return R.rotateVector(localDir)
}


/* * Calculates the impact normal of a surface hit by a trace. 
 *
 * @param {Vector} startPos - The start position of the trace.
 * @param {Vector} hitPos - The hit position of the trace.
 * @returns {Vector} - The calculated impact normal vector. 
*/
::CalculateImpactNormal <- function(startPos, hitPos) {
    const offset = 5.0;
    local dir = hitPos - startPos; dir.Norm()

    // Ortho Basis
    local up = abs(dir.z) < 0.99 ? Vector(0,0,1) : Vector(0,1,0)
    local right = dir.Cross(up); right.Norm()
    local up2 = right.Cross(dir); up2.Norm()

    local newStart1 = startPos + right * offset
    local newStart2 = startPos + up2 * offset
    local endPos1   = newStart1 + dir * 8000
    local endPos2   = newStart2 + dir * 8000

    local fraction1 = TraceLine(newStart1, endPos1, null)
    local fraction2 = TraceLine(newStart2, endPos2, null)
    local point1    = newStart1 + (endPos1 - newStart1) * fraction1
    local point2    = newStart2 + (endPos2 - newStart2) * fraction2

    local normal = _calculateNormal(hitPos, point1, point2)
    if (normal.Dot(dir) > 0) normal = normal * -1.0
    return normal
}

::CalculateImpactNormalFromBbox <- function(startPos, hitPos, hitEntity) {
    // Construct rotation matrix
    local angles = hitEntity.GetAngles()
    local R = math.Matrix().fromEuler(angles)  // local -> world

    // Transform hit point to local space
    local localHit = _worldToLocal(hitEntity, hitPos, R)

    // Get local AABB bounds (engine always stores them in local space)
    local bmin = hitEntity.GetBoundingMins()
    local bmax = hitEntity.GetBoundingMaxs()

    // Find the nearest plane
    local distXmin = fabs(localHit.x - bmin.x)
    local distXmax = fabs(bmax.x - localHit.x)
    local distYmin = fabs(localHit.y - bmin.y)
    local distYmax = fabs(bmax.y - localHit.y)
    local distZmin = fabs(localHit.z - bmin.z)
    local distZmax = fabs(bmax.z - localHit.z)

    local axis = 0   // 0=X,1=Y,2=Z
    local sign = -1.0
    local best = distXmin

    if (distXmax < best) { best = distXmax; axis = 0; sign =  1.0 }
    if (distYmin < best) { best = distYmin; axis = 1; sign = -1.0 }
    if (distYmax < best) { best = distYmax; axis = 1; sign =  1.0 }
    if (distZmin < best) { best = distZmin; axis = 2; sign = -1.0 }
    if (distZmax < best) { best = distZmax; axis = 2; sign =  1.0 }

    // Local normal of that plane
    local nLocal = Vector(0,0,0)
    if (axis == 0) nLocal.x = sign
    else if (axis == 1) nLocal.y = sign
    else nLocal.z = sign

    // Rotate normal back to world space
    local nWorld = _localDirToWorld(nLocal, R)
    nWorld.Norm()

    // Ensure the normal points AGAINST the trace direction
    local traceDir = (hitPos - startPos); traceDir.Norm()
    if (nWorld.Dot(traceDir) > 0) nWorld = nWorld * -1.0

    return nWorld
}

// todo inline all

/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Animation Alchemist - laVashik ¬_¬                                           |
+----------------------------------------------------------------------------------+ 
|       The Animations module, simplifying the creation of smooth and dynamic      |
|       animations for alpha, color, and object movement in your VScripts.         |
+----------------------------------------------------------------------------------+ */

::animate <- {
    RT = {}
}

::AnimEvent <- class {
    animName = null;
    eventName = null
    delay = 0
    globalDelay = 0
    frameInterval = 0
    maxFrames = 60.0
    autoOptimization = true
    output = null
    entities = []
    easeFunc = null;
    filterCallback = null;
    scope = null;

    /*
     * Constructor for an AnimEvent object. 
     *
     * @param {string} name - A name of type animation
     * @param {table} settings - A table containing animation settings.
     * @param {array} entities - An array of entities to animate.
     * @param {number} time - The duration of the animation in seconds.
    */
    constructor(name, table, ents, time = 0) {
        this.animName = name
        this.entities = _GetEntities(ents, name)
        this.delay = time
        
        this.eventName = macros.GetFromTable(table, "eventName", UniqueString(name + "_anim"))
        this.globalDelay = macros.GetFromTable(table, "globalDelay", 0)
        this.output = macros.GetFromTable(table, "output", null)
        this.scope = macros.GetFromTable(table, "scope", null)
        this.easeFunc = macros.GetFromTable(table, "ease", function(t) return t)
        this.filterCallback = macros.GetFromTable(table, "filterCallback", function(a,b,c,d,e) return null)
        this.frameInterval = macros.GetFromTable(table, "frameInterval", FrameTime()) 
        this.maxFrames = macros.GetFromTable(table, "fps", 60.0)
        this.autoOptimization = macros.GetFromTable(table, "optimization", true)

        if(this.frameInterval == 0) throw("frameInterval is not to have 0")

        // If the class points to the root table, it will result in a circular reference. This fixed here
        if(this.scope == getroottable()) {
            this.scope = null
        }
    } 

    /* 
     * Calls the output associated with the animation event. 
    */
    function CallOutput() {
        if(this.output)
            ScheduleEvent.Add(this.eventName, this.output, this.delay + this.globalDelay, null, this.scope)
    }

    function _GetEntities(entities, actionName) {
        local type_of = typeof entities;
        if (type_of == "string") {
            local foundEnts = List(); // todo or array?
            if(entities.find("*") == null) {
                local ent = entLib.FindByName(entities);
                if (!ent) dev.warning(actionName + " AnimEvent: Could not find entity with name '" + entities + "'");
                else foundEnts.append(ent);
            }
            else {
                for(local ent; ent = entLib.FindByName(entities, ent);)
                    foundEnts.append(ent)
                if (foundEnts.len() == 0) dev.warning(actionName + " AnimEvent: Could not find any entities matching name pattern '" + entities + "'");
            }
            return foundEnts;
        }
                
        
        if (type_of == "array" || type_of == "ArrayEx" || type_of == "List") {
            foreach(idx, entity in entities) {
                if (!entity || !entity.IsValid()) {
                    dev.warning(actionName + " AnimEvent: An invalid or null entity was found in the 'entities' list at index " + idx);
                    continue;
                }
                if(typeof entity != "pcapEntity") 
                    entities[idx] = entLib.FromEntity(entity)
            }
            return entities
        }

        if (!entities || !entities.IsValid()) throw("AnimEvent: The provided 'entities' argument is not a valid entity.");

        if (type_of != "pcapEntity")
            return [entLib.FromEntity(entities)]
        
        return [entities]
    } 
}

/*
 * Applies an animation over a specified duration, calculating and setting new values for a property at each frame.
 * 
 * This function is used internally by the various animation functions to handle the animation process.
 * It calculates the new value for the property at each frame using the provided `valueCalculator` function and applies it to each entity using the `propertySetter` function.
 *
 * @param {AnimEvent} animInfo - The AnimEvent object containing the animation settings and entities.
 * @param {function} valueCalculator - A function that calculates the new value for the property at each frame.
 *    This function should take three arguments:
 *        * `step`: The current frame number (starting from 0).
 *        * `transitionFrames`: The total number of frames in the animation.
 *        * `vars`: Optional variables passed through the `vars` parameter.
 * @param {function} propertySetter - A function that sets the new value for the property on each entity.
 *    This function should take two arguments:
 *        * `entity`: The entity to apply the value to.
 *        * `newValue`: The calculated new value for the property.
 * @param {any} vars - Optional variable to pass to the `valueCalculator` function.
 *    This can be used to customize the animation behavior.
 * @param {number} transitionFrames - The total number of frames in the animation.
 *    If 0, it's calculated based on `animInfo.delay` and `animInfo.frameInterval`. (default: 0)
*/
animate["applyAnimation"] <- function(animInfo, valueCalculator, propertySetter, vars = null, transitionFrames = 0) {
    if(transitionFrames == 0) {
        if (animInfo.autoOptimization && animInfo.delay / animInfo.frameInterval > animInfo.maxFrames)  
            animInfo.frameInterval = animInfo.delay / animInfo.maxFrames
        
        transitionFrames = animInfo.delay / animInfo.frameInterval;
    }

    transitionFrames = ceil(transitionFrames) 
    local actionsList = List()

    for(local step = 0; step <= transitionFrames; step++) {
        local elapsed = (animInfo.frameInterval * step) + animInfo.globalDelay

        local newValue = valueCalculator(step, transitionFrames, vars)
        
        local iter = typeof animInfo.entities == "List" ? animInfo.entities.iter() : animInfo.entities
        foreach(ent in iter) {
            local action = ScheduleAction(this, propertySetter, elapsed, [ent, newValue])
            actionsList.append(action)
        }
    }

    ScheduleEvent.AddActions(animInfo.eventName, actionsList, true)
    animInfo.delay = animInfo.frameInterval * transitionFrames
    animInfo.CallOutput()

    if(developer() > 0) dev.trace("Created {} animation ({}) for {} actions", animInfo.animName, animInfo.eventName, actionsList.len())
}

/*
 * Facade function for applying real-time animations in an asynchronous environment.
 * 
 * This function schedules the real-time animation to be processed using `_applyRTAnimation`.
 * The actual animation is executed without pre-calculating all the frames, 
 * which allows for more flexibility, especially when handling long animations or situations where the animation might need to be interrupted.
 *
 * The arguments are the same as those for `applyAnimation`.
*/
animate["applyRTAnimation"] <- function(animInfo, valueCalculator, propertySetter, vars = null, transitionFrames = 0) {
    if(transitionFrames == 0) {
        if (animInfo.maxFrames * 10 != 600)  
            animInfo.frameInterval = animInfo.delay / animInfo.maxFrames
        
        transitionFrames = animInfo.delay / animInfo.frameInterval;
    }

    ScheduleEvent.Add(
        animInfo.eventName, 
        animate._applyRTAnimation, 
        animInfo.globalDelay, 
        [animInfo, valueCalculator, propertySetter, vars, transitionFrames], 
        this
    )

    // calc delay
    animInfo.delay = animInfo.frameInterval * transitionFrames
}

/*
 * Applies the animation in real-time, evaluating each frame as it occurs without pre-calculating.
 * 
 * This function works similarly to `applyAnimation`, but rather than calculating all the steps in advance,
 * it applies `propertySetter` in real-time for each frame. This is useful in cases where you might need
 * to interrupt or alter the animation at runtime using `filterCallback`, or if the animation is too long
 * for VSquirrel to process upfront.
*/
animate["_applyRTAnimation"] <- function(animInfo, valueCalculator, propertySetter, vars, transitionFrames) {
    // Round up the number of transition frames
    transitionFrames = ceil(transitionFrames);
    if (developer() > 0) dev.trace("Started {} realtime animation ({})", animInfo.animName, animInfo.eventName);

    // Helper function to process each animation step
    function processStep(step, animInfo, valueCalculator, propertySetter, vars, transitionFrames) {
        // Stop if all frames are processed
        if (step > transitionFrames) {
            animInfo.delay = 0;
            animInfo.globalDelay = 0;
            animInfo.CallOutput();
            return;
        }

        // Calculate the new property value
        local newValue = valueCalculator(step, transitionFrames, vars);

        // Stop if the filter callback signals to cancel the animation
        if (animInfo.filterCallback(animInfo, newValue, transitionFrames, step, vars)) {
            return;
        }

        // Apply the new value to all entities
        foreach(ent in animInfo.entities)
            propertySetter(ent, newValue)

        // Move to the next step
        ScheduleEvent.Add(
            animInfo.eventName,
            processStep,
            animInfo.frameInterval,
            [++step, animInfo, valueCalculator, propertySetter, vars, transitionFrames],
            this  
        );
    }

    // Start the animation
    processStep(0, animInfo, valueCalculator, propertySetter, vars, transitionFrames);
};



/*
 * Creates an animation that transitions the alpha (opacity) of entities over time.
 *
 * @param {array|CBaseEntity|pcapEntity} entities - The entities to animate.
 * @param {number} startOpacity - The starting opacity value (0-255). 
 * @param {number} endOpacity - The ending opacity value (0-255). 
 * @param {number} time - The duration of the animation in seconds. 
 * @param {table} animSetting - A table containing additional animation settings. (optional) 
 * @returns {number} The duration of the animation in seconds. 
*/
animate["AlphaTransition"] <- function(entities, startOpacity, endOpacity, time, animSetting = {}) {
    if (typeof time != "integer" && typeof time != "float")  throw("AlphaTransition: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                      throw("AlphaTransition: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("alpha", animSetting, entities, time)
    local vars = {
        startOpacity = startOpacity,
        opacityDelta = endOpacity - startOpacity,
        easeFunc = animSetting.easeFunc
    }

    animate.applyAnimation(
        animSetting, 
        function(step, steps, v) {return v.startOpacity + v.opacityDelta * v.easeFunc(step / steps)},
        function(ent, newAlpha) {ent.SetAlpha(newAlpha)},
        vars
    )
    
    return animSetting.delay
}

animate.RT["AlphaTransition"] <- function(entities, startOpacity, endOpacity, time, animSetting = {}) {
    if (typeof time != "integer" && typeof time != "float")  throw("AlphaTransition: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                      throw("AlphaTransition: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("alpha", animSetting, entities, time)
    local vars = {
        startOpacity = startOpacity,
        opacityDelta = endOpacity - startOpacity,
        easeFunc = animSetting.easeFunc
    }

    animate.applyRTAnimation(
        animSetting, 
        function(step, steps, v) {return v.startOpacity + v.opacityDelta * v.easeFunc(step / steps)},
        function(ent, newAlpha) {ent.SetAlpha(newAlpha)},
        vars
    )
    
    return animSetting.delay
}
/*
 * Creates an animation that transitions the color of entities over time.
 *
 * @param {array|CBaseEntity|pcapEntity} entities - The entities to animate.
 * @param {string|Vector} startColor - The starting color as a string (e.g., "255 0 0") or a Vector. 
 * @param {string|Vector} endColor - The ending color as a string or a Vector. 
 * @param {number} time - The duration of the animation in seconds. 
 * @param {table} animSetting - A table containing additional animation settings. (optional) 
 * @returns {number} The duration of the animation in seconds. 
*/
animate["ColorTransition"] <- function(entities, startColor, endColor, time, animSetting = {}) {
    if (typeof startColor != "Vector" && typeof startColor != "string")   throw("ColorTransition: 'startColor' argument must be a Vector, but got " + typeof startColor);
    if (typeof endColor != "Vector"   && typeof endColor != "string")   throw("ColorTransition: 'endColor' argument must be a Vector, but got " + typeof endColor);
    if (typeof time != "integer" && typeof time != "float")             throw("ColorTransition: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                                  throw("ColorTransition: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("color", animSetting, entities, time)
    local vars = {
        startColor = startColor,
        endColor = endColor,
        easeFunc = animSetting.easeFunc
    }

    animate.applyAnimation(
        animSetting, 
        function(step, transitionFrames, v) {return math.lerp.color(v.startColor, v.endColor, v.easeFunc(step / transitionFrames))},
        function(ent, newColor) {ent.SetColor(newColor)},
        vars
    )
    
    return animSetting.delay
}

animate.RT["ColorTransition"] <- function(entities, startColor, endColor, time, animSetting = {}) {
    if (typeof startColor != "Vector" && typeof startColor != "string")   throw("ColorTransition: 'startColor' argument must be a Vector, but got " + typeof startColor);
    if (typeof endColor != "Vector"   && typeof endColor != "string")   throw("ColorTransition: 'endColor' argument must be a Vector, but got " + typeof endColor);
    if (typeof time != "integer" && typeof time != "float")             throw("ColorTransition: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                                  throw("ColorTransition: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("color", animSetting, entities, time)
    local vars = {
        startColor = startColor,
        endColor = endColor,
        easeFunc = animSetting.easeFunc
    }

    animate.applyRTAnimation(
        animSetting, 
        function(step, transitionFrames, v) {return math.lerp.color(v.startColor, v.endColor, v.easeFunc(step / transitionFrames))},
        function(ent, newColor) {ent.SetColor(newColor)},
        vars
    )
    
    return animSetting.delay
}
/*
 * Creates an animation that transitions the position of entities over time.
 *
 * @param {array|CBaseEntity|pcapEntity} entities - The entities to animate.
 * @param {Vector} startPos - The starting position. 
 * @param {Vector} endPos - The ending position. 
 * @param {number} time - The duration of the animation in seconds. 
 * @param {table} animSetting - A table containing additional animation settings. (optional) 
 * @returns {number} The duration of the animation in seconds. 
*/
animate["PositionTransitionByTime"] <- function(entities, startPos, endPos, time, animSetting = {}) {
    if (typeof startPos != "Vector")                        throw("PositionTransitionByTime: 'startPos' argument must be a Vector, but got " + typeof startPos);
    if (typeof endPos != "Vector")                          throw("PositionTransitionByTime: 'endPos' argument must be a Vector, but got " + typeof endPos);
    if (typeof time != "integer" && typeof time != "float")  throw("PositionTransitionByTime: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                      throw("PositionTransitionByTime: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("position", animSetting, entities, time)
    local vars = {
        startPos = startPos,
        dist = endPos - startPos,
        easeFunc = animSetting.easeFunc
    }

    animate.applyAnimation(
        animSetting, 
        function(step, steps, v) {return v.startPos + v.dist * v.easeFunc(step / steps)},
        function(ent, newPosition) {ent.CBaseEntity.SetAbsOrigin(newPosition)},
        vars
    )
    
    return animSetting.delay
}

animate.RT["PositionTransitionByTime"] <- function(entities, startPos, endPos, time, animSetting = {}) {
    if (typeof startPos != "Vector")                        throw("PositionTransitionByTime: 'startPos' argument must be a Vector, but got " + typeof startPos);
    if (typeof endPos != "Vector")                          throw("PositionTransitionByTime: 'endPos' argument must be a Vector, but got " + typeof endPos);
    if (typeof time != "integer" && typeof time != "float")  throw("PositionTransitionByTime: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                      throw("PositionTransitionByTime: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("position", animSetting, entities, time)
    local vars = {
        startPos = startPos,
        dist = endPos - startPos,
        easeFunc = animSetting.easeFunc
    }

    animate.applyRTAnimation(
        animSetting, 
        function(step, steps, v) {return v.startPos + v.dist * v.easeFunc(step / steps)},
        function(ent, newPosition) {ent.CBaseEntity.SetAbsOrigin(newPosition)},
        vars
    )
    
    return animSetting.delay
}


/*
 * Creates an animation that transitions the position of entities over time based on a specified speed. 
 *
 * @param {array|CBaseEntity|pcapEntity} entities - The entities to animate.
 * @param {Vector} startPos - The starting position.
 * @param {Vector} endPos - The ending position.
 * @param {number} speed - The speed of the animation in units per tick.
 * @param {table} animSetting - A table containing additional animation settings. (optional)
 * 
 * The animation will calculate the time it takes to travel from the start position to the end position based on the specified speed. 
 * It will then use this time to create a smooth transition of the entities' positions over that duration.
 * @returns {number} The duration of the animation in seconds. 
*/
animate["PositionTransitionBySpeed"] <- function(entities, startPos, endPos, speed, animSetting = {}) {
    if (typeof startPos != "Vector")                        throw("PositionTransitionBySpeed: 'startPos' argument must be a Vector, but got " + typeof startPos);
    if (typeof endPos != "Vector")                          throw("PositionTransitionBySpeed: 'endPos' argument must be a Vector, but got " + typeof endPos);
    if (typeof speed != "integer" && typeof speed != "float")  throw("PositionTransitionBySpeed: 'speed' argument must be a number, but got " + typeof speed);
    if (typeof animSetting != "table")                      throw("PositionTransitionBySpeed: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("position", animSetting, entities)
    local vars = {
        startPos = startPos,
        dist = endPos - startPos,
        easeFunc = animSetting.easeFunc
    }
    
    animate.applyAnimation(
        animSetting, 
        function(step, steps, v) {return v.startPos + v.dist * v.easeFunc(step / steps)},
        function(ent, newPosition) {ent.CBaseEntity.SetAbsOrigin(newPosition)},
        vars,
        vars.dist.Length() / speed.tofloat() // steps
    )
    
    return animSetting.delay
} 

animate.RT["PositionTransitionBySpeed"] <- function(entities, startPos, endPos, speed, animSetting = {}) {
    if (typeof startPos != "Vector")                        throw("PositionTransitionBySpeed: 'startPos' argument must be a Vector, but got " + typeof startPos);
    if (typeof endPos != "Vector")                          throw("PositionTransitionBySpeed: 'endPos' argument must be a Vector, but got " + typeof endPos);
    if (typeof speed != "integer" && typeof speed != "float")  throw("PositionTransitionBySpeed: 'speed' argument must be a number, but got " + typeof speed);
    if (typeof animSetting != "table")                      throw("PositionTransitionBySpeed: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("position", animSetting, entities)
    local vars = {
        startPos = startPos,
        dist = endPos - startPos,
        easeFunc = animSetting.easeFunc
    }
    
    animate.applyRTAnimation(
        animSetting, 
        function(step, steps, v) {return v.startPos + v.dist * v.easeFunc(step / steps)},
        function(ent, newPosition) {ent.CBaseEntity.SetAbsOrigin(newPosition)},
        vars,
        vars.dist.Length() / speed.tofloat() // steps
    )
    
    return animSetting.delay
} 
/*
 * Creates an animation that transitions the angles of entities over time.
 *
 * @param {array|CBaseEntity|pcapEntity} entities - The entities to animate.
 * @param {Vector} startAngles - The starting angles. 
 * @param {Vector} endAngles - The ending angles. 
 * @param {number} time - The duration of the animation in seconds. 
 * @param {table} animSetting - A table containing additional animation settings. (optional) 
 * @returns {number} The duration of the animation in seconds. 
*/
animate["AnglesTransitionByTime"] <- function(entities, startAngles, endAngles, time, animSetting = {}) {
    if (typeof startAngles != "Vector")                     throw("AnglesTransitionByTime: 'startAngles' argument must be a Vector, but got " + typeof startAngles);
    if (typeof endAngles != "Vector")                       throw("AnglesTransitionByTime: 'endAngles' argument must be a Vector, but got " + typeof endAngles);
    if (typeof time != "integer" && typeof time != "float")  throw("AnglesTransitionByTime: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                      throw("AnglesTransitionByTime: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("angles", animSetting, entities, time)

    local deltaAngleX = ((((endAngles.x - startAngles.x) % 360) + 540) % 360) - 180;
    local deltaAngleY = ((((endAngles.y - startAngles.y) % 360) + 540) % 360) - 180;
    local deltaAngleZ = ((((endAngles.z - startAngles.z) % 360) + 540) % 360) - 180;
    
    local vars = {
        startAngles = startAngles,
        angleDelta = Vector(deltaAngleX, deltaAngleY, deltaAngleZ),
        easeFunc = animSetting.easeFunc
    }

    animate.applyAnimation(
        animSetting, 
        function(step, steps, v){return v.startAngles + v.angleDelta * v.easeFunc(step / steps)},
        function(ent, newAngle) {ent.SetAngles2(newAngle)},
        vars
    )
    
    return animSetting.delay
}

animate.RT["AnglesTransitionByTime"] <- function(entities, startAngles, endAngles, time, animSetting = {}) {
    if (typeof startAngles != "Vector")                     throw("AnglesTransitionByTime: 'startAngles' argument must be a Vector, but got " + typeof startAngles);
    if (typeof endAngles != "Vector")                       throw("AnglesTransitionByTime: 'endAngles' argument must be a Vector, but got " + typeof endAngles);
    if (typeof time != "integer" && typeof time != "float") throw("AnglesTransitionByTime: 'time' argument must be a number, but got " + typeof time);
    if (typeof animSetting != "table")                      throw("AnglesTransitionByTime: 'animSetting' argument must be a table, but got " + typeof animSetting);

    local animSetting = AnimEvent("angles", animSetting, entities, time)

    local deltaAngleX = ((((endAngles.x - startAngles.x) % 360) + 540) % 360) - 180;
    local deltaAngleY = ((((endAngles.y - startAngles.y) % 360) + 540) % 360) - 180;
    local deltaAngleZ = ((((endAngles.z - startAngles.z) % 360) + 540) % 360) - 180;
    
    local vars = {
        startAngles = startAngles,
        angleDelta = Vector(deltaAngleX, deltaAngleY, deltaAngleZ),
        easeFunc = animSetting.easeFunc
    }

    animate.applyRTAnimation(
        animSetting, 
        function(step, steps, v){return v.startAngles + v.angleDelta * v.easeFunc(step / steps)},
        function(ent, newAngle) {ent.SetAngles2(newAngle)},
        vars
    )
    
    return animSetting.delay
}

/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Game Event Guru - laVashik >_<                                               |
+----------------------------------------------------------------------------------+
|   The Script Events module, empowering you to create and handle custom           |
|   "game events" with triggers, filters, and actions,                             |
|   surpassing the limitations of standard VScripts game events.                   |
+----------------------------------------------------------------------------------+ */

::AllScriptEvents <- {}

/* 
 * Listens for and handles custom "game events".
*/
::EventListener <- {
    /*
     * Notifies the listener of a triggered event.
     *
     * @param {string} eventName - The name of the triggered event.
     * @param {any} ... - Optional arguments associated with the event. 
     * @returns {any|null} - The result of the event's action, or null if the event is not found or the filter fails. 
    */
    function Notify(eventName, ...) {
        if((eventName in AllScriptEvents) == false)
            return dev.warning("Unknown VGameEvent {" + eventName + "}")

        local varg = array(vargc)
        for(local i = 0; i< vargc; i++) {
            varg[i] = vargv[i]
        }

        return AllScriptEvents[eventName].Trigger(varg)
        
    }
    
    /* 
     * Gets a VGameEvent object by name. 
     * 
     * @param {string} eventName - The name of the event to retrieve. 
     * @returns {VGameEvent|null} - The VGameEvent object, or null if the event is not found. 
    */
    function GetEvent(eventName) {
        return eventName in AllScriptEvents ? AllScriptEvents[eventName] : null
    }
}
/*
 * Represents a custom "game event". 
 * 
 * This class allows you to create and manage custom "game events" with triggers, filters, and actions. 
*/
::VGameEvent <- class {
    // The name of the event.  
    eventName = null; 
    // The number of times the event can be triggered before it becomes inactive (-1 for unlimited triggers). 
    triggerCount = null; 
    // The actions to be performed when the event is triggered. 
    actions = null; 
    // A filter function to check conditions before triggering the event.  
    filterFunction = null; 

    // Constructor for initializing the VGameEvent
    /*
     * Constructor for a VGameEvent object.
     *
     * @param {string} eventName - The name of the event.
     * @param {number} triggerCount - The number of times the event can be triggered (-1 for unlimited). (optional, default=-1) 
     * @param {function} actionsList - The action to be performed when the event is triggered. (optional) 
    */
    constructor(eventName, triggerCount = -1, actionsList = null) {
        this.eventName = eventName
        this.triggerCount = triggerCount
        this.actions = List()
        
        if(actionsList) this.actions.append(actionsList)
        
        AllScriptEvents[eventName] <- this
    }

    /* 
     * Adds the action function for the event. 
     *
     * @param {function} actionFunction - The function to execute when the event is triggered. 
    */
    function AddAction(actionFunction) null

    function ClearActions() null

    /* 
     * Sets the filter function for the event. 
     *
     * The filter function should return true if the event should be triggered, false otherwise. 
     *
     * @param {function} filterFunction - The function to use for filtering trigger conditions. 
    */
    function SetFilter(filterFunc) null
    
    /* 
     * Triggers the event if the trigger count allows and the filter function (if set) returns true. 
     *
     * @param {any} args - Optional arguments to pass to the actions function. 
    */
    function Trigger(args = null) null
    
    /*
     * Forces the event to trigger, ignoring the filter function and trigger count. 
     * 
     * @param {any} args - Optional arguments to pass to the actions function. 
    */
    function ForceTrigger(args = null) null
}



/*
 * Add the action function for the event. 
 *
 * @param {function} actionFunction - The function to execute when the event is triggered. 
*/
function VGameEvent::AddAction(actionFunction) {
    this.actions.append(actionFunction)
}

function VGameEvent::ClearActions() {
    this.actions.clear()
}

/* 
 * Sets the filter function for the event. 
 *
 * The filter function should return true if the event should be triggered, false otherwise. 
 *
 * @param {function} filterFunction - The function to use for filtering trigger conditions. 
*/
function VGameEvent::SetFilter(filterFunc) {
    this.filterFunction = filterFunc
}


/* 
 * Triggers the event if the trigger count allows and the filter function (if set) returns true. 
 *
 * @param {array} args - Optional arguments to pass to the actions function. 
*/
function VGameEvent::Trigger(args) {
    if(this.actions.len() == 0) {
        dev.trace("Attempt to run {}, which has no actions", this.eventName)
        return
    }

    if (this.triggerCount != 0 && (this.filterFunction == null || this.filterFunction(args))) {
        if (this.triggerCount > 0) {
            // Decrement the trigger count if it is not unlimited
            this.triggerCount-- 
        }

        return this.ForceTrigger(args)
    }
}


/*
 * Forces the event to trigger, ignoring the filter function and trigger count. 
 * 
 * @param {array} args - Optional arguments to pass to the actions function. 
*/
function VGameEvent::ForceTrigger(args) {
    args.insert(0, this)
    foreach(action in this.actions.iter()) {
        try {
            action.acall(args)
        } catch(err) {
            throw("VGameEvent Error: " + this.eventName + " has accured: " + err )
        }
    }
    dev.trace("VScript Event Fired - " + this.eventName)
    return true // todo: what ._.
}

/*+--------------------------------------------------------------------------------+
|                           PCapture Vscripts Library                              |
+----------------------------------------------------------------------------------+
| Author:                                                                          |
|     Interface Illusionist - laVashik :|                                          |
+----------------------------------------------------------------------------------+
|    The HUD module, providing tools to craft immersive and informative on-screen  | 
|    elements like text displays and interactive hints.                            |
+----------------------------------------------------------------------------------+ */ 

::HUD <- {}

/*
 * A class for displaying on-screen text using the "game_text" entity.
*/
HUD["ScreenText"] <- class {
    // The underlying pcapEntity object representing the "game_text" entity. 
    CPcapEntity = null;
    holdtime = 0;
    
    /*
     * Constructor for a ScreenText object.
     *
     * @param {Vector} position - The position of the text on the screen. 
     * @param {string} message - The text message to display. 
     * @param {number} holdtime - The duration in seconds to display the text. (optional, default=10)
     * @param {string} targetname - The targetname of the "game_text" entity. (optional) 
    */
    constructor(position, message, holdtime = 10, targetname = "") {
        if (typeof position != "Vector")                                throw("HUD.ScreenText: 'position' must be a Vector, but got " + typeof position);
        if (typeof message != "string")                                 throw("HUD.ScreenText: 'message' must be a string, but got " + typeof message);
        if (typeof holdtime != "integer" && typeof holdtime != "float")  throw("HUD.ScreenText: 'holdtime' must be a number, but got " + typeof holdtime);
    
        this.holdtime = holdtime
        this.CPcapEntity = entLib.CreateByClassname("game_text", {
            // Set initial properties for the text display entity
            channel = 2,
            color = "170 170 170",
            color2 = "0 0 0",
            effect = 0,
            fadein = 0,
            fadeout = 0,
            fxtime = 0,
            holdtime = holdtime,
            x = position.x,
            y = position.y,
            spawnflags = 0,
            message = message,
            targetname = targetname
        })
    }

    // Displays the on-screen text. 
    function Enable() null
    // Hides the on-screen text. 
    function Disable() null
    // Updates and redisplays the on-screen text. 
    function Update() null

    //* Something like builders methods
    // Changes the message of the text display 
    function SetText(message) null 
    // Sets the channel of the text display.  
    function SetChannel(value) null
    // Sets the primary color of the text display as a string.  
    function SetColor(string_color) null
    // Sets the secondary color of the text display as a string.  
    function SetColor2(string_color) null
    // Sets the effect of the text display.  
    function SetEffect(value) null
    // Sets the fade-in time of the text display. 
    function SetFadeIn(value) null
    // Sets the fade-out time of the text display. 
    function SetFadeOut(value) null
    // Sets the hold time (duration) of the text display.  
    function SetHoldTime(time) null
    // Sets the position of the text display.  
    function SetPos(Vector) null
}


/*
 * Displays the on-screen text. 
*/
function HUD::ScreenText::Enable(holdtime = null) {
    this.CPcapEntity.SetKeyValue("holdtime", holdtime ? holdtime : this.holdtime)
    EntFireByHandle(this.CPcapEntity, "Display")
    return this
}

/*
 * Hides the on-screen text. 
*/
function HUD::ScreenText::Disable() {
    this.CPcapEntity.SetKeyValue("holdtime", 0.01)
    EntFireByHandle(this.CPcapEntity, "Display")
}

/*
 * Updates and redisplays the on-screen text. 
*/
function HUD::ScreenText::Update() {
    this.Enable()
}

/*
 * Changes the message of the text display and redisplays it.
 * 
 * @param {string} message - The new text message to display. 
*/
function HUD::ScreenText::SetText(message) {
    this.CPcapEntity.SetKeyValue("message", message)
    return this
}

/*
 * Sets the channel of the text display. 
 *
 * @param {number} channel - The channel to set.
*/
function HUD::ScreenText::SetChannel(channel) {
    this.CPcapEntity.SetKeyValue("channel", channel)
    return this
}

/*
 * Sets the primary color of the text display as a string. 
 *
 * @param {string} color - The color string, e.g., "255 0 0". 
*/
function HUD::ScreenText::SetColor(color) {
    this.CPcapEntity.SetKeyValue("color", color)
    return this
}

/*
 * Sets the secondary color of the text display as a string. 
 *
 * @param {string} color - The color string, e.g., "255 0 0". 
*/
function HUD::ScreenText::SetColor2(color) {
    this.CPcapEntity.SetKeyValue("color2", color)
    return this
}

/* 
 * Sets the effect of the text display. 
 *
 * @param {number} index - The index of the effect to set. 
*/
function HUD::ScreenText::SetEffect(idx) {
    this.CPcapEntity.SetKeyValue("effect", idx)
    return this
}

/*
 * Sets the fade-in time of the text display.
 *
 * @param {number} value - The fade-in time in seconds.  
*/ 
function HUD::ScreenText::SetFadeIn(value) {
    this.CPcapEntity.SetKeyValue("fadein", value)
    return this
}

/*
 * Sets the fade-out time of the text display.
 *
 * @param {number} value - The fade-out time in seconds.  
*/ 
function HUD::ScreenText::SetFadeOut(value) {
    this.CPcapEntity.SetKeyValue("fadeout", value)
    return this
}

/*
 * Sets the hold time (duration) of the text display. 
 *
 * @param {number} time - The hold time in seconds.  
*/
function HUD::ScreenText::SetHoldTime(time) {
    this.holdtime = time
    this.CPcapEntity.SetKeyValue("holdtime", time)
    return this
}

/*
 * Sets the position of the text display. 
 *
 * @param {Vector} position - The new position of the text. 
*/
function HUD::ScreenText::SetPos(position) {
    this.CPcapEntity.SetKeyValue("x", position.x)
    this.CPcapEntity.SetKeyValue("y", position.y)
    return this
}
/*
 * A class for displaying hints using the "env_instructor_hint" entity. 
*/
HUD["HintInstructor"] <- class {
    // The underlying pcapEntity object representing the "env_instructor_hint" entity.  
    CPcapEntity = null;

    /*
     * Constructor for a HintInstructor object. 
     *
     * @param {string} message - The hint message to display.
     * @param {number} holdtime - The duration in seconds to display the hint. (optional, default=5) 
     * @param {string} icon - The icon to display with the hint. (optional, default="icon_tip") 
     * @param {number} showOnHud - Whether to display the hint on the HUD or at the target entity's position (1 for HUD, 0 for target entity). (optional, default=1) 
     * @param {string} targetname - The targetname of the "env_instructor_hint" entity. (optional, default="") 
    */
    constructor(message, holdtime = 5, icon = "icon_tip", showOnHud = 1, targetname = "") {
        if (typeof message != "string")                                 throw("HUD.HintInstructor: 'message' must be a string, but got " + typeof message);
        if (typeof holdtime != "integer" && typeof holdtime != "float")  throw("HUD.HintInstructor: 'holdtime' must be a number, but got " + typeof holdtime);
        if (typeof icon != "string")                                    throw("HUD.HintInstructor: 'icon' must be a string, but got " + typeof message);

        this.CPcapEntity = entLib.CreateByClassname("env_instructor_hint", {
            // The text of your hint. 100 character limit.
            hint_caption = message,
            // Either show at the position of the Target Entity, or show the hint directly on the HUD at a fixed position.
            hint_static = showOnHud,
            hint_allow_nodraw_target = showOnHud,
            // The color of the caption text.
            hint_color = "255, 255, 255",
            // The icon to use when the hint is within the player's view.
            hint_icon_onscreen = icon,
            hint_icon_offscreen = icon,
            // The automatic timeout for the hint. 0 will persist until stopped with EndHint.
            hint_timeout = holdtime,
            hint_forcecaption = 1,
            hint_nooffscreen = 0,
            hint_range = 0, 
            targetname = targetname
        })
    }

    // Displays the hint.  
    function Enable(delay) null
    // Hides the hint. 
    function Disable() null
    // Updates and redisplays the hint.  
    function Update() null
    
    //* Something like builders methods
    // Changes the message of the hint. 
    function SetText(message) null 
    // Sets the bind to display with the hint icon.  
    function SetBind(bind) null
    // Sets the positioning of the hint (on HUD or at target entity).  
    function SetPositioning(value, ent) null
    // Sets the color of the hint text as a string. 
    function SetColor(string_color) null
    // Sets the icon to display when the hint is on-screen.  
    function SetIconOnScreen(icon) null
    // Sets the icon to display when the hint is off-screen.  
    function SetIconOffScreen(icon) null
    // Sets the hold time (duration) of the hint.  
    function SetHoldTime(time) null
    // Sets the distance at which the hint is visible.  
    function SetDistance(value) null
    // Sets the visual effects for the hint.  
    function SetEffects(sizePulsing, alphaPulsing, shaking) null
}

// Implementation of 'enable' to display the on-screen text
/*
 * Displays the hint. 
*/
function HUD::HintInstructor::Enable(delay=0) {
    EntFireByHandle(this.CPcapEntity, "ShowHint", "", delay)
}

// Implementation of 'disable' to hide the on-screen text
/*
 * Hides the hint. 
*/
function HUD::HintInstructor::Disable() {
    EntFireByHandle(this.CPcapEntity, "EndHint")
}

/*
 * Updates and redisplays the hint. 
*/
function HUD::HintInstructor::Update() {
    this.Enable()
}

/*
 * Changes the message of the hint and redisplays it. 
 * 
 * @param {string} message - The new hint message to display. 
*/
function HUD::HintInstructor::SetText(message) {
    this.CPcapEntity.SetKeyValue("hint_caption", message)
    return this
}
 
/* 
 * Sets the bind to display with the hint icon and updates the icon to "use_binding". 
 *
 * @param {string} bind - The bind name to display. 
*/
function HUD::HintInstructor::SetBind(bind) {
    this.CPcapEntity.SetKeyValue("hint_binding", bind)
    this.CPcapEntity.SetKeyValue("hint_icon_onscreen", "use_binding")
    return this
}

/*
 * Sets the positioning of the hint (on HUD or at target entity). 
 *
 * @param {number} value - 1 to display the hint on the HUD, 0 to display it at the target entity's position.
 * @param {CBaseEntity|pcapEntity|null} entity - The target entity to position the hint at (only used if value is 0). (optional) 
*/
function HUD::HintInstructor::SetPositioning(value, ent = null) { // showOnHud
    this.CPcapEntity.SetKeyValue("hint_static", value)
    this.CPcapEntity.SetKeyValue("hint_target", ent)
    return this
}

/* 
 * Sets the color of the hint text as a string. 
 *
 * @param {string} color - The color string, e.g., "255 0 0". 
*/
function HUD::HintInstructor::SetColor(color) {
    this.CPcapEntity.SetKeyValue("hint_color", color)
    return this
}

/* 
 * Sets the icon to display when the hint is on-screen. 
 *
 * @param {string} icon - The icon name to display. 
*/
function HUD::HintInstructor::SetIconOnScreen(icon) {
    this.CPcapEntity.SetKeyValue("hint_icon_onscreen", icon)
    return this
}

/* 
 * Sets the icon to display when the hint is off-screen. 
 *
 * @param {string} icon - The icon name to display. 
*/
function HUD::HintInstructor::SetIconOffScreen(icon) {
    this.CPcapEntity.SetKeyValue("hint_icon_offscreen", icon)
    return this
}   

/* 
 * Sets the hold time (duration) of the hint. 
 *
 * @param {number} time - The hold time in seconds. 
*/
function HUD::HintInstructor::SetHoldTime(time) {
    this.CPcapEntity.SetKeyValue("hint_timeout", time)
    return this
}

/*
 * Sets the distance at which the hint is visible.
 *
 * @param {number} distance - The distance in units.  
*/
function HUD::HintInstructor::SetDistance(value) {
    this.CPcapEntity.SetKeyValue("hint_range", value)
    return this
}

/*
 * Sets the visual effects for the hint. 
 *
 * @param {number} sizePulsing - The size pulsing option (0 for no pulsing, 1 for pulsing). 
 * @param {number} alphaPulsing - The alpha pulsing option (0 for no pulsing, 1 for pulsing).
 * @param {number} shaking - The shaking option (0 for no shaking, 1 for shaking).  
*/
function HUD::HintInstructor::SetEffects(sizePulsing, alphaPulsing, shaking) {
    this.CPcapEntity.SetKeyValue("hint_pulseoption", sizePulsing)
    this.CPcapEntity.SetKeyValue("hint_alphaoption", alphaPulsing)
    this.CPcapEntity.SetKeyValue("hint_shakeoption", shaking)
    return this
}


// Garbage collector for `PCapEntity::EntitiesScopes` and `PcapEntityCache` 
ScheduleEvent.AddInterval("global", function() {
    foreach(ent, _ in EntitiesScopes) {
        if(!ent || !ent.IsValid()) {
            delete EntitiesScopes[ent]
        }
    }
    foreach(ent, _ in pcapEntityCache) {
        if(!ent || !ent.IsValid()) {
            delete pcapEntityCache[ent]
        }
    }
    foreach(ent, _ in TracePlusIgnoreEnts) {
        if(!ent || !ent.IsValid()) {
            delete TracePlusIgnoreEnts[ent]
        }
    }
}, 5, 0)


/*
 * Initializes eye tracking for all players, allowing retrieval of their coordinates and viewing directions.
 * This serves as a workaround for the absence of the EyeForward function in Portal 2.
 *
 * In multiplayer sessions, it reinitializes eye tracking after 1 second to ensure that players are set up 
 * correctly, as there is typically a slight delay (1-2 seconds) in player initialization.
 *
 * When running in the Portal 2 Multiplayer Mod (P2MM), it schedules repeated initialization every second 
 * to dynamically accommodate new players joining the session.
*/

TrackPlayerJoins()
ScheduleEvent.Add("global", TrackPlayerJoins, 0.4)
if(IsMultiplayer()) {
    ScheduleEvent.Add("global", TrackPlayerJoins, 2) // Thanks Volve for making it take so long for players to initialize
    ScheduleEvent.AddInterval("global", HandlePlayerEventsMP, 0.3)
    
    if("TEAM_SINGLEPLAYER" in getroottable()) 
        // This session is running in P2MM, actively monitoring players.
        ScheduleEvent.AddInterval("global", TrackPlayerJoins, 1, 2)
} 
else {
    ScheduleEvent.AddInterval("global", HandlePlayerEventsSP, 0.5, 0.5)
} 


// Global settings for the portals correct working
SetupLinkedPortals()
local globalDetector = _CreatePortalDetector("CheckAllIDs", true)
globalDetector.ConnectOutputEx("OnStartTouchPortal", function() {entLib.FromEntity(activator).SetTraceIgnore(false)})
globalDetector.ConnectOutputEx("OnEndTouchPortal", function() {entLib.FromEntity(activator).SetTraceIgnore(true)})


::LIB_VERSION <- version
::PCaptureLibInited <- true

/*
 * Prints information about the PCapture library upon initialization.
 *
 * This includes the library name, version, author, and a link to the GitHub repository.
*/
printl("\n----------------------------------------")
printl("Welcome to " + LIB_VERSION)
printl("Author: laVashik Production") // The God of VScripts :P
printl("GitHub: https://github.com/LaVashikk/PCapture-LIB")
printl("----------------------------------------\n")

