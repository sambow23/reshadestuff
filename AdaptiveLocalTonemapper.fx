// Adaptive Local Tonemapper for ReShade
// Author: CR
// Credits: 
//     100% of code written by multiple LLMs
//     Some adaptation Code from luluco250's AdaptiveTonemapper.fx
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

static const int AdaptMipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;

// AgX LUT texture
texture AgXLUTTex < source = "AgX-default_contrast.lut.png"; > { Width = 32*32; Height = 32; Format = RGBA8; };
sampler2D AgXLUTSampler { Texture = AgXLUTTex; };

//#region Uniforms

// Final Adjustments

uniform int TonemapperType <
    ui_type = "combo";
    ui_label = "Tonemapper Type";
    ui_tooltip = "Select the tonemapping algorithm to use. (ACES/AgX settings do not match each other, please re-adjust when switching tonemappers)";
    ui_category = "Tone Mapping";
    ui_items = "ACES\0AgX\0";
> = 1;

uniform float Gamma <
    ui_type = "slider";
    ui_label = "Final Gamma";
    ui_tooltip = "Adjusts the gamma curve of the final image. Lower values brighten shadows, higher values darken midtones.";
    ui_category = "Final Adjustments";
    ui_min = 0.1;
    ui_max = 2.2;
    ui_step = 0.01;
> = 0.50;

uniform float GlobalOpacity <
    ui_type = "slider";
    ui_label = "Final Opacity";
    ui_tooltip = "Controls the blend between the original image and the processed image. 0 = Original, 1 = Fully Processed";
    ui_category = "Final Adjustments";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 1.0;

// Exposure
uniform float Exposure <
    ui_type = "slider";
    ui_label = "Exposure";
    ui_tooltip = "Adjusts the overall brightness before tonemapping. Higher values brighten the image, lower values darken it.";
    ui_category = "Exposure";
    ui_min = -3.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 0.0;

// Tone Mapping
uniform float TonemappingIntensity <
    ui_type = "slider";
    ui_label = "Tone Mapping Strength";
    ui_tooltip = "Controls the intensity of the tone mapping effect. Higher values increase contrast and color vibrancy.";
    ui_category = "Tone Mapping";
    ui_min = 0.1;
    ui_max = 3.0;
    ui_step = 0.01;
> = 1.5;

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
> = 0.5;

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
> = 0.5;

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
> = float2(0.5, 2.0);

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
> = 0.08;

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
> = 0.04;

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
> = 0.3;

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
    // Transform to AgX compressed space
    color = mul(agx_compressed_matrix, color);
    
    // Convert to log domain
    color = agx_transform_to_log(color);
    
    // Apply AgX curve via LUT
    color = agx_look_lut(color);
    
    // Transform back from compressed space
    color = mul(agx_compressed_matrix_inverse, color);
    
    return color;
}

