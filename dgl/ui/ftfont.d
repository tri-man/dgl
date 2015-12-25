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

module dgl.ui.ftfont;

import std.stdio;

import std.string;
import std.ascii;
import std.utf;
import std.file;

import dlib.core.memory;
//import dlib.container.bst;
import dlib.container.dict;
import dlib.text.utf8;

import derelict.opengl.gl;
import derelict.freetype.ft;

import dgl.ui.font;

struct Glyph
{
    GLuint textureId = 0;
    FT_Glyph ftGlyph = null;
    int width = 0;
    int height = 0;
    FT_Pos advanceX = 0;
}

int nextPowerOfTwo(int a)
{
    int rval = 1;
    while(rval < a)
        rval <<= 1;
    return rval;
}

/*
class CharStorage(T): BST!(T)
{
    this()
    {
        super();
    }

    void opIndexAssign(T v, dchar k)
    {
        insert(k, v);
    }

    T opIndex(dchar k)
    {
        auto node = find(k);
        if (node is null)
            return value.init;
        else
            return node.value;
    }

    T* opIn_r(dchar k)
    {
        auto node = find(k);
        if (node !is null)
            return &node.value;
        else
            return null;
    }

    size_t length()
    {
        uint len = 1;
        foreach(i, glyph; this)
            len++;
        return len;
    }
}
*/

final class FreeTypeFont: Font
{
    FT_Face ftFace;
    FT_Library ftLibrary;

    //CharStorage!Glyph glyphs;
    Dict!(Glyph, dchar) glyphs;

    this(string filename, uint height)
    {
        enum ASCII_CHARS = 128;
        this.height = height;

        if (FT_Init_FreeType(&ftLibrary))
            throw new Exception("FT_Init_FreeType failed");

        if (!exists(filename))
            throw new Exception("Cannot find font file " ~ filename);

        if (FT_New_Face(ftLibrary, toStringz(filename), 0, &ftFace))
            throw new Exception("FT_New_Face failed (there is probably a problem with your font file)");

        FT_Set_Char_Size(ftFace, height << 6, height << 6, 96, 96);

        glyphs = New!(Dict!(Glyph, dchar));

        foreach(i; 0..ASCII_CHARS)
        {
            GLuint tex;
            glGenTextures(1, &tex);
            loadGlyph(i, tex);
        }
    }

    ~this()
    {
        //writefln("Deleting %s glyph(s) in FTFont...", glyphs.length);
        foreach(i, glyph; glyphs)
            glDeleteTextures(1, &glyph.textureId);
        Delete(glyphs);
    }

    void free()
    {
        Delete(this);
    }

    uint loadGlyph(dchar code, GLuint texId)
    {
        uint charIndex = FT_Get_Char_Index(ftFace, code);

        if (charIndex == 0)
        {
            //TODO: if character wasn't found in font file
        }

        if (FT_Load_Glyph(ftFace, charIndex, FT_LOAD_DEFAULT))
            throw new Exception("FT_Load_Glyph failed");

        FT_Glyph glyph;
        if (FT_Get_Glyph(ftFace.glyph, &glyph))
            throw new Exception("FT_Get_Glyph failed");

        FT_Glyph_To_Bitmap(&glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL, null, 1);
        FT_BitmapGlyph bitmapGlyph = cast(FT_BitmapGlyph)glyph;

        FT_Bitmap bitmap = bitmapGlyph.bitmap;

        int width = nextPowerOfTwo(bitmap.width);
        int height = nextPowerOfTwo(bitmap.rows);

        GLubyte[] img = New!(GLubyte[])(2 * width * height);

        foreach(j; 0..height)
        foreach(i; 0..width)
        {
            img[2 * (i + j * width)] = 255;
            img[2 * (i + j * width) + 1] =
                (i >= bitmap.width || j >= bitmap.rows)?
                 0 : bitmap.buffer[i + bitmap.width * j];
        }

        glBindTexture(GL_TEXTURE_2D, texId);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glTexImage2D(GL_TEXTURE_2D,
            0, GL_RGBA, width, height,
            0, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, img.ptr);

        Delete(img);

        Glyph g = Glyph(texId, glyph, width, height, ftFace.glyph.advance.x);
        glyphs[code] = g;

        return charIndex;
    }

    dchar loadChar(dchar code)
    {
        GLuint tex;
        glGenTextures(1, &tex);
        loadGlyph(code, tex);
        return code;
    }

    float renderGlyph(dchar code)
    {
        Glyph glyph;
        if (code in glyphs)
            glyph = glyphs[code];
        else
            glyph = glyphs[loadChar(code)];

        FT_BitmapGlyph bitmapGlyph = cast(FT_BitmapGlyph)(glyph.ftGlyph);
        FT_Bitmap bitmap = bitmapGlyph.bitmap;

        glBindTexture(GL_TEXTURE_2D, glyph.textureId);

        glPushMatrix();
        glTranslatef(bitmapGlyph.left, 0, 0);

        float chWidth = cast(float)bitmap.width;
        float chHeight = cast(float)bitmap.rows;
        float texWidth = cast(float)glyph.width;
        float texHeight = cast(float)glyph.height;

        glTranslatef(0, bitmapGlyph.top - bitmap.rows, 0);
        float x = 0.5f / texWidth + chWidth / texWidth;
        float y = 0.5f / texHeight + chHeight / texHeight;
        glBegin(GL_QUADS);
            glTexCoord2f(0, 0); glVertex2f(0, bitmap.rows);
            glTexCoord2f(0, y); glVertex2f(0, 0);
            glTexCoord2f(x, y); glVertex2f(bitmap.width, 0);
            glTexCoord2f(x, 0); glVertex2f(bitmap.width, bitmap.rows);
        glEnd();
        glPopMatrix();
        float shift = glyph.advanceX >> 6;
        glTranslatef(shift, 0, 0);

        glBindTexture(GL_TEXTURE_2D, 0);

        return shift;
    }

    int glyphAdvance(dchar code)
    {
        Glyph glyph;
        if (code in glyphs)
            glyph = glyphs[code];
        else
            glyph = glyphs[loadChar(code)];
        return cast(int)(glyph.advanceX >> 6);
    }

    import std.stdio;

    override void draw(string str)
    {
        UTF8Decoder dec = UTF8Decoder(str);
        //foreach(ch; /*stride(str, 1)*/ byDchar(str))
        int ch;
        do
        {
            ch = dec.decodeNext();
            //writeln(ch);
            if (ch == 0 || ch == UTF8_END || ch == UTF8_ERROR) break;
            dchar code = ch;
            if (code.isASCII)
            {
                if (code.isPrintable)
                    renderGlyph(code);
            }
            else
                renderGlyph(code);
        } while(ch != UTF8_END && ch != UTF8_ERROR);
    }

    override float textWidth(string str)
    {
        float width = 0.0f;
        UTF8Decoder dec = UTF8Decoder(str);
        //foreach(ch;  /*stride(str, 1)*/ byDchar(str))
        int ch;
        do
        {
            ch = dec.decodeNext();
            if (ch == 0 || ch == UTF8_END || ch == UTF8_ERROR) break;
            dchar code = ch;
            if (code.isASCII)
            {
                if (code.isPrintable)
                    width += glyphAdvance(code);
            }
            else
                width += glyphAdvance(code);
        } while(ch != UTF8_END && ch != UTF8_ERROR);

        return width;
    }
}
