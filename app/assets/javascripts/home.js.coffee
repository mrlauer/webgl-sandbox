# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$ ->
    $('#window-width-slider').slider()

    $.ajax '/binary', {
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
        }
     
