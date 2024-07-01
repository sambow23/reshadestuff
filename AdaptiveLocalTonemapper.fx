// Adaptive Local Tonemapper for ReShade
// Author: CR
// Credits: 
//     100% of code written by: ChatGPT 4o and Claude 3.5 
//     Adaptation Code from luluco250's AdaptiveTonemapper.fx

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// Adaptive tonemapping constants
#define ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE 256
#define ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS 9
#define BILATERAL_SAMPLES 9
#define BILATERAL_RADIUS 4.0
#define BILATERAL_SIGMA_SPATIAL 3.0
#define BILATERAL_SIGMA_RANGE 0.1

static const int AdaptMipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;

//#region Uniforms

// Exposure
uniform float Exposure <
    ui_type = "slider";
    ui_label = "Exposure";
    ui_tooltip = "Adjusts the overall brightness before tonemapping. Higher values brighten the image, lower values darken it.";
    ui_category = "Exposure";
    ui_min = -2.0;
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
    ui_max = 1.5;
    ui_step = 0.01;
> = 0.8;

// Local Adjustments
uniform float LocalAdaptationStrength <
    ui_type = "slider";
    ui_label = "Local Adaptation";
    ui_tooltip = "Adjusts how much the tone mapping adapts to local brightness. Higher values increase local contrast.";
    ui_category = "Local Adjustments";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.2;

uniform float LocalContrastAdaptation <
    ui_type = "slider";
    ui_label = "Local Contrast";
    ui_tooltip = "Enhances contrast in local areas. Higher values make details pop more.";
    ui_category = "Local Adjustments";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 0.0;

// Color
uniform float LocalSaturationBoost <
    ui_type = "slider";
    ui_label = "Color Vibrance";
    ui_tooltip = "Boosts color saturation, especially in less saturated areas. Higher values make colors more vivid.";
    ui_category = "Color";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.1;

// Final Adjustments
uniform float Brightness <
    ui_type = "slider";
    ui_label = "Final Brightness";
    ui_tooltip = "Adjusts the overall brightness of the final image. Use this for fine-tuning after other adjustments.";
    ui_category = "Final Adjustments";
    ui_min = 0.5;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;

uniform float Gamma <
    ui_type = "slider";
    ui_label = "Final Gamma";
    ui_tooltip = "Adjusts the gamma curve of the final image. Lower values brighten shadows, higher values darken midtones.";
    ui_category = "Final Adjustments";
    ui_min = 0.1;
    ui_max = 2.2;
    ui_step = 0.01;
> = 1.0;

// Adaptation
uniform float2 AdaptRange <
    ui_type = "drag";
    ui_label = "Adaptation Range";
    ui_tooltip = "The minimum and maximum values that adaptation can use.";
    ui_category = "Adaptation";
    ui_min = 0.001;
    ui_max = 1.0;
    ui_step = 0.001;
> = float2(0.0, 1.0);

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
    ui_max = 3.0;
    ui_step = 0.01;
> = 1.0;

uniform int AdaptPrecision <
    ui_type = "slider";
    ui_label = "Adaptation Precision";
    ui_tooltip = "The amount of precision used when determining the overall brightness.";
    ui_category = "Adaptation";
    ui_min = 0;
    ui_max = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;
> = 0;

uniform float2 AdaptFocalPoint <
    ui_type = "drag";
    ui_label = "Adaptation Focal Point";
    ui_tooltip = "Determines a point in the screen that adaptation will be centered around.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001;
> = 0.5;

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

//#endregion

//#region Helper Functions

