// We need to initialize this block only once
if(!("MULTIPORTALS_INITED" in getroottable())) {
    DoIncludeScript("PCapture-Lib", getroottable())
    DoIncludeScript("multiportals/global_stuff", getroottable()) 
    DoIncludeScript("multiportals/custom_portal", getroottable()) 
    DoIncludeScript("multiportals/ghosting", getroottable()) 
    ::MULTIPORTALS_INITED <- true
}

const OPEN_TIME = 0.45                  // default value: 0.5
const PORTAL_STATIC_OPEN_TIME = 1.2     // default value: 0.9
const CLOSE_TIME = 0.25                 // default value: 0


// Parse instance parameters from the entity's model name, using '|' as a delimiter.
instanceParams <- split(self.GetModelName(), "|") 
// Validate that we have enough parameters to proceed.
if(instanceParams.len() < 6) throw("Invalid instance parameters in model name. Expected at least 6 arguments, but received " + instanceParams.len())

pairId <- instanceParams[0].tointeger()

// Initialize the two CustomPortal objects that make up this pair.
portal1 <- CustomPortal(EntityGroup[0], instanceParams[1], instanceParams)
portal2 <- CustomPortal(EntityGroup[1], instanceParams[2], instanceParams)
// A small hack to make alternative for `SetActivatedState`.
portal1.portal.SetInputHook("FireUser1", function():(portal1) {EntFireByHandle(portal1.portal, "SetActivatedState", "1"); portal1.OnPlaced(); return true})
portal2.portal.SetInputHook("FireUser1", function():(portal2) {EntFireByHandle(portal2.portal, "SetActivatedState", "1"); portal2.OnPlaced(); return true})
portal1.portal.SetInputHook("FireUser4", function():(portal1) {portal1.FizzleFast(); return true})
portal2.portal.SetInputHook("FireUser4", function():(portal2) {portal2.FizzleFast(); return true})


// Initialize the portal pair detector and connect its outputs to handle fizzle events.
pairDetector <- InitPortalPair(pairId)
pairDetector.ConnectOutputEx("OnEndTouchPortal1", function():(portal1) {portal1.OnFizzled()})
pairDetector.ConnectOutputEx("OnEndTouchPortal2", function():(portal2) {portal2.OnFizzled()})


// This function is called to make this portal pair the active one for the player's portal gun.
function ActivatePortalPair() {
    SendToConsole("change_portalgun_linkage_id " + pairId)
}

// Store the portal instances for the global GetCustomPortal API.
customPortals[pairId] <- [portal1, portal2]