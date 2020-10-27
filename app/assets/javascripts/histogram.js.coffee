#
# Histogram for displaying intensity frequencies, range, threshold, whatever else
#

(($) ->
    $.widget "babybrain.histogram",
        options:
            minRange: 0
            maxRange: 1
            thresholds: [[0, 1]]
            rainbow: false
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
            if @options.rainbow
                colors = ColorUtilities.getRainbowColors()
                start = self.options.minRange
                delta = (self.options.maxRange - start) / (colors.length - 1)
                for idx, c of colors
                    gradient.addColorStop start + delta * idx, c
            else
                gradient.addColorStop self.options.minRange, "#000"
                gradient.addColorStop self.options.maxRange, "#fff"
            ctx.fillStyle = gradient
            ctx.fillRect 0, 0, w, h

            # threshold
            ctx.fillStyle = "black"
            [minThreshold, maxThreshold] = self.options.thresholds[0]
            if minThreshold > 0
                ctx.fillRect 0, 0, minThreshold * w, h
            if maxThreshold < 1
                ctx.fillRect maxThreshold * w, 0, (1-maxThreshold)*w, h

            #data
            data = self.options.data
            hColor = if @options.rainbow then "white" else "red"
            ctx.strokeStyle = hColor
            ctx.fillStyle = hColor
            if data
                top = Math.max.apply null, data.max
                top = Math.log top
                scale = h/top
                ctx.beginPath()
                started = false
                for i in [0 .. w]
                    if !data.max[i]?
                        continue
                    min = Math.log(data.min[i] || 1)
                    max = Math.log(data.max[i] || 1)
                    min *= scale
                    max *= scale
                    if started
                        ctx.moveTo 0, h - max
                        started = true
                    ctx.lineTo i, h - max
                    ctx.lineTo i, h - min
                ctx.lineWidth = 2
                ctx.stroke()
                ctx.lineTo w+1, h+1
                ctx.lineTo 0, h+1
                ctx.globalAlpha = 0.3
                ctx.fill()
                ctx.globalAlpha = 1


)(jQuery)
