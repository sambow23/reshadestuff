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
    ui_min = 0.0; ui_max = 5.0;
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

uniform float ChromaticAberrationStrength <
    ui_type = "slider";
    ui_label = "Chromatic Aberration Strength";
    ui_min = 0.0; ui_max = 10.0;
    ui_tooltip = "Strength of the chromatic aberration effect";
> = 0.25;

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
> = 0.4;

uniform float AdaptationSensitivity <
    ui_type = "drag";
    ui_label = "Adaptation Sensitivity";
    ui_tooltip = "Determines how sensitive adaptation is to bright lights.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 15.0;
    ui_step = 0.01;
> = 10.0;

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

uniform float VignetteDistortionStrength <
    ui_type = "slider";
    ui_label = "Vignette Distortion Strength";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the strength of the lens distortion in the vignette area";
> = 0.1;

uniform float VignetteOpacity <
    ui_type = "slider";
    ui_label = "Vignette Opacity";
    ui_category = "Vignette";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the overall visibility of the vignette effect";
> = 1.0;

uniform float GlobalOpacity <
    ui_type = "slider";
    ui_label = "Global Opacity";
    ui_category = "Final Changes";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Controls the opacity of the shader";
> = 1.0;

uniform bool DebugExposedGlare <
    ui_label = "Debug Exposed Glare";
    ui_category = "Debug";
    ui_tooltip = "Show only the exposed glare effect";
> = false;

uniform bool DebugVignette <
    ui_label = "Debug Vignette";
    ui_category = "Debug";
    ui_category = "Vignette";
    ui_tooltip = "Show only the vignette effect";
> = false;

uniform bool DebugBloom <
    ui_label = "Debug VLGlare";
    ui_category = "Debug";
    ui_tooltip = "Show only the bloom effect without the original image";
> = false;

uniform bool DebugAdaptation <
    ui_label = "Debug Adaptation";
    ui_category = "Debug";
    ui_tooltip = "Show the current adaptation value";
> = false;

uniform float FrameTime < source = "frametime"; >;

// Textures
texture texBrightPass { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA32F; };
sampler samplerBrightPass { Texture = texBrightPass; };

texture texVeilingGlare { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA32F; };
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

// Local Adaptation
texture texLocalAdaptation
{
    Width = BUFFER_WIDTH / 1;
    Height = BUFFER_HEIGHT / 1;
    Format = R32F;
    MipLevels = 1;
};
sampler samplerLocalAdaptation { Texture = texLocalAdaptation; };

//// Shaders


// Lens Distortion
float2 DistortUV(float2 uv, float distortionStrength)
{
    float2 center = float2(0.5, 0.5);
    float2 delta = uv - center;
    float radius = length(delta);
    float distortion = 1.0 + distortionStrength * pow(radius, 2.0);
    
    return center + delta * distortion;
}

// Vignette
float4 CalculateVignette(float2 texcoord, float3 color)
{
    float2 coord = (texcoord - 0.5) * 2.0;
    coord.x *= ReShade::AspectRatio;
    
    float dist = length(coord);
    
    // Base vignette
    float vignette = smoothstep(VignetteRadius, VignetteRadius - VignetteFalloff, dist);
    vignette = pow(vignette, 1.0 + VignetteStrength * 3.0);
    
    // Apply distortion
    float2 distortedUV = DistortUV(texcoord, (1.0 - vignette) * VignetteDistortionStrength);
    float3 distortedColor = tex2D(BackBuffer, distortedUV).rgb;
    
    // Subtle color shift
    float3 vignetteColor;
    float colorShiftAmount = VignetteColorShift * 0.02;
    vignetteColor.r = smoothstep(VignetteRadius * (1.0 - colorShiftAmount), (VignetteRadius - VignetteFalloff) * (1.0 - colorShiftAmount), dist);
    vignetteColor.b = smoothstep(VignetteRadius * (1.0 + colorShiftAmount), (VignetteRadius - VignetteFalloff) * (1.0 + colorShiftAmount), dist);
    vignetteColor.g = vignette;
    
    // Blend the color shift more subtly
    float3 shiftedColor = lerp(distortedColor, distortedColor * vignetteColor, VignetteColorShift * 0.5);
    
    // Apply vignette darkening
    float3 vignetted = shiftedColor * lerp(1.0 - VignetteStrength, 1.0, vignette);
    
    // Blend between original and distorted color based on vignette strength
    float3 finalColor = lerp(color, vignetted, VignetteOpacity);
    
    return float4(finalColor, vignette);
}

// Adaptation
float4 PS_CalculateLocalAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 color = 0;
    float2 texelSize = 1.0 / float2(BUFFER_WIDTH / 8, BUFFER_HEIGHT / 8);
    float totalWeight = 0;

    for (int y = -4; y <= 4; y++)
    {
        for (int x = -4; x <= 4; x++)
        {
            float2 offset = float2(x, y) * texelSize * 8;
            float weight = exp(-(x*x + y*y) / 16.0);  // Gaussian-like weight
            color += tex2D(BackBuffer, uv + offset).rgb * weight;
            totalWeight += weight;
        }
    }
    color /= totalWeight;

    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    float compressedLuminance = 1.0 - exp(-luminance * AdaptationSensitivity);
    float adapt = clamp(compressedLuminance, 0.0001, 0.9999);

    float last = tex2D(samplerLocalAdaptation, uv).x;
    float adaptationRate = saturate((FrameTime * 0.001) / max(AdaptationTime, 0.001));
    adapt = lerp(last, adapt, adaptationRate);

    return adapt;
}

