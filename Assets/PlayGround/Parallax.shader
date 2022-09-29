Shader "Unlit/Parallax"
{
    Properties
    {
        _Depth("Depth",Range(0,1)) = 1
        _baseMap ("baseMap", 2D) = "white" {}
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
            float _Depth;
            CBUFFER_END 

            TEXTURE2D(_baseMap);
            SAMPLER(sampler_baseMap);


            struct appdata
            {
                float4 vertex : POSITION;
                float4 tangent:TANGENT;
                float3 normal :NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPosition:TEXCOORD1;
                float3 normal :TEXCOORD2;
                float4 tangent:TEXCOORD3;
                float3 bitangent:TEXCOORD4;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPosition=TransformObjectToWorld(v.vertex);
                o.tangent=v.tangent;
                o.normal=v.normal;
                o.uv = v.uv;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 V=normalize(_WorldSpaceCameraPos-i.worldPosition);
                //return float4(V/2+0.5f,1);
                float3 worldNormal=TransformObjectToWorldNormal(i.normal);
                //return float4(worldNormal/2+0.5f,1);
                float3 worldTangent=TransformObjectToWorldDir(i.tangent);
                //return float4(worldTangent/2+0.5f,1);
                float3 worldBitangent=cross(worldNormal,worldTangent)*i.tangent.w;
                //return float4(worldBitangent/2+0.5f,1);
                float3x3 TBN = float3x3(normalize(worldTangent),normalize(worldBitangent),normalize(worldNormal));
                TBN=transpose(TBN);
                V=normalize(mul(V,TBN));
                //return float4(V/2+0.5f,1);
				float4 baseColor = SAMPLE_TEXTURE2D(_baseMap, sampler_baseMap, i.uv+V.xy/V.z*-_Depth);
                
				return baseColor;
            }
            ENDHLSL
        }

        
    }
}
