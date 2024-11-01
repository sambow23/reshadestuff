/**
 * SimplifiedEye.fx
 *
 * This shader implements various eye-related visual effects including:
 * - 3-Stage Bloom
 * - Chromatic Aberration
 * - Vignette
 * - Adaptive Exposure
 *
 * It aims to simulate realistic eye behavior and camera lens effects in a simplified manner.
 */

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// Samplers
sampler BackBuffer { Texture = ReShade::BackBufferTex; };

//------------------------------------------------------------------------------
// UI Parameters
//------------------------------------------------------------------------------

// Bloom Parameters
uniform bool EnableBloom <
    ui_label = "Enable Bloom";
    ui_category = "Bloom";
    ui_tooltip = "Toggle to enable or disable the bloom effect";
> = true;

uniform float BloomThreshold <
    ui_type = "slider";
    ui_label = "Bloom Threshold";
    ui_category = "Bloom";
    ui_min = 0.0; ui_max = 2.0;
    ui_tooltip = "Threshold for the bloom effect";
> = 1.0;

// Stage 1 Bloom
uniform float BloomIntensity1 <
    ui_type = "slider";
    ui_label = "Bloom Intensity 1";
    ui_category = "Bloom";
    ui_min = 0.0; ui_max = 5.0;
    ui_tooltip = "Intensity of the first bloom stage (low-frequency details)";
> = 1.0;

uniform float BloomRadius1 <
    ui_type = "slider";
    ui_label = "Bloom Radius 1";
    ui_category = "Bloom";
    ui_min = 1.0; ui_max = 20.0;
    ui_tooltip = "Blur radius of the first bloom stage";
> = 10.0;

// Stage 2 Bloom
uniform float BloomIntensity2 <
    ui_type = "slider";
    ui_label = "Bloom Intensity 2";
    ui_category = "Bloom";
    ui_min = 0.0; ui_max = 5.0;
    ui_tooltip = "Intensity of the second bloom stage (medium-frequency details)";
> = 1.0;

uniform float BloomRadius2 <
    ui_type = "slider";
    ui_label = "Bloom Radius 2";
    ui_category = "Bloom";
    ui_min = 1.0; ui_max = 20.0;
    ui_tooltip = "Blur radius of the second bloom stage";
> = 5.0;

// Stage 3 Bloom
uniform float BloomIntensity3 <
    ui_type = "slider";
    ui_label = "Bloom Intensity 3";
    ui_category = "Bloom";
    ui_min = 0.0; ui_max = 5.0;
    ui_tooltip = "Intensity of the third bloom stage (high-frequency details)";
> = 1.0;

uniform float BloomRadius3 <
    ui_type = "slider";
    ui_label = "Bloom Radius 3";
    ui_category = "Bloom";
    ui_min = 1.0; ui_max = 20.0;
    ui_tooltip = "Blur radius of the third bloom stage";
> = 2.0;

// Chromatic Aberration Parameters
uniform float ChromaticAberrationStrength <
    ui_type = "slider";
    ui_label = "Chromatic Aberration";
    ui_category = "Chromatic Aberration";
    ui_min = 0.0; ui_max = 10.0;
    ui_tooltip = "Strength of the chromatic aberration effect";
> = 0.25;

// Vignette Parameters
uniform float VignetteStrength <
    ui_type = "slider";
    ui_label = "Vignette Strength";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1.5;
    ui_tooltip = "Controls the intensity of the vignette effect";
> = 0.6;

uniform float VignetteRadius <
    ui_type = "slider";
    ui_label = "Vignette Radius";
    ui_category = "Vignette";
    ui_min = 0.5; ui_max = 2.5;
    ui_tooltip = "Controls the size of the vignette effect (larger values cover more of the screen)";
> = 2.0;

uniform float VignetteSoftness <
    ui_type = "slider";
    ui_label = "Vignette Softness";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the softness of the vignette edges";
> = 0.5;

