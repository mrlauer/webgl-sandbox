# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
    $('#window-width-slider').slider()

    if false
        $.ajax '/binary', 
            type: 'GET',
            success: (data) ->
                # unpack the data; it's 4-byte big-endian
                l = data.length
                nb = l/4
                for i in [0...nb]
                    d = data.charCodeAt(i*4)
                    for j in [1...4]
                        d = d * 256 + data.charCodeAt(i*4+j)
                    $('body').append d + '<br/>'
       
    # gl stuff
    drawScene = () ->
        widget = this
        gl = this.gl
        gl.viewport 0, 0, gl.viewportWidth, gl.viewportHeight
        gl.clear (gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        mat4.identity this.mvMatrix
        mat4.ortho(-1, 1, -1, -1, 1, -1, this.pMatrix)
        
        mat4.identity this.pMatrix

        this.setupShader = ->
            shaderProgram = this.shaderProgram
            lighting = false
            this.uniform1i 'uUseLighting', lighting
            phong = true
            this.uniform1i('uPhong', phong)
            shiny = 8.0
            this.uniform1f("uMaterialShininess", shiny)
            
            this.uniform1i("uShowSpecularHighlights", 1)
            this.uniform3f("uAmbientColor", 0.5, 0.5, 0.5)
            this.uniform3f('uPintLightingLocation', 1.0, 10.0, 4.0)
            this.uniform3f('uPointLightingSpecularColor', 1.0, 1.0, 1.0)
            this.uniform3f('uPointLightingDiffuseColor', 0.5, 0.5, 0.5)
            
            this.enableVertexAttribArray("aUV", false)
            this.enableVertexAttribArray("aVertexPostion")
            this.enableVertexAttribArray("aColor", false)
            this.enableVertexAttribArray("aVertexNormal", true)
            
            this.setUniformMatrices('uMVMatrix', 'uPMatrix', 'uNMatrix')

        this.setupShader()
        this.vertexAttrib4f 'aColor', 1, 0.9, 0, 1

        bds =
            left : -0.5
            right : 0.5
            top : 0.5
            bottom : -0.5
        vertices = [
            bds.left, bds.bottom, 0,
            bds.right, bds.bottom, 0,
            bds.left, bds.top, 0,
            bds.right, bds.top, 0,
        ]
        normals = [
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, 1
        ]
        texsz = 128
#         uvs = [
#             0, texsz-1,
#             texsz-1, texsz-1,
#             0, 0,
#             texsz-1, 0
#         ]
        uvs = [
            0, 0,
            1, 0,
            0, 1,
            1, 1
        ]
        this.setFloatBufferData this.positionBuffer, vertices, 3
        this.setFloatAttribPointer 'aVertexPosition', this.positionBuffer
        this.setFloatBufferData this.normalBuffer, vertices, 3
        this.setFloatAttribPointer 'aVertexNormal', this.normalBuffer
        this.setFloatBufferData this.uvBuffer, uvs, 2
        this.setFloatAttribPointer 'aUV', this.uvBuffer

        this.uniform1i 'uTexture', 0
        this.gl.activeTexture this.gl.TEXTURE0
        gl.bindTexture(gl.TEXTURE_2D, this.texture)
        gl.drawArrays gl.TRIANGLE_STRIP, 0, this.positionBuffer.numItems

    widget = null
    $('#canvas').mrlgl
        initialize: ->
            widget = this
            this.initProgram()
            this.positionBuffer = this.gl.createBuffer()
            this.normalBuffer = this.gl.createBuffer()
            this.uvBuffer = this.gl.createBuffer()
            this.enableVertexAttribArray("aUV", false)
            this.enableVertexAttribArray("aVertexPosition")
            this.gl.clearColor 0, 0, 0, 1
            this.gl.enable this.gl.DEPTH_TEST

        draw : drawScene

    # make a texture
    gl = widget.gl
    texbits = []
    texsz = 128
    texsz2 = texsz/2
    for i in [0...texsz]
        f1 = (i - texsz2)/texsz2
        for j in [0...texsz]
            f2 = (j-texsz2)/texsz2
            z = Math.sqrt(1.0 - f1*f1 - f2*f2)
            z *= 255
            if z < 0
                z = 0
            if z > 255
                z = 255
            texbits.push z
    pixels = new Uint8Array(texbits)
    texture = gl.createTexture()
    gl.bindTexture gl.TEXTURE_2D, texture
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, texsz, texsz, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, pixels)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)

    widget.texture = texture

    widget.draw()
