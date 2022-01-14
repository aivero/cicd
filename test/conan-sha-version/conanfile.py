from build import *


class ConanRecipe(Recipe):
    description = "Conan sha test recipe"
    license = "custom"

    def build(self):
        print(f"Build: {self.name}")