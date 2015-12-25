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

module gdl.templates.freeview;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;

import dgl.core.api;
import dgl.core.event;
import dgl.graphics.tbcamera;
import dgl.templates.app3d;

class Freeview: EventListener
{
    TrackballCamera camera;
    int prevMouseX;
    int prevMouseY;

    this(EventManager emngr)
    {
        super(emngr);
        camera = New!TrackballCamera();
        camera.pitch(45.0f);
        camera.turn(45.0f);
        camera.setZoom(20.0f);
    }

    ~this()
    {
        Delete(camera);
    }

    override void onMouseButtonDown(int button)
    {
        if (button == SDL_BUTTON_MIDDLE)
        {
            prevMouseX = eventManager.mouseX;
            prevMouseY = eventManager.mouseY;
        }
        else if (button == SDL_BUTTON_WHEELUP)
        {
            camera.zoom(1.0f);
        }
        else if (button == SDL_BUTTON_WHEELDOWN)
        {
            camera.zoom(-1.0f);
        }
    }

    void update()
    {
        processEvents();

        if (eventManager.mouseButtonPressed[SDL_BUTTON_MIDDLE] && eventManager.keyPressed[SDLK_LSHIFT])
        {
            float shift_x = (eventManager.mouseX - prevMouseX) * 0.1f;
            float shift_y = (eventManager.mouseY - prevMouseY) * 0.1f;
            Vector3f trans = camera.getUpVector * shift_y + camera.getRightVector * shift_x;
            camera.translateTarget(trans);
        }
        else if (eventManager.mouseButtonPressed[SDL_BUTTON_MIDDLE] && eventManager.keyPressed[SDLK_LCTRL])
        {
            float shift_x = (eventManager.mouseX - prevMouseX);
            float shift_y = (eventManager.mouseY - prevMouseY);
            camera.zoom((shift_x + shift_y) * 0.1f);
        }
        else if (eventManager.mouseButtonPressed[SDL_BUTTON_MIDDLE])
        {                
            float turn_m = (eventManager.mouseX - prevMouseX);
            float pitch_m = -(eventManager.mouseY - prevMouseY);
            camera.pitch(pitch_m);
            camera.turn(turn_m);
        }

        prevMouseX = eventManager.mouseX;
        prevMouseY = eventManager.mouseY;
        
        camera.update();
    }

    Matrix4x4f getCameraMatrix()
    {
        return camera.getInvTransformation();
    }
}

class FreeviewApplication: Application3D
{
    Freeview freeview;

    this()
    {
        super();
        freeview = New!Freeview(eventManager);
    }
    
    ~this()
    {
        Delete(freeview);
    }
    
    override void onUpdate(double dt)
    {
        super.onUpdate(dt);
        freeview.update();
        setCameraMatrix(freeview.getCameraMatrix());
    }
}