float4 PS_SaveAdaptation(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float adapt = tex2Dlod(samplerAdaptation, float4(AdaptFocalPoint, 0, AdaptMipLevels - AdaptPrecision)).r;
    return adapt;
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
float3 AnisotropicBlur(sampler s, float2 texcoord, float veilingGlareRadius, float smoothingRadius)
{
    float3 color = 0.0;
    float total = 0.0;
    float combinedRadius = veilingGlareRadius + smoothingRadius;
    int samples = min(64, ceil(combinedRadius));  // Increased max samples for better quality

    for(int i = 0; i < samples; i++)
    {
        float angle = (i / float(samples)) * 3.14159 * 2.0;
        
        // Make the blur more horizontal
        float2 offset = float2(cos(angle), sin(angle) * (1.0 - AnisotropicAmount));
        
        // Use the combined radius
        offset *= combinedRadius * ReShade::PixelSize;
        
        // Use a Gaussian-like weight based on distance
        float distance = length(offset);
        float weight = exp(-distance * distance / (2.0 * smoothingRadius * smoothingRadius));
        
        color += tex2D(s, texcoord + offset).rgb * weight;
        total += weight;
    }
    
    return color / max(total, 0.0001);
}

// Init Pass
float4 PS_InitialVeilingGlare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 veilingGlare = AnisotropicBlur(samplerBrightPass, texcoord, VeilingGlareRadius, SmoothingRadius);
    
    // Apply HDR effect to the glare
    veilingGlare = max(veilingGlare - GlareThreshold * 0.25, 0.0);
    veilingGlare = pow(veilingGlare, 1.5); // Reduced contrast enhancement
    
    return float4(veilingGlare, 1.0);
}

// Bright pass shader
float4 PS_BrightPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    
    float threshold = GlareThreshold * 0.25; // Lower threshold
    float softness = 0.5;
    
    // Preserve color ratios
    float3 brightPass = max(0, color - threshold);
    float brightLuminance = max(dot(brightPass, float3(0.2126, 0.7152, 0.0722)), 0.001);
    brightPass *= luminance / brightLuminance;
    
    // Apply a soft knee curve
    float knee = smoothstep(threshold, threshold + softness, luminance);
    brightPass *= knee;
    
    return float4(brightPass * 8.0, 1.0); // Reduced multiplier
}


float3 ApplySpectralFilter(float3 color)
{
    float3 filterColor = float3(1.0, 0.8, 0.6);
    return lerp(color, color * filterColor, SpectralFilterStrength);
}

float4 PS_BlurLocalAdaptation(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float adapt = 0;
    float2 texelSize = 1.0 / float2(BUFFER_WIDTH / 8, BUFFER_HEIGHT / 8);

    for (int y = -2; y <= 2; y++)
    {
        for (int x = -2; x <= 2; x++)
        {
            float2 offset = float2(x, y) * texelSize;
            adapt += tex2D(samplerLocalAdaptation, texcoord + offset).x;
        }
    }
    adapt /= 25.0;

    return adapt;
}

float3 SimpleToneMap(float3 color)
{
    // Simple Reinhard tone mapping
    return color / (1.0 + color);
}

// Main pass
float4 PS_Glare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 originalColor = tex2D(BackBuffer, texcoord).rgb;
    float3 color = ApplyChromaticAberration(texcoord);
    
    // Get the local adaptation value
    float localAdapt = 0;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 offset = float2(x, y) * ReShade::PixelSize;
            localAdapt += tex2D(samplerLocalAdaptation, texcoord + offset).x;
        }
    }
    localAdapt /= 9.0;
    localAdapt = clamp(localAdapt, AdaptRange.x, AdaptRange.y);
    
    // Calculate adaptive exposure for glare only
    float adaptiveExposure = 1.0 / max(localAdapt, 0.0001);
    float manualExposure = exp2(Exposure);
    float finalExposure = manualExposure * adaptiveExposure;
    
    // Calculate glare threshold based on local adaptation
    float dynamicGlareThreshold = lerp(GlareThreshold, GlareThreshold * 3.0, saturate(localAdapt));
    
    // Apply anisotropic veiling glare with dynamic threshold
    float3 veilingGlare = AnisotropicBlur(samplerVeilingGlare, texcoord, VeilingGlareRadius, SmoothingRadius);
    veilingGlare = ApplySpectralFilter(veilingGlare);
    
    // Apply exposure to the glare
    veilingGlare *= finalExposure;
    
    // Tone map the glare
    veilingGlare = SimpleToneMap(veilingGlare);
    
    // Combine original color with exposed glare
    float3 result = color + veilingGlare * VeilingGlareIntensity;
    
    // Apply vignette
    float4 vignetteResult = CalculateVignette(texcoord, result);
    result = vignetteResult.rgb;
    
    // Debug output
    if (DebugBloom)
    {
        return float4(veilingGlare, 1.0);
    }
    else if (DebugVignette)
    {
        // Show only the vignette factor
        return float4(vignetteResult.aaa, 1.0);
    }
    if (DebugExposedGlare)
    {
        return float4(veilingGlare * finalExposure * VeilingGlareIntensity, 1.0);
    }
    if (DebugAdaptation)
    {
        float adapt = tex2Dfetch(samplerLastAdaptation, int2(0, 0)).x;
        return float4(adapt.xxx, 1.0);
    }
    
    // Apply vignette in normal mode
    result = vignetteResult.rgb;
    
    // Apply global opacity
    result = lerp(originalColor, result, GlobalOpacity);
    
    return float4(result, 1.0);
}


technique EyeSight
{
    pass CalculateLocalAdaptation
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_CalculateLocalAdaptation;
        RenderTarget = texLocalAdaptation;
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
    pass BlurLocalAdaptation
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BlurLocalAdaptation;
        RenderTarget = texLocalAdaptation;
    }
}