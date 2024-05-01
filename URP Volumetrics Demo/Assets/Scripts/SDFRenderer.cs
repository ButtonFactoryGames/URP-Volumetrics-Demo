using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UIElements;


    [ExecuteAlways]
public class SDFRenderer : MonoBehaviour
{
    private Renderer m_Renderer;
    private MaterialPropertyBlock m_Props;

    [SerializeField] private Texture sdf;
    [SerializeField,HideInInspector] private Vector3 m_Size = Vector3.one;
    [SerializeField,HideInInspector] private int m_Resolution = 64;
    [SerializeField] private float scale;

    public Texture SDF { get { ValidateTexture(); return sdf; } set { sdf = value; } }
    public int Resolution { get { return m_Resolution; } set { m_Resolution = value; ValidateResolution(); } }

    // Max 3D texture resolution in any dimension is 2048
    private int kMaxResolution = 2048;
    // Max compute buffer size
    private int kMaxVoxelCount = 1024 * 1024 * 1024 / 2;
    void Update()
    {
        if (sdf == null)
            return;

        if (m_Renderer == null)
            m_Renderer = GetComponent<Renderer>();

        if (m_Props == null)
            m_Props = new MaterialPropertyBlock();


        m_Props.Clear();
        m_Props.SetTexture("_SDF", SDF);
        m_Props.SetMatrix("_WorldToSDF", worldToSDFTexCoords);
        m_Renderer.SetPropertyBlock(m_Props);
    }

    public enum Mode
    {
        None,
        Static,
        Dynamic
    }

    public Mode mode
    {
        get
        {
            if ((sdf as Texture3D) != null)
                return Mode.Static;

            RenderTexture rt = sdf as RenderTexture;
            if (rt != null && rt.dimension == TextureDimension.Tex3D)
                return Mode.Dynamic;

            return Mode.None;
        }
    }

    public Vector3Int voxelResolution
    {
        get
        {
            Texture3D tex3D = sdf as Texture3D;
            if (tex3D != null)
                return new Vector3Int(tex3D.width, tex3D.height, tex3D.depth);

            Vector3Int res = new Vector3Int();
            res.x = m_Resolution;
            res.y = (int)(m_Resolution * m_Size.y / m_Size.x);
            res.z = (int)(m_Resolution * m_Size.z / m_Size.x);
            res.y = Mathf.Clamp(res.y, 1, kMaxResolution);
            res.z = Mathf.Clamp(res.z, 1, kMaxResolution);
            return res;
        }
    }

    public Bounds voxelBounds
    {
        get
        {
            Vector3Int voxelRes = voxelResolution;
            if (voxelRes == Vector3Int.zero)
                return new Bounds(Vector3.zero, Vector3.zero);

            // voxelBounds is m_Size, but adjusted to be filled by uniformly scaled voxels
            // voxelResolution quantizes to integer counts, so we just need to multiply by voxelSize
            Vector3 extent = new Vector3(voxelRes.x, voxelRes.y, voxelRes.z) * voxelSize;
            return new Bounds(Vector3.zero, extent);
        }
    }

    public float voxelSize
    {
        get
        {
            if (mode == Mode.Dynamic)
                return m_Size.x / m_Resolution;

            int resX = voxelResolution.x;
            return resX != 0 ? 1f / (float)resX : 0f;
        }
    }

    public Matrix4x4 worldToSDFTexCoords
    {
        get
        {
            Vector3 scaleScaled = voxelBounds.size * scale;
            Matrix4x4 localToSDFLocal = Matrix4x4.Scale(new Vector3(1.0f / scaleScaled.x, 1.0f / scaleScaled.y, 1.0f / scaleScaled.z));
            Matrix4x4 worldToSDFLocal = localToSDFLocal * transform.worldToLocalMatrix;
            return Matrix4x4.Translate(Vector3.one * 0.5f) * worldToSDFLocal;
        }
    }

    public Matrix4x4 sdflocalToWorld
    {
        get
        {
            Vector3 scale = voxelBounds.size;
            return transform.localToWorldMatrix * Matrix4x4.Scale(scale);
        }
    }

