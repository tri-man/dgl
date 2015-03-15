/*
Copyright (c) 2014-2015 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dgl.asset.entity;

import std.json;

import derelict.opengl.gl;
import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.geometry.aabb;
import dgl.core.interfaces;
import dgl.graphics.object3d;

class Entity: Object3D
{
    Drawable drawable;
    Modifier modifier;
    Matrix4x4f transformation;
    
    this(Drawable drw, Vector3f position)
    {
        transformation = translationMatrix(position);
        drawable = drw;
    }
    
    this(Vector3f position)
    {
        transformation = translationMatrix(position);
        drawable = null;
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }
    
    override AABB getAABB()
    {
        return AABB(transformation.translation, Vector3f(1, 1, 1));
    }
    
    override void draw(double dt)
    {
        if (modifier !is null)
            modifier.bind(dt);
            
        if (drawable !is null)
        {
            glPushMatrix();
            glMultMatrixf(transformation.arrayof.ptr);
            drawable.draw(dt);
            glPopMatrix();
        }
        
        if (modifier !is null)
            modifier.unbind();
    }
    
    override void free()
    {
        Delete(this);
    }
    
    mixin ManualModeImpl;
}