// Adaptive Exposure Parameters
uniform bool EnableAdaptiveExposure <
    ui_label = "Enable Adaptive Exposure";
    ui_category = "Adaptive Exposure";
    ui_tooltip = "Toggle to enable or disable the adaptive exposure effect";
> = true;

uniform float Exposure <
    ui_type = "slider";
    ui_label = "Manual Exposure";
    ui_category = "Adaptive Exposure";
    ui_min = -4.0; ui_max = 4.0;
    ui_tooltip = "Adjusts the overall exposure of the image";
> = 0.0;

uniform float AdaptationSpeed <
    ui_type = "slider";
    ui_label = "Adaptation Speed";
    ui_category = "Adaptive Exposure";
    ui_min = 0.0; ui_max = 5.0;
    ui_tooltip = "Speed at which the exposure adapts to changes in luminance";
> = 1.0;

uniform float MinExposure <
    ui_type = "slider";
    ui_label = "Minimum Exposure";
    ui_category = "Adaptive Exposure";
    ui_min = -4.0; ui_max = 0.0;
    ui_tooltip = "Minimum exposure limit for adaptive exposure";
> = -2.0;

uniform float MaxExposure <
    ui_type = "slider";
    ui_label = "Maximum Exposure";
    ui_category = "Adaptive Exposure";
    ui_min = 0.0; ui_max = 4.0;
    ui_tooltip = "Maximum exposure limit for adaptive exposure";
> = 2.0;

uniform float TargetLuminance <
    ui_type = "slider";
    ui_label = "Target Luminance";
    ui_category = "Adaptive Exposure";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Desired average luminance for the scene";
> = 0.5;

// Final Adjustment Parameters
uniform float GlobalOpacity <
    ui_type = "slider";
    ui_label = "Global Opacity";
    ui_category = "Final Adjustments";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the opacity of the shader effects";
> = 1.0;

//------------------------------------------------------------------------------
// Textures and Samplers
//------------------------------------------------------------------------------

// Use separate textures for each bloom stage to avoid feedback sampling errors
texture BloomTexture1 { Format = RGBA16F; };
sampler BloomSampler1 { Texture = BloomTexture1; };

texture BloomTexture1Intermediate { Format = RGBA16F; };
sampler BloomSampler1Intermediate { Texture = BloomTexture1Intermediate; };

texture BloomTexture2 { Format = RGBA16F; };
sampler BloomSampler2 { Texture = BloomTexture2; };

texture BloomTexture2Intermediate { Format = RGBA16F; };
sampler BloomSampler2Intermediate { Texture = BloomTexture2Intermediate; };

texture BloomTexture3 { Format = RGBA16F; };
sampler BloomSampler3 { Texture = BloomTexture3; };

texture AdaptLuminanceTex { Format = R16F; };
sampler AdaptLuminanceSampler { Texture = AdaptLuminanceTex; };

uniform float FrameTime < source = "frametime"; >;
uniform float Time < source = "time"; >;

//------------------------------------------------------------------------------
– Helper Functions
//------------------------------------------------------------------------------

// Extract bright areas for bloom
float3 ExtractBrightAreas(float3 color, float threshold)
{
    return max(color - threshold, 0.0);
}

// Apply Gaussian Blur
float4 GaussianBlur(sampler s, float2 texcoord, float radius)
{
    float4 color = 0.0;
    float totalWeight = 0.0;
    const int samples = 5;

    for (int x = -samples; x <= samples; x++)
    {
        for (int y = -samples; y <= samples; y++)
        {
            float2 offset = float2(x, y) * ReShade::PixelSize * radius;
            float weight = exp(-dot(offset, offset) / (2.0 * radius * radius));
            color += tex2D(s, texcoord + offset) * weight;
            totalWeight += weight;
        }
    }

    return color / totalWeight;
}

