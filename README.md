# Adaptive Local Tonemapper

A high-quality, feature-rich tonemapping shader for ReShade.

## Features

- **Tonemappers**:
  - ACES
  - AgX

- **Adaptive Processing**:
  - Automatically adjusts to scene brightness
  - Configurable adaptation speed and sensitivity
  - Optional manual control with fixed luminance mode

- **Local Contrast Enhancement**:
  - Bilateral filtering for edge-aware processing
  - Separate controls for local and micro contrast
  - Noise-aware detail enhancement

- **Zonal Adjustments**:
  - Independent control over shadows, midtones, and highlights
  - Configurable midtone center and width
  - Smooth transitions between zones

- **Color Processing**:
  - Vibrance enhancement with curve control
  - Skin tone protection
  - Natural saturation handling

- **Advanced AgX Controls**:
  - Highlight gain with threshold control
  - Punch exposure, saturation and gamma adjustments


## Usage

The shader offers extensive customization options organized into categories:

### Exposure

- **Exposure**: Adjusts overall image brightness before tonemapping (-3.0 to 2.0)

### Tone Mapping

- **Tonemapper Type**: Choose between ACES and AgX algorithms
- **Tone Mapping Strength**: Controls the intensity of the effect (0.1 to 3.0)
- **Local Adaptation Strength**: Adjusts how much local luminance affects processing (0.0 to 1.0)

#### AgX-specific Settings
- **AgX Highlight Gain**: Boosts highlights for increased dynamic range
- **AgX Highlight Gain Threshold**: Controls the range of highlight boosting
- **AgX Punch Exposure/Saturation/Gamma**: Fine-tune the AgX look

### Zonal Adjustments

- **Shadows/Midtones/Highlights**: Independent control over each tonal range
- **Midtones Center/Width**: Precisely define the midtone range

### Color

- **Color Vibrance**: Boosts color saturation, especially in less saturated areas
- **Skin Tone Protection**: Prevents oversaturation of skin tones
- **Vibrance Curve**: Controls how the vibrance effect is applied

### Adaptation

- **Adaptation Range**: Sets min/max values for adaptation
- **Adaptation Time**: How quickly the shader adapts to brightness changes
- **Adaptation Sensitivity**: Controls sensitivity to bright light
- **Enable Adaptation**: Toggle between adaptive and static tonemapping
- **Fixed Luminance**: Manual control when adaptation is disabled

### Local and Micro Contrast

- **Enable Local/Micro Contrast**: Toggle each enhancement independently
- **Local/Micro Contrast Strength**: Control the intensity of each effect
- **Local Contrast Radius**: Size of the area for contrast detection
- **Micro Contrast Falloff**: Controls detail enhancement across larger differences
- **Micro Contrast Noise Threshold**: Prevents enhancing noise

### Final Adjustments

- **Final Gamma**: Fine-tune the gamma curve
- **Final Opacity**: Blend between original and processed image

### Debug

- **Debug View**: Various visualization modes
- **Debug Multiplier**: Adjusts debug visualization strength

## Credits

- All shader code written by LLMs
- Some adaptation code from [luluco250's AdaptiveTonemapper.fx](https://github.com/luluco250/FXShaders/blob/master/Shaders/AdaptiveTonemapper.fx)
- AgX implementation based on Liam Collod's [AgXc](https://github.com/MrLixm/AgXc)