using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteInEditMode] // �ñ༭���ڲ�����״̬������
public class Kawase : ScriptableRendererFeature
{
    [System.Serializable]   // renderfeature �����
    public class featureSetting
    {
        public string passRenderName = "KawaseBlur";
        public Material passMat;
        [Range(1, 10)] public int downsample = 1;
        [Range(1, 10)] public int loop = 2;
        [Range(0.5f, 5)] public float blur = 0.5f;
        [Range(0, 1)] public float lerp = 1;    // �Ա�processǰ������
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;  // copy�����ĸ��׶ε�ͼ��
    }
    public featureSetting setting = new featureSetting();  // ʵ����
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public string passName;
        public int passdownsample = 1;
        public int passloop = 2;
        public float passblur = 4;
        public float lerp = 1;
        string passTag; // ���֣������frameDebug�￴��
        private RenderTargetIdentifier passSource { get; set; } // Դͼ��

        public void setup(RenderTargetIdentifier sour) // �������ͼ��copy��������������ȡ����renderEvent
        {
            this.passSource = sour;
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // ����shaderGUI��Ĵ��ݣ�����Ͳ���setfloat�ˣ�������shaderProperty��ID��,��Ϊ����Ҫ��id������ʱͼ��
            int TempID1 = Shader.PropertyToID("Temp1");         // ��ʱͼ��Ҳ������ Handle��ID���ҾͿ���
            int TempID2 = Shader.PropertyToID("Temp2");
            int Lerp = Shader.PropertyToID("_Lerp");
            int ScoureID = Shader.PropertyToID("_SourceTex");   // Ϊ�˷���Ա�prossesǰ�������

            CommandBuffer cmd = CommandBufferPool.Get(passTag); // ������cbuffer����������Ⱦ����Ȧ����
            RenderTextureDescriptor getCameraData = renderingData.cameraData.cameraTargetDescriptor;   // �õ�������ݣ����㴴��������Ե�rt
            int width = getCameraData.width / passdownsample; //downSample
            int height = getCameraData.height / passdownsample;

            // ��ȡ��ʱ��Ⱦ���� ע��hdr��֧��
            cmd.GetTemporaryRT(TempID1, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR); //����һ����ʱͼ�񣬲��������rt�Ĳ�����ȥ
            cmd.GetTemporaryRT(TempID2, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);
            cmd.GetTemporaryRT(ScoureID, getCameraData);

            RenderTargetIdentifier Temp1 = TempID1;
            RenderTargetIdentifier Temp2 = TempID2;
            RenderTargetIdentifier Scoure = ScoureID;

            // ���ò���
            cmd.SetGlobalFloat("_Blur", 1f);
            cmd.SetGlobalFloat(Lerp, lerp);
            // ����
            cmd.Blit(passSource, Scoure);           // ��ԭʼͼ���������lerp�������Ա�ǰ��仯
            cmd.ReleaseTemporaryRT(ScoureID);       // �ͷ� RT 
            cmd.Blit(passSource, Temp1, passMat);   // ��Դ��ͼ���뵽���ʶ�Ӧ��pass�ﴦ�����Ѵ�������ͼ��洢����ʱͼ��
            for (int t = 1; t < passloop; t++)      // ÿ��ѭ���൱�ڰ��Ѿ�ģ����ͼƬ�Ž�������ģ������
            {
                cmd.SetGlobalFloat("_Blur", t * passblur); // 1.5
                cmd.Blit(Temp1, Temp2, passMat);
                var temRT = Temp1;
                Temp1 = Temp2;
                Temp2 = temRT;
            }
            // cmd.SetGlobalFloat("_Blur", passloop * passblur); // �����൱����loop����ģ��һ�Σ�������ֱ�ӵ� passloop �Ĳ���
            // cmd.Blit(Temp1, passSource, passMat);
            cmd.Blit(Temp1, passSource);

            // �ͷ�
            cmd.ReleaseTemporaryRT(TempID1);    // ����������������ͷŵĻ��ͻ�һֱ���У���Ӱ�� passSource �� Tex ͼ��
            cmd.ReleaseTemporaryRT(TempID2);
            context.ExecuteCommandBuffer(cmd);  //ִ����������ĸ�����
            CommandBufferPool.Release(cmd);     //�ͷŸ�����
        }
    }
    CustomRenderPass m_ScriptablePass;
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.passEvent;   // ��Ⱦλ��
        m_ScriptablePass.passMat = setting.passMat;             // ����
        m_ScriptablePass.passName = setting.passRenderName;     // ��Ⱦ����
        m_ScriptablePass.passblur = setting.blur;               // ����
        m_ScriptablePass.passloop = setting.loop;
        m_ScriptablePass.passdownsample = setting.downsample;
        m_ScriptablePass.lerp = setting.lerp;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.setup(renderer.cameraColorTarget);     // ͨ��setup�������ò�ͬ����Ⱦ�׶ε���Ⱦ����� passSource ����
        renderer.EnqueuePass(m_ScriptablePass);                 // ִ��
    }
}