// Calculate local luminance using bilateral filtering
float CalculateLocalLuminance(float2 texcoord) {
    float totalWeight = 0.0;
    float filteredLuminance = 0.0;
    float centerLuminance = dot(tex2D(BackBuffer, texcoord).rgb, float3(0.2126, 0.7152, 0.0722));

    [unroll]
    for (int x = -BILATERAL_SAMPLES / 2; x <= BILATERAL_SAMPLES / 2; x++) {
        [unroll]
        for (int y = -BILATERAL_SAMPLES / 2; y <= BILATERAL_SAMPLES / 2; y++) {
            float2 offset = float2(x, y) * BILATERAL_RADIUS * ReShade::PixelSize;
            float3 sampleColor = tex2D(BackBuffer, texcoord + offset).rgb;
            float sampleLuminance = dot(sampleColor, float3(0.2126, 0.7152, 0.0722));

            float spatialWeight = exp(-(x*x + y*y) / (2.0 * BILATERAL_SIGMA_SPATIAL * BILATERAL_SIGMA_SPATIAL));
            float rangeWeight = exp(-abs(sampleLuminance - centerLuminance) / (2.0 * BILATERAL_SIGMA_RANGE * BILATERAL_SIGMA_RANGE));
            float weight = spatialWeight * rangeWeight;

            filteredLuminance += sampleLuminance * weight;
            totalWeight += weight;
        }
    }

    return filteredLuminance / totalWeight;
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

// Local ACES RRT Tonemapping function
float3 ACES_RRT_Local(float3 color, float localLuminance, float adaptedLuminance) {
    const float A = 2.51;
    const float B = 0.03;
    const float C = 2.43;
    const float D = 0.59;
    const float E = 0.14;

    float adaptationFactor = max(adaptedLuminance, 0.001);
    float3 adaptedColor = color / adaptationFactor;

    // Local adaptation
    float localAdaptation = lerp(1.0, localLuminance / adaptationFactor, LocalAdaptationStrength);
    adaptedColor *= localAdaptation;

    // Local Contrast
    // Define a small epsilon value to avoid division by zero or extremely small values
    const float epsilon = 0.001;
    float safeAdaptationFactor = max(adaptationFactor, epsilon);

    // Calculate local contrast adaptation with clamping
    float contrastAdaptation = 1.0 + (LocalContrastAdaptation * (1.0 - saturate(localLuminance / safeAdaptationFactor)));

    // Apply the contrast adaptation
    adaptedColor *= contrastAdaptation;

    float3 toneMapped = (adaptedColor * (A * adaptedColor + B)) / (adaptedColor * (C * adaptedColor + D) + E);
    
    // Apply local saturation boost
    float3 saturationBoost = lerp(dot(toneMapped, float3(0.2126, 0.7152, 0.0722)), toneMapped, 1.0 + LocalSaturationBoost * (1.0 - localLuminance / adaptationFactor));
    
    return saturationBoost;
}

// Apply Gamma Correction
float3 ApplyGamma(float3 color, float gamma) {
    return pow(max(color, 0.0001), 1.0 / gamma);
}

//#endregion

//#region Pixel Shaders

// Calculate adaptation values
float4 PS_CalculateAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float3 color = tex2D(BackBuffer, uv).rgb;
    float adapt = dot(color, float3(0.299, 0.587, 0.114));
    adapt *= AdaptSensitivity;

    float last = tex2Dfetch(LastAdapt, int2(0, 0), 0).x;

    if (AdaptTime > 0.0)
        adapt = lerp(last, adapt, saturate((FrameTime * 0.001) / AdaptTime));

    return adapt;
}

// Save adaptation values
float4 PS_SaveAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return tex2Dlod(Small, float4(AdaptFocalPoint, 0, AdaptMipLevels - AdaptPrecision));
}

// Main tonemapping pass
float4 MainPS(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET {
    float4 color = tex2D(BackBuffer, texcoord);
    float localLuminance = CalculateLocalLuminance(texcoord);
    
    float adaptedLuminance = tex2Dfetch(LastAdapt, int2(0, 0), 0).x;
    adaptedLuminance = clamp(adaptedLuminance, AdaptRange.x, AdaptRange.y);

    float exposure = exp2(Exposure);
    
    // Apply exposure adjustment
    color.rgb *= exposure;

    // Apply local ACES RRT tonemapping
    color.rgb = ACES_RRT_Local(color.rgb * TonemappingIntensity, localLuminance, adaptedLuminance);

    // Apply brightness adjustment
    color.rgb *= Brightness;

    // Apply gamma correction
    color.rgb = ApplyGamma(color.rgb, Gamma);

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
    pass ApplyTonemapping {
        VertexShader = PostProcessVS;
        PixelShader = MainPS;
        SRGBWriteEnable = true;
    }
}

//#endregion
