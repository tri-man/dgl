/*
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

module dgl.asset.resman;

import std.stdio;
import std.file;
import dlib.core.memory;
import dlib.container.aarray;
import dlib.image.io.png;
import dlib.filesystem.filesystem;
import vegan.stdfs;
import vegan.image;
import dgl.vfs.vfs;
import dgl.graphics.texture;
import dgl.ui.font;
import dgl.asset.scene;
import dgl.graphics.lightmanager;

class ResourceManager: ManuallyAllocatable
{
    VirtualFileSystem fs;
    VeganImageFactory imgFac;
    AArray!Font fonts;
    AArray!Texture textures;
    LightManager lm;
    
    this()
    {
        fs = New!VirtualFileSystem();
        imgFac = New!VeganImageFactory();
        fonts = New!(AArray!Font)();
        textures = New!(AArray!Texture)();
        lm = New!LightManager();
        lm.lightsVisible = true; 
    }

    Font addFont(string name, Font f)
    {
        fonts[name] = f;
        return f;
    }

    Font getFont(string name)
    {
        return fonts[name];
    }

    Texture addTexture(string name, Texture t)
    {
        textures[name] = t;
        return t;
    }
    
    Texture getTexture(string filename)
    {
        if (filename in textures)
            return textures[filename];
            
        writefln("Loading texture %s...", filename);

        if (!fileExists(filename))
        {
            writefln("Warning: cannot find image file (trying to load \'%s\')", filename);
            return null;
        }
        
        auto fstrm = fs.openForInput(filename);
        auto res = loadPNG(fstrm, imgFac);
        fstrm.free();
        
        if (res[0] is null)
        {
            writeln(res[1]);
            return null;
        }
        else
        {
            auto tex = New!Texture(res[0]);
            res[0].free();
            return addTexture(filename, tex);
        }
    }

    void freeFonts()
    {
        foreach(i, f; fonts)
            f.free();
        fonts.free();
    }

    void freeTextures()
    {
        foreach(i, t; textures)
            t.free();
        textures.free();
    }
    
    void free()
    {
        Delete(imgFac);
        fs.free();
        freeFonts();
        freeTextures();
        lm.free();
        Delete(this);
    }

    bool fileExists(string filename)
    {
        FileStat stat;
        return fs.stat(filename, stat);
    }

    // Don't forget to delete the string!
    string readText(string filename)
    {
        auto fstrm = fs.openForInput(filename);
        string text = .readText(fstrm);
        fstrm.free();
        return text;
    }
    
    mixin ManualModeImpl;
}

