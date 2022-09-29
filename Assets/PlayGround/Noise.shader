Shader "Unlit/Noise"
{
    Properties
    {
        _baseMap ("baseMap", 2D) = "white" {}
        _scale("Scale",float)=1
        _tile("Tile",Range(1,1024))=5
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
            float _scale;
            float _tile;
            CBUFFER_END 


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

            float PsudoRandom(float2 xy){
                float2 pos=frac(xy/128.0f)*128.0f+float2(-64.340622f,-72.465622f);

                return frac(dot(pos.xyx*pos.xyy,float3(20.390625f,60.703125f,2.4281209f)));
            }

            float RandFast(uint2 PixelPos,float Magic=3571.0){
                float2 Random2=(1.0/4320.0)*PixelPos+float2(0.25,0.0);
                float Random=frac(dot(Random2*Random2,Magic));
                Random=frac(Random*Random*(2*Magic));
                return Random;
            }

            uint3  Rand3DPCG16(int3 p){
                uint3 v =uint3(p);

                v=v*1664525u+1013904223u;
                v.x+=v.y*v.z;
                v.y+=v.z*v.x;
                v.z+=v.x*v.y;
                v.x+=v.y*v.z;
                v.y+=v.z*v.x;
                v.z+=v.x*v.y;

                return v>>16u;
            }

            uint3 Rand3DPCG32(int3 p){
                uint3 v=(uint3)p;
                v=v*1664525u+1013904223u;
                v.x+=v.y*v.z;
                v.y+=v.z*v.x;
                v.z+=v.x*v.y;
                v^=v>>16u;
                v.x+=v.y*v.z;
                v.y+=v.z*v.x;
                v.z+=v.x*v.y;

                return v;
            }

            float Rand3dPCG16f2f1(float2 x){
                int2 ix=asint(x+65504);
                return (float)Rand3DPCG16(int3(ix.xy,ix.x*ix.y))/(float)0xffff;
            }

            float smoothlerp(float a,float b,float x){
                return lerp(a,b,3*x*x-2*x*x*x);
            }

            float ValueNoise(float2 uv,float tile){
                uint2 seed=floor(uv*tile);
                uint2 seed00=seed;
                uint2 seed01=seed+uint2(0,1);
                uint2 seed10=seed+uint2(1,0);
                uint2 seed11=seed+uint2(1,1);
                float rand00=RandFast(seed00);
                float rand01=RandFast(seed01);
                float rand10=RandFast(seed10);
                float rand11=RandFast(seed11);
                float2 tileduv=frac(uv*tile);
                float lerp1=lerp(rand00,rand01,tileduv.y);
                float lerp2=lerp(rand10,rand11,tileduv.y);
                return lerp(lerp1,lerp2,tileduv.x);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float randomresult=ValueNoise(i.uv,_tile);

				return float4(randomresult.xxx,1);
            }
            ENDHLSL
        }

        
    }
}
