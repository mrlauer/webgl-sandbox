#
# Histogram for displaying intensity frequencies, range, threshold, whatever else
#

(($) ->

    combineIntervals = (intervals) ->
        sorted = [intervals...]
        sorted.sort()

        out = []
        for int in sorted
            [..., last] = out
            if not last or int[0] > last[1]
                out.push int.slice()
            else if int[1] > last[1]
                last[1] = int[1]
        out

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
            intervals = combineIntervals self.options.thresholds
            values = [].concat 0, intervals..., 1
            for i in [0 ... values.length] by 2
                [low, high] = values[i..i+1]
                if high > low
                    ctx.fillRect low * w, 0, (high - low) * w, h

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
