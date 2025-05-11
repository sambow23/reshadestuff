// Adaptive Local Tonemapper for ReShade
// Author: CR
// Credits: 
//     100% of code written by multiple LLMs
//     Some adaptation Code from luluco250's AdaptiveTonemapper.fx
//     Bloom implementation inspired by Prod80's Bloom shader: https://github.com/prod80/prod80-ReShade-Repository
//     AgX implementation based on Liam Collod's AgXc: https://github.com/MrLixm/AgXc

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// Adaptive tonemapping constants
#define ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE 256
#define ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS 9
#define BILATERAL_SAMPLES 9
#define BILATERAL_RADIUS 4.0
#define BILATERAL_SIGMA_SPATIAL 3.0
#define BILATERAL_SIGMA_RANGE 0.1
#define ADAPT_FOCAL_POINT float2(0.5, 0.5)
#define ADAPT_PRECISION 0

// Bloom constants
#define BLOOM_DOWNSAMPLE_SCALE_1 0.25
#define BLOOM_DOWNSAMPLE_SCALE_2 0.125
#define BLOOM_DOWNSAMPLE_SCALE_3 0.0625
#define BLOOM_ITERATIONS 64 // Number of iterations for the blur
#define BLOOM_LOOP_LIMITER 0.001 // Limiter for iterative blur, similar to PD80

static const int AdaptMipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;

// AgX LUT texture
texture AgXLUTTex < source = "AgX-default_contrast.lut.png"; > { Width = 32*32; Height = 32; Format = RGBA8; };
sampler2D AgXLUTSampler { Texture = AgXLUTTex; };   

//#region Uniforms

// Basic Settings
uniform float SceneBrightness <
    ui_type = "slider";
    ui_label = "Scene Brightness";
    ui_tooltip = "Universally scales brightness affecting LAB-based adjustments, preserving whitepoint. Applied alongside Exposure.";
    ui_category = "Basic Settings";
    ui_min = 0.1;
    ui_max = 5.0;
    ui_step = 0.01;
> = 0.20;

// Final Adjustments

uniform float LabGamma <
    ui_type = "slider";
    ui_label = "LAB Lightness Gamma";
    ui_tooltip = "Applies a gamma curve to the perceptual lightness (L channel) after entering LAB space, before other LAB adjustments. Affects midtone brightness perception.";
    ui_category = "Final Adjustments";
    ui_min = 0.1;
    ui_max = 2.2;
    ui_step = 0.01;
> = 1.25;

uniform float Gamma <
    ui_type = "slider";
    ui_label = "Final Gamma";
    ui_tooltip = "Adjusts the gamma curve of the final image. Lower values brighten shadows, higher values darken midtones.";
    ui_category = "Final Adjustments";
    ui_min = 0.1;
    ui_max = 2.2;
    ui_step = 0.01;
> = 1.00;

uniform float GlobalOpacity <
    ui_type = "slider";
    ui_label = "Final Opacity";
    ui_tooltip = "Controls the blend between the original image and the processed image. 0 = Original, 1 = Fully Processed";
    ui_category = "Final Adjustments";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 1.0;

uniform int BlendMode <
    ui_type = "combo";
    ui_label = "Blend Mode";
    ui_tooltip = "Selects how the processed image is blended with the original image.";
    ui_category = "Final Adjustments";
    ui_items = "Normal (Lerp)\0Additive\0Multiplicative\0Screen\0Overlay\0";
> = 0; // Default to Normal (Lerp)

// Exposure
uniform float Exposure <
    ui_type = "slider";
    ui_label = "Exposure";
    ui_tooltip = "Adjusts the overall brightness before tonemapping. Higher values brighten the image, lower values darken it.";
    ui_category = "Exposure";
    ui_min = -3.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 0.75;

// Bloom Settings
uniform bool EnableBloom <
    ui_type = "checkbox";
    ui_label = "Enable Bloom";
    ui_tooltip = "Toggle bloom effect on/off.";
    ui_category = "Bloom";
> = true;

uniform float BloomIntensity <
    ui_type = "slider";
    ui_label = "Bloom Intensity";
    ui_tooltip = "Controls the overall strength of the bloom effect.";
    ui_category = "Bloom";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.00;

uniform float BloomThreshold <
    ui_type = "slider";
    ui_label = "Bloom Threshold";
    ui_tooltip = "Minimum brightness value that generates bloom.";
    ui_category = "Bloom";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.6;

uniform float BloomWidth <
    ui_type = "slider";
    ui_label = "Bloom Width";
    ui_tooltip = "Controls the size of the bloom effect.";
    ui_category = "Bloom";
    ui_min = 0.1;
    ui_max = 5.0;
    ui_step = 0.1;
> = 2.0;

uniform float3 BloomTint <
    ui_type = "color";
    ui_label = "Bloom Tint";
    ui_tooltip = "Color tint for the bloom effect.";
    ui_category = "Bloom";
> = float3(1.0, 1.0, 1.0);

uniform float Bloom1Weight <
    ui_type = "slider";
    ui_label = "Bloom Layer 1 Weight";
    ui_tooltip = "Controls the weight of the small bloom layer.";
    ui_category = "Bloom";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.7;

uniform float Bloom2Weight <
    ui_type = "slider";
    ui_label = "Bloom Layer 2 Weight";
    ui_tooltip = "Controls the weight of the medium bloom layer.";
    ui_category = "Bloom";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;

uniform float Bloom3Weight <
    ui_type = "slider";
    ui_label = "Bloom Layer 3 Weight";
    ui_tooltip = "Controls the weight of the large bloom layer.";
    ui_category = "Bloom";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.3;

uniform bool EnableAdaptiveBloom <
    ui_type = "checkbox";
    ui_label = "Enable Adaptive Bloom";
    ui_tooltip = "Toggles whether bloom intensity adapts to scene luminance.";
    ui_category = "Bloom";
> = true;

uniform float AdaptiveBloomStrength <
    ui_type = "slider";
    ui_label = "Adaptive Bloom Strength";
    ui_tooltip = "Controls how strongly bloom adapts to scene luminance. 0 = no adaptation, higher = stronger effect.";
    ui_category = "Bloom";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.05;
> = 0.75;

uniform float BloomAdaptationReference <
    ui_type = "slider";
    ui_label = "Bloom Adaptation Reference";
    ui_tooltip = "The reference scene luminance for bloom adaptation. Bloom is stronger below this, weaker above.";
    ui_category = "Bloom";
    ui_min = 0.1;
    ui_max = 5.0;
    ui_step = 0.05;
> = 0.80;

// Bloom Debug Views
uniform int BloomDebugView <
    ui_type = "combo";
    ui_label = "Bloom Debug View";
    ui_tooltip = "Shows different stages of the bloom pipeline.";
    ui_category = "Bloom";
    ui_items = "Off\0Bloom Prefilter (ThresholdTex)\0Bloom Layer 1 Output\0Bloom Layer 2 Output\0Bloom Layer 3 Output\0";
> = 0;

