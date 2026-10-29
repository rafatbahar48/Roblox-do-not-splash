# Meshy props for the Splash Park lobby

Each prop has a reference image cut from `art/concepts/splash-park-lobby.png` for **Image to 3D**, and a text prompt for **Text to 3D** if the image result looks wrong.

Settings for every prop:
- Cartoon or stylised style, if Meshy offers one.
- Aim for about **10,000 triangles** or fewer (Roblox's hard limit is 20,000 per mesh). Use Meshy's remesh step to get there.
- Export as **FBX** or **GLB**, then in Studio use **Import 3D**.
- Keep the file under 20 MB.

Size in Studio is in studs; a player is about 5 studs tall.

## 1. Giant rubber duck
- Image: `rubber-duck.png`
- Text: `Giant cartoon rubber duck toy, glossy yellow plastic, orange beak, big black shiny eyes, smooth simple shapes, sitting upright, stylised game prop`
- Size: about 12 studs tall

## 2. Float rental hut
- Image: `float-hut.png`
- Text: `Small cartoon kiosk hut for renting swim rings, orange plastic plank walls, rounded bubblegum pink roof, open front counter, four colourful inflatable swim rings hanging along the front, chunky simple shapes, stylised game prop`
- Size: about 12 studs wide, 10 tall, 7 deep
- The sign text will come out blurry. Leave the sign blank or ignore it; the real sign will be added in Studio.

## 3. Tube slide
- Image: `slide-pink.png` (or `slide-yellow.png`)
- Text: `Curving enclosed water slide tube, smooth glossy plastic, dark navy rings around the tube every few metres, one S-shaped bend ending in an open round exit at the bottom, thin navy support poles, stylised game prop`
- Size: about 30 studs tall
- One slide is enough. Export it **without a texture** (or remove the texture in Studio) and set each copy's **Color** to pink or yellow, so one mesh gives you both slides.
- Both crops have other things in them (the avatar's hair, the hut's roof). If Meshy picks those up, use the text prompt instead.

## Easier to build in Studio than in Meshy
- **Beach ball:** a Ball part with a striped texture.
- **Scoreboards, STILL WATER sign, CLOSED sign, rules poster:** flat panels with SurfaceGui text or decals, so the text stays sharp.
- **Tunnel arch, walls, floor, glass roof:** parts and materials.
