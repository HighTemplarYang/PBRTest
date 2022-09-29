Shader "Unlit/Grass"
{
	Properties
	{
		_WindMap("WindMap",2D)="white"{}
		_WindStrength("WindStrength",float)=1
		_WindSpeed("WindSpeed",float)=1
		_BottomColor("BottomColor",Color) = (1,1,1,1)
		_TopColor("TopColor",Color) = (1,1,1,1)
		_Flow("Flow",Range(0,1)) = 0
		_BladeWidth("BladeWidth",float) = 0.05
		_BladeWidthRandom("BladeWidthRandom",float) = 0.02
		_BladeHeight("BladeHeight",float) = 0.5
		_BladeHeightRandom("BladeHeightRandom",float) = 0.5
		_TessellationUniform("Tessellation Uniform",Range(1,64))=1
	}
	SubShader
	{
		

		HLSLINCLUDE
			#define UNITY_TWO_PI 6.283
			#define BLADE_SEGMENT 5
			#define MAIN_LIGHT_CALCULATE_SHADOWS
            #define _SHADOWS_SOFT

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

			CBUFFER_START(UnityPerMaterial)
			float4 _BottomColor;
			float4 _TopColor;
			float _Flow;
			float _BladeWidth;
			float _BladeWidthRandom;
			float _BladeHeight;
			float _BladeHeightRandom;
			float _TessellationUniform;
			float _WindStrength;
			float _WindSpeed;
            CBUFFER_END 

			TEXTURE2D(_WindMap);
            SAMPLER(sampler_WindMap);


			float rand(float3 co) {
				return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539)))*43758.5453);
			}



		   struct appdata
			{
				float3 vertex : POSITION;
				float4 tangent:TANGENT;
				float3 normal:NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2g {
				float4 vertex : SV_POSITION;
				float4 tangent:TANGENT;
				float3 normal:NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct g2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 worldPosition:TEXCOORD1;
				float3 normal:TEXCOORD2;
			};

			v2g vert (appdata v)
            {
				v2g o;
                o.vertex = float4(TransformObjectToWorld(v.vertex),1);
				o.tangent = v.tangent;
				o.normal = v.normal;
                o.uv = v.uv;
                return o;
            }

			struct PatchTess{
				float EdgeTess[3]:SV_TessFactor;
				float InsideTess:SV_InsideTessFactor;
			};

			PatchTess ConstantHS(InputPatch<v2g,3> patch,uint patchID:SV_PrimitiveID){
				PatchTess pt;
				pt.EdgeTess[0]=_TessellationUniform;
				pt.EdgeTess[1]=_TessellationUniform;
				pt.EdgeTess[2]=_TessellationUniform;
				pt.InsideTess=_TessellationUniform;
				return pt;
			}

			[domain("tri")]
			[partitioning("integer")]
			[outputtopology("triangle_cw")]
			[outputcontrolpoints(3)]
			[patchconstantfunc("ConstantHS")]
			[maxtessfactor(64.0f)]
			v2g hull(InputPatch<v2g,3> p,uint i:SV_OutputControlPointID){
				return p[i];
			}

			[domain("tri")]
			v2g domain(PatchTess patchTess,float3 bary:SV_DomainLocation,const OutputPatch<v2g,3> triangles){
				v2g o=(v2g)0;
				o.vertex=triangles[0].vertex*bary.x+triangles[1].vertex*bary.y+triangles[2].vertex*bary.z;
				o.tangent=triangles[0].tangent*bary.x+triangles[1].tangent*bary.y+triangles[2].tangent*bary.z;
				o.normal=triangles[0].normal*bary.x+triangles[1].normal*bary.y+triangles[2].normal*bary.z;
				o.uv=triangles[0].uv*bary.x+triangles[1].uv*bary.y+triangles[2].uv*bary.z;
				return o;
			}


			[maxvertexcount(BLADE_SEGMENT*2+1)]
			void geo(triangle v2g input[3], inout TriangleStream<g2f> outStream) {
				g2f o = (g2f)0;
				float3 normal = TransformObjectToWorldNormal(input[0].normal);
				float4 tangent = float4(TransformObjectToWorldDir(input[0].tangent), input[0].tangent.w);
				float3 bitangent = normalize(cross(tangent.xyz, normal));
				bitangent *= input[0].tangent.w;
				
				float rand1 = rand(input[0].vertex);
				float c, s;
				sincos(rand1*UNITY_TWO_PI, s, c);
				
				float rand2 = rand(input[0].vertex.yzx);
				float3 bottomDir = (tangent.xyz*c + bitangent * s);
				float3 bottombiDir= (tangent.xyz*s + bitangent * -c);
				
				float3 wind=SAMPLE_TEXTURE2D_LOD(_WindMap,sampler_WindMap,input[0].uv+_Time.y*0.05*_WindSpeed,0);
				float3 Dir = normalize(lerp(normal, bottombiDir, _Flow)+wind.yzx*_WindStrength);
				float3 BottomOffset=(_BladeWidth+_BladeWidthRandom*rand2)*bottomDir;
				float3 TopOffset=(_BladeHeight+_BladeHeightRandom*rand2)*Dir;
				float3 NORMAL=normalize(cross(Dir,BottomOffset));
				o.normal=NORMAL;
				for(int i=0;i<BLADE_SEGMENT;i++){
					float t=i/(float)BLADE_SEGMENT;
					o.worldPosition=input[0].vertex+float3(lerp(BottomOffset,TopOffset,t).x,lerp(BottomOffset,TopOffset,pow(t,0.8)).y,lerp(BottomOffset,TopOffset,t).z);
					o.vertex = TransformWorldToHClip(o.worldPosition);
					o.uv = t;
					outStream.Append(o);
					o.worldPosition=input[0].vertex+float3(lerp(-BottomOffset,TopOffset,t).x,lerp(-BottomOffset,TopOffset,pow(t,0.8)).y,lerp(-BottomOffset,TopOffset,t).z);	
					o.vertex = TransformWorldToHClip(o.worldPosition);
					o.uv = t;
					outStream.Append(o);
				}
				o.vertex = TransformWorldToHClip(input[0].vertex + TopOffset);
				o.uv = 1;
				outStream.Append(o);
			}

			


            half4 frag(g2f i,half facing:VFACE) : SV_Target
            {
				float4 shadowCoord=TransformWorldToShadowCoord(i.worldPosition);
                half4 shadowMask = half4(1, 1, 1, 1);
                Light mainLight = GetMainLight(shadowCoord,i.worldPosition,unity_ProbesOcclusion);
				//return mainLight.shadowAttenuation;
				float3 NORMAL=facing>0?i.normal:-i.normal;
				//return float4(NORMAL,1);
				float NDL=saturate(dot(NORMAL,mainLight.direction));
				return lerp(_BottomColor,_TopColor,i.uv.x)*(0.5+0.5*NDL*mainLight.shadowAttenuation);
            }

			ENDHLSL
		

		Pass
		{
			Tags { "LightMode" = "UniversalForward" "RenderType" = "Opaque" }
			LOD 100
			Cull off
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geo
			#pragma hull hull
			#pragma domain domain

			
            ENDHLSL
        }

		Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM


            #pragma vertex vert
			#pragma geometry geo
			#pragma hull hull
			#pragma domain domain
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        
    }
}