uniform float BloomDebugBrightness <
    ui_type = "slider";
    ui_label = "Bloom Debug Brightness";
    ui_tooltip = "Multiplies the brightness of the bloom debug visualization.";
    ui_category = "Bloom";
    ui_min = 0.1;
    ui_max = 10.0;
    ui_step = 0.1;
> = 1.0;

// Tonemapper Settings

uniform int TonemapperType <
    ui_type = "combo";
    ui_label = "Tonemapper Type";
    ui_tooltip = "Select the tonemapping algorithm to use. (ACES/AgX settings do not match each other, please re-adjust when switching tonemappers)";
    ui_category = "Tone Mapping";
    ui_items = "ACES\0AgX\0";
> = 1;

uniform float TonemappingIntensity <
    ui_type = "slider";
    ui_label = "Tone Mapping Strength";
    ui_tooltip = "Controls the intensity of the tone mapping effect. Higher values increase contrast and color vibrancy.";
    ui_category = "Tone Mapping";
    ui_min = 0.1;
    ui_max = 3.0;
    ui_step = 0.01;
> = 1.0;

// AgX-specific settings
uniform float AgXHighlightGain <
    ui_type = "slider";
    ui_label = "AgX Highlight Gain";
    ui_tooltip = "Increase dynamic range (in a fake way) by boosting highlights.";
    ui_category = "Tone Mapping";
    ui_min = 0.0;
    ui_max = 10.0;
    ui_step = 0.01;
> = 5.0;

uniform float AgXHighlightGainGamma <
    ui_type = "slider";
    ui_label = "AgX Highlight Gain Threshold";
    ui_tooltip = "A simple Gamma operation on the Luminance mask. Increase/decrease ranges of highlight boosted.";
    ui_category = "Tone Mapping";
    ui_min = 0.0;
    ui_max = 4.0;
    ui_step = 0.01;
> = 1.0;

uniform float AgXPunchExposure <
    ui_type = "slider";
    ui_label = "AgX Punch Exposure";
    ui_tooltip = "Post display conversion. Applied after the AgX transform.";
    ui_category = "Tone Mapping";
    ui_min = -5.0;
    ui_max = 5.0;
    ui_step = 0.01;
> = 1.5;

uniform float AgXPunchSaturation <
    ui_type = "slider";
    ui_label = "AgX Punch Saturation";
    ui_tooltip = "Post display conversion. Applied after the AgX transform.";
    ui_category = "Tone Mapping";
    ui_min = 0.5;
    ui_max = 3.0;
    ui_step = 0.01;
> = 0.90;

uniform float AgXPunchGamma <
    ui_type = "slider";
    ui_label = "AgX Punch Gamma";
    ui_tooltip = "Post display conversion. Applied after the AgX transform.";
    ui_category = "Tone Mapping";
    ui_min = 0.001;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.25;

// Color
uniform float LocalSaturationBoost <
    ui_type = "slider";
    ui_label = "Color Vibrance";
    ui_tooltip = "Boosts color saturation, especially in less saturated areas. Higher values make colors more vivid.";
    ui_category = "Color";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;

uniform float SkinToneProtection <
    ui_type = "slider";
    ui_label = "Skin Tone Protection";
    ui_tooltip = "Higher values protect skin tones from oversaturation.";
    ui_category = "Color";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.0;

uniform float VibranceCurve <
    ui_type = "slider";
    ui_label = "Vibrance Curve";
    ui_tooltip = "Adjusts the curve of the vibrance effect. Higher values boost less saturated colors more.";
    ui_category = "Color";
    ui_min = 0.5;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;


// Zonal Adjustments
uniform float ShadowAdjustment <
    ui_type = "slider";
    ui_label = "Shadows";
    ui_tooltip = "Adjusts the tonemapping intensity in shadow areas.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.5;

uniform float MidtoneAdjustment <
    ui_type = "slider";
    ui_label = "Midtones";
    ui_tooltip = "Adjusts the tonemapping intensity in midtone areas.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;

uniform float HighlightAdjustment <
    ui_type = "slider";
    ui_label = "Highlights";
    ui_tooltip = "Adjusts the tonemapping intensity in highlight areas.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;

uniform float MidtonesCenter <
    ui_type = "slider";
    ui_label = "Midtones Center";
    ui_tooltip = "Center point of the midtone range.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;

uniform float MidtonesWidth <
    ui_type = "slider";
    ui_label = "Midtones Width";
    ui_tooltip = "Width of the midtone range.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.1;
    ui_max = 0.8;
    ui_step = 0.01;
> = 0.4;

// Adaptation

uniform float2 AdaptRange <
    ui_type = "drag";
    ui_label = "Adaptation Range";
    ui_tooltip = "The minimum and maximum values that adaptation can use.";
    ui_category = "Adaptation";
    ui_min = 0.001;
    ui_max = 2.0;
    ui_step = 0.001;
> = float2(0.75, 2.0);

uniform float AdaptTime <
    ui_type = "drag";
    ui_label = "Adaptation Time";
    ui_tooltip = "The time in seconds that adaptation takes to occur.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 3.0;
    ui_step = 0.01;
> = 1.0;

uniform float AdaptSensitivity <
    ui_type = "drag";
    ui_label = "Adaptation Sensitivity";
    ui_tooltip = "Determines how sensitive adaptation is to bright lights.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 12.0;
    ui_step = 0.01;
> = 11.0;

uniform bool EnableAdaptation <
    ui_type = "checkbox";
    ui_label = "Enable Adaptation";
    ui_tooltip = "Toggle adaptive tonemapping on/off. When off, static tonemapping is used.";
    ui_category = "Adaptation";
> = true;

uniform float FixedLuminance <
    ui_type = "slider";
    ui_label = "Fixed Luminance";
    ui_tooltip = "The fixed luminance value to use when adaptation is disabled. 0.18 is middle gray.";
    ui_category = "Adaptation";
    ui_min = 0.50;
    ui_max = 5.0;
    ui_step = 0.01;
> = 1.50;

// Local Contrast Controls
uniform bool EnableLocalContrast <
    ui_type = "checkbox";
    ui_label = "Enable Local Contrast";
    ui_tooltip = "Toggles local contrast enhancement";
    ui_category = "Local and Micro Contrast";
> = true;

uniform float LocalContrastStrength <
    ui_type = "slider";
    ui_label = "Local Contrast Strength";
    ui_tooltip = "Controls the strength of local contrast enhancement";
    ui_category = "Local and Micro Contrast";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.10;

uniform float LocalContrastRadius <
    ui_type = "slider";
    ui_label = "Local Contrast Radius";
    ui_tooltip = "Size of the area used for local contrast detection";
    ui_category = "Local and Micro Contrast";
    ui_min = 1.0;
    ui_max = 10.0;
    ui_step = 0.1;
> = 4.5;

// Micro Contrast Controls
uniform bool EnableMicroContrast <
    ui_type = "checkbox";
    ui_label = "Enable Micro Contrast";
    ui_tooltip = "Toggles micro contrast enhancement";
    ui_category = "Local and Micro Contrast";
> = true;

uniform float MicroContrastStrength <
    ui_type = "slider";
    ui_label = "Micro Contrast Strength";
    ui_tooltip = "Controls the strength of micro contrast enhancement";
    ui_category = "Local and Micro Contrast";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.10;

