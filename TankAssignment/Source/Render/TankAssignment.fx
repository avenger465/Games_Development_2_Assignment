//--------------------------------------------------------------------------------------
//	File: TankAssignment.fx
//
//	A range of shaders/techniques used for the tank assignment. Graphics is not the
//  focus of this assignment, most marks are given for game logic tasks.
//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
// Global Variables
//--------------------------------------------------------------------------------------

// Matrices for transforming model vertices from model space -> world space -> camera space -> 2D projected vertices
float4x4 WorldMatrix;
float4x4 ViewMatrix;
float4x4 ProjMatrix;

// Camera position (needed for specular lighting at least)
float3 CameraPos;

// Light data
float3 Light1Pos;
float3 Light2Pos;
float3 Light1Colour;
float3 Light2Colour;
float3 AmbientColour;

// Material colour data
float4 DiffuseColour;
float4 SpecularColour;
float  SpecularPower;

// Texture maps
Texture2D DiffuseMap;
Texture2D DiffuseMap2; // Second diffuse map for special techniques (currently unused)
Texture2D NormalMap;

// Samplers to use with the above texture maps. Specifies texture filtering and addressing mode to use when accessing texture pixels
SamplerState TrilinearWrap
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};


//--------------------------------------------------------------------------------------
// Structures
//--------------------------------------------------------------------------------------

// Standard vertex data to be sent into the vertex shader
struct VS_INPUT
{
    float3 Pos     : POSITION;
    float3 Normal  : NORMAL;
	float2 UV      : TEXCOORD0;
};

// Minimum vertex shader output 
struct VS_BASIC_OUTPUT
{
    float4 ProjPos       : SV_POSITION;
};

// Vertex shader output for texture only
struct VS_TEX_OUTPUT
{
    float4 ProjPos       : SV_POSITION;
    float2 UV            : TEXCOORD0;
};


// Vertex shader output for pixel lighting with no texture
struct VS_LIGHTING_OUTPUT
{
    float4 ProjPos       : SV_POSITION;
	float3 WorldPos      : POSITION;
	float3 WorldNormal   : NORMAL;
};

// Vertex shader output for pixel lighting with a texture
struct VS_LIGHTINGTEX_OUTPUT
{
    float4 ProjPos       : SV_POSITION;  // 2D "projected" position for vertex (required output for vertex shader)
	float3 WorldPos      : POSITION;
	float3 WorldNormal   : NORMAL;
    float2 UV            : TEXCOORD0;
};


//--------------------------------------------------------------------------------------
// Vertex Shaders
//--------------------------------------------------------------------------------------

// Basic vertex shader to transform 3D model vertices to 2D only
//
VS_BASIC_OUTPUT VSTransformOnly( VS_INPUT vIn )
{
	VS_BASIC_OUTPUT vOut;
	
	// Transform the input model vertex position into world space, then view space, then 2D projection space
	float4 modelPos = float4(vIn.Pos, 1.0f); // Promote to 1x4 so we can multiply by 4x4 matrix, put 1.0 in 4th element for a point (0.0 for a vector)
	float4 worldPos = mul( modelPos, WorldMatrix );
	float4 viewPos  = mul( worldPos, ViewMatrix );
	vOut.ProjPos    = mul( viewPos,  ProjMatrix );

	return vOut;
}


// Basic vertex shader to transform 3D model vertices to 2D and pass UVs to the pixel shader
//
VS_TEX_OUTPUT VSTransformTex( VS_INPUT vIn )
{
	VS_TEX_OUTPUT vOut;
	
	// Transform the input model vertex position into world space, then view space, then 2D projection space
	float4 modelPos = float4(vIn.Pos, 1.0f); // Promote to 1x4 so we can multiply by 4x4 matrix, put 1.0 in 4th element for a point (0.0 for a vector)
	float4 worldPos = mul( modelPos, WorldMatrix );
	float4 viewPos  = mul( worldPos, ViewMatrix );
	vOut.ProjPos    = mul( viewPos,  ProjMatrix );
	
	// Pass texture coordinates (UVs) on to the pixel shader
	vOut.UV = vIn.UV;

	return vOut;
}


