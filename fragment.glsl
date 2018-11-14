#version 330

uniform vec2 c_Size;
uniform sampler2D c_tex;

layout(location = 0) out vec4 diffuseColor;

vec4 xyz2rgb(vec4 xyz)
{
	float x = xyz[0]; float y = xyz[1]; float z = xyz[2];
	float r =  3.240970*x - 1.537383*y - 0.498611*z;
	float g = -0.969244*x + 1.875968*y + 0.041555*z;
	float b =  0.055630*x - 0.203977*y + 1.056972*z;
	return vec4( r,g,b,0.0 );
}

#define CS_XYZ 11.0/255.0

void main(void)
{
    diffuseColor = vec4(1.0, 0.0, 0.0, 1.0);
    diffuseColor = vec4( gl_FragCoord.x/c_Size.x, gl_FragCoord.y/c_Size.y, 0.0, 1.0 );
    vec2 crd = vec2( gl_FragCoord.x/c_Size.x, gl_FragCoord.y/c_Size.y );
//    diffuseColor = texture( c_tex, crd );
    float colorSpace = texture( c_tex, vec2(0,0) ).z;
    if( colorSpace == CS_XYZ )//xyz
	    diffuseColor = pow( xyz2rgb( texture( c_tex, crd ) ), vec4(1.0/2.2) );
	else
	    diffuseColor = pow( texture( c_tex, crd ), vec4(1.0/2.2) );
}
