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

uniform bool DebugBloom <
    ui_label = "Debug Bloom";
    ui_tooltip = "Show only the bloom effect without the original image";
> = false;

// Textures
texture texBrightPass { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler samplerBrightPass { Texture = texBrightPass; };

// Bright pass shader
float4 PS_BrightPass(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    float brightness = dot(color, float3(0.2126, 0.7152, 0.0722));
    float3 brightPass = smoothstep(GlareThreshold, GlareThreshold + 0.5, brightness) * color;
    return float4(brightPass, 1.0);
}

// Improved Gaussian blur function
float3 GaussianBlur(sampler s, float2 texcoord, float radius)
{
    float3 color = 0.0;
    float total = 0.0;
    int samples = min(32, ceil(radius)); // Limit samples for performance

    for(int i = 0; i < samples; i++)
    {
        float2 offset = float2(sin(i * 6.28318 / samples), cos(i * 6.28318 / samples)) * radius * ReShade::PixelSize;
        float weight = 1.0 / samples;
        color += tex2D(s, texcoord + offset).rgb * weight;
        total += weight;
    }
    
    return color / total;
}

// Main pass
float4 PS_Glare(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, texcoord).rgb;
    
    // Apply veiling glare
    float3 veilingGlare = GaussianBlur(samplerBrightPass, texcoord, VeilingGlareRadius);
    
    // Debug output
    if (DebugBloom)
    {
        return float4(veilingGlare * VeilingGlareIntensity, 1.0);
    }
    
    // Normal output
    float3 result = color + veilingGlare * VeilingGlareIntensity;
    
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

    pass VeilingGlare
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Glare;
    }
}