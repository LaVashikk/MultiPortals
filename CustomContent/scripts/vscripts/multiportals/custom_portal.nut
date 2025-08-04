::CustomPortal <- class {
    //* set of required entities
    portal = null;
    fakePortalModel = null;
    dynamicLight = null;
    ghosting = null;
    particle = null;
    particleCP7 = null;

    //* internal state fields
    color = null;
    colorScale = 1;
    lastPos = Vector();
    isOpen = false;
    currentPortalFrame = null;

    //* material_modify
    modifyColor = null;
    modifyGhosting = null;
    modifyOpenAmount = null;
    modifyStatic = null;
    modifyColorScale = null;

    constructor(portal, color, instanceParams = null) {
        this.portal = entLib.FromEntity(portal)
        this.color = color
            
        foreach(ent in this.portal.GetAllChildrenRecursivly()) {
            local indicator = ent.GetName().slice(-5)
            if(indicator == "-base") this.fakePortalModel = ent
            if(indicator == "light") this.dynamicLight = ent
            if(indicator == "ghost") this.ghosting = ent
            if(indicator == "ticle") this.particle = ent
            // controllers
            if(indicator == "mount") this.modifyOpenAmount = ent
            if(indicator == "Color") this.modifyColor = ent
            if(indicator == "tatic") this.modifyStatic = ent
            if(indicator == "Frame") this.modifyGhosting = ent
            if(indicator == "Scale") this.modifyColorScale = ent
        }
        
        if(this.particle) 
            this.particleCP7 = entLib.FindByName(this.particle.GetName() + "-ColorPoint")
        
        // Hack to remove the portal particle that attaches to the model's attachment (WARN: the default particle will be at zero coordinates)
        ScheduleEvent.Add("global", portal.SetModel, 1, [ALWAYS_PRECACHED_MODEL], portal) 

        // Initial setup
        this.SetColor(color)
        this.SetPortalStatic(1, 0.5)
        this.SetOpenAmount(0, 0.5)
        this.portal.SetUserData("CustomPortalInstance", this)
        
        // And process the specified instance settings
        if(instanceParams == null) return
        this.SetColorScale(instanceParams[3])
        if(instanceParams[4] == "0") EntFireByHandle(this.ghosting, "Kill")         // No Ghosting
        if(instanceParams[5] == "0") EntFireByHandle(this.dynamicLight, "Kill")     // No Dyn. Light
    }

    // Setters
    function SetColor(color) {
        if (type(color) == "string") color = macros.StrToVec(color)
        
        this.color = color
        EntFireByHandle(this.modifyColor, "SetMaterialVar", "{" + macros.VecToStr(color) + "}")
        
        // particle control point
        this.particleCP7.SetOrigin(color)

        // if open - update stuff
        if(this.isOpen) {
            this.RestartParticle()
            if(this.dynamicLight && this.dynamicLight.IsValid()) 
                this.dynamicLight.SetColor(color)
        }

        // Ghosting
        if(!ghosting || !ghosting.IsValid()) return
        local ghostFrame = findColorIndex(color.x, color.y, color.z)
        EntFireByHandle(this.modifyGhosting, "SetMaterialVar", ghostFrame.tostring())
    }
    function SetColorScale(value, delay=0) {
        this.colorScale = value
        EntFireByHandle(this.modifyColorScale, "SetMaterialVar", value.tostring(), delay)
    }
    function SetOpenAmount(value, delay=0) {
        EntFireByHandle(this.modifyOpenAmount, "SetMaterialVar", value.tostring(), delay)
    }
    function SetPortalStatic(value, delay=0) {
        EntFireByHandle(this.modifyStatic, "SetMaterialVar", value.tostring(), delay)
    }

    // Lerp Anim
    function LerpOpenAmount(startVal, endVal, time) {
        EntFireByHandle(this.modifyOpenAmount, "StartFloatLerp", macros.format("{} {} {} 0", startVal, endVal, time))
    }
    function LerpPortalStatic(startVal, endVal, time) {
        EntFireByHandle(this.modifyStatic, "StartFloatLerp", macros.format("{} {} {} 0", startVal, endVal, time))
    }
    
    // Particles
    function RestartParticle() {
        EntFireByHandle(this.particle, "DestroyImmediately")
        EntFireByHandle(this.particle, "Start", "", 0.03)
    }
    function StopParticle() {
        EntFireByHandle(this.particle, "StopPlayEndCap", "", 0.03)
    }

    // ------------------------------------------------------------------------------ \\

    // Handlers
    function OnPlaced() {
        local portalOrigin = this.portal.GetOrigin()

        // do not process if the portal position has not changed!
        if(math.vector.isEqually2(portalOrigin, this.lastPos, 1000) && this.isOpen) return
        this.lastPos = portalOrigin
        
        // If it was previously closed
        if(!this.isOpen) {
            this.fakePortalModel.SetDrawEnabled(1)
            if(this.ghosting && this.ghosting.IsValid()) 
                this.ghosting.SetDrawEnabled(1)
            this.isOpen = true
        }

        // Portal opening animation
        this.RestartParticle()
        this.LerpOpenAmount(0, 1, OPEN_TIME)
        if(this.dynamicLight && this.dynamicLight.IsValid()) 
            animate.ColorTransition(this.dynamicLight, "0 0 0", this.color, OPEN_TIME, {ease = math.ease.InSine, eventName=this.dynamicLight})

        // Process portal frame (because I can)
        local portalFrame = entLib.FindByModelWithin("models/multiportals/portal_emitter.mdl", portalOrigin, 5)
        if(portalFrame) portalFrame.SetColor(math.vector.clamp((this.color * this.colorScale.tofloat()), 0, 255))
        
        // And process last portal frame
        if(this.currentPortalFrame) this.currentPortalFrame.SetColor(Vector())
        this.currentPortalFrame = portalFrame
        

        // Processing the PortalStatic effect
        local portalPartner = this.portal.GetPartnerInstance()
        if(!portalPartner) return  // partner is closed, ignore
        local partner = portalPartner.GetUserData("CustomPortalInstance")
        if(!partner.isOpen) return
        this.LerpPortalStatic(1, 0, PORTAL_STATIC_OPEN_TIME)
        partner.LerpPortalStatic(1, 0, PORTAL_STATIC_OPEN_TIME)
    }

    function OnFizzled() {
        if(!this.isOpen) return 
        this.isOpen = false
        this.StopParticle()
        this.LerpOpenAmount(1, 0, CLOSE_TIME)
        this.SetPortalStatic(1)
        this.fakePortalModel.SetDrawEnabled(0, CLOSE_TIME)
        
        if(this.ghosting && this.ghosting.IsValid()) 
            this.ghosting.SetDrawEnabled(0, CLOSE_TIME)
        
        if(this.dynamicLight && this.dynamicLight.IsValid()) {
            ScheduleEvent.TryCancel(this.dynamicLight)
            animate.ColorTransition(this.dynamicLight, this.dynamicLight.GetColor(), "0 0 0", CLOSE_TIME, {eventName=this.dynamicLight})
        }

        // And process last portal frame
        if(this.currentPortalFrame) {
            this.currentPortalFrame.SetColor("0 0 0")
            this.currentPortalFrame = null
        }
    }

    function FizzleFast() {
        this.isOpen = false
        EntFireByHandle(this.portal, "SetActivatedState", "0")
        EntFireByHandle(this.particle, "DestroyImmediately")
        this.SetPortalStatic(1)
        this.SetOpenAmount(0)
        this.fakePortalModel.SetDrawEnabled(0)
        if(this.dynamicLight && this.dynamicLight.IsValid()) 
            this.dynamicLight.SetColor("0 0 0")
        if(this.currentPortalFrame) {
            this.currentPortalFrame.SetColor("0 0 0")
            this.currentPortalFrame = null
        }
    }

    function _tostring() return "CustomPortal{ pair: " + pairId + ", portal: " + this.portal.GetName() + " }" 
}