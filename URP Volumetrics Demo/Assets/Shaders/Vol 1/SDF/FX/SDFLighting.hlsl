#include "NoiseUtils.hlsl" 
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"

SamplerState SDF_linear_clamp_sampler;

float GetDepth(float2 UV)
{
    float pixelWidthX = 1.0f / _ScreenParams.x;
    float pixelHeightY = 1.0f / _ScreenParams.y;
    return Linear01Depth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(UV), _ZBufferParams);
}

float GetEyeDepth(float3 worldPos)
{
    float3 view = TransformWorldToView(worldPos);
    return view.z * -1.0f;

}



void GetDepth_float(float3 worldPos, out float depth)
{
    float3 view = TransformWorldToView(worldPos);
    depth = view.z * -1.0f;

}

float3 voronoi_noise_randomVector(float3 UV, float offset)
{
    float3x3 m = float3x3(15.27, 47.63, 99.41, 89.98, 95.07, 38.39, 33.83, 51.06, 60.77);
    UV = frac(sin(mul(UV, m)) * 46839.32);
    return float3(sin(UV.y * +offset) * 0.5 + 0.5, cos(UV.x * offset) * 0.5 + 0.5, sin(UV.z * offset) * 0.5 + 0.5);
}


float Voronoi(float3 UV, float CellDensity)
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

float inverseLerp(float from, float to, float value)
{
    return (value - from) / (to - from);
}

float Noise(float3 P)
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

float sdVesicaSegment(in float3 p, in float3 start, in float3 end, in float width)
{
    float a = start;
    float b = end;
    float w = width;
    
    
    float3 c = (a + b) * 0.5;
    float l = length(b - a);
    float3 v = (b - a) / l;
    float y = dot(p - c, v);
    float2 q = float2(length(p - c - y * v), abs(y));
    
    float r = 0.5 * l;
    float d = 0.5 * (r * r - w * w) / w;
    float3 h = (r * q.x < d * (q.y - r)) ? float3(0.0, r, 0.0) : float3(-d, 0.0, d + w);
 
    return length(q - h.xy) - h.z;
}

float sdOrientedVesica(float2 p, float2 a, float2 b, float w)
{
    float r = 0.5 * length(b - a);
    float d = 0.5 * (r * r - w * w) / w;
    float2 v = (b - a) / r;
    float2 c = (b + a) * 0.5;
   // float2 q = 0.5 * abs(float2x2(v.y, v.x, -v.x, v.y) * (p - c));
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

static float EPSILON = 0.01f;
static float MINIMUM_MOVE = 0.01f;


float3 Unity_RotateAboutAxis_Degrees(float3 In, float3 Axis, float Rotation)
{
    Rotation = radians(Rotation);
    float s = sin(Rotation);
    float c = cos(Rotation);
    float one_minus_c = 1.0 - c;

    Axis = normalize(Axis);
    float3x3 rot_mat =
    {
        one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
        one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
        one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
    };
    return mul(rot_mat, In);
}

void Mist_float(float3 cameraPos, float3 cameraDir, float4x4 inverseModel, float height, float width, float noiseScale, float noiseHeight, int samples, float sampleRate, out float alpha, out float density)
{
    density = 0;
    alpha = 0;
    float start = 0;
    float depth = start;
    float3 vesicaStart = float3(height, 0, 0);
    float3 vesicaEnd = float3(height * -1.0f, 0, 0);
    for (int a = 0; a < samples; a++)
    {
        float3 p = cameraPos + (depth * cameraDir);
        //p = Unity_RotateAboutAxis_Degrees(p, float3(1, 0, 0), 50);
        float3 pTransformed = mul(inverseModel, float4(p, 1));
        float dist = sdVesica(pTransformed, vesicaStart, vesicaEnd, width) + ((Noise(p * noiseScale) * noiseHeight));
        if (dist < EPSILON)
        {
            alpha = 1;
            float interiorSamples = 0;
            for (int b = a; b < samples; b++)
            {
                p = cameraPos + (depth * cameraDir);
                pTransformed = mul(inverseModel, float4(p, 1));
                //p = Unity_RotateAboutAxis_Degrees(p, float3(1, 0, 0), 50);
                float sdfSample = sdVesica(pTransformed, vesicaStart, vesicaEnd, width) + ((Noise(p * noiseScale) * noiseHeight));
                if (sdfSample < EPSILON)
                {
                    density += sampleRate;
                }
                depth += sampleRate;
            }
            break;
        }
        
        dist = abs(dist);
        depth += max(dist, MINIMUM_MOVE);
    }
  
}

void Fire_float(float3 cameraPos, float3 cameraDir, float2 minMaxHeight, float jaggedness, float gain, float noiseScale, float voronoiScale, int samples, float sampleRate, out float alpha, out float density)
{
    density = 0;
    alpha = 0;
    float start = 0;
    float depth = start;
    for (int a = 0; a < samples; a++)
    {
        float3 p = cameraPos + (depth * cameraDir);
        float sample = (lerp(Noise(p * noiseScale), (Voronoi(p, voronoiScale)), jaggedness) + gain) * (1.0f - clamp(inverseLerp(minMaxHeight.x, minMaxHeight.y, p.y), 0, 1));
  
        alpha = 1;
            //density += sampleRate * sample;
        density += sample;
            
        
        depth += sampleRate;
    }
}

float2 boxIntersection(in float3 ro, in float3 rd, in float3 rad)
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

    return float2(tN, tF);
}

