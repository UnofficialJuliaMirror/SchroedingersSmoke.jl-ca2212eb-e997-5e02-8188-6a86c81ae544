# TorusDEC a class simple 3D grid with basic exterior calculus operations.
#
# SYNTAX
#
#   obj = TorusDEC(sizex,sizey,sizez,resx,resy,resz)
#   obj = TorusDEC(sizex,sizey,sizez,res)
#   classdef MyPDEProblem < TorusDEC
#
# DESCRIPTION
#
#   TorusDEC is a handle class that an instance is a 3D grid with periodic
#   boundaries in x,y,z direction, i.e. a 3-torus. DEC stands for "Discrete
#   Exterior Calculus", a set of operations including exterior derivatives,
#   codifferentials.
#
#   obj = TorusDEC(sizex,sizey,sizez,resx,resy,resz) creates an instance
#   obj, a 3D grid with size sizex, sizey, sizez and number of divisions
#   resx,resy,resz in each dimension.
#
#   obj = TorusDEC creates a default empty instance.
#
#   obj = TorusDEC(obj2) copies obj2 to obj.
#
#   obj = TorusDEC(sizex,sizey,sizez,res) creates a grid with size
#   sizex,sizey,sizez so that edge lengths dx,dy,dz are equal (cubic
#   lattice).  Input res specifies the number of grid points in the longest
#   dimension.
#
#   classdef MyPDEProblem < TorusDEC defines MyPDEProblem as a subclass of
#   TorusDEC. MyPDEProblem inherits all methods and members of TorusDEC.
#
#
# CLASS MEMBERS
#
#   sizex,sizey,sizez - length in each dimension.
#     resx, resy,resz - number of divisions in each dimension.
#          px, py, pz - positions.  Each of px, py, pz is a 3D array
#                       carrying x,y,z coordinate of each grid vertex.
#                       px ranges from 0 to sizex, and similarly for py,pz.
#          dx, dy, dz - edge lengths in each dimension.
#          ix, iy, iz - convenient 1D arrays 1:resx, 1:resy, 1:resz.
#       iix, iiy, iiz - convenient 3D arrays generated by ndgrid(ix,iy,iz).
#
# METHODS
#
#  Suppose obj is an instance of TorusDEC.
#
#  Exterior derivatives:
#
#  [vx,vy,vz] = obj.DerivativeOfFunction(f)
#     For a function f compute the 1-form df.
#     f is a 3D array representing a scalar function on the grid. vx,vy,vz
#     is the 1-form df integrated along edges. vx corresonds to edge
#     (i,j,k)->(i+1,j,k) and so on.
#
#  [wx,wy,wz] = obj.DerivativeOfOneForm(vx,vy,vz)
#     For a 1-form v compute the 2-form dv.
#
#  f = obj.DerivativeOfTwoForm(wx,wy,wz)
#     For a 2-form w compute the 3-form dw.
#
#  Codifferentials:
#
#  f = obj.Div(vx,vy,vz)
#     For a 1-form v compute the function *d*v.
#
#  Sharp Operator:
#
#  [ux,uy,uz] = obj.Sharp(vx,vy,vz)
#       For a 1-form v compute the corresponding vector field v^sharp by
#       averaging to vertices
#
#  [ux,uy,uz] = obj.StaggeredSharp(vx,vy,vz)
#       For a 1-form v compute the corresponding vector field v^sharp as
#       a staggered vector field living on edges
#
#  Poisson Solve:
#
#  u = obj.PoissonSolve(f)
#       solves the Poisson equation L u = f, where L is the Laplacian on
#       the 3-torus (negative semidefinite convension).
#       u and f has zero mean.
#


function ndgrid{T}(vs::AbstractVector{T}...)
    n = length(vs)
    sz = map(length, vs)
    out = ntuple(i->Array(T, sz), n)
    s = 1
    for i=1:n
        a = out[i]::Array
        v = vs[i]
        snext = s*size(a,i)
        ndgrid_fill(a, v, s, snext)
        s = snext
    end
    out
