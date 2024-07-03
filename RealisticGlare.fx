#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#define ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE 256
#define ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS 9
static const int AdaptMipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;

// Samplers
sampler BackBuffer { Texture = ReShade::BackBufferTex; };

// Parameters
uniform float GlareThreshold <
    ui_type = "slider";
    ui_label = "Glare Threshold";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Brightness threshold for glare effect";
> = 0.8;

uniform float VeilingGlareIntensity <
    ui_type = "slider";
    ui_label = "Veiling Glare Intensity";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Intensity of the veiling glare effect";
> = 0.1;

uniform float VeilingGlareRadius <
    ui_type = "slider";
    ui_label = "Veiling Glare Radius";
    ui_min = 1.0; ui_max = 100.0;
    ui_tooltip = "Radius of the veiling glare effect";
> = 50.0;

uniform float SmoothingRadius <
    ui_type = "slider";
    ui_label = "Smoothing Radius";
    ui_min = 1.0; ui_max = 100.0;
    ui_tooltip = "Radius of the smoothing blur applied to the veiling glare";
> = 20.0;

uniform float SpectralFilterStrength <
    ui_type = "slider";
    ui_label = "Spectral Filter Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Strength of the spectral filter applied to the glare";
> = 0.5;

uniform float StarburstIntensity <
    ui_type = "slider";
    ui_label = "Starburst Intensity";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Intensity of the starburst effect";
> = 0.5;

uniform int StarburstPoints <
    ui_type = "slider";
    ui_label = "Starburst Points";
    ui_min = 4; ui_max = 16;
    ui_tooltip = "Number of points in the starburst pattern";
> = 8;

uniform float StarburstLength <
    ui_type = "slider";
    ui_label = "Starburst Length";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Length of the starburst rays";
> = 0.1;

uniform bool DebugBloom <
    ui_label = "Debug Bloom";
    ui_tooltip = "Show only the bloom effect without the original image";
> = false;

uniform float ChromaticAberrationStrength <
    ui_type = "slider";
    ui_label = "Chromatic Aberration Strength";
    ui_min = 0.0; ui_max = 10.0;
    ui_tooltip = "Strength of the chromatic aberration effect";
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

uniform float AdaptationTime <
    ui_type = "drag";
    ui_label = "Adaptation Time";
    ui_tooltip = "The time in seconds that adaptation takes to occur.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 3.0;
    ui_step = 0.01;
> = 1.0;

uniform float AdaptationSensitivity <
    ui_type = "drag";
    ui_label = "Adaptation Sensitivity";
    ui_tooltip = "Determines how sensitive adaptation is to bright lights.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 6.0;
    ui_step = 0.01;
> = 4.0;

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

uniform float Exposure <
    ui_type = "slider";
    ui_label = "Exposure";
    ui_category = "Final Changes";
    ui_min = -4.0; ui_max = 4.0;
    ui_tooltip = "Adjusts the overall exposure of the image";
> = 0.0;

uniform float AnisotropicAmount <
    ui_type = "slider";
    ui_label = "Anisotropic Amount";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the strength of horizontal glare. Higher values make the glare more horizontal.";
> = 0.5;

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

uniform float VignetteFalloff <
    ui_type = "slider";
    ui_label = "Vignette Falloff";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1;
    ui_tooltip = "Controls the falloff of the vignette effect";
> = 0.136;

uniform float VignetteColorShift <
    ui_type = "slider";
    ui_label = "Vignette Color Shift";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1.5;
    ui_tooltip = "Controls the subtle color shift of the vignette (simulates chromatic aberration at edges)";
> = 0.985;

uniform float VignetteOpacity <
    ui_type = "slider";
    ui_label = "Vignette Opacity";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the overall visibility of the vignette effect";
> = 1.0;

uniform bool DebugVignette <
    ui_label = "Debug Vignette";
    ui_category = "Vignette";
    ui_tooltip = "Show only the vignette effect";
