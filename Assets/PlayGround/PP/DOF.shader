Shader "Unlit/DOF"
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
		float _DOFStrength,_DOFFocus,_DOFRange;
		float4 _MainTex_TexelSize;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		TEXTURE2D_X_FLOAT(_CameraDepthTexture);
		SAMPLER(sampler_CameraDepthTexture);

		struct a2v
		{
			float4 positionOS:POSITION;
			float2 texcoord:TEXCOORD;
		};

		struct v2f
		{
			float4 positionCS:SV_POSITION;
			float2 texcoord:TEXCOORD;
		};

		v2f vert(a2v i) {
			v2f o;
			o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
			o.texcoord = i.texcoord;
			return o;
		}

		half4 fragdualdown(v2f i) : SV_TARGET{
			float depth=SAMPLE_TEXTURE2D_X(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoord);
			float depthValue=Linear01Depth(depth,_ZBufferParams);
			float BlurRange=0;
			float FocusDistance=abs(depthValue-_DOFFocus);
			if(FocusDistance>_DOFRange){
				BlurRange=FocusDistance*_DOFStrength;
			}
			half4 col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*0.5f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, 1)*_MainTex_TexelSize*BlurRange)*0.125f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, 1)*_MainTex_TexelSize*BlurRange)*0.125f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, -1)*_MainTex_TexelSize*BlurRange)*0.125f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, -1)*_MainTex_TexelSize*BlurRange)*0.125f;
			return col;
		}

		half4 fragdualup(v2f i) : SV_TARGET{
			float depth=SAMPLE_TEXTURE2D_X(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoord);
			float depthValue=Linear01Depth(depth,_ZBufferParams);
			float BlurRange=0;
			float FocusDistance=abs(depthValue-_DOFFocus);
			if(FocusDistance>_DOFRange){
				BlurRange=FocusDistance*_DOFStrength;
			}
			half4 col = 0;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, 1)*_MainTex_TexelSize*BlurRange)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, 1)*_MainTex_TexelSize*BlurRange)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, -1)*_MainTex_TexelSize*BlurRange)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, -1)*_MainTex_TexelSize*BlurRange)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(2, 0)*_MainTex_TexelSize*BlurRange);
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-2, 0)*_MainTex_TexelSize*BlurRange);
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(0, 2)*_MainTex_TexelSize*BlurRange);
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(0, -2)*_MainTex_TexelSize*BlurRange);
			return col / 12;
		}
		ENDHLSL

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragdualdown
			ENDHLSL
		}

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragdualup
			ENDHLSL
		}

	}
}