void LightShafts_float(float3 cameraPos, float3 cameraDir, float4x4 model, UnityTexture2D tex, UnitySamplerState ss, float height, float width, float pixelDepth, int samples, out float3 averageColor)
{
    averageColor = float3(0, 0, 0);
    float start = 0;
    float depth = start;
    float halfWidth = width / 2.0f;
    int hits = 0;
    
    float2 intersection = boxIntersection(cameraPos, cameraDir, float3(width / 2, height / 2, width /2));
    float thickness = abs(intersection.x - intersection.y);
    float sampleRate = thickness / samples;
    [unroll(100)]
    for (int a = 0; a < samples; a++)
    {
        float3 p = cameraPos + (depth * cameraDir);
        float pLocalNormalizedX = inverseLerp(-1 * halfWidth, halfWidth, p.x);
        float pLocalNormalizedZ = inverseLerp(-1 * halfWidth, halfWidth, p.z);
        float3 pWorld = mul(model, float4(p, 1));
        if (GetEyeDepth(pWorld) > pixelDepth)//could jsut use decal instead
        {
            break;
        }
        if (pLocalNormalizedX > 1.01f || pLocalNormalizedZ > 1.01f)
        {
            break;
        }
        else
        {
            float3 color = SAMPLE_TEXTURE2D(tex, ss, float2(pLocalNormalizedX, pLocalNormalizedZ)).rgb;
            hits++;
            averageColor += color;
            depth += sampleRate;
        }
        
    }
    if(hits > 0)
    {
    
        averageColor = averageColor / hits;
    }
}

void AveragePositionLight_float(float3 cameraPos, float3 cameraDir, float4x4 worldToSDF, UnityTexture3D sdf, float pixelDepth, int samples, float sampleRate, out float alpha, out float3 averagePosition, out float density)
{
    alpha = 0;
    density = 0;
    averagePosition = float3(0, 0, 0);
    float3 cameraSDFLocalPos = cameraPos;
    float3 cameraSDFLocalDir = cameraDir;
    float start = 0;
    float depth = start;
    float hits = 0;
    for (int a = 0; a < samples; a++)
    {
        float3 p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
        float dist = sdf.SampleLevel(SDF_linear_clamp_sampler, mul(worldToSDF, float4(p, 1)), 0).r;
        if (dist < EPSILON)
        {
            alpha = 1;
            for (int b = a; b < samples; b++)
            {
                p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
                
                float sample = sdf.SampleLevel(SDF_linear_clamp_sampler, mul(worldToSDF, float4(p, 1)), 0).r;
                if (GetEyeDepth(p) > pixelDepth)
                {
                    break;
                }
                if (sample < EPSILON)
                {
                    density += sampleRate;
                    averagePosition += p;
                    hits++;
                }
                depth += sampleRate;
            }
            averagePosition /= hits;
            break;
        }
        dist = abs(dist);
        depth += dist;
    }
}

