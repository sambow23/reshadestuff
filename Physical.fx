#include "ReShade.fxh"
#include "ReShadeUI.fxh"

//////////////////////////////////////////////////
// Global Parameters
//////////////////////////////////////////////////

uniform float GlobalIntensity <
    ui_type = "slider";
    ui_label = "Global Effect Intensity";
    ui_tooltip = "Master intensity control for all effects";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 1.0;

uniform float ChromaticIntensity <
    ui_type = "slider";
    ui_label = "Chromatic Aberration Intensity";
    ui_tooltip = "Intensity control for chromatic aberration";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.01;
> = 0.5;


//////////////////////////////////////////////////
// Chroma Parameters
//////////////////////////////////////////////////

uniform float ChromaAmount <
    ui_type = "slider";
    ui_label = "Aberration Amount";
    ui_category = "CA";
    ui_tooltip = "Controls the strength of the chromatic aberration (in mm from optical axis)";
    ui_min = 0.0;
    ui_max = 10.0;
    ui_step = 0.01;
> = 1.0;

uniform float FocalLength <
    ui_type = "slider";
    ui_label = "Focal Length";
    ui_category = "CA";
    ui_tooltip = "Lens focal length in mm";
    ui_min = 10.0;
    ui_max = 200.0;
    ui_step = 1.0;
> = 50.0;

uniform bool UseRealGlass <
    ui_label = "Use Real Glass Properties";
    ui_category = "CA";
    ui_tooltip = "Enable to use real glass dispersion properties (BK7/Flint combination)";
> = true;

// Common functions
// These utilities provide physically-based calculations and transformations
// for implementing realistic lens effects in screen space.

//////////////////////////////////////////////////
// Coordinate Transformations
//////////////////////////////////////////////////

// Convert screen coordinates (0 to 1 range) to centered coordinates (-1 to 1 range)
// with aspect ratio correction for circular uniformity
float2 GetCenteredCoord(float2 texcoord)
{
    float2 centered = (texcoord - 0.5) * 2.0;
    // Correct for aspect ratio to maintain circular symmetry
    centered.x *= BUFFER_WIDTH * (1.0 / BUFFER_HEIGHT);
    return centered;
}

// Convert centered coordinates back to texture coordinates
// Inverse of GetCenteredCoord
float2 GetTexCoord(float2 centered)
{
    // Reverse aspect ratio correction
    centered.x *= BUFFER_HEIGHT * (1.0 / BUFFER_WIDTH);
    return centered * 0.5 + 0.5;
}

// Get normalized radius from center (0 at center, 1 at screen corner)
float GetRadius(float2 centered)
{
    return length(centered);
}

// Get angle from center in radians (-PI to PI)
float GetAngle(float2 centered)
{
    return atan2(centered.y, centered.x);
}

// Convert polar coordinates back to Cartesian
float2 PolarToCartesian(float radius, float angle)
{
    return float2(radius * cos(angle), radius * sin(angle));
}

//////////////////////////////////////////////////
// Color and Wavelength Handling
//////////////////////////////////////////////////

// More accurate wavelength to RGB conversion based on CIE curves
// Input wavelength should be in nanometers (380-750nm)
float3 WavelengthToRGB(float wavelength)
{
    float3 rgb;
    
    // Normalized wavelength between 0 and 1
    float x = (wavelength - 380.0) / (750.0 - 380.0);
    
    // More accurate conversion based on spectral distribution
    // These curves approximate CIE color matching functions
    rgb.r = smoothstep(0.0, 0.22, x) * smoothstep(1.0, 0.57, x);
    rgb.g = smoothstep(0.2, 0.35, x) * smoothstep(0.75, 0.45, x);
    rgb.b = smoothstep(0.0, 0.17, x) * smoothstep(0.4, 0.15, x);
    
    // Normalize and adjust for perceived brightness
    float luma = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    rgb = lerp(rgb, rgb/max(luma, 0.01), 0.8);
    
    return rgb;
}

// Sellmeier dispersion equation for calculating wavelength-dependent IOR
// B and C are the Sellmeier coefficients specific to the glass type
// Common coefficients:
// BK7:  B = (1.03961212, 0.231792344, 1.01046945)
//       C = (0.00600069867, 0.0200179144, 103.560653)
float GetIOR(float wavelength, float3 B, float3 C)
{
    float w2 = wavelength * wavelength * 1e-6; // Convert nm² to μm²
    float n2 = 1.0 + 
        (B.x * w2) / (w2 - C.x) +
        (B.y * w2) / (w2 - C.y) +
        (B.z * w2) / (w2 - C.z);
    return sqrt(n2);
}

//////////////////////////////////////////////////
// Advanced Sampling
//////////////////////////////////////////////////

// Cubic interpolation weight calculation
float4 GetCubicWeight(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    
    // Cubic coefficients for Catmull-Rom spline
    float4 w;
    w.x = -x + 2.0 * x2 - x3;        // -1/6(x-1)(x-2)(x)
    w.y = 2.0 - 5.0 * x2 + 3.0 * x3; // 1/2(x-2)(x+1)(x)
    w.z = x + 4.0 * x2 - 3.0 * x3;   // -1/2(x-1)(x+1)(x)
    w.w = -x2 + x3;                   // 1/6(x)(x-1)(x-2)
    
    return w / 6.0;
}

