function love.conf(t)
	t.window.icon 	= nil
	t.window.title  = "Polygon Jumble Texture Editor"

	t.console = true
	t.version = "11.3"

	t.window.width     	= 900
	t.window.height    	= 720
	t.window.resizable 	= false
	t.window.display 	= 1
	t.window.fullscreen = false

	t.window.vsync = true
	t.window.msaa = 16
end