> = false;

uniform float FrameTime < source = "frametime"; >;

// Textures
texture texBrightPass { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerBrightPass { Texture = texBrightPass; };

texture texVeilingGlare { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerVeilingGlare { Texture = texVeilingGlare; };

// Adaptation Textures
texture texAdaptation
{
    Width = ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE;
    Height = ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE;
    Format = R32F;
    MipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;
};
sampler samplerAdaptation { Texture = texAdaptation; };

texture texLastAdaptation { Format = R32F; };
sampler samplerLastAdaptation 
{ 
    Texture = texLastAdaptation;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
};

//// Shaders

// Vignette
float4 CalculateVignette(float2 texcoord, float3 color)
{
    float2 coord = (texcoord - 0.5) * 2.0;
    coord.x *= ReShade::AspectRatio;
    
    float dist = length(coord);
    
    // Base vignette
    float vignette = smoothstep(VignetteRadius, VignetteRadius - VignetteFalloff, dist);
    vignette = pow(vignette, 1.0 + VignetteStrength * 3.0);
    
    // Subtle color shift
    float3 vignetteColor;
    float colorShiftAmount = VignetteColorShift * 0.02;
    vignetteColor.r = smoothstep(VignetteRadius * (1.0 - colorShiftAmount), (VignetteRadius - VignetteFalloff) * (1.0 - colorShiftAmount), dist);
    vignetteColor.b = smoothstep(VignetteRadius * (1.0 + colorShiftAmount), (VignetteRadius - VignetteFalloff) * (1.0 + colorShiftAmount), dist);
    vignetteColor.g = vignette;
    
    // Blend the color shift more subtly
    float3 shiftedColor = lerp(color, color * vignetteColor, VignetteColorShift * 0.5);
    
    // Apply vignette darkening
    float3 vignetted = shiftedColor * lerp(1.0 - VignetteStrength, 1.0, vignette);
    
    // Apply opacity
    float3 finalColor = lerp(color, vignetted, VignetteOpacity);
    
    return float4(finalColor, vignette);
}

// Adaptation
float4 PS_CalculateAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, uv).rgb;
    float adapt = dot(color, float3(0.299, 0.587, 0.114));
    adapt *= AdaptationSensitivity;

    float last = tex2Dfetch(samplerLastAdaptation, int2(0, 0)).x;

    if (AdaptationTime > 0.0)
        adapt = lerp(last, adapt, saturate((FrameTime * 0.001) / AdaptationTime));

    return adapt;
}

float4 PS_SaveAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return tex2Dlod(samplerAdaptation, float4(AdaptFocalPoint, 0, AdaptMipLevels - AdaptPrecision));
}

// CA
float3 ApplyChromaticAberration(float2 texcoord)
{
    float2 direction = texcoord - 0.5;
    float distanceFromCenter = length(direction);
    
    float redOffset = ChromaticAberrationStrength * 0.01 * distanceFromCenter;
    float blueOffset = ChromaticAberrationStrength * -0.01 * distanceFromCenter;
    
    float3 distortedColor;
    distortedColor.r = tex2D(BackBuffer, texcoord + direction * redOffset).r;
    distortedColor.g = tex2D(BackBuffer, texcoord).g;
    distortedColor.b = tex2D(BackBuffer, texcoord + direction * blueOffset).b;
    
    return distortedColor;
}


// Anisotropic blur function
float3 AnisotropicBlur(sampler s, float2 texcoord, float radius)
{
    float3 color = 0.0;
    float total = 0.0;
    int samples = min(32, ceil(radius));

    for(int i = 0; i < samples; i++)
    {
        float angle = (i / float(samples)) * 3.14159 * 2.0;
        
        // Make the blur more horizontal
        float2 offset = float2(cos(angle), sin(angle) * (1.0 - AnisotropicAmount));
        
        offset *= radius * ReShade::PixelSize;
        
        float weight = 1.0 / samples;
        color += tex2D(s, texcoord + offset).rgb * weight;
        total += weight;
    }
    
    return color / total;
}

