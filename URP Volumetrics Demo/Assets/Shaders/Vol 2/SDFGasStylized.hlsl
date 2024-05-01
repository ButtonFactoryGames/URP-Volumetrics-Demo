uniform float _Positions[10 * 3];
uniform float _Radii[10];
uniform float _Count;
uniform float _Smoothness;

inline float3 voronoi_noise_randomVector (float3 UV, float offset){
    float3x3 m = float3x3(15.27, 47.63, 99.41, 89.98, 95.07, 38.39, 33.83, 51.06, 60.77);
    UV = frac(sin(mul(UV, m)) * 46839.32);
    return float3(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5, sin(UV.z*offset)*0.5+0.5);
}

float voronoi3D(float3 UV, float AngleOffset, float CellDensity) {
    float3 g = floor(UV * CellDensity);
    float3 f = frac(UV * CellDensity);
    float3 res = float3(8.0, 8.0, 8.0);
 
    for(int y=-1; y<=1; y++){
        for(int x=-1; x<=1; x++){
            for(int z=-1; z<=1; z++){
                float3 lattice = float3(x, y, z);
                float3 offset = voronoi_noise_randomVector(g + lattice, AngleOffset);
                float3 v = lattice + offset - f;
                float d = dot(v, v);
                
                if(d < res.x){
                    res.y = res.x;
                    res.x = d;
                    res.z = offset.x;
                }else if (d < res.y){
                    res.y = d;
                }
            }
        }
    }
 
    return res.x;
}

float sdSphere(float3 p, float3 spherePosition, float radius)
{
  return (distance(p, spherePosition) - radius);
}

float sdf_smin(float a, float b)
{
        float k = _Smoothness;
    float res = exp(-k*a) + exp(-k*b);
    return -log(max(0.0001,res)) / k;
}


float opSmoothUnion( float d1, float d2)
{
    float k = _Smoothness;
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return lerp( d2, d1, h ) - k*h*(1.0-h);
}

float opUnion( float d1, float d2 )
{
    return min(d1,d2);
}

float sceneSDF(float3 p)
{
    float3 spherePosition = float3(_Positions[0],_Positions[1],_Positions[2]);
    float sphereRadius = _Radii[0];

    float sdf = sdSphere(p, spherePosition, sphereRadius);

	for(int i = 1; i < _Count; i++)
	{
		spherePosition = float3(_Positions[(i * 3)],_Positions[(i * 3) + 1],_Positions[(i * 3) + 2]);
		sphereRadius = _Radii[i];
        sdf = opSmoothUnion(sdf, sdSphere(p, spherePosition, sphereRadius));
    }

    return sdf;
}

float GetEyeDepth(float3 worldPos)
{
    float3 view = TransformWorldToView(worldPos);
    return view.z * -1.0f;
}

static int MAX_MARCHING_STEPS = 30;
static float EPSILON = 0.01f;
static float END_DISTANCE = 20;
static float MINIMUM_MOVE = 0.01f;


void GasStylized_float(float3 cameraPos, float3 cameraDir, float voronoiScale, float voronoiHeight, float pixelDepth, out float voronoi, out float thickness, out float3 normals)
{
    voronoi = 0;
    thickness = 0;
    normals = float3(0,0,0);
    bool hitFront = false;
    bool hitBack = false;
    float3 entry = float3(0,0,0);
    float3 exit = float3(0,0,0);
    if(_Count != 0)
    {
        float start = 0;
	    float depth = start;
        for (int b = 0; b < MAX_MARCHING_STEPS; b++) 
        {
            float3 p = cameraPos + (depth * cameraDir);
            float dist = sceneSDF(p);
            if (GetEyeDepth(p) > pixelDepth)
            {
                break;
            }
            if(dist < voronoiHeight)
            {
                voronoi = 1 - voronoi3D(p * voronoiScale, 100, 5);
                dist += voronoi * voronoiHeight;
            }
            if (dist < EPSILON) 
            {
                hitFront = true;
                entry = p;
                normals = normalize(float3(
                    sceneSDF(float3(p.x + EPSILON, p.y, p.z)) - sceneSDF(float3(p.x - EPSILON, p.y, p.z)),
                    sceneSDF(float3(p.x, p.y + EPSILON, p.z)) - sceneSDF(float3(p.x, p.y - EPSILON, p.z)),
                    sceneSDF(float3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(float3(p.x, p.y, p.z - EPSILON))
                ));
                break;
            }
            dist = abs(dist);
            depth += max(dist, MINIMUM_MOVE);
        }

        cameraPos = cameraPos + (cameraDir * END_DISTANCE);
        cameraDir *= -1.0f;

        start = 0;
	    depth = start;
        for (int b = 0; b < MAX_MARCHING_STEPS; b++) 
        {
            float3 p = cameraPos + (depth * cameraDir);
            float dist = sceneSDF(p);
            if (dist < EPSILON * 2.0f) 
            {
                hitBack = true;
                exit = p;
                break;
            }
            dist = abs(dist);
            depth += max(dist, MINIMUM_MOVE);
        }
        if(hitFront && hitBack)
        {
            thickness = distance(entry, exit);
        }
    }


}