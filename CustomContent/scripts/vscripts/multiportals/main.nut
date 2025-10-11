// We need to initialize this block only once
if(!("MULTIPORTALS_INITED" in getroottable())) {
    DoIncludeScript("multiportals/PCapture-Lib", getroottable())
    DoIncludeScript("multiportals/global_stuff", getroottable()) 
    DoIncludeScript("multiportals/custom_portal", getroottable()) 
    DoIncludeScript("multiportals/ghosting", getroottable()) 
    ::MULTIPORTALS_INITED <- true
}

const OPEN_TIME = 0.45                  // default value: 0.5
const PORTAL_STATIC_OPEN_TIME = 1.2     // default value: 0.9
const CLOSE_TIME = 0.3                  // default value: 0


// Parse instance parameters from the entity's model name, using '|' as a delimiter.
instanceParams <- split(self.GetModelName(), "|") 
// Validate that we have enough parameters to proceed.
if(instanceParams.len() < 6) throw("Invalid instance parameters in model name. Expected at least 6 arguments, but received " + instanceParams.len())
pairId <- instanceParams[0].tointeger()

// Initialize the two CustomPortal objects that make up this pair.
portal1 <- CustomPortal(pairId, EntityGroup[0], true , instanceParams[1], instanceParams)
portal2 <- CustomPortal(pairId, EntityGroup[1], false, instanceParams[2], instanceParams)

// A small hack to make alternative for `SetActivatedState`. // TODO
foreach(CPortal in [portal1, portal2]) {
    CPortal.portal.SetInputHook("FireUser1", function():(CPortal) {EntFireByHandle(CPortal.portal, "SetActivatedState", "1"); CPortal.OnPlaced(); return true})
    CPortal.portal.SetInputHook("FireUser3", function():(CPortal) {CPortal.Fizzle(); return true})
    CPortal.portal.SetInputHook("FireUser4", function():(CPortal) {CPortal.FizzleFast(); return true})
}

// Initialize the portal pair detector and connect its outputs to handle fizzle events.
pairDetector <- InitPortalPair(pairId)
pairDetector.ConnectOutputEx("OnEndTouchPortal1", function():(portal1) {portal1.OnFizzled()})
pairDetector.ConnectOutputEx("OnEndTouchPortal2", function():(portal2) {portal2.OnFizzled()})


// This function is called to make this portal pair the active one for the player's portal gun.
function ActivatePortalPair() {
    ::selectedPair = pairId
    EventListener.Notify("ChangePortalPair", pairId)
    SendToConsole("change_portalgun_linkage_id " + pairId)
}

// Store the portal instances for the global GetCustomPortal API.
customPortals[pairId] <- [portal1, portal2]