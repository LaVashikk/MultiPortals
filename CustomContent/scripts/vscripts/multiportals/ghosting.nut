::colors <- [
    [63, 0, 0],
    [127, 0, 0],
    [191, 0, 0],
    [63, 31, 0],
    [127, 63, 0],
    [191, 95, 0],
    [63, 63, 0],
    [127, 127, 0],
    [191, 191, 0],
    [31, 63, 0],
    [63, 127, 0],
    [95, 191, 0],
    [0, 63, 0],
    [0, 127, 0],
    [0, 191, 0],
    [0, 63, 63],
    [0, 127, 127],
    [0, 191, 191],
    [0, 0, 63],
    [0, 0, 127],
    [0, 0, 191],
    [31, 0, 63],
    [63, 0, 127],
    [95, 0, 191]
]

::findColorIndex <- function(R, G, B) {
    if (abs(R - G) <= 17 && abs(G - B) <= 17 && abs(B - R) <= 17)       // Gray
        return 0

    local min_distance = 1000000.0 
    local closest_idx = 0
    
    foreach(index, color in colors){
        local r = color[0]
        local g = color[1]
        local b = color[2]
            
        local distance = sqrt((r - R) * (r - R) + (g - G) * (g - G) + (b - B) * (b - B))
        
        if (distance < min_distance) {
            min_distance = distance
            closest_idx = index + 1
        }
    }

    return closest_idx
}