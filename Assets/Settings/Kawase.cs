using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode] // 让编辑器在不运行状态下运行
public class Kawase : ScriptableRendererFeature
{
    [System.Serializable]   // renderfeature 的面板
    public class featureSetting
    {
        public string passRenderName = "KawaseBlur";
        public Material passMat;
        [Range(1, 10)] public int downsample = 1;
        [Range(1, 10)] public int loop = 2;
        [Range(0.5f, 5)] public float blur = 0.5f;
        [Range(0, 1)] public float lerp = 1;    // 对比process前后区别
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;  // copy具体哪个阶段的图像
    }
    public featureSetting setting = new featureSetting();  // 实例化
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public string passName;
        public int passdownsample = 1;
        public int passloop = 2;
        public float passblur = 4;
        public float lerp = 1;
        string passTag; // 名字，方便从frameDebug里看到
        private RenderTargetIdentifier passSource { get; set; } // 源图像

        public void setup(RenderTargetIdentifier sour) // 把相机的图像copy过来，具体哪张取决于renderEvent
        {
            this.passSource = sour;
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 类似shaderGUI里的传递，这里就不是setfloat了，就是拿shaderProperty的ID了,因为下面要用id创建临时图像
            int TempID1 = Shader.PropertyToID("Temp1");         // 临时图像，也可以用 Handle，ID不乱就可以
            int TempID2 = Shader.PropertyToID("Temp2");
            int Lerp = Shader.PropertyToID("_Lerp");
            int ScoureID = Shader.PropertyToID("_SourceTex");   // 为了方便对比prosses前后的区别

            CommandBuffer cmd = CommandBufferPool.Get(passTag); // 类似于cbuffer，把整个渲染命令圈起来
            RenderTextureDescriptor getCameraData = renderingData.cameraData.cameraTargetDescriptor;   // 拿到相机数据，方便创建共享屬性的rt
            int width = getCameraData.width / passdownsample; //downSample
            int height = getCameraData.height / passdownsample;

            // 获取临时渲染纹理 注意hdr的支持
            cmd.GetTemporaryRT(TempID1, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR); //申请一个临时图像，并设置相机rt的参数进去
            cmd.GetTemporaryRT(TempID2, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(ScoureID, getCameraData);

            RenderTargetIdentifier Temp1 = TempID1;
            RenderTargetIdentifier Temp2 = TempID2;
            RenderTargetIdentifier Scoure = ScoureID;

            // 设置参数
            cmd.SetGlobalFloat("_Blur", 1f);
            cmd.SetGlobalFloat(Lerp, lerp);
            // 拷贝
            cmd.Blit(passSource, Scoure);           // 把原始图像存起来做lerp操作，对比前后变化
            cmd.ReleaseTemporaryRT(ScoureID);       // 释放 RT 
            cmd.Blit(passSource, Temp1, passMat);   // 把源贴图输入到材质对应的pass里处理，并把处理结果的图像存储到临时图像；
            for (int t = 1; t < passloop; t++)      // 每次循环相当于把已经模糊的图片放进来进行模糊运算
            {
                cmd.SetGlobalFloat("_Blur", t * passblur); // 1.5
                cmd.Blit(Temp1, Temp2, passMat);
                var temRT = Temp1;
                Temp1 = Temp2;
                Temp2 = temRT;
            }
            // cmd.SetGlobalFloat("_Blur", passloop * passblur); // 这里相当于在loop外又模糊一次，还不如直接调 passloop 的参数
            // cmd.Blit(Temp1, passSource, passMat);
            cmd.Blit(Temp1, passSource);

            // 释放
            cmd.ReleaseTemporaryRT(TempID1);    // 看起来好像如果不释放的话就会一直运行，会影响 passSource 的 Tex 图像
            cmd.ReleaseTemporaryRT(TempID2);
            context.ExecuteCommandBuffer(cmd);  //执行命令缓冲区的该命令
            CommandBufferPool.Release(cmd);     //释放该命令
        }
    }
    CustomRenderPass m_ScriptablePass;
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.passEvent;   // 渲染位置
        m_ScriptablePass.passMat = setting.passMat;             // 材质
        m_ScriptablePass.passName = setting.passRenderName;     // 渲染名称
        m_ScriptablePass.passblur = setting.blur;               // 变量
        m_ScriptablePass.passloop = setting.loop;
        m_ScriptablePass.passdownsample = setting.downsample;
        m_ScriptablePass.lerp = setting.lerp;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setup(renderer.cameraColorTarget);     // 通过setup函数设置不同的渲染阶段的渲染结果进 passSource 里面
        renderer.EnqueuePass(m_ScriptablePass);                 // 执行
    }
}