// Standard vertex shader for pixel-lit untextured models
//
VS_LIGHTING_OUTPUT VSPixelLit( VS_INPUT vIn )
{
	VS_LIGHTING_OUTPUT vOut;

	// Add 4th element to position and normal (needed to multiply by 4x4 matrix. Recall lectures - set 1 for position, 0 for vector)
	float4 modelPos = float4(vIn.Pos, 1.0f);
	float4 modelNormal = float4(vIn.Normal, 0.0f);

	// Transform model vertex position and normal to world space
	float4 worldPos    = mul( modelPos,    WorldMatrix );
	float3 worldNormal = mul( modelNormal, WorldMatrix ).xyz;

	// Pass world space position & normal to pixel shader for lighting calculations
   	vOut.WorldPos    = worldPos.xyz;
	vOut.WorldNormal = worldNormal;

	// Use camera matrices to further transform the vertex from world space into view space (camera's point of view) and finally into 2D "projection" space for rendering
	float4 viewPos  = mul( worldPos, ViewMatrix );
	vOut.ProjPos    = mul( viewPos,  ProjMatrix );

	return vOut;
}

// Standard vertex shader for pixel-lit textured models
//
VS_LIGHTINGTEX_OUTPUT VSPixelLitTex( VS_INPUT vIn )
{
	VS_LIGHTINGTEX_OUTPUT vOut;

	// Add 4th element to position and normal (needed to multiply by 4x4 matrix. Recall lectures - set 1 for position, 0 for vector)
	float4 modelPos = float4(vIn.Pos, 1.0f);
	float4 modelNormal = float4(vIn.Normal, 0.0f);

	// Transform model vertex position and normal to world space
	float4 worldPos    = mul( modelPos,    WorldMatrix );
	float3 worldNormal = mul( modelNormal, WorldMatrix ).xyz;

	// Pass world space position & normal to pixel shader for lighting calculations
   	vOut.WorldPos    = worldPos.xyz;
	vOut.WorldNormal = worldNormal;

	// Use camera matrices to further transform the vertex from world space into view space (camera's point of view) and finally into 2D "projection" space for rendering
	float4 viewPos  = mul( worldPos, ViewMatrix );
	vOut.ProjPos    = mul( viewPos,  ProjMatrix );

	// Pass texture coordinates (UVs) on to the pixel shader, the vertex shader doesn't need them
	vOut.UV = vIn.UV;

	return vOut;
}


//--------------------------------------------------------------------------------------
// Pixel Shaders
//--------------------------------------------------------------------------------------

// A pixel shader that just outputs the diffuse material colour
//
float4 PSPlainColour( VS_BASIC_OUTPUT vOut ) : SV_Target
{
	return DiffuseColour;
}

// A pixel shader that just outputs an diffuse map tinted by the diffuse material colour
//
float4 PSTexColour( VS_TEX_OUTPUT vOut ) : SV_Target
{
	float4 diffuseMapColour = DiffuseMap.Sample( TrilinearWrap, vOut.UV );
	return float4( DiffuseColour.xyz * diffuseMapColour.xyz, diffuseMapColour.a ); // Only tint the RGB, get alpha from texture directly
}



