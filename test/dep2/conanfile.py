from build import *

class Dep2(Recipe):
    description = "Dep 2"
    license = "MIT"
    build_requires = ("compiler/[^1.0.0]")
    requires = ("dep1/[^1.0.0]")