uniform float MicroContrastFalloff <
    ui_type = "slider";
    ui_label = "Micro Contrast Falloff";
    ui_tooltip = "Controls how quickly the micro contrast effect falls off with difference. Higher values retain more detail across larger differences.";
    ui_category = "Local and Micro Contrast";
    ui_min = 0.1;
    ui_max = 5.0;
    ui_step = 0.1;
> = 2.0;

uniform float MicroContrastNoiseThreshold <
    ui_type = "slider";
    ui_label = "Micro Contrast Noise Threshold";
    ui_tooltip = "Luminance threshold below which differences are considered noise and not enhanced. Higher values reduce noise enhancement.";
    ui_category = "Local and Micro Contrast";
    ui_min = 0.001;
    ui_max = 0.1;
    ui_step = 0.001;
> = 0.02;

// Local adaptation control
uniform float LocalAdaptationStrength <
    ui_type = "slider";
    ui_label = "Local Adaptation Strength";
    ui_tooltip = "Controls how much the local luminance affects adaptation. Higher values increase local contrast.";
    ui_category = "Tone Mapping";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.25;

uniform float LocalAdaptSmoothingMultiplier <
    ui_type = "slider";
    ui_label = "Local Adaptation Smoothing";
    ui_tooltip = "Multiplier for adaptation time when smoothing local luminance changes. Higher values create smoother transitions but more lag in local adaptation.";
    ui_category = "Tone Mapping";
    ui_min = 0.5;
    ui_max = 5.0;
    ui_step = 0.1;
> = 1.0;

// Add these debug uniforms
uniform int DebugMode <
    ui_type = "combo";
    ui_label = "Debug View";
    ui_tooltip = "Shows different aspects of the micro-contrast enhancement";
    ui_category = "Local and Micro Contrast";
    ui_items = "Off\0Detail Map\0Noise Mask\0Enhancement Strength\0Detail Vectors\0";
> = 0;

uniform float DebugMultiplier <
    ui_type = "slider";
    ui_label = "Debug Multiplier";
    ui_tooltip = "Multiplies the debug visualization strength";
    ui_category = "Local and Micro Contrast";
    ui_min = 1.0;
    ui_max = 10.0;
    ui_step = 0.1;
> = 1.0;

uniform float FrameTime <source = "frametime";>;

//#endregion

//#region Textures and Samplers

sampler BackBuffer {
    Texture = ReShade::BackBufferTex;
    SRGBTexture = true;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
};

texture SmallTex {
    Width = ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE;
    Height = ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE;
    Format = R32F;
    MipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;
};
sampler Small { Texture = SmallTex; };

texture LastAdaptTex { Format = R32F; };
sampler LastAdapt {
    Texture = LastAdaptTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
};

texture LocalLuminanceHPassTex {
    Format = R32F; // Store intermediate horizontal pass luminance
};
sampler LocalLuminanceHPassSampler { Texture = LocalLuminanceHPassTex; };

texture LocalLuminanceTex {
    Format = R32F; // Store final vertical pass luminance
};
sampler LocalLuminanceSampler { Texture = LocalLuminanceTex; };

texture PrevLocalLuminanceTex {
    Format = R32F; // Store previous frame's local luminance for temporal smoothing
};
sampler PrevLocalLuminanceSampler { Texture = PrevLocalLuminanceTex; };