void SearchLight_float(float3 cameraPos, float3 cameraDir, float4x4 inverseModel, float length, float startWidth, float endWidth, float separation, float pixelDepth, int samples, float sampleRate, out float alpha, out float3 averagePosition, out float density)
{
    density = 0;
    alpha = 0;
    averagePosition = float3(0, 0, 0);
    float start = 0;
    float depth = start;
    float hits = 0;
    for (int a = 0; a < samples; a++)
    {
        float3 p = cameraPos + (depth * cameraDir);
        float3 pTransformed = mul(inverseModel, float4(p, 1));
        float dist = sdDoubleCappedCones(pTransformed, length, startWidth, endWidth, separation);
        if (dist < EPSILON)
        {
            alpha = 1;
            for (int b = a; b < samples; b++)
            {
                p = cameraPos + (depth * cameraDir);
                pTransformed = mul(inverseModel, float4(p, 1));
                float sample = sdDoubleCappedCones(pTransformed, length, startWidth, endWidth, separation);
                if (GetEyeDepth(p) > pixelDepth)
                {
                    break;
                }
                if (sample < EPSILON)
                {
                    density += sampleRate;
                    averagePosition += pTransformed;
                    hits++;
                }
                depth += sampleRate;
            }
            averagePosition /= hits;
            break;
        }
        dist = abs(dist);
        depth += max(dist, MINIMUM_MOVE);
    }
}

void PointLight_float(float3 cameraPos, float3 cameraDir, float4x4 worldToSDF, UnityTexture3D sdf, float3 lightPos, float pixelDepth, int samples, float sampleRate, out float alpha, out float light, out float density)
{
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
        float dist = sdf.SampleLevel(SDF_linear_clamp_sampler, mul(worldToSDF, float4(p, 1)), 0).r;
        if (dist < EPSILON)
        {
            alpha = 1;
            for (int b = a; b < samples; b++)
            {
                p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
                light += 1.0f / (distance(p, lightPos));
                float sample = sdf.SampleLevel(SDF_linear_clamp_sampler, mul(worldToSDF, float4(p, 1)), 0).r;
                if (GetEyeDepth(p) > pixelDepth)
                {
                    break;
                }
                if (sample < EPSILON)
                {
                    density += sampleRate;
                }
                depth += sampleRate;
            }
            break;
        }
        dist = abs(dist);
        depth += dist;
    }
}

//void BeamLight_float(float3 cameraPos, float3 cameraDir, float4x4 worldToSDF, UnityTexture3D sdf, float3 lightPos, float3 lightAxis, float pixelDepth, int samples, float sampleRate, out float alpha, out float light, out float density)
//{
//    alpha = 0;
//    density = 0;
//    light = 0;
//    float3 cameraSDFLocalPos = cameraPos;
//    float3 cameraSDFLocalDir = cameraDir;
//    float start = 0;
//    float depth = start;
//    for (int a = 0; a < samples; a++)
//    {
//        float3 p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
//        float dist = sdf.SampleLevel(SDF_linear_clamp_sampler, mul(worldToSDF, float4(p, 1)), 0).r;
//        if (dist < EPSILON)
//        {
//            alpha = 1;
//            for (int b = a; b < samples; b++)
//            {
//                p = cameraSDFLocalPos + (depth * cameraSDFLocalDir);
//                light += 1.0f / (distance(p * lightAxis, lightPos * lightAxis));
//                float sample = sdf.SampleLevel(SDF_linear_clamp_sampler, mul(worldToSDF, float4(p, 1)), 0).r;
//                if (GetEyeDepth(p) > pixelDepth)
//                {
//                    break;
//                }
//                if (sample < EPSILON)
//                {
//                    density += sampleRate;
//                }
//                depth += sampleRate;
//            }
//            break;
//        }
//        dist = abs(dist);
//        depth += dist;
//    }
//}