// Init Pass
float4 PS_InitialVeilingGlare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 veilingGlare = AnisotropicBlur(samplerBrightPass, texcoord, VeilingGlareRadius);
    return float4(veilingGlare, 1.0);
}

// Bright pass shader
float4 PS_BrightPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    float brightness = dot(color, float3(0.2126, 0.7152, 0.0722));
    float3 brightPass = smoothstep(GlareThreshold, GlareThreshold + 0.5, brightness) * color;
    return float4(brightPass, 1.0);
}


float3 ApplySpectralFilter(float3 color)
{
    float3 filterColor = float3(1.0, 0.8, 0.6);
    return lerp(color, color * filterColor, SpectralFilterStrength);
}

float3 ApplyStarburst(float3 color, float2 texcoord)
{
    float brightness = dot(color, float3(0.2126, 0.7152, 0.0722));
    float threshold = 0.8; // Adjust this threshold as needed
    
    if (brightness > threshold)
    {
        float2 center = texcoord;
        float starburst = 0.0;
        
        for (int i = 0; i < StarburstPoints; i++)
        {
            float angle = (2.0 * 3.14159 * i) / StarburstPoints;
            float2 direction = float2(cos(angle), sin(angle));
            
            for (float t = 0.0; t < StarburstLength; t += 0.01)
            {
                float2 samplePos = center + direction * t;
                float3 sampleColor = tex2D(BackBuffer, samplePos).rgb;
                float sampleBrightness = dot(sampleColor, float3(0.2126, 0.7152, 0.0722));
                starburst += max(0, sampleBrightness - threshold) * (1.0 - t / StarburstLength);
            }
        }
        
        starburst /= StarburstPoints;
        return color + starburst * StarburstIntensity;
    }
    
    return color;
}

// Main pass
float4 PS_Glare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = ApplyChromaticAberration(texcoord);
    
    // Get the current adaptation value
    float adapt = tex2Dfetch(samplerLastAdaptation, int2(0, 0)).x;
    adapt = clamp(adapt, AdaptRange.x, AdaptRange.y);
    
    // Calculate adaptive exposure
    float exposure = exp2(Exposure) / adapt;
    
    // Apply anisotropic veiling glare
    float3 veilingGlare = AnisotropicBlur(samplerVeilingGlare, texcoord, SmoothingRadius);
    veilingGlare = ApplySpectralFilter(veilingGlare);
    
    // Apply starburst effect
    float3 withStarburst = ApplyStarburst(color, texcoord);
    
    float3 finalGlare = max(veilingGlare, withStarburst - color);
    
    // Apply adaptive exposure to the glare
    finalGlare *= exposure;
    
    // Combine original color with glare
    float3 result = color + finalGlare * VeilingGlareIntensity;
    
    // Apply vignette
    float4 vignetteResult = CalculateVignette(texcoord, result);
    
    // Debug output
    if (DebugBloom)
    {
        return float4(finalGlare, 1.0);
    }
    else if (DebugVignette)
    {
        // Show only the vignette factor
        return float4(vignetteResult.aaa, 1.0);
    }
    
    // Always apply vignette in normal mode
    result = vignetteResult.rgb;
    
    return float4(result, 1.0);
}


technique RealisticGlare
{
    pass CalculateAdaptation
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_CalculateAdaptation;
        RenderTarget = texAdaptation;
    }
    pass SaveAdaptation
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SaveAdaptation;
        RenderTarget = texLastAdaptation;
    }
    pass BrightPass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BrightPass;
        RenderTarget = texBrightPass;
    }
    pass InitialVeilingGlare
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_InitialVeilingGlare;
        RenderTarget = texVeilingGlare;
    }
    pass FinalGlare
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Glare;
    }
}