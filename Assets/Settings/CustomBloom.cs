using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode]
public class CustomBloom : ScriptableRendererFeature
{
    [System.Serializable]
    public class bloomSetting
    {
        public string passRenderName = "Bloom";
        public Material passMat;
        [Range(1, 10)] public int downsample = 1;
        [Range(1, 10)] public int loop = 2;
        [Range(0.5f, 5)] public float blur = 0.5f;
        [Range(0, 1)] public float brightness = 0.8f;
        [Range(0, 5)] public float bloomStrengh = 1;
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    public bloomSetting setting = new bloomSetting();

    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public string passName;
        public int passdownsample = 1;
        public int passloop = 2;
        public float passblur = 4;
        public float passstrength;
        public float brightness = 0.8f;
        string passTag;
        private RenderTargetIdentifier passSource { get; set; }

        public void setup(RenderTargetIdentifier sour) // 把相机的图像copy过来，具体哪张取决于renderEvent
        {
            this.passSource = sour;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int TempID1 = Shader.PropertyToID("Temp1");
            int TempID2 = Shader.PropertyToID("Temp2");
            int Brightness = Shader.PropertyToID("_Brightness");
            int ScoureID = Shader.PropertyToID("_SourceTex");

            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            RenderTextureDescriptor getCameraData = renderingData.cameraData.cameraTargetDescriptor;

            int width = getCameraData.width / passdownsample;
            int height = getCameraData.height / passdownsample;

            cmd.GetTemporaryRT(TempID1, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(TempID2, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(ScoureID, getCameraData);

            RenderTargetIdentifier Temp1 = TempID1;
            RenderTargetIdentifier Temp2 = TempID2;
            RenderTargetIdentifier Scoure = ScoureID;

            cmd.SetGlobalFloat("_BloomBlur", passblur);
            cmd.SetGlobalFloat(Brightness, brightness);
            cmd.SetGlobalFloat("_BloomStrength", passstrength);

            cmd.Blit(passSource, Scoure);
            //cmd.ReleaseTemporaryRT(ScoureID);
            cmd.Blit(passSource, Temp1, passMat,0);
            for(int t = 1; t < passloop; t++)
            {
                cmd.Blit(Temp1, Temp2, passMat, 1);
                cmd.Blit(Temp2, Temp1, passMat, 2);
            }
            cmd.SetGlobalTexture("_BloomSource", Scoure);
            cmd.Blit(Temp1, passSource, passMat, 3);
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
        m_ScriptablePass.passblur = setting.blur;
        m_ScriptablePass.passloop = setting.loop;
        m_ScriptablePass.passstrength = setting.bloomStrengh;
        m_ScriptablePass.passdownsample = setting.downsample;
        m_ScriptablePass.brightness = setting.brightness;
    }

    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


