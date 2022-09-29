Shader "Unlit/FXAA"
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
		float _MinThreshold,_Threshold;
		float4 _MainTex_TexelSize;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);

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

		float get_L(half4 col){
			return dot(col,(0.213,0.715,0.072));
		}
		

		half4 frag(v2f i) :SV_TARGET{
			//采样
			half4 Mcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			half4 Ncol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(0, 1)*_MainTex_TexelSize);
			half4 Scol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(0, -1)*_MainTex_TexelSize);
			half4 Wcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(-1, 0)*_MainTex_TexelSize);
			half4 Ecol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(1, 0)*_MainTex_TexelSize);
			half4 NWcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(1, 1)*_MainTex_TexelSize);
			half4 NEcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(-1, 1)*_MainTex_TexelSize);
			half4 SWcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(-1, -1)*_MainTex_TexelSize);
			half4 SEcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(1, -1)*_MainTex_TexelSize);

			//计算亮度
			float M=get_L(Mcol);
			float N=get_L(Ncol);
			float S=get_L(Scol);
			float W=get_L(Wcol);
			float E=get_L(Ecol);
			float NW=get_L(NWcol);
			float NE=get_L(NEcol);
			float SW=get_L(SWcol);
			float SE=get_L(SEcol);

			//计算对比度
			float MaxLuma=max(S,max(M,max(W,max(N,E))));
			float MinLuma=min(S,min(M,min(W,min(N,E))));

			float Constrast=MaxLuma-MinLuma;
			//如果对比度同时大于预设值和预设比例则进行抗锯齿计算
			if(Constrast>=max(_MinThreshold,MaxLuma*_Threshold)){
				//计算混合比例
				float Filter = 2*(N+E+S+W)+NE+NW+SE+SW;
				Filter = Filter/12;
				Filter = abs(Filter-M);
				Filter = saturate(Filter/Constrast);
				float PixelBlend=smoothstep(0,1,Filter);
				//计算混合方向
				float Vertical = abs(N+S-2*M)*2+abs(NE+SE-2*E)+abs(NW+SW-2*W);
				float Horizontal = abs(E+W-2*M)*2+abs(NE+NW-2*N)+abs(SE+SW-2*S);
				bool IsHorizontal=Vertical>Horizontal;
				float2 PixelStep=(IsHorizontal?float2(0,1):float2(1,0))*_MainTex_TexelSize;
				float Positive=abs((IsHorizontal?N:E)-M);
				float Negative=abs((IsHorizontal?S:W)-M);
				float Gradient,OppositeLuminance;
				if(Positive>Negative)
				{
					Gradient=Positive;
					//为边界另一侧的亮度
					OppositeLuminance=IsHorizontal?N:E;
				}else{
					PixelStep=-PixelStep;
					Gradient=Negative;
					OppositeLuminance=IsHorizontal?S:W;
				}
				//取边界的UV
				float2 UVEdge=i.texcoord;
				UVEdge+=PixelStep*0.5f;
				//取边界搜索的步长
				float2 EdgeStep=IsHorizontal?float2(1,0):float2(0,1)*_MainTex_TexelSize;
				//取边界的亮度
				float EdgeLuminance=(M+OppositeLuminance)*0.5f;
				//设置梯度的临界值，搜索时超过临界值则认为到达了边界的边界
				float GradientThreshold=EdgeLuminance*0.25f;


				//循环搜索
				float PLuminanceDelta,NLuminanceDelta,PDistance,NDistance;
				int j;
				for(j=0;j<=10;j++){
					PLuminanceDelta=get_L(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+j*EdgeStep))-EdgeLuminance;
					if(abs(PLuminanceDelta)>GradientThreshold){
						PDistance=j*(IsHorizontal?EdgeStep.x:EdgeStep.y);
						break;
					}
				}
				if(j==11){
					PDistance=(IsHorizontal?EdgeStep.x:EdgeStep.y)*8;
				}

				for(j=0;j<=10;j++){
					NLuminanceDelta=get_L(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord-j*EdgeStep))-EdgeLuminance;
					if(abs(NLuminanceDelta)>GradientThreshold){
						NDistance=j*(IsHorizontal?EdgeStep.x:EdgeStep.y);
						break;
					}
				}
				if(j==11){
					NDistance=(IsHorizontal?EdgeStep.x:EdgeStep.y)*8;
				}

				//计算混合比例，如果该像素边界距离更近的一侧的边界像素与该像素同边界方向，则边界不会穿过该像素，则不需要做混合
				float EdgeBlend;
				if(PDistance<NDistance){
					if(sign(PLuminanceDelta)==sign(M-EdgeLuminance)){
						EdgeBlend=0;
					}else{
						//根据像素距更近的边界的距离和边界长度的比值计算混合系数
						EdgeBlend=0.5-PDistance/(PDistance+NDistance);
					}
				}else{
					if(sign(NLuminanceDelta)==sign(M-EdgeLuminance)){
						EdgeBlend=0;
					}else{
						//根据像素距更近的边界的距离和边界长度的比值计算混合系数
						EdgeBlend=0.5-NDistance/(PDistance+NDistance);
					}
				}

				float FinalBlend=max(PixelBlend,EdgeBlend);
				
				return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+PixelStep*FinalBlend);
			}
			return Mcol;
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
