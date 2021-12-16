from build import *

class Pkg(Recipe):
    description = "Pkg"
    license = "MIT"
    build_requires = ("compiler/[^1.0.0]")
    requires = ("dep2/[^1.0.0]", "dep3/[^1.0.0]")