end
type TorusDEC
    px::Array{Float64,3}; py::Array{Float64,3}; pz::Array{Float64,3}          # coordinates of grid points
    ix::UnitRange{Int}; iy::UnitRange{Int}; iz::UnitRange{Int}          # 1D index array
    iix::Array{Int, 3}; iiy::Array{Int, 3}; iiz::Array{Int, 3}         # 3D index array
    dx::Float64; dy::Float64; dz::Float64          # edge length
    sizex::Int; sizey::Int; sizez::Int # size of grid
    resx::Int; resy::Int; resz::Int    # number of grid points in each dimension

    function TorusDEC(varargin...)
        n = length(varargin)
        if n == 0 # empty instance
            return
        elseif n == 4
            mi = findmax(varargin[1:3])
            ratio = [varargin[1:3]...]./varargin[mi]
            res = round(ratio*varargin[4])
            return TorusDEC(varargin[1:3],res[1],res[2],res[3])
        elseif n == 6
            obj = new()
            obj.sizex = varargin[1];
            obj.sizey = varargin[2];
            obj.sizez = varargin[3];
            obj.resx = round(Int, varargin[4]);
            obj.resy = round(Int, varargin[5]);
            obj.resz = round(Int, varargin[6]);
            obj.dx = obj.sizex/obj.resx;
            obj.dy = obj.sizey/obj.resy;
            obj.dz = obj.sizez/obj.resz;
            obj.ix = 1:obj.resx;
            obj.iy = 1:obj.resy;
            obj.iz = 1:obj.resz;
            obj.iix,obj.iiy,obj.iiz = ndgrid(obj.ix,obj.iy,obj.iz)
            obj.px = (obj.iix-1)*obj.dx;
            obj.py = (obj.iiy-1)*obj.dy;
            obj.pz = (obj.iiz-1)*obj.dz;
            return obj
        end
        error(
            "TorusDEC:badinput
            Wrong number of inputs."
        )
    end
end



function DerivativeOfFunction{T}(obj::TorusDEC, f::Array{T, 3})
    ixp = mod(obj.ix, obj.resx) + 1
    iyp = mod(obj.iy, obj.resy) + 1
    izp = mod(obj.iz, obj.resz) + 1
    vx = sub(f, ixp,:,:) - f
    vy = sub(f, :,iyp,:) - f
    vz = sub(f, :,:,izp) - f
    vx, vy, vz
end

function DerivativeOfOneForm(obj::TorusDEC,vx,vy,vz)
    ixp = mod(obj.ix, obj.resx) + 1
    iyp = mod(obj.iy, obj.resy) + 1
    izp = mod(obj.iz, obj.resz) + 1
    wx = vy - sub(vy, :,:,izp) + sub(vz, :,iyp,:) - vz
    wy = vz - sub(vz, ixp,:,:) + sub(vx, :,:,izp) - vx
    wz = vx - sub(vx, :,iyp,:) + sub(vy, ixp,:,:) - vy
    wx,wy,wz
end

@acc function DerivativeOfTwoForm(obj::TorusDEC,wx,wy,wz)
    ixp = mod(obj.ix, obj.resx) + 1
    iyp = mod(obj.iy, obj.resy) + 1
    izp = mod(obj.iz, obj.resz) + 1
    f =     sub(wx, ixp,:,:) - wx
    f = f + sub(wy, :,iyp,:) - wy
    f = f + sub(wz, :,:,izp) - wz
    f
end

@acc function Div(obj::TorusDEC,vx,vy,vz)
    ixm = mod(obj.ix-2, obj.resx) + 1
    iym = mod(obj.iy-2, obj.resy) + 1
    izm = mod(obj.iz-2, obj.resz) + 1
    f =     (vx - sub(vx, ixm,:,:))/(obj.dx^2)
    f = f + (vy - sub(vy, :,iym,:))/(obj.dy^2)
    f = f + (vz - sub(vz, :,:,izm))/(obj.dz^2)
    f
end

@acc function Sharp(obj::TorusDEC,vx,vy,vz)
    ixm = mod(obj.ix-2,obj.resx) + 1
    iym = mod(obj.iy-2,obj.resy) + 1
    izm = mod(obj.iz-2,obj.resz) + 1
    ux = 0.5*( sub(vx, ixm,:,:) + vx )/obj.dx
    uy = 0.5*( sub(vy, :,iym,:) + vy )/obj.dy
    uz = 0.5*( sub(vz, :,:,izm) + vz )/obj.dz
    ux,uy,uz
end

@acc function StaggeredSharp(obj::TorusDEC,vx,vy,vz)
    ux = vx.*(1./obj.dx)
    uy = vy.*(1./obj.dy)
    uz = vz.*(1./obj.dz)
    ux,uy,uz
end


@acc function PoissonSolve(obj, f)
    f = fft(f)
    sx = sin(3.1415926535897*(obj.iix-1)/obj.resx)/obj.dx
    sy = sin(3.1415926535897*(obj.iiy-1)/obj.resy)/obj.dy
    sz = sin(3.1415926535897*(obj.iiz-1)/obj.resz)/obj.dz
    denom = sx.^2 + sy.^2 + sz.^2
    fac = -0.25./denom
    fac[1,1,1] = 0.0
    f = f .* fac
    ifft(f)
end