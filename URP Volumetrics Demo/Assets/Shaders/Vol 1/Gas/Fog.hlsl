inline float3 voronoi_noise_randomVector (float3 UV, float offset){
    float3x3 m = float3x3(15.27, 47.63, 99.41, 89.98, 95.07, 38.39, 33.83, 51.06, 60.77);
    UV = frac(sin(mul(UV, m)) * 46839.32);
    return float3(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5, sin(UV.z*offset)*0.5+0.5);
}

float Voronoi3D(float3 UV, float AngleOffset, float CellDensity) {
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

float remap(float In, float2 InMinMax, float2 OutMinMax)
{
    return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
}


void myFog_float(float3 cameraPos, float3 cameraDir, float3 position, float radius, float voronoi3DScale,float voronoi2DScale, float3 voronoiOffset, out float thickness, out float voronoi3d, out float voronoi2d, out float3 normals)
{
    thickness = 0;
    voronoi3d = 0;
        voronoi2d = 0;
        normals = float3(0,0,0);
    float voronoiAngle = 100;
	  float cx = position.x;
        float cy = position.y;
        float cz = position.z;

        float px = cameraPos.x;
        float py = cameraPos.y;
        float pz = cameraPos.z;

        float vx = cameraDir.x - px;
        float vy = cameraDir.y - py;
        float vz = cameraDir.z - pz;

        float A = vx * vx + vy * vy + vz * vz;
        float B = 2.0f * (px * vx + py * vy + pz * vz - vx * cx - vy * cy - vz * cz);
        float C = px * px - 2 * px * cx + cx * cx + py * py - 2 * py * cy + cy * cy +
                   pz * pz - 2 * pz * cz + cz * cz - radius * radius;

        float D = B * B - 4 * A * C;

        if (D <= 0)
        {
            thickness = 0;
        }
        else
        {
            float t1 = (-B - sqrt(D)) / (2.0f * A);

            float3 solution1 = float3(cameraPos.x * (1 - t1) + t1 * cameraDir.x,
                                             cameraPos.y * (1 - t1) + t1 * cameraDir.y,
                                             cameraPos.z * (1 - t1) + t1 * cameraDir.z);
            float t2 = (-B + sqrt(D)) / (2.0f * A);
            float3 solution2 = float3(cameraPos.x * (1 - t2) + t2 * cameraDir.x,
                                             cameraPos.y * (1 - t2) + t2 * cameraDir.y,
                                             cameraPos.z * (1 - t2) + t2 * cameraDir.z);

            thickness = distance(solution1, solution2);
            thickness = thickness / (radius * 2.0f);
            float3 closest = solution1;
            float3 furthest = solution2;
            if(distance(solution2, cameraPos) < distance(solution1, cameraPos))
            {
                closest = solution2;
                furthest = solution1;
            }
            //voronoi3d = clamp( Voronoi3D(closest + voronoiOffset, voronoiAngle, voronoi3DScale), 0 , 1);
            // voronoi3d = clamp( Voronoi3D(closest + voronoiOffset, voronoiAngle, voronoi3DScale) + (Voronoi3D(furthest + voronoiOffset, voronoiAngle, voronoi3DScale) / 2.0f), 0 , 1);
            voronoi3d = clamp( Voronoi3D(closest + voronoiOffset, voronoiAngle, voronoi3DScale) + (Voronoi3D(closest - voronoiOffset, voronoiAngle, voronoi3DScale) / 2.0f), 0 , 1);

            float3 normal =  position - cameraPos;
            float3 rayDir = normalize(cameraDir);
            float denominator = dot(rayDir, normal);
            if (denominator > 0.00001f)
            {
                float t = dot(position - cameraPos, normal) / denominator;
                float3 p = cameraPos + (rayDir * t);
                 voronoi2d = clamp( Voronoi3D(p + (voronoiOffset * -1), voronoiAngle, voronoi2DScale), 0 , 1);
            }

            normals = normalize(position - closest);
        }
}