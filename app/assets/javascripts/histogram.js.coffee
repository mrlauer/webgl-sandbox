#
# Histogram for displaying intensity frequencies, range, threshold, whatever else
#

(($) ->
    $.widget "babybrain.histogram",
        options:
            minRange: 0
            maxRange: 1
            minThreshold: 0
            maxThreshold: 1
            data: null
        _create: ->
            # add a canvas
            self = this
            canvas = $('<canvas class="histogram-canvas"></canvas>').appendTo self.element
            canvasDom = canvas.get 0
            canvasDom.width = canvas.width()
            canvasDom.height = canvas.height()
            self.draw()

        draw: ->
            self = this
            canvas = $('canvas', self.element)
            ctx = canvas.get(0).getContext '2d'
            w = canvas.width()
            h = canvas.height()
            gradient = ctx.createLinearGradient 0, 0, w, 0
            gradient.addColorStop self.options.minRange, "#000"
            gradient.addColorStop self.options.maxRange, "#fff"
            ctx.fillStyle = gradient
            ctx.fillRect 0, 0, w, h

            # threshold
            ctx.fillStyle = "black"
            if self.options.minThreshold > 0
                ctx.fillRect 0, 0, self.options.minThreshold * w, h
            if self.options.maxThreshold < 1
                ctx.fillRect self.options.maxThreshold * w, 0, (1-self.options.maxThreshold)*w, h

            #data
            data = self.options.data
            ctx.strokeStyle = "red"
            ctx.fillStyle = "red"
            if data
                top = Math.max.apply null, data.max
                top = Math.log top
                scale = h/top
                ctx.beginPath()
                ctx.moveTo 0, h
                for i in [0 ... w]
                    min = Math.log(data.min[i] ? 1)
                    max = Math.log(data.max[i] ? 1)
                    min *= scale
                    max *= scale
                    ctx.lineTo i, h - max
                    ctx.lineTo i, h - min
                ctx.lineWidth = 2
                ctx.stroke()
                ctx.lineTo w, h
                ctx.globalAlpha = 0.3
                ctx.fill()
                ctx.globalAlpha = 1


)(jQuery)
