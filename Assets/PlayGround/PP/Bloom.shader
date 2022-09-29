Shader "Unlit/Bloom"
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
		float _BloomBlur,_Brightness,_BloomStrength;
		float4 _MainTex_TexelSize;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		TEXTURE2D(_BloomSource);
		SAMPLER(sampler_BloomSource);

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

		half4 fragpick(v2f i) :SV_TARGET{
			half4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			half bright = max(col.r, col.g);
			bright = max(col.b, bright);
			if (bright > _Brightness) {
				return col;
			}
			else {
				return 0;
			}
			
		}

		half4 fragdualdown(v2f i) : SV_TARGET{
			half4 col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*0.5f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, 1)*_MainTex_TexelSize*_BloomBlur)*0.125f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, 1)*_MainTex_TexelSize*_BloomBlur)*0.125f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, -1)*_MainTex_TexelSize*_BloomBlur)*0.125f;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, -1)*_MainTex_TexelSize*_BloomBlur)*0.125f;
			return col;
		}

		half4 fragdualup(v2f i) : SV_TARGET{
			half4 col = 0;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, 1)*_MainTex_TexelSize*_BloomBlur)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, 1)*_MainTex_TexelSize*_BloomBlur)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(1, -1)*_MainTex_TexelSize*_BloomBlur)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-1, -1)*_MainTex_TexelSize*_BloomBlur)*2;
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(2, 0)*_MainTex_TexelSize*_BloomBlur);
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(-2, 0)*_MainTex_TexelSize*_BloomBlur);
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(0, 2)*_MainTex_TexelSize*_BloomBlur);
			col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + float2(0, -2)*_MainTex_TexelSize*_BloomBlur);
			return col / 12;
		}

		half4 fragmix(v2f i) :SV_TARGET{
			half4 col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			return col* _BloomStrength + SAMPLE_TEXTURE2D(_BloomSource, sampler_BloomSource, i.texcoord);
		}
		ENDHLSL


		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragpick
			ENDHLSL
		}
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

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragmix
			ENDHLSL
		}
	}
}
