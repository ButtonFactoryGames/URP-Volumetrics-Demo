#include "Noise.cginc" 
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
#endif

float GetEyeDepth(float3 worldPos)
{
    float3 view = TransformWorldToView(worldPos);
    return view.z * -1.0f;

}

float3 voronoi_noise_randomVector(float3 UV, float offset)
{
    float3x3 m = float3x3(15.27, 47.63, 99.41, 89.98, 95.07, 38.39, 33.83, 51.06, 60.77);
    UV = frac(sin(mul(UV, m)) * 46839.32);
    return float3(sin(UV.y * +offset) * 0.5 + 0.5, cos(UV.x * offset) * 0.5 + 0.5, sin(UV.z * offset) * 0.5 + 0.5);
}


float Voronoi(float3 UV, float CellDensity) // 0 to 1
{
    float AngleOffset = 100;
    float3 g = floor(UV * CellDensity);
    float3 f = frac(UV * CellDensity);
    float value = 8;
    int dist = 1;
    for (int y = -1 * dist; y <= dist; y++)
    {
        for (int x = -1 * dist; x <= dist; x++)
        {
            for (int z = -1 * dist; z <= dist; z++)
            {
                float3 lattice = float3(x, y, z);
                float3 offset = voronoi_noise_randomVector(g + lattice, AngleOffset);
                float3 v = lattice + offset - f;
                float d = dot(v, v);
                
                if (d < value)
                {
                    value = d;
                }
            }
        }
    }
    return value;
}

