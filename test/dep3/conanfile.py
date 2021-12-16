from build import *

class Dep3(Recipe):
    description = "Dep 3"
    license = "MIT"
    build_requires = ("compiler/[^1.0.0]")
    requires = ("dep1/[^1.0.0]")
    options = {"test": [True, False]}
    default_options = { "test": False}