// High quality bicubic sampling
// This provides much better quality than bilinear for distortion effects
float4 SampleBicubic(sampler2D tex, float2 coord)
{
    float2 texSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 texelSize = 1.0 / texSize;
    
    // Calculate sample positions
    float2 pc = coord * texSize - 0.5;
    float2 f = frac(pc);
    float2 ic = floor(pc);
    
    float4 xWeights = GetCubicWeight(f.x);
    float4 yWeights = GetCubicWeight(f.y);
    
    float4 color = 0;
    
    // Sample 16 texels
    for(int y = -1; y <= 2; y++)
    {
        for(int x = -1; x <= 2; x++)
        {
            float2 samplePos = (ic + float2(x, y)) * texelSize;
            float weight = xWeights[x+1] * yWeights[y+1];
            color += tex2D(tex, samplePos) * weight;
        }
    }
    
    return color;
}

//////////////////////////////////////////////////
// Color Space Conversions
//////////////////////////////////////////////////

// sRGB to Linear conversion
float3 ToLinear(float3 srgb)
{
    return pow(max(srgb, 0.0), 2.2);
}

// Linear to sRGB conversion
float3 ToSRGB(float3 color)  
{
    return pow(max(color, 0.0), 1.0/2.2);
}

//////////////////////////////////////////////////
// Constants and Definitions
//////////////////////////////////////////////////

#define PI 3.14159265359
#define WAVELENGTH_MIN 380.0 // nm
#define WAVELENGTH_MAX 750.0 // nm

// Common glass types Sellmeier coefficients
static const float3 BK7_B = float3(1.03961212, 0.231792344, 1.01046945);
static const float3 BK7_C = float3(0.00600069867, 0.0200179144, 103.560653);

// Crown glass (typical)
static const float3 CROWN_B = float3(1.12709, 0.124412, 0.827100);
static const float3 CROWN_C = float3(0.00720341, 0.0269835, 100.384);

// Flint glass (typical)
static const float3 FLINT_B = float3(1.34533359, 0.209073176, 0.937357162);
static const float3 FLINT_C = float3(0.00997743871, 0.0470450767, 111.886764);

//////////////////////////////////////////////////
// Shader Logic
//////////////////////////////////////////////////

// Calculate dispersion offset for a specific wavelength
float2 GetDispersionOffset(float wavelength, float2 centered_coord, float radius)
{
    float ior;
    if(UseRealGlass)
    {
        // Combine crown (BK7) and flint glass properties for achromatic-like behavior
        float ior_crown = GetIOR(wavelength, BK7_B, BK7_C);
        float ior_flint = GetIOR(wavelength, FLINT_B, FLINT_C);
        
        // Simulate an achromatic doublet behavior
        ior = (ior_crown - ior_flint) * 2.0;
    }
    else
    {
        // Simplified dispersion model
        ior = 1.0 + (wavelength - WAVELENGTH_MIN) / (WAVELENGTH_MAX - WAVELENGTH_MIN) * 0.1;
    }
    
    // Calculate radial displacement based on IOR
    // This simulates how different wavelengths bend differently through the lens
    float displacement = (ior - 1.0) * radius * ChromaAmount * (FocalLength / 50.0);
    
    return centered_coord * displacement;
}

float4 PhysicalChromaPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float effectStrength = GlobalIntensity * ChromaticIntensity;
    
    // Early exit if effect is disabled
    if (effectStrength <= 0.0)
        return tex2D(ReShade::BackBuffer, texcoord);
        
    // Convert to centered coordinates with aspect ratio correction
    float2 centered = GetCenteredCoord(texcoord);
    float radius = GetRadius(centered);
    float normalizedRadius = radius / sqrt(1.0 + pow(BUFFER_WIDTH / BUFFER_HEIGHT, 2));
    
    // Get original color for mixing
    float3 originalColor = tex2D(ReShade::BackBuffer, texcoord).rgb;
    
    // Sample multiple wavelengths across the visible spectrum
    const int WAVELENGTH_SAMPLES = 8;
    float3 color = 0.0;
    float3 wavelength_sum = 0.0001; // Avoid division by zero
    
    [unroll]
    for(int i = 0; i < WAVELENGTH_SAMPLES; i++)
    {
        float wavelength = lerp(WAVELENGTH_MIN, WAVELENGTH_MAX, 
                              float(i) / (WAVELENGTH_SAMPLES - 1));
        
        float2 offset = GetDispersionOffset(wavelength, centered, normalizedRadius);
        float2 sample_coord = GetTexCoord(centered + offset);
        
        float3 sample_color = SampleBicubic(ReShade::BackBuffer, sample_coord).rgb;
        float3 wavelength_weight = WavelengthToRGB(wavelength);
        
        // Weight the wavelength contribution by the original color
        float3 channel_weight = wavelength_weight * originalColor;
        
        color += sample_color * channel_weight;
        wavelength_sum += channel_weight;
    }
    
    // Normalize while preserving color relationships
    color = color / wavelength_sum;
    
    // Blend based on both radius and color intensity
    float colorIntensity = length(originalColor);
    float blend = smoothstep(0.0, 1.0, normalizedRadius * normalizedRadius) * effectStrength;
    
    // Adjust blend to preserve more of the original color
    blend *= lerp(0.5, 1.0, colorIntensity);
    
    // Final mix preserving original color characteristics
    float3 finalColor = lerp(originalColor, 
                            lerp(originalColor, color, 0.8), // Reduce pure dispersion influence
                            blend);
    
    return float4(finalColor, 1.0);
}


technique PhysicalCA
{
    pass ChromaticAberration
    {
        VertexShader = PostProcessVS;
        PixelShader = PhysicalChromaPS;
    }
}