// Per-pixel lighting pixel shader using diffuse/specular colours but no textures
//
float4 PSPixelLit( VS_LIGHTING_OUTPUT vOut ) : SV_Target 
{
	// Can't guarantee the normals are length 1 at this point, because the world matrix may contain scaling and because interpolation
	// from vertex shader to pixel shader will also rescale normal. So renormalise the normals we receive
	float3 worldNormal = normalize(vOut.WorldNormal); 


	///////////////////////
	// Calculate lighting

	// Calculate direction of camera
	float3 cameraDir = normalize(CameraPos - vOut.WorldPos.xyz); // Position of camera - position of current pixel (in world space)
	
	//// LIGHT 1
	float3 light1Dir = normalize(Light1Pos - vOut.WorldPos.xyz);   // Direction for each light is different
	float3 light1Dist = length(Light1Pos - vOut.WorldPos.xyz); 
	float3 diffuseLight1 = Light1Colour * max( dot(worldNormal.xyz, light1Dir), 0 ) / light1Dist;
	float3 halfway = normalize(light1Dir + cameraDir);
	float3 specularLight1 = diffuseLight1 * pow( max( dot(worldNormal.xyz, halfway), 0 ), SpecularPower );

	//// LIGHT 2
	float3 light2Dir = normalize(Light2Pos - vOut.WorldPos.xyz);
	float3 light2Dist = length(Light2Pos - vOut.WorldPos.xyz);
	float3 diffuseLight2 = Light2Colour * max( dot(worldNormal.xyz, light2Dir), 0 ) / light2Dist;
	halfway = normalize(light2Dir + cameraDir);
	float3 specularLight2 = diffuseLight2 * pow( max( dot(worldNormal.xyz, halfway), 0 ), SpecularPower );

	// Sum the effect of the two lights - add the ambient at this stage rather than for each light (or we will get twice the ambient level)
	float3 diffuseLight = AmbientColour + diffuseLight1 + diffuseLight2;
	float3 specularLight = specularLight1 + specularLight2;


	////////////////////
	// Combine colours 
	
	// Combine maps and lighting for final pixel colour
	float4 combinedColour;
	combinedColour.rgb = DiffuseColour.rgb * diffuseLight + SpecularColour.rgb * specularLight;
	combinedColour.a = 1.0f; // No alpha processing in this shader, so just set it to 1

	return combinedColour;
}


// Per-pixel lighting pixel shader using diffuse/specular material colours and combined diffuse/specular map
//
float4 PSPixelLitTex( VS_LIGHTINGTEX_OUTPUT vOut ) : SV_Target
{
	// Can't guarantee the normals are length 1 at this point, because the world matrix may contain scaling and because interpolation
	// from vertex shader to pixel shader will also rescale normal. So renormalise the normals we receive
	float3 worldNormal = normalize(vOut.WorldNormal); 


	///////////////////////
	// Calculate lighting

	// Calculate direction of camera
	float3 cameraDir = normalize(CameraPos - vOut.WorldPos.xyz); // Position of camera - position of current pixel (in world space)
	
	//// LIGHT 1
	float3 light1Dir = normalize(Light1Pos - vOut.WorldPos.xyz);   // Direction for each light is different
	float3 light1Dist = length(Light1Pos - vOut.WorldPos.xyz); 
	float3 diffuseLight1 = Light1Colour * max( dot(worldNormal.xyz, light1Dir), 0 ) / light1Dist;
	float3 halfway = normalize(light1Dir + cameraDir);
	float3 specularLight1 = diffuseLight1 * pow( max( dot(worldNormal.xyz, halfway), 0 ), SpecularPower );

	//// LIGHT 2
	float3 light2Dir = normalize(Light2Pos - vOut.WorldPos.xyz);
	float3 light2Dist = length(Light2Pos - vOut.WorldPos.xyz);
	float3 diffuseLight2 = Light2Colour * max( dot(worldNormal.xyz, light2Dir), 0 ) / light2Dist;
	halfway = normalize(light2Dir + cameraDir);
	float3 specularLight2 = diffuseLight2 * pow( max( dot(worldNormal.xyz, halfway), 0 ), SpecularPower );

	// Sum the effect of the two lights - add the ambient at this stage rather than for each light (or we will get twice the ambient level)
	float3 diffuseLight = AmbientColour + diffuseLight1 + diffuseLight2;
	float3 specularLight = specularLight1 + specularLight2;


	////////////////////
	// Material colour

	// Combine diffuse material colour with diffuse map
	float4 diffuseTex = DiffuseMap.Sample( TrilinearWrap, vOut.UV );
	float3 diffuseMaterial = DiffuseColour.rgb * diffuseTex.rgb;
	
	// Combine specular material colour with specular map held in diffuse map alpha
	float3 specularMaterial = SpecularColour.rgb * diffuseTex.a;
	
	////////////////////
	// Combine colours 
	
	// Combine maps and lighting for final pixel colour
	float4 combinedColour;
	combinedColour.rgb = diffuseMaterial * diffuseLight + specularMaterial * specularLight;
	combinedColour.a = 1.0f; // No alpha processing in this shader, so just set it to 1

	return combinedColour;
}


