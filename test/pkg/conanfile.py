from build import *

class Pkg(Recipe):
    description = "Pkg"
    license = "MIT"
    requires = ("dep2/[^1.0.0]")