local pwd = os.getenv('PWD')
package.cpath = pwd..'/lib/?.so;'..package.cpath

local qtcore = require 'qtcore'
local qtgui = require 'qtgui'

--app = QApplication(1 + select('#', ...), {arg[0], ...})
--app.__gc = app.delete -- take ownership of object

a = QString.new("Disziplin ")

print(a:toString())


--app.exec()

