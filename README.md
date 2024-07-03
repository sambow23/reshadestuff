# ReShade Stuff
Collection of shaders I have made

## AdaptiveLocalTonemapper:
### Features
* Adaptive exposure adjustment
* Local contrast enhancement
* ACES RRT (Reference Rendering Transform) tonemapping
* Color space conversions (RGB to Lab and back)
* Bilateral filtering for local luminance calculation
#### Customizable parameters including:
* Exposure and brightness
* Tonemapping intensity
* Local adjustment strength and curve
* Color vibrance
* Gamma correction
* Adaptation settings (range, time, sensitivity)

## EyeSight
### Features
* Veiling glare (soft glow around bright areas)
* Starburst effect on bright points (WIP)
* Chromatic aberration simulation
* Adaptive exposure adjustment
* Customizable vignette effect
* Spectral filtering of glare

All shader code was written by ChatGPT 4o and Claude 3.5 Sonnet

Adapation code from: [luluco250's AdaptiveTonemapper.fx](https://github.com/luluco250/FXShaders/blob/master/Shaders/AdaptiveTonemapper.fx)
