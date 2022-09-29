using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class DOF : ScriptableRendererFeature
{
    [System.Serializable]
    public class DOFSetting
    {
        public string passRenderName = "DOF";
        public Material passMat;
        [Range(0, 10)] public float DOFStrength = 1;
        [Range(0, 1)] public float DOFFocus = 0.5f;
        [Range(0, 1)] public float DOFRange = 0.1f;
        [Range(0, 10)] public int DOFLoop = 2;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    public DOFSetting setting = new DOFSetting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public string passName;
        public float DOFStrength = 1;
        public float DOFFocus = 0.5f;
        public float DOFRange = 0.1f;
        public int DOFLoop = 2;
        string passTag;
        private RenderTargetIdentifier passSource { get; set; }

        public void setup(RenderTargetIdentifier sour)
        {
            this.passSource = sour;
        }

        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int TempID1 = Shader.PropertyToID("Temp1");
            int TempID2 = Shader.PropertyToID("Temp2");
            int ScoureID = Shader.PropertyToID("_SourceTex");

            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            RenderTextureDescriptor getCameraData = renderingData.cameraData.cameraTargetDescriptor;
            int width = getCameraData.width;
            int height = getCameraData.height;

            cmd.GetTemporaryRT(TempID1, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(TempID2, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(ScoureID, getCameraData);

            RenderTargetIdentifier Temp1 = TempID1;
            RenderTargetIdentifier Temp2 = TempID2;
            RenderTargetIdentifier Scoure = ScoureID;

            cmd.SetGlobalFloat("_DOFStrength", DOFStrength);
            cmd.SetGlobalFloat("_DOFFocus", DOFFocus);
            cmd.SetGlobalFloat("_DOFRange", DOFRange);

            cmd.Blit(passSource, Scoure);
            cmd.Blit(passSource, Temp1, passMat, 0);
            for(int i = 1; i < DOFLoop; i++)
            {
                cmd.Blit(Temp1, Temp2, passMat, 1);
                cmd.Blit(Temp2, Temp1, passMat, 0);
            }
            cmd.Blit(Temp1, passSource, passMat, 1);
            cmd.ReleaseTemporaryRT(TempID1);
            cmd.ReleaseTemporaryRT(TempID2);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.passEvent;
        m_ScriptablePass.passMat = setting.passMat;
        m_ScriptablePass.passName = setting.passRenderName;
        m_ScriptablePass.DOFStrength = setting.DOFStrength;
        m_ScriptablePass.DOFFocus = setting.DOFFocus;
        m_ScriptablePass.DOFRange = setting.DOFRange;
        m_ScriptablePass.DOFLoop = setting.DOFLoop;
    }

    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


