#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"

SamplerState SDF_linear_clamp_sampler;

void SDFSample_float(float3 PositionWS, float4x4 WorldToSDF, UnityTexture3D SDF, out float Distance)
{
    float3 sdfLocalPos = mul(WorldToSDF, float4(PositionWS, 1)).xyz;
    Distance = SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos, 0).r;
}

void SDFSampleNormal_float(float3 PositionWS, float4x4 WorldToSDF, UnityTexture3D SDF, out float Distance, out float3 Normal)
{
    float3 sdfLocalPos = mul(WorldToSDF, float4(PositionWS, 1)).xyz;
    Distance = SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos, 0).r;

    float3 size;
    float levels;
    SDF.tex.GetDimensions(0, size.x, size.y, size.z, levels); 
    float2 k = float2(1, -1);
    // A simple texel size estimate, since the tetrahedral sampling pattern requires more care to get the right eps
    float avgSize = dot(size, 0.33);
    // TODO: get rid of the magic 4 mult 
    float eps = 4.0/avgSize;
    Normal = normalize( k.xyy * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.xyy * eps, 0).r + 
                        k.yyx * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.yyx * eps, 0).r + 
                        k.yxy * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.yxy * eps, 0).r + 
                        k.xxx * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.xxx * eps, 0).r);
}

static float EPSILON = 0.01f;
static float END_DISTANCE = 500;
static float MINIMUM_MOVE = 0.01f;

void SDFRaymarch_float(float3 cameraPos, float3 cameraDir, float4x4 worldToSDF, UnityTexture3D sdf, int samples, float sampleRate, out float alpha, out float density, out float3 worldPos)
{
    worldPos = float3(0,0,0);
    alpha = 0;
    density = 0;

    float3 cameraSDFLocalPos = cameraPos;
    float3 cameraSDFLocalDir = cameraDir;
    float start = 0;
	float depth = start;
    for (int a = 0; a < samples; a++) 
    {
        float3 p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
        float dist = sdf.SampleLevel(SDF_linear_clamp_sampler,  mul(worldToSDF, float4(p, 1)), 0).r;
        if (dist < EPSILON) 
        {
            alpha = 1;
            worldPos = p;

            for (int b = a; b < samples; b++) 
            {
                p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
                float sample = sdf.SampleLevel(SDF_linear_clamp_sampler,  mul(worldToSDF, float4(p, 1)), 0).r;
                if(sample < EPSILON)
                {
                    density += sampleRate;
                }
                depth+=sampleRate;
            }
            break;
        }
        dist = abs(dist);
       // depth += max(dist, MINIMUM_MOVE);
        depth += dist;
    }

}

void SDFRaymarchPointLight_float(float3 cameraPos, float3 cameraDir, float4x4 worldToSDF, UnityTexture3D sdf,float3 lightPos, int samples, float sampleRate, out float alpha, out float light, out float density, out float3 worldPos)
{
    worldPos = float3(0,0,0);
    alpha = 0;
    density = 0;
    light = 0;
    float3 cameraSDFLocalPos = cameraPos;
    float3 cameraSDFLocalDir = cameraDir;
    float start = 0;
	float depth = start;
    for (int a = 0; a < samples; a++) 
    {
        float3 p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
        float dist = sdf.SampleLevel(SDF_linear_clamp_sampler,  mul(worldToSDF, float4(p, 1)), 0).r;
        if (dist < EPSILON) 
        {
            alpha = 1;
            worldPos = p;

            for (int b = a; b < samples; b++) 
            {
                p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
                light += 1.0f / (distance(p, lightPos));
                float sample = sdf.SampleLevel(SDF_linear_clamp_sampler,  mul(worldToSDF, float4(p, 1)), 0).r;
                if(sample < EPSILON)
                {
                    density += sampleRate;
                }
                depth+=sampleRate;
            }
            break;
        }
       
        dist = abs(dist);
        depth += dist;
    }
}