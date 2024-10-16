/**
 * Adaptive Local Tonemapper for ReShade
 * Author: CR
 * 
 * All shader code was written by ChatGPT o1-Preview and Claude 3.5 Sonnet
 * Adapation code from: luluco250's AdaptiveTonemapper.fx
 */

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

//------------------------------------------------------------------------------
// UI Elements
//------------------------------------------------------------------------------

// Final Adjustments
uniform float Brightness <
    ui_type = "slider";
    ui_label = "Final Brightness";
    ui_tooltip = "Adjusts the overall brightness of the final image.";
    ui_category = "Final Adjustments";
    ui_min = 0.5; ui_max = 5.0; ui_step = 0.01;
> = 1.0;

uniform float Gamma <
    ui_type = "slider";
    ui_label = "Final Gamma";
    ui_tooltip = "Adjusts the gamma curve of the final image.";
    ui_category = "Final Adjustments";
    ui_min = 0.1; ui_max = 2.2; ui_step = 0.01;
> = 1.0;

uniform float GlobalOpacity <
    ui_type = "slider";
    ui_label = "Final Opacity";
    ui_tooltip = "Controls the blend between the original and processed image.";
    ui_category = "Final Adjustments";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 1.0;

// Exposure
uniform float Exposure <
    ui_type = "slider";
    ui_label = "Exposure";
    ui_tooltip = "Adjusts the overall brightness before tonemapping.";
    ui_category = "Exposure";
    ui_min = -3.0; ui_max = 2.0; ui_step = 0.01;
> = 0.0;

// Tone Mapping
uniform float TonemappingIntensity <
    ui_type = "slider";
    ui_label = "Tone Mapping Strength";
    ui_tooltip = "Controls the intensity of the tone mapping effect.";
    ui_category = "Tone Mapping";
    ui_min = 0.1; ui_max = 1.5; ui_step = 0.01;
> = 0.8;

uniform int TonemapperType <
    ui_type = "combo";
    ui_label = "Tonemapper Type";
    ui_tooltip = "Select the tonemapping algorithm to use.";
    ui_category = "Tone Mapping";
    ui_items = "ACES\0AgX\0";
> = 0;

// AgX Parameters
uniform float AgX_ShoulderStrength <
    ui_type = "slider";
    ui_label = "AgX Shoulder Strength";
    ui_tooltip = "Controls how quickly highlights roll off.";
    ui_category = "AgX Parameters";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.22;

uniform float AgX_LinearStrength <
    ui_type = "slider";
    ui_label = "AgX Linear Strength";
    ui_tooltip = "Adjusts the midtone contrast.";
    ui_category = "AgX Parameters";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.3;

uniform float AgX_LinearAngle <
    ui_type = "slider";
    ui_label = "AgX Linear Angle";
    ui_tooltip = "Controls the angle of the linear section of the curve.";
    ui_category = "AgX Parameters";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.1;

uniform float AgX_ToeStrength <
    ui_type = "slider";
    ui_label = "AgX Toe Strength";
    ui_tooltip = "Affects the shadows and how quickly they fade to black.";
    ui_category = "AgX Parameters";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.2;

uniform float AgX_ToeNumerator <
    ui_type = "slider";
    ui_label = "AgX Toe Numerator";
    ui_tooltip = "Adjusts the toe numerator for the curve.";
    ui_category = "AgX Parameters";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.01;

uniform float AgX_ToeDenominator <
    ui_type = "slider";
    ui_label = "AgX Toe Denominator";
    ui_tooltip = "Adjusts the toe denominator for the curve.";
    ui_category = "AgX Parameters";
    ui_min = 0.1; ui_max = 1.0; ui_step = 0.01;
> = 0.3;

uniform float AgX_ExposureBias <
    ui_type = "slider";
    ui_label = "AgX Exposure Bias";
    ui_tooltip = "Balances the overall exposure level.";
    ui_category = "AgX Parameters";
    ui_min = 0.1; ui_max = 5.0; ui_step = 0.01;
> = 1.0;

// Local Adjustments
uniform float LocalAdjustmentStrength <
    ui_type = "slider";
    ui_label = "Local Adjustment Strength";
    ui_tooltip = "Controls the overall strength of local adjustments.";
    ui_category = "Local Adjustments";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.5;

