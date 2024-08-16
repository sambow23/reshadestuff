#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#define ADAPTIVE_TONEMAPPER_SMALL_TEX_SIZE 256
#define ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS 9
#define GLARE_SATURATION 0.5
static const int AdaptMipLevels = ADAPTIVE_TONEMAPPER_SMALL_TEX_MIPLEVELS;

// Samplers
sampler BackBuffer { Texture = ReShade::BackBufferTex; };

// Parameters

uniform float GlareFalloff <
    ui_type = "slider";
    ui_label = "Glare Falloff";
    ui_min = 0.1; ui_max = 5.0;
    ui_tooltip = "Controls the smoothness of the glare falloff";
> = 1.0;

uniform float VeilingGlareIntensity <
    ui_type = "slider";
    ui_label = "Veiling Glare Intensity";
    ui_min = 0.0; ui_max = 10.0;
    ui_step = 1.0;
    ui_tooltip = "Intensity of the veiling glare effect";
> = 1.0;

uniform float BaseGlareThreshold <
    ui_type = "slider";
    ui_label = "Base Glare Threshold";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Base threshold for glare effect before scene adaptation";
> = 0.5;

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
    ui_max = 2.0;
    ui_step = 0.001;
> = float2(0.0, 2.0);

uniform float AdaptationInfluence <
    ui_type = "slider";
    ui_label = "Adaptation Strength";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 100.0; // Increased from 15.0
    ui_step = 1.0;
    ui_tooltip = "Higher values make the glare more sensitive to scene adaptation";
> = 20.0; // 

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
    ui_type = "slider";
    ui_label = "Adaptation Sensitivity";
    ui_tooltip = "Determines how sensitive adaptation is to bright lights.";
    ui_category = "Adaptation";
    ui_min = 0.0;
    ui_max = 50.0; // Increased from 15.0
    ui_step = 0.1;
> = 5.0; // 

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

uniform bool DebugRawAdaptation <
    ui_label = "Debug Raw Adaptation";
    ui_category = "Debug";
    ui_tooltip = "Show the raw adaptation value before processing";
> = false;

uniform float FrameTime < source = "frametime"; >;

// Textures
texture texBrightPass { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerBrightPass { Texture = texBrightPass; };

texture texVeilingGlare { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerVeilingGlare { Texture = texVeilingGlare; };

texture texIntermediateBlur { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerIntermediateBlur { Texture = texIntermediateBlur; };

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

texture texIntermediateAdaptation { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = R32F; };
sampler samplerIntermediateAdaptation { Texture = texIntermediateAdaptation; };

//// Shaders

float3 AdjustSaturation(float3 color, float saturationFactor)
{
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return lerp(float3(luma, luma, luma), color, saturationFactor);
}

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
float4 PS_CalculateLocalAdaptation(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 texelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float4 brightPassData = tex2D(samplerBrightPass, texcoord);
    float packedData = brightPassData.a;
    float avgLuminance = floor(packedData) / 1000;
    float localContrast = frac(packedData);

    float adapt = 0;
    float totalWeight = 0;

    for (int y = -4; y <= 4; y++)
    {
        for (int x = -4; x <= 4; x++)
        {
            float2 offset = float2(x, y) * texelSize * 8;
            float weight = exp(-(x*x + y*y) / 16.0);  // Gaussian-like weight
            float4 neighborData = tex2D(samplerBrightPass, texcoord + offset);
            float neighborLuminance = floor(neighborData.a) / 1000;
            adapt += neighborLuminance * weight;
            totalWeight += weight;
        }
    }
    adapt /= max(totalWeight, 0.001);

    float compressedLuminance = 1.0 - exp(-adapt * AdaptationSensitivity);
    adapt = clamp(compressedLuminance, 0.0001, 0.9999);

    float last = tex2D(samplerLocalAdaptation, texcoord).x;
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
float4 AnisotropicBlur(sampler s, float2 texcoord, float veilingGlareRadius, float smoothingRadius)
{
    float4 color = 0.0;
    float total = 0.0;
    float combinedRadius = veilingGlareRadius + smoothingRadius;
    int samples = min(128, ceil(combinedRadius * 2)); // Increased from 64 to 128

    for(int i = 0; i < samples; i++)
    {
        float angle = (i / float(samples)) * 3.14159 * 2.0;
        float2 offset = float2(cos(angle), sin(angle) * (1.0 - AnisotropicAmount));
        offset *= combinedRadius * ReShade::PixelSize;
        
        float distance = length(offset);
        float weight = exp(-distance * distance / (2.0 * smoothingRadius * smoothingRadius));
        
        // Use bilinear sampling for smoother results
        float4 sampleColor = tex2Dlod(s, float4(texcoord + offset, 0, 0));
        color += sampleColor * weight;
        total += weight;
    }
    
    return color / max(total, 0.0001);
}

float4 PS_IntermediateBlur(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return AnisotropicBlur(samplerBrightPass, texcoord, VeilingGlareRadius * 0.5, SmoothingRadius * 0.5);
}

float3 ApplySpectralFilter(float3 color)
{
    float3 filterColor = float3(1.0, 0.8, 0.6);
    return lerp(color, color * filterColor, SpectralFilterStrength);
}


float CalculateDynamicThreshold(float2 texcoord)
{
    float sceneLuminance = tex2D(samplerAdaptation, float2(0.5, 0.5)).r;
    float dynamicThreshold = BaseGlareThreshold * (1.0 + sceneLuminance);
    return dynamicThreshold;
}

// Init Pass
float4 PS_InitialVeilingGlare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Get the local adaptation value
    float localAdapt = tex2D(samplerLocalAdaptation, texcoord).x;
    
    // Adjust glare threshold based on local adaptation
    float dynamicThreshold = CalculateDynamicThreshold(texcoord);
    
    // Apply anisotropic blur
    float4 veilingGlare = AnisotropicBlur(samplerIntermediateBlur, texcoord, VeilingGlareRadius * 0.5, SmoothingRadius * 0.5);
    
    // Apply dynamic threshold
    veilingGlare.rgb = max(veilingGlare.rgb - dynamicThreshold, 0.0);
    
    // Adjust glare intensity based on adaptation
    dynamicThreshold *= lerp(1.0, 3.0, saturate(localAdapt));
    
    // Apply spectral filter
    veilingGlare.rgb = ApplySpectralFilter(veilingGlare.rgb);
    
    // Store luminance in alpha channel for later use
    veilingGlare.a = dot(veilingGlare.rgb, float3(0.299, 0.587, 0.114));
    
    return veilingGlare;
}

// Bright pass shader
float4 PS_BrightPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    
    float dynamicThreshold = CalculateDynamicThreshold(texcoord);
    float softness = dynamicThreshold * 0.5;
    
    float3 brightPass = max(0, color - dynamicThreshold);
    float brightLuminance = max(dot(brightPass, float3(0.2126, 0.7152, 0.0722)), 0.001);
    brightPass *= luminance / brightLuminance;
    
    float knee = smoothstep(dynamicThreshold, dynamicThreshold + softness, luminance);
    brightPass *= knee;
    
    // Calculate average scene luminance
    float avgLuminance = 0;
    float2 texelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    for (int y = -2; y <= 2; y++)
    {
        for (int x = -2; x <= 2; x++)
        {
            float2 offset = float2(x, y) * texelSize * 4; // Sample a wider area
            avgLuminance += dot(tex2D(BackBuffer, texcoord + offset).rgb, float3(0.2126, 0.7152, 0.0722));
        }
    }
    avgLuminance /= 25.0; // 5x5 samples
    
    // Calculate local contrast
    float localContrast = 0;
    float mean = luminance;
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 offset = float2(x, y) * texelSize;
            float sampleLum = dot(tex2D(BackBuffer, texcoord + offset).rgb, float3(0.2126, 0.7152, 0.0722));
            localContrast += (sampleLum - mean) * (sampleLum - mean);
        }
    }
    localContrast = sqrt(localContrast / 9.0); // Standard deviation as a measure of contrast
    
    // Pack avgLuminance and localContrast into a single float
    float packedData = (avgLuminance * 1000) + localContrast; // Assuming avgLuminance < 1

    return float4(brightPass, packedData);
}

