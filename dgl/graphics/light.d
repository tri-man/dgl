﻿/*
Copyright (c) 2015 Timur Gafarov

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

module dgl.graphics.light;

import derelict.opengl.gl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.image.color;
import dlib.container.array;

import dgl.core.interfaces;
import dgl.graphics.entity;
import dgl.graphics.scene;

class Light: Drawable
{
    Vector4f position;
    Color4f diffuseColor;
    Color4f ambientColor;
    float constantAttenuation;
    float linearAttenuation;
    float quadraticAttenuation;
    float brightness;
    bool enabled = true;
    bool debugDraw = false;
    bool forceOn = false;
    bool highPriority = false;

    this(
        Vector4f position,
        Color4f diffuseColor,
        Color4f ambientColor,
        float constantAttenuation,
        float linearAttenuation,
        float quadraticAttenuation)
    {
        this.position = position;
        this.diffuseColor = diffuseColor;
        this.ambientColor = ambientColor;
        this.constantAttenuation = constantAttenuation;
        this.linearAttenuation = linearAttenuation;
        this.quadraticAttenuation = quadraticAttenuation;
    }

    void draw(double dt)
    {
        if (debugDraw)
        {
            glDisable(GL_LIGHTING);
            glColor4fv(diffuseColor.arrayof.ptr);
            glPointSize(5.0f);
            glBegin(GL_POINTS);
            glVertex3f(0, 0, 0);
            glEnd();
            glPointSize(1.0f);
            glEnable(GL_LIGHTING);
        }
    }
}

Light pointLight(
    Vector3f pos,
    Color4f diffuseColor,
    Color4f ambientColor,
    float constantAttenuation = 0.5f,
    float linearAttenuation = 0.0f,
    float quadraticAttenuation = 0.1f)
{
    return New!Light(
        Vector4f(pos.x, pos.y, pos.z, 1.0f),
        diffuseColor, ambientColor,
        constantAttenuation, linearAttenuation,
        quadraticAttenuation);
}

enum maxLightsPerObject = 4;

class LightManager
{
    DynamicArray!Light lights;

    bool lightsVisible = false;
    bool lightsOn = true;
    bool useUpdateTreshold = false;
    Vector3f referencePoint = Vector3f(0, 0, 0);
    float updateThreshold = 400.0f;

    Light addLight(Light light)
    {
        lights.append(light);
        return light;
    }

    Light addPointLight(Vector3f position)
    {
        Light light = pointLight(
            position,
            Color4f(1.0f, 1.0f, 1.0f, 1.0f),
            Color4f(0.1f, 0.1f, 0.1f, 1.0f));
        lights.append(light);
        return light;
    }

    void calcLighting(Scene s)
    {
        foreach(e; s.entities)
            if (e.visible && !e.shadeless)
                calcLighting(e);
    }

    void calcLighting(Entity e)
    {
        Vector3f ePos = e.position;
        if (useUpdateTreshold)
        {
            if ((ePos - referencePoint).lengthsqr < updateThreshold)
                calcLighting(ePos);
        }
        else
            calcLighting(ePos);

        sortLights();

        e.numLights = 0;
        foreach(i; 0..maxLightsPerObject)
        if (i < lights.length)
        {
            e.lights[i] = lights.data[i];
            e.numLights++;
        }
    }

    void calcLighting(Vector3f pos)
    {
        auto ldata = lights.data;
        foreach(light; ldata)
            if (lightsOn || light.forceOn)
                calcBrightness(light, pos);
    }

    void calcBrightness(Light light, Vector3f objPos)
    {
        if (!light.enabled && !light.forceOn)
        {
            light.brightness = 0.0f;
        }
        else
        {
            Vector3f d = (light.position.xyz - objPos);
            float distSqr = d.lengthsqr;
            if (light.highPriority && distSqr < 50)
                light.brightness = float.max;
            else
                light.brightness = 1.0f / distSqr;
        }
    }

    void sortLights()
    {
        size_t j = 0;
        Light tmp;

        auto ldata = lights.data;

        foreach(i, v; ldata)
        {
            j = i;
            size_t k = i;

            while (k < ldata.length)
            {
                float b1 = ldata[j].brightness;
                float b2 = ldata[k].brightness;
                
                if (b2 > b1)
                    j = k;
                
                k++;
            }

            tmp = ldata[i];
            ldata[i] = ldata[j];
            ldata[j] = tmp;
        }
    }

    static void bindLighting(Entity e)
    {
        glEnable(GL_LIGHTING);
        foreach(i; 0..maxLightsPerObject)
        if (i < e.numLights)
        {
            auto light = e.lights[i];
            if (light.enabled)
            {
                glEnable(GL_LIGHT0 + i);
                glLightfv(GL_LIGHT0 + i, GL_POSITION, light.position.arrayof.ptr);
				glLightfv(GL_LIGHT0 + i, GL_SPECULAR, light.diffuseColor.arrayof.ptr);
                glLightfv(GL_LIGHT0 + i, GL_DIFFUSE, light.diffuseColor.arrayof.ptr);
                glLightfv(GL_LIGHT0 + i, GL_AMBIENT, light.ambientColor.arrayof.ptr);
                glLightf( GL_LIGHT0 + i, GL_CONSTANT_ATTENUATION, light.constantAttenuation);
                glLightf( GL_LIGHT0 + i, GL_LINEAR_ATTENUATION, light.linearAttenuation);
                glLightf( GL_LIGHT0 + i, GL_QUADRATIC_ATTENUATION, light.quadraticAttenuation);
            }
            else
            {
                Vector4f p = Vector4f(0, 0, 0, 2);
                glLightfv(GL_LIGHT0 + i, GL_POSITION, p.arrayof.ptr);
            }
        }
    }

    static void unbindLighting()
    {
        foreach(i; 0..maxLightsPerObject)
            glDisable(GL_LIGHT0 + i);
        glDisable(GL_LIGHTING);
    }
    
/*
    // TODO
    void draw(double dt)
    {
        // Draw lights
        if (lightsVisible)
        {
            glPointSize(5.0f);
            foreach(light; lights.data)
            if (light.debugDraw)
            {
                glColor4fv(light.diffuseColor.arrayof.ptr);
                glBegin(GL_POINTS);
                glVertex3fv(light.position.arrayof.ptr);
                glEnd();
            }
            glPointSize(1.0f);
        }
    }
*/

    void freeLights()
    {
        foreach(light; lights.data)
            Delete(light);
        lights.free();
    }

    ~this()
    {
        freeLights();
    }
}
