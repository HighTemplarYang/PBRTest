Shader "Unlit/SSAO"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderPipeline" = "UniversalRenderPipeline" }
		Cull Off ZWrite Off ZTest Always
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		float4 _MainTex_TexelSize;
		float _RenderViewportScaleFactor;
		float4x4 _InverseProjectionMatrix,_InverseViewMatrix,_CustomProjectionMatrix,_CustomViewMatrix;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		TEXTURE2D_X_FLOAT(_CameraDepthTexture);
		SAMPLER(sampler_CameraDepthTexture);

		struct a2v
		{
			float4 positionOS:POSITION;
			float2 texcoord:TEXCOORD0;
		};

		struct v2f
		{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD0;
			float2 texcoordStereo:TEXCOORD1;
		};

		float4 GetWorldSpacePosition(float depth,float2 uv){
			float4 view_vector = mul(_InverseProjectionMatrix, float4(2.0 * uv - 1.0, depth, 1.0));
            view_vector.xyz /= view_vector.w;
            float4x4 l_matViewInv = _InverseViewMatrix;
            float4 world_vector = mul(l_matViewInv, float4(view_vector.xyz, 1));
            return world_vector;
		}

		float4 GetHClip(float4 world_vector){
			float4 view_vector=mul(_CustomViewMatrix,world_vector);
			float4 hclip_vector=mul(_CustomProjectionMatrix,view_vector);
			hclip_vector/=hclip_vector.w;
			return hclip_vector;
		}

		float3 rand(float3 co) {
				return frac(sin(co.xyz*float3(12.9898, 78.233, 53.539))*432758.5453);
		}

		v2f vert(a2v i) {
			v2f o;
			o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
			o.texcoord = i.texcoord;
			return o;
		}

		half4 frag(v2f i) : SV_TARGET{
			float depth=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoord);
			float4 worldPos=GetWorldSpacePosition(depth,i.texcoord);
			float3 tangent=normalize(ddx(worldPos));
			float3 bitangent=normalize(ddy(worldPos));
			float3 normal=normalize(cross(bitangent,tangent));
			float sum=0;
			float4 randPos=float4(rand(worldPos),0);
			float4 newWorldpos=0;
			float4 newHClip=0;
			float2 newuv;
			float newdepth=0;
			//return GetHClip(worldPos).z;
			//return depth;
			for(int j=0;j<20;j++){
				if(dot(randPos,normal)<0){
					randPos=-randPos;
				}
				newWorldpos=worldPos+randPos*0.1;
				newHClip=GetHClip(newWorldpos);
				newuv=newHClip.xy/2+0.5;
				//return newHClip.z;
				
				//return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,newuv);
				newdepth=SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,newuv);
				if(newdepth>newHClip.z+0.02){
					sum+=0.05;
				}
				randPos=float4(rand(randPos),0);
			}
			half4 col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			//return (1-sum);
			return lerp(col,0,sum);

		}
		ENDHLSL

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDHLSL
		}

	}
}
