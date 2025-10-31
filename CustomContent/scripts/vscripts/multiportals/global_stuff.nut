::customPortals <- {}
::selectedPair <- null

ScheduleEvent.Add("late_init", function() {
    SendToConsole("portal_draw_ghosting 0")
    
    SendToConsole("hud_saytext_time 0")
    SendToConsole("sv_cheats 1")
    yield 0.3
    SendToConsole("hud_saytext_time 12")

    if(customPortals.len() >= 3) {
        SendToConsole("r_portal_fastpath 0")
    }

    local cmd = "script foreach(pair in customPortals) foreach(p in pair) p.ghosting.Destroy()"
    macros.CreateCommand("portal_draw_ghosting_disable", cmd)
    macros.CreateCommand("multiportal_draw_ghosting_off", cmd)
    
    printl("\n===================================\nMultiPortals successfully initialized\nAuthor: laVashik\nGitHub: https://github.com/LaVashikk\n===================================\n")
}, 1)

::GetCustomPortal <- function(pairId, portalIdx) {
    if(pairId in customPortals)
        return customPortals[pairId][portalIdx]
}

::SetPortalPair <- function(pairId) {
    selectedPair = pairId
    EventListener.Notify("ChangePortalPair", pairId)
    SendToConsole("change_portalgun_linkage_id " + pairId)
}


::LerpMaterialModity <- macros.BuildAnimateFunction("material_modity_controller", function(ent, newValue) {
    EntFireByHandle(ent, "SetMaterialVar", newValue.tostring())
})

/*
 * This table serves as a central hub for all custom VScript events fired by the MultiPortals system.
 * It allows other scripts/addons to react to portal events (like being placed, fizzled, or changing color)
 * in a modular way, without needing to modify the core MultiPortals scripts.
 *
 * HOW TO USE:
 * To listen for an event, access the desired VGameEvent from this table and use its AddAction() method.
 * The function you provide will be executed every time the event is triggered.
 *
 * Example in another script:
 *
 * function MyCustomOnPlacedAction(event, portalInstance) {
 *     // This function will run whenever ANY MultiPortal is placed.
 *     // 'portalInstance' is the CustomPortal object that was placed.
 *     local portalName = portalInstance.portal.GetName();
 *     printl("A portal was placed: " + portalName);
 *
 *     // You can check its color, pair ID, etc.
 *     if (portalInstance.pairId == 3) {
 *         // Do something specific for portal pair 3
 *     }
 * }
 *
 * // Subscribe the function to the 'OnPlaced' event
 * MP_Events.OnPlaced.AddAction(MyCustomOnPlacedAction);
 *
*/
::MP_Events <- {
    ChangePortalPair = VGameEvent("ChangePortalPair"),      // args: pairId (int)
    ChangePortalColor = VGameEvent("ChangePortalColor"),    // args: instance (CustomPortal), color (Vector)
    OnPlaced = VGameEvent("OnPlaced"),                      // args: instance (CustomPortal)
    OnFizzled = VGameEvent("OnFizzled"),                    // args: instance (CustomPortal)
}