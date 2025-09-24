::customPortals <- {}

ScheduleEvent.Add("late_init", function() {
    SendToConsole("r_portal_fastpath 0")
    SendToConsole("portal_draw_ghosting 0")
    
    SendToConsole("hud_saytext_time 0")
    SendToConsole("sv_cheats 1")
    yield 0.2
    SendToConsole("hud_saytext_time 12")
    
    printl("\n===================================\nMultiPortals successfully initialized\nAuthor: laVashik\nGitHub: https://github.com/IaVashik\n===================================\n")
}, 1)

::GetCustomPortal <- function(pairId, portalIdx) {
    return customPortals[pairId][portalIdx]
}

::LerpMaterialModity <- macros.BuildAnimateFunction("material_modity_controller", function(ent, newValue) {
    EntFireByHandle(ent, "SetMaterialVar", newValue.tostring())
})