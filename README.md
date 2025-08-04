<div align="center">
<img src="Other\logo.png" alt="Logo" >

<h2 align="center">
    Your portals. Your colors. Your rules!
</h2>
</div>

## Description

MultiPortals is a powerful VScript-driven instance for Portal 2 that allows map makers to implement fully customizable, multi-colored portal pairs. Break free from the standard blue and orange! Define unique colors, effects, and behaviors for up to 127 different portal pairs, all controlled directly within the Hammer editor.

### See It in Action!
Check out the official demonstration video to see what MultiPortals V2 can do:
<div align="center">
<a href="https://youtu.be/UP8hD6QeGzc" target="_blank">
  <img src="https://github.com/user-attachments/assets/de0ac274-bc6d-4c90-9cba-5d1fd379864d" alt="MultiPortals V2 Demonstration" width="480">
</a>
</div>


## Why MultiPortals?
MultiPortals is the most flexible and easy-to-use solution for customizing portals in Workshop maps:

- **Fully VScript-Driven:** No complex entity logic. The instance is stable, efficient, and easy to configure.

- **Custom Portal Colors:** Define any color you want for each portal using simple RGB values.
  <details>
    <summary>🎥 <b>Video: Custom Colors Demo</b></summary>
    
    https://github.com/LaVashikk/MultiPortals/assets/105387234/2badbdad-2395-4e56-98d3-590659ddc616
  </details>

- **Dynamic Lighting:** Portals cast beautiful, smooth, colored light on world geometry and models. (This is optional and can be disabled for performance).
  <details>
    <summary>🎥 <b>Video: Dynamic Lighting Demo</b></summary>
    
    https://github.com/LaVashikk/MultiPortals/assets/105387234/3a8c03d9-6f9e-4fb2-ba26-f8443ffe7540
  </details>

- **Support for up to 127 different portal pairs** with individualized settings!
  <details>
    <summary>🎥 <b>Video: Multiple Portal Pairs Demo</b></summary>
    
    https://github.com/LaVashikk/MultiPortals/assets/105387234/e5493d9a-1185-4ad5-a430-ed523d6c0496
  </details>

- **Customizable Effects:**
  - A stylish, smooth portal closing animation.
  - Use the auto-colored default portal particles or specify your own custom particle effects.
  - Per-portal colored ghosting effect.
  <details>
    <summary>🎥 <b>Video: Ghosting Demo</b></summary>
    
    https://github.com/LaVashikk/MultiPortals/assets/105387234/33a39fa1-da8a-4f4c-8b7f-6758896cf728
  </details>

- **Advanced Control:**
  - Activate/deactivate static portals using I/O commands. Perfect for button-activated puzzles.
  - A simple VScript API to interact with portals from your own scripts.
- **Highly Configurable:** Control everything from portal ID and colors to brightness and optional features right from the `func_instance` properties.
## Installation

1.  **Download the latest release** from the [Releases Page](https://github.com/LaVashikk/MultiPortals/releases).
2.  **Extract the contents** of the `CustomContent` folder into your `.../Portal 2/portal2/` directory. This will add the necessary `scripts` and `materials` files.
3.  Copy the `multiportals.vmf` file from the downloaded archive into your Hammer instances folder (e.g., `.../sdk_content/maps/instances/`).
4. When your map is ready, pack the content from `CustomContent` into your BSP map.
5. Don't forget to give me a credit in the description :D

If you want, you can customize assets files to get more unique portal pairs!

## Usage in Hammer

1.  Create a `func_instance` entity in your map.
2.  In the **VMF Filename** property, browse to and select the `multiportals.vmf` instance file.
3.  **(CRITICAL)** Give the `func_instance` a unique **Name** (e.g., `multiportals_pair_1`). This name is used as a prefix for all its child entities.
4.  Go to the **Replace** tab in the entity's properties to configure your portal pair.

![Multiportal Instance](https://github.com/user-attachments/assets/48f4f519-9840-45b3-a620-2d94290319c1)

## Instance Parameters (Replace Keyvalues)

Use the `Replace` tab to set these parameters.

| Key                      | Description                                                                                                                                  | Example Value           |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| `$portal-id`             | **(Required)** A unique ID for this portal pair (0-127). This sets the `portalgun_linkage_id`. **Do not repeat this ID** across other instances. | `1`                     |
| `$portal1-color`         | The color of the first portal in `R G B` format.                                                                                             | `255 128 0` (Orange)    |
| `$portal2-color`         | The color of the second portal in `R G B` format.                                                                                            | `128 0 255` (Purple)    |
| `$portals-color-scale`   | A brightness multiplier for the portal color. Useful for HDR.                                                                                | `1.5`                   |
| `$withGhosting`          | Enable (`1`) or disable (`0`) the portal ghosting effect.                                                                                    | `1`                     |
| `$withDynamicLight`      | Enable (`1`) or disable (`0`) dynamic lighting. Disable for better performance.                                                              | `1`                     |
| `$custom-edge-particle`  | The name of a custom particle system for the portal's edge. Leave empty to use the default, auto-colored particle.                             | `my_custom_portal_fx`   |

## Advanced Usage

### Controlling Static Portals with I/O

You can open and close the portals from this instance using inputs. This is perfect for puzzles that don't use the player's portal gun. The target names for the portals are generated automatically based on the instance name:
- First Portal: `[Instance Name]-portal1`
- Second Portal: `[Instance Name]-portal2`

**Available Inputs:**
- **`FireUser1`**: Opens the portal with the standard animation.
- **`FireUser4`**: Closes the portal instantly.

*Example:* To have a button open a static red portal, send the button's `OnPressed` output to `my_red_portals-portal1` with the input `FireUser1`.

### VScript API

For advanced scripting, you can get a handle to any portal instance from another VScript file using a global function.

`GetCustomPortal(pairId, portalIdx)`
- `pairId` (integer): The ID you set in `$portal-id`.
- `portalIdx` (integer): The portal index (0 for the first, 1 for the second).

*Example VScript Code:*
```cs
// Get the instance of the first portal from the pair with ID 1
local myPortal = GetCustomPortal(1, 0); 

if (myPortal) {
    // Dynamically change its color to green
    myPortal.SetColor("0 255 0");
}
```

## Important Notes

> **Note:** Do not place your map at the origin coordinates (0, 0, 0), as there will be an unnecessary portal particle.

> **Warning:** When you are ready to publish your map, you **MUST** pack all the custom content (`/scripts/`, `/materials/`) into your final `.bsp` file. Use a tool like `Pakrat` or other to do this, otherwise other players will not see the portals correctly.

## Credits
The MultiPortals was created by <a href="https://www.youtube.com/@laVashikProductions">LaVashik</a>. Please give credit to LaVashik when using this in your projects :>

Protected by the MIT license.