// Per-pixel lighting pixel shader for tree leaves. Cuts out pixels with low alpha, tweaked diffuse lighting to suit leaves
// Additional input, isFront, allows us to find out which side of a polygon we are looking at (when not culling back faces)
float4 PSCutoutPixelLitTex(VS_LIGHTINGTEX_OUTPUT vOut, bool isFront : SV_IsFrontFace) : SV_Target
{
	// Read texture map first in case this pixel is cutout so we can discard it immediately
	float4 diffuseTex = DiffuseMap.Sample(TrilinearWrap, vOut.UV);
	float alphaThreshold = 0.75f - 0.5f * saturate(vOut.ProjPos.w / 150.0f); // Subtle adjustment to the alpha threshold for cutting out based on distance - keeps leaf detail sharp
	clip(diffuseTex.a - alphaThreshold); // Cut out pixels < certain alpha (from 0.25 to 0.75 depending on above)

	// Can't guarantee the normals are length 1 at this point, because the world matrix may contain scaling and because interpolation
	// from vertex shader to pixel shader will also rescale normal. So renormalise the normals we receive
	float3 worldNormal = normalize(vOut.WorldNormal);
	if (!isFront) worldNormal = -worldNormal; // Reverse normal if looking at reverse side of polygon for correct lighting (technique for when not culling back faces)


	///////////////////////
	// Calculate lighting

	// Calculate direction of camera
	float3 cameraDir = normalize(CameraPos - vOut.WorldPos.xyz); // Position of camera - position of current pixel (in world space)

	 //// LIGHT 1
	float3 light1Dir = normalize(Light1Pos - vOut.WorldPos.xyz);   // Direction for each light is different
	float3 light1Dist = length(Light1Pos - vOut.WorldPos.xyz);
	float3 diffuseLight1 = Light1Colour * pow(0.5f * dot(worldNormal.xyz, light1Dir) + 0.5f, 2) / light1Dist; // Tweaked diffuse gives more light to reverse side (leafs point all directions and are translucent)
	float3 halfway = normalize(light1Dir + cameraDir);
	float3 specularLight1 = diffuseLight1 * pow(max(dot(worldNormal.xyz, halfway), 0), SpecularPower);

	//// LIGHT 2
	float3 light2Dir = normalize(Light2Pos - vOut.WorldPos.xyz);
	float3 light2Dist = length(Light2Pos - vOut.WorldPos.xyz);
	float3 diffuseLight2 = Light2Colour * pow(0.5f * dot(worldNormal.xyz, light2Dir) + 0.5f, 2) / light2Dist; // Tweaked diffuse gives more light to reverse side (leafs point all directions and are translucent)
	halfway = normalize(light2Dir + cameraDir);
	float3 specularLight2 = diffuseLight2 * pow(max(dot(worldNormal.xyz, halfway), 0), SpecularPower);

	// Sum the effect of the two lights - add the ambient at this stage rather than for each light (or we will get twice the ambient level)
	float3 diffuseLight = AmbientColour + diffuseLight1 + diffuseLight2;
	float3 specularLight = specularLight1 + specularLight2;


	////////////////////
	// Material colour

	// Combine diffuse material colour with diffuse map
	float3 diffuseMaterial = DiffuseColour.rgb * diffuseTex.rgb;

	// Not using specular map in this shader because alpha is used for cutout
	float3 specularMaterial = SpecularColour.rgb;

	////////////////////
	// Combine colours 

	// Combine maps and lighting for final pixel colour
	float4 combinedColour;
	combinedColour.rgb = diffuseMaterial * diffuseLight + specularMaterial * specularLight;
	combinedColour.a = 1.0f; // No alpha processing in this shader, so just set it to 1

	return combinedColour;
}


