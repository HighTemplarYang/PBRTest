Shader "Unlit/InteriorMapping"
{
    Properties
    {
        _Depth("Depth",Range(0,1)) = 1
        _baseMap ("baseMap", 2D) = "white" {}
        _width("Width",Range(0,10))=1
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
            float _width;
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
                float3 objectPosition:TEXCOORD5;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPosition=TransformObjectToWorld(v.vertex);
                o.tangent=v.tangent;
                o.normal=v.normal;
                o.uv = v.uv;
                o.objectPosition=-v.vertex;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 V=normalize(_WorldSpaceCameraPos-i.worldPosition);
                V=normalize(TransformWorldToObjectDir(V));
                //return float4(V/2+0.5f,1);
                float width=_width;
                //return float4(i.objectPosition,1);
                float tx1=(width-i.objectPosition.x)/V.x;
                float tx2=-(width+i.objectPosition.x)/V.x;
                float tz1=(width-i.objectPosition.z)/V.z;
                float tz2=-(width+i.objectPosition.z)/V.z;
                float ty=width/V.y;
                bool leftright=tx1>0;
                bool updown=tz1>0;
                float tx = tx1>0?tx1:tx2;
                float tz = tz1>0?tz1:tz2;

                float tout=min(tx,tz);
                tout=min(tout,ty);

                if(ty<tx&&ty<tz){
                    return float4(1,0,0,1);
                }
                if(tx<tz){
                    return float4(0,1,0,1);
                }
                return float4(0,0,1,1);

				float4 baseColor = SAMPLE_TEXTURE2D(_baseMap, sampler_baseMap, i.uv+V.xy/V.z*-_Depth);
                
				return baseColor;
            }
            ENDHLSL
        }

        
    }
}
