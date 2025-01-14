// RUN: %clang_cc1 -triple dxil-pc-shadermodel6.3-library -finclude-default-header -x hlsl -ast-dump -verify -o - %s

[numthreads(8,8,1)]
// expected-error@+1 {{attribute 'SV_DispatchThreadID' only applies to a field or parameter of type 'uint/uint2/uint3'}}
void CSMain(float ID : SV_DispatchThreadID) {

}

struct ST {
  int a;
  float b;
};
[numthreads(8,8,1)]
// expected-error@+1 {{attribute 'SV_DispatchThreadID' only applies to a field or parameter of type 'uint/uint2/uint3'}}
void CSMain2(ST ID : SV_DispatchThreadID) {

}

void foo() {
// expected-warning@+1 {{'SV_DispatchThreadID' attribute only applies to parameters and non-static data members}}
  uint V : SV_DispatchThreadID;

}

struct ST2 {
// expected-warning@+1 {{'SV_DispatchThreadID' attribute only applies to parameters and non-static data members}}
    static uint X : SV_DispatchThreadID;
    uint s : SV_DispatchThreadID;
};

[numthreads(8,8,1)]
// expected-error@+1 {{attribute 'SV_GroupID' only applies to a field or parameter of type 'uint/uint2/uint3'}}
void CSMain_GID(float ID : SV_GroupID) {
}

[numthreads(8,8,1)]
// expected-error@+1 {{attribute 'SV_GroupID' only applies to a field or parameter of type 'uint/uint2/uint3'}}
void CSMain2_GID(ST GID : SV_GroupID) {

}

void foo_GID() {
// expected-warning@+1 {{'SV_GroupID' attribute only applies to parameters and non-static data members}}
  uint GIS : SV_GroupID;
}

struct ST2_GID {
// expected-warning@+1 {{'SV_GroupID' attribute only applies to parameters and non-static data members}}
    static uint GID : SV_GroupID;
    uint s_gid : SV_GroupID;
};
