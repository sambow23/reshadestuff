
> All shader code was written by ChatGPT 4o and Claude 3.5 Sonnet\
> Adapation code from: [luluco250's AdaptiveTonemapper.fx](https://github.com/luluco250/FXShaders/blob/master/Shaders/AdaptiveTonemapper.fx)


# ReShade Stuff
Collection of shaders I have made

## AdaptiveLocalTonemapper:
### Features
* Adaptive exposure adjustment
* Local contrast enhancement
* ACES RRT and AgX tonemapping
#### Customizable parameters including:
* Exposure and brightness
* Tonemapping intensity
* Local adjustment strength and curve
* Color vibrance
* Gamma correction
* Adaptation settings (range, time, sensitivity)
* Zonal Control of Tonemapping

## EyeSight (needs rewrite)
Shader that emulates parts of a camera
### Features
* Veiling glare (soft glow around bright areas)
* Chromatic aberration simulation
* Adaptive exposure adjustment
* Customizable physically-based vignette effect
* Spectral filtering of glare
