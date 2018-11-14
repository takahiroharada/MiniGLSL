#version 330

//precision highp float;

uniform vec2 c_Size;
uniform vec2 c_po;// pixel offset
uniform int c_steps;
uniform ivec4 c_mouse;

layout(location = 0) out vec4 diffuseColor;


#define FLT_MAX 3.402823e+38
#define PI 3.1415
#define float4 vec4
#define float2 vec2
#define int2 ivec2
#define uint2 ivec2
#define u32 int

#define make_float4 float4

#define sqrtf sqrt

#define RAYCAST_EPSILON 0.001
#define WORLD_SIZE 10.0

float dot3F4( float4 a, float4 b ) { return dot( a.xyz, b.xyz ); }

float4 normalize3( float4 a ) { return normalize( a.xyz ).xyzz; }

float4 cross3( float4 a, float4 b ) { return cross( a.xyz, b.xyz ).xyzz; }

float length3( float4 a ) { return length( a.xyz ); }

#define R_INIT int rng = c_steps;
#define R_ARGS_LIST vec2( gl_FragCoord.x/c_Size.x, gl_FragCoord.y/c_Size.y ), rng
#define R_ARGS float2 seed, inout int rng

float draw(float2 seed, inout int s)
{
	float c = 0.01f;
	seed.x*=cos(s*c);
	seed.y*=sin(s*c);
	s++;
	return fract(sin(dot(seed.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


float4 getRandomSphericalVector(float s0, float s1)
{
	float t = 2*cos(sqrtf(1.0-s0));
	float p = 2*PI*s1;
	return float4( sin(t)*cos(p), sin(t)*sin(p),cos(t), 0.0 );
}

float2 getRandomUnitDisk( float s0, float s1 )
{
	float r = sqrtf(s0);
	float t = 2.0*PI*s1;
	return float2( r*cos(t), r*sin(t) );
}

float4 getRandomHemiSphericalCosWeighted( float4 up, float s0, float s1 )
{
	float4 t = cross3((abs(up.x)>0.0001)? float4(0.0,1.0,0.0,0.0):float4(1.0,0.0,0.0,0.0), up);
	float4 b = cross3(up,t);

	t = normalize3( t );
	b = normalize3( b );
	float2 uv = getRandomUnitDisk(s0,s1);
	float w = sqrtf( 1.0 - uv.x*uv.x - uv.y*uv.y );
	return normalize3( uv.x*t+uv.y*b+w*up );
}

struct CameraInfo
{
	float4 m_viewDir;
	float4 m_holDir;
	float4 m_upDir;
	float2 m_dx;
	int2 m_resolution;
};

float4 rotateX(float4 p, float a)
{
    float sa = sin(a);
    float ca = cos(a);
    return float4(p.x, ca*p.y - sa*p.z, sa*p.y + ca*p.z, 0.0);
}

float4 rotateY(float4 p, float a)
{
    float sa = sin(a);
    float ca = cos(a);
    return float4(ca*p.x + sa*p.z, p.y, -sa*p.x + ca*p.z, 0.0);
}

float RayCastUtils_castRay(const float4 sphereCenter, float r, const float4 from, const float4 to)
{
	float4 m = from - sphereCenter;
	float4 d = to - from;
	float a = dot3F4(d, d);
	float b = 2.0*dot3F4(m, d);
	float c = dot3F4(m, m) - r*r;
	float dd = b*b - 4.0*a*c;
	if (dd < 0.0) return -1.0;
    
	float x0 = (-b - sqrt(dd)) / (2.0*a);
	float x1 = (-b + sqrt(dd)) / (2.0*a);

	if( x0 > 0 ) return x0;
	return x1;
}

int nSpheres = 8;
#define RA 1e4
vec4 spheres[8] = vec4[](
                         vec4(-0.5, -1.0 + 0.4, -0.1, 0.4),
                         vec4( 0.5, -1.0 + 0.35, 0.5, 0.35),
                         vec4(50, 681.6 - .27, 81.6, 600), // light
                         
                         vec4(0.0, -RA - 1.0, 0.0, RA),
                         vec4(0.0,  RA + 1.0, 0.0, RA),
                         
                         vec4(-RA - 1.0, 0.0, 0.0, RA),
                         vec4( RA + 1.0, 0.0, 0.0, RA),
                         
                         vec4(0.0, 0.0, 1.0 + RA, RA)
                         );

float4 colors[8] = float4[](
                        float4(1.0, 1.0, 1.0, 0.0),
                        float4(1.0, 1.0, 1.0, 0.0),
                        float4(1.0, 1.0, 1.0, 0.0),
                        
                        float4(.75, .75, .75, 0.0),
                        float4(.75, .75, .75, 0.0),
                        
                        float4(.0, .25, .75, 0.0),
                        float4(.75, .0, .25, 0.0),
                        
                        float4(.75, .75, .75, 0.0)
                        );

float4 lightPos = float4(0.0, 0.7, 0.0, 0.0);

struct HitInfo
{
	float4 m_hitNormal;
	int m_idx;
	float m_f;
};

bool hasHit(HitInfo info)
{
	return info.m_idx != -1;
}

HitInfo intersect(float4 from, float4 to)
{
	float4 dir = normalize3(to - from);
	HitInfo info;
	info.m_idx = -1;
	info.m_f = 1.0;
	for (int i = 0; i<nSpheres; i++)
	{
		float ff = RayCastUtils_castRay(spheres[i], spheres[i].w, from, to);
		if (ff > 0.0 && ff < info.m_f)
		{
			float4 hitpoint = from + ff * (to - from);
			info.m_idx = i;
			info.m_f = ff;
			info.m_hitNormal = (hitpoint - spheres[i]);
		}
	}
	info.m_hitNormal = normalize3(info.m_hitNormal);
	return info;
}


struct SampleInfo
{
	float4 m_x;
	float4 m_n;
	float4 m_le;
	float m_pdf;
};

SampleInfo sampleLightVtx( float4 x )
{
	float4 d = x - lightPos;
	SampleInfo i;
	i.m_x = lightPos;
	i.m_n = normalize3( x - lightPos );
	i.m_le = float4(2.0) / dot3F4( d, d );
	i.m_pdf = 1.0;
	return i;
}


void main(void)
{
	R_INIT;
    //	diffuseColor = vec4( gl_FragCoord.x/640.0, gl_FragCoord.y/480.0, 0.0, 0.0 );
    
	float4 from, to;
	CameraInfo info;
	{//	set up camera
		float fov = PI*40.0 / 180.0;
		float tfar = 10.0;
		float4 eye = float4(0.0,0.0,-4.5, 0.0);
		float4 center = eye + float4(0.0, 0.0, 1.0, 0.0);
		float4 up = float4(0.0, 1.0, 0.0, 0.0);
		{
			vec2 mouse = c_mouse.xy / c_Size.xy;
			float rotx = -(mouse.y-0.5)*1.0;
			float roty = (mouse.x-0.5)*2.0;
			float4 dir = center - eye;
			dir = rotateX( dir, rotx );
			dir = rotateY( dir, roty );
			center = eye + dir;
		}

		float i = gl_FragCoord.x + c_po.x;
		float j = gl_FragCoord.y + c_po.y;
        
		info.m_viewDir = normalize3(center - eye);
		info.m_holDir = normalize3(cross3(info.m_viewDir, up));
		info.m_upDir = normalize3(cross3(info.m_holDir, info.m_viewDir));
        
		info.m_dx = vec2(tan(fov / 2.0) / c_Size.y, tan(fov / 2.0) / c_Size.y) * 2.0;
                
		float4 vec = info.m_holDir*info.m_dx.x*(i + 0.5 - c_Size.x / 2.0) + info.m_upDir*info.m_dx.y*(j + 0.5 - c_Size.y / 2.0) + info.m_viewDir;
		vec = normalize3(vec);
        
		from = eye;
		to = eye + vec * tfar;
	}
    
	HitInfo hit = intersect(from, to);
    
	if (!hasHit(hit))
		return;

	if(false)
	{
		diffuseColor = colors[hit.m_idx];
		return;
	}

	float4 color = float4(0.0);
	{//	shadow ray cast
		float4 f1 = from + hit.m_f * (to - from);
		f1 += hit.m_hitNormal * RAYCAST_EPSILON;

		SampleInfo l = sampleLightVtx( f1 );
		float4 t1 = l.m_x + RAYCAST_EPSILON * l.m_n;
        
		HitInfo shit = intersect(f1, t1);
		if (!hasHit(shit))
		{
			float4 f = colors[hit.m_idx]/PI;
			color = f * max(0.0, dot3F4(normalize3(t1 - f1), hit.m_hitNormal)) * l.m_le / l.m_pdf;
		}
	}
    
	diffuseColor = color;
    
	//  gl_FragColor = vec4( gl_FragCoord.x/c_Size.x, gl_FragCoord.y/c_Size.y, 0.0, 0.0 );
}