// Bloom textures
texture BloomThresholdTex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_1;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_1;
    Format = RGBA16F;
};
sampler BloomThresholdSampler { 
    Texture = BloomThresholdTex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

// Bloom Layer 1 (Small)
texture BloomLayer1HorizontalTex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_1;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_1;
    Format = RGBA16F;
};
sampler BloomLayer1HorizontalSampler { 
    Texture = BloomLayer1HorizontalTex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

texture BloomLayer1Tex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_1;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_1;
    Format = RGBA16F;
};
sampler BloomLayer1Sampler { 
    Texture = BloomLayer1Tex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

// Bloom Layer 2 (Medium)
texture BloomLayer2HorizontalTex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_2;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_2;
    Format = RGBA16F;
};
sampler BloomLayer2HorizontalSampler { 
    Texture = BloomLayer2HorizontalTex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

texture BloomLayer2Tex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_2;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_2;
    Format = RGBA16F;
};
sampler BloomLayer2Sampler { 
    Texture = BloomLayer2Tex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

// Bloom Layer 3 (Large)
texture BloomLayer3HorizontalTex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_3;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_3;
    Format = RGBA16F;
};
sampler BloomLayer3HorizontalSampler { 
    Texture = BloomLayer3HorizontalTex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

texture BloomLayer3Tex {
    Width = BUFFER_WIDTH * BLOOM_DOWNSAMPLE_SCALE_3;
    Height = BUFFER_HEIGHT * BLOOM_DOWNSAMPLE_SCALE_3;
    Format = RGBA16F;
};
sampler BloomLayer3Sampler { 
    Texture = BloomLayer3Tex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
};

//#endregion

//#region Helper Functions

float smootherstep(float edge0, float edge1, float x) {
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return x * x * x * (x * (x * 6 - 15) + 10);
}

float3 RGB2Lab(float3 rgb)
{
    // Convert RGB to XYZ
    float3 xyz = mul(float3x3(
        0.4124564, 0.3575761, 0.1804375,
        0.2126729, 0.7151522, 0.0721750,
        0.0193339, 0.1191920, 0.9503041
    ), rgb);

    // XYZ to Lab
    float3 n = xyz / float3(0.95047, 1.0, 1.08883);
    float3 v = (n > 0.008856) ? pow(n, 1.0/3.0) : (7.787 * n + 16.0/116.0);
    
    return float3(
        (116.0 * v.y) - 16.0,    // L
        500.0 * (v.x - v.y),     // a
        200.0 * (v.y - v.z)      // b
    );
}

float3 Lab2RGB(float3 lab)
{
    float fy = (lab.x + 16.0) / 116.0;
    float fx = lab.y / 500.0 + fy;
    float fz = fy - lab.z / 200.0;

    float3 xyz = float3(
        0.95047 * ((fx > 0.206897) ? fx * fx * fx : (fx - 16.0/116.0) / 7.787),
        1.00000 * ((fy > 0.206897) ? fy * fy * fy : (fy - 16.0/116.0) / 7.787),
        1.08883 * ((fz > 0.206897) ? fz * fz * fz : (fz - 16.0/116.0) / 7.787)
    );

    // XYZ to RGB
    return saturate(mul(float3x3(
        3.2404542, -1.5371385, -0.4985314,
        -0.9692660,  1.8760108,  0.0415560,
        0.0556434, -0.2040259,  1.0572252
    ), xyz));
}

// ACES RRT Tonemapping function
float3 ACES_RRT(float3 color) {
    const float A = 2.51;
    const float B = 0.03;
    const float C = 2.43;
    const float D = 0.59;
    const float E = 0.14;
    return (color * (A * color + B)) / (color * (C * color + D) + E);
}

// AgX constants and helper functions
static const float3 agx_luma_coefs = float3(0.2126, 0.7152, 0.0722);
static const float3x3 agx_compressed_matrix = float3x3(
    0.84247906, 0.0784336, 0.07922375,
    0.04232824, 0.87846864, 0.07916613,
    0.04237565, 0.0784336, 0.87914297
);
static const float3x3 agx_compressed_matrix_inverse = float3x3(
    1.1968790, -0.09802088, -0.09902975,
    -0.05289685, 1.15190313, -0.09896118,
    -0.05297163, -0.09804345, 1.15107368
);

float3 agx_powsafe(float3 color, float power) {
    return pow(abs(color), power) * sign(color);
}

float3 agx_transform_to_log(float3 color) {
    color = max(0.0, color);
    color = (color < 0.00003051757) ? (0.00001525878 + color) : (color);
    color = clamp(log2(color / 0.18), -10.0, 6.5);
    return (color + 10.0) / 16.5;
}

float3 agx_look_lut(float3 color) {
    float3 lut3D = color * 31.0;
    
    float2 lut2D[2];
    // Front
    lut2D[0].x = floor(lut3D.z) * 32.0 + lut3D.x;
    lut2D[0].y = lut3D.y;
    // Back
    lut2D[1].x = ceil(lut3D.z) * 32.0 + lut3D.x;
    lut2D[1].y = lut3D.y;
    
    // Convert from texel to texture coords
    lut2D[0] = (lut2D[0] + 0.5) / float2(32*32, 32);
    lut2D[1] = (lut2D[1] + 0.5) / float2(32*32, 32);
    
    // Bicubic LUT interpolation
    float3 lutResult = lerp(
        tex2D(AgXLUTSampler, lut2D[0]).rgb,
        tex2D(AgXLUTSampler, lut2D[1]).rgb,
        frac(lut3D.z)
    );
    
    return agx_powsafe(lutResult, 2.2); // Decode gamma from LUT
}

float3 AgX_Tonemap(float3 color) {
    // Apply highlight gain (pre-processing)
    float imageLuma = dot(color, agx_luma_coefs);
    float highlightMask = pow(imageLuma, AgXHighlightGainGamma);
    color += color * highlightMask * AgXHighlightGain;
    
    // Transform to AgX compressed space
    color = mul(agx_compressed_matrix, color);
    
    // Convert to log domain
    color = agx_transform_to_log(color);
    
    // Apply AgX curve via LUT
    color = agx_look_lut(color);
    
    // Transform back from compressed space
    color = mul(agx_compressed_matrix_inverse, color);
    
    // Apply "punchy" look (post-processing)
    // Apply gamma
    color = agx_powsafe(color, AgXPunchGamma);
    
    // Apply saturation
    float luma = dot(color, agx_luma_coefs);
    color = lerp(luma.xxx, color, AgXPunchSaturation);
    
    // Apply exposure
    color *= pow(2.0, AgXPunchExposure);
    
    return color;
}

// Apply Gamma Correction
float3 ApplyGamma(float3 color, float gamma) {
    return pow(max(color, 0.0001), 1.0 / gamma);
}

// Simple Gamut Mapping function
float3 GamutMap(float3 color) {
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    float maxComponent = max(color.r, max(color.g, color.b));
    
    // If any component is > 1, desaturate towards luminance
    if (maxComponent > 1.0) {
        return lerp(float3(luminance, luminance, luminance), color, 1.0 / maxComponent);
    }
    
    // If any component is < 0 (less common but possible with some ops), 
    // we can simply clamp for now, or implement a more complex mapping.
    // Clamping negative values is generally acceptable here.
    return max(color, 0.0);
}

//#endregion

//#region Bloom Functions

// Pre-downsampling pass to prevent aliasing before blurring (Thresholding)
float4 PS_BloomPrefilter(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    // Use a more substantial pre-blurred source for all calculations
    float2 ps = ReShade::PixelSize;
    float4 preBlurredSource = 0.0;
    float totalPreBlurWeight = 0.0;
    
    // 3x3 Gaussian-like blur weights
    float weights[9] = { 
        1.0, 2.0, 1.0, 
        2.0, 4.0, 2.0, 
        1.0, 2.0, 1.0 
    };

    int k = 0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            preBlurredSource += tex2D(BackBuffer, texcoord + float2(x, y) * ps) * weights[k];
            totalPreBlurWeight += weights[k];
            k++;
        }
    }
    preBlurredSource /= totalPreBlurWeight;

    // Convert to LAB space for perceptual brightness evaluation using the pre-blurred source
    float3 labColor = RGB2Lab(preBlurredSource.rgb);
    
    float brightness = labColor.x / 100.0; // L channel (0-100) normalized to 0-1
    
    // Apply threshold with soft knee
    float knee = BloomThreshold * 0.25;
    float soft = saturate((brightness - BloomThreshold + knee) / (2.0 * knee + 0.00001));
    soft = soft * soft * (3.0 - 2.0 * soft); // Smoothstep
    
    float contribution = max(0.0, brightness - BloomThreshold + soft * knee);
    
    // Modulate by global intensity
    contribution *= BloomIntensity;

    // --- Adaptive Bloom based on scene adaptation ---    
    if (EnableAdaptation && EnableAdaptiveBloom) 
    {
        float adaptedLuminanceScene = tex2Dfetch(LastAdapt, int2(0,0), 0).x;
        adaptedLuminanceScene = clamp(adaptedLuminanceScene, AdaptRange.x, AdaptRange.y);
        adaptedLuminanceScene = max(adaptedLuminanceScene, 0.01);
        float bloomAdaptationFactor = pow(BloomAdaptationReference / adaptedLuminanceScene, AdaptiveBloomStrength);
        contribution *= bloomAdaptationFactor;
    }
    
    // Apply bloom value to LAB channels, emphasizing the L channel
    float3 brightBloomLab = float3(labColor.x * contribution * BloomTint.r, 
                                   labColor.y * contribution * BloomTint.g, 
                                   labColor.z * contribution * BloomTint.b);

    // Convert back to RGB space
    float3 bloomColorRGB = Lab2RGB(brightBloomLab);
    
    return float4(bloomColorRGB, 1.0);
}

// Iterative Gaussian blur - Horizontal pass (inspired by PD80)
float4 PS_BloomBlurH(float4 pos : SV_Position, float2 texcoord : TEXCOORD, sampler2D sourceSampler, float layerScale) : SV_Target
{
    float4 color = tex2D(sourceSampler, texcoord);
    float px = ReShade::PixelSize.x / layerScale; // Adjusted pixel size for the current layer's scale
    
    // Dynamic sigma based on BloomWidth and layer scale - wider layers get relatively more blur
    float bSigma = BloomWidth * (1.0 / layerScale) * 2.0; 

    // Gaussian Math (from PD80, adapted)
    float3 SigmaWeights;
    SigmaWeights.x = 1.0f / (sqrt(2.0f * 3.141592f) * bSigma);
    SigmaWeights.y = exp(-0.5f / (bSigma * bSigma));
    SigmaWeights.z = SigmaWeights.y * SigmaWeights.y;

    float totalWeight = SigmaWeights.x;
    color.rgb *= SigmaWeights.x;

    float currentOffset = 1.5f; // Initial offset

    [loop]
    for(int i = 0; i < BLOOM_ITERATIONS; ++i)
    {
        SigmaWeights.xy *= SigmaWeights.yz; // Update weights for next step
        if(SigmaWeights.x < BLOOM_LOOP_LIMITER) break; // Stop if weight is too small

        float weightPair = SigmaWeights.x * 2.0; // Combined weight for two samples
        
        color.rgb += tex2D(sourceSampler, texcoord + float2(currentOffset * px, 0.0f)).rgb * SigmaWeights.x;
        color.rgb += tex2D(sourceSampler, texcoord - float2(currentOffset * px, 0.0f)).rgb * SigmaWeights.x;
        
        totalWeight += weightPair;
        currentOffset += 2.0f; // Increase offset for next samples
    }

    color.rgb /= totalWeight;
    return color;
}

