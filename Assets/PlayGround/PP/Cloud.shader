Shader "Unlit/Cloud"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Noise3D("_Noise",3D)="white"{}
	}
	SubShader
	{
		Tags { "RenderPipeline" = "UniversalRenderPipeline" }
		Cull Off ZWrite Off ZTest Always
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		float4 _MainTex_TexelSize,_CloudMin,_CloudMax;
		float4x4 _InverseProjectionMatrix,_InverseViewMatrix;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		TEXTURE3D(_Noise3D);
		SAMPLER(sampler_Noise3D);
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

		float4 GetWorldSpacePosition(float depth,float2 uv){
			float4 view_vector=mul(_InverseProjectionMatrix,float4(2.0*uv-1.0,depth,1.0));
			view_vector/=view_vector.w;
			//return float4(view_vector.xyz,1);
			float4 world_vector=mul(_InverseViewMatrix,float4(view_vector.xyz,1));
			return world_vector;
		}

		float cloudRayMarching(float3 startPoint,float3 direction,float maxDst){
			float3 testPoint = startPoint;
			float sumDensity=0;
			float raySetp=0.02;
			float dstTravelled = 0;
			direction*=raySetp;
			for(int i=0;i<64;i++){
				dstTravelled+=raySetp;
				if(dstTravelled<maxDst){
					testPoint+=direction;
					float d=SAMPLE_TEXTURE3D(_Noise3D,sampler_Noise3D,testPoint+_Time.y*0.2).r;
					sumDensity += 0.02*d;
					if(sumDensity>1){
						return 1;
					}
				}
			}
			return sumDensity;
		}

		//
		float2 rayBoxDst(float3 boundsMin,float3 boundsMax,float3 rayOrigin,float3 rayDir){
			float3 invRayDir=1/rayDir;

			float3 t0=(boundsMin-rayOrigin)*invRayDir;
			float3 t1=(boundsMax-rayOrigin)*invRayDir;
			float3 tmin=min(t0,t1);
			float3 tmax=max(t0,t1);

			float dstA=max(max(tmin.x,tmin.y),tmin.z);
			float dstB=min(min(tmax.x,tmax.y),tmax.z);

			float dstToBox=max(dstA,0);
			float dstInsideBox=max(0,dstB-dstToBox);
			return float2(dstToBox,dstInsideBox);

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
			return worldPos;
			
			//return d3;

			half4 col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			float3 rayPos=_WorldSpaceCameraPos;
			float3 worldDir=normalize(worldPos.xyz-rayPos);
			//return float4(-worldDir,1);

			float2 dst=rayBoxDst(_CloudMin,_CloudMax,rayPos,worldDir);
			float dstToBox=dst.x;
			float dstInside=dst.y;
			
			float depthEyeLinear=length(worldPos.xyz-_WorldSpaceCameraPos);
			float dstLimit=max(min(depthEyeLinear-dstToBox,dstInside),0);
			float3 entryPoint=rayPos+worldDir*dstToBox;

			float cloud=cloudRayMarching(entryPoint,worldDir,dstLimit);
			return lerp(col,1,cloud);

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
