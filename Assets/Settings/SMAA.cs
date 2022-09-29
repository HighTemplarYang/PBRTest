using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class SMAA : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public string passRenderName = "MSAA";
        public Material passMat;
        [Range(0, 1)] public float threshold = 1;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    public Setting setting = new Setting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public string passName;
        public float threshold = 0.8f;
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

            cmd.GetTemporaryRT(TempID1, getCameraData.width, getCameraData.height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(TempID2, getCameraData.width, getCameraData.height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(ScoureID, getCameraData.width, getCameraData.height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);

            RenderTargetIdentifier Temp1 = TempID1;
            RenderTargetIdentifier Temp2 = TempID2;
            RenderTargetIdentifier Scoure = ScoureID;

            cmd.SetGlobalFloat("_Threshold", threshold);

            cmd.Blit(passSource, Scoure);
            cmd.Blit(passSource, Temp1, passMat,0);
            cmd.Blit(Temp1, Temp2, passMat,1);
            //cmd.Blit(Temp2, passSource);
            cmd.SetGlobalTexture("_BlendTex", Temp2);
            cmd.Blit(Scoure, Temp1, passMat, 2);
            cmd.Blit(Temp1, passSource);
            cmd.ReleaseTemporaryRT(TempID1);   
            cmd.ReleaseTemporaryRT(TempID2);   
            context.ExecuteCommandBuffer(cmd);  
            CommandBufferPool.Release(cmd);
        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.passEvent;
        m_ScriptablePass.passMat = setting.passMat;
        m_ScriptablePass.passName = setting.passRenderName;
        m_ScriptablePass.threshold = setting.threshold;
    }

    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


