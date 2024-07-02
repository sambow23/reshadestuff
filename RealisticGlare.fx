#include "ReShade.fxh"
#include "ReShadeUI.fxh"

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

// Textures
texture texBrightPass { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerBrightPass { Texture = texBrightPass; };

texture texVeilingGlare { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerVeilingGlare { Texture = texVeilingGlare; };

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


// Improved Gaussian blur function
float3 GaussianBlur(sampler s, float2 texcoord, float radius)
{
    float3 color = 0.0;
    float total = 0.0;
    int samples = min(32, ceil(radius));

    for(int i = 0; i < samples; i++)
    {
        float2 offset = float2(sin(i * 6.28318 / samples), cos(i * 6.28318 / samples)) * radius * ReShade::PixelSize;
        float weight = 1.0 / samples;
        color += tex2D(s, texcoord + offset).rgb * weight;
        total += weight;
    }
    
    return color / total;
}

// Init Pass
float4 PS_InitialVeilingGlare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 veilingGlare = GaussianBlur(samplerBrightPass, texcoord, VeilingGlareRadius);
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
    
    // Apply smoothing blur to the veiling glare
    float3 veilingGlare = GaussianBlur(samplerVeilingGlare, texcoord, SmoothingRadius);
    
    // Apply spectral filter to the glare
    veilingGlare = ApplySpectralFilter(veilingGlare);
    
    // Apply starburst effect
    float3 withStarburst = ApplyStarburst(color, texcoord);
    
    // Combine veiling glare and starburst
    float3 finalGlare = max(veilingGlare, withStarburst - color);
    
    // Debug output
    if (DebugBloom)
    {
        return float4(finalGlare, 1.0);
    }
    
    // Normal output
    float3 result = color + finalGlare * VeilingGlareIntensity;
    result = saturate(result); // Ensure we don't exceed 1.0
    
    return float4(result, 1.0);
}

technique RealisticGlare
{
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