// Iterative Gaussian blur - Vertical pass (inspired by PD80)
float4 PS_BloomBlurV(float4 pos : SV_Position, float2 texcoord : TEXCOORD, sampler2D sourceSampler, float layerScale) : SV_Target
{
    float4 color = tex2D(sourceSampler, texcoord);
    float py = ReShade::PixelSize.y / layerScale; // Adjusted pixel size

    float bSigma = BloomWidth * (1.0 / layerScale) * 2.0;

    float3 SigmaWeights;
    SigmaWeights.x = 1.0f / (sqrt(2.0f * 3.141592f) * bSigma);
    SigmaWeights.y = exp(-0.5f / (bSigma * bSigma));
    SigmaWeights.z = SigmaWeights.y * SigmaWeights.y;

    float totalWeight = SigmaWeights.x;
    color.rgb *= SigmaWeights.x;

    float currentOffset = 1.5f;

    [loop]
    for(int i = 0; i < BLOOM_ITERATIONS; ++i)
    {
        SigmaWeights.xy *= SigmaWeights.yz; 
        if(SigmaWeights.x < BLOOM_LOOP_LIMITER) break;

        float weightPair = SigmaWeights.x * 2.0;

        color.rgb += tex2D(sourceSampler, texcoord + float2(0.0f, currentOffset * py)).rgb * SigmaWeights.x;
        color.rgb += tex2D(sourceSampler, texcoord - float2(0.0f, currentOffset * py)).rgb * SigmaWeights.x;
        
        totalWeight += weightPair;
        currentOffset += 2.0f;
    }

    color.rgb /= totalWeight;
    return color;
}

// Bloom passes for each layer (no change, but will use the new blur functions)
float4 PS_BloomLayer1H(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return PS_BloomBlurH(pos, texcoord, BloomThresholdSampler, BLOOM_DOWNSAMPLE_SCALE_1);
}

float4 PS_BloomLayer1V(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return PS_BloomBlurV(pos, texcoord, BloomLayer1HorizontalSampler, BLOOM_DOWNSAMPLE_SCALE_1);
}

float4 PS_BloomLayer2H(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return PS_BloomBlurH(pos, texcoord, BloomThresholdSampler, BLOOM_DOWNSAMPLE_SCALE_2);
}

float4 PS_BloomLayer2V(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return PS_BloomBlurV(pos, texcoord, BloomLayer2HorizontalSampler, BLOOM_DOWNSAMPLE_SCALE_2);
}

float4 PS_BloomLayer3H(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return PS_BloomBlurH(pos, texcoord, BloomThresholdSampler, BLOOM_DOWNSAMPLE_SCALE_3);
}

float4 PS_BloomLayer3V(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return PS_BloomBlurV(pos, texcoord, BloomLayer3HorizontalSampler, BLOOM_DOWNSAMPLE_SCALE_3);
}

//#endregion

//#region Pixel Shaders

// Separable Bilateral Filter - Horizontal Pass
float4 PS_LocalLuminanceHPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float totalWeight = 0.0;
    float filteredLuminance = 0.0;
    float centerLuminance = dot(tex2D(BackBuffer, texcoord).rgb, float3(0.2126, 0.7152, 0.0722));

    [unroll]
    for (int x = -BILATERAL_SAMPLES / 2; x <= BILATERAL_SAMPLES / 2; x++) {
        float2 offset = float2(x, 0) * BILATERAL_RADIUS * ReShade::PixelSize.x;
        float3 sampleColor = tex2D(BackBuffer, texcoord + offset).rgb;
        float sampleLuminance = dot(sampleColor, float3(0.2126, 0.7152, 0.0722));

        float spatialWeight = exp(-(x*x) / (2.0 * BILATERAL_SIGMA_SPATIAL * BILATERAL_SIGMA_SPATIAL));
        float rangeWeight = exp(-abs(sampleLuminance - centerLuminance) / (2.0 * BILATERAL_SIGMA_RANGE * BILATERAL_SIGMA_RANGE));
        float weight = spatialWeight * rangeWeight;

        filteredLuminance += sampleLuminance * weight;
        totalWeight += weight;
    }

    return filteredLuminance / max(totalWeight, 0.0001);
}

// Separable Bilateral Filter - Vertical Pass
float4 PS_LocalLuminanceVPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    float totalWeight = 0.0;
    float filteredLuminance = 0.0;
    // Recalculate center luminance from original backbuffer for range comparison
    float centerLuminanceOriginal = dot(tex2D(BackBuffer, texcoord).rgb, float3(0.2126, 0.7152, 0.0722));

    [unroll]
    for (int y = -BILATERAL_SAMPLES / 2; y <= BILATERAL_SAMPLES / 2; y++) {
        float2 offset = float2(0, y) * BILATERAL_RADIUS * ReShade::PixelSize.y;
        // Read horizontally filtered luminance from intermediate texture
        float sampleLuminanceHFiltered = tex2D(LocalLuminanceHPassSampler, texcoord + offset).r;

        float spatialWeight = exp(-(y*y) / (2.0 * BILATERAL_SIGMA_SPATIAL * BILATERAL_SIGMA_SPATIAL));
        // Range weight uses difference between H-filtered sample and original center luminance
        float rangeWeight = exp(-abs(sampleLuminanceHFiltered - centerLuminanceOriginal) / (2.0 * BILATERAL_SIGMA_RANGE * BILATERAL_SIGMA_RANGE));
        float weight = spatialWeight * rangeWeight;

        filteredLuminance += sampleLuminanceHFiltered * weight;
        totalWeight += weight;
    }

    float currentLuminance = filteredLuminance / max(totalWeight, 0.0001);
    
    // Apply temporal smoothing by blending with previous frame's luminance
    float prevLuminance = tex2D(PrevLocalLuminanceSampler, texcoord).r;
    
    // Use the same adaptation time parameter used for global adaptation
    float alpha = 0.0;
    if (AdaptTime > 0.0)
        alpha = 1.0 - exp(- (FrameTime * 0.001) / (AdaptTime * LocalAdaptSmoothingMultiplier));
    else
        alpha = 1.0; // Immediate adaptation if AdaptTime is zero
    
    // Blend current and previous luminance values
    return lerp(prevLuminance, currentLuminance, alpha);
}

