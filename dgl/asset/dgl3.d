/*
Copyright (c) 2016 Timur Gafarov 

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

module dgl.asset.dgl3;

import std.stdio;
import dlib.core.memory;
import dlib.core.stream;
import dlib.filesystem.stdfs;
import dlib.math.vector;
import dlib.math.quaternion;
import dlib.container.dict;
import dgl.graphics.material;
import dgl.graphics.texture;
import dgl.asset.resource;
import dgl.asset.serialization;
import dgl.asset.trimesh;
import dgl.asset.entity;
import dgl.asset.props;

class DGL3MaterialResource: Resource
{
    ResourceManager resourceManager;
    
    Properties props;
    Material material;

    this(ResourceManager resman)
    {
        resourceManager = resman;
        props = New!Properties();
        material = New!Material();
    }
    
    bool loadThreadSafePart(InputStream istrm)
    {
        string input = readText(istrm);
        bool res = props.parse(input);
        Delete(input);
        if ("ambientColor" in props)
            material.ambientColor = props["ambientColor"].toColor4f;
        if ("diffuseColor" in props)
            material.diffuseColor = props["diffuseColor"].toColor4f;
        if ("specularColor" in props)
            material.specularColor = props["specularColor"].toColor4f;
        if ("emissionColor" in props)
            material.emissionColor = props["emissionColor"].toColor4f;
        if ("diffuseTexture" in props)
        {
            string texName = props["diffuseTexture"].toString;
            material.textures[0] = loadTexture(texName);
        }
        if ("normalTexture" in props)
        {
            string texName = props["normalTexture"].toString;
            material.textures[1] = loadTexture(texName);
        }       
        if ("emissionTexture" in props)
        {
            string texName = props["emissionTexture"].toString;
            material.textures[2] = loadTexture(texName);
        }
        if ("ambientTexture" in props)
        {
            string texName = props["ambientTexture"].toString;
            material.textures[3] = loadTexture(texName);
        }
        if ("shadeless" in props)
            material.shadeless = props["shadeless"].toBool;
        if ("matcap" in props)
            material.matcap = props["matcap"].toBool;
        if ("receiveShadows" in props)
            material.receiveShadows = props["receiveShadows"].toBool;
        if ("doubleSided" in props)
            material.doubleSided = props["doubleSided"].toBool;
        if ("specularity" in props)
            material.specularity = props["specularity"].toFloat;  
        if ("roughness" in props)
            material.roughness = props["roughness"].toFloat;  
        if ("useTextures" in props)
            material.useTextures = props["useTextures"].toBool;
        if ("additiveBlending" in props)
            material.additiveBlending = props["additiveBlending"].toBool;
        if ("useGLSL" in props)
            material.useGLSL = props["useGLSL"].toBool; 
        if ("useFog" in props)
            material.useFog = props["useFog"].toBool;  
  
        // TODO: bump, parallax, glowMap
        
        return res;
    }
    
    bool loadThreadUnsafePart()
    {
        return true;
    }
    
    Texture loadTexture(string filename)
    {
        Texture tex = null;
        
        if (filename in resourceManager.resources)
        {
            tex = resourceManager.getTexture(filename);
        }
        else
        {
            TextureResource texres = New!TextureResource(resourceManager.imageFactory);
            resourceManager.loadResourceThreadSafePart(texres, filename);
            tex = texres.texture;
            resourceManager.addResource(filename, texres);
        }
        
        return tex;
    }
    
    ~this()
    {
        Delete(props);
        Delete(material);
    }
}

class DGL3Resource: Resource
{
    ResourceManager resourceManager;
    
    string name;
    string creator;
    ubyte[] metadata;
    Trimesh[] meshes;
    DGL3Entity[] entities;

    Dict!(Trimesh, string) meshesByName;
    Dict!(DGL3Entity, string) entitiesByName;
    Dict!(Material, string) materialsByName;

    Material defaultMaterial;
    
    this(ResourceManager resman, Material defaultMaterial)
    {
        this.resourceManager = resman;
        this.defaultMaterial = defaultMaterial;

        this.meshesByName = New!(Dict!(Trimesh, string));
        this.entitiesByName = New!(Dict!(DGL3Entity, string));
        this.materialsByName = New!(Dict!(Material, string));
    }

    bool loadThreadSafePart(InputStream istrm)
    {
        readDGL3(resourceManager, istrm, this);
        return true;
    }

    bool loadThreadUnsafePart()
    {
        return true;
    }

    ~this()
    {
        if (name.length)
            Delete(name);
        if (creator.length)
            Delete(creator);
        if (metadata.length)
            Delete(metadata);

        Delete(meshesByName);
        Delete(entitiesByName);
        Delete(materialsByName);

        foreach(mesh; meshes)
            Delete(mesh);
        if (meshes.length)
            Delete(meshes);
        foreach(entity; entities)
            Delete(entity);
        if (entities.length)
            Delete(entities);
    }
}

Vector2f readVector2f(InputStream istrm)
{
    ubyte[2*4] bytes;
    istrm.fillArray(bytes);
    return *cast(Vector2f*)bytes.ptr;
}

Vector3f readVector3f(InputStream istrm)
{
    ubyte[3*4] bytes;
    istrm.fillArray(bytes);
    return *cast(Vector3f*)bytes.ptr;
}

Vector4f readVector4f(InputStream istrm)
{
    ubyte[4*4] bytes;
    istrm.fillArray(bytes);
    return *cast(Vector4f*)bytes.ptr;
}

Quaternionf readQuaternionf(InputStream istrm)
{
    ubyte[4*4] bytes;
    istrm.fillArray(bytes);
    return *cast(Quaternionf*)bytes.ptr;
}

string readString(InputStream istrm, int len)
{
    auto rawData = New!(ubyte[])(len);
    istrm.fillArray(rawData);
    return cast(string)rawData[0..$];
}

ubyte[] readRawData(InputStream istrm, int len)
{
    auto rawData = New!(ubyte[])(len);
    istrm.fillArray(rawData);
    return rawData;
}

void readMesh(InputStream istrm, Trimesh mesh)
{
    mesh.id = istrm.read!int;
    int meshNameSize = istrm.read!int;  
    mesh.name = istrm.readString(meshNameSize);
    int meshIsExternal = istrm.read!int;
    string externalMeshFilename;
    if (meshIsExternal)
    {
        int externalMeshFilenameSize = istrm.read!int;
        if (externalMeshFilenameSize)
        {
            externalMeshFilename = istrm.readString(externalMeshFilenameSize);
            // TODO
            Delete(externalMeshFilename);
        }
    }
    else
    {
        int numVertices = istrm.read!int;
        if (numVertices)
        {
            ubyte[] verticesBytes = istrm.readRawData(numVertices * 12); // 3x4 bytes per vertex
            mesh.vertices = cast(Vector3f[])verticesBytes;

            ubyte[] normalsBytes = istrm.readRawData(numVertices * 12); // 3x4 bytes per vertex
            mesh.normals = cast(Vector3f[])normalsBytes;

            ubyte[] texcoordsBytes = istrm.readRawData(numVertices * 8); // 2x4 bytes per vertex
            mesh.texcoords = cast(Vector2f[])texcoordsBytes;

            int haveLightmapTexCoords = istrm.read!int;
            if (haveLightmapTexCoords)
            {
                ubyte[] haveLightmapTexCoordsBytes = istrm.readRawData(numVertices * 8);
                mesh.lightmapTexcoords = cast(Vector2f[])haveLightmapTexCoordsBytes;
            }
        }

        int numTriangles = istrm.read!int;
        if (numTriangles)
        {
            ubyte[] trianglesBytes = istrm.readRawData(numTriangles * 12); // 3x4 bytes per triangle
            mesh.triangles = cast(int[3][])trianglesBytes;
        }

        int haveSkeletalAnimation = istrm.read!int;
        int haveMorphTargetAnimation = istrm.read!int;  
    }
}

//version = DGL3Debug;

void readEntity(InputStream istrm, DGL3Entity entity)
{
    entity.id = istrm.read!int;
    int entityNameSize = istrm.read!int;  
    string entityName = istrm.readString(entityNameSize);
    entity.name = entityName;
    int entityIsExternal = istrm.read!int;
    string externalEntityFilename;
    if (entityIsExternal)
    {
        int externalEntityFilenameSize = istrm.read!int;
        if (externalEntityFilenameSize)
        {
            externalEntityFilename = istrm.readString(externalEntityFilenameSize);
            // TODO
            Delete(externalEntityFilename);
        }
    }
    int entityMeshId = istrm.read!int; 

    version(DGL3Debug)
    {
        writefln("entity.id: %s", entity.id);
        writefln("entityName: %s", entityName);
        writefln("entityMeshId: %s", entityMeshId);
    }

    Vector3f position = istrm.readVector3f;
    Quaternionf rotation = istrm.readQuaternionf;
    Vector3f scaling = istrm.readVector3f;

    entity.setTransformation(position, rotation, scaling);
    entity.meshID = entityMeshId;

    version(DGL3Debug)
    {
        writefln("entity.position: %s", entity.position);
        writefln("entity.rotation: %s", entity.rotation);
        writefln("entity.scaling: %s", entity.scaling);
    }

    int numCustomProperties = istrm.read!int;

    if (numCustomProperties)
    {
        foreach(propi; 0..numCustomProperties)
        {
            int propNameSize = istrm.read!int;
            string propName = istrm.readString(propNameSize);
            int propType = istrm.read!int;
            Property prop;
            if (propType == 0)
                prop = Property(istrm.read!int);
            else if (propType == 1)
                prop = Property(istrm.read!float);
            else if (propType == 2)
                prop = Property(istrm.readVector2f);
            else if (propType == 3)
                prop = Property(istrm.readVector3f);
            else if (propType == 4)
                prop = Property(istrm.readVector4f);
            else if (propType == 5)
            {
                int propStrSize = istrm.read!int;
                prop = Property(istrm.readString(propStrSize));
            }
            version(DGL3Debug)
            {
                writefln("entity.%s = %s", propName, prop);
            }
            entity.props[propName] = prop;
        }
    }
}

void readDGL3(ResourceManager resman, InputStream istrm, DGL3Resource scene)
{
    // Read magic string
    char[4] magic;
    istrm.fillArray(magic);
    version(DGL3Debug)
    {
        writeln(magic);
    }
    assert(magic == "DGL3");
    
    // Read file header
    int formatVersion = istrm.read!int;
    version(DGL3Debug)
    {
        writefln("formatVersion: %s", formatVersion);
    }
    assert(formatVersion == 300);
    
    int nameSize = istrm.read!int;   
    int creatorNameSize = istrm.read!int;    
    int dataSize = istrm.read!int;
    
    version(DGL3Debug)
    {
        writefln("nameSize: %s", nameSize);
        writefln("creatorNameSize: %s", creatorNameSize);
        writefln("dataSize: %s", dataSize);
    }

    if (nameSize)
        scene.name = istrm.readString(nameSize);
    
    if (creatorNameSize)
        scene.creator = istrm.readString(creatorNameSize);
    
    if (dataSize)
        scene.metadata = istrm.readRawData(dataSize);

    version(DGL3Debug)
    {
        writefln("scene.name: %s", scene.name);
        writefln("scene.creator: %s", scene.creator);
        writefln("scene.metadata: %s", scene.metadata);
    }

    // Read scene header
    int numMeshes = istrm.read!int;
    int numEntities = istrm.read!int;
    int numLights = istrm.read!int;

    version(DGL3Debug)
    {
        writefln("numMeshes: %s", numMeshes);
        writefln("numEntities: %s", numEntities);
        writefln("numLights: %s", numLights);
    }

    // Read meshes
    scene.meshes = New!(Trimesh[])(numMeshes);
    foreach(i; 0..numMeshes)
    {
        version(DGL3Debug)
        {
            writeln("-----");
        }

        Trimesh mesh = New!Trimesh;
        readMesh(istrm, mesh);
        mesh.generateTangents();
        mesh.calcBoundingGeometry();

        version(DGL3Debug)
        {
            writefln("mesh.id: %s", mesh.id);
            writefln("mesh.name: %s", mesh.name);
            writefln("mesh.vertices.length: %s", mesh.vertices.length);
            writefln("mesh.triangles.length: %s", mesh.triangles.length);
        }

        scene.meshes[i] = mesh;
        scene.meshesByName[mesh.name] = mesh;
    }

    // Read entities
    scene.entities = New!(DGL3Entity[])(numEntities);
    foreach(i; 0..numEntities)
    {
        version(DGL3Debug)
        {
            writeln("-----");
        }

        DGL3Entity entity = New!DGL3Entity;
        readEntity(istrm, entity);
        entity.model = scene.meshes[entity.meshID];
        scene.entities[i] = entity;
        scene.entitiesByName[entity.name] = entity;
    }
    
    foreach(e; scene.entities)
    {
        if ("material" in e.props)
        {
            string matName = e.props["material"].toString;

            if (matName == "__default__.mat")
            {
                e.material = scene.defaultMaterial;
                continue;
            }
            
            DGL3MaterialResource matRes;
            if (matName in resman.resources)
            {
                matRes = cast(DGL3MaterialResource)resman.resources[matName];
                if (matRes)
                    e.material = matRes.material;
                else
                {
                    writefln("Warning: invalid material resource \"%s\" for entity \"%s\", using default", matName, e.name);
                    e.material = scene.defaultMaterial;
                }
            }
            else
            {
                if (resman.fileExists(matName))
                {
                    matRes = New!DGL3MaterialResource(resman);
                    resman.loadResourceThreadSafePart(matRes, matName);
                    resman.addResource(matName, matRes);
                    e.material = matRes.material;
                    scene.materialsByName[matName] = matRes.material;
                }
                else
                {
                    writefln("Warning: cannot find material \"%s\" for entity \"%s\", using default", matName, e.name);
                    e.material = scene.defaultMaterial;
                }
            }
        }
        else
        {
            writefln("Warning: no material specified for entity \"%s\", using default", e.name);
            e.material = scene.defaultMaterial;
        }
    }
}

