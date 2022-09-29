using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RemapWorld : ScriptableRendererFeature
{
    public Material passMat;

    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        string passTag;
        private RenderTargetIdentifier passSource { get; set; }

        public void setup(RenderTargetIdentifier sour)
        {
            this.passSource = sour;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            int TempID1 = Shader.PropertyToID("Temp1");
            int ScoureID = Shader.PropertyToID("_SourceTex");

            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            RenderTextureDescriptor getCameraData = renderingData.cameraData.cameraTargetDescriptor;
            int width = getCameraData.width;
            int height = getCameraData.height;

            cmd.GetTemporaryRT(TempID1, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(ScoureID, getCameraData);
            Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(renderingData.cameraData.GetProjectionMatrix(), false);
            cmd.SetGlobalMatrix("_InverseProjectionMatrix", projectionMatrix.inverse);
            cmd.SetGlobalMatrix("_InverseViewMatrix", renderingData.cameraData.GetViewMatrix().inverse);
            cmd.SetGlobalMatrix("_CustomProjectionMatrix", projectionMatrix);
            cmd.SetGlobalMatrix("_CustomViewMatrix", renderingData.cameraData.GetViewMatrix());
            RenderTargetIdentifier Temp1 = TempID1;
            RenderTargetIdentifier Scoure = ScoureID;
            cmd.Blit(passSource, Scoure);
            cmd.Blit(passSource, Temp1, passMat);
            cmd.Blit(Temp1, passSource);
            cmd.ReleaseTemporaryRT(TempID1);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }


    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.passMat = passMat;
        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