// Calculate adaptation values
float4 PS_CalculateAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    // Fetch current color and compute luminance
    float3 color = tex2D(BackBuffer, uv).rgb;
    float currentAdapt = dot(color, float3(0.299, 0.587, 0.114));
    currentAdapt *= AdaptSensitivity;

    // Fetch the last adaptation value
    float lastAdapt = tex2Dfetch(LastAdapt, int2(0, 0), 0).x;

    // Calculate the smoothing factor alpha using EMA
    float alpha = 0.0;
    if (AdaptTime > 0.0)
        alpha = 1.0 - exp(- (FrameTime * 0.001) / AdaptTime);
    else
        alpha = 1.0; // Immediate adaptation if AdaptTime is zero

    // Compute the new adaptation value using EMA
    float adapt = lerp(lastAdapt, currentAdapt, alpha);

    // Return the adapted luminance value
    return adapt;
}


// Save adaptation values
float4 PS_SaveAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return tex2Dlod(Small, float4(ADAPT_FOCAL_POINT, 0, AdaptMipLevels - ADAPT_PRECISION));
}

float4 ApplyMicroContrast(float3 color, float2 texcoord, out float4 debugOutput) {
    float3 labColor = RGB2Lab(color);
    float3 microDetail = 0.0;
    float3 totalWeight = 0.0;
    
    static const int numDirections = 8;
    static const float2 directions[numDirections] = {
        float2(1, 0), float2(-1, 0),
        float2(0, 1), float2(0, -1),
        float2(0.707, 0.707), float2(-0.707, 0.707),
        float2(0.707, -0.707), float2(-0.707, -0.707)
    };
    
    float3 debugDetailVectors = 0.0;
    float debugNoiseMask = 0.0;
    float debugDetailStrength = 0.0;
    
    [unroll]
    for(int i = 0; i < numDirections; i++) {
        float2 offset = directions[i] * ReShade::PixelSize * 2.0;
        float3 sampleLab = RGB2Lab(tex2D(BackBuffer, texcoord + offset).rgb);
        
        // Calculate detail in LAB space
        float3 detailVector = labColor - sampleLab;
        
        float lumWeight = exp(-abs(detailVector.x) / MicroContrastFalloff);
        float colorWeight = exp(-length(detailVector.yz) / MicroContrastFalloff);
        
        float lumNoise = smoothstep(0.0, MicroContrastNoiseThreshold, abs(detailVector.x));
        float colorNoise = smoothstep(0.0, MicroContrastNoiseThreshold, length(detailVector.yz));
        
        float3 weight = float3(lumWeight, colorWeight, colorWeight);
        float3 noiseMask = float3(lumNoise, colorNoise, colorNoise);
        
        weight *= noiseMask;
        
        microDetail += detailVector * weight;
        totalWeight += weight;
        
        // Debug information
        debugDetailVectors += abs(detailVector);
        debugNoiseMask += float(lumNoise + colorNoise) * 0.5;  // Fixed: convert to scalar
        debugDetailStrength += (abs(detailVector.x) + length(detailVector.yz)) * 0.5;  // Fixed: use abs() for x
    }
    
    microDetail /= max(totalWeight, float3(0.001, 0.001, 0.001));
    
    // Apply enhancement in LAB space
    float3 enhancedLab = labColor + microDetail * MicroContrastStrength * float3(3.0, 1.5, 1.5);
    
    // Debug output handling
    debugOutput = 0.0;
    switch(DebugMode) {
        case 1: debugOutput = float4(debugDetailVectors * DebugMultiplier / numDirections, 1.0); break;
        case 2: debugOutput = float4(debugNoiseMask.xxx * DebugMultiplier / numDirections, 1.0); break;
        case 3: debugOutput = float4(debugDetailStrength.xxx * DebugMultiplier / numDirections, 1.0); break;
        case 4: debugOutput = float4(normalize(microDetail) * 0.5 + 0.5, 1.0); break;
    }
    
    return float4(Lab2RGB(enhancedLab), 1.0);
}

float3 ApplyLocalContrast(float3 color, float2 texcoord) {
    float3 labColor = RGB2Lab(color);
    float3 labSum = 0;
    float weightSum = 0;
    
    // Calculate local LAB statistics using bilateral filtering
    [unroll]
    for (int x = -2; x <= 2; x++) {
        [unroll]
        for (int y = -2; y <= 2; y++) {
            float2 offset = float2(x, y) * LocalContrastRadius * ReShade::PixelSize;
            float3 neighborLab = RGB2Lab(tex2D(BackBuffer, texcoord + offset).rgb);
            
            // Spatial weight
            float spatialWeight = exp(-(x*x + y*y) / (2.0 * LocalContrastRadius * LocalContrastRadius));
            
            // Range weight in LAB space (more perceptually accurate)
            float labDist = length(neighborLab - labColor);
            float rangeWeight = exp(-labDist / (2.0 * 10.0)); // 10.0 is LAB sigma
            
            float weight = spatialWeight * rangeWeight;
            labSum += neighborLab * weight;
            weightSum += weight;
        }
    }
    
    float3 localLabAvg = labSum / weightSum;
    
    // Enhanced contrast in LAB space
    float3 labDiff = labColor - localLabAvg;
    
    // Separate enhancement for L and a/b channels
    labColor.x += labDiff.x * LocalContrastStrength * 2.0; // Luminance enhancement
    labColor.yz += labDiff.yz * LocalContrastStrength * 1.2; // Color enhancement
    
    return Lab2RGB(labColor);
}

// Save current local luminance for the next frame
float4 PS_SaveLocalLuminance(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
    return tex2D(LocalLuminanceSampler, texcoord);
}