uniform float LocalAdjustmentCurve <
    ui_type = "slider";
    ui_label = "Local Adjustment Curve";
    ui_tooltip = "Adjusts the balance between shadow and highlight processing.";
    ui_category = "Local Adjustments";
    ui_min = 0.1; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

// Color
uniform float LocalSaturationBoost <
    ui_type = "slider";
    ui_label = "Color Vibrance";
    ui_tooltip = "Boosts color saturation, especially in less saturated areas.";
    ui_category = "Color";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.1;

uniform float SkinToneProtection <
    ui_type = "slider";
    ui_label = "Skin Tone Protection";
    ui_tooltip = "Higher values protect skin tones from oversaturation.";
    ui_category = "Color";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.5;

uniform float VibranceCurve <
    ui_type = "slider";
    ui_label = "Vibrance Curve";
    ui_tooltip = "Adjusts the curve of the vibrance effect.";
    ui_category = "Color";
    ui_min = 0.5; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

// Zonal Adjustments
uniform float ShadowAdjustment <
    ui_type = "slider";
    ui_label = "Shadow Adjustment";
    ui_tooltip = "Adjusts the tonemapping intensity in shadow areas.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float MidtoneAdjustment <
    ui_type = "slider";
    ui_label = "Midtone Adjustment";
    ui_tooltip = "Adjusts the tonemapping intensity in midtone areas.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float HighlightAdjustment <
    ui_type = "slider";
    ui_label = "Highlight Adjustment";
    ui_tooltip = "Adjusts the tonemapping intensity in highlight areas.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.01;
> = 1.0;

uniform float MidtonesCenter <
    ui_type = "slider";
    ui_label = "Midtones Center";
    ui_tooltip = "Center point of the midtone range.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
> = 0.5;

uniform float MidtonesWidth <
    ui_type = "slider";
    ui_label = "Midtones Width";
    ui_tooltip = "Width of the midtone range.";
    ui_category = "Zonal Adjustments";
    ui_min = 0.1; ui_max = 0.8; ui_step = 0.01;
> = 0.4;

// Adaptation
uniform bool EnableAdaptation <
    ui_type = "checkbox";
    ui_label = "Enable Adaptation";
    ui_tooltip = "Toggle adaptive tonemapping on/off.";
    ui_category = "Adaptation";
> = true;

uniform float FixedLuminance <
    ui_type = "slider";
    ui_label = "Fixed Luminance";
    ui_tooltip = "The fixed luminance value to use when adaptation is disabled.";
    ui_category = "Adaptation";
    ui_min = 0.01; ui_max = 1.0; ui_step = 0.01;
> = 0.18;

uniform float2 AdaptRange <
    ui_type = "drag";
    ui_label = "Adaptation Range";
    ui_tooltip = "The minimum and maximum values that adaptation can use.";
    ui_category = "Adaptation";
    ui_min = 0.001; ui_max = 2.0; ui_step = 0.001;
> = float2(1.0, 2.0);

uniform float AdaptTime <
    ui_type = "drag";
    ui_label = "Adaptation Time";
    ui_tooltip = "The time in seconds that adaptation takes to occur.";
    ui_category = "Adaptation";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.01;
> = 1.0;

uniform float AdaptSensitivity <
    ui_type = "drag";
    ui_label = "Adaptation Sensitivity";
    ui_tooltip = "Determines how sensitive adaptation is to bright lights.";
    ui_category = "Adaptation";
    ui_min = 0.0; ui_max = 12.0; ui_step = 0.01;
> = 9.0;

uniform int AdaptPrecision <
    ui_type = "slider";
    ui_label = "Adaptation Precision";
    ui_tooltip = "The amount of precision used when determining the overall brightness.";
    ui_category = "Adaptation";
    ui_min = 0; ui_max = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;
> = 0;

uniform float2 AdaptFocalPoint <
    ui_type = "drag";
    ui_label = "Adaptation Focal Point";
    ui_tooltip = "Determines a point in the screen that adaptation will be centered around.";
    ui_category = "Adaptation";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.001;
> = 0.5;

uniform float FrameTime <source = "frametime";>;

//------------------------------------------------------------------------------
// Textures and Samplers
//------------------------------------------------------------------------------

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