// Apply Vignette Effect
float3 ApplyVignette(float2 uv, float3 color)
{
    float2 coord = (uv - 0.5) * float2(ReShade::AspectRatio, 1.0);
    float dist = length(coord);
    float vignette = smoothstep(VignetteRadius, VignetteRadius - VignetteSoftness, dist);
    return color * lerp(1.0 - VignetteStrength, 1.0, vignette);
}

// Apply Chromatic Aberration
float3 ApplyChromaticAberration(float2 uv)
{
    float2 direction = uv - 0.5;
    float dist = length(direction);
    float2 offset = direction * ChromaticAberrationStrength * 0.001 * dist;

    float3 color;
    color.r = tex2D(BackBuffer, uv + offset).r;
    color.g = tex2D(BackBuffer, uv).g;
    color.b = tex2D(BackBuffer, uv - offset).b;

    return color;
}

// Calculate Luminance
float CalculateLuminance(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

//------------------------------------------------------------------------------
– Pixel Shaders
//------------------------------------------------------------------------------

// Bloom Extraction Pass
float4 PS_BloomExtract(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    float3 bloomColor = max(color - BloomThreshold, 0.0);
    return float4(bloomColor, 1.0);
}

// Bloom Blur Passes
float4 PS_BloomBlur1(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return GaussianBlur(BloomSampler1, texcoord, BloomRadius1);
}

float4 PS_BloomBlur2(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return GaussianBlur(BloomSampler2Intermediate, texcoord, BloomRadius2);
}

float4 PS_BloomBlur3(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return GaussianBlur(BloomSampler3, texcoord, BloomRadius3);
}

// Adaptation Pass
float4 PS_AdaptLuminance(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    float luminance = CalculateLuminance(color);
    return float4(luminance, luminance, luminance, 1.0);
}

// Final Pass
float4 PS_FinalPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 originalColor = tex2D(BackBuffer, texcoord).rgb;

    // Apply Adaptive Exposure
    float exposure = exp2(Exposure);
    if (EnableAdaptiveExposure)
    {
        float currentLuminance = tex2D(AdaptLuminanceSampler, float2(0.5, 0.5)).r;
        static float adaptedLuminance = 0.0;
        float delta = (currentLuminance - adaptedLuminance) * FrameTime * AdaptationSpeed;
        adaptedLuminance = clamp(adaptedLuminance + delta, MinExposure, MaxExposure);
        exposure = exp2(-adaptedLuminance);
    }

    float3 color = originalColor * exposure;

    // Apply Bloom
    if (EnableBloom)
    {
        float3 bloom1 = tex2D(BloomSampler1, texcoord).rgb * BloomIntensity1;
        float3 bloom2 = tex2D(BloomSampler2, texcoord).rgb * BloomIntensity2;
        float3 bloom3 = tex2D(BloomSampler3, texcoord).rgb * BloomIntensity3;

        color += bloom1 + bloom2 + bloom3;
    }

    // Apply Chromatic Aberration
    color = ApplyChromaticAberration(texcoord);

    // Apply Vignette
    color = ApplyVignette(texcoord, color);

    // Apply Global Opacity
    color = lerp(originalColor, color, GlobalOpacity);

    return float4(color, 1.0);
}

//------------------------------------------------------------------------------
– Techniques
//------------------------------------------------------------------------------

// Bloom Stages with Intermediate Textures to Avoid Feedback Sampling
technique SimplifiedEye
{
    pass BloomExtract
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomExtract;
        RenderTarget = BloomTexture1; // Write to BloomTexture1
    }

    pass BloomBlur1
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomBlur1;
        RenderTarget = BloomTexture1Intermediate; // Write to intermediate texture
    }

    pass BloomBlur2
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomBlur2;
        RenderTarget = BloomTexture2Intermediate; // Write to BloomTexture2Intermediate
    }

    pass BloomBlur3
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BloomBlur3;
        RenderTarget = BloomTexture3; // Final output in BloomTexture3
    }

    pass AdaptLuminance
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_AdaptLuminance;
        RenderTarget = AdaptLuminanceTex;
    }

    pass FinalPass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_FinalPass;
    }
}
