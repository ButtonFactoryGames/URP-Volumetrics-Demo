#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
#if (SHADERPASS != SHADERPASS_FORWARD)
#undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
#endif
#endif

struct CustomLightingData
{
    float3 positionWS;
    float3 normalWS;
    float4 shadowCoord;
    float ambientOcclusion;

    // Surface attributes
    float3 albedo;

    //baked lighting
    float3 bakedGI;
};

#ifndef SHADERGRAPH_PREVIEW

float3 CustomGlobalIllumination(CustomLightingData data)
{
    float3 indirectDiffuse = data.albedo * data.bakedGI * data.ambientOcclusion;
    return indirectDiffuse;
}

float3 CustomLightHandling(CustomLightingData data, Light light)
{

    float3 radiance = light.color * (light.distanceAttenuation * light.shadowAttenuation);

    float diffuse = saturate(dot(data.normalWS, light.direction));

    float3 color = data.albedo * radiance * diffuse;

    return color;
}
#endif


float3 CalculateCustomLighting(CustomLightingData data)
{
#ifdef SHADERGRAPH_PREVIEW
    float3 lightDir = float3(0.5, 0.5, 0);
    float intensity = saturate(dot(data.normalWS, lightDir));
    return data.albedo * intensity;
#else
    // Get the main light. Located in URP/ShaderLibrary/Lighting.hlsl
    Light mainLight = GetMainLight(data.shadowCoord, data.positionWS, 1);
    MixRealtimeAndBakedGI(mainLight, data.normalWS, data.bakedGI);
    float3 color = CustomGlobalIllumination(data);
    color += CustomLightHandling(data, mainLight);

#ifdef _ADDITIONAL_LIGHTS
        // Shade additional cone and point lights. Functions in URP/ShaderLibrary/Lighting.hlsl
        uint numAdditionalLights = GetAdditionalLightsCount();
        for (uint lightI = 0; lightI < numAdditionalLights; lightI++) {
            Light light = GetAdditionalLight(lightI, data.positionWS, 1);
            color += CustomLightHandling(data, light);
        }
#endif

    return color;
#endif

}

//void CalculateCustomLighting_float(float3 Albedo, float3 Position, float3 Normal, float AmbientOcclusion,
//    float3 BakedGI,
//    out float3 Color)
//{

//    CustomLightingData data;
//    data.normalWS = Normal;
//    data.albedo = Albedo;
//    data.positionWS = Position;
//    data.ambientOcclusion = AmbientOcclusion;

//#ifdef SHADERGRAPH_PREVIEW
//    data.shadowCoord = 0;
//    data.shadowCoord = 0;
//    data.bakedGI = 0;
//#else
//    // Calculate the main light shadow coord. There are two types depending on if cascades are enabled
//    float4 positionCS = TransformWorldToHClip(Position);
//#if SHADOWS_SCREEN
//            data.shadowCoord = ComputeScreenPos(positionCS);
//#else
//    data.shadowCoord = TransformWorldToShadowCoord(Position);
//#endif

//        // // The lightmap UV is usually in TEXCOORD1
//        //// If lightmaps are disabled, OUTPUT_LIGHTMAP_UV does nothing
//        //float2 lightmapUV;
//        //OUTPUT_LIGHTMAP_UV(LightmapUV, unity_LightmapST, lightmapUV);
//        //// Samples spherical harmonics, which encode light probe data
//        //float3 vertexSH;
//        //OUTPUT_SH(Normal, vertexSH);
//        //// This function calculates the final baked lighting from light maps or probes
//        //data.bakedGI = SAMPLE_GI(lightmapUV, vertexSH, Normal);
//    data.bakedGI = BakedGI;

//#endif

//    Color = CalculateCustomLighting(data);
//}

#endif


float sdSphere(float3 p, float3 spherePosition, float radius)
{
  return (distance(p, spherePosition) - radius);
}

float sceneSDF(float3 p, float3 spherePos, float sphereRadius)
{
    float sdf = sdSphere(p, spherePos, sphereRadius);
    return sdf;
}

static float EPSILON = 0.01f;
static float MINIMUM_MOVE = 0.01f;


void Mist_float(float3 cameraPos, float3 cameraDir, float3 spherePos, float sphereRadius, int samples, float sampleRate, out float3 color , out float density)
{
    density = 0;
    color = float3(0, 0, 0);
    float start = 0;
    float depth = start;
    for (int a = 0; a < samples; a++)
    {
        float3 p = cameraPos + (depth * cameraDir);
        float dist = sceneSDF(p, spherePos, sphereRadius);
        if (dist < EPSILON)
        {
            float interiorSamples = 0;
            for (int b = a; b < samples; b++)
            {
                p = cameraPos + (depth * cameraDir);
                float sdfSample = sceneSDF(p, spherePos, sphereRadius);
                if (sdfSample < EPSILON)
                {
                    interiorSamples += 1;
                    CustomLightingData data;
                    data.normalWS = normalize(p);
                    data.albedo = float3(1, 1, 1);
                    data.positionWS = p;
                    data.ambientOcclusion = 0;
                    data.bakedGI = 0;
#ifdef SHADERGRAPH_PREVIEW
                        data.shadowCoord = 0;
                        data.shadowCoord = 0;
                        data.bakedGI = 0;
#else
                    float4 positionCS = TransformWorldToHClip(p);
#if SHADOWS_SCREEN
                               data.shadowCoord = ComputeScreenPos(positionCS);
#else
                    data.shadowCoord = TransformWorldToShadowCoord(p);
#endif
                    color += CalculateCustomLighting(data);
#endif
                    
                    density += sampleRate;
                }
                depth += sampleRate;
            }
            color /= interiorSamples;
            break;
        }
        
        dist = abs(dist);
        depth += max(dist, MINIMUM_MOVE);
    }
}