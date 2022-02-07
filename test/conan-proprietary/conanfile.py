from build import *


class ConanRecipe(Recipe):
    description = "Conan test recipe"
    license = "Proprietary"

    def build(self):
        print(f"Build: {self.name}")