// Modified Main PS to incorporate bloom and its debug views
float4 MainPS(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    float4 color = tex2D(BackBuffer, texcoord);
    float4 originalColor = color;

    // Get local luminance from the pre-calculated texture
    float localLuminance = tex2D(LocalLuminanceSampler, texcoord).r;
    
    // Get adaptation value
    float adaptedLuminance;
    if (EnableAdaptation)
    {
        adaptedLuminance = tex2Dfetch(LastAdapt, int2(0, 0), 0).x;
        adaptedLuminance = clamp(adaptedLuminance, AdaptRange.x, AdaptRange.y);
    }
    else
    {
        adaptedLuminance = FixedLuminance;
    }

    // Apply exposure adjustment with white point preservation
    float whitePoint = 1.2;
    // Calculate combined brightness factor
    float totalBrightness = exp2(Exposure) * SceneBrightness;
    
    // Apply exposure while maintaining the white point relationship
    // color.rgb *= exposure / whitePoint; // Moved brightness application before LAB
    // color.rgb = ApplyGamma(color.rgb, Gamma); // Moved Gamma application later

    // Convert to LAB space once for all LAB-based operations
    // Apply total brightness before converting to LAB
    float3 labColor = RGB2Lab(color.rgb * totalBrightness);
    float4 debugOutput = 0.0;

    // Apply LAB Gamma adjustment to Lightness channel
    labColor.x = pow(max(labColor.x / 100.0, 0.0001), 1.0 / LabGamma) * 100.0; // Normalize L (0-100 -> 0-1), apply gamma, scale back

    // Apply all LAB-space operations
    if (EnableLocalContrast || EnableMicroContrast || true) // Always apply LAB processing
    {
        // Apply local contrast in LAB space if enabled
        if (EnableLocalContrast)
        {
            // Extract local contrast logic from ApplyLocalContrast function but keep in LAB
            float3 labSum = 0;
            float weightSum = 0;
            
            // Calculate local LAB statistics using bilateral filtering
            [unroll]
            for (int x = -2; x <= 2; x++) {
                [unroll]
                for (int y = -2; y <= 2; y++) {
                    float2 offset = float2(x, y) * LocalContrastRadius * ReShade::PixelSize;
                    // Apply total brightness to samples before LAB conversion
                    float3 neighborLab = RGB2Lab(tex2D(BackBuffer, texcoord + offset).rgb * totalBrightness);
                    
                    // Spatial weight
                    float spatialWeight = exp(-(x*x + y*y) / (2.0 * LocalContrastRadius * LocalContrastRadius));
                    
                    // Range weight in LAB space (more perceptually accurate)
                    float labDist = length(neighborLab - labColor);
                    float rangeWeight = exp(-labDist / (2.0 * 10.0)); // 10.0 is LAB sigma
                    
                    float weight = spatialWeight * rangeWeight;
                    labSum += neighborLab * weight;
                    weightSum += weight;
                }
            }
            
            float3 localLabAvg = labSum / weightSum;
            
            // Enhanced contrast in LAB space
            float3 labDiff = labColor - localLabAvg;
            
            // Separate enhancement for L and a/b channels
            labColor.x += labDiff.x * LocalContrastStrength * 2.0; // Luminance enhancement
            labColor.yz += labDiff.yz * LocalContrastStrength * 1.2; // Color enhancement
        }
        
        // Apply micro contrast in LAB space if enabled
        if (EnableMicroContrast)
        {
            // Extract micro contrast logic but keep in LAB
            float3 microDetail = 0.0;
            float3 totalWeight = 0.0;
            
            static const int numDirections = 8;
            static const float2 directions[numDirections] = {
                float2(1, 0), float2(-1, 0),
                float2(0, 1), float2(0, -1),
                float2(0.707, 0.707), float2(-0.707, 0.707),
                float2(0.707, -0.707), float2(-0.707, -0.707)
            };
            
            float3 debugDetailVectors = 0.0;
            float debugNoiseMask = 0.0;
            float debugDetailStrength = 0.0;
            
            [unroll]
            for(int i = 0; i < numDirections; i++) {
                float2 offset = directions[i] * ReShade::PixelSize * 2.0;
                // Apply total brightness to samples before LAB conversion
                float3 sampleLab = RGB2Lab(tex2D(BackBuffer, texcoord + offset).rgb * totalBrightness);
                
                // Calculate detail in LAB space
                float3 detailVector = labColor - sampleLab;
                
                float lumWeight = exp(-abs(detailVector.x) / MicroContrastFalloff);
                float colorWeight = exp(-length(detailVector.yz) / MicroContrastFalloff);
                
                float lumNoise = smoothstep(0.0, MicroContrastNoiseThreshold, abs(detailVector.x));
                float colorNoise = smoothstep(0.0, MicroContrastNoiseThreshold, length(detailVector.yz));
                
                float3 weight = float3(lumWeight, colorWeight, colorWeight);
                float3 noiseMask = float3(lumNoise, colorNoise, colorNoise);
                
                weight *= noiseMask;
                
                microDetail += detailVector * weight;
                totalWeight += weight;
                
                // Debug information
                debugDetailVectors += abs(detailVector);
                debugNoiseMask += float(lumNoise + colorNoise) * 0.5;
                debugDetailStrength += (abs(detailVector.x) + length(detailVector.yz)) * 0.5;
            }
            
            microDetail /= max(totalWeight, float3(0.001, 0.001, 0.001));
            
            // Apply enhancement in LAB space
            labColor += microDetail * MicroContrastStrength * float3(3.0, 1.5, 1.5);
            
            // Debug output handling
            if (DebugMode > 0) {
                switch(DebugMode) {
                    case 1: debugOutput = float4(debugDetailVectors * DebugMultiplier / numDirections, 1.0); break;
                    case 2: debugOutput = float4(debugNoiseMask.xxx * DebugMultiplier / numDirections, 1.0); break;
                    case 3: debugOutput = float4(debugDetailStrength.xxx * DebugMultiplier / numDirections, 1.0); break;
                    case 4: debugOutput = float4(normalize(microDetail) * 0.5 + 0.5, 1.0); break;
                }
            }
        }
        
        // Apply zonal adjustments in LAB space
        // L channel in LAB is perceptual luminance
        float luminance = labColor.x / 100.0; // L ranges from 0-100, normalize to 0-1
        
        // Zonal Definitions
        float HighlightsStart = 0.0;
        float ShadowsEnd = 0.3;

        // Calculate zonal weights based on LAB luminance
        float shadowWeight = 1.0 - smootherstep(0.0, ShadowsEnd, luminance);
        float highlightWeight = smootherstep(HighlightsStart, 0.5, luminance);
        
        // Independent midtone weight calculation
        float midtoneWeight = exp(-pow(luminance - MidtonesCenter, 2) / (2 * MidtonesWidth * MidtonesWidth));

        // Normalize weights
        float totalWeight = shadowWeight + midtoneWeight + highlightWeight;
        shadowWeight /= totalWeight;
        midtoneWeight /= totalWeight;
        highlightWeight /= totalWeight;
        
        // Apply zonal luminance adjustments in LAB space
        float zonalAdjustment = shadowWeight * ShadowAdjustment + 
                               midtoneWeight * MidtoneAdjustment + 
                               highlightWeight * HighlightAdjustment;
        
        // Apply to L channel (more perceptually accurate than RGB)
        labColor.x *= zonalAdjustment;
        
        // Vibrance and saturation adjustments in LAB space
        // LAB a/b channels represent chromaticity
        float chromaValue = length(labColor.yz);
        float saturationFactor = 1.0;
        
        // Use vibrance curve in LAB space
        saturationFactor = pow(1.0 - min(1.0, chromaValue / 128.0), VibranceCurve) * LocalSaturationBoost + 1.0;
        
        // Skin tone protection in LAB space
        // Skin tones fall within a specific region in LAB space
        float skinTone = smoothstep(0.0, 0.2, 
                          exp(-pow(labColor.y - 15, 2) / 150) * // a channel for redness
                          exp(-pow(labColor.z - 15, 2) / 150)); // b channel for yellowness
        
        float skinProtect = lerp(1.0, saturate(1.0 - skinTone), SkinToneProtection);
        
        // Apply saturation and skin protection in LAB
        labColor.yz *= lerp(1.0, saturationFactor, skinProtect);
        
        // Convert back to RGB just once
        color.rgb = Lab2RGB(labColor);
    } else {
         // If no LAB ops were enabled, need to apply brightness here before tonemapping
         color.rgb *= totalBrightness;
    }
    
    // Apply adaptation factor. adaptedLuminance is based on original backbuffer, so divide after brightness/LAB ops
    float adaptationFactor = max(adaptedLuminance, 0.001);
    color.rgb /= adaptationFactor;

    // Tone mapping after LAB operations
    float localAdaptation = pow(localLuminance / adaptedLuminance, 0.5);
    localAdaptation = lerp(1.0, localAdaptation, LocalAdaptationStrength);
    
    float3 colorForTonemap = color.rgb * localAdaptation;
    
    // **Select Tonemapping Curve Based on User Choice**
    float3 toneMapped;
    if (TonemapperType == 0) {
        // ACES Tonemapping
        toneMapped = ACES_RRT(colorForTonemap);
    } else {
        // AgX Tonemapping
        toneMapped = AgX_Tonemap(colorForTonemap);
    }
    
    // Apply tonemapping with intensity
    color.rgb = lerp(color.rgb, toneMapped, TonemappingIntensity);
    
    // Apply Gamut Mapping before final adjustments
    color.rgb = GamutMap(color.rgb);

    // Apply Final Gamma *after* tonemapping and gamut mapping
    color.rgb = ApplyGamma(color.rgb, Gamma);
    
    // --- Bloom Application --- (Applied after tonemapping and main adjustments)
    float4 combinedBloom = 0.0; // Initialize to black
    if (EnableBloom) {
        // Sample the three bloom layers
        float4 bloom1 = tex2D(BloomLayer1Sampler, texcoord) * Bloom1Weight;
        float4 bloom2 = tex2D(BloomLayer2Sampler, texcoord) * Bloom2Weight;
        float4 bloom3 = tex2D(BloomLayer3Sampler, texcoord) * Bloom3Weight;
        
        combinedBloom = max(bloom1, max(bloom2, bloom3)); 
        color.rgb += combinedBloom.rgb; // Additive blend
    }

    // --- Micro Contrast Debug View --- (Has its own separate DebugMode uniform)
    if (DebugMode > 0 && EnableMicroContrast) { 
        // Assuming debugOutput for micro-contrast is calculated within its block if DebugMode is active
        // This needs to be correctly sourced if micro-contrast debug is desired.
        // For now, this just illustrates placement relative to bloom debug.
        // If micro-contrast debug is active, it might take precedence or be combined.
        // For simplicity, let micro-contrast debug take precedence if its DebugMode > 0.
        // float4 microContrastDebugOutput = getMicroContrastDebugOutput(); // Placeholder
        // return microContrastDebugOutput; 
    }

    // --- Bloom Debug Views --- (Takes precedence over final output if active)
    if (BloomDebugView > 0) {
        float4 debugBloomColor = 0.0;
        switch (BloomDebugView) {
            case 1: // Bloom Prefilter (ThresholdTex)
                debugBloomColor = tex2D(BloomThresholdSampler, texcoord);
                break;
            case 2: // Bloom Layer 1 Output
                debugBloomColor = tex2D(BloomLayer1Sampler, texcoord);
                break;
            case 3: // Bloom Layer 2 Output
                debugBloomColor = tex2D(BloomLayer2Sampler, texcoord);
                break;
            case 4: // Bloom Layer 3 Output
                debugBloomColor = tex2D(BloomLayer3Sampler, texcoord);
                break;
        }
        return float4(debugBloomColor.rgb * BloomDebugBrightness, 1.0);
    }

    // --- Final Blending with originalColor --- (If no debug views are active)
    float3 blendedColor;
    float3 processedColor = color.rgb; // Result after tonemapping, gamut, gamma, AND bloom

    switch (BlendMode)
    {
        case 0: blendedColor = lerp(originalColor.rgb, processedColor, GlobalOpacity); break;
        case 1: blendedColor = originalColor.rgb + processedColor * GlobalOpacity; break;
        case 2: blendedColor = lerp(originalColor.rgb, originalColor.rgb * processedColor, GlobalOpacity); break;
        case 3: blendedColor = 1.0 - (1.0 - originalColor.rgb) * (1.0 - lerp(0.0, processedColor, GlobalOpacity)); break;
        case 4: {
            float3 overlayResult;
            for (int i = 0; i < 3; ++i) {
                if (originalColor[i] <= 0.5) overlayResult[i] = 2.0 * originalColor[i] * processedColor[i];
                else overlayResult[i] = 1.0 - 2.0 * (1.0 - originalColor[i]) * (1.0 - processedColor[i]);
            }
            blendedColor = lerp(originalColor.rgb, overlayResult, GlobalOpacity);
            break;
        }
        default: blendedColor = lerp(originalColor.rgb, processedColor, GlobalOpacity); break;
    }

    // Apply white point scaling *after* blending
    color.rgb = blendedColor * whitePoint; 

    return saturate(color); // Final saturation clamp
}

