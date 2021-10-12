from build import *

class Dep2(Recipe):
    description = "Dep 2"
    license = "MIT"
    requires = ("dep1/[^1.0.0]")