    public int maxResolution
    {
        get
        {
            // res * (res * size.y / size.x) * (res * size.z / size.x) = voxel_count
            // res^3 = voxel_count * size.x * size.x / (size.y * size.z)
            int maxResolution = (int)(Mathf.Pow(kMaxVoxelCount * m_Size.x * m_Size.x / (m_Size.y * m_Size.z), 1.0f));
            return Mathf.Clamp(maxResolution, 1, kMaxResolution);
        }
    }

    void ValidateSize()
    {
        m_Size.x = Mathf.Max(m_Size.x, 0.001f);
        m_Size.y = Mathf.Max(m_Size.y, 0.001f);
        m_Size.z = Mathf.Max(m_Size.z, 0.001f);
    }


    void ValidateResolution()
    {
        m_Resolution = Mathf.Clamp(m_Resolution, 1, maxResolution);
    }

    void ValidateTexture()
    {
        if (mode == Mode.Static)
            return;

        RenderTexture rt = sdf as RenderTexture;
        if (rt == null)
            return;

        Vector3Int res = voxelResolution;
        bool serializedPropertyChanged = rt.depth != 0 || rt.width != res.x || rt.height != res.y || rt.volumeDepth != res.z || rt.format != RenderTextureFormat.RHalf || rt.dimension != TextureDimension.Tex3D;

        if (!rt.enableRandomWrite || serializedPropertyChanged)
        {
            rt.Release();
            if (serializedPropertyChanged)
            {
                rt.depth = 0;
                rt.width = res.x;
                rt.height = res.y;
                rt.volumeDepth = res.z;
                rt.format = RenderTextureFormat.RHalf;
                rt.dimension = TextureDimension.Tex3D;
            }

            // For some reason this flag gets lost (not serialized?), so we don't want to write and dirty other properties if just this doesn't match
            rt.enableRandomWrite = true;
            rt.Create();
        }

        if (rt.wrapMode != TextureWrapMode.Clamp)
            rt.wrapMode = TextureWrapMode.Clamp;

        if (!rt.IsCreated())
        {
            rt.Create();
        }
    }

    public void OnValidate()
    {
        ValidateSize();
        ValidateResolution();
        ValidateTexture();
        UpdateMesh();
    }


    private void UpdateMesh()
    {
        Texture3D tex3D = sdf as Texture3D;
        Renderer renderer = GetComponent<Renderer>();
        MeshFilter meshFilter = GetComponent<MeshFilter>();

        if (tex3D != null && renderer != null && meshFilter != null)
        {
            //var matrix = transform.localToWorldMatrix;
            var matrix = Matrix4x4.identity;
            matrix *= Matrix4x4.Translate(voxelBounds.center);

            Vector3 boundPoint1 = voxelBounds.min * scale;
            Vector3 boundPoint2 = voxelBounds.max * scale;
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
                vertices[i] = (Vector3)(matrix * vertices[i]);// + transform.position;
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
            meshFilter.sharedMesh = mesh;

        }
    }
}

//[CustomEditor(typeof(SDFRenderer))]
//public class SDFRendererEditor : Editor
//{
//    static SDFRenderer sdf;
//    void OnEnable()
//    {
//        sdf = (SDFRenderer)target;
//        UnityEditor.SceneView.duringSceneGui -= OnSceneGUI;
//        UnityEditor.SceneView.duringSceneGui += OnSceneGUI;
//    }

//    void OnDisable()
//    {
//        UnityEditor.SceneView.duringSceneGui -= OnSceneGUI;
//    }

//    static void OnSceneGUI(UnityEditor.SceneView sceneview)
//    {
//        Bounds voxelBounds = sdf.voxelBounds;
//        var matrix = sdf.transform.localToWorldMatrix;
//        matrix *= Matrix4x4.Translate(voxelBounds.center);

//        Handles.matrix = matrix;

//        // Helpers.DebugDrawSphere(sdf.transform.position, 1.0f, Color.red);

//        Handles.color = Color.white;
//        Handles.DrawWireCube(Vector3.zero, sdf.voxelBounds.size);
//    }
//}