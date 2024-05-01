using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.ProBuilder;
using UnityEngine.SceneManagement;

[ExecuteAlways]
public class SDFGasInputs : MonoBehaviour
{
    private const int maxSphereCount = 10;

    [SerializeField] private MeshFilter gasMeshFilter;
    [SerializeField] private Renderer gasRenderer;
    [SerializeField] private float smoothness;
    [SerializeField] private bool updateMesh;
    [SerializeField] private GasPosition[] gasPositions;

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

    [System.Serializable]
    private struct GasPosition
    {
        [SerializeField] public Vector3 position;
        [SerializeField] public float radius;
    }

    private void UpdateGas()
    {
        if (gasRenderer != null && gasPositions.Length > 0)
        {
            gasRenderer.GetPropertyBlock(PropertyBlock);
            List<float> positions = new List<float>();
            foreach (GasPosition position in gasPositions)
            {
                positions.Add(position.position.x);
                positions.Add(position.position.y);
                positions.Add(position.position.z);
            }
            while (positions.Count < 3 * maxSphereCount)
            {
                positions.Add(0);
            }
            var radii = gasPositions.Select(x => x.radius).ToList();
            while(radii.Count < maxSphereCount)
            {
                radii.Add(0);
            }
            PropertyBlock.SetFloatArray("_Positions", positions);
            PropertyBlock.SetFloatArray("_Radii", radii);
            PropertyBlock.SetFloat("_Count", gasPositions.Count());
            PropertyBlock.SetFloat("_Smoothness", smoothness);
            gasRenderer.SetPropertyBlock(PropertyBlock);
        }
    }


    private void Update()
    {

        UpdateMesh();
        UpdateGas();

    }

    private void UpdateMesh()
    {
        if(gasPositions.Length == 0)
        {
            return;
        }
        Bounds bounds = new Bounds();
        bounds.center = gasPositions.First().position;
        bounds.Encapsulate(gasPositions.First().position + (Vector3.one * gasPositions.First().radius));
        bounds.Encapsulate(gasPositions.First().position + (Vector3.one * gasPositions.First().radius * -1.0f));
        for (int i = 1; i < gasPositions.Length; i++)
        {
            var gas = gasPositions[i];
            bounds.Encapsulate(gas.position +( Vector3.one * gas.radius));
            bounds.Encapsulate(gas.position + (Vector3.one * gas.radius * -1.0f));
        }

        Vector3 boundPoint1 = bounds.min;
        Vector3 boundPoint2 = bounds.max;
        Vector3 boundPoint3 = new Vector3(boundPoint1.x, boundPoint1.y, boundPoint2.z);
        Vector3 boundPoint4 = new Vector3(boundPoint1.x, boundPoint2.y, boundPoint1.z);
        Vector3 boundPoint5 = new Vector3(boundPoint2.x, boundPoint1.y, boundPoint1.z);
        Vector3 boundPoint6 = new Vector3(boundPoint1.x, boundPoint2.y, boundPoint2.z);
        Vector3 boundPoint7 = new Vector3(boundPoint2.x, boundPoint1.y, boundPoint2.z);
        Vector3 boundPoint8 = new Vector3(boundPoint2.x, boundPoint2.y, boundPoint1.z);

        var mesh = new Mesh();
        Vector3[] vertices = new[] { boundPoint1, boundPoint2, boundPoint3, boundPoint4, boundPoint5, boundPoint6, boundPoint7, boundPoint8 };
        for (int i = 0; i < vertices.Length; i++)
        {
            vertices[i] = vertices[i] - transform.position;
        }
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
        gasMeshFilter.sharedMesh = mesh;
    }

}