float Noise(float3 P) // -1 to 1
{
    float3 Pi0 = floor(P); // Integer part for indexing
    float3 Pi1 = Pi0 + (float3) 1.0; // Integer part + 1
    Pi0 = mod289(Pi0);
    Pi1 = mod289(Pi1);
    float3 Pf0 = frac(P); // Fractional part for interpolation
    float3 Pf1 = Pf0 - (float3) 1.0; // Fractional part - 1.0
    float4 ix = float4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    float4 iy = float4(Pi0.y, Pi0.y, Pi1.y, Pi1.y);
    float4 iz0 = (float4) Pi0.z;
    float4 iz1 = (float4) Pi1.z;

    float4 ixy = permute(permute(ix) + iy);
    float4 ixy0 = permute(ixy + iz0);
    float4 ixy1 = permute(ixy + iz1);

    float4 gx0 = ixy0 / 7.0;
    float4 gy0 = frac(floor(gx0) / 7.0) - 0.5;
    gx0 = frac(gx0);
    float4 gz0 = (float4) 0.5 - abs(gx0) - abs(gy0);
    float4 sz0 = step(gz0, (float4) 0.0);
    gx0 -= sz0 * (step((float4) 0.0, gx0) - 0.5);
    gy0 -= sz0 * (step((float4) 0.0, gy0) - 0.5);

    float4 gx1 = ixy1 / 7.0;
    float4 gy1 = frac(floor(gx1) / 7.0) - 0.5;
    gx1 = frac(gx1);
    float4 gz1 = (float4) 0.5 - abs(gx1) - abs(gy1);
    float4 sz1 = step(gz1, (float4) 0.0);
    gx1 -= sz1 * (step((float4) 0.0, gx1) - 0.5);
    gy1 -= sz1 * (step((float4) 0.0, gy1) - 0.5);

    float3 g000 = float3(gx0.x, gy0.x, gz0.x);
    float3 g100 = float3(gx0.y, gy0.y, gz0.y);
    float3 g010 = float3(gx0.z, gy0.z, gz0.z);
    float3 g110 = float3(gx0.w, gy0.w, gz0.w);
    float3 g001 = float3(gx1.x, gy1.x, gz1.x);
    float3 g101 = float3(gx1.y, gy1.y, gz1.y);
    float3 g011 = float3(gx1.z, gy1.z, gz1.z);
    float3 g111 = float3(gx1.w, gy1.w, gz1.w);

    float4 norm0 = taylorInvSqrt(float4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;

    float4 norm1 = taylorInvSqrt(float4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;

    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, float3(Pf1.x, Pf0.y, Pf0.z));
    float n010 = dot(g010, float3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, float3(Pf1.x, Pf1.y, Pf0.z));
    float n001 = dot(g001, float3(Pf0.x, Pf0.y, Pf1.z));
    float n101 = dot(g101, float3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, float3(Pf0.x, Pf1.y, Pf1.z));
    float n111 = dot(g111, Pf1);

    float3 fade_xyz = fade(Pf0);
    float4 n_z = lerp(float4(n000, n100, n010, n110), float4(n001, n101, n011, n111), fade_xyz.z);
    float2 n_yz = lerp(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = lerp(n_yz.x, n_yz.y, fade_xyz.x);
    return 2.2 * n_xyz;
}

float NoiseNormalized(float3 P) // 0 to 1
{
    return (Noise(P) + 1.0f) / 2.0f;

}



float sdCappedCone(float3 p, float3 a, float3 b, float ra, float rb)
{
    float rba = rb - ra;
    float baba = dot(b - a, b - a);
    float papa = dot(p - a, p - a);
    float paba = dot(p - a, b - a) / baba;
    float x = sqrt(papa - paba * paba * baba);
    float cax = max(0.0, x - ((paba < 0.5) ? ra : rb));
    float cay = abs(paba - 0.5) - 0.5;
    float k = rba * rba + baba;
    float f = clamp((rba * (x - ra) + paba * baba) / k, 0.0, 1.0);
    float cbx = x - ra - f * rba;
    float cby = paba - f;
    float s = (cbx < 0.0 && cay < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(cax * cax + cay * cay * baba,
                     cbx * cbx + cby * cby * baba));
}

float sdDoubleCappedCones(float3 p, float length, float startWidth, float endWidth, float separation)
{
    float3 cone1Start = float3(separation, 0, length);
    float3 cone1End = float3(separation, 0, length * -1.0f);
    float3 cone2Start = float3(separation * -1.0f, 0, length);
    float3 cone2End = float3(separation * -1.0f, 0, length * -1.0f);
    
    float cone1dist = sdCappedCone(p, cone1Start, cone1End, startWidth, endWidth);
    float cone2dist = sdCappedCone(p, cone2Start, cone2End, startWidth, endWidth);
    
    return min(cone1dist, cone2dist);
}

float boxIntersection(in float3 ro, in float3 rd, in float3 rad)
{
    float3 m = 1.0 / rd;
    float3 n = m * ro;
    float3 k = abs(m) * rad;
    float3 t1 = -n - k;
    float3 t2 = -n + k;

    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
	
    if (tN > tF || tF < 0.0)
        return float2(-1, -1); // no intersection
    
    //oN = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);

    return abs(tN - tF);
}


float Remap(float In, float2 InMinMax, float2 OutMinMax)
{
    return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
}

float sdOrientedVesica(float2 p, float2 a, float2 b, float w)
{
    float r = 0.5 * length(b - a);
    float d = 0.5 * (r * r - w * w) / w;
    float2 v = (b - a) / r;
    float2 c = (b + a) * 0.5;
    float2 q = 0.5 * abs((p - c));
    float3 h = (r * q.x < d * (q.y - r)) ? float3(0.0, r, 0.0) : float3(-d, 0.0, d + w);
    return length(q - h.xy) - h.z;
}

float sdVesica(in float3 p, in float3 start, in float3 end, in float width)
{
    float o = 0;
    float2 q = float2(length(p.xz) - o, p.y);
    return sdOrientedVesica(q, start, end, width);
}

void FireObjectSpace_float(float3 cameraPos, float3 cameraDir, float time, float noiseScale, float voronoiScale, float surfaceSamples, float interiorSamples, float sampleRate, out float alpha, out float density)
{
    alpha = 0;
    density = 0;
    float depth = 0;
    float thickness = boxIntersection(cameraPos - cameraDir, cameraDir, float3(0.5f, 0.5f, 0.5f));
    float averageHeight = 0;
    float3 vesicaStart = float3(0, 0, 0);
    float3 vesicaEnd = float3(0, -1, 0);

    sampleRate = thickness / (surfaceSamples);
    for (int a = 0; a < surfaceSamples; a++)
    {
        alpha = 1;
        float3 p = cameraPos + (depth * cameraDir);
        
        float dist = sdVesica(p, vesicaStart, vesicaEnd, 0.25f);
        dist = Remap(dist, float2(-0.5f, 0.0f), float2(1.0f, 0.0f));
        dist = clamp(dist, 0, 1);
        float noise = NoiseNormalized((p - float3(0, time, 0)) * noiseScale);
        float voronoi = Voronoi((p - float3(0, time, 0)) * voronoiScale, 1);
        float combined = lerp(1 - voronoi, noise, interiorSamples);
        float height = Remap(p.y, float2(-0.5f, 0.5f), float2(0, 1));
            //height = pow(height, 2.0f);
        combined = Remap(combined, float2(0, 1), float2(0.8, -0.2f));
        averageHeight += height;
        density += dist * combined;
        depth += sampleRate;
    }
    averageHeight /= surfaceSamples;
    
}


void SmokeObjectSpace_float(float3 cameraPos, float3 cameraDir, float time, float voronoiScale, float globeSize, float surfaceSamples, float sampleRate, out float3 color, out float alpha)
{
    alpha = 0;
    color = float3(0, 0, 0);
    float depth = 0;
    float thickness = boxIntersection(cameraPos - cameraDir, cameraDir, float3(0.5f, 0.5f, 0.5f));
    cameraDir = normalize(cameraDir);
    cameraPos = (cameraPos * voronoiScale) + float3(0, 0, time);
    
    for (int a = 0; a < surfaceSamples; a++)
    {
        float3 p = cameraPos + (depth * cameraDir);
        if (length(closestCell(p).xyz - p) < globeSize)
        {
            float3 surfacePosition = p;
            
            CustomLightingData data;
            data.normalWS = normalize(surfacePosition);
            data.albedo = float3(1, 1, 1);
            data.positionWS = surfacePosition;
            data.ambientOcclusion = 0;
            data.bakedGI = 0;
#ifdef SHADERGRAPH_PREVIEW
                        data.shadowCoord = 0;
                        data.shadowCoord = 0;
                        data.bakedGI = 0;
#else
            float4 positionCS = TransformWorldToHClip(surfacePosition);
#if SHADOWS_SCREEN
            data.shadowCoord = ComputeScreenPos(positionCS);
#else
            data.shadowCoord = TransformWorldToShadowCoord(surfacePosition);
#endif
            color = CalculateCustomLighting(data);
#endif
                    
            alpha = 1;
            break;
        }
        depth += sampleRate;
    }
    
}
