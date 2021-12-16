from build import *

class Dep1(Recipe):
    description = "Dep 1"
    license = "MIT"
    build_requires = ("compiler/[^1.0.0]")