/*
Copyright (c) 2015-2016 Timur Gafarov

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

module dgl.asset.resource;

import std.stdio;
import std.path;
import std.string;

import dlib.core.memory;
import dlib.core.stream;
import dlib.core.thread;
import dlib.container.dict;
import dlib.filesystem.filesystem;
import dlib.filesystem.stdfs;
import dlib.image.image;
import dlib.image.unmanaged;
import dlib.image.io.png;

import dgl.vfs.vfs;
//import dgl.graphics.scene;
import dgl.graphics.material;
import dgl.graphics.texture;
import dgl.asset.dgl3;

interface Resource
{
    bool loadThreadSafePart(InputStream istrm);
    bool loadThreadUnsafePart();
}

import core.memory;

class TextureResource: Resource
{
    SuperImage image;
    Texture texture;
    UnmanagedImageFactory imageFactory;
    
    this(UnmanagedImageFactory imgfac)
    {
        texture = New!Texture();
        imageFactory = imgfac;
    }
    
    bool loadThreadSafePart(InputStream istrm)
    {
        if (image !is null)
            return true;
        
        auto res = loadPNG(istrm, imageFactory);
        image = res[0];
        if (image !is null)
        {
            return true;
        }
        else
        {
            writeln(res[1]);
            return false;
        }
    }
    
    bool loadThreadUnsafePart()
    {
        if (image !is null)
        {
            texture.createFromImage(image);
            Delete(image);
            image = null;
            if (texture.valid)
            {
                return true;
            }
            else
                return false;
        }
        else
        {
            return false;
        }
    }
    
    ~this()
    {
        if (image !is null)
            Delete(image);
        Delete(texture);
    }
}

enum ResourceType
{
    Texture,
    DGL3
}

class ResourceManager
{
    VirtualFileSystem fs;
    UnmanagedImageFactory imageFactory;
    Dict!(Resource, string) resources;
    Thread loadingThread;
    Material defaultMaterial;

    // TODO: loading percentage
    
    this(Material defaultMat)
    {
        fs = New!VirtualFileSystem();
        fs.mount(".");
        
        imageFactory = New!UnmanagedImageFactory();
        resources = New!(Dict!(Resource, string));
        loadingThread = New!Thread(&threadFunc);

        defaultMaterial = defaultMat;
    }

    void mountDirectory(string dir)
    {
        fs.mount(dir);
    }
/*
    void umountDirectory(string dir)
    {
        fs.umount(dir);
    }
*/
    Texture loadTexture(string filename)
    {
        Texture tex = null;
        auto fstrm = fs.openForInput(filename);
        assert(fstrm !is null, format("error operning %s", filename));
        auto res = loadPNG(fstrm, imageFactory);
        auto image = res[0];
        if (image !is null)
        {
            tex = New!Texture(image);
            Delete(image);
        }
        Delete(fstrm);
        return tex;
    }
    
    void addResource(string filename, Resource res)
    {
        if (!(filename in resources))
            resources[filename] = res;
    }
    
    Resource addResource(string filename, ResourceType type)
    {        
        if (type == ResourceType.Texture)
        {
            if (!(filename in resources))
            {
                TextureResource res = New!TextureResource(imageFactory);
                resources[filename] = res;
                return res;
            }
            else
            {
                return resources[filename];
            }
        }
        else if (type == ResourceType.DGL3)
        {
            if (!(filename in resources))
            {
                DGL3Resource res = New!DGL3Resource(this, defaultMaterial);
                resources[filename] = res;
                return res;
            }
            else
            {
                return resources[filename];
            }
        }
        else
            assert(0);
    }
    
    TextureResource addTextureResource(string filename)
    {
        return cast(TextureResource)addResource(filename, ResourceType.Texture);
    }
    
    DGL3Resource addDGL3Resource(string filename)
    {
        return cast(DGL3Resource)addResource(filename, ResourceType.DGL3);
    }
    
    void loadThreadSafePart()
    {
        loadingThread.start();
    }
    
    bool isLoading()
    {
        return loadingThread.isRunning;
    }
    
    void loadResourceThreadSafePart(Resource res, string filename)
    {
        if (!fileExists(filename))
        {
            writefln("Warning: cannot find file \"%s\"", filename);
            return;
        }
            
        auto fstrm = fs.openForInput(filename);
          
        if (!res.loadThreadSafePart(fstrm))
            writefln("Warning: error loading file \"%s\"", filename);
            
        Delete(fstrm);
    }

    void threadFunc()
    {
        foreach(filename, resource; resources)
        {
            loadResourceThreadSafePart(resource, filename);
        }
    }
    
    void loadThreadUnsafePart()
    {
        foreach(filename, resource; resources)
        {           
            if (!resource.loadThreadUnsafePart())
            {
                writefln("Warning: failed to load resource \"%s\"", filename);
            }
        }
    }
    
    bool fileExists(string filename)
    {
        FileStat stat;
        return fs.stat(filename, stat);
    }
    
    Texture getTexture(string name)
    {
        return (cast(TextureResource)resources[name]).texture;
    }

    bool textureExists(string name)
    {
        if (name in resources)
            return (cast(TextureResource)resources[name]) !is null;
        else
            return false;
    }

    bool DGLResourceExists(string name)
    {
        if (name in resources)
            return (cast(DGL3Resource)resources[name]) !is null;
        else
            return false;
    }
    
    void freeResources()
    {
        foreach(filename, resource; resources)
            Delete(resource);
        Delete(resources);
        resources = New!(Dict!(Resource, string));
    }
    
    ~this()
    {
        if (loadingThread)
        {
            if (loadingThread.isRunning)
            {
                loadingThread.join();
            }

            Delete(loadingThread);
        }

        Delete(fs);
        Delete(imageFactory);
        foreach(filename, resource; resources)
            Delete(resource);
        Delete(resources);
    }
}
