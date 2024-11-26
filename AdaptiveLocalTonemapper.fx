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

// Final Adjustments

uniform int TonemapperType <
    ui_type = "combo";
    ui_label = "Tonemapper Type";
    ui_tooltip = "Select the tonemapping algorithm to use.";
    ui_category = "Tone Mapping";
    ui_items = "ACES\0AgX\0";
> = 0;

uniform float Brightness <
    ui_type = "slider";
    ui_label = "Final Brightness";
    ui_tooltip = "Adjusts the overall brightness of the final image. Use this for fine-tuning after other adjustments.";
    ui_category = "Final Adjustments";
    ui_min = 0.5;
    ui_max = 5.0;
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
    ui_max = 1.5;
    ui_step = 0.01;
> = 0.8;

// Local Adjustments
uniform float LocalAdjustmentStrength <
    ui_type = "slider";
    ui_label = "Local Adjustment Strength";
    ui_tooltip = "Controls the overall strength of local adjustments.";
    ui_category = "Local Adjustments";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;

uniform float LocalAdjustmentCurve <
    ui_type = "slider";
    ui_label = "Local Adjustment Curve";
    ui_tooltip = "Adjusts the balance between shadow and highlight processing.";
    ui_category = "Local Adjustments";
    ui_min = 0.1;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;

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
> = 1.0;


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

uniform float ShadowsEnd <
    ui_type = "slider";
    ui_label = "Shadows End";
    ui_tooltip = "Adjusts the LAB end of shadows.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;

uniform float HighlightsStart <
    ui_type = "slider";
    ui_label = "Highlights Start";
    ui_tooltip = "Adjusts the LAB start of highlights.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0;
    ui_max = 2.0;
    ui_step = 0.01;
> = 1.0;

// Adaptation
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
    ui_min = 0.01;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.18;

uniform float2 AdaptRange <
    ui_type = "drag";
    ui_label = "Adaptation Range";
    ui_tooltip = "The minimum and maximum values that adaptation can use.";
    ui_category = "Adaptation";
    ui_min = 0.001;
    ui_max = 2.0;
    ui_step = 0.001;
> = float2(1.0, 2.0);

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
> = 9.0;

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

// Local Contrast Controls
uniform bool EnableLocalContrast <
    ui_type = "checkbox";
    ui_label = "Enable Local Contrast";
    ui_tooltip = "Toggles local contrast enhancement";
    ui_category = "Local Contrast";
> = true;

uniform float LocalContrastStrength <
    ui_type = "slider";
    ui_label = "Local Contrast Strength";
    ui_tooltip = "Controls the strength of local contrast enhancement";
    ui_category = "Local Contrast";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;

uniform float LocalContrastRadius <
    ui_type = "slider";
    ui_label = "Local Contrast Radius";
    ui_tooltip = "Size of the area used for local contrast detection";
    ui_category = "Local Contrast";
    ui_min = 1.0;
    ui_max = 10.0;
    ui_step = 0.1;
> = 3.0;

// Micro Contrast Controls
uniform bool EnableMicroContrast <
    ui_type = "checkbox";
    ui_label = "Enable Micro Contrast";
    ui_tooltip = "Toggles micro contrast enhancement";
    ui_category = "Micro Contrast";
> = true;

uniform float MicroContrastStrength <
    ui_type = "slider";
    ui_label = "Micro Contrast Strength";
    ui_tooltip = "Controls the strength of micro contrast enhancement";
    ui_category = "Micro Contrast";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.3;

uniform float DetailPreservation <
    ui_type = "slider";
    ui_label = "Detail Preservation";
    ui_tooltip = "Prevents over-sharpening of fine details";
    ui_category = "Micro Contrast";
    ui_min = 0.75;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.75;

uniform float NoiseThreshold <
    ui_type = "slider";
    ui_label = "Noise Threshold";
    ui_tooltip = "Prevents enhancement of image noise";
    ui_category = "Micro Contrast";
    ui_min = 0.0;
    ui_max = 0.1;
    ui_step = 0.001;
> = 0.01;

// Add these debug uniforms
uniform int DebugMode <
    ui_type = "combo";
    ui_label = "Debug View";
    ui_tooltip = "Shows different aspects of the micro-contrast enhancement";
    ui_category = "Debug";
    ui_items = "Off\0Detail Map\0Noise Mask\0Enhancement Strength\0Detail Vectors\0";
> = 0;

uniform float DebugMultiplier <
    ui_type = "slider";
    ui_label = "Debug Multiplier";
    ui_tooltip = "Multiplies the debug visualization strength";
    ui_category = "Debug";
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

float3 AgX_Tonemap(float3 color) {
    // AgX tonemapping curve approximation
    // Parameters derived to match the AgX response
    float3 tonemappedColor = color / (color + float3(0.155, 0.155, 0.155)) * 1.019; // Simple approximation
    return tonemappedColor;
}


