Shader "Unlit/SMAA"
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
		#define MAXSTEPS 10

		CBUFFER_START(UnityPerMaterial)
		float _Threshold;
		float4 _MainTex_TexelSize;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		TEXTURE2D(_BlendTex);
		SAMPLER(sampler_MainTex);
		SAMPLER(sampler_BlendTex);

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
		

		half4 fragedge(v2f i) :SV_TARGET{
			//采样
			half4 Mcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			half4 Lcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(-1, 0)*_MainTex_TexelSize);
			half4 L2col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(-2, 0)*_MainTex_TexelSize);
			half4 Rcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(1, 0)*_MainTex_TexelSize);
			half4 Tcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(0, -1)*_MainTex_TexelSize);
			half4 T2col= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(0, -2)*_MainTex_TexelSize);
			half4 Bcol= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+ float2(0, 1)*_MainTex_TexelSize);

			half M=get_L(Mcol);
			half L=abs(get_L(Lcol)-M);
			half T=abs(get_L(Tcol)-M);
			half R=abs(get_L(Rcol)-M);
			half L2=abs(get_L(L2col)-M);
			half T2=abs(get_L(T2col)-M);
			half B=abs(get_L(Bcol)-M);

			float CMAX = max(max(L,R),max(B,T));

			//边界条件除了需要大于临界值以外还需要在周围的变化中足够大
			bool EL = L>_Threshold;
			EL=EL&&L>(max(CMAX,L2)*0.5f);
			

			bool ET = T>_Threshold;
			ET=ET&&T>(max(CMAX,T2)*0.5f);


			//确定边界,只考虑左上是否是边界
			return float4(EL ? 1 : 0, ET ? 1 : 0, 0, 0);
		}

		float SearchLeft(float2 coord){
			coord -= float2(1.5f,0);
			float e=0;
			int i=0;
			UNITY_UNROLL
			for(;i<MAXSTEPS;i++){
				e= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,coord*_MainTex_TexelSize).g;
				[flatten]
				if(e<0.9f)
					break;
				coord-=float2(2,0);
			}

			return min(2.0*(i+e),2.0*MAXSTEPS);
		}

		float SearchRight(float2 coord){
			coord += float2(1.5f,0);
			float e=0;
			int i=0;
			UNITY_UNROLL
			for(;i<MAXSTEPS;i++){
				e= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,coord*_MainTex_TexelSize).g;
				[flatten]
				if(e<0.9f)
					break;
				coord+=float2(2,0);
			}

			return min(2.0*(i+e),2.0*MAXSTEPS);
		}

		float SearchUp(float2 coord){
			coord -= float2(0,1.5f);
			float e=0;
			int i=0;
			UNITY_UNROLL
			for(;i<MAXSTEPS;i++){
				e= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,coord*_MainTex_TexelSize).g;
				[flatten]
				if(e<0.9f)
					break;
				coord-=float2(0,2);
			}

			return min(2.0*(i+e),2.0*MAXSTEPS);
		}

		float SearchDown(float2 coord){
			coord += float2(0,1.5f);
			float e=0;
			int i=0;
			UNITY_UNROLL
			for(;i<MAXSTEPS;i++){
				e= SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,coord*_MainTex_TexelSize).g;
				[flatten]
				if(e<0.9f)
					break;
				coord+=float2(0,2);
			}

			return min(2.0*(i+e),2.0*MAXSTEPS);
		}

		//判断边界模式
		bool4 ModeOfSingle(float value){
			bool4 ret=false;
			if(value>0.875f)
				ret.yz=bool2(true,true);
			else if(value>0.5)
				ret.z=true;
			else if(value>0.125)
			    ret.y= true;
			return ret;
		}

		bool4 ModeOfDouble(float value1,float value2){
			bool4 ret;
			ret.xy=ModeOfSingle(value1).yz;
			ret.zw=ModeOfSingle(value2).yz;
			return ret;
		}

		//  单侧L型, 另一侧没有, d表示总间隔, m表示像素中心距边缘距离
        //  |____
        // 
        float L_N_Shape(float d, float m)
        {
            float l = d * 0.5;
            float s = 0;
            [flatten]
            if ( l > (m + 0.5))
            {
                // 梯形面积, 宽为1
                s = (l - m) * 0.5 / l;
            }
            else if (l > (m - 0.5))
            {
                   // 三角形面积, a是宽, b是高
                float a = l - m + 0.5;
                // float b = a * 0.5 / l;
                // float s = a * b * 0.5;
                s = a * a * 0.25 * rcp(l);
            }
            return s;
        }

        //  双侧L型, 且方向相同
        //  |____|
        // 
        float L_L_S_Shape(float d1, float d2)
        {
            float d = d1 + d2;
            float s1 = L_N_Shape(d, d1);
            float s2 = L_N_Shape(d, d2);
            return s1 + s2;
        }

        //  双侧L型/或一侧L, 一侧T, 且方向不同, 这里假设左侧向上, 来取正负
        //  |____    |___|    
        //       |       |
        float L_L_D_Shape(float d1, float d2)
        {
            float d = d1 + d2;
            float s1 = L_N_Shape(d, d1);
            float s2 = -L_N_Shape(d, d2);
            return s1 + s2;
        }

        float Area(float2 d, bool4 left, bool4 right)
        {
            // result为正, 表示将该像素点颜色扩散至上/左侧; result为负, 表示将上/左侧颜色扩散至该像素
            float result = 0;
            [branch]
            if(!left.y && !left.z)
            {
                [branch]
                if(right.y && !right.z)
                {
                    result = L_N_Shape(d.y + d.x + 1, d.y + 0.5);
                }
                else if (!right.y && right.z)
                {
                    result = -L_N_Shape(d.y + d.x + 1, d.y + 0.5);
                }
            }
            else if (left.y && !left.z)
    	    {
                [branch]
                if(right.z)
                {
                	result = L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                }
                else if (!right.y)
                {
                    result = L_N_Shape(d.y + d.x + 1, d.x + 0.5);
                }
                else
                {
                    result = L_L_S_Shape(d.x + 0.5, d.y + 0.5);
                }
            }
            else if (!left.y && left.z)
            {
                [branch]
                if (right.y)
                {
                    result = -L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                }
                else if (!right.z)
                {
                    result = -L_N_Shape(d.x + d.y + 1, d.x + 0.5);
                }
                else
                {
                    result = -L_L_S_Shape(d.x + 0.5, d.y + 0.5);
                }
            }
            else
            {
                [branch]
                if(right.y && !right.z)
                {
                    result = -L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                }
                else if (!right.y && right.z)
                {
                    result = L_L_D_Shape(d.x + 0.5, d.y + 0.5);
                }
            }

        /*#ifdef ROUNDING_FACTOR
            bool apply = false;
            if (result > 0)
            {
                if(d.x < d.y && left.x)
                {
                    apply = true;
                }
                else if(d.x >= d.y && right.x)
                {
                    apply = true;
                }
            }
            else if (result < 0)
            {
                if(d.x < d.y && left.w)
                {
                    apply = true;
                }
                else if(d.x >= d.y && right.w)
                {
                    apply = true;
                }
            }
            if (apply)
            {
                result = result * ROUNDING_FACTOR;
            }
        #endif*/

            return result;

        }




		half4 fragblend(v2f i) :SV_TARGET{
			float2 uv = i.texcoord;
			float2 pos=i.texcoord*_MainTex_TexelSize.zw;
			float2 edge = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv).rg;
			float4 result=0;
			bool4 l,r;

			if(edge.g>0.1f){
				float left = SearchLeft(pos);
				float right = SearchRight(pos);

			/*#ifdef ROUNDING_FACTOR
                float left1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(-left, -1.25)) * _MainTex_TexelSize.xy).r;
                float left2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(-left, 0.75)) * _MainTex_TexelSize.xy).r;
                l = ModeOfDouble(left1, left2);
                float right1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(right + 1, -1.25)) * _MainTex_TexelSize.xy).r;
                float right2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(right + 1, 0.75)) * _MainTex_TexelSize.xy).r;
                r = ModeOfDouble(right1, right2);
            #else*/
				float left_value=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,(pos+float2(-left,-0.25))*_MainTex_TexelSize.xy).r;
				float right_value=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,(pos+float2(right+1,-0.25))*_MainTex_TexelSize.xy).r;
				l=ModeOfSingle(left_value);
				r=ModeOfSingle(right_value);
			//#endif
				float value = Area(float2(left,right),l,r);
				result.xy=float2(-value,value);

			}

			if (edge.r > 0.1f)
            {
                float up = SearchUp(pos);
                float down = SearchDown(pos);

                bool4 u, d;
            /*#ifdef ROUNDING_FACTOR
                float up1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(-1.25, -up)) * _MainTex_TexelSize.xy).g;
                float up2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(0.75, -up)) * _MainTex_TexelSize.xy).g;
                float down1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(-1.25, down + 1)) * _MainTex_TexelSize.xy).g;
                float down2 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(0.75, down + 1)) * _MainTex_TexelSize.xy).g;
                u = ModeOfDouble(up1, up2);
                d = ModeOfDouble(down1, down2);
            #else*/
                float up_value = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(-0.25, -up)) * _MainTex_TexelSize.xy).g;
                float down_value = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, (pos + float2(-0.25, down + 1)) * _MainTex_TexelSize.xy).g;
                u = ModeOfSingle(up_value);
                d = ModeOfSingle(down_value);
            //#endif
                float value = Area(float2(up, down), u, d);
                result.zw = float2(-value, value);
            }
                    
            return result;
		}

		half4 fragneighbor(v2f i) :SV_TARGET{
			float4 TL=SAMPLE_TEXTURE2D(_BlendTex,sampler_BlendTex,i.texcoord);
			float R=SAMPLE_TEXTURE2D(_BlendTex,sampler_BlendTex,i.texcoord+float2(1.0,0)*_MainTex_TexelSize).a;
			float B=SAMPLE_TEXTURE2D(_BlendTex,sampler_BlendTex,i.texcoord+float2(0,1.0)*_MainTex_TexelSize).g;
			float4 a = float4(TL.r, B, TL.b, R);

			float4 w=a*a*a;
			float sum=dot(w,1);

			[branch]
			if(sum>0){
				float4 o=a*_MainTex_TexelSize.yyxx;
				float4 color=0;
				color=mad(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(0,-o.r)),w.r,color);
				color=mad(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(0,o.g)),w.g,color);
				color=mad(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(-o.b,0)),w.b,color);
				color=mad(SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord+float2(o.a,0)),w.a,color);
				return color/sum;
			}else{
				return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord);
			}

		}

		ENDHLSL


		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragedge
			ENDHLSL
		}

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragblend
			ENDHLSL
		}

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment fragneighbor
			ENDHLSL
		}
	}
}