//------------------------------------------------------------------------------
// Helper Functions
//------------------------------------------------------------------------------

// Smootherstep function for smoother transitions
float smootherstep(float edge0, float edge1, float x) {
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return x * x * x * (x * (x * 6 - 15) + 10);
}

// Convert RGB to Lab color space
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

// Convert Lab to RGB color space
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

// AgX Tonemapping function
float3 AgX_Tonemap(float3 color) {
    // Apply exposure bias
    color *= AgX_ExposureBias;

    // Parameters
    float shoulder_strength = AgX_ShoulderStrength;
    float linear_strength = AgX_LinearStrength;
    float linear_angle = AgX_LinearAngle;
    float toe_strength = AgX_ToeStrength;
    float toe_numerator = AgX_ToeNumerator;
    float toe_denominator = AgX_ToeDenominator;

    // AgX Tonemapping curve
    float3 x = max(color - toe_numerator, 0.0);
    float3 y = ((x * (linear_strength + x * shoulder_strength)) / (x + linear_strength * x + shoulder_strength)) + toe_numerator * x / (x + toe_denominator);

    return y;
}

// Apply selected tonemapper
float3 ApplyTonemapper(float3 color) {
    if (TonemapperType == 0) {
        // ACES Tonemapping
        return ACES_RRT(color);
    } else if (TonemapperType == 1) {
        // AgX Tonemapping
        return AgX_Tonemap(color);
    } else {
        // Default to ACES
        return ACES_RRT(color);
    }
}

// Local Tonemapping function
float3 Tonemap_Local(float3 color, float localLuminance, float adaptedLuminance, float intensity)
{
    // Local adaptation
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

    // Apply selected tonemapping function
    float3 toneMapped = ApplyTonemapper(adjustedColor);
    
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

//------------------------------------------------------------------------------
// Pixel Shaders
//------------------------------------------------------------------------------

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

// Main tonemapping pass
float4 MainPS(float4 pos : SV_POSITION, float2 texcoord : TEXCOORD) : SV_TARGET
{
    float4 originalColor = tex2D(BackBuffer, texcoord);
    float4 color = originalColor;  // Start with the original color
    float localLuminance = CalculateLocalLuminance(texcoord);
    
    float adaptedLuminance;
    if (EnableAdaptation)
    {
        adaptedLuminance = tex2Dfetch(LastAdapt, int2(0, 0), 0).x;
        adaptedLuminance = clamp(adaptedLuminance, AdaptRange.x, AdaptRange.y);
    }
    else
    {
        // Use the user-defined fixed luminance value when adaptation is disabled
        adaptedLuminance = FixedLuminance;
    }

    float exposure = exp2(Exposure);
    
    // Apply exposure adjustment
    color.rgb *= exposure;

    // Apply local tonemapping with selected tonemapper
    color.rgb = Tonemap_Local(color.rgb, localLuminance, adaptedLuminance, TonemappingIntensity);

    // Apply enhanced local saturation boost
    float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float saturation = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
    float adjustedSaturation = pow(saturation, VibranceCurve);

    // Skin tone detection (simple approximation)
    float skinTone = smoothstep(0.2, 0.6, color.r) * smoothstep(0.6, 0.2, color.g) * smoothstep(0.4, 0.2, color.b);
    float skinProtect = lerp(1.0, saturate(1.0 - skinTone), SkinToneProtection);

    // Calculate boost factor
    float boostFactor = 1.0 + LocalSaturationBoost * (1.0 - adjustedSaturation) * skinProtect;

    // Apply the boost with a soft limit
    float3 boostedColor = lerp(float3(luma, luma, luma), color.rgb, boostFactor);
    color.rgb = lerp(color.rgb, boostedColor, skinProtect);

    // Soft limit to prevent oversaturation
    color.rgb = lerp(color.rgb, float3(luma, luma, luma), saturate(saturation - 1.0));

    // Apply brightness adjustment
    color.rgb *= Brightness;

    // Apply gamma correction
    color.rgb = ApplyGamma(color.rgb, Gamma);

    // Blend between original and processed color based on GlobalOpacity
    color.rgb = lerp(originalColor.rgb, color.rgb, GlobalOpacity);

    return saturate(color);
}

//------------------------------------------------------------------------------
// Technique
//------------------------------------------------------------------------------

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