//#endregion

//#region Technique

technique LocalTonemapper {
    pass CalculateAdaptation { VertexShader = PostProcessVS; PixelShader = PS_CalculateAdaptation; RenderTarget = SmallTex; }
    pass SaveAdaptation { VertexShader = PostProcessVS; PixelShader = PS_SaveAdaptation; RenderTarget = LastAdaptTex; }
    pass LocalLuminanceHPass { VertexShader = PostProcessVS; PixelShader = PS_LocalLuminanceHPass; RenderTarget = LocalLuminanceHPassTex; }
    pass LocalLuminanceVPass { VertexShader = PostProcessVS; PixelShader = PS_LocalLuminanceVPass; RenderTarget = LocalLuminanceTex; }
    pass SaveLocalLuminance { VertexShader = PostProcessVS; PixelShader = PS_SaveLocalLuminance; RenderTarget = PrevLocalLuminanceTex; }
    
    // Bloom extraction and blur passes
    pass BloomPrefilterPass { // Renamed from BloomThreshold to reflect its new role
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomPrefilter; // Use the new prefilter shader
        RenderTarget = BloomThresholdTex;
    }
    
    pass BloomLayer1H { VertexShader = PostProcessVS; PixelShader = PS_BloomLayer1H; RenderTarget = BloomLayer1HorizontalTex; }
    pass BloomLayer1V { VertexShader = PostProcessVS; PixelShader = PS_BloomLayer1V; RenderTarget = BloomLayer1Tex; }
    pass BloomLayer2H { VertexShader = PostProcessVS; PixelShader = PS_BloomLayer2H; RenderTarget = BloomLayer2HorizontalTex; }
    pass BloomLayer2V { VertexShader = PostProcessVS; PixelShader = PS_BloomLayer2V; RenderTarget = BloomLayer2Tex; }
    pass BloomLayer3H { VertexShader = PostProcessVS; PixelShader = PS_BloomLayer3H; RenderTarget = BloomLayer3HorizontalTex; }
    pass BloomLayer3V { VertexShader = PostProcessVS; PixelShader = PS_BloomLayer3V; RenderTarget = BloomLayer3Tex; }
    
    pass ApplyTonemapping { VertexShader = PostProcessVS; PixelShader = MainPS; SRGBWriteEnable = true; }
}

//#endregion