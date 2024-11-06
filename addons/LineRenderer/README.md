# Line Renderer
A Godot Plugin implementation of a line renderer in Godot 4.0, useful for rendering cylindrical volume such as lasers, trails, etc. Based on the [Godot 3.0 version by @dbp8890](https://github.com/dbp8890/line-renderer), which is based on [the helpful C# implementation](https://github.com/paulohyy/linerenderer) by @paulohyy and forked from to a [Godot 4 port](https://github.com/LemiSt24/line-renderer) by @LemiSt24 with some addtional creature comforts. Made to a plugin by @betalars.

## Installation and Usage

### Reccomended:
 1. Get this via the Built-in Godot AssetLib. Do not install the Demo Folder, when you don't need it.
 2. Activate the Plugin in your Project Settings.
 3. Add a new LineRenderer3D to your scene.

To edit the line's points, simply edit the `points` member variable of the line renderer, and add/remove points from the array (see demo project for details). This can also be done via the editor in Godot.

![Demonstration](https://github.com/dbp8890/LineRenderer/blob/master/linerendererdemo.gif)

## Features
- **Start thickness/end thickness**: how thick to make the line, which will be interpolated between each segment.
- **Corner smooth/cap smooth**: how much smoothing to apply to the line's corners/caps. Generally, values around 5 work well. A value of 2 results in pointed corners/caps.
- **Draw caps/corners**: Enables/disables drawing caps or corners separately.
- **Global coords**: If enabled, the line's points are assumed to be global coordinates, which are independent of the line's transform or its parent. To have the line move/rotate with either itself or its parent, uncheck this so that the points are local.
- **Scale texture**: Checking this box tiles the texture, automatically repeating in the line's axial direction. Unchecking this box stretches the texture instead along the line's segments.

## Limitations
- Since this effectively uses camera-facing billboards, as with most billboards, certain angles can break the illusion of cylindrical volume.
- Corners and caps currently have suboptimal UV mapping, but textures formed in the shape of a line should generally work well.
- Texture scaling doesn't connect neatly to each segment at the moment; however, this is not very noticable in most cases.
- Does not yet have gizmos

## Demo Instructions
To use the demo, click anywhere on the screen to add a line segment. The camera automatically orbits around a point; use the arrow keys to change direction.

## License
1) MIT License (credit to @dbp8890, @paulohyy and @LemiSt24 for initial implementations)