// **Modified Tonemap_Local Function**
float3 Tonemap_Local(float3 color, float localLuminance, float adaptedLuminance, float intensity)
{
    float adaptationFactor = max(adaptedLuminance, 0.001);
    float3 adaptedColor = color / adaptationFactor;

    // Convert to Lab space
    float3 labColor = RGB2Lab(adaptedColor);

    // Automatic range adjustment
    float sceneAvgLuminance = adaptedLuminance;
    float dynamicRange = max(1.0, log2(1.0 / sceneAvgLuminance));
    float adjustmentRange = lerp(0.1, 2.0, saturate(dynamicRange / 10.0));

    // Local adaptation with curve
    float localAdaptation = pow(localLuminance / adaptationFactor, LocalAdjustmentCurve);
    localAdaptation = lerp(1.0, localAdaptation, LocalAdjustmentStrength * adjustmentRange);

    // Apply local adjustment to L channel
    labColor.x *= localAdaptation;

    // Apply zonal adjustments in LAB space
    float L = labColor.x / 100.0; // Normalize L to 0-1 range for easier calculations
    
    // Calculate zonal weights using L channel
    float shadowWeight = 1.0 - smootherstep(0.0, ShadowsEnd, L);
    float highlightWeight = smootherstep(HighlightsStart, 0.5, L);
    float midtoneWeight = exp(-pow(L - MidtonesCenter, 2) / (2 * MidtonesWidth * MidtonesWidth));

    // Normalize weights
    float totalWeight = shadowWeight + midtoneWeight + highlightWeight;
    shadowWeight /= totalWeight;
    midtoneWeight /= totalWeight;
    highlightWeight /= totalWeight;

    // Apply zonal adjustments to L channel
    float zonalFactor = shadowWeight * ShadowAdjustment + 
                       midtoneWeight * MidtoneAdjustment + 
                       highlightWeight * HighlightAdjustment;
    
    labColor.x *= zonalFactor;
    
    // Convert back to RGB for tonemapping
    float3 adjustedColor = Lab2RGB(labColor);

    // Soft clipping to prevent harsh clipping
    adjustedColor = 1.0 - exp(-adjustedColor);

    // Apply tonemapping based on user choice
    float3 toneMapped;
    if (TonemapperType == 0) {
        toneMapped = ACES_RRT(adjustedColor);
    } else {
        toneMapped = AgX_Tonemap(adjustedColor);
    }

    // Blend between original and tonemapped
    return lerp(adjustedColor, toneMapped, intensity);
}

// Apply Gamma Correction
float3 ApplyGamma(float3 color, float gamma) {
    return pow(max(color, 0.0001), 1.0 / gamma);
}

//#endregion

//#region Pixel Shaders

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
    return tex2Dlod(Small, float4(AdaptFocalPoint, 0, AdaptMipLevels - AdaptPrecision));
}

// Modified micro-contrast function with debug output
float4 ApplyMicroContrast(float3 color, float2 texcoord, out float4 debugOutput) {
    float3 labColor = RGB2Lab(color);
    float3 microDetail = 0.0;
    float detailMask = 0.0;
    float totalWeight = 0.0;
    
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
        
        // Separate weights for luminance and color channels
        float lumWeight = exp(-abs(detailVector.x) * (1.0 - DetailPreservation));
        float colorWeight = exp(-length(detailVector.yz) * (1.0 - DetailPreservation));
        
        // Noise detection in LAB space (more accurate)
        float lumNoise = smoothstep(NoiseThreshold * 5.0, NoiseThreshold * 20.0, abs(detailVector.x));
        float colorNoise = smoothstep(NoiseThreshold * 3.0, NoiseThreshold * 12.0, length(detailVector.yz));
        
        float3 weight = float3(lumWeight, colorWeight, colorWeight);
        float3 noiseMask = float3(lumNoise, colorNoise, colorNoise);
        
        weight *= noiseMask;
        
        microDetail += detailVector * weight;
        totalWeight += weight;
        
        // Debug information
        debugDetailVectors += abs(detailVector);
        debugNoiseMask += (lumNoise + colorNoise) * 0.5;
        debugDetailStrength += (length(detailVector.x) + length(detailVector.yz)) * 0.5;
    }
    
    microDetail /= max(totalWeight, 0.001);
    
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

    // Apply exposure adjustment
    float exposure = exp2(Exposure);
    color.rgb *= exposure;

    // Get local luminance (already implemented)
    float localLuminance = CalculateLocalLuminance(texcoord);
    
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
    
    // Final adjustments
    color.rgb *= Brightness;
    color.rgb = ApplyGamma(color.rgb, Gamma);
    color.rgb = lerp(originalColor.rgb, color.rgb, GlobalOpacity);

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