float3 Tonemap_Local(float3 color, float localLuminance, float adaptedLuminance, float intensity)
{
    float adaptationFactor = max(adaptedLuminance, 0.001);
    float3 adaptedColor = color / adaptationFactor;

    // Convert to Lab space
    float3 labColor = RGB2Lab(adaptedColor);

    float localAdaptation = pow(localLuminance / adaptationFactor, 0.5); // Use 0.5 instead of 0.0 for a square root effect
    localAdaptation = lerp(1.0, localAdaptation, LocalAdaptationStrength); // Use the new parameter instead of 0.0
    
    // Apply local adjustment to L channel
    labColor.x *= localAdaptation;

    // Convert back to RGB
    float3 adjustedColor = Lab2RGB(labColor);

    // Soft clipping to prevent harsh clipping
    adjustedColor = 1.0 - exp(-adjustedColor);

    // Calculate luminance
    float luminance = dot(adjustedColor, float3(0.2126, 0.7152, 0.0722));

    // Zonal Definitions
    float HighlightsStart = 0.0;
    float ShadowsEnd = 0.3;

    // Calculate zonal weights
    float shadowWeight = 1.0 - smootherstep(0.0, ShadowsEnd, luminance);
    float highlightWeight = smootherstep(HighlightsStart, 0.5, luminance);
    
    // Independent midtone weight calculation
    float midtoneWeight = exp(-pow(luminance - MidtonesCenter, 2) / (2 * MidtonesWidth * MidtonesWidth));

    // Normalize weights
    float totalWeight = shadowWeight + midtoneWeight + highlightWeight;
    shadowWeight /= totalWeight;
    midtoneWeight /= totalWeight;
    highlightWeight /= totalWeight;

    // **Select Tonemapping Curve Based on User Choice**
    float3 toneMapped;
    if (TonemapperType == 0) {
        // ACES Tonemapping
        toneMapped = ACES_RRT(adjustedColor);
    } else {
        // AgX Tonemapping
        toneMapped = AgX_Tonemap(adjustedColor);
    }
    
    // Calculate zonal tonemapping intensity
    float zonalIntensity = shadowWeight * ShadowAdjustment + 
                           midtoneWeight * MidtoneAdjustment + 
                           highlightWeight * HighlightAdjustment;

    // Blend between original and tonemapped based on zonal intensities
    return lerp(adjustedColor, toneMapped, intensity * zonalIntensity);
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

    return filteredLuminance / max(totalWeight, 0.0001);
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

// Main tonemapping pass
float4 MainPS(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    float4 color = tex2D(BackBuffer, texcoord);
    float4 originalColor = color;

    // Get local luminance from the pre-calculated texture
    float localLuminance = tex2D(LocalLuminanceSampler, texcoord).r;
    
    // Get adaptation value (reusing existing code)
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

    // Apply local contrast if enabled
    if (EnableLocalContrast)
    {
        color.rgb = ApplyLocalContrast(color.rgb, texcoord);
    }

    // Apply micro contrast if enabled, with debug output
    float4 debugOutput;
    if (EnableMicroContrast)
    {
        float4 microContrastResult = ApplyMicroContrast(color.rgb, texcoord, debugOutput);
        color.rgb = microContrastResult.rgb;
        
        // Show debug visualization if enabled
        if (DebugMode > 0)
        {
            return debugOutput;
        }
    }

    // Apply exposure adjustment with white point preservation
    float whitePoint = 1.2; // Move the static white point here as a constant
    float exposure = exp2(Exposure);
    
    // Apply exposure while maintaining the white point relationship
    color.rgb *= exposure / whitePoint;
    color.rgb = ApplyGamma(color.rgb, Gamma);
    
    // Continue with existing tonemapping
    color.rgb = Tonemap_Local(color.rgb, localLuminance, adaptedLuminance, TonemappingIntensity);

    // Apply the rest of the existing effects (color, brightness, gamma, etc.)
    float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float saturation = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
    float adjustedSaturation = pow(saturation, VibranceCurve);

    // Rest of the existing processing...
    float skinTone = smoothstep(0.2, 0.6, color.r) * smoothstep(0.6, 0.2, color.g) * smoothstep(0.4, 0.2, color.b);
    float skinProtect = lerp(1.0, saturate(1.0 - skinTone), SkinToneProtection);
    float boostFactor = 1.0 + LocalSaturationBoost * (1.0 - adjustedSaturation) * skinProtect;
    float3 boostedColor = lerp(float3(luma, luma, luma), color.rgb, boostFactor);
    color.rgb = lerp(color.rgb, boostedColor, skinProtect);
    color.rgb = lerp(color.rgb, float3(luma, luma, luma), saturate(saturation - 1.0));
    
    // Apply Gamut Mapping before opacity blending and final scaling
    color.rgb = GamutMap(color.rgb);

    // Final adjustments
    color.rgb = lerp(originalColor.rgb, color.rgb, GlobalOpacity);

    color.rgb *= whitePoint;

    return saturate(color);
}

//#endregion

//#region Technique

technique LocalTonemapper {
    pass CalculateAdaptation {
        VertexShader = PostProcessVS;
        PixelShader = PS_CalculateAdaptation;
        RenderTarget = SmallTex;
    }
    pass SaveAdaptation {
        VertexShader = PostProcessVS;
        PixelShader = PS_SaveAdaptation;
        RenderTarget = LastAdaptTex;
    }
    pass LocalLuminanceHPass {
        VertexShader = PostProcessVS;
        PixelShader = PS_LocalLuminanceHPass;
        RenderTarget = LocalLuminanceHPassTex;
    }
    pass LocalLuminanceVPass {
        VertexShader = PostProcessVS;
        PixelShader = PS_LocalLuminanceVPass;
        RenderTarget = LocalLuminanceTex;
    }
    pass ApplyTonemapping {
        VertexShader = PostProcessVS;
        PixelShader = MainPS;
        SRGBWriteEnable = true;
    }
}

//#endregion