//--------------------------------------------------------------------------------------
// States
//--------------------------------------------------------------------------------------

// States are needed to switch between additive blending for the lights and no blending for other models

RasterizerState CullNone  // Cull none of the polygons, i.e. show both sides
{
	CullMode = None;
};
RasterizerState CullBack  // Cull back side of polygon - normal behaviour, only show front of polygons
{
	CullMode = Back;
};


DepthStencilState DepthWritesOff // Don't write to the depth buffer - polygons rendered will not obscure other polygons
{
	DepthWriteMask = ZERO;
};
DepthStencilState DepthWritesOn  // Write to the depth buffer - normal behaviour 
{
	DepthWriteMask = ALL;
};


BlendState NoBlending // Switch off blending - pixels will be opaque
{
    BlendEnable[0] = FALSE;
};

BlendState AlphaBlending
{
    BlendEnable[0] = TRUE;
    SrcBlend = SRC_ALPHA;
    DestBlend = INV_SRC_ALPHA;
    BlendOp = ADD;
};


//--------------------------------------------------------------------------------------
// Techniques
//--------------------------------------------------------------------------------------

// Techniques are used to render models in our scene. They select a combination of vertex, geometry and pixel shader from those provided above. Can also set states.
// Different material render methods select different techniques

// Diffuse material colour only
technique10 PlainColour
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VSTransformOnly() ) );
        SetGeometryShader( NULL );                                   
        SetPixelShader( CompileShader( ps_4_0, PSPlainColour() ) );

		// Switch off blending states
		SetBlendState( NoBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
		SetRasterizerState( CullBack ); 
		SetDepthStencilState( DepthWritesOn, 0 );
     }
}


// Texture tinted with diffuse material colour
technique10 TexColour
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VSTransformTex() ) );
        SetGeometryShader( NULL );                                   
        SetPixelShader( CompileShader( ps_4_0, PSTexColour() ) );

		// Switch off blending states
		SetBlendState( NoBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
		SetRasterizerState( CullBack ); 
		SetDepthStencilState( DepthWritesOn, 0 );
     }
}


// Pixel lighting with diffuse texture
technique10 PixelLit
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VSPixelLit() ) );
        SetGeometryShader( NULL );                                   
        SetPixelShader( CompileShader( ps_4_0, PSPixelLit() ) );

		// Switch off blending states
		SetBlendState( NoBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
		SetRasterizerState( CullBack ); 
		SetDepthStencilState( DepthWritesOn, 0 );
	}
}

// Pixel lighting with diffuse texture
technique10 PixelLitTex
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VSPixelLitTex() ) );
        SetGeometryShader( NULL );                                   
        SetPixelShader( CompileShader( ps_4_0, PSPixelLitTex() ) );

		// Switch off blending states
		SetBlendState( NoBlending, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF );
		SetRasterizerState( CullBack ); 
		SetDepthStencilState( DepthWritesOn, 0 );
	}
}


// Pixel lighting with diffuse texture, cutout where alpha < 0.5f
technique10 CutoutPixelLitTex
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VSPixelLitTex()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_4_0, PSCutoutPixelLitTex()));

		// Switch off blending states
		SetBlendState(NoBlending, float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFFF);
		SetRasterizerState(CullNone); // Show both sides of cutout polygons
		SetDepthStencilState(DepthWritesOn, 0);
	}
}
