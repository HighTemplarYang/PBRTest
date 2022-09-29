Shader "Unlit/FlowMap"
{
    Properties
    {
        _Speed("Speed",float) = 1
		_Amplitude("amplitude",float)=0.1
        _baseMap ("baseMap", 2D) = "white" {}
        _flowMap("flowMap",2D) = "white" {}
    }
    SubShader
    {
        Tags { "LightMode" = "UniversalForward" "RenderType" = "Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _Speed;
			float _Amplitude;
            CBUFFER_END 

            TEXTURE2D(_baseMap);
            TEXTURE2D(_flowMap);
            SAMPLER(sampler_baseMap);


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
				float2 flow = SAMPLE_TEXTURE2D(_flowMap,sampler_baseMap,i.uv*2);
				flow = flow * 2 - 1;
				flow *= _Amplitude;
				float schedule1 = abs(frac(_Time*_Speed)*2-1);
				float schedule2 = abs(frac(_Time*_Speed+0.5)*2-1);
				float prgoress1 = frac(_Time*_Speed);
				float prgoress2 = frac(_Time*_Speed+0.5);
				float4 baseColor1 = SAMPLE_TEXTURE2D(_baseMap, sampler_baseMap, i.uv + flow * prgoress1);
				float4 baseColor2 = SAMPLE_TEXTURE2D(_baseMap, sampler_baseMap, i.uv+float2(0.5,0) + flow * prgoress2);	
                
				return baseColor1* schedule2+ baseColor2* schedule1;
            }
            ENDHLSL
        }

        
    }
}
