from build import *


class ConanRecipe(Recipe):
    description = "Conan test recipe"
    license = "custom"

    def build(self):
			  print(f"Build: {self.name}")