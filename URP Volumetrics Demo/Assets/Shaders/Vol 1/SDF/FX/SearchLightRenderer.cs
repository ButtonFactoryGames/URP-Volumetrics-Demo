using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

[ExecuteAlways]
public class SearchLightRenderer : MonoBehaviour
{
    [SerializeField] private float length;
    [SerializeField] private float startRadius;
    [SerializeField] private float endRadius;
    [SerializeField] private float separation;


    private static MaterialPropertyBlock _propertyBlock;
    public static MaterialPropertyBlock PropertyBlock
    {
        get
        {
            if (_propertyBlock == null)
                _propertyBlock = new MaterialPropertyBlock();
            return _propertyBlock;
        }
    }

    public void OnValidate()
    {
        UpdateTexture();
        UpdateMesh();
    }

    private void UpdateTexture()
    {
        Renderer renderer = GetComponent<Renderer>();
        renderer.GetPropertyBlock(PropertyBlock);
        PropertyBlock.SetFloat("_Separation", separation);
        PropertyBlock.SetFloat("_Length", length);
        PropertyBlock.SetFloat("_StartRadius", startRadius);
        PropertyBlock.SetFloat("_EndRadius", endRadius);
        renderer.SetPropertyBlock(PropertyBlock);
    }
    private void UpdateMesh()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();

        if (meshFilter != null)
        {
            Bounds bounds = new Bounds();
            bounds.center = Vector3.zero;
            bounds.size = new Vector3( (separation * 2.0f) + (Mathf.Max(startRadius, endRadius) * 2.0f), (Mathf.Max(startRadius, endRadius) * 2.0f), length * 2.0f);
            meshFilter.sharedMesh = GetMesh(bounds);

        }
    }

    private Vector3[] GetCorners(Bounds bounds)
    {
        Vector3 boundPoint1 = bounds.min;
        Vector3 boundPoint2 = bounds.max;
        Vector3 boundPoint3 = new Vector3(boundPoint1.x, boundPoint1.y, boundPoint2.z);
        Vector3 boundPoint4 = new Vector3(boundPoint1.x, boundPoint2.y, boundPoint1.z);
        Vector3 boundPoint5 = new Vector3(boundPoint2.x, boundPoint1.y, boundPoint1.z);
        Vector3 boundPoint6 = new Vector3(boundPoint1.x, boundPoint2.y, boundPoint2.z);
        Vector3 boundPoint7 = new Vector3(boundPoint2.x, boundPoint1.y, boundPoint2.z);
        Vector3 boundPoint8 = new Vector3(boundPoint2.x, boundPoint2.y, boundPoint1.z);

        Vector3[] vertices = new[] { boundPoint1, boundPoint2, boundPoint3, boundPoint4, boundPoint5, boundPoint6, boundPoint7, boundPoint8 };
        return vertices;
    }

    private Mesh GetMesh(Bounds bounds)
    {
        var mesh = new Mesh();
        Vector3[] vertices = GetCorners(bounds);
        mesh.vertices = vertices;
        mesh.triangles = new[]
        {
            0,7,4,
            0,3,7,
            5,1,3,
            3,1,7,
            7,1,4,
            4,1,6,
            5,3,2,
            2,3,0,
            0,4,2,
            2,4,6,
            1,5,2,
            6,1,2
            };
        mesh.Optimize();
        mesh.RecalculateNormals();
        return mesh;
    }
}