float3 GaussianBlur(sampler s, float2 texcoord, float2 direction)
{
    float3 color = 0.0;
    float offsets[3] = { 0.0, 1.3846153846, 3.2307692308 };
    float weights[3] = { 0.2270270270, 0.3162162162, 0.0702702703 };
    
    color += tex2D(s, texcoord).rgb * weights[0];
    
    for (int i = 1; i < 3; i++)
    {
        color += tex2D(s, texcoord + direction * offsets[i]).rgb * weights[i];
        color += tex2D(s, texcoord - direction * offsets[i]).rgb * weights[i];
    }
    
    return color;
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
            adapt += tex2D(samplerIntermediateAdaptation, texcoord + offset).x;
        }
    }
    adapt /= 25.0;

    return adapt;
}

float4 PS_Glare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 originalColor = tex2D(BackBuffer, texcoord).rgb;
    float3 color = ApplyChromaticAberration(texcoord);
    
    // Get the local adaptation value
    float localAdapt = tex2D(samplerLocalAdaptation, texcoord).x;
    localAdapt = clamp(localAdapt, AdaptRange.x, AdaptRange.y);
    
    // Calculate adaptive exposure for glare only
    float adaptationStrength = AdaptationInfluence; // Increase this value to make adaptation more influential
    float adaptiveExposure = 0.5 / max(localAdapt, 0.001);
    float manualExposure = exp2(Exposure);
    float glareExposure = manualExposure * adaptiveExposure * (adaptationStrength / 16);
    
    // Apply anisotropic veiling glare
    float4 veilingGlare = tex2D(samplerVeilingGlare, texcoord);
    
    // Adjust saturation of the glare
    veilingGlare.rgb = AdjustSaturation(veilingGlare.rgb, GLARE_SATURATION);
    
    // Calculate glare intensity
    float glareIntensity = pow(veilingGlare.a, GlareFalloff) * pow(1.0 - saturate(localAdapt), 1.5);
    
    // Add glare to the original color
    float3 result = color + veilingGlare.rgb * VeilingGlareIntensity * glareIntensity;
    
    // Debug output
    if (DebugBloom)
    {
        return float4(veilingGlare.rgb, 1.0);
    }
    else if (DebugVignette)
    {
        float4 vignetteResult = CalculateVignette(texcoord, result);
        return float4(vignetteResult.aaa, 1.0);
    }
    if (DebugExposedGlare)
    {
        return float4(veilingGlare.rgb * glareExposure * VeilingGlareIntensity, 1.0);
    }
    if (DebugAdaptation)
    {
        return float4(localAdapt.xxx, 1.0);
    }
    if (DebugRawAdaptation)
    {
        return float4(localAdapt.xxx, 1.0);
    }
    else if (DebugAdaptation)
    {
        float adaptationEffect = 1.0 / (1.0 + localAdapt * AdaptationSensitivity);
        return float4(adaptationEffect.xxx, 1.0);
    }
    
    // Apply vignette
    float4 vignetteResult = CalculateVignette(texcoord, result);
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
        RenderTarget = texIntermediateAdaptation;
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
    pass IntermediateBlur
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_IntermediateBlur;
        RenderTarget = texIntermediateBlur;
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