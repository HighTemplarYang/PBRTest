Shader "Unlit/PBRTest"
{
    Properties
    {
        _Color("color",Color) = (1,1,1,1)
        _baseMap ("baseMap", 2D) = "white" {}
        _metallic("metallic",2D) = "white" {}
        _normal("normal",2D)="bump"{}
        _smoothness("smoothness",Range(0,1))=0
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

            #define UNITY_PI 3.14
            #define MAIN_LIGHT_CALCULATE_SHADOWS
            #define _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float _smoothness;
            CBUFFER_END 

            TEXTURE2D(_baseMap);
            TEXTURE2D(_metallic);
            TEXTURE2D(_normal);
            SAMPLER(sampler_baseMap);
            SAMPLER(sampler_normal);


            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal :NORMAL;
                float4 tangent:TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal :TEXCOORD1;
                float3 objectPosition :TEXCOORD2;
                float4 tangent:TEXCOORD3;
                float4 vertex : SV_POSITION;
            };

            float D_Function(float NdH,float roughness){
                float roughness2 = roughness*roughness;
                float NdH2=NdH*NdH;
                float denom=(NdH2*(roughness2-1)+1);
                denom=UNITY_PI*denom*denom;
                return roughness2/denom;
            }

            float G_SubFunction(float NdW,float k){
                float denom=NdW*(1-k)+k;
                return NdW/denom;
            }

            float G_Function(float NdV,float NdL,float roughness){
                float k=(roughness+1)*(roughness+1)/8;
                return G_SubFunction(NdV,k)*G_SubFunction(NdL,k);
            }

            float3 F_Dir_Function(float HdV,float3 F0){
                float fresnel=exp2((-5.55473*HdV-6.98316)*HdV);
                return lerp(fresnel,1,F0);
            }
            
            float3 F_Indir_Function(float NdotV,float roughness,float3 F0){
                float fresnel=exp2((-5.55473 * NdotV - 6.98316) * NdotV);
                return F0+fresnel*saturate(1-roughness-F0);
            }

            real3 IndirSpecCube(float3 R,float roughness,float AO){
                roughness=roughness*(1.7-0.7*roughness);
                half MidLevel=roughness*6;
                half4 specColor=SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0,R,MidLevel);
                #if !defined(UNITY_USE_NATIVE_HDR)
                    return DecodeHDREnvironment(specColor,unity_SpecCube0_HDR)*AO;
                #else
                    return specColor*AO;
                #endif
                    return specColor;
            }

            float2 LUT_Approx(float roughness,float NdV){
                const float4 c0={-1,-0.0275,-0.572,0.022};
                const float4 c1={1,0.0425,1.04,-0.04};
                float4 r=roughness*c0+c1;
                float a004=min(r.x*r.x,exp2(-9.28*NdV))*r.x+r.y;
                float2 AB=float2(-1.04,1.04)*a004+r.zw;
                return saturate(AB);
            }

            half3 IndirSpec_Function(float3 R,float roughness,float NdV,float AO,float F0){
                half3 indirectionCube=IndirSpecCube(R,roughness,AO);
                float2 LUT=LUT_Approx(roughness,NdV);
                float3 F_IndirectionLight = F_Indir_Function(NdV,roughness,F0);
                float3 indirectionSpecFactor = indirectionCube*(F_IndirectionLight * LUT.r+LUT.g);
                return indirectionSpecFactor;
            }

            real3 MySHEvalLinearL0L1(real3 worldNormal, real4 shAr, real4 shAg, real4 shAb)
            {
                real4 vA = real4(worldNormal, 1.0);

                real3 x1;
                // Linear (L1) + constant (L0) polynomial terms
                x1.r = dot(shAr, vA);
                x1.g = dot(shAg, vA);
                x1.b = dot(shAb, vA);

                return x1;
            }

            real3 MySHEvalLinearL2(real3 N, real4 shBr, real4 shBg, real4 shBb, real4 shC)
            {
                real3 x2;
                // 4 of the quadratic (L2) polynomials
                real4 vB = N.xyzz * N.yzzx;
                x2.r = dot(shBr, vB);
                x2.g = dot(shBg, vB);
                x2.b = dot(shBb, vB);

                // Final (5th) quadratic (L2) polynomial
                real vC = N.x * N.x - N.y * N.y;
                real3 x3 = shC.rgb * vC;

                return x2 + x3;
            }

            float3 GetSHColor(float3 worldNormal){
                half3 SH = MySHEvalLinearL0L1(worldNormal, unity_SHAr, unity_SHAg, unity_SHAb);
                SH += MySHEvalLinearL2(worldNormal, unity_SHBr, unity_SHBg, unity_SHBb, unity_SHC);

                return SH;
            }

            float3 IndirectionDiffuse_Function(float NdV,float3 worldNormal,float metallic,float3 baseColor,float roughness,float occlusion,float3 F0){
                float3 SH=GetSHColor(worldNormal);
                float3 KS=F_Indir_Function(NdV,roughness,F0);
                float3 KD=(1-KS)*(1-metallic);
                return SH*KD*baseColor*occlusion;
            }




            v2f vert (appdata v)
            {
                v2f o;
                o.objectPosition=v.vertex;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.normal = v.normal;
                o.tangent=v.tangent;
                o.uv = v.uv;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float4 baseColor= SAMPLE_TEXTURE2D(_baseMap,sampler_baseMap,i.uv) * _Color;
                float4 MRA=SAMPLE_TEXTURE2D(_metallic,sampler_baseMap,i.uv);
                float metallic = MRA.r;
                float roughness = lerp(MRA.a,0,_smoothness);
                float AO=MRA.g;
                float3 worldPosition=TransformObjectToWorld(i.objectPosition);
                float3 worldNormal=TransformObjectToWorldNormal(i.normal);
                float3 worldTangent=TransformObjectToWorldDir(i.tangent);
                float3 worldBitangent=cross(worldNormal,worldTangent)*i.tangent.w;

                float3 bump=UnpackNormal(SAMPLE_TEXTURE2D(_normal, sampler_normal,i.uv));
                float3x3 TBN = float3x3(normalize(worldTangent),normalize(worldBitangent),normalize(worldNormal));
                worldNormal=mul(bump,TBN);

                float4 shadowCoord=TransformWorldToShadowCoord(worldPosition);
                half4 shadowMask = half4(1, 1, 1, 1);
                Light mainLight = GetMainLight(shadowCoord,worldPosition,unity_ProbesOcclusion);

                float3 F0 = lerp(0.04,baseColor,metallic);
                float3 L=normalize(mainLight.direction);
                float3 V=normalize(_WorldSpaceCameraPos-worldPosition);
                float3 H=normalize(L+V);
                float3 R=reflect(-V,worldNormal);
                float NdH=saturate(dot(worldNormal,H));
                float NdL=saturate(dot(worldNormal,L));
                float NdV=saturate(dot(worldNormal,V));
                float HdV=saturate(dot(H,V));

                float D=D_Function(NdH,roughness);
                float G=G_Function(NdV,NdL,roughness);
                float3 F=F_Dir_Function(HdV,F0);
                float3 KS=F;
                float3 KD=(1-KS)*(1-metallic);

                float3 BRDFSpeSection=D*G*F/(4*NdV*NdL);
                float3 DirectSpeColor=BRDFSpeSection*mainLight.color*NdL*UNITY_PI;
                float3 DirectDiffColor=KD*baseColor.xyz*mainLight.color*NdL;
                float3 DirectColor=DirectSpeColor+DirectDiffColor;
                DirectColor=saturate(DirectColor);
                DirectColor*=AO;
                float3 IndirectDiffColor=IndirectionDiffuse_Function(NdV,worldNormal,metallic,baseColor,roughness,AO,F0);
                half3 IndirectSpeColor=IndirSpec_Function(R,roughness,NdV,AO,F0);
                float3 IndirectColor=IndirectDiffColor+IndirectSpeColor;


                float3 FinalColor=IndirectColor+DirectColor*mainLight.shadowAttenuation*mainLight.distanceAttenuation;
                return float4(FinalColor,1);
            }
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


            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}
